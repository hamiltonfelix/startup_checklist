-- 0009 · Conselho: modelo de ata, pauta, ata, pendência e banco de pautas
-- Dono: engenheiro de governança. Nenhum outro agente altera este arquivo.
--
-- O rito da casa, conforme a seção 7 de CATALOGO-E-REGRAS.md:
--   padrão de ata de sete seções em uso desde setembro de 2026, com a extensão
--   opcional de 16 blocos ligável por cliente; o assessor escreve, o conselheiro
--   aprova, o sistema envia, com alerta se não sair em 24 horas; pendência aberta
--   reaparece na pré-pauta da reunião seguinte até fechar; reunião sobre pessoas
--   do cliente fica marcada como restrita, fora da ata enviada e fora do parceiro;
--   banco de pautas com os 15 temas de governança e as 6 famílias de gestão.
--
-- Dependência em aberto: a migração 0008, que cria valor.encontros, está sendo
-- escrita em paralelo. Por isso as colunas encontro_id e turma_id nascem soltas,
-- sem chave estrangeira. O pedido de acrescentar as restrições depois está no
-- relatório final desta entrega.
--
-- Nada é apagado. Arquivar é preencher arquivado_em. Nenhuma tabela deste arquivo
-- recebe política de remoção, e um gatilho de guarda recusa qualquer delete.

-- ---------------------------------------------------------------- tipos do domínio

create type valor.ata_modelo_tipo as enum ('padrao_sete_secoes', 'extensao_dezesseis_blocos');

create type valor.ata_status as enum ('rascunho', 'em_aprovacao', 'aprovada', 'enviada');

create type valor.pendencia_status as enum ('aberta', 'em_andamento', 'concluida', 'cancelada');

create type valor.pendencia_origem as enum ('deliberacao', 'proximo_passo', 'tarefa_do_conselheiro', 'tarefa_do_assessor', 'tarefa_do_cliente');

create type valor.pauta_status as enum ('rascunho', 'publicada', 'usada', 'cancelada');

create type valor.pauta_item_tipo as enum ('deliberativo', 'informativo', 'consultivo');

create type valor.pauta_origem as enum ('pendencia_aberta', 'banco_de_pautas', 'ritual_semanal', 'pedido_do_cliente', 'conselheiro', 'assessor');

create type valor.pauta_familia as enum ('governanca', 'gestao', 'tendencias');

-- ---------------------------------------------------------------- guarda de remoção

-- O contrato técnico proíbe remover linha. Quem precisa tirar algo de circulação
-- preenche arquivado_em. Este gatilho fecha a porta também para quem contorna a
-- política de linha, por exemplo o dono da tabela numa carga manual.
create or replace function valor.impedir_remocao() returns trigger
language plpgsql as $$
begin
  raise exception 'Remoção proibida em %. Arquive preenchendo arquivado_em.', tg_table_name
    using errcode = 'restrict_violation';
end;
$$;

comment on function valor.impedir_remocao() is
  'Guarda do contrato técnico: nada é apagado, arquivar é preencher arquivado_em.';

-- ---------------------------------------------------------------- modelos de ata

create table valor.modelos_ata (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  codigo         text not null,
  nome           text not null,
  tipo           valor.ata_modelo_tipo not null,
  versao         smallint not null default 1 check (versao >= 1),
  estrutura      jsonb not null default '{}',
  quantidade_secoes smallint not null check (quantidade_secoes > 0),
  padrao_da_casa boolean not null default false,
  vigente_desde  date not null default current_date,
  ativo          boolean not null default true,
  observacao     text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, codigo, versao)
);
comment on table valor.modelos_ata is
  'O padrão de sete seções e a extensão de 16 blocos, versionados. A versão nova nasce como linha nova, a antiga continua para histórico.';
comment on column valor.modelos_ata.estrutura is
  'As seções ordenadas, cada uma com chave, rótulo acentuado, obrigatoriedade e texto de apoio.';
comment on column valor.modelos_ata.padrao_da_casa is
  'Verdadeiro apenas no modelo oficial da casa. Um por inquilino, garantido por índice único parcial.';

create unique index modelos_ata_padrao_unico
  on valor.modelos_ata (inquilino_id)
  where padrao_da_casa and ativo and arquivado_em is null;

-- A escolha por cliente: qual modelo vale para a conta e se a extensão está ligada.
create table valor.modelos_ata_por_conta (
  id              uuid primary key default gen_random_uuid(),
  inquilino_id    uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id        uuid not null references valor.contas(id) on delete restrict,
  modelo_ata_id   uuid not null references valor.modelos_ata(id) on delete restrict,
  usa_extensao    boolean not null default false,
  extensao_modelo_id uuid references valor.modelos_ata(id) on delete restrict,
  vigente_desde   date not null default current_date,
  observacao      text,
  criado_em       timestamptz not null default now(),
  criado_por      uuid,
  atualizado_em   timestamptz,
  atualizado_por  uuid,
  arquivado_em    timestamptz,
  check (not usa_extensao or extensao_modelo_id is not null)
);
comment on table valor.modelos_ata_por_conta is
  'Liga a extensão de 16 blocos por cliente. Sem linha aqui, a conta usa o padrão da casa.';

create unique index modelos_ata_por_conta_unico
  on valor.modelos_ata_por_conta (inquilino_id, conta_id)
  where arquivado_em is null;

-- ---------------------------------------------------------------- banco de pautas

create table valor.banco_pautas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  familia        valor.pauta_familia not null,
  codigo         text not null,
  tema           text not null,
  descricao      text,
  perguntas_orientadoras jsonb not null default '[]',
  materiais      jsonb not null default '[]',
  tipo_sugerido  valor.pauta_item_tipo not null default 'consultivo',
  tempo_sugerido_minutos smallint not null default 30 check (tempo_sugerido_minutos > 0),
  ordem          smallint not null default 100,
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, codigo)
);
comment on table valor.banco_pautas is
  'Os 15 temas de governança e as 6 famílias de gestão do método, para montar pauta sem partir do zero.';
comment on column valor.banco_pautas.perguntas_orientadoras is
  'Lista de perguntas que abrem a conversa do tema. Sai impressa na pauta enviada ao cliente.';

-- ---------------------------------------------------------------- pauta da reunião

create table valor.pautas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  turma_id       uuid,
  encontro_id    uuid,
  numero         integer,
  titulo         text not null,
  data_reuniao   date not null,
  hora_inicio    time,
  status         valor.pauta_status not null default 'rascunho',
  observacao     text,
  publicada_em   timestamptz,
  enviada_em     timestamptz,
  gerada_com_ia  boolean not null default false,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on table valor.pautas is
  'A pauta de uma reunião de conselho. Nasce com as pendências abertas da turma já dentro.';
comment on column valor.pautas.encontro_id is
  'Liga ao encontro quando houver. Sem chave estrangeira até a migração 0008 criar valor.encontros.';
comment on column valor.pautas.turma_id is
  'Sem chave estrangeira até a migração 0008 criar valor.turmas.';

create unique index pautas_numero_unico
  on valor.pautas (inquilino_id, conta_id, numero)
  where numero is not null and arquivado_em is null;

-- ---------------------------------------------------------------- ata

create table valor.atas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  pauta_id       uuid references valor.pautas(id) on delete restrict,
  modelo_ata_id  uuid references valor.modelos_ata(id) on delete restrict,
  turma_id       uuid,
  encontro_id    uuid,
  numero         integer not null,
  titulo         text,
  data_reuniao   date not null,
  conteudo       jsonb not null default '{}',
  status         valor.ata_status not null default 'rascunho',
  restrita       boolean not null default false,
  ata_anterior_aprovada boolean not null default false,
  escrita_por    uuid references valor.usuarios(id),
  escrita_em     timestamptz,
  aprovada_por   uuid references valor.usuarios(id),
  aprovada_em    timestamptz,
  enviada_em     timestamptz,
  prazo_envio    timestamptz not null default now() + interval '24 hours',
  destinatarios  jsonb not null default '[]',
  arquivo_pdf_url  text,
  arquivo_docx_url text,
  gerada_com_ia  boolean not null default false,
  proxima_data   date,
  pre_pauta      jsonb not null default '[]',
  insight_conselho text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint ata_restrita_nunca_enviada check (not (restrita and status = 'enviada')),
  constraint ata_restrita_sem_destinatario check (not restrita or destinatarios = '[]'::jsonb),
  constraint ata_aprovada_tem_aprovador check (
    status not in ('aprovada', 'enviada') or (aprovada_por is not null and aprovada_em is not null)),
  constraint ata_enviada_tem_carimbo check (status <> 'enviada' or enviada_em is not null),
  unique (inquilino_id, conta_id, numero)
);
comment on table valor.atas is
  'A ata da reunião, com o conteúdo por seção em jsonb, no modelo escolhido para a conta.';
comment on column valor.atas.conteudo is
  'Uma chave por seção do modelo: identificacao, participantes, pauta, resumo_discussoes, deliberacoes, proximos_passos, proxima_reuniao.';
comment on column valor.atas.restrita is
  'CONFIDENCIAL: líder, administrador, financeiro e quem escreveu ou aprovou. A reunião tratou de pessoas do cliente. Fica fora de qualquer envio e de qualquer visão de parceiro.';
comment on column valor.atas.insight_conselho is
  'CONFIDENCIAL: time interno. A reflexão própria do conselheiro, que não vai na ata enviada.';
comment on column valor.atas.prazo_envio is
  'O carimbo de prazo do fluxo: o assessor escreve, o conselheiro aprova, o sistema envia em 24 horas. Vencido e sem envio, vira alerta.';
comment on column valor.atas.encontro_id is
  'Liga ao encontro quando houver. Sem chave estrangeira até a migração 0008 criar valor.encontros.';
comment on column valor.atas.gerada_com_ia is
  'Verdadeiro quando a ata saiu com apoio de inteligência artificial. Da fase 3 em diante a inteligência artificial é assistente, nunca decisora.';

-- ---------------------------------------------------------------- pendência

create table valor.pendencias (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  turma_id       uuid,
  encontro_id    uuid,
  ata_id         uuid references valor.atas(id) on delete restrict,
  ata_secao      text,
  origem         valor.pendencia_origem not null default 'deliberacao',
  descricao      text not null,
  dono_usuario_id uuid references valor.usuarios(id),
  dono_nome      text,
  prazo          date,
  status         valor.pendencia_status not null default 'aberta',
  reaparece_na_pauta boolean not null default true,
  concluida_em   date,
  evidencia      text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint pendencia_tem_dono check (dono_usuario_id is not null or dono_nome is not null),
  constraint pendencia_concluida_tem_data check (status <> 'concluida' or concluida_em is not null)
);
comment on table valor.pendencias is
  'O que ficou em aberto na reunião. Reaparece na pré-pauta da reunião seguinte, com dono e prazo, até fechar.';
comment on column valor.pendencias.dono_nome is
  'Usado quando o dono é pessoa do cliente, que não tem usuário na plataforma.';
comment on column valor.pendencias.reaparece_na_pauta is
  'Padrão verdadeiro. Só o líder desliga, e mesmo assim a pendência continua no relatório de aberto.';
comment on column valor.pendencias.ata_secao is
  'Em que seção da ata a pendência nasceu: deliberacoes ou proximos_passos.';
comment on column valor.pendencias.encontro_id is
  'Sem chave estrangeira até a migração 0008 criar valor.encontros.';

-- ---------------------------------------------------------------- itens da pauta

create table valor.pautas_itens (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  pauta_id       uuid not null references valor.pautas(id) on delete cascade,
  ordem          smallint not null default 100,
  tema           text not null,
  detalhe        text,
  tipo           valor.pauta_item_tipo not null default 'deliberativo',
  tempo_previsto_minutos smallint not null default 15 check (tempo_previsto_minutos > 0),
  responsavel_usuario_id uuid references valor.usuarios(id),
  responsavel_nome text,
  origem         valor.pauta_origem not null default 'conselheiro',
  pendencia_id   uuid references valor.pendencias(id) on delete restrict,
  banco_pauta_id uuid references valor.banco_pautas(id) on delete restrict,
  automatico     boolean not null default false,
  tratado        boolean not null default false,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint item_de_pendencia_tem_origem check (
    pendencia_id is null or origem = 'pendencia_aberta'),
  constraint item_de_banco_tem_origem check (
    banco_pauta_id is null or origem = 'banco_de_pautas')
);
comment on table valor.pautas_itens is
  'Os itens ordenados da pauta, com tempo previsto, responsável e origem. Item vindo de pendência aberta entra automaticamente.';
comment on column valor.pautas_itens.automatico is
  'Verdadeiro quando o item entrou sozinho, pela regra da pendência que reaparece.';
comment on column valor.pautas_itens.responsavel_nome is
  'Usado quando o responsável é pessoa do cliente, que não tem usuário na plataforma.';

create unique index pautas_itens_pendencia_unica
  on valor.pautas_itens (pauta_id, pendencia_id)
  where pendencia_id is not null and arquivado_em is null;

-- ---------------------------------------------------------------- índices

create index on valor.modelos_ata (inquilino_id, tipo) where ativo and arquivado_em is null;
create index on valor.banco_pautas (inquilino_id, familia, ordem) where ativo and arquivado_em is null;
create index on valor.pautas (inquilino_id, turma_id, data_reuniao desc) where arquivado_em is null;
create index on valor.pautas (inquilino_id, conta_id, data_reuniao desc) where arquivado_em is null;
create index on valor.pautas_itens (pauta_id, ordem) where arquivado_em is null;
create index on valor.atas (inquilino_id, conta_id, data_reuniao desc) where arquivado_em is null;
create index on valor.atas (inquilino_id, status, prazo_envio) where arquivado_em is null;
create index on valor.atas (inquilino_id, turma_id, data_reuniao desc) where arquivado_em is null;
create index on valor.pendencias (inquilino_id, turma_id, status) where arquivado_em is null;
create index on valor.pendencias (inquilino_id, conta_id, prazo) where arquivado_em is null;
create index on valor.pendencias (ata_id) where arquivado_em is null;

-- ---------------------------------------------------------------- fluxo da ata

-- O assessor escreve, o conselheiro aprova, o sistema envia. O carimbo de prazo
-- nasce da data da reunião: 24 horas depois do encontro a ata precisa ter saído.
create or replace function valor.ata_fluxo() returns trigger
language plpgsql as $$
declare
  perfil text := valor.perfil_atual();
begin
  if tg_op = 'INSERT' then
    if new.escrita_por is null then
      new.escrita_por := valor.usuario_atual();
    end if;
    if new.escrita_em is null then
      new.escrita_em := now();
    end if;
    new.prazo_envio := (new.data_reuniao + time '23:59') at time zone current_setting('TimeZone') + interval '24 hours';
    return new;
  end if;

  if new.data_reuniao is distinct from old.data_reuniao then
    new.prazo_envio := (new.data_reuniao + time '23:59') at time zone current_setting('TimeZone') + interval '24 hours';
  end if;

  -- O fluxo anda para a frente. Ata enviada não volta para rascunho nem para
  -- aprovação. Se algo estiver errado, nasce uma ata nova, com número novo.
  if old.status = 'enviada' and new.status <> 'enviada' then
    raise exception 'Ata já enviada não volta de status. Registre uma ata nova.'
      using errcode = 'restrict_violation';
  end if;
  if old.status = 'aprovada' and new.status in ('rascunho', 'em_aprovacao')
     and not valor.ve_confidencial() then
    raise exception 'Perfil % não reabre ata aprovada. Só o líder devolve para correção.', perfil
      using errcode = 'insufficient_privilege';
  end if;

  -- Quem aprova é o conselheiro, o líder ou o administrador. O assessor escreve.
  if new.status in ('aprovada', 'enviada') and old.status not in ('aprovada', 'enviada') then
    if perfil not in ('conselheiro', 'lider', 'admin_master', 'emergencia') then
      raise exception 'Perfil % não aprova ata. O assessor escreve, o conselheiro aprova.', perfil
        using errcode = 'insufficient_privilege';
    end if;
    if new.aprovada_por is null then
      new.aprovada_por := valor.usuario_atual();
    end if;
    if new.aprovada_em is null then
      new.aprovada_em := now();
    end if;
  end if;

  -- Ata restrita nunca sai. A regra vive aqui e na restrição de verificação.
  if new.status = 'enviada' then
    if new.restrita then
      raise exception 'Ata restrita não é enviada. A reunião tratou de pessoas do cliente.'
        using errcode = 'restrict_violation';
    end if;
    if new.enviada_em is null then
      new.enviada_em := now();
    end if;
  end if;

  return new;
end;
$$;

comment on function valor.ata_fluxo() is
  'Guarda o fluxo da ata: quem escreve, quem aprova, quem envia, e o carimbo de prazo de 24 horas.';

create trigger ata_fluxo before insert or update on valor.atas
  for each row execute function valor.ata_fluxo();

-- ---------------------------------------------------------------- pré-pauta

-- A regra do rito: pendência aberta reaparece na pré-pauta da reunião seguinte,
-- com dono e prazo, até fechar. Depois das pendências vêm os temas sugeridos do
-- banco de pautas, priorizando o que a turma ainda não tratou.
create or replace function valor.montar_pre_pauta(turma_id uuid, data_referencia date)
returns table (
  ordem_item             integer,
  bloco                  text,
  tema                   text,
  detalhe                text,
  dono                   text,
  prazo                  date,
  situacao               text,
  tempo_previsto_minutos smallint,
  tipo                   valor.pauta_item_tipo,
  pendencia_id           uuid,
  banco_pauta_id         uuid
)
language plpgsql stable as $$
#variable_conflict use_column
declare
  alvo_inquilino uuid;
  abertas        integer;
begin
  select p.inquilino_id into alvo_inquilino
  from valor.pendencias p
  where p.turma_id = montar_pre_pauta.turma_id
  limit 1;

  if alvo_inquilino is null then
    select q.inquilino_id into alvo_inquilino
    from valor.pautas q
    where q.turma_id = montar_pre_pauta.turma_id
    limit 1;
  end if;

  alvo_inquilino := coalesce(valor.inquilino_atual(), alvo_inquilino);

  select count(*) into abertas
  from valor.pendencias p
  where p.turma_id = montar_pre_pauta.turma_id
    and p.inquilino_id = alvo_inquilino
    and p.arquivado_em is null
    and p.reaparece_na_pauta
    and p.status in ('aberta', 'em_andamento');

  return query
  with pendentes as (
    select
      p.id        as pendencia_id,
      p.descricao as descricao,
      coalesce(u.nome, p.dono_nome) as dono,
      p.prazo     as prazo,
      p.status    as status,
      row_number() over (
        order by (p.prazo is null), p.prazo, p.criado_em
      )::integer as posicao
    from valor.pendencias p
    left join valor.usuarios u on u.id = p.dono_usuario_id
    where p.turma_id = montar_pre_pauta.turma_id
      and p.inquilino_id = alvo_inquilino
      and p.arquivado_em is null
      and p.reaparece_na_pauta
      and p.status in ('aberta', 'em_andamento')
  ),
  ja_tratados as (
    select distinct i.banco_pauta_id
    from valor.pautas_itens i
    join valor.pautas q on q.id = i.pauta_id
    where q.turma_id = montar_pre_pauta.turma_id
      and i.banco_pauta_id is not null
      and i.arquivado_em is null
  ),
  sugeridos as (
    select
      b.id   as banco_pauta_id,
      b.tema as tema,
      b.descricao as descricao,
      b.tipo_sugerido as tipo_sugerido,
      b.tempo_sugerido_minutos as tempo_sugerido_minutos,
      row_number() over (order by b.familia, b.ordem, b.codigo)::integer as posicao
    from valor.banco_pautas b
    where b.inquilino_id = alvo_inquilino
      and b.ativo
      and b.arquivado_em is null
      and not exists (select 1 from ja_tratados t where t.banco_pauta_id = b.id)
  )
  select
    x.ordem_item,
    x.bloco,
    x.tema,
    x.detalhe,
    x.dono,
    x.prazo,
    x.situacao,
    x.tempo_previsto_minutos,
    x.tipo,
    x.pendencia_id,
    x.banco_pauta_id
  from (
    select
      d.posicao as ordem_item,
      'pendencia'::text as bloco,
      'Pendência em aberto'::text as tema,
      d.descricao as detalhe,
      d.dono as dono,
      d.prazo as prazo,
      case
        when d.prazo is null then 'sem prazo definido'
        when d.prazo < montar_pre_pauta.data_referencia then 'atrasada'
        else 'no prazo'
      end::text as situacao,
      10::smallint as tempo_previsto_minutos,
      'deliberativo'::valor.pauta_item_tipo as tipo,
      d.pendencia_id as pendencia_id,
      null::uuid as banco_pauta_id,
      0 as grupo
    from pendentes d
    union all
    select
      abertas + s.posicao as ordem_item,
      'tema_sugerido'::text as bloco,
      s.tema as tema,
      s.descricao as detalhe,
      null::text as dono,
      null::date as prazo,
      'sugestão do banco de pautas'::text as situacao,
      s.tempo_sugerido_minutos as tempo_previsto_minutos,
      s.tipo_sugerido as tipo,
      null::uuid as pendencia_id,
      s.banco_pauta_id as banco_pauta_id,
      1 as grupo
    from sugeridos s
    where s.posicao <= 5
  ) x
  order by x.grupo, x.ordem_item;
end;
$$;

comment on function valor.montar_pre_pauta(uuid, date) is
  'Monta a pré-pauta da reunião seguinte de uma turma: primeiro as pendências abertas, com dono e prazo, depois os temas sugeridos do banco de pautas.';

-- Toda pauta nova nasce com as pendências abertas da turma já dentro. A regra é
-- do banco, não da tela: quem cria a pauta por qualquer caminho recebe os itens.
create or replace function valor.pauta_puxar_pendencias() returns trigger
language plpgsql as $$
begin
  if new.turma_id is null then
    return new;
  end if;

  insert into valor.pautas_itens (
    inquilino_id, pauta_id, ordem, tema, detalhe, tipo,
    tempo_previsto_minutos, responsavel_usuario_id, responsavel_nome,
    origem, pendencia_id, automatico, criado_por
  )
  select
    new.inquilino_id,
    new.id,
    row_number() over (order by (p.prazo is null), p.prazo, p.criado_em)::smallint,
    'Pendência em aberto',
    p.descricao,
    'deliberativo'::valor.pauta_item_tipo,
    10::smallint,
    p.dono_usuario_id,
    coalesce(u.nome, p.dono_nome),
    'pendencia_aberta'::valor.pauta_origem,
    p.id,
    true,
    valor.usuario_atual()
  from valor.pendencias p
  left join valor.usuarios u on u.id = p.dono_usuario_id
  where p.turma_id = new.turma_id
    and p.inquilino_id = new.inquilino_id
    and p.arquivado_em is null
    and p.reaparece_na_pauta
    and p.status in ('aberta', 'em_andamento')
  on conflict do nothing;

  return new;
end;
$$;

comment on function valor.pauta_puxar_pendencias() is
  'Pendência aberta entra automaticamente como item da pauta nova da turma.';

create trigger pauta_puxar_pendencias after insert on valor.pautas
  for each row execute function valor.pauta_puxar_pendencias();

-- ---------------------------------------------------------------- semeadura

create or replace function valor.semear_modelos_ata(alvo_inquilino uuid)
returns integer language plpgsql as $$
declare
  inseridos integer;
begin
  insert into valor.modelos_ata (
    inquilino_id, codigo, nome, tipo, versao, quantidade_secoes,
    padrao_da_casa, vigente_desde, estrutura, observacao
  ) values (
    alvo_inquilino,
    'ata_sete_secoes',
    'Ata de conselho · padrão de sete seções',
    'padrao_sete_secoes',
    1,
    7,
    true,
    date '2026-09-01',
    jsonb_build_object(
      'secoes', jsonb_build_array(
        jsonb_build_object('chave','identificacao','ordem',1,'rotulo','Identificação','obrigatoria',true),
        jsonb_build_object('chave','participantes','ordem',2,'rotulo','Participantes','obrigatoria',true),
        jsonb_build_object('chave','pauta','ordem',3,'rotulo','Pauta','obrigatoria',true),
        jsonb_build_object('chave','resumo_discussoes','ordem',4,'rotulo','Resumo das discussões','obrigatoria',true),
        jsonb_build_object('chave','deliberacoes','ordem',5,'rotulo','Deliberações','obrigatoria',true),
        jsonb_build_object('chave','proximos_passos','ordem',6,'rotulo','Próximos passos','obrigatoria',true),
        jsonb_build_object('chave','proxima_reuniao','ordem',7,'rotulo','Próxima reunião com pré-pauta','obrigatoria',true)
      )
    ),
    'Padrão em uso desde setembro de 2026.'
  ),
  (
    alvo_inquilino,
    'ata_dezesseis_blocos',
    'Ata de conselho · extensão de 16 blocos',
    'extensao_dezesseis_blocos',
    1,
    16,
    false,
    date '2026-09-01',
    jsonb_build_object(
      'secoes', jsonb_build_array(
        jsonb_build_object('chave','identificacao','ordem',1,'rotulo','Identificação','obrigatoria',true),
        jsonb_build_object('chave','participantes','ordem',2,'rotulo','Participantes','obrigatoria',true),
        jsonb_build_object('chave','quorum_e_abertura','ordem',3,'rotulo','Quórum e abertura','obrigatoria',true),
        jsonb_build_object('chave','aprovacao_ata_anterior','ordem',4,'rotulo','Aprovação da ata anterior','obrigatoria',true),
        jsonb_build_object('chave','pauta','ordem',5,'rotulo','Pauta','obrigatoria',true),
        jsonb_build_object('chave','contexto_e_cenario','ordem',6,'rotulo','Contexto e cenário','obrigatoria',false),
        jsonb_build_object('chave','indicadores_do_periodo','ordem',7,'rotulo','Indicadores do período','obrigatoria',false),
        jsonb_build_object('chave','highlights','ordem',8,'rotulo','Highlights','obrigatoria',false),
        jsonb_build_object('chave','lowlights','ordem',9,'rotulo','Lowlights','obrigatoria',false),
        jsonb_build_object('chave','resumo_discussoes','ordem',10,'rotulo','Resumo das discussões','obrigatoria',true),
        jsonb_build_object('chave','deliberacoes','ordem',11,'rotulo','Deliberações','obrigatoria',true),
        jsonb_build_object('chave','riscos_e_mitigacoes','ordem',12,'rotulo','Riscos e mitigações','obrigatoria',false),
        jsonb_build_object('chave','metas_e_prioridades','ordem',13,'rotulo','Metas e prioridades','obrigatoria',false),
        jsonb_build_object('chave','proximos_passos','ordem',14,'rotulo','Próximos passos','obrigatoria',true),
        jsonb_build_object('chave','insight_conselho','ordem',15,'rotulo','Insight do conselho','obrigatoria',false),
        jsonb_build_object('chave','proxima_reuniao','ordem',16,'rotulo','Próxima reunião com pré-pauta','obrigatoria',true)
      )
    ),
    'Extensão opcional, ligada por cliente em valor.modelos_ata_por_conta.'
  )
  on conflict (inquilino_id, codigo, versao) do nothing;

  get diagnostics inseridos = row_count;
  return inseridos;
end;
$$;

comment on function valor.semear_modelos_ata(uuid) is
  'Semeia o padrão de sete seções e a extensão de 16 blocos para um inquilino. Idempotente.';

create or replace function valor.semear_banco_pautas(alvo_inquilino uuid)
returns integer language plpgsql as $$
declare
  inseridos integer;
begin
  insert into valor.banco_pautas (
    inquilino_id, familia, codigo, tema, descricao,
    perguntas_orientadoras, tipo_sugerido, tempo_sugerido_minutos, ordem
  )
  select
    alvo_inquilino, t.familia::valor.pauta_familia, t.codigo, t.tema, t.descricao,
    to_jsonb(t.perguntas), t.tipo::valor.pauta_item_tipo, t.minutos::smallint, t.ordem::smallint
  from (values
    ('governanca','GOV01','Propósito, missão, visão e valores',
     'O porquê da empresa e o que ela não abre mão.',
     array['O propósito está escrito e é o mesmo na boca de cada sócio?','Que decisão recente contrariou algum valor declarado?'],'consultivo',30,1),
    ('governanca','GOV02','Acordo de sócios e regras da sociedade',
     'Direitos, deveres, dedicação, remuneração e saída.',
     array['O acordo cobre entrada, saída e impasse?','Quem decide o que, e com que maioria?'],'deliberativo',45,2),
    ('governanca','GOV03','Estrutura e funcionamento do conselho',
     'Composição, cadência, pauta e prestação de contas do conselho.',
     array['O conselho é consultivo ou de administração?','A cadência atual dá tempo de acompanhar as decisões?'],'deliberativo',40,3),
    ('governanca','GOV04','Alçadas e processo de decisão',
     'Quem decide até que valor e a partir de quando sobe para o conselho.',
     array['Qual decisão hoje trava por falta de alçada clara?','O que já foi decidido fora da alçada e por quê?'],'deliberativo',40,4),
    ('governanca','GOV05','Estratégia de longo prazo e sua revisão',
     'Onde a empresa quer chegar e com que frequência revisa o caminho.',
     array['A estratégia de três anos cabe no caixa de doze meses?','O que mudou no mercado desde a última revisão?'],'consultivo',45,5),
    ('governanca','GOV06','Modelo de negócio e proposta de valor',
     'Como a empresa cria, entrega e captura valor.',
     array['Para quem a proposta de valor é óbvia, e para quem ainda não é?','Que parte do modelo depende de uma pessoa só?'],'consultivo',40,6),
    ('governanca','GOV07','Indicadores, metas e prestação de contas',
     'O painel do conselho e o ritmo de cobrança.',
     array['Quais são os cinco números que o conselho acompanha?','Quem responde por cada número, com nome e prazo?'],'deliberativo',40,7),
    ('governanca','GOV08','Gestão financeira e estrutura de capital',
     'Caixa, margem, endividamento e necessidade de aporte.',
     array['Quantos meses de caixa a empresa tem no cenário pessimista?','Que dívida vence nos próximos doze meses?'],'deliberativo',45,8),
    ('governanca','GOV09','Riscos, controles e continuidade',
     'O mapa de riscos e o plano de continuidade do negócio.',
     array['Qual risco derruba a operação em uma semana?','Que controle existe hoje e quem testa esse controle?'],'deliberativo',40,9),
    ('governanca','GOV10','Conformidade legal, fiscal e regulatória',
     'Obrigações, licenças, contratos e passivos.',
     array['Que obrigação está vencida ou perto de vencer?','Qual passivo não está provisionado?'],'informativo',30,10),
    ('governanca','GOV11','Ética, conduta e canal de denúncia',
     'O código de conduta e o caminho seguro para reportar desvio.',
     array['O canal de denúncia existe, funciona e é conhecido?','Que caso foi tratado no período e como terminou?'],'consultivo',30,11),
    ('governanca','GOV12','Pessoas, liderança e sucessão',
     'Time-chave, retenção, desenvolvimento e plano de sucessão.',
     array['Quem substitui cada posição crítica amanhã?','Que líder está pronto para o próximo degrau?'],'consultivo',45,12),
    ('governanca','GOV13','Propriedade intelectual e ativos',
     'Titularidade da marca, do software, das bases e dos contratos.',
     array['A propriedade intelectual está no nome da empresa?','Que ativo está registrado em nome de pessoa física?'],'deliberativo',30,13),
    ('governanca','GOV14','Marca, comunicação e reputação',
     'Como a empresa é vista e como responde quando é mal vista.',
     array['Que promessa a marca faz e a operação não cumpre?','Existe protocolo para crise de reputação?'],'consultivo',30,14),
    ('governanca','GOV15','Crescimento, expansão e novos mercados',
     'Onde crescer, com que capital e em que ordem.',
     array['Qual a próxima fronteira e por que agora?','O que precisa estar pronto antes de escalar?'],'deliberativo',45,15),
    ('gestao','GES01','Estratégia e mercado',
     'Família de gestão: posicionamento, concorrência e escolhas de onde competir.',
     array['Que escolha estratégica ainda não foi feita?','Quem é o concorrente que mais incomoda e por quê?'],'consultivo',40,21),
    ('gestao','GES02','Processos e operação',
     'Família de gestão: desenho, padronização e produtividade da operação.',
     array['Qual processo quebra quando o volume dobra?','O que é feito à mão e deveria ser sistema?'],'deliberativo',40,22),
    ('gestao','GES03','Pessoas e cultura',
     'Família de gestão: estrutura, papéis, avaliação e cultura.',
     array['A estrutura atual sustenta a meta do ano?','Que comportamento a cultura premia sem querer?'],'consultivo',40,23),
    ('gestao','GES04','Finanças e resultado',
     'Família de gestão: precificação, custo, margem e capital de giro.',
     array['Que produto ou cliente destrói margem?','O preço acompanhou o custo no último ano?'],'deliberativo',40,24),
    ('gestao','GES05','Clientes e receita',
     'Família de gestão: funil, carteira, retenção e expansão de receita.',
     array['Qual a receita recorrente em risco nos próximos noventa dias?','Que cliente cresce e ninguém percebeu?'],'deliberativo',40,25),
    ('gestao','GES06','Inovação e tecnologia',
     'Família de gestão: produto, dados, automação e adoção de tecnologia.',
     array['Que aposta de inovação está sem dono?','Onde a tecnologia hoje custa mais do que devolve?'],'consultivo',40,26)
  ) as t(familia, codigo, tema, descricao, perguntas, tipo, minutos, ordem)
  on conflict (inquilino_id, codigo) do nothing;

  get diagnostics inseridos = row_count;
  return inseridos;
end;
$$;

comment on function valor.semear_banco_pautas(uuid) is
  'Semeia os 15 temas de governança e as 6 famílias de gestão do método para um inquilino. Idempotente.';

-- ---------------------------------------------------------------- visões de apoio

-- A fila de envio: ata aprovada, não restrita e ainda não enviada.
create view valor.atas_para_envio
  with (security_invoker = true) as
select
  a.id,
  a.inquilino_id,
  a.conta_id,
  a.numero,
  a.data_reuniao,
  a.status,
  a.prazo_envio,
  a.destinatarios,
  a.arquivo_pdf_url,
  a.arquivo_docx_url
from valor.atas a
where a.arquivado_em is null
  and not a.restrita
  and a.status = 'aprovada';

comment on view valor.atas_para_envio is
  'Fila de envio da ata. Ata restrita nunca aparece aqui, por regra do banco.';

-- O alerta de 24 horas do rito.
create view valor.atas_atrasadas
  with (security_invoker = true) as
select
  a.id,
  a.inquilino_id,
  a.conta_id,
  a.numero,
  a.data_reuniao,
  a.status,
  a.prazo_envio,
  a.restrita,
  greatest(0, extract(epoch from (now() - a.prazo_envio)) / 3600.0)::numeric(10,1) as horas_de_atraso,
  case
    when a.restrita then 'ata restrita, não sai por envio, precisa de tratativa do líder'
    when a.status = 'rascunho' then 'o assessor ainda não fechou a ata'
    when a.status = 'em_aprovacao' then 'aguardando a aprovação do conselheiro'
    else 'aprovada e ainda não enviada'
  end as motivo
from valor.atas a
where a.arquivado_em is null
  and a.status <> 'enviada'
  and now() > a.prazo_envio;

comment on view valor.atas_atrasadas is
  'Alerta do rito: a ata precisa sair em 24 horas depois da reunião.';

-- Pendências que continuam cobrando, com o atraso já calculado.
create view valor.pendencias_abertas
  with (security_invoker = true) as
select
  p.id,
  p.inquilino_id,
  p.conta_id,
  p.turma_id,
  p.ata_id,
  p.descricao,
  coalesce(u.nome, p.dono_nome) as dono,
  p.prazo,
  p.status,
  case
    when p.prazo is null then 'sem prazo definido'
    when p.prazo < current_date then 'atrasada'
    else 'no prazo'
  end as situacao,
  case when p.prazo is null then null else current_date - p.prazo end as dias_de_atraso
from valor.pendencias p
left join valor.usuarios u on u.id = p.dono_usuario_id
where p.arquivado_em is null
  and p.status in ('aberta', 'em_andamento');

comment on view valor.pendencias_abertas is
  'O que continua em aberto, com dono, prazo e atraso. Alimenta a pré-pauta e o painel do conselheiro.';

-- ---------------------------------------------------------------- carimbos e guardas

create trigger carimbo before update on valor.modelos_ata for each row execute function valor.carimbar();
create trigger carimbo before update on valor.modelos_ata_por_conta for each row execute function valor.carimbar();
create trigger carimbo before update on valor.banco_pautas for each row execute function valor.carimbar();
create trigger carimbo before update on valor.pautas for each row execute function valor.carimbar();
create trigger carimbo before update on valor.pautas_itens for each row execute function valor.carimbar();
create trigger carimbo before update on valor.atas for each row execute function valor.carimbar();
create trigger carimbo before update on valor.pendencias for each row execute function valor.carimbar();

create trigger sem_remocao before delete on valor.modelos_ata for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.modelos_ata_por_conta for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.banco_pautas for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.pautas for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.pautas_itens for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.atas for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.pendencias for each statement execute function valor.impedir_remocao();

-- ---------------------------------------------------------------- segurança

alter table valor.modelos_ata           enable row level security;
alter table valor.modelos_ata_por_conta enable row level security;
alter table valor.banco_pautas          enable row level security;
alter table valor.pautas                enable row level security;
alter table valor.pautas_itens          enable row level security;
alter table valor.atas                  enable row level security;
alter table valor.pendencias            enable row level security;

-- Nenhuma tabela deste arquivo recebe política de remoção. Sem política, o delete
-- não passa pela segurança de linha. O gatilho sem_remocao fecha o resto.

-- O perfil participante é a pessoa do cliente que ocupa cadeira na turma. Ele não
-- é do time da casa: não escreve nada do rito e só lê o que é da turma dele.
-- Sem este predicado, toda política que dizia apenas "não é parceiro" passaria a
-- entregar o material interno da casa ao primeiro empresário que fizesse login.
-- Não lê tabela nenhuma, então nunca pode causar recursão em política.


-- Diz se a ata de origem de uma pendência é restrita, sem passar pela segurança
-- de linha da própria ata. É security definer de propósito: se lesse a ata pela
-- visão do leitor, a ata restrita ficaria invisível, o exists daria falso e a
-- pendência vazaria justamente no caso que queremos barrar.
-- Não há recursão: esta função lê valor.atas e é usada só na política de
-- valor.pendencias, nunca numa política de valor.atas.
create or replace function valor.gov_ata_restrita(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, public as $$
  select coalesce((select a.restrita from valor.atas a where a.id = alvo), false);
$$;

comment on function valor.gov_ata_restrita(uuid) is
  'Se a ata de origem é restrita. Usada para impedir que a pendência nascida de reunião sobre pessoas do cliente chegue a quem só ocupa cadeira.';

-- ------------------------------------------------- material interno da casa
-- Modelo de ata, escolha por cliente, banco de pautas e itens de pauta são
-- preparação interna. Nem parceiro nem participante alcançam.

create policy modelo_ata_le on valor.modelos_ata for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy modelo_ata_insere on valor.modelos_ata for insert
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());
create policy modelo_ata_atualiza on valor.modelos_ata for update
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy modelo_conta_le on valor.modelos_ata_por_conta for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy modelo_conta_insere on valor.modelos_ata_por_conta for insert
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());
create policy modelo_conta_atualiza on valor.modelos_ata_por_conta for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

create policy banco_pauta_le on valor.banco_pautas for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy banco_pauta_insere on valor.banco_pautas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy banco_pauta_atualiza on valor.banco_pautas for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

-- O item de pauta carrega origem, vínculo com pendência e responsável interno.
-- É a cozinha da reunião, e não tem turma_id para ancorar, então fecha por perfil.
create policy pauta_item_le on valor.pautas_itens for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy pauta_item_insere on valor.pautas_itens for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy pauta_item_atualiza on valor.pautas_itens for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

-- ------------------------------------------------- o rito, ancorado na turma
-- O participante lê a pauta, a ata e as pendências da turma dele, e nada mais.
-- Quem não tem turma na linha é material sem cadeira, e aí só o time da casa lê.

create policy pauta_le on valor.pautas for select
  using (
    valor.do_inquilino(inquilino_id)
    and not valor.eh_parceiro()
    and (
      valor.time_da_casa()
      or (turma_id is not null and valor.brm_turma_visivel(turma_id))
    )
  );
create policy pauta_insere on valor.pautas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy pauta_atualiza on valor.pautas for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

-- A ata nunca chega ao parceiro. A ata restrita só é lida por quem vê
-- confidencial e por quem escreveu ou aprovou aquela ata. O participante lê a
-- ata não restrita da turma dele, que é o direito de quem ocupa cadeira, e a
-- cláusula de brm_so_participante espelha o que a 0008 faz em encontro_le.
create policy ata_le on valor.atas for select
  using (
    valor.do_inquilino(inquilino_id)
    and not valor.eh_parceiro()
    and (
      not restrita
      or valor.ve_confidencial()
      or valor.usuario_atual() = escrita_por
      or valor.usuario_atual() = aprovada_por
    )
    and (not restrita or not valor.brm_so_participante(turma_id))
    and (
      valor.time_da_casa()
      or (turma_id is not null and valor.brm_turma_visivel(turma_id) and not restrita)
    )
  );
create policy ata_insere on valor.atas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy ata_atualiza on valor.atas for update
  using (
    valor.do_inquilino(inquilino_id)
    and valor.time_da_casa()
    and (
      not restrita
      or valor.ve_confidencial()
      or valor.usuario_atual() = escrita_por
      or valor.usuario_atual() = aprovada_por
    )
  )
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

-- A pendência é do rito interno e do cliente, nunca do parceiro. O participante
-- vê o que ficou em aberto na turma dele, menos o que nasceu de ata restrita.
create policy pendencia_le on valor.pendencias for select
  using (
    valor.do_inquilino(inquilino_id)
    and not valor.eh_parceiro()
    and (not valor.brm_so_participante(turma_id) or not valor.gov_ata_restrita(ata_id))
    and (
      valor.time_da_casa()
      or (turma_id is not null
          and valor.brm_turma_visivel(turma_id)
          and not valor.gov_ata_restrita(ata_id))
    )
  );
create policy pendencia_insere on valor.pendencias for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy pendencia_atualiza on valor.pendencias for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
