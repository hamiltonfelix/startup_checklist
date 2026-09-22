-- 0010 · NPS, pesquisas e avaliação do conselheiro
-- Dono: engenheiro de governança. Nenhum outro agente altera este arquivo.
--
-- O instrumento da casa, conforme a seção 7 de CATALOGO-E-REGRAS.md e a decisão
-- E13 a E15 de REQUISITOS-PARA-CONSTRUIR.md:
--   NPS trimestral, com a pergunta clássica de recomendação mais os blocos de
--   qualidade, atendimento, relacionamento comercial, entrega, valor percebido,
--   lealdade e inovação; nota do conselheiro de 0 a 10, semestral, respondida
--   pelos sócios do cliente, com as críticas construtivas registradas.
--
-- Toda avaliação de pessoa é confidencial. O parceiro nunca vê. O conselheiro não
-- lê a própria avaliação em cru sem passar pelo líder, e isso vive na coluna
-- liberada_para_avaliado e na política de linha, não na interface.
--
-- Dependência em aberto: a migração 0008, que cria valor.turmas e valor.encontros,
-- está sendo escrita em paralelo. As colunas turma_id e programa_id nascem soltas,
-- sem chave estrangeira. O pedido está no relatório final desta entrega.

-- ---------------------------------------------------------------- tipos do domínio

create type valor.pesquisa_tipo as enum ('nps_trimestral', 'nota_conselheiro_semestral', 'avulsa');

create type valor.pesquisa_status as enum ('rascunho', 'agendada', 'aberta', 'fechada', 'cancelada');

create type valor.questao_tipo as enum ('nota_0_10', 'escala', 'texto_livre', 'multipla_escolha');

create type valor.questao_bloco as enum (
  'recomendacao', 'qualidade', 'atendimento', 'relacionamento_comercial',
  'entrega', 'valor_percebido', 'lealdade', 'inovacao'
);

create type valor.nps_faixa as enum ('promotor', 'neutro', 'detrator');

-- ---------------------------------------------------------------- campanha

create table valor.pesquisas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid references valor.contas(id) on delete restrict,
  turma_id       uuid,
  programa_id    uuid,
  tipo           valor.pesquisa_tipo not null,
  titulo         text not null,
  periodo        text not null,
  periodo_inicio date not null,
  periodo_fim    date not null,
  publico_alvo   text not null,
  publico_alvo_detalhe jsonb not null default '{}',
  status         valor.pesquisa_status not null default 'rascunho',
  abertura_em    timestamptz,
  fechamento_em  timestamptz,
  anonima        boolean not null default false,
  observacao     text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint pesquisa_periodo_coerente check (periodo_fim >= periodo_inicio),
  constraint pesquisa_aberta_tem_data check (status <> 'aberta' or abertura_em is not null),
  constraint pesquisa_fechada_tem_data check (status <> 'fechada' or fechamento_em is not null)
);
comment on table valor.pesquisas is
  'A campanha de avaliação: NPS trimestral, nota do conselheiro semestral, ou avulsa.';
comment on column valor.pesquisas.periodo is
  'Rótulo do ciclo, por exemplo 2026-T3 para o trimestre e 2026-S2 para o semestre.';
comment on column valor.pesquisas.publico_alvo is
  'Quem responde: sócios do cliente, participantes da turma, time interno, ou revenda.';
comment on column valor.pesquisas.conta_id is
  'Nulo quando a campanha é da casa inteira e não de uma conta.';
comment on column valor.pesquisas.turma_id is
  'Sem chave estrangeira até a migração 0008 criar valor.turmas.';
comment on column valor.pesquisas.anonima is
  'Campanha anônima: a identidade do respondente fica mascarada em toda visão.';

-- ---------------------------------------------------------------- questões

create table valor.pesquisas_questoes (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  pesquisa_id    uuid not null references valor.pesquisas(id) on delete cascade,
  ordem          smallint not null default 100,
  bloco          valor.questao_bloco not null,
  tipo           valor.questao_tipo not null,
  enunciado      text not null,
  ajuda          text,
  obrigatoria    boolean not null default true,
  escala_minimo  smallint,
  escala_maximo  smallint,
  opcoes         jsonb not null default '[]',
  eh_pergunta_classica boolean not null default false,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint questao_escala_coerente check (
    tipo <> 'escala' or (escala_minimo is not null and escala_maximo is not null and escala_maximo > escala_minimo)),
  constraint questao_multipla_tem_opcoes check (
    tipo <> 'multipla_escolha' or jsonb_array_length(opcoes) > 0),
  constraint questao_classica_eh_nota check (
    not eh_pergunta_classica or (tipo = 'nota_0_10' and bloco = 'recomendacao'))
);
comment on table valor.pesquisas_questoes is
  'A pergunta clássica de recomendação mais os blocos de qualidade, atendimento, relacionamento comercial, entrega, valor percebido, lealdade e inovação.';
comment on column valor.pesquisas_questoes.eh_pergunta_classica is
  'A pergunta de recomendação de 0 a 10, a que calcula o NPS. Uma por pesquisa.';

create unique index questao_classica_unica
  on valor.pesquisas_questoes (pesquisa_id)
  where eh_pergunta_classica and arquivado_em is null;

create unique index questao_ordem_unica
  on valor.pesquisas_questoes (pesquisa_id, ordem)
  where arquivado_em is null;

-- ---------------------------------------------------------------- respostas

create table valor.respostas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  pesquisa_id    uuid not null references valor.pesquisas(id) on delete restrict,
  questao_id     uuid not null references valor.pesquisas_questoes(id) on delete restrict,
  conta_id       uuid references valor.contas(id) on delete restrict,
  contato_id     uuid references valor.contatos(id) on delete restrict,
  usuario_id     uuid references valor.usuarios(id) on delete restrict,
  token_anonimo  text,
  respondente_chave text generated always as (
    coalesce(contato_id::text, usuario_id::text, token_anonimo)) stored,
  nota           smallint check (nota between 0 and 10),
  texto          text,
  opcao_escolhida text,
  respondida_em  timestamptz not null default now(),
  anonima        boolean not null default false,
  canal          text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint resposta_tem_respondente check (
    contato_id is not null or usuario_id is not null or token_anonimo is not null),
  constraint resposta_tem_conteudo check (
    nota is not null or texto is not null or opcao_escolhida is not null)
);
comment on table valor.respostas is
  'Uma linha por pessoa e por questão, com nota, texto, data e a marca de anônima quando for o caso.';
comment on column valor.respostas.contato_id is
  'CONFIDENCIAL: time interno da conta. O parceiro nunca lê. Em pesquisa anônima a identidade é mascarada nas visões.';
comment on column valor.respostas.usuario_id is
  'CONFIDENCIAL: usado no eNPS, quando quem responde é gente da casa.';
comment on column valor.respostas.texto is
  'CONFIDENCIAL: time interno da conta. É a motivação escrita da nota, e pode citar pessoas.';
comment on column valor.respostas.respondente_chave is
  'Chave estável do respondente, para achar a última resposta de cada pessoa. Nunca é a média.';
comment on column valor.respostas.token_anonimo is
  'Identificador opaco do convite, usado quando a pesquisa é anônima. Não identifica a pessoa.';

create unique index resposta_unica_por_questao
  on valor.respostas (pesquisa_id, questao_id, respondente_chave)
  where arquivado_em is null;

-- ---------------------------------------------------------------- avaliação do conselheiro

create table valor.avaliacoes_conselheiro (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  conselheiro_usuario_id uuid not null references valor.usuarios(id) on delete restrict,
  pesquisa_id    uuid references valor.pesquisas(id) on delete restrict,
  avaliador_contato_id uuid references valor.contatos(id) on delete restrict,
  periodo        text not null,
  periodo_inicio date not null,
  periodo_fim    date not null,
  nota           smallint not null check (nota between 0 and 10),
  pontos_fortes  text,
  criticas_construtivas text,
  comentario_livre text,
  respondida_em  timestamptz not null default now(),
  liberada_para_avaliado boolean not null default false,
  liberada_em    timestamptz,
  liberada_por   uuid references valor.usuarios(id),
  devolutiva_do_lider text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  constraint avaliacao_periodo_coerente check (periodo_fim >= periodo_inicio),
  constraint avaliacao_liberacao_tem_carimbo check (
    not liberada_para_avaliado or (liberada_em is not null and liberada_por is not null))
);
comment on table valor.avaliacoes_conselheiro is
  'A nota de 0 a 10 do conselheiro, semestral, respondida pelos sócios do cliente. Avaliação de pessoa, confidencial por inteiro.';
comment on column valor.avaliacoes_conselheiro.nota is
  'CONFIDENCIAL: líder, administrador e financeiro. O parceiro nunca vê. O avaliado só depois de liberada_para_avaliado.';
comment on column valor.avaliacoes_conselheiro.criticas_construtivas is
  'CONFIDENCIAL: líder, administrador e financeiro. O parceiro nunca vê. O avaliado só depois de liberada_para_avaliado.';
comment on column valor.avaliacoes_conselheiro.pontos_fortes is
  'CONFIDENCIAL: líder, administrador e financeiro. O parceiro nunca vê. O avaliado só depois de liberada_para_avaliado.';
comment on column valor.avaliacoes_conselheiro.comentario_livre is
  'CONFIDENCIAL: líder, administrador e financeiro. O parceiro nunca vê. O avaliado só depois de liberada_para_avaliado.';
comment on column valor.avaliacoes_conselheiro.avaliador_contato_id is
  'CONFIDENCIAL: líder, administrador e financeiro. Quem avaliou nunca é revelado ao avaliado.';
comment on column valor.avaliacoes_conselheiro.liberada_para_avaliado is
  'Só o líder libera. Enquanto for falso, o conselheiro não lê a própria avaliação em cru. A regra vive na política de linha.';
comment on column valor.avaliacoes_conselheiro.devolutiva_do_lider is
  'CONFIDENCIAL: líder, administrador e financeiro. O texto que o líder trabalha com o conselheiro na conversa de devolutiva.';

-- ---------------------------------------------------------------- ciclo por conta

create table valor.ciclos_avaliacao (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  tipo           valor.pesquisa_tipo not null,
  periodicidade_meses smallint not null check (periodicidade_meses > 0),
  ultima_aplicacao date,
  proxima_aplicacao date not null,
  responsavel_usuario_id uuid references valor.usuarios(id),
  dias_de_antecedencia smallint not null default 15 check (dias_de_antecedencia >= 0),
  ativo          boolean not null default true,
  observacao     text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on table valor.ciclos_avaliacao is
  'A data do próximo ciclo por conta, para o painel saber cobrar. NPS a cada 3 meses, nota do conselheiro a cada 6.';
comment on column valor.ciclos_avaliacao.dias_de_antecedencia is
  'Quantos dias antes do próximo ciclo o painel começa a avisar.';

create unique index ciclo_avaliacao_unico
  on valor.ciclos_avaliacao (inquilino_id, conta_id, tipo)
  where arquivado_em is null;

-- ---------------------------------------------------------------- índices

create index on valor.pesquisas (inquilino_id, tipo, status) where arquivado_em is null;
create index on valor.pesquisas (inquilino_id, conta_id, periodo_fim desc) where arquivado_em is null;
create index on valor.pesquisas_questoes (pesquisa_id, ordem) where arquivado_em is null;
create index on valor.respostas (inquilino_id, conta_id, respondida_em desc) where arquivado_em is null;
create index on valor.respostas (pesquisa_id, questao_id) where arquivado_em is null;
create index on valor.respostas (respondente_chave, respondida_em desc) where arquivado_em is null;
create index on valor.avaliacoes_conselheiro (inquilino_id, conselheiro_usuario_id, periodo_fim desc) where arquivado_em is null;
create index on valor.avaliacoes_conselheiro (inquilino_id, conta_id, periodo_fim desc) where arquivado_em is null;
create index on valor.ciclos_avaliacao (inquilino_id, proxima_aplicacao) where ativo and arquivado_em is null;

-- ---------------------------------------------------------------- funções do ciclo

create or replace function valor.periodicidade_do_tipo(tipo valor.pesquisa_tipo)
returns smallint language sql immutable as $$
  select case tipo
    when 'nps_trimestral' then 3
    when 'nota_conselheiro_semestral' then 6
    else 12
  end::smallint;
$$;

comment on function valor.periodicidade_do_tipo(valor.pesquisa_tipo) is
  'A régua do rito: a pesquisa é trimestral, a avaliação do conselheiro é semestral.';

create or replace function valor.proxima_data_ciclo(base date, meses smallint)
returns date language sql immutable as $$
  select (base + (meses || ' months')::interval)::date;
$$;

-- Ao fechar a campanha, o ciclo da conta anda sozinho. O painel passa a cobrar a
-- data nova sem ninguém precisar lembrar.
create or replace function valor.avancar_ciclo_avaliacao() returns trigger
language plpgsql as $$
declare
  meses smallint;
begin
  if new.conta_id is null then
    return new;
  end if;
  if new.status <> 'fechada' or old.status = 'fechada' then
    return new;
  end if;

  meses := valor.periodicidade_do_tipo(new.tipo);

  insert into valor.ciclos_avaliacao (
    inquilino_id, conta_id, tipo, periodicidade_meses,
    ultima_aplicacao, proxima_aplicacao, criado_por
  ) values (
    new.inquilino_id, new.conta_id, new.tipo, meses,
    new.periodo_fim, valor.proxima_data_ciclo(new.periodo_fim, meses), valor.usuario_atual()
  )
  on conflict do nothing;

  update valor.ciclos_avaliacao c
     set ultima_aplicacao  = new.periodo_fim,
         proxima_aplicacao = valor.proxima_data_ciclo(new.periodo_fim, meses),
         atualizado_em     = now(),
         atualizado_por    = valor.usuario_atual()
   where c.inquilino_id = new.inquilino_id
     and c.conta_id = new.conta_id
     and c.tipo = new.tipo
     and c.arquivado_em is null;

  return new;
end;
$$;

comment on function valor.avancar_ciclo_avaliacao() is
  'Campanha fechada empurra a data do próximo ciclo da conta, trimestral ou semestral conforme o tipo.';

create trigger avancar_ciclo after update on valor.pesquisas
  for each row execute function valor.avancar_ciclo_avaliacao();

-- O líder é quem libera a avaliação para o avaliado. O próprio avaliado não libera.
create or replace function valor.avaliacao_liberacao() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    if new.liberada_para_avaliado and not valor.ve_confidencial() then
      raise exception 'Somente o líder libera a avaliação para o avaliado.'
        using errcode = 'insufficient_privilege';
    end if;
    return new;
  end if;

  if new.liberada_para_avaliado and not old.liberada_para_avaliado then
    if not valor.ve_confidencial() then
      raise exception 'Somente o líder libera a avaliação para o avaliado.'
        using errcode = 'insufficient_privilege';
    end if;
    if valor.usuario_atual() = new.conselheiro_usuario_id then
      raise exception 'O avaliado não libera a própria avaliação.'
        using errcode = 'insufficient_privilege';
    end if;
    new.liberada_em  := coalesce(new.liberada_em, now());
    new.liberada_por := coalesce(new.liberada_por, valor.usuario_atual());
  end if;

  return new;
end;
$$;

comment on function valor.avaliacao_liberacao() is
  'Guarda da confidencialidade: o conselheiro não vê a própria avaliação em cru sem passar pelo líder.';

create trigger avaliacao_liberacao before insert or update on valor.avaliacoes_conselheiro
  for each row execute function valor.avaliacao_liberacao();

-- ---------------------------------------------------------------- NPS

-- A última resposta de cada pessoa na pergunta clássica, por conta, com a data e
-- a motivação escrita. A pessoa entra com a última nota, nunca com a média.
create view valor.nps_ultima_por_pessoa
  with (security_invoker = true) as
with notas as (
  select
    r.inquilino_id,
    coalesce(r.conta_id, p.conta_id) as conta_id,
    r.pesquisa_id,
    p.periodo,
    p.tipo,
    p.anonima as pesquisa_anonima,
    r.respondente_chave,
    r.contato_id,
    r.usuario_id,
    r.anonima,
    r.nota,
    r.respondida_em,
    row_number() over (
      partition by r.inquilino_id, coalesce(r.conta_id, p.conta_id), r.respondente_chave
      order by r.respondida_em desc, r.criado_em desc
    ) as posicao
  from valor.respostas r
  join valor.pesquisas_questoes q on q.id = r.questao_id
  join valor.pesquisas p on p.id = r.pesquisa_id
  where r.arquivado_em is null
    and q.arquivado_em is null
    and p.arquivado_em is null
    and q.eh_pergunta_classica
    and r.nota is not null
)
select
  n.inquilino_id,
  n.conta_id,
  n.pesquisa_id,
  n.periodo,
  n.tipo,
  n.respondente_chave,
  case
    when n.anonima or n.pesquisa_anonima then 'anônimo'
    else coalesce(c.nome, u.nome, 'não identificado')
  end as respondente,
  case when n.anonima or n.pesquisa_anonima then null else n.contato_id end as contato_id,
  case when n.anonima or n.pesquisa_anonima then null else n.usuario_id end as usuario_id,
  n.anonima or n.pesquisa_anonima as anonima,
  n.nota,
  n.respondida_em,
  n.respondida_em::date as data_da_nota,
  case
    when n.nota >= 9 then 'promotor'
    when n.nota >= 7 then 'neutro'
    else 'detrator'
  end::valor.nps_faixa as faixa,
  (
    select m.texto
    from valor.respostas m
    join valor.pesquisas_questoes mq on mq.id = m.questao_id
    where m.pesquisa_id = n.pesquisa_id
      and m.respondente_chave = n.respondente_chave
      and m.texto is not null
      and m.arquivado_em is null
      and mq.tipo = 'texto_livre'
    order by (mq.bloco = 'recomendacao') desc, mq.ordem
    limit 1
  ) as motivacao
from notas n
left join valor.contatos c on c.id = n.contato_id
left join valor.usuarios u on u.id = n.usuario_id
where n.posicao = 1;

comment on view valor.nps_ultima_por_pessoa is
  'A última nota de cada pessoa, por conta, com a data, a faixa e a motivação escrita. Nunca a média.';

-- A visão pedida pelo rito: a pessoa com a última nota, e ao lado dela o cálculo
-- de promotores, neutros e detratores da conta e o NPS resultante.
create view valor.nps_por_conta
  with (security_invoker = true) as
select
  u.inquilino_id,
  u.conta_id,
  u.respondente_chave,
  u.respondente,
  u.anonima,
  u.nota,
  u.data_da_nota,
  u.respondida_em,
  u.faixa,
  u.motivacao,
  u.pesquisa_id,
  u.periodo,
  count(*) over (partition by u.inquilino_id, u.conta_id) as respondentes,
  count(*) filter (where u.faixa = 'promotor') over (partition by u.inquilino_id, u.conta_id) as promotores,
  count(*) filter (where u.faixa = 'neutro')   over (partition by u.inquilino_id, u.conta_id) as neutros,
  count(*) filter (where u.faixa = 'detrator') over (partition by u.inquilino_id, u.conta_id) as detratores,
  round(
    (count(*) filter (where u.faixa = 'promotor') over (partition by u.inquilino_id, u.conta_id))::numeric
    / nullif(count(*) over (partition by u.inquilino_id, u.conta_id), 0), 4
  ) as proporcao_promotores,
  round(
    (count(*) filter (where u.faixa = 'detrator') over (partition by u.inquilino_id, u.conta_id))::numeric
    / nullif(count(*) over (partition by u.inquilino_id, u.conta_id), 0), 4
  ) as proporcao_detratores,
  round(
    100.0 * (
      (count(*) filter (where u.faixa = 'promotor') over (partition by u.inquilino_id, u.conta_id))
      - (count(*) filter (where u.faixa = 'detrator') over (partition by u.inquilino_id, u.conta_id))
    )::numeric
    / nullif(count(*) over (partition by u.inquilino_id, u.conta_id), 0), 1
  ) as nps
from valor.nps_ultima_por_pessoa u;

comment on view valor.nps_por_conta is
  'Uma linha por pessoa, com a última nota, a data e a motivação escrita, e ao lado o cálculo de promotores, neutros, detratores e o NPS da conta.';

-- O consolidado de uma linha por conta, para o painel.
create view valor.nps_consolidado_por_conta
  with (security_invoker = true) as
select
  u.inquilino_id,
  u.conta_id,
  count(*) as respondentes,
  count(*) filter (where u.faixa = 'promotor') as promotores,
  count(*) filter (where u.faixa = 'neutro')   as neutros,
  count(*) filter (where u.faixa = 'detrator') as detratores,
  round(
    100.0 * (count(*) filter (where u.faixa = 'promotor') - count(*) filter (where u.faixa = 'detrator'))::numeric
    / nullif(count(*), 0), 1
  ) as nps,
  max(u.data_da_nota) as ultima_resposta
from valor.nps_ultima_por_pessoa u
group by u.inquilino_id, u.conta_id;

comment on view valor.nps_consolidado_por_conta is
  'Uma linha por conta, com promotores, neutros, detratores, NPS e a data da última resposta.';

-- O alerta de ciclo do painel: o que já venceu e o que vence dentro da antecedência.
create view valor.alertas_ciclo_avaliacao
  with (security_invoker = true) as
select
  c.id,
  c.inquilino_id,
  c.conta_id,
  c.tipo,
  c.periodicidade_meses,
  c.ultima_aplicacao,
  c.proxima_aplicacao,
  c.responsavel_usuario_id,
  c.proxima_aplicacao - current_date as dias_para_o_ciclo,
  case
    when c.proxima_aplicacao < current_date then 'vencido'
    when c.proxima_aplicacao - current_date <= c.dias_de_antecedencia then 'a vencer'
    else 'em dia'
  end as situacao
from valor.ciclos_avaliacao c
where c.ativo and c.arquivado_em is null;

comment on view valor.alertas_ciclo_avaliacao is
  'Alerta de ciclo por conta: NPS a cada três meses, nota do conselheiro a cada seis.';

-- A avaliação que o conselheiro pode ler de si mesmo, já liberada pelo líder.
create view valor.minhas_avaliacoes_liberadas
  with (security_invoker = true) as
select
  a.id,
  a.inquilino_id,
  a.conta_id,
  a.conselheiro_usuario_id,
  a.periodo,
  a.periodo_inicio,
  a.periodo_fim,
  a.nota,
  a.pontos_fortes,
  a.criticas_construtivas,
  a.liberada_em,
  a.devolutiva_do_lider
from valor.avaliacoes_conselheiro a
where a.arquivado_em is null
  and a.liberada_para_avaliado
  and a.conselheiro_usuario_id = valor.usuario_atual();

comment on view valor.minhas_avaliacoes_liberadas is
  'O que o conselheiro lê de si mesmo, depois que o líder liberou. Quem avaliou nunca aparece.';

-- ---------------------------------------------------------------- semeadura do instrumento

create or replace function valor.semear_questoes_nps(alvo_pesquisa uuid)
returns integer language plpgsql as $$
declare
  alvo_inquilino uuid;
  inseridos integer;
begin
  select p.inquilino_id into alvo_inquilino from valor.pesquisas p where p.id = alvo_pesquisa;
  if alvo_inquilino is null then
    raise exception 'Pesquisa % não encontrada.', alvo_pesquisa using errcode = 'no_data_found';
  end if;

  insert into valor.pesquisas_questoes (
    inquilino_id, pesquisa_id, ordem, bloco, tipo, enunciado, obrigatoria,
    escala_minimo, escala_maximo, eh_pergunta_classica
  )
  select
    alvo_inquilino, alvo_pesquisa, t.ordem::smallint, t.bloco::valor.questao_bloco,
    t.tipo::valor.questao_tipo, t.enunciado, t.obrigatoria,
    t.minimo::smallint, t.maximo::smallint, t.classica
  from (values
    (1,'recomendacao','nota_0_10','Em uma escala de 0 a 10, o quanto você recomendaria a Felix Empresarial a um colega ou parceiro?',true,null,null,true),
    (2,'recomendacao','texto_livre','Qual o principal motivo da sua nota?',true,null,null,false),
    (3,'qualidade','escala','Como você avalia a qualidade técnica do que foi entregue?',true,1,5,false),
    (4,'atendimento','escala','Como você avalia o atendimento e a disponibilidade da equipe?',true,1,5,false),
    (5,'relacionamento_comercial','escala','Como você avalia a clareza e a postura no relacionamento comercial?',true,1,5,false),
    (6,'entrega','escala','Como você avalia o cumprimento de prazos e combinados na entrega?',true,1,5,false),
    (7,'valor_percebido','escala','O quanto o resultado entregue justifica o investimento feito?',true,1,5,false),
    (8,'lealdade','escala','Qual a sua intenção de continuar com a Felix Empresarial no próximo ciclo?',true,1,5,false),
    (9,'inovacao','escala','O quanto a Felix Empresarial traz ideias novas e provocações úteis para o seu negócio?',true,1,5,false),
    (10,'inovacao','texto_livre','O que faríamos de diferente para merecer uma nota mais alta?',false,null,null,false)
  ) as t(ordem, bloco, tipo, enunciado, obrigatoria, minimo, maximo, classica)
  on conflict do nothing;

  get diagnostics inseridos = row_count;
  return inseridos;
end;
$$;

comment on function valor.semear_questoes_nps(uuid) is
  'Monta o instrumento da casa numa pesquisa: a pergunta clássica de recomendação mais os blocos de qualidade, atendimento, relacionamento comercial, entrega, valor percebido, lealdade e inovação.';

-- ---------------------------------------------------------------- carimbos e guardas

create trigger carimbo before update on valor.pesquisas for each row execute function valor.carimbar();
create trigger carimbo before update on valor.pesquisas_questoes for each row execute function valor.carimbar();
create trigger carimbo before update on valor.respostas for each row execute function valor.carimbar();
create trigger carimbo before update on valor.avaliacoes_conselheiro for each row execute function valor.carimbar();
create trigger carimbo before update on valor.ciclos_avaliacao for each row execute function valor.carimbar();

create trigger sem_remocao before delete on valor.pesquisas for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.pesquisas_questoes for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.respostas for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.avaliacoes_conselheiro for each statement execute function valor.impedir_remocao();
create trigger sem_remocao before delete on valor.ciclos_avaliacao for each statement execute function valor.impedir_remocao();

-- ---------------------------------------------------------------- segurança

alter table valor.pesquisas              enable row level security;
alter table valor.pesquisas_questoes     enable row level security;
alter table valor.respostas              enable row level security;
alter table valor.avaliacoes_conselheiro enable row level security;
alter table valor.ciclos_avaliacao       enable row level security;

-- Nenhuma tabela deste arquivo recebe política de remoção.
--
-- O perfil participante, criado para a pessoa do cliente que ocupa cadeira,
-- responde pesquisa mas não lê apuração. Ler a apuração seria ver a nota e a
-- motivação escrita dos colegas de mesa, e no caso de turma compartilhada seria
-- ver a nota de empresas concorrentes. O predicado valor.gov_time_da_casa vem
-- da migração 0009 e vale igual aqui.

create policy pesquisa_le on valor.pesquisas for select
  using (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
create policy pesquisa_insere on valor.pesquisas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
create policy pesquisa_atualiza on valor.pesquisas for update
  using (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());

create policy questao_le on valor.pesquisas_questoes for select
  using (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
create policy questao_insere on valor.pesquisas_questoes for insert
  with check (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
create policy questao_atualiza on valor.pesquisas_questoes for update
  using (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());

-- A resposta do cliente é do time interno. O parceiro nunca lê, e o participante
-- também não: a apuração não é dele. Mas ele grava a própria resposta, que é o
-- ato de responder a pesquisa, e só a própria.
create policy resposta_le on valor.respostas for select
  using (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
create policy resposta_insere on valor.respostas for insert
  with check (
    valor.do_inquilino(inquilino_id)
    and not valor.eh_parceiro()
    and (valor.gov_time_da_casa() or usuario_id = valor.usuario_atual())
  );
create policy resposta_atualiza on valor.respostas for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

-- Avaliação de pessoa. O parceiro nunca vê. O avaliado só depois de liberada.
-- Quem responde é o sócio do cliente, que pode ter perfil participante, então a
-- escrita continua aberta a ele. A leitura não: nem do que ele mesmo escreveu,
-- senão a autoria de uma avaliação de pessoa ficaria rastreável.
create policy avaliacao_conselheiro_le on valor.avaliacoes_conselheiro for select
  using (
    valor.do_inquilino(inquilino_id)
    and not valor.eh_parceiro()
    and (
      valor.ve_confidencial()
      or (liberada_para_avaliado and valor.usuario_atual() = conselheiro_usuario_id)
    )
  );
create policy avaliacao_conselheiro_insere on valor.avaliacoes_conselheiro for insert
  with check (
    valor.do_inquilino(inquilino_id)
    and not valor.eh_parceiro()
    and valor.usuario_atual() is distinct from conselheiro_usuario_id
  );
create policy avaliacao_conselheiro_atualiza on valor.avaliacoes_conselheiro for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

create policy ciclo_le on valor.ciclos_avaliacao for select
  using (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
create policy ciclo_insere on valor.ciclos_avaliacao for insert
  with check (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
create policy ciclo_atualiza on valor.ciclos_avaliacao for update
  using (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.gov_time_da_casa());
