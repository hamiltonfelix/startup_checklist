-- 0011 · Atividades no método GTD, quadro Kanban e caixa de entrada
-- Dono: engenheiro de operação. Kanban e GTD saem da mesma tabela valor.atividades.
-- Nenhuma linha de dado real vive aqui. O que existe é vocabulário e configuração
-- padrão, semeada por função, para que a casa troque tudo em tela e não em código.

-- --------------------------------------------------------------------- tipos

create type valor.estado_gtd as enum (
  'entrada', 'proxima_acao', 'aguardando', 'agendada', 'algum_dia', 'concluida', 'cancelada'
);
comment on type valor.estado_gtd is
  'Os estados do método Getting Things Done. Rótulos de tela: Entrada, Próxima ação, Aguardando, Agendada, Algum dia, Concluída, Cancelada.';

create type valor.energia_atividade as enum ('alta', 'media', 'baixa');
comment on type valor.energia_atividade is
  'Energia exigida pela atividade. Rótulos de tela: Alta, Média, Baixa.';

create type valor.frequencia_recorrencia as enum (
  'diaria', 'semanal', 'quinzenal', 'mensal', 'bimestral', 'trimestral', 'semestral', 'anual'
);
comment on type valor.frequencia_recorrencia is
  'Cadência da regra de repetição. Cobre o encontro semanal e a pauta mensal do conselho.';

create type valor.escopo_kanban as enum ('usuario', 'equipe');

-- ------------------------------------------------- leitura de configuração

-- Todo prazo, toda janela e todo limite desta plataforma mora em
-- valor.configuracoes. Esta função é o único jeito de ler um número de lá.
-- O terceiro argumento é a rede de segurança para o inquilino que ainda não
-- semeou a configuração, e repete o mesmo número que a semente grava.
create or replace function valor.configuracao_num(p_inquilino uuid, p_chave text, p_padrao numeric)
returns numeric language sql stable as $$
  select coalesce(
    (select (c.valor #>> '{}')::numeric
       from valor.configuracoes c
      where c.inquilino_id = p_inquilino
        and c.chave = p_chave
        and c.arquivado_em is null),
    p_padrao);
$$;
comment on function valor.configuracao_num(uuid, text, numeric) is
  'Lê um número de valor.configuracoes. Devolve o padrão quando o inquilino ainda não configurou a chave.';

create or replace function valor.gravar_configuracao(
  p_inquilino uuid, p_chave text, p_valor jsonb, p_rotulo text, p_grupo text
) returns void language sql as $$
  insert into valor.configuracoes (inquilino_id, chave, valor, rotulo, grupo)
  values (p_inquilino, p_chave, p_valor, p_rotulo, p_grupo)
  on conflict (inquilino_id, chave) do nothing;
$$;
comment on function valor.gravar_configuracao(uuid, text, jsonb, text, text) is
  'Semeia uma chave de configuração sem sobrescrever o que a casa já ajustou na tela.';

-- ------------------------------------------------------------- contexto GTD

create table valor.contextos_gtd (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  codigo         text not null,
  rotulo         text not null,
  descricao      text,
  ordem          integer not null default 100,
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, codigo)
);
comment on table valor.contextos_gtd is
  'Contexto do método GTD. A casa começa com arroba ligar, arroba escrever, arroba reunião, arroba decidir e arroba esperar, e cria quantos quiser.';
comment on column valor.contextos_gtd.codigo is
  'Identificador curto do contexto, como arroba ligar. É o que aparece na etiqueta da atividade.';

-- --------------------------------------------------------- regra de repetição

create table valor.atividades_recorrencia (
  id                  uuid primary key default gen_random_uuid(),
  inquilino_id        uuid not null references valor.inquilinos(id) on delete restrict,
  nome                text not null,
  frequencia          valor.frequencia_recorrencia not null,
  intervalo           smallint not null default 1 check (intervalo between 1 and 52),
  dia_da_semana       smallint check (dia_da_semana between 0 and 6),
  dia_do_mes          smallint check (dia_do_mes between 1 and 31),
  inicio_em           date not null default current_date,
  fim_em              date,
  ocorrencias_maximas integer check (ocorrencias_maximas > 0),
  ocorrencias_geradas integer not null default 0,
  ultima_ocorrencia_em date,
  ativa               boolean not null default true,
  criado_em           timestamptz not null default now(),
  criado_por          uuid,
  atualizado_em       timestamptz,
  atualizado_por      uuid,
  arquivado_em        timestamptz,
  check (fim_em is null or fim_em >= inicio_em)
);
comment on table valor.atividades_recorrencia is
  'A regra de repetição de uma série de atividades. Serve o encontro semanal de gestão e a pauta prioritária mensal.';
comment on column valor.atividades_recorrencia.dia_da_semana is
  'Zero é domingo, seis é sábado, como o dow do banco. Só vale nas frequências semanal e quinzenal.';
comment on column valor.atividades_recorrencia.ocorrencias_geradas is
  'Quantas ocorrências a série já produziu. Cresce quando uma ocorrência é concluída e a próxima nasce.';

-- -------------------------------------------------------------- atividades

create table valor.atividades (
  id                   uuid primary key default gen_random_uuid(),
  inquilino_id         uuid not null references valor.inquilinos(id) on delete restrict,
  titulo               text not null,
  descricao            text,

  estado               valor.estado_gtd not null default 'entrada',
  contexto_id          uuid references valor.contextos_gtd(id),
  energia              valor.energia_atividade,
  tempo_estimado_min   integer check (tempo_estimado_min > 0),
  prazo                date,
  agendada_para        timestamptz,

  responsavel_id       uuid references valor.usuarios(id),
  delegado_para_id     uuid references valor.usuarios(id),
  delegado_para_externo text,
  aguardando_desde     date,

  prioridade           smallint check (prioridade between 1 and 3),
  ordem_kanban         integer not null default 0,

  -- Vínculo com o que originou a atividade. Colunas nomeadas, e no máximo uma
  -- preenchida. Nada de par genérico de tipo e identificador.
  conta_id             uuid references valor.contas(id),
  negocio_id           uuid references valor.negocios(id),
  contrato_id          uuid references valor.contratos(id),
  encontro_id          uuid references valor.encontros(id),
  pendencia_id         uuid references valor.pendencias(id),

  recorrencia_id       uuid references valor.atividades_recorrencia(id),
  origem_atividade_id  uuid references valor.atividades(id),
  proxima_ocorrencia_id uuid references valor.atividades(id),

  resultado            text,
  concluida_em         timestamptz,
  cancelada_em         timestamptz,
  motivo_cancelamento  text,

  criado_em            timestamptz not null default now(),
  criado_por           uuid,
  atualizado_em        timestamptz,
  atualizado_por       uuid,
  arquivado_em         timestamptz,

  constraint vinculo_no_maximo_um check (
    (case when conta_id     is not null then 1 else 0 end) +
    (case when negocio_id   is not null then 1 else 0 end) +
    (case when contrato_id  is not null then 1 else 0 end) +
    (case when encontro_id  is not null then 1 else 0 end) +
    (case when pendencia_id is not null then 1 else 0 end) <= 1
  ),
  constraint aguardando_tem_delegado check (
    estado <> 'aguardando'
    or delegado_para_id is not null
    or delegado_para_externo is not null
  ),
  constraint agendada_tem_quando check (
    estado <> 'agendada' or agendada_para is not null or prazo is not null
  )
);
comment on table valor.atividades is
  'A atividade única da casa. O quadro Kanban e a lista do método GTD leem esta mesma tabela, sem duplicar dado.';
comment on column valor.atividades.estado is
  'Estado do método GTD. O Kanban desenha colunas sobre este estado, pelo mapeamento de valor.colunas_kanban.';
comment on column valor.atividades.contrato_id is
  'Vínculo com o contrato que originou a atividade. Chave estrangeira para valor.contratos, criada na migração 0005.';
comment on column valor.atividades.encontro_id is
  'Vínculo com o encontro que originou a atividade. Chave estrangeira para valor.encontros, criada na migração 0008.';
comment on column valor.atividades.pendencia_id is
  'Vínculo com a pendência que originou a atividade. Chave estrangeira para valor.pendencias, criada na migração 0009.';
comment on column valor.atividades.delegado_para_externo is
  'Nome de quem recebeu a delegação quando a pessoa é do cliente e não tem usuário na plataforma.';
comment on column valor.atividades.aguardando_desde is
  'Dia em que a atividade entrou no estado Aguardando. É o relógio da cobrança de terceiro.';
comment on column valor.atividades.ordem_kanban is
  'Posição manual do cartão dentro da coluna. Ordenação de tela, não regra de negócio.';

-- Subitens da atividade.
create table valor.atividades_checklist (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  atividade_id   uuid not null references valor.atividades(id) on delete cascade,
  descricao      text not null,
  ordem          integer not null default 100,
  concluido      boolean not null default false,
  concluido_em   timestamptz,
  concluido_por  uuid references valor.usuarios(id),
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on table valor.atividades_checklist is
  'Os subitens de uma atividade. Servem de roteiro de execução e viajam para a próxima ocorrência da série.';

-- Colunas do quadro, por usuário ou por equipe, com ordem e mapeamento GTD.
create table valor.colunas_kanban (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  escopo         valor.escopo_kanban not null default 'equipe',
  usuario_id     uuid references valor.usuarios(id),
  equipe         text,
  nome           text not null,
  estado_gtd     valor.estado_gtd not null,
  ordem          integer not null default 100,
  cor            text,
  limite_wip     smallint check (limite_wip > 0),
  ativa          boolean not null default true,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint escopo_coerente check (
    (escopo = 'usuario' and usuario_id is not null and equipe is null)
    or (escopo = 'equipe' and usuario_id is null and equipe is not null)
  )
);
comment on table valor.colunas_kanban is
  'As colunas configuráveis do quadro. Cada coluna aponta para um estado do método GTD, então o quadro e a lista nunca divergem.';
comment on column valor.colunas_kanban.equipe is
  'Nome da equipe dona do quadro. Texto livre por enquanto: a tabela de equipes ainda não existe. O pedido está no relatório de entrega.';
comment on column valor.colunas_kanban.limite_wip is
  'Limite de trabalho em andamento na coluna. Nulo significa sem limite.';

-- --------------------------------------------------------------- índices

create index on valor.atividades (inquilino_id, responsavel_id, estado) where arquivado_em is null;
create index on valor.atividades (inquilino_id, prazo) where arquivado_em is null;
create index on valor.atividades (inquilino_id, estado, aguardando_desde) where arquivado_em is null;
create index on valor.atividades (negocio_id) where negocio_id is not null and arquivado_em is null;
create index on valor.atividades (conta_id) where conta_id is not null and arquivado_em is null;
create index on valor.atividades (recorrencia_id) where recorrencia_id is not null;
create index on valor.atividades_checklist (atividade_id, ordem) where arquivado_em is null;
create index on valor.contextos_gtd (inquilino_id, ordem) where ativo;

create unique index colunas_kanban_ordem_usuario
  on valor.colunas_kanban (inquilino_id, usuario_id, ordem)
  where escopo = 'usuario' and arquivado_em is null;
create unique index colunas_kanban_ordem_equipe
  on valor.colunas_kanban (inquilino_id, equipe, ordem)
  where escopo = 'equipe' and arquivado_em is null;

-- --------------------------------------------------------------- gatilhos

create trigger carimbo before update on valor.contextos_gtd          for each row execute function valor.carimbar();
create trigger carimbo before update on valor.atividades_recorrencia for each row execute function valor.carimbar();
create trigger carimbo before update on valor.atividades             for each row execute function valor.carimbar();
create trigger carimbo before update on valor.atividades_checklist   for each row execute function valor.carimbar();
create trigger carimbo before update on valor.colunas_kanban         for each row execute function valor.carimbar();

-- Mantém os relógios do estado GTD sem exigir disciplina de quem escreve na tela.
create or replace function valor.marcar_estado_gtd() returns trigger
language plpgsql as $$
begin
  if new.estado = 'aguardando' then
    if tg_op = 'INSERT' or old.estado is distinct from 'aguardando' then
      new.aguardando_desde := coalesce(new.aguardando_desde, current_date);
    end if;
  else
    new.aguardando_desde := null;
  end if;

  if new.estado = 'concluida' then
    if tg_op = 'INSERT' or old.estado is distinct from 'concluida' then
      new.concluida_em := coalesce(new.concluida_em, now());
    end if;
  else
    new.concluida_em := null;
  end if;

  if new.estado = 'cancelada' then
    if tg_op = 'INSERT' or old.estado is distinct from 'cancelada' then
      new.cancelada_em := coalesce(new.cancelada_em, now());
    end if;
  else
    new.cancelada_em := null;
  end if;

  return new;
end;
$$;

create trigger estado_gtd before insert or update on valor.atividades
  for each row execute function valor.marcar_estado_gtd();

-- ------------------------------------------------------------- recorrência

create or replace function valor.proxima_data_recorrencia(
  p_regra valor.atividades_recorrencia, p_base date
) returns date
language plpgsql immutable as $$
declare
  v_intervalo integer := greatest(coalesce(p_regra.intervalo, 1), 1);
  v_passo     interval;
  v_data      date;
  v_ultimo_dia integer;
begin
  v_passo := case p_regra.frequencia
    when 'diaria'     then make_interval(days   => v_intervalo)
    when 'semanal'    then make_interval(days   => v_intervalo * 7)
    when 'quinzenal'  then make_interval(days   => v_intervalo * 14)
    when 'mensal'     then make_interval(months => v_intervalo)
    when 'bimestral'  then make_interval(months => v_intervalo * 2)
    when 'trimestral' then make_interval(months => v_intervalo * 3)
    when 'semestral'  then make_interval(months => v_intervalo * 6)
    when 'anual'      then make_interval(years  => v_intervalo)
  end;

  v_data := (p_base + v_passo)::date;

  if p_regra.dia_do_mes is not null
     and p_regra.frequencia in ('mensal', 'bimestral', 'trimestral', 'semestral', 'anual') then
    v_ultimo_dia := extract(day from (date_trunc('month', v_data::timestamp) + interval '1 month' - interval '1 day'))::integer;
    v_data := (date_trunc('month', v_data::timestamp))::date + (least(p_regra.dia_do_mes, v_ultimo_dia) - 1);
  end if;

  if p_regra.dia_da_semana is not null
     and p_regra.frequencia in ('semanal', 'quinzenal') then
    v_data := v_data + ((p_regra.dia_da_semana - extract(dow from v_data)::integer + 7) % 7);
  end if;

  return v_data;
end;
$$;
comment on function valor.proxima_data_recorrencia(valor.atividades_recorrencia, date) is
  'Calcula a data da próxima ocorrência a partir da data base e da regra de repetição.';

-- Concluir uma atividade recorrente cria a próxima ocorrência.
-- A ocorrência concluída fica onde está, com a data de conclusão carimbada.
create or replace function valor.gerar_proxima_ocorrencia() returns trigger
language plpgsql as $$
declare
  v_regra valor.atividades_recorrencia%rowtype;
  v_prazo date;
  v_nova  uuid;
begin
  if new.estado <> 'concluida' or old.estado = 'concluida' then
    return null;
  end if;
  if new.recorrencia_id is null or new.proxima_ocorrencia_id is not null then
    return null;
  end if;

  select * into v_regra
    from valor.atividades_recorrencia r
   where r.id = new.recorrencia_id and r.ativa and r.arquivado_em is null;
  if not found then
    return null;
  end if;

  if v_regra.ocorrencias_maximas is not null
     and v_regra.ocorrencias_geradas >= v_regra.ocorrencias_maximas then
    return null;
  end if;

  v_prazo := valor.proxima_data_recorrencia(
    v_regra, coalesce(new.prazo, new.agendada_para::date, current_date));

  if v_regra.fim_em is not null and v_prazo > v_regra.fim_em then
    return null;
  end if;

  insert into valor.atividades (
    inquilino_id, titulo, descricao, estado, contexto_id, energia, tempo_estimado_min,
    prazo, agendada_para, responsavel_id, prioridade, ordem_kanban,
    conta_id, negocio_id, contrato_id, encontro_id, pendencia_id,
    recorrencia_id, origem_atividade_id, criado_por
  ) values (
    new.inquilino_id, new.titulo, new.descricao,
    case when new.agendada_para is not null then 'agendada'::valor.estado_gtd
         else 'proxima_acao'::valor.estado_gtd end,
    new.contexto_id, new.energia, new.tempo_estimado_min,
    v_prazo,
    case when new.agendada_para is null then null
         else (v_prazo + new.agendada_para::time) at time zone current_setting('TimeZone') end,
    new.responsavel_id, new.prioridade, new.ordem_kanban,
    new.conta_id, new.negocio_id, new.contrato_id, new.encontro_id, new.pendencia_id,
    new.recorrencia_id, new.id, valor.usuario_atual()
  ) returning id into v_nova;

  insert into valor.atividades_checklist (inquilino_id, atividade_id, descricao, ordem, criado_por)
  select c.inquilino_id, v_nova, c.descricao, c.ordem, valor.usuario_atual()
    from valor.atividades_checklist c
   where c.atividade_id = new.id and c.arquivado_em is null;

  update valor.atividades_recorrencia
     set ocorrencias_geradas = ocorrencias_geradas + 1,
         ultima_ocorrencia_em = v_prazo
   where id = v_regra.id;

  update valor.atividades set proxima_ocorrencia_id = v_nova where id = new.id;

  return null;
end;
$$;
comment on function valor.gerar_proxima_ocorrencia() is
  'Ao concluir uma ocorrência de série, cria a próxima e aponta uma para a outra. Nada é apagado.';

create trigger recorrencia after update of estado on valor.atividades
  for each row execute function valor.gerar_proxima_ocorrencia();

-- ------------------------------------------------------- caixa de entrada

-- A caixa de entrada de cada usuário, com os quatro montes que o método pede.
-- A janela de dias vem de valor.configuracoes, não do código.
create view valor.caixa_de_entrada with (security_invoker = true) as
with base as (
  select a.id, a.inquilino_id, a.titulo, a.estado, a.prazo, a.prioridade,
         a.contexto_id, a.criado_em, a.aguardando_desde,
         a.delegado_para_id, a.delegado_para_externo,
         a.conta_id, a.negocio_id, a.contrato_id, a.encontro_id, a.pendencia_id,
         coalesce(a.responsavel_id, a.criado_por) as usuario_id,
         valor.configuracao_num(a.inquilino_id, 'gtd.janela_dias', 7)::integer as janela
    from valor.atividades a
   where a.arquivado_em is null
     and a.estado not in ('concluida', 'cancelada')
)
select b.inquilino_id, b.usuario_id, b.id as atividade_id, b.titulo, b.estado,
       b.contexto_id, b.prazo, b.prioridade,
       b.conta_id, b.negocio_id, b.contrato_id, b.encontro_id, b.pendencia_id,
       'entrou_hoje'::text as grupo,
       'Caiu hoje'::text   as rotulo,
       1                   as ordem_grupo,
       0                   as dias
  from base b
 where b.criado_em::date = current_date
union all
select b.inquilino_id, b.usuario_id, b.id, b.titulo, b.estado,
       b.contexto_id, b.prazo, b.prioridade,
       b.conta_id, b.negocio_id, b.contrato_id, b.encontro_id, b.pendencia_id,
       'vencida'::text,
       'Vencida'::text,
       2,
       (current_date - b.prazo)
  from base b
 where b.prazo is not null and b.prazo < current_date
union all
select b.inquilino_id, b.usuario_id, b.id, b.titulo, b.estado,
       b.contexto_id, b.prazo, b.prioridade,
       b.conta_id, b.negocio_id, b.contrato_id, b.encontro_id, b.pendencia_id,
       'vence_na_janela'::text,
       'Vence em ' || b.janela || ' dias',
       3,
       (b.prazo - current_date)
  from base b
 where b.prazo is not null
   and b.prazo >= current_date
   and b.prazo <= current_date + b.janela
union all
select b.inquilino_id, b.usuario_id, b.id, b.titulo, b.estado,
       b.contexto_id, b.prazo, b.prioridade,
       b.conta_id, b.negocio_id, b.contrato_id, b.encontro_id, b.pendencia_id,
       'aguardando_terceiro'::text,
       'Aguardando terceiro há mais de ' || b.janela || ' dias',
       4,
       (current_date - b.aguardando_desde)
  from base b
 where b.estado = 'aguardando'
   and b.aguardando_desde is not null
   and b.aguardando_desde <= current_date - b.janela;

comment on view valor.caixa_de_entrada is
  'Caixa de entrada por usuário: o que caiu hoje, o que venceu, o que vence dentro da janela e o que está aguardando terceiro além da janela.';

-- O mesmo dado, desenhado como quadro. Nenhuma coluna duplicada.
create view valor.quadro_kanban with (security_invoker = true) as
select k.id as coluna_id, k.nome as coluna, k.ordem as coluna_ordem,
       k.escopo, k.usuario_id as quadro_usuario_id, k.equipe,
       a.id as atividade_id, a.inquilino_id, a.titulo, a.estado, a.contexto_id,
       a.responsavel_id, a.prazo, a.prioridade, a.energia,
       a.tempo_estimado_min, a.ordem_kanban
  from valor.colunas_kanban k
  join valor.atividades a
    on a.inquilino_id = k.inquilino_id
   and a.estado = k.estado_gtd
   and a.arquivado_em is null
   and (k.escopo = 'equipe' or a.responsavel_id = k.usuario_id)
 where k.ativa and k.arquivado_em is null;

comment on view valor.quadro_kanban is
  'A visão de quadro sobre valor.atividades. A coluna sai do mapeamento configurado, o cartão sai da atividade.';

-- ------------------------------------------------------------- semente GTD

-- Vocabulário padrão de um inquilino novo. Contexto e coluna são configuração,
-- trocadas em tela. Nenhum nome de pessoa, conta ou negócio entra aqui.
create or replace function valor.semear_gtd(p_inquilino uuid) returns void
language plpgsql as $$
begin
  insert into valor.contextos_gtd (inquilino_id, codigo, rotulo, descricao, ordem)
  values
    (p_inquilino, '@ligar',   'Ligar',    'Tudo que se resolve com uma ligação.',            10),
    (p_inquilino, '@escrever','Escrever', 'Mensagem, documento ou artefato para redigir.',   20),
    (p_inquilino, '@reuniao', 'Reunião',  'Só avança com gente junto, presencial ou online.', 30),
    (p_inquilino, '@decidir', 'Decidir',  'Espera uma decisão da casa, não uma execução.',    40),
    (p_inquilino, '@esperar', 'Esperar',  'Está na mão de terceiro e precisa de cobrança.',   50)
  on conflict (inquilino_id, codigo) do nothing;

  insert into valor.colunas_kanban (inquilino_id, escopo, equipe, nome, estado_gtd, ordem, cor)
  values
    (p_inquilino, 'equipe', 'comercial', 'Entrada',      'entrada',      10, '#707070'),
    (p_inquilino, 'equipe', 'comercial', 'Próxima ação', 'proxima_acao', 20, '#5E1E3A'),
    (p_inquilino, 'equipe', 'comercial', 'Agendada',     'agendada',     30, '#C2900A'),
    (p_inquilino, 'equipe', 'comercial', 'Aguardando',   'aguardando',   40, '#C58A00'),
    (p_inquilino, 'equipe', 'comercial', 'Algum dia',    'algum_dia',    50, '#1D1D1B'),
    (p_inquilino, 'equipe', 'comercial', 'Concluída',    'concluida',    60, '#2E7D4F')
  on conflict do nothing;

  perform valor.gravar_configuracao(
    p_inquilino, 'gtd.janela_dias', to_jsonb(7),
    'Janela da caixa de entrada, em dias', 'atividades');
end;
$$;
comment on function valor.semear_gtd(uuid) is
  'Semeia contexto e coluna padrão de um inquilino. Idempotente, não sobrescreve ajuste feito na tela.';

do $$
declare r record;
begin
  for r in select id from valor.inquilinos loop
    perform valor.semear_gtd(r.id);
  end loop;
end;
$$;

-- ------------------------------------------------------------- segurança

alter table valor.contextos_gtd          enable row level security;
alter table valor.atividades_recorrencia enable row level security;
alter table valor.atividades             enable row level security;
alter table valor.atividades_checklist   enable row level security;
alter table valor.colunas_kanban         enable row level security;

-- O parceiro indica negócio. A agenda interna da casa não é dele.
create policy contexto_le on valor.contextos_gtd for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy contexto_escreve on valor.contextos_gtd for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy recorrencia_le on valor.atividades_recorrencia for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy recorrencia_escreve on valor.atividades_recorrencia for all
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro())
  with check (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());

create policy atividade_le on valor.atividades for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy atividade_escreve on valor.atividades for all
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro())
  with check (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());

create policy checklist_le on valor.atividades_checklist for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy checklist_escreve on valor.atividades_checklist for all
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro())
  with check (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());

create policy coluna_le on valor.colunas_kanban for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy coluna_escreve on valor.colunas_kanban for all
  using (valor.do_inquilino(inquilino_id)
         and (valor.eh_admin() or (escopo = 'usuario' and usuario_id = valor.usuario_atual())))
  with check (valor.do_inquilino(inquilino_id)
         and (valor.eh_admin() or (escopo = 'usuario' and usuario_id = valor.usuario_atual())));
