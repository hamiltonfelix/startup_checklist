-- 0008 · BRM de Valor: encontros, presenças, ritual semanal, entregáveis e Histórico de Valor
-- Dono: engenheiro de BRM. Nenhum outro agente altera este arquivo.
--
-- Depende de 0001, 0002, 0003 e 0007. Não depende de 0004, 0005 nem 0006.
-- A coluna contrato_id nasce sem chave estrangeira, como em 0007.
--
-- Nada é apagado. Remover é preencher arquivado_em. Por isso nenhuma tabela
-- deste arquivo ganha política for delete: o comando fica sem linha alcançável.

-- ------------------------------------------------------------ tipos do BRM

create type valor.brm_status_encontro as enum (
  'previsto', 'realizado', 'remarcado', 'cancelado'
);

create type valor.brm_situacao_presenca as enum (
  'presente', 'ausente_justificado', 'ausente'
);

create type valor.brm_tipo_item_ritual as enum (
  'highlight', 'lowlight', 'meta', 'prioridade'
);

create type valor.brm_tipo_entregavel as enum (
  'ata', 'pre_pauta', 'resumo_semanal', 'plano_de_conta', 'plano_de_negocio',
  'plano_de_trabalho', 'plano_de_acao', 'plano_de_desenvolvimento',
  'diagnostico', 'relatorio', 'material_de_apoio', 'certificado', 'outro'
);

create type valor.brm_status_entregavel as enum ('rascunho', 'entregue', 'aprovado');

-- ------------------------------------------------------------------ encontros

-- O encontro da turma. O campo numero é a posição na sequência oficial e não
-- muda em remarcação: a remarcação nasce como nova tentativa do mesmo número.
create table valor.encontros (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  turma_id       uuid not null references valor.turmas(id) on delete restrict,
  numero         smallint not null check (numero >= 1),
  tentativa      smallint not null default 1 check (tentativa >= 1),
  tema           text not null,
  pauta          jsonb not null default '[]',
  data_prevista           date not null,
  hora_prevista_inicio    time,
  hora_prevista_fim       time,
  data_prevista_original  date,
  data_realizada          date,
  hora_realizada_inicio   time,
  hora_realizada_fim      time,
  formato        valor.brm_formato_encontro not null default 'online',
  local          text,
  link           text,
  status         valor.brm_status_encontro not null default 'previsto',
  conselheiro_id uuid references valor.usuarios(id) on delete restrict,
  assessor_id    uuid references valor.usuarios(id) on delete restrict,
  gravacao_url     text,
  transcricao_url  text,
  transcricao_texto text,
  remarcado_de   uuid references valor.encontros(id) on delete restrict,
  remarcado_para uuid references valor.encontros(id) on delete restrict
                   deferrable initially deferred,
  motivo_remarcacao text,
  eh_presencial_do_mes     boolean not null default false,
  eh_pauta_prioritaria     boolean not null default false,
  eh_encontro_de_gestao    boolean not null default false,
  eh_hotseat               boolean not null default false,
  hotseat_participante_id  uuid references valor.participantes(id) on delete restrict,
  restrito       boolean not null default false,
  observacoes_restritas text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (turma_id, numero, tentativa),
  check (hora_prevista_fim is null or hora_prevista_inicio is null
         or hora_prevista_fim > hora_prevista_inicio),
  check (status <> 'realizado' or data_realizada is not null),
  check (remarcado_de is null or remarcado_de <> id)
);

comment on table valor.encontros is
  'O encontro da turma, previsto e realizado, com condução, gravação e transcrição.';
comment on column valor.encontros.numero is
  'Posição na sequência oficial da turma, de 1 até a carga do programa. A remarcação preserva este número.';
comment on column valor.encontros.tentativa is
  'Quantas vezes este número já foi marcado. A primeira marcação é 1, cada remarcação soma um.';
comment on column valor.encontros.data_prevista_original is
  'A data da primeira marcação deste número. Preenchida pelo gatilho e nunca reescrita.';
comment on column valor.encontros.remarcado_de is
  'O encontro que esta linha substitui. Quem tem este campo preenchido é a remarcação.';
comment on column valor.encontros.remarcado_para is
  'O encontro que substituiu esta linha. Preenchido pelo gatilho no momento da remarcação. A chave estrangeira é adiada até o commit porque o sucessor ainda está nascendo quando o gatilho roda.';
comment on column valor.encontros.formato is
  'Modalidade do encontro: presencial, online ou híbrido.';
comment on column valor.encontros.eh_presencial_do_mes is
  'Marca o presencial mensal do conselho.';
comment on column valor.encontros.eh_pauta_prioritaria is
  'Marca a pauta prioritária mensal do conselho dedicado.';
comment on column valor.encontros.eh_encontro_de_gestao is
  'Marca o encontro semanal de gestão, que anda ao lado do encontro de conselho.';
comment on column valor.encontros.eh_hotseat is
  'Marca o encontro com hotseat de um membro, no conselho compartilhado.';
comment on column valor.encontros.restrito is
  'Encontro sobre pessoas do cliente. Fica fora de qualquer visão de participante.';
comment on column valor.encontros.transcricao_texto is
  'CONFIDENCIAL: equipe de entrega da casa. Texto bruto da reunião, pode conter avaliação de pessoa.';
comment on column valor.encontros.transcricao_url is
  'CONFIDENCIAL: equipe de entrega da casa. Aponta para a transcrição bruta da reunião.';
comment on column valor.encontros.observacoes_restritas is
  'CONFIDENCIAL: equipe de entrega da casa. Anotação sobre gente do cliente, fora da ata enviada.';
comment on column valor.encontros.gravacao_url is
  'CONFIDENCIAL: equipe de entrega da casa e participantes da própria turma.';

-- Só existe um encontro vivo por número. O remarcado e o cancelado saem da
-- disputa, mas continuam na tabela com o número original preservado.
create unique index encontro_numero_vivo
  on valor.encontros (turma_id, numero)
  where status in ('previsto', 'realizado') and arquivado_em is null;

create or replace function valor.brm_encontro_sequencia() returns trigger
language plpgsql security definer set search_path = valor, public as $$
declare
  v_numero    smallint;
  v_tentativa smallint;
  v_original  date;
  v_turma     uuid;
  v_status    valor.brm_status_encontro;
begin
  if new.remarcado_de is not null then
    select e.numero, e.tentativa, e.data_prevista_original, e.turma_id, e.status
      into v_numero, v_tentativa, v_original, v_turma, v_status
    from valor.encontros e
    where e.id = new.remarcado_de;

    if v_numero is null then
      raise exception 'O encontro de origem da remarcação não existe.'
        using errcode = '23503';
    end if;

    if v_turma <> new.turma_id then
      raise exception 'A remarcação precisa ficar na mesma turma do encontro de origem.'
        using errcode = '23514';
    end if;

    if v_status = 'realizado' then
      raise exception 'Encontro já realizado não é remarcado.' using errcode = '23514';
    end if;

    -- A numeração original não se perde: a remarcação herda o número e a data
    -- da primeira marcação, e apenas soma uma tentativa.
    new.numero := v_numero;
    new.tentativa := (v_tentativa + 1)::smallint;
    new.data_prevista_original := v_original;

    -- O antecessor sai da disputa aqui, antes de o índice único ser conferido.
    update valor.encontros
       set status = 'remarcado', remarcado_para = new.id
     where id = new.remarcado_de;
  else
    new.tentativa := coalesce(new.tentativa, 1);
    new.data_prevista_original := coalesce(new.data_prevista_original, new.data_prevista);
  end if;

  return new;
end;
$$;

comment on function valor.brm_encontro_sequencia() is
  'Mantém a numeração oficial da turma quando um encontro é remarcado.';

create trigger sequencia_do_encontro
  before insert on valor.encontros
  for each row execute function valor.brm_encontro_sequencia();

-- ------------------------------------------------------------------ presenças

create table valor.presencas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  encontro_id    uuid not null references valor.encontros(id) on delete restrict,
  participante_id uuid not null references valor.participantes(id) on delete restrict,
  situacao       valor.brm_situacao_presenca not null default 'ausente',
  minutos_presentes smallint check (minutos_presentes >= 0),
  justificativa  text,
  observacao     text,
  registrada_em  timestamptz not null default now(),
  registrada_por uuid references valor.usuarios(id) on delete restrict,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (encontro_id, participante_id),
  check (situacao <> 'ausente_justificado' or justificativa is not null)
);

comment on table valor.presencas is
  'Presença de cada participante em cada encontro: presente, ausente justificado ou ausente.';
comment on column valor.presencas.justificativa is
  'CONFIDENCIAL: equipe de entrega da casa e o próprio participante. Motivo de ausência de gente do cliente.';
comment on column valor.presencas.observacao is
  'CONFIDENCIAL: equipe de entrega da casa. Anotação sobre gente do cliente no encontro.';

-- A presença acumulada do participante vive em valor.participantes e é
-- recalculada aqui, para o painel não precisar somar em tempo de consulta.
create or replace function valor.brm_recalcula_presenca() returns trigger
language plpgsql security definer set search_path = valor, public as $$
declare v_participante uuid;
begin
  v_participante := coalesce(new.participante_id, old.participante_id);

  update valor.participantes pa
     set encontros_convocados = soma.convocados,
         encontros_presentes  = soma.presentes
    from (
      select count(*)::smallint as convocados,
             count(*) filter (where pr.situacao = 'presente')::smallint as presentes
      from valor.presencas pr
      where pr.participante_id = v_participante
        and pr.arquivado_em is null
    ) soma
   where pa.id = v_participante;

  return null;
end;
$$;

create trigger presenca_acumulada
  after insert or update on valor.presencas
  for each row execute function valor.brm_recalcula_presenca();

-- ------------------------------------------------------- ritual semanal

-- O ritual semanal da turma: Highlights, Lowlights, Metas e Prioridades.
-- Cada item tem tópico, responsável e data, e fica ligado ao encontro.
create table valor.itens_ritual_semanal (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  encontro_id    uuid not null references valor.encontros(id) on delete restrict,
  turma_id       uuid not null references valor.turmas(id) on delete restrict,
  conta_id       uuid references valor.contas(id) on delete restrict,
  tipo           valor.brm_tipo_item_ritual not null,
  ordem          smallint not null default 1 check (ordem >= 1),
  topico         text not null,
  detalhe        text,
  responsavel_usuario_id      uuid references valor.usuarios(id) on delete restrict,
  responsavel_participante_id uuid references valor.participantes(id) on delete restrict,
  responsavel_nome            text,
  data_alvo      date not null,
  concluido_em   date,
  evidencia      text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  check (responsavel_usuario_id is not null
         or responsavel_participante_id is not null
         or responsavel_nome is not null)
);

comment on table valor.itens_ritual_semanal is
  'O ritual semanal da turma, nos quatro tipos: Highlights, Lowlights, Metas e Prioridades.';
comment on column valor.itens_ritual_semanal.tipo is
  'Rótulos de tela: Highlights, Lowlights, Metas e Prioridades.';
comment on column valor.itens_ritual_semanal.topico is
  'O tópico do item. É o texto que aparece na lista do ritual.';
comment on column valor.itens_ritual_semanal.responsavel_nome is
  'Nome do responsável quando é gente do cliente sem cadastro próprio.';
comment on column valor.itens_ritual_semanal.data_alvo is
  'A data do item. Todo item do ritual tem tópico, responsável e data.';
comment on column valor.itens_ritual_semanal.detalhe is
  'CONFIDENCIAL: equipe de entrega da casa e a própria turma. Pode conter anotação sobre gente do cliente.';

-- ---------------------------------------------------------------- entregáveis

create table valor.entregaveis (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  turma_id       uuid not null references valor.turmas(id) on delete restrict,
  encontro_id    uuid references valor.encontros(id) on delete restrict,
  participante_id uuid references valor.participantes(id) on delete restrict,
  conta_id       uuid references valor.contas(id) on delete restrict,
  tipo           valor.brm_tipo_entregavel not null default 'outro',
  tipo_detalhe   text,
  titulo         text not null,
  descricao      text,
  arquivo_url    text,
  versao         smallint not null default 1 check (versao >= 1),
  prazo          date,
  data_entrega   date,
  produzido_por_usuario_id      uuid references valor.usuarios(id) on delete restrict,
  produzido_por_participante_id uuid references valor.participantes(id) on delete restrict,
  produzido_por_nome            text,
  status         valor.brm_status_entregavel not null default 'rascunho',
  visivel_ao_cliente boolean not null default false,
  aprovado_em    date,
  aprovado_por   uuid references valor.usuarios(id) on delete restrict,
  avaliacao      jsonb not null default '{}',
  nota           numeric(6,4) check (nota >= 0),
  devolutiva     text,
  avaliador_id   uuid references valor.usuarios(id) on delete restrict,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  check (status = 'rascunho' or data_entrega is not null),
  check (status <> 'aprovado' or aprovado_em is not null),
  check (aprovado_em is null or data_entrega is null or aprovado_em >= data_entrega)
);

comment on table valor.entregaveis is
  'O que cada encontro produziu: ata, plano, resumo semanal, diagnóstico e o que mais a turma gerar.';
comment on column valor.entregaveis.tipo_detalhe is
  'Nome livre do entregável quando o tipo é outro.';
comment on column valor.entregaveis.visivel_ao_cliente is
  'Chave da visão do participante do cliente. Falso guarda o entregável dentro de casa.';
comment on column valor.entregaveis.produzido_por_nome is
  'Nome de quem produziu quando é gente do cliente sem cadastro próprio.';
comment on column valor.entregaveis.avaliacao is
  'CONFIDENCIAL: equipe de entrega da casa e o próprio participante. Rubrica do programa, é avaliação de pessoa.';
comment on column valor.entregaveis.nota is
  'CONFIDENCIAL: equipe de entrega da casa e o próprio participante. É avaliação de pessoa.';
comment on column valor.entregaveis.devolutiva is
  'CONFIDENCIAL: equipe de entrega da casa e o próprio participante. Devolutiva sobre o trabalho de uma pessoa.';

-- ------------------------------------------------------- Histórico de Valor

-- O registro obrigatório por trimestre: o que foi entregue, que resultado
-- gerou e qual a evidência, por conta e por programa. É o insumo da Renovação.
create table valor.historico_valor (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  programa_id    uuid not null references valor.programas(id) on delete restrict,
  turma_id       uuid references valor.turmas(id) on delete restrict,
  encontro_id    uuid references valor.encontros(id) on delete restrict,
  entregavel_id  uuid references valor.entregaveis(id) on delete restrict,
  contrato_id    uuid,
  ano            smallint not null check (ano between 2000 and 2100),
  trimestre      smallint not null check (trimestre between 1 and 4),
  competencia    text generated always as (ano::text || '-T' || trimestre::text) stored,
  data_referencia date not null default current_date,
  entregue       text not null,
  resultado      text not null,
  evidencia      text not null,
  valor_numero   numeric(14,2),
  valor_unidade  text,
  arquivo_url    text,
  registrado_por uuid references valor.usuarios(id) on delete restrict,
  confirmado_por_contato_id uuid references valor.contatos(id) on delete restrict,
  confirmado_em  date,
  observacao_interna text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);

comment on table valor.historico_valor is
  'Registro obrigatório por trimestre: o que foi entregue, que resultado gerou e qual a evidência.';
comment on column valor.historico_valor.competencia is
  'Trimestre em texto, no formato ano, traço, letra T e número, por exemplo 2026-T3.';
comment on column valor.historico_valor.entregue is 'O que foi entregue no trimestre.';
comment on column valor.historico_valor.resultado is 'Que resultado a entrega gerou para a conta.';
comment on column valor.historico_valor.evidencia is 'Qual a evidência do resultado.';
comment on column valor.historico_valor.contrato_id is
  'Contrato do registro. Sem chave estrangeira até valor.contratos existir.';
comment on column valor.historico_valor.observacao_interna is
  'CONFIDENCIAL: equipe de entrega da casa. Pode conter anotação sobre gente do cliente.';

-- Programas ativos sem registro no trimestre corrente. É a fila de cobrança do
-- registro obrigatório. A visão respeita a política de quem consulta.
create view valor.vw_historico_valor_devido
with (security_invoker = true) as
select
  p.inquilino_id,
  p.id                         as programa_id,
  p.codigo                     as programa_codigo,
  p.nome                       as programa_nome,
  p.responsavel_id,
  tc.conta_id,
  extract(year from current_date)::smallint    as ano,
  extract(quarter from current_date)::smallint as trimestre
from valor.programas p
join valor.turmas t        on t.programa_id = p.id and t.arquivado_em is null
join valor.turmas_contas tc on tc.turma_id = t.id and tc.arquivado_em is null
where p.status = 'ativo'
  and p.arquivado_em is null
  and not exists (
    select 1 from valor.historico_valor hv
    where hv.programa_id = p.id
      and hv.conta_id = tc.conta_id
      and hv.arquivado_em is null
      and hv.ano = extract(year from current_date)::smallint
      and hv.trimestre = extract(quarter from current_date)::smallint
  )
group by p.inquilino_id, p.id, p.codigo, p.nome, p.responsavel_id, tc.conta_id;

comment on view valor.vw_historico_valor_devido is
  'Conta e programa ativos que ainda não têm registro de Histórico de Valor no trimestre corrente.';

-- Agenda da turma sem nenhuma coluna confidencial. É a visão que o portal do
-- participante consome, para a máscara de coluna não depender da interface.
create view valor.vw_agenda_turma
with (security_invoker = true) as
select
  e.inquilino_id,
  e.turma_id,
  e.id as encontro_id,
  e.numero,
  e.tentativa,
  e.tema,
  e.data_prevista,
  e.data_prevista_original,
  e.data_realizada,
  e.hora_prevista_inicio,
  e.hora_prevista_fim,
  e.formato,
  e.local,
  e.link,
  e.status,
  e.eh_presencial_do_mes,
  e.eh_pauta_prioritaria,
  e.eh_encontro_de_gestao,
  e.eh_hotseat
from valor.encontros e
where e.arquivado_em is null and not e.restrito;

comment on view valor.vw_agenda_turma is
  'Agenda da turma sem transcrição, sem gravação e sem anotação restrita.';

-- ------------------------------------------------------------------- índices

create index on valor.encontros (turma_id, numero, tentativa);
create index on valor.encontros (inquilino_id, data_prevista) where arquivado_em is null;
create index on valor.encontros (turma_id, status) where arquivado_em is null;
create index on valor.encontros (conselheiro_id) where arquivado_em is null;
create index on valor.presencas (participante_id) where arquivado_em is null;
create index on valor.presencas (encontro_id, situacao) where arquivado_em is null;
create index on valor.itens_ritual_semanal (encontro_id, tipo, ordem) where arquivado_em is null;
create index on valor.itens_ritual_semanal (turma_id, data_alvo) where concluido_em is null;
create index on valor.entregaveis (turma_id, tipo, status) where arquivado_em is null;
create index on valor.entregaveis (encontro_id) where arquivado_em is null;
create index on valor.entregaveis (participante_id) where arquivado_em is null;
create index on valor.entregaveis (turma_id) where visivel_ao_cliente and arquivado_em is null;
create index on valor.historico_valor (inquilino_id, conta_id, ano, trimestre) where arquivado_em is null;
create index on valor.historico_valor (programa_id, ano, trimestre) where arquivado_em is null;

create trigger carimbo before update on valor.encontros            for each row execute function valor.carimbar();
create trigger carimbo before update on valor.presencas            for each row execute function valor.carimbar();
create trigger carimbo before update on valor.itens_ritual_semanal for each row execute function valor.carimbar();
create trigger carimbo before update on valor.entregaveis          for each row execute function valor.carimbar();
create trigger carimbo before update on valor.historico_valor      for each row execute function valor.carimbar();

-- ------------------------------------------------------------------ segurança

alter table valor.encontros            enable row level security;
alter table valor.presencas            enable row level security;
alter table valor.itens_ritual_semanal enable row level security;
alter table valor.entregaveis          enable row level security;
alter table valor.historico_valor      enable row level security;

-- O parceiro nunca enxerga nada de BRM. A leitura abre com a negativa
-- `not valor.eh_parceiro()` porque logo depois vem o predicado positivo que
-- ancora o acesso, como faz a 0007. Sem essa âncora a negativa seria o defeito,
-- e não a regra.
-- O participante do cliente só alcança a própria turma, e nela não vê encontro
-- restrito nem entregável que não esteja marcado como visível ao cliente.
-- Toda escrita deste arquivo passa por `valor.brm_pode_escrever()`, que nomeia
-- quem pode, então nenhum perfil novo do enum entra aqui por omissão.

create policy encontro_le on valor.encontros for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and valor.brm_turma_visivel(turma_id)
         and (not restrito or not valor.brm_so_participante(turma_id)));

create policy encontro_insere on valor.encontros for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and valor.brm_eh_equipe_da_turma(turma_id));

create policy encontro_atualiza on valor.encontros for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_eh_equipe_da_turma(turma_id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

create policy presenca_le on valor.presencas for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and exists (
           select 1 from valor.participantes pa
           where pa.id = presencas.participante_id
             and ( valor.brm_eh_equipe_da_turma(pa.turma_id)
                   or pa.usuario_id = valor.usuario_atual() )
         ));

create policy presenca_insere on valor.presencas for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and exists (
                select 1 from valor.participantes pa
                where pa.id = presencas.participante_id
                  and valor.brm_eh_equipe_da_turma(pa.turma_id)
              ));

create policy presenca_atualiza on valor.presencas for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and exists (
           select 1 from valor.participantes pa
           where pa.id = presencas.participante_id
             and valor.brm_eh_equipe_da_turma(pa.turma_id)
         ))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

create policy ritual_le on valor.itens_ritual_semanal for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and valor.brm_turma_visivel(turma_id));

create policy ritual_insere on valor.itens_ritual_semanal for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and valor.brm_eh_equipe_da_turma(turma_id));

create policy ritual_atualiza on valor.itens_ritual_semanal for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_eh_equipe_da_turma(turma_id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

create policy entregavel_le on valor.entregaveis for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and valor.brm_turma_visivel(turma_id)
         and (visivel_ao_cliente or not valor.brm_so_participante(turma_id)));

create policy entregavel_insere on valor.entregaveis for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and valor.brm_eh_equipe_da_turma(turma_id));

create policy entregavel_atualiza on valor.entregaveis for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_eh_equipe_da_turma(turma_id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

-- O Histórico de Valor é registro interno da entrega. Quem está na sala como
-- participante não o lê, salvo quando também conduz a entrega pela casa.
create policy historico_le on valor.historico_valor for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and valor.brm_programa_visivel(programa_id)
         and (valor.brm_pode_escrever() or not valor.brm_sessao_eh_participante()));

create policy historico_insere on valor.historico_valor for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and valor.brm_programa_visivel(programa_id));

create policy historico_atualiza on valor.historico_valor for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_programa_visivel(programa_id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());
