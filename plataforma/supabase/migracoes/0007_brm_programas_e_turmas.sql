-- 0007 · BRM de Valor: programas, turmas, participantes e contas na turma
-- Dono: engenheiro de BRM. Nenhum outro agente altera este arquivo.
--
-- Depende apenas de 0001, 0002 e 0003. Não depende de 0004, 0005 nem 0006.
--
-- A coluna contrato_id nasce sem chave estrangeira, no mesmo padrão que
-- negocios.parceiro_id usa em 0003. A migração que criar valor.contratos
-- acrescenta a restrição depois. A Felix pode rodar uma turma antes de o
-- contrato estar assinado, então o vínculo é opcional por desenho.
--
-- Nada é apagado. Remover é preencher arquivado_em. Por isso nenhuma tabela
-- deste arquivo ganha política for delete: o comando fica sem linha alcançável.

-- ------------------------------------------------------------ tipos do BRM

create type valor.brm_modalidade_turma as enum ('dedicada', 'compartilhada');

create type valor.brm_status_programa as enum (
  'planejado', 'ativo', 'suspenso', 'concluido', 'cancelado'
);

create type valor.brm_status_turma as enum (
  'planejada', 'em_andamento', 'suspensa', 'concluida', 'cancelada'
);

create type valor.brm_cadencia as enum (
  'semanal', 'quinzenal', 'mensal', 'bimestral', 'trimestral',
  'modular', 'imersao', 'sob_demanda'
);

create type valor.brm_formato_encontro as enum ('presencial', 'online', 'hibrido');

create type valor.brm_papel_participante as enum (
  'membro', 'socio', 'executivo', 'convidado', 'observador'
);

create type valor.brm_status_participante as enum (
  'ativo', 'pausado', 'concluido', 'desligado'
);

-- ------------------------------------------------------- calendário de turma

-- Chave de dia no ano, no formato mês vezes cem mais dia. Serve para comparar
-- uma data com uma janela que atravessa a virada do ano.
create or replace function valor.brm_chave_dia(p_data date) returns integer
language sql immutable as $$
  select (extract(month from p_data) * 100 + extract(day from p_data))::integer;
$$;

-- O recesso do conselho vai de meados de dezembro a meados de janeiro, ou seja,
-- atravessa a virada do ano. A janela é lida por dia e mês, nunca por ano.
create or replace function valor.brm_em_recesso(
  p_data date, p_recesso_inicio date, p_recesso_fim date
) returns boolean
language sql immutable as $$
  select case
    when p_recesso_inicio is null or p_recesso_fim is null then false
    when valor.brm_chave_dia(p_recesso_inicio) <= valor.brm_chave_dia(p_recesso_fim)
      then valor.brm_chave_dia(p_data)
             between valor.brm_chave_dia(p_recesso_inicio)
                 and valor.brm_chave_dia(p_recesso_fim)
    else valor.brm_chave_dia(p_data) >= valor.brm_chave_dia(p_recesso_inicio)
      or valor.brm_chave_dia(p_data) <= valor.brm_chave_dia(p_recesso_fim)
  end;
$$;

comment on function valor.brm_em_recesso(date, date, date) is
  'Verdadeiro quando a data cai no recesso da turma. A janela atravessa a virada do ano.';

-- Gera o calendário base de uma turma pulando o recesso. Quarenta e oito
-- reuniões semanais com recesso de meados de dezembro a meados de janeiro
-- cabem em um ano civil sem perder nenhuma data.
create or replace function valor.brm_calendario_turma(
  p_inicio          date,
  p_quantidade      integer,
  p_cadencia        valor.brm_cadencia default 'semanal',
  p_recesso_inicio  date default null,
  p_recesso_fim     date default null
) returns setof date
language plpgsql immutable as $$
declare
  v_passo   interval;
  v_data    date := p_inicio;
  v_geradas integer := 0;
  v_voltas  integer := 0;
begin
  v_passo := case p_cadencia
    when 'semanal'    then interval '7 days'
    when 'quinzenal'  then interval '14 days'
    when 'mensal'     then interval '1 month'
    when 'bimestral'  then interval '2 months'
    when 'trimestral' then interval '3 months'
    when 'imersao'    then interval '1 day'
    else interval '7 days'
  end;

  while v_geradas < p_quantidade and v_voltas < 5000 loop
    v_voltas := v_voltas + 1;
    if valor.brm_em_recesso(v_data, p_recesso_inicio, p_recesso_fim) then
      v_data := (v_data + v_passo)::date;
      continue;
    end if;
    return next v_data;
    v_geradas := v_geradas + 1;
    v_data := (v_data + v_passo)::date;
  end loop;
end;
$$;

comment on function valor.brm_calendario_turma(date, integer, valor.brm_cadencia, date, date) is
  'Calendário base da turma na cadência informada, saltando as datas do recesso.';

-- ------------------------------------------------------------------ programas

-- A instância vendida de uma oferta do portfólio. Uma venda gera um contrato,
-- o contrato gera um programa, o programa gera uma ou mais turmas.
create table valor.programas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  oferta_id      uuid references valor.ofertas(id) on delete restrict,
  contrato_id    uuid,
  negocio_id     uuid references valor.negocios(id) on delete restrict,
  conta_id       uuid references valor.contas(id) on delete restrict,
  codigo         text not null,
  nome           text not null,
  ano            smallint not null default extract(year from current_date)
                   check (ano between 2000 and 2100),
  modalidade     valor.brm_modalidade_turma not null,
  status         valor.brm_status_programa not null default 'planejado',
  responsavel_id uuid references valor.usuarios(id) on delete restrict,
  data_inicio    date,
  data_fim       date,
  -- carga oficial da oferta, como está no catálogo da casa
  cadencia                 valor.brm_cadencia not null default 'semanal',
  encontros_previstos      smallint check (encontros_previstos >= 0),
  duracao_encontro_minutos smallint check (duracao_encontro_minutos >= 0),
  semanas_sustentacao      smallint check (semanas_sustentacao >= 0),
  dias_imersao             smallint check (dias_imersao >= 0),
  modulos_previstos        smallint check (modulos_previstos >= 0),
  temas_previstos          smallint check (temas_previstos >= 0),
  etapas_previstas         smallint check (etapas_previstas >= 0),
  meses_duracao            smallint check (meses_duracao >= 0),
  presenciais_por_mes      smallint not null default 0 check (presenciais_por_mes >= 0),
  estacoes_plano           smallint check (estacoes_plano >= 0),
  encontro_gestao_semanal  boolean not null default false,
  pauta_prioritaria_mensal boolean not null default false,
  hotseat_por_membro       boolean not null default false,
  resumo_semanal           boolean not null default false,
  deep_dive_mensal         boolean not null default false,
  plano_por_participante   boolean not null default false,
  certificacao             boolean not null default false,
  marcos_indice            text[] not null default '{}',
  carga_extra              jsonb not null default '{}',
  observacoes    text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, codigo),
  check (data_fim is null or data_inicio is null or data_fim >= data_inicio)
);

comment on table valor.programas is
  'A instância vendida de uma oferta do portfólio, para um ano e uma modalidade.';
comment on column valor.programas.contrato_id is
  'Contrato de origem. Fica sem chave estrangeira até valor.contratos existir. Nulo enquanto a turma roda antes da assinatura.';
comment on column valor.programas.negocio_id is
  'Negócio de origem no funil. Opcional: a turma pode começar antes de o negócio virar contrato.';
comment on column valor.programas.conta_id is
  'Preenchida na modalidade dedicada. Na compartilhada as contas vivem em valor.turmas_contas.';
comment on column valor.programas.modalidade is
  'Dedicada quando o programa é de um único cliente. Compartilhada quando reúne contas diferentes.';
comment on column valor.programas.responsavel_id is
  'O conselheiro ou facilitador responsável pela entrega do programa.';
comment on column valor.programas.encontros_previstos is
  'Carga oficial: 48 no conselho anual, 12 no Negócios de Valor, 10 na variante, 12 na Mesa do CEO.';
comment on column valor.programas.duracao_encontro_minutos is
  'Carga oficial: 150 para o encontro de 2h30, 120 para o encontro quinzenal de 2h.';
comment on column valor.programas.semanas_sustentacao is
  'Carga oficial: 8 semanas de sustentação do Negócios de Valor.';
comment on column valor.programas.dias_imersao is
  'Carga oficial: imersão de 3 dias do Negócios de Valor, workshop de 2 dias da Liderança de Valor.';
comment on column valor.programas.modulos_previstos is
  'Carga oficial: 8 módulos na Liderança de Valor, 6 módulos na Gestão de Valor.';
comment on column valor.programas.temas_previstos is
  'Carga oficial: 48 temas da Gestão de Valor.';
comment on column valor.programas.etapas_previstas is
  'Carga oficial: 12 etapas da Mesa do CEO, no Executivo de Valor.';
comment on column valor.programas.estacoes_plano is
  'Carga oficial: as 4 estações do plano da Mentoria de Valor.';
comment on column valor.programas.marcos_indice is
  'Marcos de medição do índice próprio do programa, por exemplo T0, T90 e T180.';
comment on column valor.programas.carga_extra is
  'Sobras da carga oficial que não têm coluna própria, para não inventar coluna a cada oferta nova.';
comment on column valor.programas.observacoes is
  'CONFIDENCIAL: equipe de entrega da casa, ou seja, administrador, líder, conselheiro e assessor. Pode conter anotação sobre gente do cliente.';

-- --------------------------------------------------------------------- turmas

-- O grupo que percorre o programa. Uma turma dedicada tem uma conta. Uma turma
-- compartilhada tem contas diferentes, cada uma com as cadeiras que contratou.
create table valor.turmas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  programa_id    uuid not null references valor.programas(id) on delete restrict,
  contrato_id    uuid,
  negocio_id     uuid references valor.negocios(id) on delete restrict,
  codigo         text not null,
  nome           text,
  cadeiras_minimas smallint not null default 1 check (cadeiras_minimas >= 1),
  cadeiras_maximas smallint not null default 8 check (cadeiras_maximas >= 1),
  data_inicio    date,
  data_fim       date,
  status         valor.brm_status_turma not null default 'planejada',
  -- calendário base
  cadencia          valor.brm_cadencia not null default 'semanal',
  formato           valor.brm_formato_encontro not null default 'online',
  dia_semana        smallint check (dia_semana between 0 and 6),
  horario_inicio    time,
  horario_fim       time,
  encontros_previstos smallint check (encontros_previstos >= 0),
  recesso_inicio    date,
  recesso_fim       date,
  calendario_base   date[] not null default '{}',
  facilitador_id uuid references valor.usuarios(id) on delete restrict,
  coordenador_id uuid references valor.usuarios(id) on delete restrict,
  observacoes    text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, codigo),
  check (cadeiras_maximas >= cadeiras_minimas),
  check (data_fim is null or data_inicio is null or data_fim >= data_inicio),
  check ((recesso_inicio is null) = (recesso_fim is null)),
  check (horario_fim is null or horario_inicio is null or horario_fim > horario_inicio)
);

comment on table valor.turmas is
  'O grupo que percorre o programa, com cadeiras, calendário base e condução.';
comment on column valor.turmas.contrato_id is
  'Contrato de origem. Fica sem chave estrangeira até valor.contratos existir. Nulo quando a turma começa antes da assinatura.';
comment on column valor.turmas.negocio_id is
  'Negócio de origem no funil, quando houver.';
comment on column valor.turmas.cadeiras_minimas is
  'Piso de cadeiras ocupadas para a turma começar. Conferido quando o status vira em_andamento.';
comment on column valor.turmas.cadeiras_maximas is
  'Teto de cadeiras ocupadas, por exemplo 8 no conselho compartilhado e 16 no Negócios de Valor.';
comment on column valor.turmas.recesso_inicio is
  'Início do recesso da turma. No conselho é meados de dezembro. O ano da data é ignorado na comparação.';
comment on column valor.turmas.recesso_fim is
  'Fim do recesso da turma. No conselho é meados de janeiro. O ano da data é ignorado na comparação.';
comment on column valor.turmas.calendario_base is
  'Datas previstas da turma. Montadas por valor.brm_calendario_turma, que já salta o recesso.';
comment on column valor.turmas.observacoes is
  'CONFIDENCIAL: equipe de entrega da casa. Pode conter anotação sobre gente do cliente.';

-- -------------------------------------------------------------- turmas_contas

-- Quais contas estão na turma e quantas cadeiras cada uma contratou. É esta
-- tabela que resolve a turma compartilhada sem gambiarra.
create table valor.turmas_contas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  turma_id       uuid not null references valor.turmas(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  contrato_id    uuid,
  negocio_id     uuid references valor.negocios(id) on delete restrict,
  cadeiras_contratadas smallint not null default 1 check (cadeiras_contratadas >= 1),
  eh_anfitria    boolean not null default false,
  entrou_em      date not null default current_date,
  saiu_em        date,
  observacoes    text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, turma_id, conta_id),
  check (saiu_em is null or saiu_em >= entrou_em)
);

comment on table valor.turmas_contas is
  'As contas presentes na turma, com as cadeiras que cada uma contratou.';
comment on column valor.turmas_contas.contrato_id is
  'Contrato da conta nesta turma. Sem chave estrangeira até valor.contratos existir.';
comment on column valor.turmas_contas.eh_anfitria is
  'Marca a conta anfitriã. Na turma dedicada é a única conta presente.';
comment on column valor.turmas_contas.cadeiras_contratadas is
  'Quantas cadeiras desta turma pertencem à conta. No conselho compartilhado costuma ser uma.';
comment on column valor.turmas_contas.observacoes is
  'CONFIDENCIAL: equipe de entrega da casa. Pode conter anotação sobre gente do cliente.';

-- --------------------------------------------------------------- participantes

-- A pessoa na cadeira. Quando é gente de conta cliente, aponta para
-- valor.contatos. Quando é convidado de fora, basta o nome.
create table valor.participantes (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  turma_id       uuid not null references valor.turmas(id) on delete restrict,
  conta_id       uuid references valor.contas(id) on delete restrict,
  contato_id     uuid references valor.contatos(id) on delete restrict,
  usuario_id     uuid references valor.usuarios(id) on delete restrict,
  contrato_id    uuid,
  nome           text,
  papel          valor.brm_papel_participante not null default 'membro',
  cadeira        smallint check (cadeira >= 1),
  entrou_em      date not null default current_date,
  saiu_em        date,
  motivo_saida   text,
  status         valor.brm_status_participante not null default 'ativo',
  encontros_convocados smallint not null default 0 check (encontros_convocados >= 0),
  encontros_presentes  smallint not null default 0 check (encontros_presentes >= 0),
  presenca_percentual  numeric(6,4) generated always as (
    case when encontros_convocados > 0
         then round(encontros_presentes::numeric / encontros_convocados::numeric, 4)
         else null end
  ) stored,
  indices        jsonb not null default '{}',
  certificado_em date,
  certificado_url text,
  observacoes    text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  check (contato_id is not null or nome is not null),
  check (status <> 'desligado' or saiu_em is not null),
  check (saiu_em is null or saiu_em >= entrou_em),
  check (encontros_presentes <= encontros_convocados)
);

comment on table valor.participantes is
  'A pessoa na cadeira da turma, com papel, presença acumulada e situação.';
comment on column valor.participantes.contato_id is
  'Aponta para valor.contatos quando a pessoa é de conta cliente. Nulo para convidado de fora.';
comment on column valor.participantes.usuario_id is
  'Preenchida quando a pessoa ganha login. É por aqui que a política de linha reconhece o participante.';
comment on column valor.participantes.contrato_id is
  'Contrato por participante, usado na turma compartilhada. Sem chave estrangeira até valor.contratos existir.';
comment on column valor.participantes.cadeira is
  'Número da cadeira na turma. Uma cadeira viva por pessoa, garantido por índice único parcial.';
comment on column valor.participantes.presenca_percentual is
  'Presença acumulada, de 0 a 1. Recalculada pelo gatilho de presença da migração 0008.';
comment on column valor.participantes.indices is
  'CONFIDENCIAL: o próprio participante, o conselheiro da turma e a liderança da casa. Índice próprio do programa em T0, T90 e T180. É avaliação de pessoa.';
comment on column valor.participantes.motivo_saida is
  'CONFIDENCIAL: equipe de entrega da casa. Anotação sobre gente do cliente.';
comment on column valor.participantes.observacoes is
  'CONFIDENCIAL: equipe de entrega da casa. Anotação sobre gente do cliente.';

-- --------------------------------------------------------------- integridade

-- Uma cadeira ocupada por pessoa, dentro da turma.
create unique index participante_cadeira_viva
  on valor.participantes (turma_id, cadeira)
  where cadeira is not null and status <> 'desligado' and arquivado_em is null;

create unique index participante_contato_unico
  on valor.participantes (turma_id, contato_id)
  where contato_id is not null and arquivado_em is null;

-- Contagem de cadeiras contra a capacidade da turma e contra as cadeiras que
-- cada conta contratou. A restrição vive aqui, no banco, não na interface.
create or replace function valor.brm_valida_cadeiras() returns trigger
language plpgsql security definer set search_path = valor, public as $$
declare
  v_turma       uuid;
  v_maximas     smallint;
  v_modalidade  valor.brm_modalidade_turma;
  v_codigo      text;
  v_ocupadas    integer;
  v_contas      integer;
  v_excedida    record;
begin
  v_turma := coalesce(new.turma_id, old.turma_id);

  select t.cadeiras_maximas, t.codigo, p.modalidade
    into v_maximas, v_codigo, v_modalidade
  from valor.turmas t
  join valor.programas p on p.id = t.programa_id
  where t.id = v_turma;

  if v_maximas is null then
    return null;
  end if;

  select count(*) into v_ocupadas
  from valor.participantes pa
  where pa.turma_id = v_turma
    and pa.status <> 'desligado'
    and pa.arquivado_em is null;

  if v_ocupadas > v_maximas then
    raise exception 'A turma % tem % cadeiras ocupadas e o teto é %.',
      v_codigo, v_ocupadas, v_maximas using errcode = '23514';
  end if;

  select count(*) into v_contas
  from valor.turmas_contas tc
  where tc.turma_id = v_turma and tc.arquivado_em is null;

  if v_modalidade = 'dedicada' and v_contas > 1 then
    raise exception 'A turma % é dedicada e aceita uma única conta. Foram encontradas %.',
      v_codigo, v_contas using errcode = '23514';
  end if;

  for v_excedida in
    select tc.conta_id, tc.cadeiras_contratadas,
           count(pa.id) filter (where pa.id is not null) as ocupadas
    from valor.turmas_contas tc
    left join valor.participantes pa
      on pa.turma_id = tc.turma_id
     and pa.conta_id = tc.conta_id
     and pa.status <> 'desligado'
     and pa.arquivado_em is null
    where tc.turma_id = v_turma and tc.arquivado_em is null
    group by tc.conta_id, tc.cadeiras_contratadas
    having count(pa.id) filter (where pa.id is not null) > tc.cadeiras_contratadas
  loop
    raise exception 'Na turma % a conta % ocupa % cadeiras e contratou %.',
      v_codigo, v_excedida.conta_id, v_excedida.ocupadas, v_excedida.cadeiras_contratadas
      using errcode = '23514';
  end loop;

  if exists (
    select 1
    from valor.participantes pa
    where pa.turma_id = v_turma
      and pa.conta_id is not null
      and pa.status <> 'desligado'
      and pa.arquivado_em is null
      and not exists (
        select 1 from valor.turmas_contas tc
        where tc.turma_id = v_turma
          and tc.conta_id = pa.conta_id
          and tc.arquivado_em is null
      )
  ) then
    raise exception 'A turma % tem participante de conta que não está em valor.turmas_contas.',
      v_codigo using errcode = '23514';
  end if;

  return null;
end;
$$;

comment on function valor.brm_valida_cadeiras() is
  'Guarda a capacidade da turma, as cadeiras de cada conta e a regra de turma dedicada com uma conta só.';

create constraint trigger cadeiras_do_participante
  after insert or update on valor.participantes
  deferrable initially deferred
  for each row execute function valor.brm_valida_cadeiras();

create constraint trigger cadeiras_da_conta
  after insert or update on valor.turmas_contas
  deferrable initially deferred
  for each row execute function valor.brm_valida_cadeiras();

-- O piso de cadeiras vale no momento de começar, não no momento de montar.
create or replace function valor.brm_valida_inicio_turma() returns trigger
language plpgsql security definer set search_path = valor, public as $$
declare v_ocupadas integer;
begin
  if new.status = 'em_andamento' and old.status <> 'em_andamento' then
    select count(*) into v_ocupadas
    from valor.participantes pa
    where pa.turma_id = new.id
      and pa.status <> 'desligado'
      and pa.arquivado_em is null;

    if v_ocupadas < new.cadeiras_minimas then
      raise exception 'A turma % precisa de ao menos % cadeiras ocupadas para começar e tem %.',
        new.codigo, new.cadeiras_minimas, v_ocupadas using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger inicio_da_turma
  before update on valor.turmas
  for each row execute function valor.brm_valida_inicio_turma();

-- ------------------------------------------------------------------- índices

create index on valor.programas (inquilino_id, status) where arquivado_em is null;
create index on valor.programas (inquilino_id, ano, modalidade) where arquivado_em is null;
create index on valor.programas (responsavel_id) where arquivado_em is null;
create index on valor.programas (contrato_id) where contrato_id is not null;
create index on valor.turmas (programa_id, status) where arquivado_em is null;
create index on valor.turmas (inquilino_id, data_inicio) where arquivado_em is null;
create index on valor.turmas (facilitador_id) where arquivado_em is null;
create index on valor.turmas (contrato_id) where contrato_id is not null;
create index on valor.turmas_contas (turma_id) where arquivado_em is null;
create index on valor.turmas_contas (conta_id) where arquivado_em is null;
create index on valor.participantes (turma_id, status) where arquivado_em is null;
create index on valor.participantes (conta_id) where arquivado_em is null;
create index on valor.participantes (contato_id) where contato_id is not null;
create index on valor.participantes (usuario_id) where usuario_id is not null;

create trigger carimbo before update on valor.programas     for each row execute function valor.carimbar();
create trigger carimbo before update on valor.turmas        for each row execute function valor.carimbar();
create trigger carimbo before update on valor.turmas_contas for each row execute function valor.carimbar();
create trigger carimbo before update on valor.participantes for each row execute function valor.carimbar();

-- ------------------------------------------------------------------ segurança

-- Quem enxerga o BRM inteiro do inquilino.
create or replace function valor.brm_alcance_total() returns boolean
language sql stable as $$
  select valor.perfil_atual() in ('admin_master', 'emergencia', 'lider');
$$;

-- Quem escreve entrega: a casa que conduz. Financeiro, comercial e gerente de
-- contas leem o que alcançam, mas não escrevem no BRM. O parceiro fica fora.
create or replace function valor.brm_pode_escrever() returns boolean
language sql stable as $$
  select valor.perfil_atual() in
    ('admin_master', 'emergencia', 'lider', 'conselheiro', 'assessor');
$$;

-- As turmas em que o usuário da sessão está sentado como participante.
create or replace function valor.brm_turmas_do_participante() returns setof uuid
language sql stable security definer set search_path = valor, public as $$
  select pa.turma_id
  from valor.participantes pa
  where pa.usuario_id = valor.usuario_atual()
    and pa.inquilino_id = valor.inquilino_atual()
    and pa.arquivado_em is null;
$$;

-- Verdadeiro quando o usuário da sessão está sentado em alguma turma.
create or replace function valor.brm_sessao_eh_participante() returns boolean
language sql stable security definer set search_path = valor, public as $$
  select exists (
    select 1 from valor.participantes pa
    where pa.usuario_id = valor.usuario_atual()
      and pa.inquilino_id = valor.inquilino_atual()
      and pa.arquivado_em is null
  );
$$;

-- Quem é equipe da casa nesta turma: liderança, responsável do programa,
-- facilitador, coordenador, ou o gerente de contas de uma das contas.
create or replace function valor.brm_eh_equipe_da_turma(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, public as $$
  select alvo is not null
     and not valor.eh_parceiro()
     and (
       valor.brm_alcance_total()
       or exists (
         select 1 from valor.turmas t
         where t.id = alvo
           and t.inquilino_id = valor.inquilino_atual()
           and (t.facilitador_id = valor.usuario_atual()
                or t.coordenador_id = valor.usuario_atual())
       )
       or exists (
         select 1 from valor.turmas t
         join valor.programas p on p.id = t.programa_id
         where t.id = alvo
           and t.inquilino_id = valor.inquilino_atual()
           and p.responsavel_id = valor.usuario_atual()
       )
       or exists (
         select 1 from valor.turmas t
         join valor.programas p on p.id = t.programa_id
         join valor.papeis_negocio pn on pn.negocio_id = p.negocio_id
         where t.id = alvo
           and t.inquilino_id = valor.inquilino_atual()
           and pn.usuario_id = valor.usuario_atual()
           and pn.ativo
           and pn.arquivado_em is null
       )
       or exists (
         select 1 from valor.turmas_contas tc
         join valor.contas c on c.id = tc.conta_id
         where tc.turma_id = alvo
           and tc.arquivado_em is null
           and c.gerente_contas_id = valor.usuario_atual()
       )
     );
$$;

comment on function valor.brm_eh_equipe_da_turma(uuid) is
  'Quem tem papel de casa na turma. O conselheiro chega aqui como responsável do programa, facilitador, coordenador ou por papel no negócio.';

create or replace function valor.brm_programa_visivel(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, public as $$
  select not valor.eh_parceiro() and exists (
    select 1 from valor.programas p
    where p.id = alvo
      and p.inquilino_id = valor.inquilino_atual()
      and (
        valor.brm_alcance_total()
        or p.responsavel_id = valor.usuario_atual()
        or exists (select 1 from valor.contas c
                   where c.id = p.conta_id
                     and c.gerente_contas_id = valor.usuario_atual())
        or exists (select 1 from valor.papeis_negocio pn
                   where pn.negocio_id = p.negocio_id
                     and pn.usuario_id = valor.usuario_atual()
                     and pn.ativo and pn.arquivado_em is null)
        or exists (select 1 from valor.turmas t
                   where t.programa_id = p.id
                     and valor.brm_eh_equipe_da_turma(t.id))
        or exists (select 1 from valor.turmas t
                   where t.programa_id = p.id
                     and t.id in (select valor.brm_turmas_do_participante()))
      )
  );
$$;

create or replace function valor.brm_turma_visivel(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, public as $$
  select not valor.eh_parceiro() and exists (
    select 1 from valor.turmas t
    where t.id = alvo
      and t.inquilino_id = valor.inquilino_atual()
      and ( valor.brm_eh_equipe_da_turma(t.id)
            or t.id in (select valor.brm_turmas_do_participante())
            or valor.brm_programa_visivel(t.programa_id) )
  );
$$;

-- Verdadeiro quando o único vínculo da sessão com a turma é a cadeira. É este
-- predicado que limita o participante do cliente à própria turma.
create or replace function valor.brm_so_participante(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, public as $$
  select alvo is not null
     and alvo in (select valor.brm_turmas_do_participante())
     and not valor.brm_eh_equipe_da_turma(alvo);
$$;

alter table valor.programas     enable row level security;
alter table valor.turmas        enable row level security;
alter table valor.turmas_contas enable row level security;
alter table valor.participantes enable row level security;

-- O parceiro nunca enxerga nada de BRM. Aqui, e só aqui, a leitura abre com a
-- negativa `not valor.eh_parceiro()` em vez de `valor.time_da_casa()`, e é de
-- propósito: logo em seguida vem sempre um predicado positivo que ancora o
-- acesso, `brm_programa_visivel`, `brm_turma_visivel` ou a própria linha do
-- usuário. É esse predicado que deixa o participante do cliente entrar na turma
-- dele, que é o portal que a casa prometeu. Quem copiar esta forma para uma
-- tabela sem âncora abre a porta para todo perfil novo do enum, que foi
-- exatamente o defeito corrigido nas demais migrações.
-- Escrita é outra história: toda política de escrita deste arquivo passa por
-- `valor.brm_pode_escrever()`, que é lista de quem pode, e não negação.

create policy programa_le on valor.programas for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and valor.brm_programa_visivel(id));

create policy programa_insere on valor.programas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

create policy programa_atualiza on valor.programas for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_programa_visivel(id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

create policy turma_le on valor.turmas for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and valor.brm_turma_visivel(id));

create policy turma_insere on valor.turmas for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and valor.brm_programa_visivel(programa_id));

create policy turma_atualiza on valor.turmas for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_eh_equipe_da_turma(id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

create policy turma_conta_le on valor.turmas_contas for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and valor.brm_turma_visivel(turma_id));

create policy turma_conta_insere on valor.turmas_contas for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and valor.brm_eh_equipe_da_turma(turma_id));

create policy turma_conta_atualiza on valor.turmas_contas for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_eh_equipe_da_turma(turma_id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());

-- O participante do cliente enxerga a própria linha, e mais nada desta tabela.
create policy participante_le on valor.participantes for select
  using (valor.do_inquilino(inquilino_id)
         and not valor.eh_parceiro()
         and ( valor.brm_eh_equipe_da_turma(turma_id)
               or usuario_id = valor.usuario_atual() ));

create policy participante_insere on valor.participantes for insert
  with check (valor.do_inquilino(inquilino_id)
              and valor.brm_pode_escrever()
              and valor.brm_eh_equipe_da_turma(turma_id));

create policy participante_atualiza on valor.participantes for update
  using (valor.do_inquilino(inquilino_id)
         and valor.brm_pode_escrever()
         and valor.brm_eh_equipe_da_turma(turma_id))
  with check (valor.do_inquilino(inquilino_id) and valor.brm_pode_escrever());
