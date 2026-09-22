-- Plataforma de Valor · esquema completo
-- Gerado em 22/09/2026 a partir das migracoes numeradas.
-- Cole isto inteiro no editor de SQL do Supabase e mande executar.
-- Aplica de uma vez so, na ordem certa.


-- ==========================================================================
-- 0001_tipos_e_funcoes.sql
-- ==========================================================================
-- 0001 · Tipos, esquema e funções de contexto
-- Dono: orquestrador. Base compartilhada. Nenhum agente altera este arquivo.
-- Os tipos aqui são os tipos comuns aos três produtos. Um agente pode criar
-- tipos próprios do seu domínio dentro da própria migração, com nome prefixado.

create extension if not exists pgcrypto;
create schema if not exists valor;

-- ---------------------------------------------------------------- tipos comuns

create type valor.perfil_usuario as enum (
  'admin_master', 'lider', 'comercial', 'gerente_contas',
  'conselheiro', 'assessor', 'financeiro', 'parceiro', 'participante', 'emergencia'
);
comment on type valor.perfil_usuario is
  'O participante e a pessoa do cliente que ocupa cadeira numa turma. Ele alcanca a propria turma e somente o entregavel marcado como visivel ao cliente.';

create type valor.papel_negocio as enum (
  'gerente_contas', 'conselheiro', 'pre_vendas',
  'gerente_projetos', 'assessor', 'parceiro'
);

create type valor.tipo_artefato as enum (
  'plano_conta', 'plano_negocio', 'plano_trabalho', 'contrato_valor',
  'entrega_valor', 'monitoria_valor', 'renovacao_valor'
);

create type valor.status_artefato as enum (
  'rascunho', 'interno_pronto', 'validado_com_cliente', 'superado'
);

create type valor.forecast_categoria as enum ('compromisso', 'possivel', 'aberto', 'fora');

create type valor.desfecho_negocio as enum ('concluido', 'vencido', 'cancelado', 'perdido');

create type valor.tier_conta as enum ('t1', 't2', 't3');

create type valor.probabilidade as enum ('alta', 'media', 'baixa');

create type valor.origem_lead as enum (
  'evento', 'indicacao_parceiro', 'indicacao_cliente', 'prospeccao_ativa',
  'inbound', 'rede_pessoal', 'licitacao_publica', 'base_instalada', 'outro'
);

create type valor.rota_negocio as enum ('privada', 'publica');

create type valor.modalidade_oferta as enum ('pontual', 'recorrente', 'pontual_com_sustentacao');

create type valor.nivel_contrato as enum ('n1', 'n2', 'n3');

create type valor.criticidade as enum ('verde', 'amarelo', 'vermelho');

create type valor.canal_interacao as enum (
  'reuniao_presencial', 'reuniao_online', 'ligacao', 'email',
  'whatsapp', 'evento', 'visita', 'outro'
);

-- ------------------------------------------------- contexto da sessão

-- Lê o contexto de duas fontes, na ordem: o parâmetro local app.<chave>,
-- usado em teste e em carga; e a claim do token, usada no Supabase.
-- O mesmo SQL roda nos dois lugares, sem ramificação.
-- A ordem importa e nao e arbitraria. A claim do token vem primeiro, sempre.
-- O parametro local so responde quando nao existe token, que e o caso do teste e
-- da carga administrativa. Assim nenhum caminho de aplicacao consegue sobrepor o
-- que o token afirma, nem por engano nem de proposito.
create or replace function valor.claim(chave text)
returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> chave, ''),
    nullif(current_setting('app.' || chave, true), '')
  );
$$;

create or replace function valor.inquilino_atual() returns uuid
language sql stable as $$ select nullif(valor.claim('inquilino_id'), '')::uuid $$;

create or replace function valor.usuario_atual() returns uuid
language sql stable as $$ select nullif(valor.claim('usuario_id'), '')::uuid $$;

create or replace function valor.perfil_atual() returns text
language sql stable as $$ select coalesce(valor.claim('perfil'), 'nenhum') $$;

create or replace function valor.parceiro_atual() returns uuid
language sql stable as $$ select nullif(valor.claim('parceiro_id'), '')::uuid $$;

create or replace function valor.eh_admin() returns boolean
language sql stable as $$ select valor.perfil_atual() in ('admin_master', 'emergencia') $$;

-- Quem enxerga margem, comissão de terceiros e custo de conselheiro.
create or replace function valor.ve_confidencial() returns boolean
language sql stable as $$
  select valor.perfil_atual() in ('admin_master', 'emergencia', 'lider', 'financeiro')
$$;

create or replace function valor.eh_parceiro() returns boolean
language sql stable as $$ select valor.perfil_atual() = 'parceiro' $$;

create or replace function valor.eh_conselheiro() returns boolean
language sql stable as $$ select valor.perfil_atual() = 'conselheiro' $$;

create or replace function valor.eh_participante() returns boolean
language sql stable as $$ select valor.perfil_atual() = 'participante' $$;

-- Quem e da casa, e nao gente de fora sentada numa cadeira ou indicando negocio.
-- Toda politica que existe para separar a casa do mundo externo usa esta funcao,
-- e nunca `not valor.eh_parceiro()` sozinho. O motivo foi aprendido na pratica:
-- quando o perfil `participante` entrou, toda politica escrita com `not
-- eh_parceiro()` passou a valer para ele sem que ninguem tivesse decidido isso,
-- inclusive as de escrita. Um perfil novo nao pode herdar permissao por omissao.
create or replace function valor.time_da_casa() returns boolean
language sql stable as $$
  select valor.perfil_atual() not in ('parceiro', 'participante')
$$;

-- Predicado que toda política de linha usa como primeiro filtro.
create or replace function valor.do_inquilino(alvo uuid) returns boolean
language sql stable as $$ select alvo = valor.inquilino_atual() $$;

-- ------------------------------------------------- carimbo de atualização

create or replace function valor.carimbar() returns trigger
language plpgsql as $$
begin
  new.atualizado_em := now();
  new.atualizado_por := valor.usuario_atual();
  return new;
end;
$$;

comment on function valor.claim(text) is
  'Lê o contexto da sessão. Local, por set_config. No Supabase, pela claim do token.';


-- ==========================================================================
-- 0002_inquilinos_e_usuarios.sql
-- ==========================================================================
-- 0002 · Inquilino, usuários, convites e configuração
-- Dono: orquestrador. Base compartilhada. Nenhum agente altera este arquivo.

create table valor.inquilinos (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  apelido       text not null unique,
  dominio       text,
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz,
  arquivado_em  timestamptz
);
comment on table valor.inquilinos is 'A empresa que usa a plataforma. A Felix é uma linha. Cada cliente white label é outra.';

create table valor.usuarios (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  auth_id        uuid unique,
  email          text not null,
  nome           text not null,
  perfil         valor.perfil_usuario not null,
  telefone       text,
  ativo          boolean not null default true,
  mfa_obrigatorio boolean not null default true,
  ultimo_acesso  timestamptz,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, email)
);
comment on column valor.usuarios.auth_id is 'Identidade no provedor de autenticação. Nulo enquanto o convite não for aceito.';
comment on column valor.usuarios.telefone is 'CONFIDENCIAL: o próprio usuário, o líder e o administrador.';

create table valor.convites (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  email          text not null,
  nome           text not null,
  perfil         valor.perfil_usuario not null,
  token_hash     text not null,
  expira_em      timestamptz not null default now() + interval '7 days',
  aceito_em      timestamptz,
  usuario_id     uuid references valor.usuarios(id),
  reenviado_em   timestamptz,
  reenvios       integer not null default 0,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on column valor.convites.token_hash is 'Guarda apenas o resumo do token. O token puro vive só no e-mail enviado.';

-- Configuração de inquilino em pares chave e valor, para trocar regra em tela
-- e não em código: meta do período, percentuais padrão, prazos de alerta.
create table valor.configuracoes (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  chave          text not null,
  valor          jsonb not null,
  rotulo         text not null,
  grupo          text not null default 'geral',
  editavel_por   valor.perfil_usuario not null default 'admin_master',
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, chave)
);

create index on valor.usuarios (inquilino_id, perfil) where arquivado_em is null;
create index on valor.convites (inquilino_id, email) where aceito_em is null;

create trigger carimbo before update on valor.usuarios for each row execute function valor.carimbar();
create trigger carimbo before update on valor.convites for each row execute function valor.carimbar();
create trigger carimbo before update on valor.configuracoes for each row execute function valor.carimbar();

alter table valor.inquilinos    enable row level security;
alter table valor.usuarios      enable row level security;
alter table valor.convites      enable row level security;
alter table valor.configuracoes enable row level security;

create policy inquilino_proprio on valor.inquilinos
  for select using (id = valor.inquilino_atual());

-- O time da casa enxerga a lista de colegas, com nome e perfil. Gente de fora
-- não: nem o parceiro, que só indica negócio, nem o participante, que ocupa
-- cadeira numa turma. Nenhum dos dois precisa conhecer o time por dentro.
create policy usuario_le on valor.usuarios for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy usuario_escreve on valor.usuarios for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy convite_admin on valor.convites for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy configuracao_le on valor.configuracoes for select
  using (valor.do_inquilino(inquilino_id));

create policy configuracao_escreve on valor.configuracoes for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());


-- ==========================================================================
-- 0003_nucleo_crm.sql
-- ==========================================================================
-- 0003 · Núcleo do CRM de Valor: oferta, conta, contato, negócio, papel, artefato, interação
-- Dono: orquestrador. Base compartilhada. Nenhum agente altera este arquivo.
-- A tabela valor.ofertas é criada aqui e semeada pelo agente de catálogo.
-- A coluna negocios.parceiro_id nasce sem chave estrangeira. A migração do PRM
-- acrescenta a restrição quando a tabela valor.parceiros existir.

create table valor.ofertas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  codigo         text not null,
  nome           text not null,
  familia        text not null,
  modalidade     valor.modalidade_oferta not null,
  niveis_aceitos valor.nivel_contrato[] not null default '{n1}',
  gera_turma     boolean not null default false,
  publico_alvo   text,
  estrutura      text,
  ativa          boolean not null default true,
  sugerida       boolean not null default true,
  ordem          integer not null default 100,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (inquilino_id, codigo)
);
comment on column valor.ofertas.sugerida is 'Oferta inativa continua no catálogo para histórico, mas não aparece como sugestão.';

create table valor.contas (
  id              uuid primary key default gen_random_uuid(),
  inquilino_id    uuid not null references valor.inquilinos(id) on delete restrict,
  nome            text not null,
  razao_social    text,
  cnpj            text,
  setor           text,
  porte           text,
  cidade          text,
  uf              char(2),
  site            text,
  tier            valor.tier_conta,
  tier_sugerido   valor.tier_conta,
  tier_confirmado_em timestamptz,
  prioridade      smallint check (prioridade between 1 and 3),
  power_of_x      smallint not null default 0,
  eh_cliente      boolean not null default false,
  eh_prospecto    boolean not null default true,
  eh_fornecedor   boolean not null default false,
  eh_parceiro     boolean not null default false,
  gerente_contas_id uuid references valor.usuarios(id),
  observacoes     text,
  criado_em       timestamptz not null default now(),
  criado_por      uuid,
  atualizado_em   timestamptz,
  atualizado_por  uuid,
  arquivado_em    timestamptz
);
comment on column valor.contas.power_of_x is 'Quantas linhas do portfólio esta conta já comprou. Alimenta a sugestão de tier.';
comment on column valor.contas.tier_sugerido is 'Calculado pela matriz do método. O tier vigente é sempre confirmado por gente.';

create table valor.contatos (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  nome           text not null,
  cargo          text,
  papel_decisao  text,
  email          text,
  telefone       text,
  linkedin       text,
  eh_principal   boolean not null default false,
  aniversario    date,
  observacoes    text,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on column valor.contatos.email is 'CONFIDENCIAL: quem tem papel na conta.';
comment on column valor.contatos.telefone is 'CONFIDENCIAL: quem tem papel na conta.';
comment on column valor.contatos.papel_decisao is 'Decisor, influenciador, usuário, guardião, patrocinador.';

create table valor.negocios (
  id                    uuid primary key default gen_random_uuid(),
  inquilino_id          uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id              uuid not null references valor.contas(id) on delete restrict,
  oferta_id             uuid references valor.ofertas(id),
  parceiro_id           uuid,
  titulo                text not null,
  descricao             text,
  fase                  smallint not null default 0 check (fase between 0 and 9),
  rota                  valor.rota_negocio not null default 'privada',
  origem                valor.origem_lead not null default 'outro',
  origem_detalhe        text,
  valor_total           numeric(14,2),
  valor_recorrente_mes  numeric(14,2),
  meses_recorrencia     smallint,
  nivel_contrato        valor.nivel_contrato not null default 'n1',
  probabilidade         valor.probabilidade,
  data_decisao_cliente  date,
  proximo_passo         text,
  proximo_passo_data    date,
  proximo_passo_responsavel uuid references valor.usuarios(id),
  ultima_interacao      date,
  entrou_na_fase_em     date not null default current_date,
  desfecho              valor.desfecho_negocio,
  motivo_desfecho       text,
  data_desfecho         date,
  concorrente           text,
  criado_em             timestamptz not null default now(),
  criado_por            uuid,
  atualizado_em         timestamptz,
  atualizado_por        uuid,
  arquivado_em          timestamptz
);
comment on column valor.negocios.valor_total is 'CONFIDENCIAL: time interno e o parceiro dono do negócio.';
comment on column valor.negocios.data_decisao_cliente is 'A data em que o cliente decide. Nunca chame de data de fechamento.';
comment on column valor.negocios.fase is '0 lead, 1 a 7 as fases do método, 9 arquivo. A fase 8 é a plataforma inteira.';
comment on column valor.negocios.probabilidade is 'Leitura qualitativa do time. Jamais usada para calcular previsão de receita.';

-- Rota pública, Lei 14.133. Só existe quando a rota do negócio é pública.
create table valor.negocios_rota_publica (
  negocio_id        uuid primary key references valor.negocios(id) on delete cascade,
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  identificador_pncp text,
  orgao             text,
  modalidade        text,
  fase_administrativa text,
  data_sessao       date,
  data_publicacao   date,
  desfecho_publico  text check (desfecho_publico in ('homologado','suspenso','impugnado','deserto','fracassado','revogado','anulado')),
  criado_em         timestamptz not null default now(),
  atualizado_em     timestamptz,
  atualizado_por    uuid
);

-- Quem faz o quê em cada negócio, e a partir de que fase entrou.
-- É esta tabela que modela o conselheiro entrando na Conexão de Valor.
create table valor.papeis_negocio (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  negocio_id     uuid not null references valor.negocios(id) on delete cascade,
  usuario_id     uuid references valor.usuarios(id),
  parceiro_id    uuid,
  papel          valor.papel_negocio not null,
  entrou_na_fase smallint not null default 1 check (entrou_na_fase between 0 and 9),
  principal      boolean not null default false,
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  check (usuario_id is not null or parceiro_id is not null)
);
comment on column valor.papeis_negocio.entrou_na_fase is
  'O conselheiro entra na fase 3, Conexão de Valor, e segue até o fim. Aqui isso fica registrado.';

create table valor.artefatos (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  negocio_id     uuid not null references valor.negocios(id) on delete cascade,
  tipo           valor.tipo_artefato not null,
  status         valor.status_artefato not null default 'rascunho',
  versao         smallint not null default 1,
  titulo         text,
  conteudo       jsonb not null default '{}',
  arquivo_url    text,
  validado_em    date,
  validado_por_contato uuid references valor.contatos(id),
  gerado_com_ia  boolean not null default false,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on column valor.artefatos.status is
  'Só validado_com_cliente conta para o forecast. Pronto por dentro não é compromisso do cliente.';

create table valor.interacoes (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id       uuid not null references valor.contas(id) on delete restrict,
  negocio_id     uuid references valor.negocios(id) on delete cascade,
  contato_id     uuid references valor.contatos(id),
  usuario_id     uuid references valor.usuarios(id),
  canal          valor.canal_interacao not null default 'reuniao_online',
  ocorrida_em    timestamptz not null default now(),
  assunto        text not null,
  resumo         text,
  transcricao_url text,
  restrita       boolean not null default false,
  gerado_com_ia  boolean not null default false,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on column valor.interacoes.restrita is
  'Conversa sobre pessoas do cliente. Fica fora de qualquer envio e de qualquer visão de parceiro.';

create index on valor.contas    (inquilino_id, tier) where arquivado_em is null;
create index on valor.contatos  (inquilino_id, conta_id) where arquivado_em is null;
create index on valor.negocios  (inquilino_id, fase) where arquivado_em is null;
create index on valor.negocios  (inquilino_id, parceiro_id) where arquivado_em is null;
create index on valor.negocios  (inquilino_id, data_decisao_cliente) where arquivado_em is null;
create index on valor.papeis_negocio (negocio_id, papel) where ativo;
create index on valor.artefatos (negocio_id, tipo, status);
create index on valor.interacoes (inquilino_id, conta_id, ocorrida_em desc);

create trigger carimbo before update on valor.ofertas    for each row execute function valor.carimbar();
create trigger carimbo before update on valor.contas     for each row execute function valor.carimbar();
create trigger carimbo before update on valor.contatos   for each row execute function valor.carimbar();
create trigger carimbo before update on valor.negocios   for each row execute function valor.carimbar();
create trigger carimbo before update on valor.papeis_negocio for each row execute function valor.carimbar();
create trigger carimbo before update on valor.artefatos  for each row execute function valor.carimbar();
create trigger carimbo before update on valor.interacoes for each row execute function valor.carimbar();

-- ------------------------------------------------------------ segurança

alter table valor.ofertas    enable row level security;
alter table valor.contas     enable row level security;
alter table valor.contatos   enable row level security;
alter table valor.negocios   enable row level security;
alter table valor.negocios_rota_publica enable row level security;
alter table valor.papeis_negocio enable row level security;
alter table valor.artefatos  enable row level security;
alter table valor.interacoes enable row level security;

-- O time da casa alcança o negócio. O parceiro alcança só o que ele indicou, e
-- a conta desse negócio. Quem não é nem uma coisa nem outra, como o
-- participante, não alcança nada daqui.
-- Roda com os direitos do dono e com caminho de busca fixo. Sem isso, a
-- politica de uma tabela que chama esta funcao entra em recursao infinita,
-- porque a leitura interna dispara a propria politica outra vez.
create or replace function valor.negocio_visivel(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, pg_catalog as $$
  select exists (
    select 1 from valor.negocios n
    where n.id = alvo
      and n.inquilino_id = valor.inquilino_atual()
      and ( valor.time_da_casa() or n.parceiro_id = valor.parceiro_atual() )
  );
$$;

create or replace function valor.conta_visivel(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, pg_catalog as $$
  select exists (
    select 1 from valor.contas c
    where c.id = alvo and c.inquilino_id = valor.inquilino_atual()
  ) and (
    valor.time_da_casa() or exists (
      select 1 from valor.negocios n
      where n.conta_id = alvo and n.parceiro_id = valor.parceiro_atual()
    )
  );
$$;

create policy oferta_le on valor.ofertas for select using (valor.do_inquilino(inquilino_id));
create policy oferta_escreve on valor.ofertas for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy conta_le on valor.contas for select
  using (inquilino_id = valor.inquilino_atual()
         and ( valor.time_da_casa()
               or exists (select 1 from valor.negocios n
                          where n.conta_id = contas.id
                            and n.inquilino_id = valor.inquilino_atual()
                            and n.parceiro_id = valor.parceiro_atual()) ));
create policy conta_escreve on valor.contas for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

-- O contato do cliente é da casa. O parceiro indica, não fica com a agenda, e o
-- participante está do lado do cliente, então também não fica.
create policy contato_le on valor.contatos for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy contato_escreve on valor.contatos for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy negocio_le on valor.negocios for select
  using (inquilino_id = valor.inquilino_atual()
         and ( valor.time_da_casa() or parceiro_id = valor.parceiro_atual() ));
create policy negocio_escreve on valor.negocios for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy rota_publica_le on valor.negocios_rota_publica for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy rota_publica_escreve on valor.negocios_rota_publica for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy papel_le on valor.papeis_negocio for select using (valor.negocio_visivel(negocio_id));
create policy papel_escreve on valor.papeis_negocio for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy artefato_le on valor.artefatos for select using (valor.negocio_visivel(negocio_id));
create policy artefato_escreve on valor.artefatos for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

-- A interação é registro comercial da casa, e gente de fora não a lê. A
-- restrita ainda estreita: nem o conselheiro de fora da conta chega nela.
create policy interacao_le on valor.interacoes for select
  using (valor.do_inquilino(inquilino_id) and not restrita and valor.time_da_casa()
         or valor.do_inquilino(inquilino_id) and restrita and valor.ve_confidencial());
-- A escrita vem separada em inserir e atualizar, e não como uma política `for
-- all`. O motivo é que no PostgreSQL a cláusula `using` de uma política `for
-- all` também vale para o select, e as políticas permissivas se somam. Enquanto
-- esta era `for all`, o `using` dela devolvia a interação restrita para todo o
-- time da casa e anulava o recorte de interacao_le: o conselheiro de fora da
-- conta lia a conversa reservada. Com `for insert` e `for update` a leitura
-- passa a sair só de interacao_le, que é onde a regra está escrita.
create policy interacao_insere on valor.interacoes for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy interacao_atualiza on valor.interacoes for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa()
         and (not restrita or valor.ve_confidencial()))
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());


-- ==========================================================================
-- 0004_prm_parceiros.sql
-- ==========================================================================
-- 0004 · PRM de Valor: parceiros, acesso ao portal e indicações
-- Dono: agente de PRM e Financeiro. Nenhum outro agente altera este arquivo.
--
-- Fecha a pendência deixada em 0003: as chaves estrangeiras de parceiro_id em
-- valor.negocios e em valor.papeis_negocio, que nasceram sem restrição porque a
-- tabela valor.parceiros ainda não existia.
--
-- Nenhuma política deste arquivo concede delete. Remover registro é preencher
-- arquivado_em, conforme o contrato técnico.

-- ------------------------------------------------------------- tipos do PRM

create type valor.parceiro_tipo as enum (
  'indicador', 'canal', 'consultor_associado', 'conselheiro_banco'
);

create type valor.parceiro_tipo_pessoa as enum ('fisica', 'juridica');

create type valor.parceiro_status as enum (
  'prospecto', 'em_credenciamento', 'ativo', 'suspenso', 'encerrado'
);

create type valor.indicacao_status as enum (
  'registrada', 'em_analise', 'aceita', 'recusada', 'duplicada', 'convertida', 'expirada'
);

-- ------------------------------------------------------------------ parceiros

create table valor.parceiros (
  id                uuid primary key default gen_random_uuid(),
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id          uuid references valor.contas(id),
  nome              text not null,
  razao_social      text,
  tipo_pessoa       valor.parceiro_tipo_pessoa not null default 'juridica',
  documento         text,
  tipo              valor.parceiro_tipo not null default 'indicador',
  status            valor.parceiro_status not null default 'prospecto',
  email_comercial   text,
  telefone_comercial text,
  cidade            text,
  uf                char(2),
  site              text,
  responsavel_interno_id uuid references valor.usuarios(id),
  credenciado_em    date,
  vigencia_inicio   date,
  vigencia_fim      date,
  contrato_parceria_url text,
  comissao_percentual_negociado numeric(6,4),
  prazo_protecao_dias integer not null default 90,
  condicoes_comerciais text,
  servicos          text[] not null default '{}',
  treinamentos_concluidos text[] not null default '{}',
  autoriza_divulgacao_site boolean not null default false,
  observacoes       text,
  criado_em         timestamptz not null default now(),
  criado_por        uuid,
  atualizado_em     timestamptz,
  atualizado_por    uuid,
  arquivado_em      timestamptz,
  unique (inquilino_id, documento),
  constraint parceiros_ativo_credenciado_ck
    check (status <> 'ativo' or credenciado_em is not null),
  constraint parceiros_vigencia_ck
    check (vigencia_fim is null or vigencia_inicio is null or vigencia_fim >= vigencia_inicio),
  constraint parceiros_prazo_protecao_ck
    check (prazo_protecao_dias between 1 and 1095),
  constraint parceiros_comissao_ck
    check (comissao_percentual_negociado is null or comissao_percentual_negociado >= 0)
);

comment on table valor.parceiros is
  'Pessoa física ou jurídica que indica negócio para a casa. O cadastro é interno, o portal é do parceiro.';
comment on column valor.parceiros.conta_id is
  'Preenchido quando o parceiro também existe como conta na base, para não duplicar o cadastro.';
comment on column valor.parceiros.documento is
  'CONFIDENCIAL: o próprio parceiro, o responsável interno, o líder, o financeiro e o administrador. CPF quando pessoa física, CNPJ quando pessoa jurídica.';
comment on column valor.parceiros.telefone_comercial is
  'CONFIDENCIAL: o próprio parceiro, o responsável interno, o líder e o administrador.';
comment on column valor.parceiros.comissao_percentual_negociado is
  'CONFIDENCIAL: o próprio parceiro, o líder, o financeiro e o administrador. Condição comercial própria, em pontos percentuais. Vale acima do percentual padrão do inquilino e abaixo de uma linha de escopo pessoa em valor.percentuais_padrao.';
comment on column valor.parceiros.prazo_protecao_dias is
  'Por quantos dias a indicação aceita reserva a conta a este parceiro. Padrão da casa: 90 dias. Cada indicação copia o prazo vigente no momento do registro.';
comment on column valor.parceiros.credenciado_em is
  'Data em que o credenciamento foi concluído. Parceiro ativo sem esta data não passa na restrição.';
comment on column valor.parceiros.condicoes_comerciais is
  'CONFIDENCIAL: o próprio parceiro, o líder, o financeiro e o administrador. Texto livre com o que foi combinado fora da tabela de percentuais.';

-- ---------------------------------------------- chaves estrangeiras pendentes

alter table valor.negocios
  add constraint negocios_parceiro_fk foreign key (parceiro_id) references valor.parceiros(id);

alter table valor.papeis_negocio
  add constraint papeis_negocio_parceiro_fk foreign key (parceiro_id) references valor.parceiros(id);

-- ---------------------------------------------- o login do parceiro no portal

create table valor.parceiros_usuarios (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  parceiro_id    uuid not null references valor.parceiros(id) on delete restrict,
  usuario_id     uuid not null references valor.usuarios(id) on delete restrict,
  principal      boolean not null default false,
  ativo          boolean not null default true,
  ultimo_acesso_portal timestamptz,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz,
  unique (parceiro_id, usuario_id)
);

comment on table valor.parceiros_usuarios is
  'Liga o usuário de perfil parceiro ao parceiro que ele representa. É esta linha que alimenta app.parceiro_id na sessão do portal.';
comment on column valor.parceiros_usuarios.principal is
  'O contato que responde pelo parceiro no portal. Um por parceiro, por convenção da tela.';

-- O perfil é validado por gatilho porque uma restrição de verificação não pode
-- consultar outra tabela.
create or replace function valor.validar_usuario_parceiro() returns trigger
language plpgsql as $$
declare
  v_perfil     valor.perfil_usuario;
  v_inquilino  uuid;
begin
  select u.perfil, u.inquilino_id into v_perfil, v_inquilino
    from valor.usuarios u
   where u.id = new.usuario_id;

  if v_perfil is null then
    raise exception 'Usuário % não existe, então não pode acessar o portal do parceiro.', new.usuario_id;
  end if;

  if v_perfil <> 'parceiro' then
    raise exception 'O acesso ao portal exige usuário de perfil parceiro. Perfil informado: %.', v_perfil;
  end if;

  if v_inquilino <> new.inquilino_id then
    raise exception 'O usuário pertence a outro inquilino, então o vínculo é inválido.';
  end if;

  return new;
end;
$$;

create trigger valida_perfil before insert or update on valor.parceiros_usuarios
  for each row execute function valor.validar_usuario_parceiro();

-- ----------------------------------------------------------------- indicações

create table valor.indicacoes (
  id                uuid primary key default gen_random_uuid(),
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  parceiro_id       uuid not null references valor.parceiros(id) on delete restrict,
  conta_id          uuid references valor.contas(id),
  conta_indicada_nome text not null,
  conta_indicada_documento text,
  conta_indicada_site text,
  conta_indicada_cidade text,
  conta_indicada_uf char(2),
  contato_nome      text not null,
  contato_cargo     text,
  contato_email     text,
  contato_telefone  text,
  oferta_id         uuid references valor.ofertas(id),
  contexto          text not null,
  necessidade_percebida text,
  analise           jsonb not null default '{}',
  status            valor.indicacao_status not null default 'registrada',
  analisado_por     uuid references valor.usuarios(id),
  decidido_em       timestamptz,
  motivo_recusa     text,
  conflito_com_negocio_id uuid references valor.negocios(id),
  aceita_em         date,
  prazo_protecao_dias integer not null default 90,
  protecao_expira_em date generated always as (aceita_em + prazo_protecao_dias) stored,
  negocio_id        uuid references valor.negocios(id),
  criado_em         timestamptz not null default now(),
  criado_por        uuid,
  atualizado_em     timestamptz,
  atualizado_por    uuid,
  arquivado_em      timestamptz,
  constraint indicacoes_prazo_protecao_ck
    check (prazo_protecao_dias between 1 and 1095),
  constraint indicacoes_aceite_ck
    check (status not in ('aceita', 'convertida', 'expirada') or aceita_em is not null),
  constraint indicacoes_conversao_ck
    check (status <> 'convertida' or negocio_id is not null),
  constraint indicacoes_recusa_ck
    check (status <> 'recusada' or motivo_recusa is not null)
);

comment on table valor.indicacoes is
  'O que o parceiro registra antes de virar negócio. A casa analisa, aceita ou recusa, e a decisão fica gravada com o motivo.';
comment on column valor.indicacoes.contexto is
  'Por que esta conta, o que o parceiro enxergou e que porta de entrada ele sugere.';
comment on column valor.indicacoes.analise is
  'Resultado da Análise de Oportunidade: momento, acesso, clareza, sinais, prontidão, faixa e porta de entrada.';
comment on column valor.indicacoes.contato_email is
  'CONFIDENCIAL: o parceiro que indicou e o time interno. Nunca sai para outro parceiro.';
comment on column valor.indicacoes.contato_telefone is
  'CONFIDENCIAL: o parceiro que indicou e o time interno. Nunca sai para outro parceiro.';
comment on column valor.indicacoes.prazo_protecao_dias is
  'Prazo de proteção desta indicação, copiado do cadastro do parceiro no registro. Padrão da casa: 90 dias.';
comment on column valor.indicacoes.protecao_expira_em is
  'Calculado: data do aceite mais o prazo de proteção. Depois desta data a conta deixa de ficar reservada ao parceiro.';
comment on column valor.indicacoes.conflito_com_negocio_id is
  'Preenchido quando a checagem encontra a conta indicada já no pipeline de outro. A decisão fica registrada com o motivo.';
comment on column valor.indicacoes.negocio_id is
  'O negócio gerado a partir da indicação aceita. A partir daí a comissão segue a vida do contrato.';

-- Uma conta aceita fica reservada a um único parceiro. A reserva é liberada
-- quando a expiração roda ou quando a indicação vira negócio.
create unique index indicacoes_reserva_unica
  on valor.indicacoes (inquilino_id, conta_id)
  where status = 'aceita' and conta_id is not null and arquivado_em is null;

create index on valor.indicacoes (inquilino_id, parceiro_id, status) where arquivado_em is null;
create index on valor.indicacoes (inquilino_id, status, protecao_expira_em) where arquivado_em is null;
create index on valor.parceiros (inquilino_id, status) where arquivado_em is null;
create index on valor.parceiros_usuarios (usuario_id) where ativo;

-- --------------------------------------------------- regra de proteção

-- Carimba a data do aceite assim que a indicação é aceita, para que o prazo de
-- proteção comece a contar sozinho.
create or replace function valor.carimbar_aceite_indicacao() returns trigger
language plpgsql as $$
begin
  if new.status in ('aceita', 'convertida') and new.aceita_em is null then
    new.aceita_em := current_date;
  end if;
  if new.status in ('aceita', 'recusada', 'duplicada', 'convertida') and new.decidido_em is null then
    new.decidido_em := now();
  end if;
  return new;
end;
$$;

create trigger carimba_aceite before insert or update on valor.indicacoes
  for each row execute function valor.carimbar_aceite_indicacao();

-- A indicação está protegida enquanto foi aceita e o prazo não venceu.
create or replace function valor.indicacao_protegida(alvo uuid) returns boolean
language sql stable as $$
  select exists (
    select 1 from valor.indicacoes i
     where i.id = alvo
       and i.arquivado_em is null
       and i.status = 'aceita'
       and i.protecao_expira_em >= current_date
  );
$$;

-- Devolve o parceiro que hoje tem a conta reservada, ou nulo quando ninguém tem.
create or replace function valor.parceiro_com_reserva(alvo_conta uuid) returns uuid
language sql stable as $$
  select i.parceiro_id
    from valor.indicacoes i
   where i.conta_id = alvo_conta
     and i.arquivado_em is null
     and i.status = 'aceita'
     and i.protecao_expira_em >= current_date
   order by i.aceita_em desc
   limit 1;
$$;

-- Rotina de expiração, para a tarefa diária. Devolve quantas indicações perderam
-- a proteção. É definidora de segurança porque a tarefa roda sem sessão de
-- usuário, e só alcança linha cujo prazo já venceu.
create or replace function valor.expirar_indicacoes() returns integer
language plpgsql security definer set search_path = valor, pg_temp as $$
declare
  v_total integer;
begin
  update valor.indicacoes i
     set status = 'expirada',
         atualizado_em = now()
   where i.arquivado_em is null
     and i.status = 'aceita'
     and i.negocio_id is null
     and i.protecao_expira_em < current_date;

  get diagnostics v_total = row_count;
  return v_total;
end;
$$;

comment on function valor.expirar_indicacoes() is
  'Libera a conta quando o prazo de proteção vence sem virar negócio. Roda uma vez por dia na tarefa agendada.';
comment on function valor.parceiro_com_reserva(uuid) is
  'Quem hoje tem a conta reservada. O CRM consulta antes de deixar outro parceiro registrar a mesma conta.';

-- ----------------------------------------------------------------- carimbos

create trigger carimbo before update on valor.parceiros
  for each row execute function valor.carimbar();
create trigger carimbo before update on valor.parceiros_usuarios
  for each row execute function valor.carimbar();
create trigger carimbo before update on valor.indicacoes
  for each row execute function valor.carimbar();

-- ---------------------------------------------------------------- segurança

alter table valor.parceiros          enable row level security;
alter table valor.parceiros_usuarios enable row level security;
alter table valor.indicacoes         enable row level security;

-- Quem cuida da rede de parceiros por dentro da casa.
create or replace function valor.gerencia_parceiros() returns boolean
language sql stable as $$
  select valor.perfil_atual() in ('admin_master', 'emergencia', 'lider', 'comercial', 'financeiro')
$$;

-- O parceiro enxerga apenas o próprio cadastro. Jamais outro parceiro, e quem
-- não é da casa nem é parceiro, como o participante, não enxerga cadastro algum.
create policy parceiro_le on valor.parceiros for select
  using (
    valor.do_inquilino(inquilino_id)
    and (valor.time_da_casa() or id = valor.parceiro_atual())
  );

create policy parceiro_insere on valor.parceiros for insert
  with check (valor.do_inquilino(inquilino_id) and valor.gerencia_parceiros());

create policy parceiro_atualiza on valor.parceiros for update
  using (valor.do_inquilino(inquilino_id) and valor.gerencia_parceiros())
  with check (valor.do_inquilino(inquilino_id) and valor.gerencia_parceiros());

-- O parceiro enxerga apenas os próprios usuários de portal.
create policy parceiro_usuario_le on valor.parceiros_usuarios for select
  using (
    valor.do_inquilino(inquilino_id)
    and (valor.time_da_casa() or parceiro_id = valor.parceiro_atual())
  );

create policy parceiro_usuario_insere on valor.parceiros_usuarios for insert
  with check (valor.do_inquilino(inquilino_id) and valor.gerencia_parceiros());

create policy parceiro_usuario_atualiza on valor.parceiros_usuarios for update
  using (valor.do_inquilino(inquilino_id) and valor.gerencia_parceiros())
  with check (valor.do_inquilino(inquilino_id) and valor.gerencia_parceiros());

-- O parceiro enxerga apenas as próprias indicações. Jamais a de outro parceiro,
-- e o participante não enxerga indicação nenhuma.
create policy indicacao_le on valor.indicacoes for select
  using (
    valor.do_inquilino(inquilino_id)
    and (valor.time_da_casa() or parceiro_id = valor.parceiro_atual())
  );

-- O parceiro registra a indicação em nome próprio, e ela nasce apenas como
-- registrada. Quem aceita ou recusa é a casa.
create policy indicacao_insere on valor.indicacoes for insert
  with check (
    valor.do_inquilino(inquilino_id)
    and (
      (valor.eh_parceiro() and parceiro_id = valor.parceiro_atual() and status = 'registrada')
      or (valor.time_da_casa() and valor.gerencia_parceiros())
    )
  );

create policy indicacao_atualiza on valor.indicacoes for update
  using (
    valor.do_inquilino(inquilino_id)
    and (
      (valor.eh_parceiro() and parceiro_id = valor.parceiro_atual() and status = 'registrada')
      or (valor.time_da_casa() and valor.gerencia_parceiros())
    )
  )
  with check (
    valor.do_inquilino(inquilino_id)
    and (
      (valor.eh_parceiro() and parceiro_id = valor.parceiro_atual() and status = 'registrada')
      or (valor.time_da_casa() and valor.gerencia_parceiros())
    )
  );


-- ==========================================================================
-- 0005_contratos_e_faturamento.sql
-- ==========================================================================
-- 0005 · Contratos de Valor, cronograma de parcelas e conselheiro do contrato
-- Dono: agente de PRM e Financeiro. Nenhum outro agente altera este arquivo.
--
-- O contrato nasce do negócio na fase 4, Confirmação de Compromisso. A parcela é
-- o cronograma financeiro desse contrato. A linha de conselheiro é quem entrega
-- aquele contrato e sob que remuneração.
--
-- O parceiro nunca enxerga contrato nem parcela. O conselheiro enxerga o
-- contrato das contas onde tem papel e a própria remuneração, nunca a de outro.
--
-- Nenhuma política deste arquivo concede delete. Remover registro é preencher
-- arquivado_em, conforme o contrato técnico.

-- --------------------------------------------------------- tipos do domínio

create type valor.contrato_situacao as enum (
  'minuta', 'pendente_assinatura', 'vigente', 'pausado', 'encerrado', 'cancelado', 'vencido'
);

create type valor.parcela_status as enum (
  'prevista', 'faturada', 'recebida', 'inadimplente', 'cancelada'
);

create type valor.conselheiro_modelo_remuneracao as enum (
  'percentual_contrato', 'fixo_mensal', 'por_reuniao'
);

-- ------------------------------------------------------------------ contratos

create table valor.contratos (
  id                uuid primary key default gen_random_uuid(),
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  conta_id          uuid not null references valor.contas(id) on delete restrict,
  negocio_id        uuid not null references valor.negocios(id) on delete restrict,
  oferta_id         uuid references valor.ofertas(id),
  contrato_anterior_id uuid references valor.contratos(id),
  numero            text not null,
  titulo            text,
  modalidade        valor.modalidade_oferta not null default 'pontual',
  nivel             valor.nivel_contrato not null default 'n1',
  situacao          valor.contrato_situacao not null default 'minuta',
  assinado          boolean not null default false,
  assinado_em       date,
  assinatura_provedor text,
  assinatura_id     text,
  documento_url     text,
  vigencia_inicio   date not null,
  vigencia_fim      date,
  meses_vigencia    smallint,
  valor_total       numeric(14,2),
  valor_mensal      numeric(14,2),
  dia_faturamento   smallint,
  indexador_reajuste text,
  mes_reajuste      smallint,
  imposto_percentual numeric(6,4),
  tem_participacao_resultados boolean not null default false,
  participacao_base text,
  participacao_percentual numeric(6,4),
  tem_equity        boolean not null default false,
  equity_tipo       text,
  equity_percentual numeric(6,4),
  cliff_meses       smallint,
  renovacao_automatica boolean not null default false,
  aviso_previo_dias integer not null default 30,
  clausula_saida    text,
  observacoes       text,
  criado_em         timestamptz not null default now(),
  criado_por        uuid,
  atualizado_em     timestamptz,
  atualizado_por    uuid,
  arquivado_em      timestamptz,
  unique (inquilino_id, numero),
  constraint contratos_vigencia_ck
    check (vigencia_fim is null or vigencia_fim >= vigencia_inicio),
  constraint contratos_assinatura_ck
    check (assinado = false or assinado_em is not null),
  constraint contratos_vigente_assinado_ck
    check (situacao <> 'vigente' or assinado),
  constraint contratos_renovacao_ck
    check (contrato_anterior_id is null or contrato_anterior_id <> id),
  constraint contratos_participacao_ck
    check (tem_participacao_resultados = false or participacao_percentual is not null),
  constraint contratos_equity_ck
    check (tem_equity = false or equity_percentual is not null),
  constraint contratos_nivel_n1_ck
    check (nivel <> 'n1' or (tem_participacao_resultados = false and tem_equity = false)),
  constraint contratos_nivel_n3_ck
    check (nivel <> 'n3' or tem_equity),
  constraint contratos_dia_faturamento_ck
    check (dia_faturamento is null or dia_faturamento between 1 and 28),
  constraint contratos_mes_reajuste_ck
    check (mes_reajuste is null or mes_reajuste between 1 and 12),
  constraint contratos_aviso_previo_ck
    check (aviso_previo_dias >= 0)
);

comment on table valor.contratos is
  'O Contrato de Valor, nascido do negócio na Confirmação de Compromisso. Nunca chame de pedido.';
comment on column valor.contratos.numero is
  'Número do contrato na casa, único por inquilino. Rótulo de tela: Número do contrato.';
comment on column valor.contratos.contrato_anterior_id is
  'Preenchido no contrato de renovação, apontando para o contrato que ele substitui. É por aqui que a comissão segue viva na renovação.';
comment on column valor.contratos.modalidade is
  'Pontual, recorrente ou pontual com sustentação, conforme o catálogo do portfólio.';
comment on column valor.contratos.nivel is
  'N1 honorário, N2 honorário mais participação nos resultados, N3 honorário, participação e equity.';
comment on column valor.contratos.valor_total is
  'CONFIDENCIAL: líder, financeiro, administrador e o conselheiro da conta. Nunca o parceiro.';
comment on column valor.contratos.valor_mensal is
  'CONFIDENCIAL: líder, financeiro, administrador e o conselheiro da conta. Nunca o parceiro.';
comment on column valor.contratos.imposto_percentual is
  'CONFIDENCIAL: líder, financeiro e administrador. Percentual de imposto deste contrato, em pontos percentuais. Nulo significa usar o padrão do inquilino, hoje 15.';
comment on column valor.contratos.participacao_base is
  'CONFIDENCIAL: líder, financeiro e administrador. Sobre o que a participação nos resultados incide.';
comment on column valor.contratos.participacao_percentual is
  'CONFIDENCIAL: líder, financeiro e administrador. Percentual de participação nos resultados, em pontos percentuais.';
comment on column valor.contratos.equity_tipo is
  'CONFIDENCIAL: líder, financeiro e administrador. Instrumento acordado, com validação de advogado e contador.';
comment on column valor.contratos.equity_percentual is
  'CONFIDENCIAL: líder, financeiro e administrador. Percentual de equity, em pontos percentuais.';
comment on column valor.contratos.cliff_meses is
  'CONFIDENCIAL: líder, financeiro e administrador. Carência em meses antes de o equity vestir.';
comment on column valor.contratos.clausula_saida is
  'CONFIDENCIAL: líder, financeiro e administrador. Condições de saída acordadas em contrato.';
comment on column valor.contratos.indexador_reajuste is
  'Índice de reajuste acordado, por exemplo IPCA ou IGPM, aplicado no mês de reajuste.';
comment on column valor.contratos.aviso_previo_dias is
  'Dias de aviso prévio para encerrar o contrato. Alimenta o alerta de renovação.';

-- Mantém contrato, negócio e conta coerentes, sem depender da tela.
create or replace function valor.validar_contrato_negocio() returns trigger
language plpgsql as $$
declare
  v_conta      uuid;
  v_inquilino  uuid;
begin
  select n.conta_id, n.inquilino_id into v_conta, v_inquilino
    from valor.negocios n
   where n.id = new.negocio_id;

  if v_conta is null then
    raise exception 'Negócio % não existe, então não gera contrato.', new.negocio_id;
  end if;

  if v_inquilino <> new.inquilino_id then
    raise exception 'O negócio pertence a outro inquilino, então o contrato é inválido.';
  end if;

  if new.conta_id is null then
    new.conta_id := v_conta;
  elsif new.conta_id <> v_conta then
    raise exception 'A conta do contrato precisa ser a mesma conta do negócio de origem.';
  end if;

  return new;
end;
$$;

create trigger valida_origem before insert or update on valor.contratos
  for each row execute function valor.validar_contrato_negocio();

-- ------------------------------------------------------------------ parcelas

create table valor.parcelas (
  id                uuid primary key default gen_random_uuid(),
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  contrato_id       uuid not null references valor.contratos(id) on delete restrict,
  numero            smallint not null default 1,
  competencia       date not null,
  vencimento        date not null,
  valor_bruto       numeric(14,2) not null,
  status            valor.parcela_status not null default 'prevista',
  faturada_em       date,
  recebida_em       date,
  nota_fiscal       text,
  nota_fiscal_emitida_em date,
  observacao        text,
  criado_em         timestamptz not null default now(),
  criado_por        uuid,
  atualizado_em     timestamptz,
  atualizado_por    uuid,
  arquivado_em      timestamptz,
  unique (contrato_id, numero),
  constraint parcelas_competencia_ck
    check (extract(day from competencia) = 1),
  constraint parcelas_valor_ck
    check (valor_bruto >= 0),
  constraint parcelas_recebimento_ck
    check (status <> 'recebida' or recebida_em is not null),
  constraint parcelas_numero_ck
    check (numero >= 1)
);

comment on table valor.parcelas is
  'O cronograma financeiro do contrato. Uma linha por competência, do previsto ao recebido.';
comment on column valor.parcelas.competencia is
  'Primeiro dia do mês de competência. A data de vencimento é outra coisa e mora na coluna ao lado.';
comment on column valor.parcelas.valor_bruto is
  'CONFIDENCIAL: líder, financeiro, administrador e o conselheiro da conta. Nunca o parceiro. Valor bruto da parcela, antes do imposto.';
comment on column valor.parcelas.nota_fiscal is
  'CONFIDENCIAL: líder, financeiro e administrador. Número da nota fiscal emitida.';
comment on column valor.parcelas.status is
  'Prevista, faturada, recebida, inadimplente ou cancelada. A comissão é apurada no recebimento.';

create index on valor.parcelas (inquilino_id, status, vencimento) where arquivado_em is null;
create index on valor.parcelas (contrato_id, competencia) where arquivado_em is null;
create index on valor.contratos (inquilino_id, situacao) where arquivado_em is null;
create index on valor.contratos (inquilino_id, conta_id) where arquivado_em is null;
create index on valor.contratos (contrato_anterior_id) where contrato_anterior_id is not null;

-- ------------------------------------------------- conselheiro do contrato

create table valor.contratos_conselheiros (
  id                uuid primary key default gen_random_uuid(),
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  contrato_id       uuid not null references valor.contratos(id) on delete restrict,
  usuario_id        uuid not null references valor.usuarios(id) on delete restrict,
  modelo            valor.conselheiro_modelo_remuneracao not null default 'percentual_contrato',
  percentual        numeric(6,4),
  valor_fixo_mensal numeric(14,2),
  valor_por_reuniao numeric(14,2),
  reunioes_previstas_mes smallint,
  vigencia_inicio   date not null default current_date,
  vigencia_fim      date,
  ativo             boolean not null default true,
  observacao        text,
  criado_em         timestamptz not null default now(),
  criado_por        uuid,
  atualizado_em     timestamptz,
  atualizado_por    uuid,
  arquivado_em      timestamptz,
  unique (contrato_id, usuario_id, vigencia_inicio),
  constraint contratos_conselheiros_vigencia_ck
    check (vigencia_fim is null or vigencia_fim >= vigencia_inicio),
  -- Os três modelos cabem na mesma tabela. Cada linha preenche o campo do seu
  -- modelo e deixa os outros dois vazios, para o cálculo nunca ficar ambíguo.
  constraint contratos_conselheiros_modelo_ck check (
    (modelo = 'percentual_contrato'
       and percentual is not null and valor_fixo_mensal is null and valor_por_reuniao is null)
    or (modelo = 'fixo_mensal'
       and valor_fixo_mensal is not null and percentual is null and valor_por_reuniao is null)
    or (modelo = 'por_reuniao'
       and valor_por_reuniao is not null and percentual is null and valor_fixo_mensal is null)
  ),
  constraint contratos_conselheiros_reunioes_ck
    check (modelo <> 'por_reuniao' or coalesce(reunioes_previstas_mes, 0) >= 0)
);

comment on table valor.contratos_conselheiros is
  'Quem entrega aquele contrato e sob que remuneração. Percentual, valor fixo mensal ou valor por reunião, os três cabem.';
comment on column valor.contratos_conselheiros.percentual is
  'CONFIDENCIAL: o próprio conselheiro, o líder, o financeiro e o administrador. Percentual sobre a base de comissão, em pontos percentuais.';
comment on column valor.contratos_conselheiros.valor_fixo_mensal is
  'CONFIDENCIAL: o próprio conselheiro, o líder, o financeiro e o administrador. Valor fixo por competência.';
comment on column valor.contratos_conselheiros.valor_por_reuniao is
  'CONFIDENCIAL: o próprio conselheiro, o líder, o financeiro e o administrador. Valor de cada reunião realizada.';
comment on column valor.contratos_conselheiros.reunioes_previstas_mes is
  'Quantidade prevista de reuniões no mês, usada enquanto o BRM não entrega a contagem de encontros realizados.';

create index on valor.contratos_conselheiros (usuario_id, ativo) where arquivado_em is null;
create index on valor.contratos_conselheiros (contrato_id) where ativo and arquivado_em is null;

-- ----------------------------------------------------------------- carimbos

create trigger carimbo before update on valor.contratos
  for each row execute function valor.carimbar();
create trigger carimbo before update on valor.parcelas
  for each row execute function valor.carimbar();
create trigger carimbo before update on valor.contratos_conselheiros
  for each row execute function valor.carimbar();

-- ---------------------------------------------------------------- segurança

alter table valor.contratos              enable row level security;
alter table valor.parcelas               enable row level security;
alter table valor.contratos_conselheiros enable row level security;

-- O conselheiro alcança o contrato das contas onde tem papel no negócio ou onde
-- está nomeado no próprio contrato. O parceiro não alcança contrato nenhum.
--
-- É definidora de segurança de propósito: a política de valor.contratos chama
-- esta função, e a função consulta valor.contratos. Sem a definição de
-- segurança, a política chamaria a si mesma a cada linha lida e a consulta
-- morreria por profundidade de pilha. A função devolve apenas verdadeiro ou
-- falso, então não abre nenhuma linha de dado para quem a chama.
create or replace function valor.contrato_visivel(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, pg_temp as $$
  select valor.time_da_casa() and exists (
    select 1
      from valor.contratos c
     where c.id = alvo
       and c.inquilino_id = valor.inquilino_atual()
       and (
         not valor.eh_conselheiro()
         or exists (
           select 1 from valor.contratos_conselheiros cc
            where cc.contrato_id = c.id
              and cc.usuario_id = valor.usuario_atual()
              and cc.arquivado_em is null
         )
         or exists (
           select 1 from valor.papeis_negocio pn
            join valor.negocios n on n.id = pn.negocio_id
           where n.conta_id = c.conta_id
             and pn.usuario_id = valor.usuario_atual()
             and pn.papel = 'conselheiro'
             and pn.ativo
             and pn.arquivado_em is null
         )
       )
  );
$$;

comment on function valor.contrato_visivel(uuid) is
  'Primeiro filtro de contrato e de parcela. Só o time da casa entra, então parceiro e participante saem fora sempre. O conselheiro entra só nas contas dele.';

create policy contrato_le on valor.contratos for select
  using (valor.contrato_visivel(id));

create policy contrato_insere on valor.contratos for insert
  with check (
    valor.do_inquilino(inquilino_id)
    and valor.time_da_casa()
    and (valor.ve_confidencial() or valor.perfil_atual() in ('comercial', 'gerente_contas'))
  );

create policy contrato_atualiza on valor.contratos for update
  using (
    valor.do_inquilino(inquilino_id)
    and valor.time_da_casa()
    and (valor.ve_confidencial() or valor.perfil_atual() in ('comercial', 'gerente_contas'))
  )
  with check (
    valor.do_inquilino(inquilino_id)
    and valor.time_da_casa()
    and (valor.ve_confidencial() or valor.perfil_atual() in ('comercial', 'gerente_contas'))
  );

-- A parcela acompanha a visibilidade do contrato. O parceiro nunca chega aqui.
create policy parcela_le on valor.parcelas for select
  using (valor.do_inquilino(inquilino_id) and valor.contrato_visivel(contrato_id));

create policy parcela_insere on valor.parcelas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

create policy parcela_atualiza on valor.parcelas for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

-- O conselheiro enxerga a própria remuneração, nunca a de outro conselheiro.
create policy conselheiro_remuneracao_le on valor.contratos_conselheiros for select
  using (
    valor.do_inquilino(inquilino_id)
    and valor.time_da_casa()
    and (valor.ve_confidencial() or usuario_id = valor.usuario_atual())
  );

create policy conselheiro_remuneracao_insere on valor.contratos_conselheiros for insert
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

create policy conselheiro_remuneracao_atualiza on valor.contratos_conselheiros for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());


-- ==========================================================================
-- 0006_comissoes_e_margem.sql
-- ==========================================================================
-- 0006 · Comissões, percentuais padrão e margem
-- Dono: agente de PRM e Financeiro. Nenhum outro agente altera este arquivo.
--
-- A conta da casa, nesta ordem exata:
--   1. valor da parcela                                    valor bruto
--   2. imposto                = valor bruto x 15%
--   3. base de comissão       = valor bruto menos imposto
--   4. comissão do vendedor   = base x 10%
--   5. comissão do parceiro   = base x 10%
--   6. custo do conselheiro   = conforme o contrato do conselheiro
--   7. margem                 = base menos comissões menos custo do conselheiro
--
-- Cada comissão de 10% equivale a 8,5% do bruto. As duas leituras ficam
-- gravadas na mesma linha, para o relatório do vendedor e o do dono não
-- divergirem nunca.
--
-- Percentual é sempre guardado em pontos percentuais: 15 significa 15%, 10
-- significa 10% e 8,5 significa 8,5%.
--
-- Nenhuma política deste arquivo concede delete. Cancelar comissão é mudar o
-- status para cancelada. Remover registro é preencher arquivado_em.

-- --------------------------------------------------------- tipos do domínio

create type valor.percentual_escopo as enum ('inquilino', 'oferta', 'contrato', 'pessoa');

create type valor.comissao_beneficiario as enum ('vendedor_interno', 'parceiro', 'conselheiro');

create type valor.comissao_status as enum ('prevista', 'apurada', 'paga', 'cancelada');

-- ------------------------------------------------------- percentuais padrão

create table valor.percentuais_padrao (
  id                uuid primary key default gen_random_uuid(),
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  escopo            valor.percentual_escopo not null default 'inquilino',
  escopo_id         uuid,
  rotulo            text,
  imposto_percentual numeric(6,4),
  comissao_vendedor_percentual numeric(6,4),
  comissao_parceiro_percentual numeric(6,4),
  vigencia_inicio   date not null default current_date,
  vigencia_fim      date,
  criado_em         timestamptz not null default now(),
  criado_por        uuid,
  atualizado_em     timestamptz,
  atualizado_por    uuid,
  arquivado_em      timestamptz,
  constraint percentuais_padrao_escopo_ck check (
    (escopo = 'inquilino' and escopo_id is null)
    or (escopo <> 'inquilino' and escopo_id is not null)
  ),
  constraint percentuais_padrao_vigencia_ck
    check (vigencia_fim is null or vigencia_fim >= vigencia_inicio),
  constraint percentuais_padrao_algum_valor_ck check (
    imposto_percentual is not null
    or comissao_vendedor_percentual is not null
    or comissao_parceiro_percentual is not null
  ),
  constraint percentuais_padrao_faixa_ck check (
    coalesce(imposto_percentual, 0) >= 0
    and coalesce(comissao_vendedor_percentual, 0) >= 0
    and coalesce(comissao_parceiro_percentual, 0) >= 0
  )
);

comment on table valor.percentuais_padrao is
  'Onde a regra de percentual vive, para trocar em tela e não em código. O histórico fica, nada é sobrescrito.';
comment on column valor.percentuais_padrao.escopo is
  'Inquilino, oferta, contrato ou pessoa. A busca resolve na ordem pessoa, contrato, oferta, inquilino.';
comment on column valor.percentuais_padrao.escopo_id is
  'A oferta, o contrato ou a pessoa a que esta linha se aplica. Nulo quando o escopo é o inquilino.';
comment on column valor.percentuais_padrao.imposto_percentual is
  'CONFIDENCIAL: líder, financeiro e administrador. Padrão da casa: 15 pontos percentuais.';
comment on column valor.percentuais_padrao.comissao_vendedor_percentual is
  'Padrão da casa: 10 pontos percentuais sobre a base de comissão.';
comment on column valor.percentuais_padrao.comissao_parceiro_percentual is
  'Padrão da casa: 10 pontos percentuais sobre a base de comissão.';
comment on column valor.percentuais_padrao.vigencia_fim is
  'Nulo significa vigente por prazo indeterminado. Para trocar o percentual, feche a linha antiga e abra outra.';

create unique index percentuais_padrao_unico
  on valor.percentuais_padrao (inquilino_id, escopo, coalesce(escopo_id, inquilino_id), vigencia_inicio)
  where arquivado_em is null;

create index on valor.percentuais_padrao (inquilino_id, escopo, escopo_id) where arquivado_em is null;

-- Resolve o percentual na precedência pessoa, contrato, oferta, inquilino, e
-- devolve o primeiro que casar na data pedida. Devolve nulo quando não há
-- nenhuma linha vigente, e quem chama decide o que fazer com isso.
create or replace function valor.percentual_vigente(
  p_inquilino uuid,
  p_tipo      text,
  p_data      date default current_date,
  p_pessoa    uuid default null,
  p_contrato  uuid default null,
  p_oferta    uuid default null
) returns numeric
language plpgsql stable as $$
declare
  v_valor numeric(6,4);
  v_data  date := coalesce(p_data, current_date);
begin
  if p_tipo not in ('imposto', 'comissao_vendedor', 'comissao_parceiro') then
    raise exception 'Tipo de percentual desconhecido: %. Use imposto, comissao_vendedor ou comissao_parceiro.', p_tipo;
  end if;

  select case p_tipo
           when 'imposto' then pp.imposto_percentual
           when 'comissao_vendedor' then pp.comissao_vendedor_percentual
           else pp.comissao_parceiro_percentual
         end
    into v_valor
    from valor.percentuais_padrao pp
   where pp.inquilino_id = p_inquilino
     and pp.arquivado_em is null
     and v_data >= pp.vigencia_inicio
     and (pp.vigencia_fim is null or v_data <= pp.vigencia_fim)
     and (
          (pp.escopo = 'pessoa'   and p_pessoa   is not null and pp.escopo_id = p_pessoa)
       or (pp.escopo = 'contrato' and p_contrato is not null and pp.escopo_id = p_contrato)
       or (pp.escopo = 'oferta'   and p_oferta   is not null and pp.escopo_id = p_oferta)
       or (pp.escopo = 'inquilino')
     )
     and case p_tipo
           when 'imposto' then pp.imposto_percentual
           when 'comissao_vendedor' then pp.comissao_vendedor_percentual
           else pp.comissao_parceiro_percentual
         end is not null
   order by case pp.escopo
              when 'pessoa' then 1
              when 'contrato' then 2
              when 'oferta' then 3
              else 4
            end,
            pp.vigencia_inicio desc
   limit 1;

  return v_valor;
end;
$$;

comment on function valor.percentual_vigente(uuid, text, date, uuid, uuid, uuid) is
  'Percentual vigente na precedência pessoa, contrato, oferta, inquilino. Devolve o primeiro que casar.';

-- O imposto do contrato: o que estiver no próprio contrato vence, e na falta
-- dele vale o percentual vigente do inquilino.
create or replace function valor.imposto_percentual_do_contrato(
  p_contrato uuid,
  p_data     date default current_date
) returns numeric
language plpgsql stable as $$
declare
  v_contrato valor.contratos%rowtype;
  v_pct      numeric(6,4);
begin
  select * into v_contrato from valor.contratos c where c.id = p_contrato;
  if not found then
    raise exception 'Contrato % não encontrado.', p_contrato;
  end if;

  if v_contrato.imposto_percentual is not null then
    return v_contrato.imposto_percentual;
  end if;

  v_pct := valor.percentual_vigente(
    v_contrato.inquilino_id, 'imposto', coalesce(p_data, current_date),
    null, v_contrato.id, v_contrato.oferta_id
  );

  if v_pct is null then
    raise exception 'Não há percentual de imposto vigente para o contrato % na data %. Cadastre a linha de escopo inquilino em valor.percentuais_padrao.',
      p_contrato, coalesce(p_data, current_date);
  end if;

  return v_pct;
end;
$$;

-- ------------------------------------------------------------------ comissões

create table valor.comissoes (
  id                uuid primary key default gen_random_uuid(),
  inquilino_id      uuid not null references valor.inquilinos(id) on delete restrict,
  beneficiario_tipo valor.comissao_beneficiario not null,
  usuario_id        uuid references valor.usuarios(id),
  parceiro_id       uuid references valor.parceiros(id),
  beneficiario_id   uuid generated always as (coalesce(usuario_id, parceiro_id)) stored,
  negocio_id        uuid references valor.negocios(id),
  contrato_id       uuid not null references valor.contratos(id) on delete restrict,
  parcela_id        uuid not null references valor.parcelas(id) on delete restrict,
  valor_bruto       numeric(14,2) not null,
  imposto_percentual numeric(6,4) not null,
  imposto_valor     numeric(14,2) not null,
  base_calculo      numeric(14,2) not null,
  percentual        numeric(6,4),
  valor             numeric(14,2) not null,
  percentual_efetivo_sobre_bruto numeric(6,4)
    generated always as (round(valor * 100 / nullif(valor_bruto, 0), 4)) stored,
  status            valor.comissao_status not null default 'prevista',
  competencia       date not null,
  pago_em           date,
  observacao        text,
  criado_em         timestamptz not null default now(),
  criado_por        uuid,
  atualizado_em     timestamptz,
  atualizado_por    uuid,
  arquivado_em      timestamptz,
  unique (parcela_id, beneficiario_tipo, beneficiario_id),
  constraint comissoes_beneficiario_ck check (
    (beneficiario_tipo = 'parceiro' and parceiro_id is not null and usuario_id is null)
    or (beneficiario_tipo in ('vendedor_interno', 'conselheiro')
        and usuario_id is not null and parceiro_id is null)
  ),
  constraint comissoes_valor_ck
    check (valor >= 0 and valor <= valor_bruto),
  constraint comissoes_base_ck
    check (base_calculo = valor_bruto - imposto_valor),
  constraint comissoes_pagamento_ck
    check (status <> 'paga' or pago_em is not null),
  constraint comissoes_competencia_ck
    check (extract(day from competencia) = 1)
);

comment on table valor.comissoes is
  'Uma linha por beneficiário e por parcela. Serve ao vendedor interno, ao parceiro e ao conselheiro, com a mesma régua de cálculo aberto.';
comment on column valor.comissoes.beneficiario_tipo is
  'Vendedor interno, parceiro ou conselheiro. Quando há vendedor e parceiro no mesmo negócio, nascem duas linhas, cada uma com 10% sobre a mesma base líquida.';
comment on column valor.comissoes.beneficiario_id is
  'Calculado: o usuário ou o parceiro da linha. Garante uma linha por beneficiário em cada parcela, e é o que torna a apuração idempotente.';
comment on column valor.comissoes.valor_bruto is
  'CONFIDENCIAL: o próprio beneficiário, o líder, o financeiro e o administrador. Valor bruto da parcela de origem.';
comment on column valor.comissoes.imposto_percentual is
  'CONFIDENCIAL: o próprio beneficiário, o líder, o financeiro e o administrador. Padrão da casa: 15 pontos percentuais.';
comment on column valor.comissoes.imposto_valor is
  'CONFIDENCIAL: o próprio beneficiário, o líder, o financeiro e o administrador. Valor bruto vezes o percentual de imposto.';
comment on column valor.comissoes.base_calculo is
  'CONFIDENCIAL: o próprio beneficiário, o líder, o financeiro e o administrador. Valor bruto menos imposto. É sobre isto que a comissão incide.';
comment on column valor.comissoes.percentual is
  'Percentual acordado sobre a base, em pontos percentuais. Nulo quando o conselheiro é pago por valor fixo ou por reunião.';
comment on column valor.comissoes.valor is
  'CONFIDENCIAL: o próprio beneficiário, o líder, o financeiro e o administrador. Base vezes percentual, ou o valor combinado com o conselheiro.';
comment on column valor.comissoes.percentual_efetivo_sobre_bruto is
  'Calculado: o mesmo dinheiro lido sobre o bruto. Com 10% sobre a base e 15% de imposto, dá 8,5%. É o número que faz o relatório do dono bater com o do vendedor.';
comment on column valor.comissoes.competencia is
  'Primeiro dia do mês de competência da parcela de origem.';
comment on column valor.comissoes.pago_em is
  'Data em que o beneficiário recebeu. Linha paga não é mais recalculada pela apuração.';
comment on constraint comissoes_valor_ck on valor.comissoes is
  'Nenhuma comissão e nenhum custo de conselheiro passa do bruto da parcela. Se passar, o cadastro de remuneração está errado e a apuração para com erro claro.';

create index on valor.comissoes (inquilino_id, beneficiario_tipo, competencia) where arquivado_em is null;
create index on valor.comissoes (usuario_id, competencia) where usuario_id is not null;
create index on valor.comissoes (parceiro_id, competencia) where parceiro_id is not null;
create index on valor.comissoes (contrato_id, status) where arquivado_em is null;

create trigger carimbo before update on valor.percentuais_padrao
  for each row execute function valor.carimbar();
create trigger carimbo before update on valor.comissoes
  for each row execute function valor.carimbar();

-- ------------------------------------------------------------- apuração

-- Gera ou atualiza as linhas de comissão de uma parcela. Rodar duas vezes não
-- duplica nada: a chave parcela mais beneficiário resolve o conflito, e a linha
-- já paga nunca é reescrita.
-- É definidora de segurança porque a apuração precisa enxergar o negócio
-- inteiro, e não o recorte que o operador enxerga. Comissão calculada sobre
-- meia verdade seria comissão errada. A permissão de quem chama é conferida na
-- primeira linha do corpo, e a função não devolve dado nenhum, só a contagem de
-- linhas geradas.
create or replace function valor.apurar_comissoes(parcela_id uuid)
returns integer
language plpgsql security definer set search_path = valor, pg_temp as $$
-- O argumento se chama parcela_id, igual à coluna de valor.comissoes. Onde a
-- coluna existe, como na cláusula de conflito, vale a coluna. Onde ela não
-- existe, como na busca da parcela, vale o argumento. O argumento é copiado
-- para v_parcela_id logo no início e é ele que o resto da função usa.
#variable_conflict use_column
declare
  v_parcela       valor.parcelas%rowtype;
  v_contrato      valor.contratos%rowtype;
  v_negocio       valor.negocios%rowtype;
  v_conselheiro   valor.contratos_conselheiros%rowtype;
  v_parcela_id    uuid;
  v_imposto_pct   numeric(6,4);
  v_imposto_valor numeric(14,2);
  v_base          numeric(14,2);
  v_status        valor.comissao_status;
  v_vendedor      uuid;
  v_parceiro      uuid;
  v_negociado     numeric(6,4);
  v_pct_pessoa    numeric(6,4);
  v_pct           numeric(6,4);
  v_valor         numeric(14,2);
  v_id            uuid;
  v_mantidas      uuid[] := '{}';
begin
  if not valor.ve_confidencial() then
    raise exception 'Apurar comissão é privativo do financeiro, do líder e do administrador. Perfil da sessão: %.',
      valor.perfil_atual();
  end if;

  select * into v_parcela from valor.parcelas p where p.id = parcela_id;
  if not found then
    raise exception 'Parcela % não encontrada.', parcela_id;
  end if;
  v_parcela_id := v_parcela.id;

  select * into v_contrato from valor.contratos c where c.id = v_parcela.contrato_id;
  select * into v_negocio  from valor.negocios  n where n.id = v_contrato.negocio_id;

  -- Parcela cancelada não gera comissão, e o que já existia fica cancelado.
  if v_parcela.status = 'cancelada' then
    update valor.comissoes k
       set status = 'cancelada',
           observacao = 'Cancelada porque a parcela de origem foi cancelada.'
     where k.parcela_id = v_parcela_id
       and k.status <> 'paga';
    return 0;
  end if;

  v_imposto_pct   := valor.imposto_percentual_do_contrato(v_contrato.id, v_parcela.competencia);
  v_imposto_valor := round(v_parcela.valor_bruto * v_imposto_pct / 100, 2);
  v_base          := v_parcela.valor_bruto - v_imposto_valor;

  -- A apuração acontece no recebimento. Antes disso a linha existe como
  -- previsão, que é o que o portal do parceiro mostra como estimativa.
  if v_parcela.status = 'recebida' then
    v_status := 'apurada';
  else
    v_status := 'prevista';
  end if;

  -- ------------------------------------------------ comissão do vendedor
  select pn.usuario_id into v_vendedor
    from valor.papeis_negocio pn
   where pn.negocio_id = v_negocio.id
     and pn.papel = 'gerente_contas'
     and pn.ativo
     and pn.usuario_id is not null
     and pn.arquivado_em is null
   order by pn.principal desc, pn.criado_em
   limit 1;

  if v_vendedor is null then
    select c.gerente_contas_id into v_vendedor
      from valor.contas c where c.id = v_contrato.conta_id;
  end if;

  if v_vendedor is not null then
    v_pct := valor.percentual_vigente(
      v_contrato.inquilino_id, 'comissao_vendedor', v_parcela.competencia,
      v_vendedor, v_contrato.id, v_contrato.oferta_id
    );
    if v_pct is null then
      raise exception 'Não há percentual de comissão de vendedor vigente para o contrato % na competência %.',
        v_contrato.id, v_parcela.competencia;
    end if;
    v_valor := round(v_base * v_pct / 100, 2);

    insert into valor.comissoes as k (
      inquilino_id, beneficiario_tipo, usuario_id, negocio_id, contrato_id, parcela_id,
      valor_bruto, imposto_percentual, imposto_valor, base_calculo, percentual, valor,
      status, competencia, criado_por
    ) values (
      v_contrato.inquilino_id, 'vendedor_interno', v_vendedor, v_negocio.id, v_contrato.id, v_parcela_id,
      v_parcela.valor_bruto, v_imposto_pct, v_imposto_valor, v_base, v_pct, v_valor,
      v_status, v_parcela.competencia, valor.usuario_atual()
    )
    on conflict (parcela_id, beneficiario_tipo, beneficiario_id) do update set
      valor_bruto        = case when k.status = 'paga' then k.valor_bruto        else excluded.valor_bruto end,
      imposto_percentual = case when k.status = 'paga' then k.imposto_percentual else excluded.imposto_percentual end,
      imposto_valor      = case when k.status = 'paga' then k.imposto_valor      else excluded.imposto_valor end,
      base_calculo       = case when k.status = 'paga' then k.base_calculo       else excluded.base_calculo end,
      percentual         = case when k.status = 'paga' then k.percentual         else excluded.percentual end,
      valor              = case when k.status = 'paga' then k.valor              else excluded.valor end,
      status             = case when k.status = 'paga' then k.status             else excluded.status end,
      competencia        = case when k.status = 'paga' then k.competencia        else excluded.competencia end,
      negocio_id         = excluded.negocio_id
    returning k.id into v_id;

    v_mantidas := v_mantidas || v_id;
  end if;

  -- ------------------------------------------------- comissão do parceiro
  v_parceiro := v_negocio.parceiro_id;

  if v_parceiro is not null then
    -- Precedência do parceiro: linha de escopo pessoa, depois a condição
    -- comercial própria do cadastro, depois contrato, oferta e inquilino.
    select pp.comissao_parceiro_percentual into v_pct_pessoa
      from valor.percentuais_padrao pp
     where pp.inquilino_id = v_contrato.inquilino_id
       and pp.escopo = 'pessoa'
       and pp.escopo_id = v_parceiro
       and pp.arquivado_em is null
       and pp.comissao_parceiro_percentual is not null
       and v_parcela.competencia >= pp.vigencia_inicio
       and (pp.vigencia_fim is null or v_parcela.competencia <= pp.vigencia_fim)
     order by pp.vigencia_inicio desc
     limit 1;

    select p.comissao_percentual_negociado into v_negociado
      from valor.parceiros p where p.id = v_parceiro;

    v_pct := coalesce(
      v_pct_pessoa,
      v_negociado,
      valor.percentual_vigente(
        v_contrato.inquilino_id, 'comissao_parceiro', v_parcela.competencia,
        null, v_contrato.id, v_contrato.oferta_id
      )
    );
    if v_pct is null then
      raise exception 'Não há percentual de comissão de parceiro vigente para o contrato % na competência %.',
        v_contrato.id, v_parcela.competencia;
    end if;
    v_valor := round(v_base * v_pct / 100, 2);

    insert into valor.comissoes as k (
      inquilino_id, beneficiario_tipo, parceiro_id, negocio_id, contrato_id, parcela_id,
      valor_bruto, imposto_percentual, imposto_valor, base_calculo, percentual, valor,
      status, competencia, criado_por
    ) values (
      v_contrato.inquilino_id, 'parceiro', v_parceiro, v_negocio.id, v_contrato.id, v_parcela_id,
      v_parcela.valor_bruto, v_imposto_pct, v_imposto_valor, v_base, v_pct, v_valor,
      v_status, v_parcela.competencia, valor.usuario_atual()
    )
    on conflict (parcela_id, beneficiario_tipo, beneficiario_id) do update set
      valor_bruto        = case when k.status = 'paga' then k.valor_bruto        else excluded.valor_bruto end,
      imposto_percentual = case when k.status = 'paga' then k.imposto_percentual else excluded.imposto_percentual end,
      imposto_valor      = case when k.status = 'paga' then k.imposto_valor      else excluded.imposto_valor end,
      base_calculo       = case when k.status = 'paga' then k.base_calculo       else excluded.base_calculo end,
      percentual         = case when k.status = 'paga' then k.percentual         else excluded.percentual end,
      valor              = case when k.status = 'paga' then k.valor              else excluded.valor end,
      status             = case when k.status = 'paga' then k.status             else excluded.status end,
      competencia        = case when k.status = 'paga' then k.competencia        else excluded.competencia end,
      negocio_id         = excluded.negocio_id
    returning k.id into v_id;

    v_mantidas := v_mantidas || v_id;
  end if;

  -- ----------------------------------------------- custo dos conselheiros
  for v_conselheiro in
    select cc.*
      from valor.contratos_conselheiros cc
     where cc.contrato_id = v_contrato.id
       and cc.ativo
       and cc.arquivado_em is null
       and v_parcela.competencia >= date_trunc('month', cc.vigencia_inicio)::date
       and (cc.vigencia_fim is null
            or v_parcela.competencia <= date_trunc('month', cc.vigencia_fim)::date)
     order by cc.vigencia_inicio
  loop
    if v_conselheiro.modelo = 'percentual_contrato' then
      v_pct   := v_conselheiro.percentual;
      v_valor := round(v_base * v_pct / 100, 2);
    elsif v_conselheiro.modelo = 'fixo_mensal' then
      v_pct   := null;
      v_valor := v_conselheiro.valor_fixo_mensal;
    else
      v_pct   := null;
      v_valor := round(v_conselheiro.valor_por_reuniao * coalesce(v_conselheiro.reunioes_previstas_mes, 0), 2);
    end if;

    insert into valor.comissoes as k (
      inquilino_id, beneficiario_tipo, usuario_id, negocio_id, contrato_id, parcela_id,
      valor_bruto, imposto_percentual, imposto_valor, base_calculo, percentual, valor,
      status, competencia, criado_por
    ) values (
      v_contrato.inquilino_id, 'conselheiro', v_conselheiro.usuario_id, v_negocio.id, v_contrato.id, v_parcela_id,
      v_parcela.valor_bruto, v_imposto_pct, v_imposto_valor, v_base, v_pct, v_valor,
      v_status, v_parcela.competencia, valor.usuario_atual()
    )
    on conflict (parcela_id, beneficiario_tipo, beneficiario_id) do update set
      valor_bruto        = case when k.status = 'paga' then k.valor_bruto        else excluded.valor_bruto end,
      imposto_percentual = case when k.status = 'paga' then k.imposto_percentual else excluded.imposto_percentual end,
      imposto_valor      = case when k.status = 'paga' then k.imposto_valor      else excluded.imposto_valor end,
      base_calculo       = case when k.status = 'paga' then k.base_calculo       else excluded.base_calculo end,
      percentual         = case when k.status = 'paga' then k.percentual         else excluded.percentual end,
      valor              = case when k.status = 'paga' then k.valor              else excluded.valor end,
      status             = case when k.status = 'paga' then k.status             else excluded.status end,
      competencia        = case when k.status = 'paga' then k.competencia        else excluded.competencia end,
      negocio_id         = excluded.negocio_id
    returning k.id into v_id;

    v_mantidas := v_mantidas || v_id;
  end loop;

  -- Quem saiu do negócio deixa de ter linha viva nesta parcela. A linha não é
  -- apagada: vira cancelada, com o motivo escrito.
  update valor.comissoes k
     set status = 'cancelada',
         observacao = 'Cancelada na reapuração: o beneficiário não consta mais neste negócio ou neste contrato.'
   where k.parcela_id = v_parcela_id
     and k.status not in ('paga', 'cancelada')
     and not (k.id = any (v_mantidas));

  return coalesce(array_length(v_mantidas, 1), 0);
end;
$$;

comment on function valor.apurar_comissoes(uuid) is
  'Apura as comissões de uma parcela. Idempotente: rodar duas vezes não duplica nada e não reescreve linha já paga.';

-- A apuração dispara sozinha no recebimento da parcela.
create or replace function valor.apurar_no_recebimento() returns trigger
language plpgsql as $$
begin
  perform valor.apurar_comissoes(new.id);
  return null;
end;
$$;

create trigger apura_no_recebimento after insert or update on valor.parcelas
  for each row when (new.status = 'recebida')
  execute function valor.apurar_no_recebimento();

-- ------------------------------------------------------------------- margem

-- Bruto, imposto, comissões, custo de conselheiro e margem, por contrato.
-- A cláusula de guarda deixa a visão vazia para quem não pode ver margem, e o
-- modo invocador mantém a política de linha das tabelas de origem valendo.
create view valor.margem_contrato
with (security_invoker = true, security_barrier = true) as
with faturamento as (
  select p.contrato_id,
         sum(p.valor_bruto) as valor_bruto,
         sum(round(p.valor_bruto
                   * valor.imposto_percentual_do_contrato(p.contrato_id, p.competencia)
                   / 100, 2)) as imposto_valor
    from valor.parcelas p
   where p.status <> 'cancelada'
     and p.arquivado_em is null
   group by p.contrato_id
),
apurado as (
  select k.contrato_id,
         coalesce(sum(k.valor) filter (where k.beneficiario_tipo = 'vendedor_interno'), 0) as comissao_vendedor,
         coalesce(sum(k.valor) filter (where k.beneficiario_tipo = 'parceiro'), 0) as comissao_parceiro,
         coalesce(sum(k.valor) filter (where k.beneficiario_tipo = 'conselheiro'), 0) as custo_conselheiro
    from valor.comissoes k
   where k.status <> 'cancelada'
     and k.arquivado_em is null
   group by k.contrato_id
),
consolidado as (
  select c.id as contrato_id,
         c.inquilino_id,
         c.numero,
         c.conta_id,
         c.situacao,
         coalesce(f.valor_bruto, 0) as valor_bruto,
         coalesce(f.imposto_valor, 0) as imposto_valor,
         coalesce(f.valor_bruto, 0) - coalesce(f.imposto_valor, 0) as base_calculo,
         coalesce(a.comissao_vendedor, 0) as comissao_vendedor,
         coalesce(a.comissao_parceiro, 0) as comissao_parceiro,
         coalesce(a.custo_conselheiro, 0) as custo_conselheiro
    from valor.contratos c
    left join faturamento f on f.contrato_id = c.id
    left join apurado a on a.contrato_id = c.id
   where c.arquivado_em is null
     and valor.ve_confidencial()
)
select s.*,
       s.base_calculo - s.comissao_vendedor - s.comissao_parceiro - s.custo_conselheiro as margem,
       round((s.base_calculo - s.comissao_vendedor - s.comissao_parceiro - s.custo_conselheiro)
             * 100 / nullif(s.valor_bruto, 0), 2) as margem_percentual_sobre_bruto
  from consolidado s;

comment on view valor.margem_contrato is
  'CONFIDENCIAL: líder, financeiro e administrador. Margem por contrato, na ordem bruto, imposto, comissões, custo de conselheiro e margem.';

-- ---------------------------------------------------------------- segurança

alter table valor.percentuais_padrao enable row level security;
alter table valor.comissoes          enable row level security;

create policy percentual_le on valor.percentuais_padrao for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy percentual_insere on valor.percentuais_padrao for insert
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

create policy percentual_atualiza on valor.percentuais_padrao for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

-- Cada um enxerga a própria linha e só ela. O vendedor nunca vê a do parceiro,
-- o parceiro nunca vê a do vendedor, e o conselheiro vê apenas a própria
-- remuneração. Líder, financeiro e administrador enxergam todas. O participante
-- não é beneficiário de comissão nenhuma, e a cláusula de time da casa garante
-- que ele não entre por um usuario_id que por acaso bata.
create policy comissao_le on valor.comissoes for select
  using (
    valor.do_inquilino(inquilino_id)
    and (
      valor.ve_confidencial()
      or (beneficiario_tipo = 'parceiro'
          and valor.eh_parceiro()
          and parceiro_id = valor.parceiro_atual())
      or (beneficiario_tipo in ('vendedor_interno', 'conselheiro')
          and valor.time_da_casa()
          and usuario_id = valor.usuario_atual())
    )
  );

create policy comissao_insere on valor.comissoes for insert
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

create policy comissao_atualiza on valor.comissoes for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());


-- ==========================================================================
-- 0007_brm_programas_e_turmas.sql
-- ==========================================================================
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

-- A porta do programa abre a turma inteira para quem é da casa, porque quem
-- responde pelo programa responde por todas as turmas dele. Para quem está do
-- lado do cliente essa porta fica fechada: o participante entra pela cadeira, e
-- só pela cadeira. Sem a cláusula de time da casa, quem senta numa turma
-- alcançaria as turmas irmãs do mesmo programa, e num programa compartilhado
-- isso é uma empresa lendo a turma de uma concorrente.
create or replace function valor.brm_turma_visivel(alvo uuid) returns boolean
language sql stable security definer set search_path = valor, public as $$
  select not valor.eh_parceiro() and exists (
    select 1 from valor.turmas t
    where t.id = alvo
      and t.inquilino_id = valor.inquilino_atual()
      and ( valor.brm_eh_equipe_da_turma(t.id)
            or t.id in (select valor.brm_turmas_do_participante())
            or (valor.time_da_casa() and valor.brm_programa_visivel(t.programa_id)) )
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


-- ==========================================================================
-- 0008_brm_encontros_e_entregaveis.sql
-- ==========================================================================
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


-- ==========================================================================
-- 0009_conselho_pautas_e_atas.sql
-- ==========================================================================
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


-- ==========================================================================
-- 0010_nps_e_avaliacoes.sql
-- ==========================================================================
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
-- ver a nota de empresas concorrentes. O predicado valor.time_da_casa vem
-- da migração 0009 e vale igual aqui.

create policy pesquisa_le on valor.pesquisas for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy pesquisa_insere on valor.pesquisas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy pesquisa_atualiza on valor.pesquisas for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy questao_le on valor.pesquisas_questoes for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy questao_insere on valor.pesquisas_questoes for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy questao_atualiza on valor.pesquisas_questoes for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

-- A resposta do cliente é do time interno. O parceiro nunca lê, e o participante
-- também não: a apuração não é dele. Mas ele grava a própria resposta, que é o
-- ato de responder a pesquisa, e só a própria.
create policy resposta_le on valor.respostas for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy resposta_insere on valor.respostas for insert
  with check (
    valor.do_inquilino(inquilino_id)
    and not valor.eh_parceiro()
    and (valor.time_da_casa() or usuario_id = valor.usuario_atual())
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
-- Quem avalia o conselheiro e socio do cliente, entao esta porta precisa abrir
-- para gente de fora. Mas abrir por negacao deixava qualquer pessoa do inquilino
-- gravar avaliacao sobre qualquer conselheiro, inclusive um participante que
-- nunca foi convidado a avaliar. A porta agora nomeia quem pode: o time da casa,
-- ou o participante que esteja identificado como avaliador.
create policy avaliacao_conselheiro_insere on valor.avaliacoes_conselheiro for insert
  with check (
    valor.do_inquilino(inquilino_id)
    and ( valor.time_da_casa()
          or (valor.eh_participante() and avaliador_contato_id is not null) )
    and valor.usuario_atual() is distinct from conselheiro_usuario_id
  );
create policy avaliacao_conselheiro_atualiza on valor.avaliacoes_conselheiro for update
  using (valor.do_inquilino(inquilino_id) and valor.ve_confidencial())
  with check (valor.do_inquilino(inquilino_id) and valor.ve_confidencial());

create policy ciclo_le on valor.ciclos_avaliacao for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy ciclo_insere on valor.ciclos_avaliacao for insert
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy ciclo_atualiza on valor.ciclos_avaliacao for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());


-- ==========================================================================
-- 0011_atividades_gtd.sql
-- ==========================================================================
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

-- A agenda interna é do time da casa. O parceiro indica negócio e o
-- participante ocupa cadeira numa turma; nenhum dos dois lê nem grava aqui.
create policy contexto_le on valor.contextos_gtd for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy contexto_escreve on valor.contextos_gtd for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy recorrencia_le on valor.atividades_recorrencia for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy recorrencia_escreve on valor.atividades_recorrencia for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy atividade_le on valor.atividades for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy atividade_escreve on valor.atividades for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy checklist_le on valor.atividades_checklist for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy checklist_escreve on valor.atividades_checklist for all
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());

create policy coluna_le on valor.colunas_kanban for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy coluna_escreve on valor.colunas_kanban for all
  using (valor.do_inquilino(inquilino_id)
         and (valor.eh_admin() or (escopo = 'usuario' and usuario_id = valor.usuario_atual())))
  with check (valor.do_inquilino(inquilino_id)
         and (valor.eh_admin() or (escopo = 'usuario' and usuario_id = valor.usuario_atual())));


-- ==========================================================================
-- 0012_alertas_e_automacoes.sql
-- ==========================================================================
-- 0012 · Alertas e automações
-- Dono: engenheiro de operação. É o que faz a plataforma cobrar sozinha.
-- Todo prazo desta migração mora em valor.configuracoes e é trocado em tela.
-- Nada é apagado: alerta resolvido é carimbado, nunca removido.

-- --------------------------------------------------------------------- tipos

create type valor.canal_alerta as enum ('painel', 'email', 'whatsapp', 'push');
comment on type valor.canal_alerta is 'Por onde o alerta chega. Rótulos de tela: Painel, E-mail, WhatsApp, Notificação.';

create type valor.status_alerta as enum ('aberto', 'reconhecido', 'resolvido', 'silenciado');
comment on type valor.status_alerta is 'Rótulos de tela: Aberto, Reconhecido, Resolvido, Silenciado.';

create type valor.tipo_condicao_alerta as enum ('sql', 'jsonb');

create type valor.gatilho_automacao as enum ('agendado', 'evento', 'manual');

create type valor.resultado_execucao as enum ('sucesso', 'erro', 'ignorada');

-- --------------------------------------------------- leitura das invariantes

create or replace function valor.artefato_exigido_na_fase(p_fase smallint)
returns valor.tipo_artefato language sql immutable as $$
  select case p_fase
    when 1 then 'plano_conta'::valor.tipo_artefato
    when 2 then 'plano_negocio'::valor.tipo_artefato
    when 3 then 'plano_trabalho'::valor.tipo_artefato
    when 4 then 'contrato_valor'::valor.tipo_artefato
  end;
$$;
comment on function valor.artefato_exigido_na_fase(smallint) is
  'O artefato que comprova cada fase do método, conforme a seção 4 do contrato técnico.';

-- As quatro invariantes de higiene da seção 6 do contrato técnico, lidas linha a
-- linha. A janela de dias sem interação vem de valor.configuracoes.
create or replace function valor.negocios_fora_da_higiene(p_inquilino uuid default null)
returns table (
  inquilino_id          uuid,
  negocio_id            uuid,
  titulo                text,
  fase                  smallint,
  tem_proximo_passo     boolean,
  decisao_no_futuro     boolean,
  interacao_recente     boolean,
  tem_artefato_da_fase  boolean,
  invariantes_quebradas text[]
)
language sql stable as $$
  with leitura as (
    select
      n.inquilino_id,
      n.id as negocio_id,
      n.titulo,
      n.fase,
      (n.proximo_passo is not null
        and n.proximo_passo_data is not null
        and n.proximo_passo_data >= current_date) as tem_proximo_passo,
      (n.data_decisao_cliente is not null
        and n.data_decisao_cliente >= current_date) as decisao_no_futuro,
      (coalesce(n.ultima_interacao, n.criado_em::date)
        >= current_date
           - valor.configuracao_num(n.inquilino_id, 'higiene.dias_sem_interacao', 30)::integer) as interacao_recente,
      exists (
        select 1 from valor.artefatos a
         where a.negocio_id = n.id
           and a.tipo = valor.artefato_exigido_na_fase(n.fase)
           and a.arquivado_em is null
      ) as tem_artefato_da_fase
    from valor.negocios n
   where n.arquivado_em is null
     and n.desfecho is null
     and n.fase between 1 and 4
     and (p_inquilino is null or n.inquilino_id = p_inquilino)
  )
  select l.inquilino_id, l.negocio_id, l.titulo, l.fase,
         l.tem_proximo_passo, l.decisao_no_futuro, l.interacao_recente, l.tem_artefato_da_fase,
         array_remove(array[
           case when not l.tem_proximo_passo    then 'Próximo passo com data definida' end,
           case when not l.decisao_no_futuro    then 'Data da decisão do cliente no futuro' end,
           case when not l.interacao_recente    then 'Interação dentro da janela de higiene' end,
           case when not l.tem_artefato_da_fase then 'Artefato da fase atual registrado' end
         ], null)
    from leitura l
   where not (l.tem_proximo_passo and l.decisao_no_futuro
              and l.interacao_recente and l.tem_artefato_da_fase);
$$;
comment on function valor.negocios_fora_da_higiene(uuid) is
  'Lista os negócios ativos das fases 1 a 4 que quebram pelo menos uma das quatro invariantes de higiene.';

-- Limite de dias parado por fase. Enquanto não houver mediana histórica com
-- amostra suficiente, vale o piso configurado. Havendo, vale o fator vezes a
-- mediana. A mediana sai de valor.historico_fases, que outra migração entrega.
create or replace function valor.limite_dias_parado(p_inquilino uuid, p_fase smallint)
returns integer language plpgsql stable as $$
declare
  v_piso    integer := valor.configuracao_num(p_inquilino, 'alerta.negocio_parado_dias_piso', 30)::integer;
  v_fator   numeric := valor.configuracao_num(p_inquilino, 'alerta.negocio_parado_fator_mediana', 2);
  v_amostra integer := valor.configuracao_num(p_inquilino, 'alerta.negocio_parado_amostra_minima', 5)::integer;
  v_n       integer;
  v_mediana numeric;
begin
  if to_regclass('valor.historico_fases') is null then
    return v_piso;
  end if;
  execute
    'select count(*)::integer,
            percentile_cont(0.5) within group (order by (h.saiu_em - h.entrou_em))
       from valor.historico_fases h
      where h.inquilino_id = $1 and h.fase = $2 and h.saiu_em is not null'
    into v_n, v_mediana
    using p_inquilino, p_fase;
  if v_n is null or v_n < v_amostra or v_mediana is null then
    return v_piso;
  end if;
  return greatest(1, ceil(v_mediana * v_fator)::integer);
end;
$$;
comment on function valor.limite_dias_parado(uuid, smallint) is
  'Piso de 30 dias por padrão, substituído por duas vezes a mediana histórica da fase quando houver amostra.';

-- ------------------------------------------------------------ regras e alertas

create table valor.regras_alerta (
  id                  uuid primary key default gen_random_uuid(),
  inquilino_id        uuid not null references valor.inquilinos(id) on delete restrict,
  codigo              text not null,
  nome                text not null,
  descricao           text,
  entidade_alvo       text not null,
  tipo_condicao       valor.tipo_condicao_alerta not null default 'sql',
  condicao_sql        text,
  condicao_jsonb      jsonb,
  tabelas_requeridas  text[],
  criticidade         valor.criticidade not null default 'amarelo',
  canal               valor.canal_alerta not null default 'painel',
  destinatario_perfil valor.perfil_usuario,
  destinatario_papel  valor.papel_negocio,
  ativa               boolean not null default true,
  configuravel        boolean not null default true,
  ordem               integer not null default 100,
  criado_em           timestamptz not null default now(),
  criado_por          uuid,
  atualizado_em       timestamptz,
  atualizado_por      uuid,
  arquivado_em        timestamptz,
  unique (inquilino_id, codigo),
  constraint condicao_presente check (
    (tipo_condicao = 'sql'   and condicao_sql is not null and condicao_jsonb is null)
    or (tipo_condicao = 'jsonb' and condicao_jsonb is not null and condicao_sql is null)
  ),
  constraint condicao_sql_recebe_inquilino check (
    condicao_sql is null or condicao_sql like '%$1%'
  )
);
comment on table valor.regras_alerta is
  'O catálogo de regras que a casa decidiu. Cada linha é configurável em tela, inclusive a condição.';
comment on column valor.regras_alerta.condicao_sql is
  'Consulta que devolve inquilino_id, entidade_chave, mensagem, criticidade e detalhe. Recebe o inquilino em $1.';
comment on column valor.regras_alerta.condicao_jsonb is
  'Alternativa declarativa para quem monta regra na tela: tabela, chave, mensagem, criticidade e filtros.';
comment on column valor.regras_alerta.tabelas_requeridas is
  'Tabelas que a condição precisa. Faltando alguma, a regra é adiada e a rodada registra o motivo, sem erro.';
comment on column valor.regras_alerta.destinatario_perfil is
  'Perfil que recebe. Quando nulo, vale o papel no negócio. Quando os dois são nulos, o alerta fica no painel da casa.';

create table valor.alertas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  regra_id       uuid not null references valor.regras_alerta(id) on delete restrict,
  entidade       text not null,
  entidade_chave uuid not null,
  criticidade    valor.criticidade not null default 'amarelo',
  mensagem       text not null,
  detalhe        jsonb not null default '{}',
  disparado_em   timestamptz not null default now(),
  status         valor.status_alerta not null default 'aberto',
  destinatario_id uuid references valor.usuarios(id),
  reconhecido_por uuid references valor.usuarios(id),
  reconhecido_em timestamptz,
  resolvido_por  uuid references valor.usuarios(id),
  resolvido_em   timestamptz,
  nota_resolucao text,
  silenciado_por uuid references valor.usuarios(id),
  silenciado_ate date,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on table valor.alertas is
  'A instância disparada de uma regra. Resolver é carimbar status e data, jamais remover a linha.';
comment on column valor.alertas.entidade_chave is
  'O identificador da linha que provocou o alerta, na tabela nomeada em entidade.';

-- É esta restrição que torna valor.avaliar_alertas idempotente: enquanto houver
-- alerta aberto da mesma regra para a mesma entidade, não nasce outro.
create unique index alertas_um_aberto_por_entidade
  on valor.alertas (inquilino_id, regra_id, entidade_chave)
  where status = 'aberto' and arquivado_em is null;

create index on valor.alertas (inquilino_id, status, criticidade) where arquivado_em is null;
create index on valor.alertas (inquilino_id, entidade, entidade_chave);
create index on valor.alertas (destinatario_id, status) where arquivado_em is null;

-- ------------------------------------------------------------- automações

create table valor.automacoes (
  id                 uuid primary key default gen_random_uuid(),
  inquilino_id       uuid not null references valor.inquilinos(id) on delete restrict,
  codigo             text not null,
  nome               text not null,
  descricao          text,
  gatilho            valor.gatilho_automacao not null default 'agendado',
  gatilho_detalhe    text,
  acao               text not null,
  parametros         jsonb not null default '{}',
  tabelas_requeridas text[],
  ativa              boolean not null default true,
  ultima_execucao_em timestamptz,
  ultimo_resultado   valor.resultado_execucao,
  criado_em          timestamptz not null default now(),
  criado_por         uuid,
  atualizado_em      timestamptz,
  atualizado_por     uuid,
  arquivado_em       timestamptz,
  unique (inquilino_id, codigo)
);
comment on table valor.automacoes is
  'O que o sistema faz sozinho. A ação é um nome conhecido, despachado por lista fechada, nunca um texto executado às cegas.';
comment on column valor.automacoes.gatilho_detalhe is
  'Para gatilho agendado, a expressão de agenda no formato do pg_cron. Para gatilho por evento, o nome do evento.';

create table valor.execucoes_automacao (
  id                 uuid primary key default gen_random_uuid(),
  inquilino_id       uuid not null references valor.inquilinos(id) on delete restrict,
  automacao_id       uuid not null references valor.automacoes(id) on delete restrict,
  iniciada_em        timestamptz not null default now(),
  terminada_em       timestamptz,
  duracao_ms         integer,
  resultado          valor.resultado_execucao not null default 'sucesso',
  registros_afetados integer not null default 0,
  mensagem           text,
  erro               text,
  criado_em          timestamptz not null default now()
);
comment on table valor.execucoes_automacao is
  'O log de cada rodada. Fica para sempre: é dele que sai a prova de que a cobrança automática rodou.';

create index on valor.execucoes_automacao (automacao_id, iniciada_em desc);
create index on valor.execucoes_automacao (inquilino_id, resultado, iniciada_em desc);

create trigger carimbo before update on valor.regras_alerta for each row execute function valor.carimbar();
create trigger carimbo before update on valor.alertas       for each row execute function valor.carimbar();
create trigger carimbo before update on valor.automacoes    for each row execute function valor.carimbar();

-- ------------------------------------------- condição declarativa em jsonb

-- Traduz a condição declarativa montada na tela para consulta. Todo nome de
-- coluna passa por quote_ident e todo valor por quote_literal, então a tela não
-- vira porta de entrada de injeção.
create or replace function valor.montar_sql_condicao(p_condicao jsonb)
returns text language plpgsql immutable as $funcao$
declare
  v_tabela      text;
  v_chave       text;
  v_mensagem    text;
  v_criticidade text;
  v_onde        text := '';
  v_pedaco      text;
  v_coluna      text;
  v_operador    text;
  f             jsonb;
begin
  if p_condicao is null or p_condicao ->> 'tabela' is null then
    raise exception 'Condição declarativa sem tabela alvo.';
  end if;

  v_tabela      := 'valor.' || quote_ident(p_condicao ->> 'tabela');
  v_chave       := quote_ident(coalesce(p_condicao ->> 'chave', 'id'));
  v_mensagem    := quote_literal(coalesce(p_condicao ->> 'mensagem', 'Condição de alerta atendida'));
  v_criticidade := quote_literal(coalesce(p_condicao ->> 'criticidade', 'amarelo'));

  for f in select * from jsonb_array_elements(coalesce(p_condicao -> 'filtros', '[]'::jsonb))
  loop
    v_coluna   := quote_ident(f ->> 'coluna');
    v_operador := f ->> 'operador';
    v_pedaco := case v_operador
      when 'nulo'       then v_coluna || ' is null'
      when 'nao_nulo'   then v_coluna || ' is not null'
      when 'verdadeiro' then v_coluna || ' is true'
      when 'falso'      then v_coluna || ' is not true'
      when 'igual'      then v_coluna || ' = ' || quote_literal(f ->> 'valor')
      when 'diferente'  then v_coluna || ' is distinct from ' || quote_literal(f ->> 'valor')
      when 'maior'      then v_coluna || ' > ' || quote_literal(f ->> 'valor')
      when 'menor'      then v_coluna || ' < ' || quote_literal(f ->> 'valor')
      when 'entre'      then v_coluna || ' between ' || quote_literal(f -> 'valor' ->> 0)
                             || ' and ' || quote_literal(f -> 'valor' ->> 1)
      when 'dias_atras' then v_coluna || ' <= current_date - ' || (f ->> 'valor')::integer
      else null
    end;
    if v_pedaco is null then
      raise exception 'Operador declarativo desconhecido na regra de alerta: %', coalesce(v_operador, 'nulo');
    end if;
    v_onde := v_onde || ' and ' || v_pedaco;
  end loop;

  return 'select f.inquilino_id, f.' || v_chave || ' as entidade_chave, '
      || v_mensagem || '::text as mensagem, '
      || v_criticidade || '::valor.criticidade as criticidade, '
      || quote_literal('{}') || '::jsonb as detalhe'
      || ' from ' || v_tabela || ' f'
      || ' where ($1::uuid is null or f.inquilino_id = $1::uuid)' || v_onde;
end;
$funcao$;
comment on function valor.montar_sql_condicao(jsonb) is
  'Traduz a condição declarativa da tela em consulta, com nome de coluna e valor sempre citados.';

-- -------------------------------------------------------- avaliar alertas

-- Varre as regras ativas e grava os alertas. Idempotente: rodar duas vezes no
-- mesmo dia não duplica alerta aberto da mesma entidade pela mesma regra, porque
-- o índice alertas_um_aberto_por_entidade converte a segunda tentativa em
-- atualização da criticidade e da mensagem. O alerta cuja condição deixou de
-- valer é carimbado como resolvido, nunca removido.
create or replace function valor.avaliar_alertas(p_inquilino uuid default null)
returns table (
  regra       text,
  criticidade valor.criticidade,
  novos       integer,
  ja_abertos  integer,
  resolvidos  integer,
  situacao    text
)
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  r        record;
  v_sql    text;
  v_base   text;
  v_falta  text;
  v_tabela text;
begin
  -- Esta função roda como dona das tabelas, então ignora a segurança de linha.
  -- O parceiro não passa daqui: a cobrança interna da casa não é dele.
  if valor.eh_parceiro() then
    raise exception 'O perfil parceiro não roda a cobrança interna da casa.'
      using errcode = 'insufficient_privilege';
  end if;

  for r in
    select * from valor.regras_alerta
     where ativa and arquivado_em is null
       and (p_inquilino is null or inquilino_id = p_inquilino)
     order by ordem, codigo
  loop
    regra       := r.codigo;
    criticidade := r.criticidade;
    novos       := 0;
    ja_abertos  := 0;
    resolvidos  := 0;
    situacao    := 'avaliada';
    v_falta     := null;

    if r.tabelas_requeridas is not null then
      foreach v_tabela in array r.tabelas_requeridas loop
        if to_regclass(v_tabela) is null then
          v_falta := coalesce(v_falta || ', ', '') || v_tabela;
        end if;
      end loop;
    end if;

    if v_falta is not null then
      situacao := 'adiada, faltam as tabelas ' || v_falta;
      return next;
      continue;
    end if;

    begin
      v_sql := coalesce(r.condicao_sql, valor.montar_sql_condicao(r.condicao_jsonb));

      -- A deduplicação garante que a mesma entidade não seja tocada duas vezes
      -- na mesma instrução, e mantém a leitura mais grave quando houver empate.
      v_base := '(select distinct on (c0.inquilino_id, c0.entidade_chave) c0.*'
             || ' from (' || v_sql || ') c0'
             || ' order by c0.inquilino_id, c0.entidade_chave, c0.criticidade desc) c';

      execute format($modelo$
        with gravado as (
          insert into valor.alertas
            (inquilino_id, regra_id, entidade, entidade_chave, criticidade, mensagem, detalhe)
          select c.inquilino_id, %L::uuid, %L, c.entidade_chave,
                 coalesce(c.criticidade, %L::valor.criticidade),
                 c.mensagem,
                 coalesce(c.detalhe, '{}'::jsonb)
            from %s
          on conflict (inquilino_id, regra_id, entidade_chave)
             where status = 'aberto' and arquivado_em is null
          do update set criticidade = excluded.criticidade,
                        mensagem    = excluded.mensagem,
                        detalhe     = excluded.detalhe
          returning (xmax = 0) as inserido
        )
        select (count(*) filter (where inserido))::integer,
               (count(*) filter (where not inserido))::integer
          from gravado
      $modelo$, r.id, r.entidade_alvo, r.criticidade, v_base)
      using r.inquilino_id
      into novos, ja_abertos;

      execute format($modelo$
        update valor.alertas a
           set status = 'resolvido',
               resolvido_em = now(),
               nota_resolucao = coalesce(a.nota_resolucao, 'Condição da regra deixou de valer.')
         where a.regra_id = %L::uuid
           and a.status = 'aberto'
           and a.arquivado_em is null
           and not exists (
             select 1 from %s
              where c.inquilino_id = a.inquilino_id
                and c.entidade_chave = a.entidade_chave)
      $modelo$, r.id, v_base)
      using r.inquilino_id;
      get diagnostics resolvidos = row_count;

    exception when others then
      novos      := 0;
      ja_abertos := 0;
      resolvidos := 0;
      situacao   := 'erro na condição: ' || sqlerrm;
    end;

    return next;
  end loop;
end;
$funcao$;
comment on function valor.avaliar_alertas(uuid) is
  'Varre as regras ativas e grava os alertas. Idempotente por regra e por entidade. Nada é apagado.';

-- ------------------------------------------------- carimbos do ciclo do alerta

create or replace function valor.reconhecer_alerta(p_alerta uuid) returns void
language sql as $$
  update valor.alertas
     set status = 'reconhecido',
         reconhecido_por = valor.usuario_atual(),
         reconhecido_em = now()
   where id = p_alerta and status = 'aberto' and arquivado_em is null;
$$;

create or replace function valor.resolver_alerta(p_alerta uuid, p_nota text default null) returns void
language sql as $$
  update valor.alertas
     set status = 'resolvido',
         resolvido_por = valor.usuario_atual(),
         resolvido_em = now(),
         nota_resolucao = coalesce(p_nota, nota_resolucao)
   where id = p_alerta and status in ('aberto', 'reconhecido', 'silenciado') and arquivado_em is null;
$$;

create or replace function valor.silenciar_alerta(p_alerta uuid, p_ate date) returns void
language sql as $$
  update valor.alertas
     set status = 'silenciado',
         silenciado_por = valor.usuario_atual(),
         silenciado_ate = p_ate
   where id = p_alerta and status in ('aberto', 'reconhecido') and arquivado_em is null;
$$;

create or replace function valor.reabrir_alertas_silenciados(p_inquilino uuid default null)
returns integer language plpgsql as $$
declare v_afetados integer;
begin
  update valor.alertas
     set status = 'aberto', silenciado_ate = null, silenciado_por = null
   where status = 'silenciado'
     and silenciado_ate is not null
     and silenciado_ate < current_date
     and arquivado_em is null
     and (p_inquilino is null or inquilino_id = p_inquilino);
  get diagnostics v_afetados = row_count;
  return v_afetados;
end;
$$;

-- Cria o negócio de renovação na antecedência configurada. Depende de
-- valor.contratos, que nasce em outra migração. Enquanto a tabela não existir,
-- a função devolve zero e a rodada é registrada como ignorada.
create or replace function valor.criar_negocios_renovacao(p_inquilino uuid)
returns integer
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  v_dias     integer := valor.configuracao_num(p_inquilino, 'alerta.contrato_renovacao_dias', 90)::integer;
  v_criados  integer := 0;
begin
  -- Esta função roda como dona das tabelas, então ignora a segurança de linha.
  -- O parceiro não passa daqui: a cobrança interna da casa não é dele.
  if valor.eh_parceiro() then
    raise exception 'O perfil parceiro não roda a cobrança interna da casa.'
      using errcode = 'insufficient_privilege';
  end if;

  if to_regclass('valor.contratos') is null then
    return 0;
  end if;
  execute $modelo$
    insert into valor.negocios
      (inquilino_id, conta_id, oferta_id, titulo, fase, origem, data_decisao_cliente, entrou_na_fase_em)
    select k.inquilino_id, k.conta_id, k.oferta_id,
           'Renovação do contrato ' || k.numero || ' da conta ' || ct.nome,
           7, 'base_instalada'::valor.origem_lead, k.vigencia_fim, current_date
      from valor.contratos k
      join valor.contas ct on ct.id = k.conta_id
     where k.inquilino_id = $1
       and k.arquivado_em is null
       and k.vigencia_fim is not null
       and k.situacao in ('vigente', 'pausado')
       and k.vigencia_fim between current_date and current_date + $2
       and not exists (
         select 1 from valor.negocios n
          where n.conta_id = k.conta_id
            and n.fase = 7
            and n.arquivado_em is null
            and n.desfecho is null)
  $modelo$ using p_inquilino, v_dias;
  get diagnostics v_criados = row_count;
  return v_criados;
end;
$funcao$;
comment on function valor.criar_negocios_renovacao(uuid) is
  'Abre o negócio de renovação na antecedência configurada, um por conta. Adiada enquanto valor.contratos não existir.';

-- ------------------------------------------------------ executar automações

create or replace function valor.executar_automacoes(p_inquilino uuid default null)
returns table (
  automacao text,
  resultado valor.resultado_execucao,
  afetados  integer,
  mensagem  text
)
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  a         record;
  v_inicio  timestamptz;
  v_falta   text;
  v_tabela  text;
  v_erro    text;
begin
  -- Esta função roda como dona das tabelas, então ignora a segurança de linha.
  -- O parceiro não passa daqui: a cobrança interna da casa não é dele.
  if valor.eh_parceiro() then
    raise exception 'O perfil parceiro não roda a cobrança interna da casa.'
      using errcode = 'insufficient_privilege';
  end if;

  for a in
    select * from valor.automacoes
     where ativa and arquivado_em is null
       and (p_inquilino is null or inquilino_id = p_inquilino)
     order by codigo
  loop
    automacao := a.codigo;
    resultado := 'sucesso';
    afetados  := 0;
    mensagem  := null;
    v_erro    := null;
    v_falta   := null;
    v_inicio  := clock_timestamp();

    if a.tabelas_requeridas is not null then
      foreach v_tabela in array a.tabelas_requeridas loop
        if to_regclass(v_tabela) is null then
          v_falta := coalesce(v_falta || ', ', '') || v_tabela;
        end if;
      end loop;
    end if;

    if v_falta is not null then
      resultado := 'ignorada';
      mensagem  := 'adiada, faltam as tabelas ' || v_falta;
    else
      begin
        case a.acao
          when 'avaliar_alertas' then
            select coalesce(sum(v.novos), 0)::integer
              into afetados
              from valor.avaliar_alertas(a.inquilino_id) v;
            mensagem := 'alertas novos gravados';
          when 'reabrir_alertas_silenciados' then
            afetados := valor.reabrir_alertas_silenciados(a.inquilino_id);
            mensagem := 'alertas devolvidos ao estado aberto';
          when 'criar_negocios_renovacao' then
            afetados := valor.criar_negocios_renovacao(a.inquilino_id);
            mensagem := 'negócios de renovação abertos';
          else
            resultado := 'ignorada';
            mensagem  := 'ação desconhecida: ' || a.acao;
        end case;
      exception when others then
        resultado := 'erro';
        v_erro    := sqlerrm;
        mensagem  := 'falhou ao executar ' || a.acao;
      end;
    end if;

    insert into valor.execucoes_automacao
      (inquilino_id, automacao_id, iniciada_em, terminada_em, duracao_ms,
       resultado, registros_afetados, mensagem, erro)
    values
      (a.inquilino_id, a.id, v_inicio, clock_timestamp(),
       (extract(epoch from (clock_timestamp() - v_inicio)) * 1000)::integer,
       resultado, afetados, mensagem, v_erro);

    update valor.automacoes
       set ultima_execucao_em = clock_timestamp(), ultimo_resultado = resultado
     where id = a.id;

    return next;
  end loop;
end;
$funcao$;
comment on function valor.executar_automacoes(uuid) is
  'Roda as automações ativas e grava uma linha de log por rodada, com resultado e erro.';

-- ------------------------------------------------------------ agendamento

-- O agendamento de produção é do pg_cron do Supabase. A extensão não existe
-- neste contêiner, então a chamada fica comentada de propósito. Para ligar no
-- Supabase, rode o bloco abaixo uma vez, com o papel postgres, trocando as
-- expressões de agenda se a casa quiser outro horário.
--
--   create extension if not exists pg_cron;
--
--   select cron.schedule(
--     'valor_avaliar_alertas',
--     '0 6 * * *',
--     $agenda$ select valor.avaliar_alertas(); $agenda$);
--
--   select cron.schedule(
--     'valor_executar_automacoes',
--     '15 6 * * *',
--     $agenda$ select valor.executar_automacoes(); $agenda$);
--
-- Para desligar: select cron.unschedule('valor_avaliar_alertas');
-- A expressão de agenda de cada automação fica em valor.automacoes.gatilho_detalhe,
-- para a tela mostrar o que está agendado sem consultar o catálogo do pg_cron.

-- -------------------------------------------------- semente da configuração

create or replace function valor.semear_configuracoes_alerta(p_inquilino uuid)
returns void language plpgsql as $$
begin
  perform valor.gravar_configuracao(p_inquilino, 'alerta.lead_sem_dono_dias', to_jsonb(3),
    'Dias até alertar lead sem dono', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.negocio_parado_dias_piso', to_jsonb(30),
    'Piso de dias parado antes do alarme', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.negocio_parado_fator_mediana', to_jsonb(2),
    'Fator sobre a mediana histórica da fase', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.negocio_parado_amostra_minima', to_jsonb(5),
    'Amostra mínima para confiar na mediana da fase', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.plano_trabalho_aviso_amarelo_dias', to_jsonb(7),
    'Primeiro aviso de Plano de Trabalho vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.plano_trabalho_aviso_vermelho_dias', to_jsonb(1),
    'Último aviso de Plano de Trabalho vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.contrato_renovacao_dias', to_jsonb(90),
    'Antecedência para abrir o negócio de renovação, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.contrato_aviso_amarelo_dias', to_jsonb(60),
    'Primeiro aviso de contrato vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.contrato_aviso_vermelho_dias', to_jsonb(30),
    'Último aviso de contrato vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.ata_nao_enviada_horas', to_jsonb(24),
    'Horas até alertar ata não enviada', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.concentracao_limite', to_jsonb(0.5),
    'Limite de concentração dos dois maiores negócios no pipeline', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'higiene.dias_sem_interacao', to_jsonb(30),
    'Dias sem interação que quebram a invariante de higiene', 'higiene');
end;
$$;

-- ------------------------------------------------------- semente das regras

create or replace function valor.semear_regras_alerta(p_inquilino uuid)
returns void language plpgsql as $funcao$
begin
  perform valor.semear_configuracoes_alerta(p_inquilino);

  insert into valor.regras_alerta
    (inquilino_id, codigo, nome, descricao, entidade_alvo, tipo_condicao, condicao_sql,
     tabelas_requeridas, criticidade, canal, destinatario_perfil, ordem)
  values
  (p_inquilino, 'lead_sem_dono',
   'Lead sem dono',
   'Lead parado sem Gerente de Contas além do prazo configurado.',
   'negocios', 'sql', $sql$
    select n.inquilino_id,
           n.id as entidade_chave,
           'Lead sem dono há ' || (current_date - n.criado_em::date) || ' dias: ' || n.titulo as mensagem,
           'amarelo'::valor.criticidade as criticidade,
           jsonb_build_object(
             'dias_sem_dono', (current_date - n.criado_em::date),
             'limite_dias', d.dias) as detalhe
      from valor.negocios n
      join valor.contas ct on ct.id = n.conta_id
      cross join lateral (
        select valor.configuracao_num(n.inquilino_id, 'alerta.lead_sem_dono_dias', 3)::integer as dias
      ) d
     where n.arquivado_em is null
       and n.desfecho is null
       and n.fase = 0
       and ct.gerente_contas_id is null
       and not exists (
         select 1 from valor.papeis_negocio p
          where p.negocio_id = n.id
            and p.ativo
            and p.arquivado_em is null
            and p.papel = 'gerente_contas')
       and n.criado_em::date <= current_date - d.dias
       and ($1::uuid is null or n.inquilino_id = $1::uuid)
   $sql$, null, 'amarelo', 'painel', 'lider', 10),

  (p_inquilino, 'negocio_parado',
   'Negócio parado',
   'Negócio sem interação acima do piso configurado, ou acima do fator sobre a mediana histórica da fase.',
   'negocios', 'sql', $sql$
    select n.inquilino_id,
           n.id as entidade_chave,
           'Negócio parado há ' || p.dias_parado || ' dias, acima do limite de '
             || p.limite || ' dias: ' || n.titulo as mensagem,
           'vermelho'::valor.criticidade as criticidade,
           jsonb_build_object(
             'dias_parado', p.dias_parado,
             'limite_dias', p.limite,
             'fase', n.fase,
             'ultima_interacao', n.ultima_interacao) as detalhe
      from valor.negocios n
      cross join lateral (
        select (current_date - coalesce(n.ultima_interacao, n.entrou_na_fase_em, n.criado_em::date)) as dias_parado,
               valor.limite_dias_parado(n.inquilino_id, n.fase) as limite
      ) p
     where n.arquivado_em is null
       and n.desfecho is null
       and n.fase between 1 and 7
       and p.dias_parado > p.limite
       and ($1::uuid is null or n.inquilino_id = $1::uuid)
   $sql$, null, 'vermelho', 'painel', 'lider', 20),

  (p_inquilino, 'plano_trabalho_vencendo',
   'Plano de Trabalho vencendo',
   'Plano de Trabalho validado com o cliente chegando ao fim da validade. Amarelo no primeiro aviso, vermelho no último.',
   'artefatos', 'sql', $sql$
    select n.inquilino_id,
           a.id as entidade_chave,
           'Plano de Trabalho do negócio ' || n.titulo || ' vence em ' || v.dias_restantes || ' dias' as mensagem,
           case when v.dias_restantes <= v.aviso_vermelho
                then 'vermelho'::valor.criticidade
                else 'amarelo'::valor.criticidade end as criticidade,
           jsonb_build_object(
             'negocio_id', n.id,
             'vence_em', v.vence_em,
             'dias_restantes', v.dias_restantes) as detalhe
      from valor.artefatos a
      join valor.negocios n on n.id = a.negocio_id
      cross join lateral (
        select coalesce((a.conteudo ->> 'valido_ate')::date, n.data_decisao_cliente) as vence_em,
               valor.configuracao_num(n.inquilino_id, 'alerta.plano_trabalho_aviso_amarelo_dias', 7)::integer as aviso_amarelo,
               valor.configuracao_num(n.inquilino_id, 'alerta.plano_trabalho_aviso_vermelho_dias', 1)::integer as aviso_vermelho
      ) x
      cross join lateral (
        select x.vence_em, x.aviso_amarelo, x.aviso_vermelho,
               (x.vence_em - current_date) as dias_restantes
      ) v
     where a.tipo = 'plano_trabalho'
       and a.status = 'validado_com_cliente'
       and a.arquivado_em is null
       and n.arquivado_em is null
       and n.desfecho is null
       and v.vence_em is not null
       and v.dias_restantes between 0 and v.aviso_amarelo
       and ($1::uuid is null or n.inquilino_id = $1::uuid)
   $sql$, null, 'amarelo', 'painel', 'gerente_contas', 30),

  (p_inquilino, 'contrato_vencendo',
   'Contrato vencendo',
   'Contrato chegando ao fim da vigência. Primeiro aviso em amarelo, último em vermelho. O negócio de renovação é aberto pela automação criar_negocios_renovacao.',
   'contratos', 'sql', $sql$
    select c.inquilino_id,
           c.id as entidade_chave,
           'Contrato ' || c.numero || ' da conta ' || ct.nome
             || ' vence em ' || (c.vigencia_fim - current_date) || ' dias' as mensagem,
           case when (c.vigencia_fim - current_date)
                     <= valor.configuracao_num(c.inquilino_id, 'alerta.contrato_aviso_vermelho_dias', 30)::integer
                then 'vermelho'::valor.criticidade
                else 'amarelo'::valor.criticidade end as criticidade,
           jsonb_build_object(
             'conta_id', c.conta_id,
             'vigencia_fim', c.vigencia_fim,
             'dias_restantes', (c.vigencia_fim - current_date)) as detalhe
      from valor.contratos c
      join valor.contas ct on ct.id = c.conta_id
     where c.arquivado_em is null
       and c.vigencia_fim is not null
       and c.situacao in ('vigente', 'pausado')
       and (c.vigencia_fim - current_date)
           between 0 and valor.configuracao_num(c.inquilino_id, 'alerta.contrato_aviso_amarelo_dias', 60)::integer
       and ($1::uuid is null or c.inquilino_id = $1::uuid)
   $sql$, array['valor.contratos'], 'amarelo', 'painel', 'lider', 40),

  (p_inquilino, 'ata_nao_enviada',
   'Ata não enviada',
   'Reunião de conselho realizada e ata ainda não enviada além do prazo configurado. A ata restrita fica de fora, porque ela nunca é enviada.',
   'atas', 'sql', $sql$
    select a.inquilino_id,
           a.id as entidade_chave,
           'Ata da reunião de ' || to_char(a.data_reuniao, 'DD/MM/YYYY') || ' da conta ' || ct.nome
             || ' não enviada dentro de ' || h.horas || ' horas' as mensagem,
           'amarelo'::valor.criticidade as criticidade,
           jsonb_build_object(
             'conta_id', a.conta_id,
             'status', a.status,
             'data_reuniao', a.data_reuniao,
             'horas_de_prazo', h.horas) as detalhe
      from valor.atas a
      join valor.contas ct on ct.id = a.conta_id
      cross join lateral (
        select valor.configuracao_num(a.inquilino_id, 'alerta.ata_nao_enviada_horas', 24)::integer as horas
      ) h
     where a.arquivado_em is null
       and a.status <> 'enviada'
       and not a.restrita
       and now() > a.data_reuniao::timestamptz + make_interval(hours => h.horas)
       and ($1::uuid is null or a.inquilino_id = $1::uuid)
   $sql$, array['valor.atas'], 'amarelo', 'painel', 'assessor', 50),

  (p_inquilino, 'higiene_quebrada',
   'Invariante de higiene quebrada',
   'Negócio ativo nas fases 1 a 4 que quebra pelo menos uma das quatro invariantes de higiene. Alarme imediato no painel.',
   'negocios', 'sql', $sql$
    select h.inquilino_id,
           h.negocio_id as entidade_chave,
           'Higiene quebrada em ' || h.titulo || ': '
             || array_to_string(h.invariantes_quebradas, ', ') as mensagem,
           'vermelho'::valor.criticidade as criticidade,
           jsonb_build_object(
             'fase', h.fase,
             'invariantes_quebradas', to_jsonb(h.invariantes_quebradas),
             'tem_proximo_passo', h.tem_proximo_passo,
             'decisao_no_futuro', h.decisao_no_futuro,
             'interacao_recente', h.interacao_recente,
             'tem_artefato_da_fase', h.tem_artefato_da_fase) as detalhe
      from valor.negocios_fora_da_higiene($1::uuid) h
   $sql$, null, 'vermelho', 'painel', 'lider', 60),

  (p_inquilino, 'concentracao_de_pipeline',
   'Concentração de pipeline',
   'Os dois maiores negócios passam da fração configurada do pipeline declarado.',
   'inquilinos', 'sql', $sql$
    with pipeline as (
      select n.inquilino_id, n.id, coalesce(n.valor_total, 0) as valor_total
        from valor.negocios n
       where n.arquivado_em is null
         and n.desfecho is null
         and n.fase between 1 and 4
         and ($1::uuid is null or n.inquilino_id = $1::uuid)
    ),
    posicionado as (
      select p.*, row_number() over (partition by p.inquilino_id order by p.valor_total desc) as posicao
        from pipeline p
    ),
    resumo as (
      select q.inquilino_id,
             sum(q.valor_total) as declarado,
             sum(q.valor_total) filter (where q.posicao <= 2) as dois_maiores,
             count(*) as quantos
        from posicionado q
       group by q.inquilino_id
    )
    select r.inquilino_id,
           r.inquilino_id as entidade_chave,
           'Concentração de ' || round(100 * r.dois_maiores / r.declarado)
             || ' por cento do pipeline declarado nos dois maiores negócios' as mensagem,
           'vermelho'::valor.criticidade as criticidade,
           jsonb_build_object(
             'pipeline_declarado', r.declarado,
             'dois_maiores', r.dois_maiores,
             'negocios_no_pipeline', r.quantos) as detalhe
      from resumo r
     where r.declarado > 0
       and r.quantos > 2
       and (r.dois_maiores / r.declarado)
           > valor.configuracao_num(r.inquilino_id, 'alerta.concentracao_limite', 0.5)
   $sql$, null, 'vermelho', 'painel', 'lider', 70)
  on conflict (inquilino_id, codigo) do nothing;

  insert into valor.automacoes
    (inquilino_id, codigo, nome, descricao, gatilho, gatilho_detalhe, acao, tabelas_requeridas)
  values
    (p_inquilino, 'avaliar_alertas', 'Avaliar alertas',
     'Varre as regras ativas todo dia de manhã e grava os alertas.',
     'agendado', '0 6 * * *', 'avaliar_alertas', null),
    (p_inquilino, 'reabrir_alertas_silenciados', 'Reabrir alertas silenciados',
     'Devolve ao estado aberto o alerta cujo silêncio venceu.',
     'agendado', '10 6 * * *', 'reabrir_alertas_silenciados', null),
    (p_inquilino, 'criar_negocios_renovacao', 'Abrir negócio de renovação',
     'Abre o negócio de renovação na antecedência configurada para cada contrato vencendo.',
     'agendado', '20 6 * * *', 'criar_negocios_renovacao', array['valor.contratos'])
  on conflict (inquilino_id, codigo) do nothing;
end;
$funcao$;
comment on function valor.semear_regras_alerta(uuid) is
  'Semeia as regras e automações que a casa já decidiu, junto com os prazos em valor.configuracoes. Idempotente.';

do $$
declare r record;
begin
  for r in select id from valor.inquilinos loop
    perform valor.semear_regras_alerta(r.id);
  end loop;
end;
$$;

-- ------------------------------------------------------------- segurança

alter table valor.regras_alerta        enable row level security;
alter table valor.alertas              enable row level security;
alter table valor.automacoes           enable row level security;
alter table valor.execucoes_automacao  enable row level security;

create policy regra_le on valor.regras_alerta for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy regra_escreve on valor.regras_alerta for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

-- O alerta é da casa. Nem o parceiro nem o participante recebem cobrança
-- interna, e por isso nenhum dos dois pode carimbar alerta como lido.
create policy alerta_le on valor.alertas for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy alerta_carimba on valor.alertas for update
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa())
  with check (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy alerta_grava on valor.alertas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy automacao_le on valor.automacoes for select
  using (valor.do_inquilino(inquilino_id) and valor.time_da_casa());
create policy automacao_escreve on valor.automacoes for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy execucao_le on valor.execucoes_automacao for select
  using (valor.do_inquilino(inquilino_id) and (valor.eh_admin() or valor.ve_confidencial()));


-- ==========================================================================
-- 0013_auditoria.sql
-- ==========================================================================
-- 0013 · Trilha de auditoria
-- Dono: engenheiro de operação. Um gatilho genérico, pendurável em qualquer
-- tabela sem ser reescrito. Guarda só a coluna que mudou, e nunca o conteúdo de
-- coluna confidencial. Ninguém atualiza nem arquiva linha desta trilha.

create type valor.operacao_auditada as enum ('insercao', 'atualizacao', 'arquivamento');
comment on type valor.operacao_auditada is
  'Rótulos de tela: Inserção, Atualização, Arquivamento. Não existe remoção, porque nada é apagado.';

create table valor.auditoria (
  id           uuid primary key default gen_random_uuid(),
  inquilino_id uuid references valor.inquilinos(id) on delete restrict,
  esquema      text not null default 'valor',
  tabela       text not null,
  chave        uuid not null,
  operacao     valor.operacao_auditada not null,
  mudancas     jsonb not null default '{}',
  usuario_id   uuid,
  perfil       text,
  momento      timestamptz not null default clock_timestamp(),
  origem       text
);
comment on table valor.auditoria is
  'A trilha imutável. É a única tabela fora do padrão da seção 7 do contrato técnico, e de propósito: trilha imutável não tem atualizado_em nem arquivado_em, porque ninguém atualiza nem arquiva linha de auditoria.';
comment on column valor.auditoria.mudancas is
  'Só as colunas que mudaram, cada uma com antes e depois. Coluna confidencial entra com marca de omissão no lugar do valor.';
comment on column valor.auditoria.usuario_id is
  'Sem chave estrangeira de propósito: a trilha precisa sobreviver a qualquer estado do cadastro de usuários e nunca pode recusar uma gravação.';
comment on column valor.auditoria.momento is
  'O instante real da mudança, pelo relógio, e não o início da transação. É o que mantém a ordem certa quando várias mudanças cabem na mesma transação.';
comment on column valor.auditoria.origem is
  'De onde veio a chamada: o parâmetro de sessão app.origem, ou o nome da aplicação conectada.';

create index on valor.auditoria (inquilino_id, tabela, chave, momento desc);
create index on valor.auditoria (inquilino_id, momento desc);
create index on valor.auditoria (usuario_id, momento desc);

-- ------------------------------------------------ leitura do próprio catálogo

-- A coluna da chave primária, para o gatilho servir qualquer tabela sem saber
-- o nome dela de antemão.
create or replace function valor.coluna_chave(p_relacao oid)
returns text language sql stable as $$
  select a.attname::text
    from pg_index i
    join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any (i.indkey)
   where i.indrelid = p_relacao
     and i.indisprimary
     and i.indnatts = 1
   limit 1;
$$;
comment on function valor.coluna_chave(oid) is
  'Devolve a coluna da chave primária simples da tabela. Nulo quando a chave é composta.';

-- As colunas confidenciais saem do próprio banco: são as que têm
-- comment on column começando pela palavra CONFIDENCIAL, como manda a seção 7
-- do contrato técnico. Marcar a coluna já basta para ela nunca vazar na trilha.
create or replace function valor.colunas_confidenciais(p_relacao oid)
returns text[] language sql stable as $$
  select coalesce(array_agg(a.attname::text order by a.attname), array[]::text[])
    from pg_attribute a
   where a.attrelid = p_relacao
     and a.attnum > 0
     and not a.attisdropped
     and upper(btrim(coalesce(col_description(a.attrelid, a.attnum), ''))) like 'CONFIDENCIAL%';
$$;
comment on function valor.colunas_confidenciais(oid) is
  'Lista as colunas cuja descrição começa com a palavra CONFIDENCIAL. É a fonte da máscara da trilha.';

-- ------------------------------------------------------------ o gatilho único

create or replace function valor.auditar() returns trigger
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  -- Carimbo de atualização não entra no diff: a própria linha da trilha já
  -- guarda o momento e o usuário, então repetir viraria ruído.
  c_ignoradas     constant text[] := array['atualizado_em', 'atualizado_por'];
  c_omitido       constant jsonb  := to_jsonb('[omitido]'::text);
  v_confidenciais text[];
  v_chave_coluna  text;
  v_antes         jsonb;
  v_depois        jsonb;
  v_mudancas      jsonb := '{}'::jsonb;
  v_operacao      valor.operacao_auditada;
  v_coluna        text;
  v_valor_depois  jsonb;
  v_valor_antes   jsonb;
begin
  if tg_op = 'DELETE' then
    raise exception
      'Nesta plataforma nada é apagado. Preencha arquivado_em em vez de remover a linha de %.%.',
      tg_table_schema, tg_table_name
      using errcode = 'restrict_violation';
  end if;

  v_chave_coluna  := valor.coluna_chave(tg_relid);
  v_confidenciais := valor.colunas_confidenciais(tg_relid);

  if tg_op = 'INSERT' then
    v_operacao := 'insercao';
    v_antes    := '{}'::jsonb;
    v_depois   := to_jsonb(new);
  else
    v_antes  := to_jsonb(old);
    v_depois := to_jsonb(new);
    if (v_antes ->> 'arquivado_em') is null and (v_depois ->> 'arquivado_em') is not null then
      v_operacao := 'arquivamento';
    else
      v_operacao := 'atualizacao';
    end if;
  end if;

  for v_coluna, v_valor_depois in select e.key, e.value from jsonb_each(v_depois) e
  loop
    if v_coluna = any (c_ignoradas) then
      continue;
    end if;

    v_valor_antes := v_antes -> v_coluna;

    if tg_op = 'INSERT' then
      if v_valor_depois is null or jsonb_typeof(v_valor_depois) = 'null' then
        continue;
      end if;
    elsif v_valor_antes is not distinct from v_valor_depois then
      continue;
    end if;

    if v_coluna = any (v_confidenciais) then
      v_mudancas := v_mudancas || jsonb_build_object(
        v_coluna, jsonb_build_object('antes', c_omitido, 'depois', c_omitido, 'confidencial', true));
    else
      v_mudancas := v_mudancas || jsonb_build_object(
        v_coluna, jsonb_build_object('antes', v_valor_antes, 'depois', v_valor_depois));
    end if;
  end loop;

  if tg_op = 'UPDATE' and v_mudancas = '{}'::jsonb then
    return null;
  end if;

  insert into valor.auditoria
    (inquilino_id, esquema, tabela, chave, operacao, mudancas, usuario_id, perfil, origem)
  values (
    nullif(v_depois ->> 'inquilino_id', '')::uuid,
    tg_table_schema,
    tg_table_name,
    (v_depois ->> v_chave_coluna)::uuid,
    v_operacao,
    v_mudancas,
    valor.usuario_atual(),
    valor.perfil_atual(),
    coalesce(valor.claim('origem'), nullif(current_setting('application_name', true), ''), 'desconhecida')
  );

  return null;
end;
$funcao$;
comment on function valor.auditar() is
  'Gatilho genérico de auditoria. Serve qualquer tabela de chave uuid simples, sem uma linha de código por tabela.';

-- ----------------------------------------------------- a trilha é imutável

create or replace function valor.auditoria_imutavel() returns trigger
language plpgsql as $$
begin
  raise exception
    'A trilha de auditoria é imutável. Ninguém atualiza, arquiva nem remove linha de valor.auditoria.'
    using errcode = 'restrict_violation';
  return null;
end;
$$;

create trigger auditoria_sem_alteracao
  before update or delete on valor.auditoria
  for each row execute function valor.auditoria_imutavel();

create trigger auditoria_sem_esvaziar
  before truncate on valor.auditoria
  for each statement execute function valor.auditoria_imutavel();

-- ------------------------------------------------- pendurar em uma tabela

create or replace function valor.pendurar_auditoria(p_esquema text, p_tabela text)
returns void language plpgsql as $funcao$
declare
  v_relacao oid;
  v_chave   text;
  v_tipo    text;
begin
  v_relacao := to_regclass(quote_ident(p_esquema) || '.' || quote_ident(p_tabela));
  if v_relacao is null then
    raise exception 'A tabela %.% não existe, então a auditoria não pode ser pendurada nela.',
      p_esquema, p_tabela;
  end if;

  v_chave := valor.coluna_chave(v_relacao);
  if v_chave is null then
    raise exception 'A tabela %.% não tem chave primária de coluna única, e a trilha precisa de uma.',
      p_esquema, p_tabela;
  end if;

  select format_type(a.atttypid, null) into v_tipo
    from pg_attribute a
   where a.attrelid = v_relacao and a.attname = v_chave;
  if v_tipo <> 'uuid' then
    raise exception 'A chave primária de %.% é do tipo %, e a trilha guarda chave uuid.',
      p_esquema, p_tabela, v_tipo;
  end if;

  execute format('drop trigger if exists auditoria_registro on %I.%I', p_esquema, p_tabela);
  execute format(
    'create trigger auditoria_registro after insert or update on %I.%I
       for each row execute function valor.auditar()', p_esquema, p_tabela);

  execute format('drop trigger if exists auditoria_sem_apagar on %I.%I', p_esquema, p_tabela);
  execute format(
    'create trigger auditoria_sem_apagar before delete on %I.%I
       for each row execute function valor.auditar()', p_esquema, p_tabela);
end;
$funcao$;
comment on function valor.pendurar_auditoria(text, text) is
  'Pendura a trilha numa tabela: um gatilho que registra inserção e atualização, e outro que barra a remoção.';

set client_min_messages = warning;
do $$
begin
  perform valor.pendurar_auditoria('valor', 'negocios');
  perform valor.pendurar_auditoria('valor', 'artefatos');
  perform valor.pendurar_auditoria('valor', 'contas');
  perform valor.pendurar_auditoria('valor', 'usuarios');
end;
$$;
reset client_min_messages;

-- ------------------------------------------------------------- segurança

alter table valor.auditoria enable row level security;

-- Quem lê a trilha inteira do inquilino é o administrador. O restante do time
-- da casa enxerga apenas a própria pegada, e nada mais. Gente de fora não
-- alcança a trilha de jeito nenhum, nem o parceiro nem o participante, porque a
-- pegada revela o que a casa fez com o dado do cliente.
-- Não existe política de escrita: a única porta de entrada é o gatilho
-- valor.auditar, que roda como dono da tabela. E os gatilhos de imutabilidade
-- barram atualização, remoção e esvaziamento até para quem é dono.
create policy auditoria_le_admin on valor.auditoria for select
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy auditoria_le_propria_pegada on valor.auditoria for select
  using (valor.do_inquilino(inquilino_id)
         and valor.time_da_casa()
         and usuario_id is not null
         and usuario_id = valor.usuario_atual());


-- ==========================================================================
-- 0014_views_forecast_e_higiene.sql
-- ==========================================================================
-- 0014 · Visões de forecast e de higiene do funil
-- Dono: agente de painéis. Nenhum outro agente altera este arquivo.
--
-- O coração do método. A previsão de receita sai do artefato validado com o
-- cliente, nunca do percentual de probabilidade. A coluna valor.negocios.probabilidade
-- existe como leitura qualitativa do time e não entra em nenhuma conta daqui.
--
-- Toda visão nasce com security_invoker = true. Sem isso a leitura correria com
-- os direitos do dono da visão, e o parceiro leria pela visão exatamente o que a
-- política de linha proíbe na tabela. O security_barrier impede que um predicado
-- barato empurrado para dentro da visão veja linha que a política esconderia.

-- ------------------------------------------------------------------ rótulos

create or replace function valor.fase_rotulo(p_fase smallint)
returns text language sql immutable as $$
  select case p_fase
    when 0 then 'Lead'
    when 1 then 'Seleção Estratégica'
    when 2 then 'Exploração Profunda'
    when 3 then 'Conexão de Valor'
    when 4 then 'Confirmação de Compromisso'
    when 5 then 'Execução de Excelência'
    when 6 then 'Cultivo de Valor'
    when 7 then 'Parceria de Crescimento'
    when 9 then 'Arquivo'
    else 'Fase fora do método'
  end;
$$;
comment on function valor.fase_rotulo(smallint) is
  'O nome de tela de cada fase. A fase 8, Gestão Contínua, é a plataforma inteira e não aparece no funil.';

create or replace function valor.categoria_rotulo(p_categoria valor.forecast_categoria)
returns text language sql immutable as $$
  select case p_categoria
    when 'compromisso' then 'Compromisso, Contrato de Valor validado com o cliente'
    when 'possivel'    then 'Possível, Plano de Trabalho validado com o cliente'
    when 'aberto'      then 'Aberto, Plano de Negócio validado com o cliente'
    else                    'Fora, nenhum artefato validado com o cliente'
  end;
$$;
comment on function valor.categoria_rotulo(valor.forecast_categoria) is
  'O rótulo de tela da categoria de forecast, com o artefato que sustenta cada uma.';

-- Código do trimestre de uma data, no formato 2026t3. É a chave de período que
-- a meta usa em valor.configuracoes e que o forecast usa para agrupar.
create or replace function valor.codigo_trimestre(p_data date)
returns text language sql immutable as $$
  select case when p_data is null then null
              else extract(year from p_data)::integer::text
                   || 't' || extract(quarter from p_data)::integer::text end;
$$;
comment on function valor.codigo_trimestre(date) is
  'Código do trimestre de uma data, no formato 2026t3.';

-- ------------------------------------------------------- meta do período

-- A meta mora em valor.configuracoes, com chave montada por esta função.
-- Sem meta cadastrada, valor.vw_cobertura devolve indisponível, e nunca um número.
create or replace function valor.chave_meta(
  p_granularidade text, p_codigo text, p_usuario uuid default null)
returns text language sql immutable as $$
  select case when p_usuario is null
              then 'meta.casa.'   || p_granularidade || '.' || p_codigo
              else 'meta.pessoa.' || p_granularidade || '.' || p_codigo || '.' || p_usuario::text
         end;
$$;
comment on function valor.chave_meta(text, text, uuid) is
  'Monta a chave da meta em valor.configuracoes. Granularidade anual ou trimestral. Código 2026 ou 2026t3. Usuário nulo é a meta da casa.';

create or replace function valor.gravar_meta(
  p_inquilino uuid, p_granularidade text, p_codigo text,
  p_valor numeric, p_usuario uuid default null)
returns void language plpgsql as $$
declare
  v_chave  text := valor.chave_meta(p_granularidade, p_codigo, p_usuario);
  v_rotulo text;
begin
  if p_granularidade not in ('anual', 'trimestral') then
    raise exception 'Granularidade da meta precisa ser anual ou trimestral. Veio %.', p_granularidade;
  end if;
  if p_valor is null or p_valor <= 0 then
    raise exception 'Meta precisa ser um valor positivo. Veio %.', p_valor;
  end if;
  v_rotulo := case when p_usuario is null then 'Meta da casa · ' else 'Meta da pessoa · ' end
              || p_granularidade || ' ' || p_codigo;
  insert into valor.configuracoes (inquilino_id, chave, valor, rotulo, grupo, editavel_por)
  values (p_inquilino, v_chave, to_jsonb(p_valor), v_rotulo, 'meta', 'lider')
  on conflict (inquilino_id, chave) do update
    set valor = excluded.valor, rotulo = excluded.rotulo, arquivado_em = null;
end;
$$;
comment on function valor.gravar_meta(uuid, text, text, numeric, uuid) is
  'Cadastra ou corrige a meta do período. É o único caminho que valor.vw_cobertura reconhece.';

-- ------------------------------------------------- negócio a negócio

-- Um negócio por linha, com a categoria de forecast, as quatro invariantes de
-- higiene como booleano, dias parado, dias até a decisão e o papel de cada um.
create view valor.vw_negocios_forecast
with (security_invoker = true, security_barrier = true) as
with ativo as (
  select n.*
    from valor.negocios n
   where n.arquivado_em is null
     and n.desfecho is null
     and n.fase between 0 and 7
),
validado as (
  select a.negocio_id,
         bool_or(a.tipo = 'contrato_valor') as tem_contrato_valor,
         bool_or(a.tipo = 'plano_trabalho') as tem_plano_trabalho,
         bool_or(a.tipo = 'plano_negocio')  as tem_plano_negocio,
         max(a.validado_em) filter (where a.tipo = 'contrato_valor') as contrato_valor_em,
         max(a.validado_em) filter (where a.tipo = 'plano_trabalho') as plano_trabalho_em,
         max(a.validado_em) filter (where a.tipo = 'plano_negocio')  as plano_negocio_em
    from valor.artefatos a
   where a.arquivado_em is null
     and a.status = 'validado_com_cliente'
   group by a.negocio_id
),
papeis as (
  select pn.negocio_id,
         (array_agg(pn.usuario_id order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'gerente_contas'))[1] as gerente_contas_id,
         (array_agg(u.nome order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'gerente_contas'))[1] as gerente_contas_nome,
         (array_agg(pn.usuario_id order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'conselheiro'))[1] as conselheiro_id,
         (array_agg(u.nome order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'conselheiro'))[1] as conselheiro_nome,
         (array_agg(pn.entrou_na_fase order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'conselheiro'))[1] as conselheiro_entrou_na_fase,
         (array_agg(u.nome order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'pre_vendas'))[1] as pre_vendas_nome,
         (array_agg(u.nome order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'gerente_projetos'))[1] as gerente_projetos_nome,
         (array_agg(u.nome order by pn.principal desc, pn.criado_em)
            filter (where pn.papel = 'assessor'))[1] as assessor_nome,
         count(*) as papeis_ativos
    from valor.papeis_negocio pn
    left join valor.usuarios u on u.id = pn.usuario_id
   where pn.ativo
     and pn.arquivado_em is null
   group by pn.negocio_id
)
select
  n.inquilino_id,
  n.id                                as negocio_id,
  n.titulo,
  n.conta_id,
  c.nome                              as conta_nome,
  c.tier                              as conta_tier,
  n.oferta_id,
  o.nome                              as oferta_nome,
  n.fase,
  valor.fase_rotulo(n.fase)           as fase_rotulo,
  n.rota,
  n.origem,
  n.nivel_contrato,
  n.valor_total,
  n.valor_recorrente_mes,
  n.meses_recorrencia,
  coalesce(n.valor_total,
           n.valor_recorrente_mes * n.meses_recorrencia,
           0)::numeric(14,2)          as valor_considerado,

  -- A categoria nasce do artefato validado com o cliente, jamais da probabilidade.
  case when coalesce(v.tem_contrato_valor, false) then 'compromisso'
       when coalesce(v.tem_plano_trabalho, false) then 'possivel'
       when coalesce(v.tem_plano_negocio,  false) then 'aberto'
       else 'fora'
  end::valor.forecast_categoria       as categoria,
  case when coalesce(v.tem_contrato_valor, false) then 'contrato_valor'
       when coalesce(v.tem_plano_trabalho, false) then 'plano_trabalho'
       when coalesce(v.tem_plano_negocio,  false) then 'plano_negocio'
  end::valor.tipo_artefato            as artefato_que_sustenta,
  case when coalesce(v.tem_contrato_valor, false) then v.contrato_valor_em
       when coalesce(v.tem_plano_trabalho, false) then v.plano_trabalho_em
       when coalesce(v.tem_plano_negocio,  false) then v.plano_negocio_em
  end                                 as artefato_validado_em,

  -- As quatro invariantes de higiene, na mesma leitura de valor.negocios_fora_da_higiene.
  h.tem_proximo_passo,
  h.decisao_no_futuro,
  h.interacao_recente,
  h.tem_artefato_da_fase,
  (n.fase between 1 and 4)            as exige_higiene,
  case when n.fase between 1 and 4
       then (h.tem_proximo_passo and h.decisao_no_futuro
             and h.interacao_recente and h.tem_artefato_da_fase)
       else null
  end                                 as na_higiene,
  case when n.fase between 1 and 4 then
    array_remove(array[
      case when not h.tem_proximo_passo    then 'Próximo passo com data definida' end,
      case when not h.decisao_no_futuro    then 'Data da decisão do cliente no futuro' end,
      case when not h.interacao_recente    then 'Interação dentro da janela de higiene' end,
      case when not h.tem_artefato_da_fase then 'Artefato da fase atual registrado' end
    ], null)
  else '{}'::text[] end               as invariantes_quebradas,
  case when n.fase between 1 and 4 then
    (not h.tem_proximo_passo)::integer + (not h.decisao_no_futuro)::integer
    + (not h.interacao_recente)::integer + (not h.tem_artefato_da_fase)::integer
  else 0 end                          as quantas_invariantes_quebradas,

  n.proximo_passo,
  n.proximo_passo_data,
  n.proximo_passo_responsavel,
  n.data_decisao_cliente,
  (n.data_decisao_cliente - current_date) as dias_ate_decisao,
  n.ultima_interacao,
  n.entrou_na_fase_em,
  p.dias_parado,
  p.limite_dias,
  (p.dias_parado > p.limite_dias)     as esta_parado,

  pa.gerente_contas_id,
  coalesce(pa.gerente_contas_nome, ug.nome) as gerente_contas_nome,
  pa.conselheiro_id,
  pa.conselheiro_nome,
  pa.conselheiro_entrou_na_fase,
  pa.pre_vendas_nome,
  pa.gerente_projetos_nome,
  pa.assessor_nome,
  n.parceiro_id,
  pr.nome                             as parceiro_nome,
  coalesce(pa.papeis_ativos, 0)       as papeis_ativos
from ativo n
join valor.contas c on c.id = n.conta_id
left join valor.ofertas o   on o.id = n.oferta_id
left join valor.parceiros pr on pr.id = n.parceiro_id
left join valor.usuarios ug  on ug.id = c.gerente_contas_id
left join validado v on v.negocio_id = n.id
left join papeis   pa on pa.negocio_id = n.id
cross join lateral (
  select
    (n.proximo_passo is not null
     and n.proximo_passo_data is not null
     and n.proximo_passo_data >= current_date)            as tem_proximo_passo,
    (n.data_decisao_cliente is not null
     and n.data_decisao_cliente >= current_date)          as decisao_no_futuro,
    (coalesce(n.ultima_interacao, n.criado_em::date)
     >= current_date
        - valor.configuracao_num(n.inquilino_id, 'higiene.dias_sem_interacao', 30)::integer)
                                                          as interacao_recente,
    exists (
      select 1 from valor.artefatos a
       where a.negocio_id = n.id
         and a.tipo = valor.artefato_exigido_na_fase(n.fase)
         and a.arquivado_em is null
    )                                                     as tem_artefato_da_fase
) h
cross join lateral (
  select (current_date - coalesce(n.ultima_interacao, n.entrou_na_fase_em, n.criado_em::date))
           as dias_parado,
         valor.limite_dias_parado(n.inquilino_id, n.fase) as limite_dias
) p;

comment on view valor.vw_negocios_forecast is
  'Um negócio ativo por linha, com a categoria de forecast tirada do artefato validado com o cliente, as quatro invariantes de higiene, dias parado, dias até a decisão e o papel de cada um.';

-- ---------------------------------------------- pipeline declarado e auditado

-- Pipeline declarado é a soma de tudo que está nas fases 1 a 4. Pipeline
-- auditado é a soma do que passa nas quatro invariantes. As duas linhas
-- aparecem lado a lado, e a diferença é o valor travado.
create view valor.vw_pipeline_higiene
with (security_invoker = true, security_barrier = true) as
with base as (
  select f.*
    from valor.vw_negocios_forecast f
   where f.exige_higiene
     and not valor.eh_parceiro()
)
select
  b.inquilino_id,
  count(*)                                                       as negocios_declarados,
  sum(b.valor_considerado)::numeric(14,2)                        as pipeline_declarado,
  count(*) filter (where b.na_higiene)                           as negocios_auditados,
  coalesce(sum(b.valor_considerado) filter (where b.na_higiene), 0)::numeric(14,2)
                                                                 as pipeline_auditado,
  count(*) filter (where not b.na_higiene)                       as negocios_travados,
  coalesce(sum(b.valor_considerado) filter (where not b.na_higiene), 0)::numeric(14,2)
                                                                 as valor_travado,
  round(100.0 * count(*) filter (where b.na_higiene) / nullif(count(*), 0), 1)
                                                                 as percentual_negocios_auditados,
  round(100.0 * coalesce(sum(b.valor_considerado) filter (where b.na_higiene), 0)
        / nullif(sum(b.valor_considerado), 0), 1)                as percentual_valor_auditado,

  count(*) filter (where not b.tem_proximo_passo)                as quebra_proximo_passo,
  count(*) filter (where not b.decisao_no_futuro)                as quebra_decisao_no_futuro,
  count(*) filter (where not b.interacao_recente)                as quebra_interacao_recente,
  count(*) filter (where not b.tem_artefato_da_fase)             as quebra_artefato_da_fase,

  coalesce(sum(b.valor_considerado) filter (where not b.tem_proximo_passo), 0)::numeric(14,2)
                                                                 as travado_por_proximo_passo,
  coalesce(sum(b.valor_considerado) filter (where not b.decisao_no_futuro), 0)::numeric(14,2)
                                                                 as travado_por_decisao_no_futuro,
  coalesce(sum(b.valor_considerado) filter (where not b.interacao_recente), 0)::numeric(14,2)
                                                                 as travado_por_interacao_recente,
  coalesce(sum(b.valor_considerado) filter (where not b.tem_artefato_da_fase), 0)::numeric(14,2)
                                                                 as travado_por_artefato_da_fase
from base b
group by b.inquilino_id;

comment on view valor.vw_pipeline_higiene is
  'Pipeline declarado e pipeline auditado lado a lado, a contagem de cada invariante quebrada e o valor travado por causa delas. O valor travado é a diferença entre os dois pipelines.';

-- ------------------------------------------ forecast por categoria e período

create view valor.vw_forecast_por_categoria
with (security_invoker = true, security_barrier = true) as
select
  f.inquilino_id,
  coalesce(valor.codigo_trimestre(f.data_decisao_cliente), 'sem_data') as periodo_codigo,
  case when f.data_decisao_cliente is null then 'Sem data de decisão'
       else 'Trimestre ' || extract(quarter from f.data_decisao_cliente)::integer::text
            || ' de ' || extract(year from f.data_decisao_cliente)::integer::text
  end                                                        as periodo_rotulo,
  date_trunc('quarter', f.data_decisao_cliente)::date         as periodo_inicio,
  (date_trunc('quarter', f.data_decisao_cliente)
     + interval '3 months' - interval '1 day')::date          as periodo_fim,
  f.categoria,
  valor.categoria_rotulo(f.categoria)                         as categoria_rotulo,
  case f.categoria when 'compromisso' then 1 when 'possivel' then 2
                   when 'aberto' then 3 else 4 end            as ordem_categoria,
  count(*)                                                    as negocios,
  sum(f.valor_considerado)::numeric(14,2)                     as valor,
  count(*) filter (where coalesce(f.na_higiene, true))        as negocios_auditados,
  coalesce(sum(f.valor_considerado) filter (where coalesce(f.na_higiene, true)), 0)::numeric(14,2)
                                                              as valor_auditado
from valor.vw_negocios_forecast f
where not valor.eh_parceiro()
group by f.inquilino_id, 2, 3, 4, 5, f.categoria;

comment on view valor.vw_forecast_por_categoria is
  'Valor e contagem por categoria de forecast, quebrados pelo trimestre da data da decisão do cliente. Negócio sem data cai no período sem_data.';

-- --------------------------------------------------------------- cobertura

-- Cobertura é um dividido pela taxa de ganho, com a não decisão dentro do
-- denominador: o negócio que venceu sem o cliente decidir conta como negócio
-- que não virou receita. Sem meta cadastrada, ou sem histórico suficiente para
-- calcular a taxa, a visão devolve indisponível e nenhum número.
--
-- A meta é lida de duas formas, e em nenhuma delas com valor padrão. Ler meta
-- com padrão inventaria uma meta que ninguém definiu, e um número errado numa
-- tela de decisão é pior do que a ausência do número.
--
--   1. As quatro chaves da tela de configuração, que nascem vazias de propósito:
--      meta.anual_casa e meta.trimestral_casa, escalares do período corrente, e
--      meta.anual_por_pessoa e meta.trimestral_por_pessoa, objetos com o
--      identificador do usuário na chave. Valor jsonb null ou objeto vazio não
--      é meta, é ausência de meta.
--   2. As chaves com período escrito, montadas por valor.chave_meta, para
--      cadastrar meta de período que não é o corrente. Quando as duas existirem
--      para o mesmo período, a de período escrito vence, por ser a mais precisa.
create view valor.vw_cobertura
with (security_invoker = true, security_barrier = true) as
with metas_com_periodo as (
  select
    1                                                            as precedencia,
    c.inquilino_id,
    split_part(c.chave, '.', 2)                                  as escopo,
    split_part(c.chave, '.', 3)                                  as granularidade,
    split_part(c.chave, '.', 4)                                  as periodo_codigo,
    nullif(split_part(c.chave, '.', 5), '')::uuid                as usuario_id,
    case when jsonb_typeof(c.valor) = 'number'
         then (c.valor #>> '{}')::numeric end                    as meta_valor
  from valor.configuracoes c
  where c.arquivado_em is null
    and c.chave ~ '^meta\.(casa|pessoa)\.(anual|trimestral)\.'
),
metas_da_tela as (
  select 2, c.inquilino_id, 'casa', 'anual',
         extract(year from current_date)::integer::text, null::uuid,
         case when jsonb_typeof(c.valor) = 'number' then (c.valor #>> '{}')::numeric end
    from valor.configuracoes c
   where c.arquivado_em is null and c.chave = 'meta.anual_casa'
  union all
  select 2, c.inquilino_id, 'casa', 'trimestral',
         valor.codigo_trimestre(current_date), null::uuid,
         case when jsonb_typeof(c.valor) = 'number' then (c.valor #>> '{}')::numeric end
    from valor.configuracoes c
   where c.arquivado_em is null and c.chave = 'meta.trimestral_casa'
  union all
  select 2, c.inquilino_id, 'pessoa', 'anual',
         extract(year from current_date)::integer::text,
         substring(e.chave from
           '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')::uuid,
         case when jsonb_typeof(e.conteudo) = 'number' then (e.conteudo #>> '{}')::numeric end
    from valor.configuracoes c
    cross join lateral jsonb_each(c.valor) as e(chave, conteudo)
   where c.arquivado_em is null and c.chave = 'meta.anual_por_pessoa'
     and jsonb_typeof(c.valor) = 'object'
  union all
  select 2, c.inquilino_id, 'pessoa', 'trimestral',
         valor.codigo_trimestre(current_date),
         substring(e.chave from
           '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')::uuid,
         case when jsonb_typeof(e.conteudo) = 'number' then (e.conteudo #>> '{}')::numeric end
    from valor.configuracoes c
    cross join lateral jsonb_each(c.valor) as e(chave, conteudo)
   where c.arquivado_em is null and c.chave = 'meta.trimestral_por_pessoa'
     and jsonb_typeof(c.valor) = 'object'
),
metas as (
  select * from metas_com_periodo
  union all
  select * from metas_da_tela
),
metas_datadas as (
  select m.*,
    case m.granularidade
      when 'anual' then
        make_date(substring(m.periodo_codigo from '^(\d{4})$')::integer, 1, 1)
      when 'trimestral' then
        make_date(substring(m.periodo_codigo from '^(\d{4})t[1-4]$')::integer,
                  substring(m.periodo_codigo from '^\d{4}t([1-4])$')::integer * 3 - 2, 1)
    end as periodo_inicio
  from metas m
),
janelas as (
  select distinct on (d.inquilino_id, d.escopo, d.granularidade, d.periodo_codigo, d.usuario_id)
    d.*,
    case d.granularidade
      when 'anual'      then (d.periodo_inicio + interval '1 year'   - interval '1 day')::date
      when 'trimestral' then (d.periodo_inicio + interval '3 months' - interval '1 day')::date
    end as periodo_fim
  from metas_datadas d
  where d.periodo_inicio is not null
    and d.meta_valor is not null
  order by d.inquilino_id, d.escopo, d.granularidade, d.periodo_codigo, d.usuario_id, d.precedencia
),
decisoes as (
  select n.inquilino_id,
         count(*)                                                as decididos,
         count(*) filter (where n.desfecho = 'concluido')         as ganhos,
         count(*) filter (where n.desfecho in ('perdido', 'cancelado')) as perdidos,
         count(*) filter (where n.desfecho = 'vencido')           as sem_decisao
    from valor.negocios n
   where n.arquivado_em is null
     and n.desfecho is not null
   group by n.inquilino_id
),
spine as (
  select i.id as inquilino_id, j.escopo, j.granularidade, j.periodo_codigo,
         j.usuario_id, j.meta_valor, j.periodo_inicio, j.periodo_fim
    from valor.inquilinos i
    left join janelas j on j.inquilino_id = i.id
   where i.arquivado_em is null
     and not valor.eh_parceiro()
)
select
  s.inquilino_id,
  coalesce(s.escopo, 'casa')                                   as escopo,
  s.granularidade,
  s.periodo_codigo,
  s.periodo_inicio,
  s.periodo_fim,
  s.usuario_id,
  u.nome                                                       as usuario_nome,
  s.meta_valor::numeric(14,2)                                  as meta_valor,
  coalesce(d.decididos, 0)                                     as negocios_decididos,
  coalesce(d.ganhos, 0)                                        as negocios_ganhos,
  coalesce(d.perdidos, 0)                                      as negocios_perdidos,
  coalesce(d.sem_decisao, 0)                                   as negocios_sem_decisao,
  g.taxa_ganho,
  g.cobertura_necessaria,
  case when g.cobertura_necessaria is not null and s.meta_valor is not null
       then round(s.meta_valor * g.cobertura_necessaria, 2) end as pipeline_necessario,
  p.pipeline_disponivel::numeric(14,2)                          as pipeline_disponivel,
  case when s.meta_valor is not null and s.meta_valor > 0
       then round(p.pipeline_disponivel / s.meta_valor, 2) end  as cobertura_atual,
  case
    when s.meta_valor is null then 'indisponivel'
    when g.taxa_ganho is null then 'indisponivel'
    when p.pipeline_disponivel >= s.meta_valor * g.cobertura_necessaria then 'suficiente'
    else 'insuficiente'
  end                                                           as situacao,
  case
    when s.meta_valor is null
      then 'Sem meta cadastrada em valor.configuracoes para este período'
    when coalesce(d.decididos, 0) < g.amostra_minima
      then 'Histórico de decisões menor que a amostra mínima de '
           || g.amostra_minima::text || ' negócios'
    when coalesce(d.ganhos, 0) = 0
      then 'Nenhum negócio ganho no histórico, a taxa de ganho seria zero'
    else null
  end                                                           as motivo_indisponivel
from spine s
left join valor.usuarios u on u.id = s.usuario_id
left join decisoes d on d.inquilino_id = s.inquilino_id
cross join lateral (
  select valor.configuracao_num(s.inquilino_id, 'cobertura.amostra_minima', 5)::integer
           as amostra_minima
) a
cross join lateral (
  select a.amostra_minima,
         case when coalesce(d.decididos, 0) >= a.amostra_minima and coalesce(d.ganhos, 0) > 0
              then round(d.ganhos::numeric / d.decididos, 4) end as taxa_ganho,
         case when coalesce(d.decididos, 0) >= a.amostra_minima and coalesce(d.ganhos, 0) > 0
              then round(d.decididos::numeric / d.ganhos, 2) end as cobertura_necessaria
) g
cross join lateral (
  select coalesce(sum(coalesce(n.valor_total,
                               n.valor_recorrente_mes * n.meses_recorrencia, 0)), 0)
           as pipeline_disponivel
    from valor.negocios n
   where n.inquilino_id = s.inquilino_id
     and n.arquivado_em is null
     and n.desfecho is null
     and n.fase between 1 and 4
     and (s.periodo_inicio is null
          or n.data_decisao_cliente between s.periodo_inicio and s.periodo_fim)
     and (s.usuario_id is null
          or exists (select 1 from valor.papeis_negocio pn
                      where pn.negocio_id = n.id
                        and pn.usuario_id = s.usuario_id
                        and pn.papel = 'gerente_contas'
                        and pn.ativo and pn.arquivado_em is null))
) p;

comment on view valor.vw_cobertura is
  'Cobertura de pipeline: um dividido pela taxa de ganho, com a não decisão dentro do denominador. Sem meta cadastrada, ou sem histórico bastante, devolve indisponível e nenhum número.';

-- ------------------------------------------------------------ concentração

create view valor.vw_concentracao
with (security_invoker = true, security_barrier = true) as
with pipeline as (
  select n.inquilino_id, n.id, n.titulo, n.conta_id,
         coalesce(n.valor_total, n.valor_recorrente_mes * n.meses_recorrencia, 0) as valor_considerado
    from valor.negocios n
   where n.arquivado_em is null
     and n.desfecho is null
     and n.fase between 1 and 4
     and not valor.eh_parceiro()
),
posicionado as (
  select p.*,
         row_number() over (partition by p.inquilino_id order by p.valor_considerado desc, p.id)
           as posicao
    from pipeline p
),
resumo as (
  select q.inquilino_id,
         count(*)                                                     as negocios_no_pipeline,
         sum(q.valor_considerado)::numeric(14,2)                      as pipeline_declarado,
         coalesce(sum(q.valor_considerado) filter (where q.posicao <= 2), 0)::numeric(14,2)
                                                                      as valor_dos_dois_maiores,
         (array_agg(q.id     order by q.posicao))[1]                  as maior_negocio_id,
         (array_agg(q.titulo order by q.posicao))[1]                  as maior_negocio_titulo,
         (array_agg(q.valor_considerado order by q.posicao))[1]::numeric(14,2)
                                                                      as maior_negocio_valor,
         (array_agg(q.id     order by q.posicao))[2]                  as segundo_negocio_id,
         (array_agg(q.titulo order by q.posicao))[2]                  as segundo_negocio_titulo,
         (array_agg(q.valor_considerado order by q.posicao))[2]::numeric(14,2)
                                                                      as segundo_negocio_valor
    from posicionado q
   group by q.inquilino_id
)
select
  r.inquilino_id,
  r.negocios_no_pipeline,
  r.pipeline_declarado,
  r.valor_dos_dois_maiores,
  r.maior_negocio_id, r.maior_negocio_titulo, r.maior_negocio_valor,
  r.segundo_negocio_id, r.segundo_negocio_titulo, r.segundo_negocio_valor,
  case when r.pipeline_declarado > 0
       then round(r.valor_dos_dois_maiores / r.pipeline_declarado, 4) end as fracao_nos_dois_maiores,
  case when r.pipeline_declarado > 0
       then round(100 * r.valor_dos_dois_maiores / r.pipeline_declarado, 1) end
                                                                          as percentual_nos_dois_maiores,
  l.limite                                                                as limite_configurado,
  round(100 * l.limite, 1)                                                as limite_percentual,
  (r.pipeline_declarado > 0
   and r.negocios_no_pipeline > 2
   and (r.valor_dos_dois_maiores / r.pipeline_declarado) > l.limite)       as alarme,
  case when r.negocios_no_pipeline <= 2
       then 'Pipeline com dois negócios ou menos, a concentração não diz nada ainda'
       when r.pipeline_declarado = 0
       then 'Pipeline declarado igual a zero'
       when (r.valor_dos_dois_maiores / r.pipeline_declarado) > l.limite
       then 'Os dois maiores negócios passam do limite de concentração'
       else 'Concentração dentro do limite'
  end                                                                     as leitura
from resumo r
cross join lateral (
  select valor.configuracao_num(r.inquilino_id, 'alerta.concentracao_limite', 0.5) as limite
) l;

comment on view valor.vw_concentracao is
  'Concentração do pipeline nos dois maiores negócios. O alarme acende quando eles passam do limite configurado, que por padrão é metade do pipeline declarado.';

-- ---------------------------------------------------------- funil por fase

-- Quantidade, valor e mediana de dias em cada uma das nove fases. A mediana é o
-- que faz o alarme de negócio parado deixar de ser 30 dias fixos: com amostra
-- bastante, o limite sugerido passa a ser duas vezes a mediana da fase.
--
-- Duas colunas de limite aparecem lado a lado, de propósito:
--   limite_vigente_dias  o que valor.limite_dias_parado devolve hoje, lendo a
--                        tabela valor.historico_fases, que nasce depois desta
--                        migração e por isso é alcançada pela função, não por
--                        junção. Sem amostra bastante lá, ele fica no piso.
--   limite_sugerido_dias o mesmo cálculo feito aqui sobre o tempo de fase que
--                        os próprios negócios mostram. Serve de conferência
--                        enquanto o histórico ainda está sendo preenchido.
create view valor.vw_funil_por_fase
with (security_invoker = true, security_barrier = true) as
with fases(fase) as (
  values (0::smallint), (1::smallint), (2::smallint), (3::smallint), (4::smallint),
         (5::smallint), (6::smallint), (7::smallint), (9::smallint)
),
spine as (
  select i.id as inquilino_id, f.fase
    from valor.inquilinos i
   cross join fases f
   where i.arquivado_em is null
     and not valor.eh_parceiro()
),
negocios as (
  select n.inquilino_id,
         n.fase,
         coalesce(n.valor_total, n.valor_recorrente_mes * n.meses_recorrencia, 0) as valor_considerado,
         (coalesce(n.data_desfecho, current_date) - n.entrou_na_fase_em)          as dias_na_fase,
         (n.desfecho is null)                                                     as ativo
    from valor.negocios n
   where n.arquivado_em is null
)
select
  s.inquilino_id,
  s.fase,
  valor.fase_rotulo(s.fase)                                       as fase_rotulo,
  valor.artefato_exigido_na_fase(s.fase)                          as artefato_da_fase,
  count(n.inquilino_id) filter (where n.ativo)                    as negocios_ativos,
  count(n.inquilino_id)                                           as negocios_no_historico,
  coalesce(sum(n.valor_considerado) filter (where n.ativo), 0)::numeric(14,2)
                                                                  as valor_ativo,
  round((percentile_cont(0.5) within group (order by n.dias_na_fase))::numeric)::integer
                                                                  as mediana_dias_na_fase,
  round(avg(n.dias_na_fase))::integer                             as media_dias_na_fase,
  max(n.dias_na_fase)                                             as maior_dias_na_fase,
  p.piso                                                          as piso_dias_configurado,
  p.fator                                                         as fator_sobre_mediana,
  p.amostra_minima,
  valor.limite_dias_parado(s.inquilino_id, s.fase)                as limite_vigente_dias,
  case when count(n.inquilino_id) >= p.amostra_minima
        and percentile_cont(0.5) within group (order by n.dias_na_fase) is not null
       then greatest(1, ceil((percentile_cont(0.5) within group (order by n.dias_na_fase))::numeric
                             * p.fator)::integer)
       else p.piso
  end                                                             as limite_sugerido_dias,
  case when count(n.inquilino_id) >= p.amostra_minima
        and percentile_cont(0.5) within group (order by n.dias_na_fase) is not null
       then 'mediana' else 'piso'
  end                                                             as origem_do_limite
from spine s
left join negocios n on n.inquilino_id = s.inquilino_id and n.fase = s.fase
cross join lateral (
  select valor.configuracao_num(s.inquilino_id, 'alerta.negocio_parado_dias_piso', 30)::integer as piso,
         valor.configuracao_num(s.inquilino_id, 'alerta.negocio_parado_fator_mediana', 2)       as fator,
         valor.configuracao_num(s.inquilino_id, 'alerta.negocio_parado_amostra_minima', 5)::integer
           as amostra_minima
) p
group by s.inquilino_id, s.fase, p.piso, p.fator, p.amostra_minima;

comment on view valor.vw_funil_por_fase is
  'Quantidade, valor e mediana de dias em cada uma das nove fases. O limite sugerido vira duas vezes a mediana quando a amostra da fase alcança o mínimo configurado, e fica no piso enquanto não houver histórico.';


-- ==========================================================================
-- 0015_views_paineis.sql
-- ==========================================================================
-- 0015 · Visões de painel, uma por pergunta
-- Dono: agente de painéis. Nenhum outro agente altera este arquivo.
--
-- Cada visão responde uma pergunta só, e devolve poucas colunas largas em vez
-- de muitas linhas estreitas, porque é isso que a interface consegue montar sem
-- refazer conta nenhuma.
--
-- Toda visão nasce com security_invoker = true. É o modo invocador que faz a
-- política de linha das tabelas de origem continuar valendo para quem lê. Sem
-- ele a leitura correria com os direitos do dono da visão, e o parceiro leria
-- pela visão o que a política proíbe na tabela.

-- ------------------------------------------- painel do gerente de contas

-- O que é meu, o que está atrasado, o que decide esta semana.
create view valor.vw_painel_gerente_contas
with (security_invoker = true, security_barrier = true) as
select
  f.inquilino_id,
  valor.usuario_atual()                      as usuario_id,
  f.negocio_id,
  f.titulo,
  f.conta_id,
  f.conta_nome,
  f.conta_tier,
  f.fase,
  f.fase_rotulo,
  f.oferta_nome,
  f.categoria,
  valor.categoria_rotulo(f.categoria)        as categoria_rotulo,
  f.valor_considerado,
  f.data_decisao_cliente,
  f.dias_ate_decisao,
  (f.data_decisao_cliente is not null
   and f.data_decisao_cliente between current_date and current_date + 7)
                                             as decide_esta_semana,
  f.proximo_passo,
  f.proximo_passo_data,
  (f.proximo_passo_data is not null and f.proximo_passo_data < current_date)
                                             as proximo_passo_vencido,
  f.ultima_interacao,
  f.dias_parado,
  f.limite_dias,
  f.esta_parado,
  f.tem_proximo_passo,
  f.decisao_no_futuro,
  f.interacao_recente,
  f.tem_artefato_da_fase,
  f.exige_higiene,
  f.na_higiene,
  f.invariantes_quebradas,
  f.quantas_invariantes_quebradas,
  f.conselheiro_nome,
  f.parceiro_nome,
  x.atividades_vencidas,
  x.alertas_abertos,
  case
    when f.esta_parado                                            then 'parado'
    when f.exige_higiene and not f.na_higiene                     then 'fora_da_higiene'
    when f.data_decisao_cliente is not null
         and f.data_decisao_cliente between current_date and current_date + 7
                                                                  then 'decide_esta_semana'
    when f.proximo_passo_data is not null
         and f.proximo_passo_data < current_date                  then 'proximo_passo_vencido'
    else 'em_dia'
  end                                        as grupo,
  case
    when f.esta_parado                                            then 'Parado acima do limite'
    when f.exige_higiene and not f.na_higiene                     then 'Fora da higiene'
    when f.data_decisao_cliente is not null
         and f.data_decisao_cliente between current_date and current_date + 7
                                                                  then 'Decide esta semana'
    when f.proximo_passo_data is not null
         and f.proximo_passo_data < current_date                  then 'Próximo passo vencido'
    else 'Em dia'
  end                                        as grupo_rotulo,
  case
    when f.esta_parado                                            then 1
    when f.exige_higiene and not f.na_higiene                     then 2
    when f.data_decisao_cliente is not null
         and f.data_decisao_cliente between current_date and current_date + 7
                                                                  then 3
    when f.proximo_passo_data is not null
         and f.proximo_passo_data < current_date                  then 4
    else 5
  end                                        as ordem_grupo
from valor.vw_negocios_forecast f
cross join lateral (
  select
    (select count(*) from valor.atividades a
      where a.negocio_id = f.negocio_id
        and a.arquivado_em is null
        and a.estado not in ('concluida', 'cancelada')
        and a.prazo is not null and a.prazo < current_date)        as atividades_vencidas,
    (select count(*) from valor.alertas al
      where al.entidade = 'negocios'
        and al.entidade_chave = f.negocio_id
        and al.arquivado_em is null
        and al.status in ('aberto', 'reconhecido'))                as alertas_abertos
) x
where not valor.eh_parceiro()
  and valor.usuario_atual() is not null
  and ( f.gerente_contas_id = valor.usuario_atual()
        or exists (select 1 from valor.contas c
                    where c.id = f.conta_id
                      and c.gerente_contas_id = valor.usuario_atual())
        or exists (select 1 from valor.papeis_negocio pn
                    where pn.negocio_id = f.negocio_id
                      and pn.usuario_id = valor.usuario_atual()
                      and pn.ativo and pn.arquivado_em is null) );

comment on view valor.vw_painel_gerente_contas is
  'A carteira de quem está na sessão: o que é meu, o que está parado ou fora da higiene, e o que o cliente decide nos próximos sete dias.';

-- ------------------------------------------------------------ painel do dono

-- O número da casa, margem, concentração, cobertura e higiene, numa linha só.
-- A guarda de confidencialidade deixa a visão vazia para quem não pode ver
-- margem, que é o mesmo critério de valor.margem_contrato.
create view valor.vw_painel_dono
with (security_invoker = true, security_barrier = true) as
select
  i.id                                        as inquilino_id,
  i.nome                                      as inquilino_nome,

  coalesce(h.negocios_declarados, 0)          as negocios_declarados,
  coalesce(h.pipeline_declarado, 0)::numeric(14,2)  as pipeline_declarado,
  coalesce(h.negocios_auditados, 0)           as negocios_auditados,
  coalesce(h.pipeline_auditado, 0)::numeric(14,2)   as pipeline_auditado,
  coalesce(h.valor_travado, 0)::numeric(14,2)       as valor_travado,
  h.percentual_valor_auditado,
  coalesce(h.quebra_proximo_passo, 0)         as quebra_proximo_passo,
  coalesce(h.quebra_decisao_no_futuro, 0)     as quebra_decisao_no_futuro,
  coalesce(h.quebra_interacao_recente, 0)     as quebra_interacao_recente,
  coalesce(h.quebra_artefato_da_fase, 0)      as quebra_artefato_da_fase,

  coalesce(fc.valor_compromisso, 0)::numeric(14,2)  as forecast_compromisso,
  coalesce(fc.valor_possivel, 0)::numeric(14,2)     as forecast_possivel,
  coalesce(fc.valor_aberto, 0)::numeric(14,2)       as forecast_aberto,
  coalesce(fc.valor_fora, 0)::numeric(14,2)         as forecast_fora,

  co.negocios_no_pipeline,
  co.valor_dos_dois_maiores,
  co.percentual_nos_dois_maiores,
  coalesce(co.alarme, false)                  as concentracao_em_alarme,

  cb.periodo_codigo                           as cobertura_periodo,
  cb.meta_valor                               as meta_do_periodo,
  cb.taxa_ganho,
  cb.cobertura_necessaria,
  cb.pipeline_necessario,
  cb.pipeline_disponivel                      as pipeline_do_periodo,
  cb.cobertura_atual,
  coalesce(cb.situacao, 'indisponivel')       as cobertura_situacao,
  cb.motivo_indisponivel                      as cobertura_motivo,

  coalesce(m.faturamento_bruto, 0)::numeric(14,2)   as faturamento_bruto,
  coalesce(m.margem, 0)::numeric(14,2)              as margem,
  m.margem_percentual,

  coalesce(ct.contratos_vigentes, 0)          as contratos_vigentes,
  coalesce(ct.receita_mensal_contratada, 0)::numeric(14,2) as receita_mensal_contratada,
  coalesce(cc.contas_cliente, 0)              as contas_cliente,
  coalesce(al.alertas_vermelhos, 0)           as alertas_vermelhos,
  coalesce(al.alertas_amarelos, 0)            as alertas_amarelos,
  coalesce(al.alertas_verdes, 0)              as alertas_verdes
from valor.inquilinos i
left join valor.vw_pipeline_higiene h on h.inquilino_id = i.id
left join valor.vw_concentracao     co on co.inquilino_id = i.id
left join lateral (
  select
    sum(g.valor) filter (where g.categoria = 'compromisso') as valor_compromisso,
    sum(g.valor) filter (where g.categoria = 'possivel')    as valor_possivel,
    sum(g.valor) filter (where g.categoria = 'aberto')      as valor_aberto,
    sum(g.valor) filter (where g.categoria = 'fora')        as valor_fora
  from valor.vw_forecast_por_categoria g
  where g.inquilino_id = i.id
) fc on true
left join lateral (
  select c.periodo_codigo, c.meta_valor, c.taxa_ganho, c.cobertura_necessaria,
         c.pipeline_necessario, c.pipeline_disponivel, c.cobertura_atual,
         c.situacao, c.motivo_indisponivel
    from valor.vw_cobertura c
   where c.inquilino_id = i.id
     and c.escopo = 'casa'
     and c.usuario_id is null
     and (c.periodo_inicio is null
          or current_date between c.periodo_inicio and c.periodo_fim)
   order by case c.granularidade when 'anual' then 1 when 'trimestral' then 2 else 3 end,
            c.periodo_codigo
   limit 1
) cb on true
left join lateral (
  select sum(g.valor_bruto) as faturamento_bruto,
         sum(g.margem)      as margem,
         round(100 * sum(g.margem) / nullif(sum(g.valor_bruto), 0), 1) as margem_percentual
    from valor.margem_contrato g
   where g.inquilino_id = i.id
) m on true
left join lateral (
  select count(*) as contratos_vigentes,
         sum(coalesce(k.valor_mensal, 0)) as receita_mensal_contratada
    from valor.contratos k
   where k.inquilino_id = i.id
     and k.arquivado_em is null
     and k.situacao = 'vigente'
) ct on true
left join lateral (
  select count(*) as contas_cliente
    from valor.contas c
   where c.inquilino_id = i.id
     and c.arquivado_em is null
     and c.eh_cliente
) cc on true
left join lateral (
  select count(*) filter (where a.criticidade = 'vermelho') as alertas_vermelhos,
         count(*) filter (where a.criticidade = 'amarelo')  as alertas_amarelos,
         count(*) filter (where a.criticidade = 'verde')    as alertas_verdes
    from valor.alertas a
   where a.inquilino_id = i.id
     and a.arquivado_em is null
     and a.status in ('aberto', 'reconhecido')
) al on true
where i.arquivado_em is null
  and valor.ve_confidencial();

comment on view valor.vw_painel_dono is
  'Uma linha por inquilino com o número da casa: pipeline declarado e auditado, forecast por categoria, margem, concentração, cobertura e higiene. Vazia para quem não pode ver margem.';

-- ------------------------------------------------------- painel do parceiro

-- As minhas indicações, os meus negócios aprovados, as datas de vencimento e a
-- minha comissão. Nada além disso. Nenhuma coluna de margem, de comissão de
-- terceiro, de contato do cliente ou de contrato entra aqui.
create view valor.vw_painel_parceiro
with (security_invoker = true, security_barrier = true) as
with comissao_por_negocio as (
  select k.inquilino_id, k.parceiro_id, k.negocio_id,
         sum(k.valor) filter (where k.status = 'prevista')::numeric(14,2) as comissao_prevista,
         sum(k.valor) filter (where k.status = 'apurada')::numeric(14,2)  as comissao_apurada,
         sum(k.valor) filter (where k.status = 'paga')::numeric(14,2)     as comissao_paga,
         sum(k.valor) filter (where k.status <> 'cancelada')::numeric(14,2) as comissao_total,
         min(k.competencia) filter (where k.status in ('prevista', 'apurada')) as proxima_competencia,
         max(k.pago_em)                                                   as ultimo_pagamento_em
    from valor.comissoes k
   where k.beneficiario_tipo = 'parceiro'
     and k.arquivado_em is null
     and k.negocio_id is not null
   group by k.inquilino_id, k.parceiro_id, k.negocio_id
)
select
  i.inquilino_id,
  i.parceiro_id,
  p.nome                                     as parceiro_nome,
  'indicacao'::text                          as linha,
  i.id                                       as indicacao_id,
  i.status                                   as status_indicacao,
  coalesce(c.nome, i.conta_indicada_nome)    as conta,
  i.aceita_em,
  i.prazo_protecao_dias,
  i.protecao_expira_em,
  case when i.protecao_expira_em is not null
       then i.protecao_expira_em - current_date end   as dias_para_expirar_protecao,
  i.motivo_recusa,
  n.id                                       as negocio_id,
  n.titulo                                   as negocio_titulo,
  n.fase,
  valor.fase_rotulo(n.fase)                  as fase_rotulo,
  (n.id is not null)                         as aprovado,
  n.valor_total,
  n.data_decisao_cliente,
  n.desfecho,
  k.comissao_prevista,
  k.comissao_apurada,
  k.comissao_paga,
  k.comissao_total,
  k.proxima_competencia,
  k.ultimo_pagamento_em
from valor.indicacoes i
join valor.parceiros p on p.id = i.parceiro_id
left join valor.contas c   on c.id = i.conta_id
left join valor.negocios n on n.id = i.negocio_id and n.arquivado_em is null
left join comissao_por_negocio k
       on k.negocio_id = n.id and k.parceiro_id = i.parceiro_id
where i.arquivado_em is null

union all

select
  n.inquilino_id,
  n.parceiro_id,
  p.nome,
  'negocio'::text,
  null::uuid, null::valor.indicacao_status,
  c.nome,
  null::date, null::integer, null::date, null::integer, null::text,
  n.id, n.titulo, n.fase, valor.fase_rotulo(n.fase), true,
  n.valor_total, n.data_decisao_cliente, n.desfecho,
  k.comissao_prevista, k.comissao_apurada, k.comissao_paga, k.comissao_total,
  k.proxima_competencia, k.ultimo_pagamento_em
from valor.negocios n
join valor.parceiros p on p.id = n.parceiro_id
join valor.contas c    on c.id = n.conta_id
left join comissao_por_negocio k
       on k.negocio_id = n.id and k.parceiro_id = n.parceiro_id
where n.arquivado_em is null
  and n.parceiro_id is not null
  and not exists (select 1 from valor.indicacoes i2
                   where i2.negocio_id = n.id and i2.arquivado_em is null);

comment on view valor.vw_painel_parceiro is
  'O portal do parceiro: as indicações dele, os negócios aprovados que saíram delas, a data em que a proteção vence e a comissão dele. Nenhuma outra coluna.';

-- --------------------------------------------------- painel do conselheiro

-- As minhas turmas, os meus encontros da semana, as atas pendentes, as
-- pendências vencidas e a minha remuneração.
create view valor.vw_painel_conselheiro
with (security_invoker = true, security_barrier = true) as
select
  t.inquilino_id,
  valor.usuario_atual()                      as usuario_id,
  t.id                                       as turma_id,
  t.codigo                                   as turma_codigo,
  t.nome                                     as turma_nome,
  t.status                                   as turma_status,
  t.cadencia,
  t.formato,
  t.data_inicio,
  t.data_fim,
  pg.id                                      as programa_id,
  pg.nome                                    as programa_nome,
  pg.modalidade                              as programa_modalidade,
  ct.contas                                  as contas_da_turma,
  ct.quantas_contas,
  pa.participantes_ativos,
  en.encontros_realizados,
  en.encontros_previstos,
  en.encontros_da_semana,
  en.proximo_encontro_em,
  en.proximo_encontro_tema,
  at.atas_pendentes,
  at.atas_atrasadas,
  pe.pendencias_abertas,
  pe.pendencias_vencidas,
  rm.modelo                                  as remuneracao_modelo,
  rm.percentual                              as remuneracao_percentual,
  rm.valor_fixo_mensal                       as remuneracao_fixo_mensal,
  rm.valor_por_reuniao                       as remuneracao_por_reuniao,
  rm.reunioes_previstas_mes,
  rm.remuneracao_mes_referencia
from valor.turmas t
left join valor.programas pg on pg.id = t.programa_id
left join lateral (
  select string_agg(c.nome, ' · ' order by c.nome) as contas,
         count(*)                                  as quantas_contas
    from valor.turmas_contas tc
    join valor.contas c on c.id = tc.conta_id
   where tc.turma_id = t.id and tc.arquivado_em is null and tc.saiu_em is null
) ct on true
left join lateral (
  select count(*) as participantes_ativos
    from valor.participantes p
   where p.turma_id = t.id and p.arquivado_em is null and p.status = 'ativo'
) pa on true
left join lateral (
  select count(*) filter (where e.status = 'realizado')             as encontros_realizados,
         count(*) filter (where e.status = 'previsto')              as encontros_previstos,
         count(*) filter (where e.status = 'previsto'
                            and e.data_prevista between current_date and current_date + 7)
                                                                    as encontros_da_semana,
         min(e.data_prevista) filter (where e.status = 'previsto'
                                        and e.data_prevista >= current_date)
                                                                    as proximo_encontro_em,
         (array_agg(e.tema order by e.data_prevista)
            filter (where e.status = 'previsto' and e.data_prevista >= current_date))[1]
                                                                    as proximo_encontro_tema
    from valor.encontros e
   where e.turma_id = t.id and e.arquivado_em is null
) en on true
left join lateral (
  select count(*) filter (where a.status <> 'enviada')              as atas_pendentes,
         count(*) filter (where a.status <> 'enviada'
                            and a.prazo_envio is not null
                            and now() > a.prazo_envio)              as atas_atrasadas
    from valor.atas a
   where a.turma_id = t.id and a.arquivado_em is null
) at on true
left join lateral (
  select count(*)                                                   as pendencias_abertas,
         count(*) filter (where p.prazo is not null and p.prazo < current_date)
                                                                    as pendencias_vencidas
    from valor.pendencias p
   where p.turma_id = t.id and p.arquivado_em is null
     and p.status in ('aberta', 'em_andamento')
) pe on true
left join lateral (
  select cc.modelo, cc.percentual, cc.valor_fixo_mensal, cc.valor_por_reuniao,
         cc.reunioes_previstas_mes,
         case cc.modelo
           when 'fixo_mensal'        then cc.valor_fixo_mensal
           when 'por_reuniao'        then cc.valor_por_reuniao
                                          * coalesce(cc.reunioes_previstas_mes, 0)
           when 'percentual_contrato' then round(coalesce(k.valor_mensal, 0)
                                                 * cc.percentual / 100, 2)
         end::numeric(14,2) as remuneracao_mes_referencia
    from valor.contratos_conselheiros cc
    left join valor.contratos k on k.id = cc.contrato_id
   where cc.contrato_id = t.contrato_id
     and cc.usuario_id = valor.usuario_atual()
     and cc.arquivado_em is null
     and cc.ativo
   order by cc.vigencia_inicio desc
   limit 1
) rm on true
where t.arquivado_em is null
  and not valor.eh_parceiro()
  and valor.usuario_atual() is not null
  and t.status in ('planejada', 'em_andamento', 'suspensa')
  and ( t.facilitador_id = valor.usuario_atual()
        or t.coordenador_id = valor.usuario_atual()
        or pg.responsavel_id = valor.usuario_atual()
        or exists (select 1 from valor.papeis_negocio pn
                    where pn.negocio_id = t.negocio_id
                      and pn.usuario_id = valor.usuario_atual()
                      and pn.papel = 'conselheiro'
                      and pn.ativo and pn.arquivado_em is null)
        or exists (select 1 from valor.contratos_conselheiros cc
                    where cc.contrato_id = t.contrato_id
                      and cc.usuario_id = valor.usuario_atual()
                      and cc.arquivado_em is null and cc.ativo) );

comment on view valor.vw_painel_conselheiro is
  'Uma linha por turma do conselheiro da sessão, com os encontros dos próximos sete dias, as atas que ainda não saíram, as pendências vencidas e a remuneração dele naquele contrato.';

-- --------------------------------------------------------- alertas abertos

-- Todo alerta que ainda pede ação, por criticidade, com quem precisa agir.
-- Reconhecer não é resolver, então o alerta reconhecido continua nesta lista.
create view valor.vw_alertas_abertos
with (security_invoker = true, security_barrier = true) as
select
  a.inquilino_id,
  a.id                                       as alerta_id,
  r.codigo                                   as regra_codigo,
  r.nome                                     as regra_nome,
  a.entidade,
  a.entidade_chave,
  a.criticidade,
  case a.criticidade when 'vermelho' then 1 when 'amarelo' then 2 else 3 end
                                             as ordem_criticidade,
  case a.criticidade when 'vermelho' then 'Vermelho, age hoje'
                     when 'amarelo'  then 'Amarelo, age esta semana'
                     else                 'Verde, acompanhe'
  end                                        as criticidade_rotulo,
  a.mensagem,
  a.detalhe,
  a.status,
  a.disparado_em,
  (current_date - a.disparado_em::date)      as dias_aberto,
  a.reconhecido_em,
  coalesce(a.destinatario_id, ug.id)         as quem_age_usuario_id,
  coalesce(ud.nome, ug.nome)                 as quem_age_nome,
  coalesce(ud.perfil, ug.perfil, r.destinatario_perfil) as quem_age_perfil,
  r.destinatario_papel                       as quem_age_papel,
  n.id                                       as negocio_id,
  n.titulo                                   as negocio_titulo,
  coalesce(n.conta_id, k.conta_id, cdir.id)  as conta_id,
  coalesce(cn.nome, ck.nome, cdir.nome)      as conta_nome
from valor.alertas a
left join valor.regras_alerta r on r.id = a.regra_id
left join valor.usuarios ud     on ud.id = a.destinatario_id
left join valor.negocios n      on a.entidade = 'negocios'  and n.id = a.entidade_chave
left join valor.contratos k     on a.entidade = 'contratos' and k.id = a.entidade_chave
left join valor.contas cdir     on a.entidade = 'contas'    and cdir.id = a.entidade_chave
left join valor.contas cn       on cn.id = n.conta_id
left join valor.contas ck       on ck.id = k.conta_id
left join valor.usuarios ug     on ug.id = coalesce(cn.gerente_contas_id, ck.gerente_contas_id,
                                                    cdir.gerente_contas_id)
where a.arquivado_em is null
  and a.status in ('aberto', 'reconhecido');

comment on view valor.vw_alertas_abertos is
  'Todo alerta que ainda pede ação, ordenável por criticidade, com o negócio, a conta e quem precisa agir. O alerta reconhecido continua aqui, porque reconhecer não resolve.';

-- ----------------------------------------------------- atividades pendentes

-- A caixa de entrada por pessoa, vencidas primeiro.
create view valor.vw_atividades_pendentes
with (security_invoker = true, security_barrier = true) as
select
  a.inquilino_id,
  coalesce(a.responsavel_id, a.criado_por)   as usuario_id,
  u.nome                                     as usuario_nome,
  a.id                                       as atividade_id,
  a.titulo,
  a.estado,
  g.codigo                                   as contexto_codigo,
  g.rotulo                                   as contexto_rotulo,
  a.energia,
  a.tempo_estimado_min,
  a.prioridade,
  a.prazo,
  a.agendada_para,
  -- Sem prazo, quem manda é a data agendada: o compromisso marcado para ontem
  -- também está vencido.
  d.data_referencia,
  case when d.data_referencia is not null and d.data_referencia < current_date
       then current_date - d.data_referencia end  as dias_de_atraso,
  case when d.data_referencia is null              then 'sem_prazo'
       when d.data_referencia < current_date       then 'vencida'
       when d.data_referencia = current_date       then 'vence_hoje'
       when d.data_referencia <= current_date + 7  then 'vence_na_semana'
       else                                            'no_prazo'
  end                                        as situacao,
  case when d.data_referencia is null              then 'Sem prazo definido'
       when d.data_referencia < current_date       then 'Vencida'
       when d.data_referencia = current_date       then 'Vence hoje'
       when d.data_referencia <= current_date + 7  then 'Vence nesta semana'
       else                                            'No prazo'
  end                                        as situacao_rotulo,
  case when d.data_referencia is null                   then 5
       when d.data_referencia < current_date            then 1
       when d.data_referencia = current_date            then 2
       when d.data_referencia <= current_date + 7       then 3
       else                                                  4
  end                                        as ordem,
  a.delegado_para_id,
  a.delegado_para_externo,
  a.aguardando_desde,
  a.conta_id,
  c.nome                                     as conta_nome,
  a.negocio_id,
  n.titulo                                   as negocio_titulo,
  a.contrato_id,
  a.encontro_id,
  a.pendencia_id,
  (select count(*) from valor.atividades_checklist ac
    where ac.atividade_id = a.id and ac.arquivado_em is null and not ac.concluido)
                                             as itens_de_checklist_abertos
from valor.atividades a
left join valor.usuarios u     on u.id = coalesce(a.responsavel_id, a.criado_por)
left join valor.contextos_gtd g on g.id = a.contexto_id
left join valor.contas c        on c.id = a.conta_id
left join valor.negocios n      on n.id = a.negocio_id
cross join lateral (
  select coalesce(a.prazo, a.agendada_para::date) as data_referencia
) d
where a.arquivado_em is null
  and a.estado not in ('concluida', 'cancelada');

comment on view valor.vw_atividades_pendentes is
  'A caixa de entrada de cada pessoa, com a coluna ordem já pronta para a interface pôr as vencidas primeiro.';

-- ------------------------------------------------------- contratos em curso

create view valor.vw_contratos_em_curso
with (security_invoker = true, security_barrier = true) as
select
  k.inquilino_id,
  k.id                                       as contrato_id,
  k.numero,
  k.titulo,
  k.conta_id,
  c.nome                                     as conta_nome,
  k.oferta_id,
  o.nome                                     as oferta_nome,
  k.modalidade,
  k.nivel,
  k.situacao,
  k.assinado,
  k.assinado_em,
  k.vigencia_inicio,
  k.vigencia_fim,
  k.meses_vigencia,
  k.valor_total,
  k.valor_mensal,
  k.renovacao_automatica,
  k.aviso_previo_dias,
  case when k.vigencia_fim is not null
       then k.vigencia_fim - current_date end          as dias_para_vencer,
  case when k.vigencia_fim is not null and k.aviso_previo_dias is not null
       then k.vigencia_fim - k.aviso_previo_dias end   as data_limite_aviso_previo,
  (k.vigencia_fim is not null
   and k.vigencia_fim between current_date and current_date + j.janela_dias)
                                                       as na_janela_de_renovacao,
  j.janela_dias                                        as janela_de_renovacao_dias,
  case when k.vigencia_fim is null                              then 'sem_vigencia_fim'
       when k.vigencia_fim < current_date                       then 'vencido'
       when k.vigencia_fim <= current_date + j.aviso_vermelho   then 'vermelho'
       when k.vigencia_fim <= current_date + j.aviso_amarelo    then 'amarelo'
       else                                                          'verde'
  end                                                  as sinal_de_vencimento,
  k.contrato_anterior_id,
  ka.numero                                            as contrato_anterior_numero,
  ren.negocio_id                                       as negocio_renovacao_id,
  ren.titulo                                           as negocio_renovacao_titulo,
  ren.fase                                             as negocio_renovacao_fase,
  ren.data_decisao_cliente                             as negocio_renovacao_decisao,
  (ren.negocio_id is not null)                         as tem_negocio_de_renovacao,
  pc.parcelas_previstas,
  pc.parcelas_recebidas,
  pc.valor_recebido,
  pc.proximo_vencimento
from valor.contratos k
join valor.contas c on c.id = k.conta_id
left join valor.ofertas o    on o.id = k.oferta_id
left join valor.contratos ka on ka.id = k.contrato_anterior_id
cross join lateral (
  select valor.configuracao_num(k.inquilino_id, 'alerta.contrato_renovacao_dias', 90)::integer as janela_dias,
         valor.configuracao_num(k.inquilino_id, 'alerta.contrato_aviso_amarelo_dias', 60)::integer as aviso_amarelo,
         valor.configuracao_num(k.inquilino_id, 'alerta.contrato_aviso_vermelho_dias', 30)::integer as aviso_vermelho
) j
left join lateral (
  select n.id as negocio_id, n.titulo, n.fase, n.data_decisao_cliente
    from valor.negocios n
   where n.conta_id = k.conta_id
     and n.fase = 7
     and n.desfecho is null
     and n.arquivado_em is null
   order by n.criado_em desc
   limit 1
) ren on true
left join lateral (
  select count(*)                                            as parcelas_previstas,
         count(*) filter (where p.status = 'recebida')        as parcelas_recebidas,
         coalesce(sum(p.valor_bruto) filter (where p.status = 'recebida'), 0)::numeric(14,2)
                                                             as valor_recebido,
         min(p.vencimento) filter (where p.status in ('prevista', 'faturada'))
                                                             as proximo_vencimento
    from valor.parcelas p
   where p.contrato_id = k.id
     and p.arquivado_em is null
     and p.status <> 'cancelada'
) pc on true
where k.arquivado_em is null
  and k.situacao in ('pendente_assinatura', 'vigente', 'pausado');

comment on view valor.vw_contratos_em_curso is
  'Contrato vigente, a data de vencimento, o sinal de renovação e o negócio de renovação da conta quando já existir um na fase 7.';

-- --------------------------------------------------------- agenda da semana

-- Encontro, reunião e compromisso dos próximos sete dias, na mesma lista.
create view valor.vw_agenda_da_semana
with (security_invoker = true, security_barrier = true) as
select
  e.inquilino_id,
  'encontro'::text                           as tipo,
  'Encontro da turma'::text                  as tipo_rotulo,
  e.id                                       as referencia_id,
  coalesce(e.tema, 'Encontro ' || e.numero::text) as titulo,
  e.data_prevista                            as quando_em,
  e.hora_prevista_inicio                     as hora_inicio,
  e.hora_prevista_fim                        as hora_fim,
  e.formato::text                            as formato,
  e.local,
  e.link,
  e.status::text                             as status,
  t.id                                       as turma_id,
  t.nome                                     as turma_nome,
  null::uuid                                 as conta_id,
  null::text                                 as conta_nome,
  coalesce(e.conselheiro_id, e.assessor_id)  as responsavel_id,
  (e.data_prevista - current_date)           as dias_ate
from valor.encontros e
left join valor.turmas t on t.id = e.turma_id
where e.arquivado_em is null
  and e.status = 'previsto'
  and e.data_prevista between current_date and current_date + 7

union all

select
  p.inquilino_id,
  'reuniao'::text,
  'Reunião de conselho'::text,
  p.id,
  coalesce(p.titulo, 'Reunião de conselho'),
  p.data_reuniao,
  p.hora_inicio,
  null::time,
  null::text,
  null::text,
  null::text,
  p.status::text,
  p.turma_id,
  t.nome,
  p.conta_id,
  c.nome,
  null::uuid,
  (p.data_reuniao - current_date)
from valor.pautas p
left join valor.turmas t on t.id = p.turma_id
left join valor.contas c on c.id = p.conta_id
where p.arquivado_em is null
  and p.status in ('rascunho', 'publicada')
  and p.data_reuniao between current_date and current_date + 7

union all

select
  a.inquilino_id,
  'compromisso'::text,
  'Compromisso da agenda'::text,
  a.id,
  a.titulo,
  coalesce(a.agendada_para::date, a.prazo),
  a.agendada_para::time,
  null::time,
  null::text,
  null::text,
  null::text,
  a.estado::text,
  null::uuid,
  null::text,
  a.conta_id,
  c.nome,
  coalesce(a.responsavel_id, a.criado_por),
  (coalesce(a.agendada_para::date, a.prazo) - current_date)
from valor.atividades a
left join valor.contas c on c.id = a.conta_id
where a.arquivado_em is null
  and a.estado not in ('concluida', 'cancelada')
  and coalesce(a.agendada_para::date, a.prazo) between current_date and current_date + 7;

comment on view valor.vw_agenda_da_semana is
  'Encontro de turma, reunião de conselho e compromisso da agenda dos próximos sete dias, numa lista só, ordenável por quando_em.';

-- ---------------------------------------------------------- saúde da conta

create view valor.vw_saude_da_conta
with (security_invoker = true, security_barrier = true) as
select
  c.inquilino_id,
  c.id                                       as conta_id,
  c.nome                                     as conta_nome,
  c.setor,
  c.cidade,
  c.uf,
  c.tier,
  case c.tier when 't1' then 'Tier 1, ouro'
              when 't2' then 'Tier 2, prata'
              when 't3' then 'Tier 3, bronze'
              else           'Tier a confirmar'
  end                                        as tier_rotulo,
  c.tier_sugerido,
  c.tier_confirmado_em,
  (c.tier is distinct from c.tier_sugerido)  as tier_diverge_da_sugestao,
  c.prioridade,
  c.power_of_x,
  c.eh_cliente,
  c.eh_prospecto,
  c.gerente_contas_id,
  u.nome                                     as gerente_contas_nome,
  nps.nps,
  nps.respondentes                           as nps_respondentes,
  nps.promotores                             as nps_promotores,
  nps.detratores                             as nps_detratores,
  nps.ultima_resposta                        as nps_ultima_resposta,
  coalesce(ct.contratos_vigentes, 0)         as contratos_vigentes,
  coalesce(ct.valor_mensal_vigente, 0)::numeric(14,2) as valor_mensal_vigente,
  ct.proximo_vencimento_de_contrato,
  it.ultimo_contato_em,
  case when it.ultimo_contato_em is not null
       then current_date - it.ultimo_contato_em end   as dias_sem_contato,
  coalesce(ng.negocios_ativos, 0)            as negocios_ativos,
  coalesce(ng.pipeline_da_conta, 0)::numeric(14,2) as pipeline_da_conta,
  coalesce(al.alertas_abertos, 0)            as alertas_abertos,
  coalesce(al.alertas_vermelhos, 0)          as alertas_vermelhos,
  coalesce(tu.turmas_ativas, 0)              as turmas_ativas,
  coalesce(pe.pendencias_vencidas, 0)        as pendencias_vencidas
from valor.contas c
left join valor.usuarios u on u.id = c.gerente_contas_id
left join valor.nps_consolidado_por_conta nps on nps.conta_id = c.id
left join lateral (
  select count(*)                                                     as contratos_vigentes,
         sum(coalesce(k.valor_mensal, 0))                             as valor_mensal_vigente,
         min(k.vigencia_fim) filter (where k.vigencia_fim >= current_date)
                                                                      as proximo_vencimento_de_contrato
    from valor.contratos k
   where k.conta_id = c.id and k.arquivado_em is null and k.situacao = 'vigente'
) ct on true
left join lateral (
  select max(x.ocorrida_em::date) as ultimo_contato_em
    from valor.interacoes x
   where x.conta_id = c.id and x.arquivado_em is null
) it on true
left join lateral (
  select count(*) as negocios_ativos,
         sum(coalesce(n.valor_total, n.valor_recorrente_mes * n.meses_recorrencia, 0))
           as pipeline_da_conta
    from valor.negocios n
   where n.conta_id = c.id and n.arquivado_em is null and n.desfecho is null
     and n.fase between 1 and 4
) ng on true
left join lateral (
  select count(*)                                          as alertas_abertos,
         count(*) filter (where v.criticidade = 'vermelho') as alertas_vermelhos
    from valor.vw_alertas_abertos v
   where v.conta_id = c.id
) al on true
left join lateral (
  select count(distinct tc.turma_id) as turmas_ativas
    from valor.turmas_contas tc
    join valor.turmas t on t.id = tc.turma_id
   where tc.conta_id = c.id and tc.arquivado_em is null and tc.saiu_em is null
     and t.status in ('planejada', 'em_andamento')
) tu on true
left join lateral (
  select count(*) as pendencias_vencidas
    from valor.pendencias p
   where p.conta_id = c.id and p.arquivado_em is null
     and p.status in ('aberta', 'em_andamento')
     and p.prazo is not null and p.prazo < current_date
) pe on true
where c.arquivado_em is null
  and not valor.eh_parceiro();

comment on view valor.vw_saude_da_conta is
  'Uma linha por conta: tier, Power of X, NPS mais recente, contratos vivos, último contato e alertas abertos.';

-- ------------------------------------------------------- trabalho da casa

-- Separa o que é projeto da Felix do que é projeto de cliente. O critério é o
-- vínculo: item ligado a conta, negócio, contrato, encontro ou pendência é
-- trabalho de cliente. Item sem nenhum vínculo é trabalho da própria casa.
create view valor.vw_trabalho_da_casa
with (security_invoker = true, security_barrier = true) as
select
  a.inquilino_id,
  case when a.conta_id is null and a.negocio_id is null and a.contrato_id is null
        and a.encontro_id is null and a.pendencia_id is null
       then 'casa' else 'cliente' end        as escopo,
  case when a.conta_id is null and a.negocio_id is null and a.contrato_id is null
        and a.encontro_id is null and a.pendencia_id is null
       then 'Projeto da Felix' else 'Projeto de cliente' end as escopo_rotulo,
  'atividade'::text                          as tipo,
  a.id                                       as item_id,
  a.titulo,
  a.estado::text                             as situacao,
  coalesce(a.responsavel_id, a.criado_por)   as responsavel_id,
  u.nome                                     as responsavel_nome,
  a.prazo                                    as data_alvo,
  (a.prazo is not null and a.prazo < current_date) as atrasado,
  a.conta_id,
  c.nome                                     as conta_nome,
  a.negocio_id,
  a.contrato_id
from valor.atividades a
left join valor.usuarios u on u.id = coalesce(a.responsavel_id, a.criado_por)
left join valor.contas c   on c.id = a.conta_id
where a.arquivado_em is null
  and a.estado not in ('concluida', 'cancelada')

union all

select
  pg.inquilino_id,
  case when pg.conta_id is null then 'casa' else 'cliente' end,
  case when pg.conta_id is null then 'Projeto da Felix' else 'Projeto de cliente' end,
  'programa'::text,
  pg.id,
  pg.nome,
  pg.status::text,
  pg.responsavel_id,
  u.nome,
  pg.data_fim,
  (pg.data_fim is not null and pg.data_fim < current_date
   and pg.status not in ('concluido', 'cancelado')),
  pg.conta_id,
  c.nome,
  pg.negocio_id,
  pg.contrato_id
from valor.programas pg
left join valor.usuarios u on u.id = pg.responsavel_id
left join valor.contas c   on c.id = pg.conta_id
where pg.arquivado_em is null
  and pg.status in ('planejado', 'ativo', 'suspenso');

comment on view valor.vw_trabalho_da_casa is
  'Todo trabalho em aberto separado em projeto da Felix e projeto de cliente. O critério é o vínculo com conta, negócio, contrato, encontro ou pendência.';


-- ==========================================================================
-- 0016_semente_do_inquilino.sql
-- ==========================================================================
-- 0016 · Semente do inquilino: catálogo do portfólio, configuração e primeiro usuário
-- Dono: Curador de Catálogo. Nenhum outro agente altera este arquivo.
--
-- Por que este arquivo existe: a plataforma precisa nascer sabendo o que a casa
-- vende e como a casa trabalha, sem ninguém digitar nada. E precisa nascer assim
-- para qualquer inquilino, porque a versão white label não é projeto futuro, é
-- entrega do programa Negócios de Valor.
--
-- Por isso a semente é função, e não insert solto:
--
--   valor.semear_inquilino(p_inquilino_id uuid, p_perfil text default 'felix')
--
-- Dois perfis de semente:
--   'felix'   o catálogo completo da casa, com os sete Programas de Valor, os
--             sete serviços fora dos programas e a identidade visual da casa.
--   'neutro'  a mesma estrutura sem uma linha de conteúdo da casa. Oferta
--             genérica, configuração padrão, paleta neutra, nenhum nome de
--             programa da casa.
--
-- Idempotente do começo ao fim: toda inserção termina em on conflict do nothing,
-- e a função devolve quantas linhas nasceram nesta chamada. Rodar de novo devolve
-- zero e não duplica nada.
--
-- Nenhum preço entra aqui, em hipótese nenhuma. Nenhum endereço de e-mail entra
-- aqui: o endereço do administrador master chega por parâmetro de
-- valor.criar_inquilino.
--
-- Sobre o grupo e o rótulo de valor.configuracoes: `chave` e `grupo` são
-- identificadores, então vão em minúscula, sem acento e sem cedilha, no mesmo
-- padrão das chaves que as migrações 0011 e 0012 já semeiam. `rotulo` é texto de
-- tela, então vai em português com acentuação correta.

-- ------------------------------------------------ grava uma linha de configuração

-- Irmã de valor.gravar_configuracao, da migração 0011, com duas diferenças que a
-- semente precisa: aceita quem edita a chave na tela, e devolve quantas linhas
-- nasceram. É esse número que prova a idempotência sem precisar contar a tabela.
create or replace function valor.semear_configuracao(
  p_inquilino_id uuid,
  p_chave        text,
  p_valor        jsonb,
  p_rotulo       text,
  p_grupo        text,
  p_editavel_por valor.perfil_usuario default 'admin_master'
) returns integer language plpgsql as $funcao$
declare
  v_inseridas integer;
begin
  insert into valor.configuracoes
    (inquilino_id, chave, valor, rotulo, grupo, editavel_por)
  values
    (p_inquilino_id, p_chave, p_valor, p_rotulo, p_grupo, p_editavel_por)
  on conflict (inquilino_id, chave) do nothing;

  get diagnostics v_inseridas = row_count;
  return v_inseridas;
end;
$funcao$;

comment on function valor.semear_configuracao(uuid, text, jsonb, text, text, valor.perfil_usuario) is
  'Semeia uma chave de configuração com rótulo, grupo e quem edita. Não sobrescreve o que a casa já ajustou na tela, e devolve quantas linhas nasceram.';

-- ------------------------------------------------------- o catálogo do portfólio

-- Os números são os oficiais da casa, tirados do catálogo de portfólio. Preço
-- nenhum entra: preço vive no Plano de Trabalho e no Contrato de Valor, nunca no
-- catálogo, que é público dentro da plataforma inteira.
create or replace function valor.semear_ofertas(p_inquilino_id uuid, p_perfil text)
returns integer language plpgsql as $funcao$
declare
  v_inseridas integer;
begin
  if p_perfil = 'felix' then

    insert into valor.ofertas (
      inquilino_id, codigo, nome, familia, modalidade, niveis_aceitos,
      gera_turma, publico_alvo, estrutura, ativa, sugerida, ordem
    ) values
    -- ------------------------------------------------- os sete Programas de Valor
    (p_inquilino_id, 'conselho-dedicado', 'Conselho de Valor dedicado',
     'Programas de Valor', 'recorrente', '{n1,n2,n3}', true,
     'Donos e sócios de uma empresa.',
     'Encontros semanais de conselho, encontro semanal de gestão, pauta prioritária mensal e um presencial por mês. Recorrente anual, turma de um cliente.',
     true, true, 10),

    (p_inquilino_id, 'conselho-compartilhado', 'Conselho de Valor compartilhado',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Até 8 empresários de mercados diferentes.',
     '48 reuniões no ano, hotseat por membro, resumo semanal e um presencial por mês. Recorrente anual, turma multiempresa.',
     true, true, 20),

    (p_inquilino_id, 'negocios-de-valor', 'Negócios de Valor',
     'Programas de Valor', 'pontual_com_sustentacao', '{n1}', true,
     'Times comerciais B2B e B2G.',
     '12 encontros de 2h30 mais 8 semanas de sustentação. Variante de 10 encontros. Imersão de 3 dias. De 8 a 16 cadeiras. A unidade de venda é o time, e a turma pode ser dedicada ou compartilhada.',
     true, true, 30),

    (p_inquilino_id, 'lideranca-de-valor', 'Liderança de Valor',
     'Programas de Valor', 'pontual', '{n1}', true,
     'Sócios, C-level e líderes.',
     'Workshop de 2 dias, 8 módulos e 1 plano de desenvolvimento por participante.',
     true, true, 40),

    (p_inquilino_id, 'gestao-de-valor', 'Gestão de Valor',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Sócios e principais executivos.',
     '6 módulos, 48 temas e encontros semanais. Recorrente anual.',
     true, true, 50),

    (p_inquilino_id, 'mentoria-de-valor', 'Mentoria de Valor',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Donos e CEOs.',
     'Encontro semanal, deep-dive mensal e plano em 4 estações. Recorrente anual e individual, turma de um.',
     true, true, 60),

    (p_inquilino_id, 'executivo-de-valor', 'Executivo de Valor',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Ocupantes de cadeira do C-level.',
     'Mesa do CEO: 12 etapas em 6 meses, encontros quinzenais de 2h e índice próprio medido em T0, T90 e T180.',
     true, true, 70),

    -- Fora do site por decisão de julho de 2026. Continua no catálogo para o
    -- histórico não perder o que já foi vendido, inativo e fora da sugestão.
    (p_inquilino_id, 'sprint-de-valor', 'Sprint de Valor',
     'Programas de Valor', 'pontual', '{n1}', true,
     'Times que precisam de um ciclo curto de execução.',
     'Fora do site por decisão de julho de 2026. Disponível no catálogo para o histórico, inativo e não sugerido. Estrutura a confirmar antes de voltar a ser oferecido.',
     false, false, 80),

    -- --------------------------------------- os sete serviços fora dos programas
    (p_inquilino_id, 'consultoria-pontual', 'Consultoria pontual',
     'Serviços', 'pontual', '{n1}', false,
     'Empresa com um problema de escopo fechado.',
     'Escopo fechado, com entregável definido.',
     true, true, 110),

    (p_inquilino_id, 'consultoria-recorrente', 'Consultoria recorrente',
     'Serviços', 'recorrente', '{n1}', false,
     'Empresa que precisa de acompanhamento continuado.',
     'Mensalidade, com escopo revisto por ciclo.',
     true, true, 120),

    (p_inquilino_id, 'treinamento', 'Treinamento',
     'Serviços', 'pontual', '{n1}', false,
     'Times que precisam de capacitação em tema específico.',
     'Workshop ou palestra contratada. Aceita contratação pontual e contratação recorrente.',
     true, true, 130),

    (p_inquilino_id, 'c-level-as-a-service', 'C-level as a service',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa que precisa de cadeira executiva sem contratar em tempo integral.',
     'Executivo alocado por tempo determinado, com agenda e entregáveis acordados.',
     true, true, 140),

    (p_inquilino_id, 'modelo-por-resultado', 'Modelo por resultado',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa disposta a dividir o resultado gerado.',
     'Honorário menor mais participação nos resultados. Aceita contratação recorrente e pontual.',
     true, true, 150),

    (p_inquilino_id, 'modelo-por-equity', 'Equity',
     'Serviços', 'recorrente', '{n1,n3}', false,
     'Empresa em que a casa entra como sócia.',
     'Honorário mais participação societária. Depende de validação de advogado e de contador antes da assinatura.',
     true, true, 160),

    (p_inquilino_id, 'next-c-level', 'NEXT C-LEVEL',
     'Serviços', 'pontual', '{n1}', false,
     'A confirmar.',
     'Frente própria, catalogada para não se perder no funil. Modalidade, estrutura e nível a confirmar.',
     true, true, 170)

    on conflict (inquilino_id, codigo) do nothing;

  else

    -- O catálogo do perfil neutro. Mesma estrutura, mesma modalidade, mesmos
    -- níveis aceitos e mesma regra de turma. Nenhum nome, nenhum número e
    -- nenhuma história da casa. É este bloco que o white label recebe.
    insert into valor.ofertas (
      inquilino_id, codigo, nome, familia, modalidade, niveis_aceitos,
      gera_turma, publico_alvo, estrutura, ativa, sugerida, ordem
    ) values
    (p_inquilino_id, 'programa-conselho-dedicado', 'Conselho consultivo dedicado',
     'Programas', 'recorrente', '{n1,n2,n3}', true,
     'Donos e sócios de uma empresa.',
     'Encontros semanais de conselho, encontro semanal de gestão, pauta prioritária mensal e um presencial por mês.',
     true, true, 10),

    (p_inquilino_id, 'programa-conselho-compartilhado', 'Conselho consultivo compartilhado',
     'Programas', 'recorrente', '{n1}', true,
     'Grupo fechado de empresários de mercados diferentes.',
     'Reuniões semanais ao longo do ano, rodada individual por membro, resumo semanal e um presencial por mês.',
     true, true, 20),

    (p_inquilino_id, 'programa-comercial', 'Programa comercial',
     'Programas', 'pontual_com_sustentacao', '{n1}', true,
     'Times comerciais.',
     'Ciclo de encontros com semanas de sustentação, com imersão opcional e turma fechada por time.',
     true, true, 30),

    (p_inquilino_id, 'programa-lideranca', 'Programa de liderança',
     'Programas', 'pontual', '{n1}', true,
     'Sócios, executivos e líderes.',
     'Workshop de dois dias, dividido em módulos, com um plano de desenvolvimento por participante.',
     true, true, 40),

    (p_inquilino_id, 'programa-gestao', 'Programa de gestão',
     'Programas', 'recorrente', '{n1}', true,
     'Sócios e principais executivos.',
     'Módulos temáticos com encontros semanais ao longo do ano.',
     true, true, 50),

    (p_inquilino_id, 'programa-mentoria', 'Mentoria individual',
     'Programas', 'recorrente', '{n1}', true,
     'Donos e principais executivos.',
     'Encontro semanal, aprofundamento mensal e plano revisado a cada trimestre.',
     true, true, 60),

    (p_inquilino_id, 'programa-executivo', 'Programa executivo',
     'Programas', 'recorrente', '{n1}', true,
     'Ocupantes de cadeira executiva.',
     'Etapas encadeadas ao longo de seis meses, com encontros quinzenais e medição no início, no meio e no fim.',
     true, true, 70),

    (p_inquilino_id, 'consultoria-pontual', 'Consultoria pontual',
     'Serviços', 'pontual', '{n1}', false,
     'Empresa com um problema de escopo fechado.',
     'Escopo fechado, com entregável definido.',
     true, true, 110),

    (p_inquilino_id, 'consultoria-recorrente', 'Consultoria recorrente',
     'Serviços', 'recorrente', '{n1}', false,
     'Empresa que precisa de acompanhamento continuado.',
     'Mensalidade, com escopo revisto por ciclo.',
     true, true, 120),

    (p_inquilino_id, 'treinamento', 'Treinamento',
     'Serviços', 'pontual', '{n1}', false,
     'Times que precisam de capacitação em tema específico.',
     'Workshop ou palestra contratada. Aceita contratação pontual e contratação recorrente.',
     true, true, 130),

    (p_inquilino_id, 'executivo-alocado', 'Executivo alocado',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa que precisa de cadeira executiva sem contratar em tempo integral.',
     'Executivo alocado por tempo determinado, com agenda e entregáveis acordados.',
     true, true, 140),

    (p_inquilino_id, 'modelo-por-resultado', 'Modelo por resultado',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa disposta a dividir o resultado gerado.',
     'Honorário menor mais participação nos resultados. Aceita contratação recorrente e pontual.',
     true, true, 150),

    (p_inquilino_id, 'modelo-por-equity', 'Participação societária',
     'Serviços', 'recorrente', '{n1,n3}', false,
     'Empresa em que a contratada entra como sócia.',
     'Honorário mais participação societária. Depende de validação jurídica e contábil antes da assinatura.',
     true, true, 160),

    (p_inquilino_id, 'frente-a-confirmar', 'Frente a confirmar',
     'Serviços', 'pontual', '{n1}', false,
     'A confirmar.',
     'Linha catalogada para não se perder no funil. Modalidade, estrutura e nível a confirmar.',
     true, true, 170)

    on conflict (inquilino_id, codigo) do nothing;

  end if;

  get diagnostics v_inseridas = row_count;
  return v_inseridas;
end;
$funcao$;

comment on function valor.semear_ofertas(uuid, text) is
  'Semeia o catálogo do portfólio de um inquilino. No perfil felix, os sete Programas de Valor, os sete serviços fora dos programas e o Sprint de Valor inativo. No perfil neutro, a mesma estrutura com oferta genérica. Idempotente. Nenhum preço entra.';

-- ------------------------------------------------------- a configuração da casa

-- Tudo que a casa decidiu e que precisa ser trocável em tela, e não em código.
--
-- Os prazos de alerta e o limite de concentração do pipeline não nascem aqui de
-- propósito: eles já moram nas chaves `alerta.*` e `higiene.*` que a migração
-- 0012 semeia, e duas linhas para o mesmo número seriam duas verdades que
-- discordam no primeiro dia de uso. A semente do inquilino garante que elas
-- existam chamando valor.semear_regras_alerta, e o teste confere uma a uma.
create or replace function valor.semear_configuracoes(p_inquilino_id uuid, p_perfil text)
returns integer language plpgsql as $funcao$
declare
  v_linhas integer := 0;
  v_felix  boolean := (p_perfil = 'felix');
begin

  -- ----------------------------------------------------------------- comissão
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.vendedor_interno_percentual', to_jsonb(10),
    'Percentual de comissão do Gerente de Contas, sobre a base líquida', 'comissao', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.parceiro_percentual', to_jsonb(10),
    'Percentual de comissão do parceiro que indica, sobre a base líquida', 'comissao', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.imposto_percentual', to_jsonb(15),
    'Imposto médio descontado do bruto antes da base de comissão', 'comissao', 'financeiro');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.momento_apuracao', to_jsonb('recebimento'::text),
    'Quando a comissão é apurada, no recebimento da parcela', 'comissao', 'financeiro');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.duracao', to_jsonb('vida_do_contrato'::text),
    'Por quanto tempo a comissão é devida, pela vida do contrato e suas renovações', 'comissao', 'admin_master');

  -- ----------------------------------------------------------------- parceria
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'parceria.protecao_indicacao_dias', to_jsonb(90),
    'Dias de proteção da indicação aceita do parceiro', 'parceria', 'admin_master');

  -- --------------------------------------------------------------------- meta
  -- Nascem vazias de propósito. Sem meta, o painel mostra cobertura de pipeline
  -- como indisponível, e não um número errado. Quem lê estas chaves não usa
  -- valor.configuracao_num com padrão, porque padrão aqui inventaria meta.
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.anual_casa', 'null'::jsonb,
    'Meta anual da casa', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.trimestral_casa', 'null'::jsonb,
    'Meta trimestral da casa', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.anual_por_pessoa', '{}'::jsonb,
    'Meta anual por pessoa, com o identificador do usuário na chave', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.trimestral_por_pessoa', '{}'::jsonb,
    'Meta trimestral por pessoa, com o identificador do usuário na chave', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.cobertura_indisponivel_sem_meta', 'true'::jsonb,
    'Mostrar a cobertura de pipeline como indisponível enquanto não houver meta', 'meta', 'lider');

  -- ----------------------------------------------------------------- conselho
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.reunioes_por_ano', to_jsonb(48),
    'Reuniões de conselho previstas no calendário do ano', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.recesso_inicio', to_jsonb('12-15'::text),
    'Início do recesso do calendário de turma, em dia e mês', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.recesso_fim', to_jsonb('01-15'::text),
    'Fim do recesso do calendário de turma, em dia e mês', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.nps_periodicidade_meses', to_jsonb(3),
    'Periodicidade da pesquisa de NPS, em meses', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.nota_conselheiro_periodicidade_meses', to_jsonb(6),
    'Periodicidade da nota do conselheiro respondida pelos sócios do cliente, em meses', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.historico_periodicidade_meses', to_jsonb(3),
    case when v_felix
         then 'Periodicidade obrigatória do registro de Histórico de Valor, em meses'
         else 'Periodicidade obrigatória do registro de histórico de entrega, em meses'
    end, 'conselho', 'lider');

  -- -------------------------------------------------------------- identidade
  -- A marca vive em dado, não em código. Levar a plataforma para outro cliente é
  -- trocar estas duas chaves, e não recompilar a interface.
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'identidade.cores',
    case when v_felix then jsonb_build_object(
        'marca',            '#5E1E3A',
        'marca_profunda',   '#490B2C',
        'realce',           '#EFB810',
        'realce_claro',     '#F9DB5C',
        'realce_legivel',   '#C2900A',
        'tinta',            '#1D1D1B',
        'cinza',            '#707070',
        'alarme_verde',     '#2E7D4F',
        'alarme_amarelo',   '#C58A00',
        'alarme_vermelho',  '#B3261E')
      else jsonb_build_object(
        'marca',            '#2B3A55',
        'marca_profunda',   '#1B2436',
        'realce',           '#4A6FA5',
        'realce_claro',     '#8FB0D9',
        'realce_legivel',   '#2F5C99',
        'tinta',            '#1A1A1A',
        'cinza',            '#6B6B6B',
        'alarme_verde',     '#1E7A46',
        'alarme_amarelo',   '#B07D00',
        'alarme_vermelho',  '#A32018')
    end,
    'Cores da marca', 'identidade', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'identidade.fontes',
    case when v_felix
         then jsonb_build_object('titulo', 'Oswald', 'texto', 'Montserrat', 'numero', 'Oswald')
         else jsonb_build_object('titulo', 'Inter',  'texto', 'Inter',      'numero', 'Inter')
    end,
    'Fontes do título e do texto', 'identidade', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'identidade.texto_justificado_em_tela', 'false'::jsonb,
    'Texto justificado somente em PDF, nunca na tela', 'identidade', 'admin_master');

  return v_linhas;
end;
$funcao$;

comment on function valor.semear_configuracoes(uuid, text) is
  'Semeia a configuração de um inquilino: comissão, parceria, meta, conselho e identidade. Os prazos de alerta e o limite de concentração do pipeline vêm das chaves alerta ponto e higiene ponto, semeadas pela migração 0012. Idempotente.';

-- ----------------------------------------------- o percentual que a conta usa

-- A conta da comissão lê valor.percentuais_padrao, e levanta exceção quando não
-- encontra linha vigente de escopo inquilino. Um inquilino recém-nascido sem
-- esta linha travaria na primeira parcela recebida, então ela nasce junto.
-- O número é o mesmo das chaves do grupo comissao: 15 de imposto, 10 e 10 de
-- comissão. A tela troca os dois lugares na mesma ação.
create or replace function valor.semear_percentuais(p_inquilino_id uuid)
returns integer language plpgsql as $funcao$
declare
  v_inseridas integer;
begin
  insert into valor.percentuais_padrao (
    inquilino_id, escopo, rotulo, imposto_percentual,
    comissao_vendedor_percentual, comissao_parceiro_percentual, vigencia_inicio
  )
  select p_inquilino_id, 'inquilino', 'Padrão do inquilino',
         15.0000, 10.0000, 10.0000, current_date
  where not exists (
    select 1 from valor.percentuais_padrao pp
     where pp.inquilino_id = p_inquilino_id
       and pp.escopo = 'inquilino'
       and pp.arquivado_em is null
  );

  get diagnostics v_inseridas = row_count;
  return v_inseridas;
end;
$funcao$;

comment on function valor.semear_percentuais(uuid) is
  'Abre a linha de percentual de escopo inquilino, sem a qual a apuração de comissão levanta exceção na primeira parcela. Idempotente: só nasce se ainda não houver percentual vigente do inquilino.';

-- --------------------------------------------- a paleta neutra do white label

-- A semente de GTD da migração 0011 pinta a coluna do quadro com a paleta da
-- casa, escrita no código. Num inquilino neutro isso seria identidade vazando
-- para fora, então a semente repinta com a paleta neutra logo em seguida.
-- O pedido de fundo, que a coluna leia a cor de identidade.cores em vez de
-- trazer a cor escrita, está no relatório do Curador de Catálogo.
create or replace function valor.neutralizar_identidade(p_inquilino_id uuid)
returns integer language plpgsql as $funcao$
declare
  v_pintadas integer;
begin
  update valor.colunas_kanban k
     set cor = n.cor
    from (values
      ('entrada',      '#6B6B6B'),
      ('proxima_acao', '#2B3A55'),
      ('agendada',     '#2F5C99'),
      ('aguardando',   '#B07D00'),
      ('algum_dia',    '#1A1A1A'),
      ('concluida',    '#1E7A46')
    ) as n(estado, cor)
   where k.inquilino_id = p_inquilino_id
     and k.estado_gtd::text = n.estado
     and k.cor is distinct from n.cor;

  get diagnostics v_pintadas = row_count;
  return v_pintadas;
end;
$funcao$;

comment on function valor.neutralizar_identidade(uuid) is
  'Troca a cor de código de qualquer semente pela paleta neutra do inquilino white label. Idempotente: na segunda passada não há linha para trocar.';

-- --------------------------------------------------------- a semente completa

create or replace function valor.semear_inquilino(
  p_inquilino_id uuid,
  p_perfil       text default 'felix'
) returns integer language plpgsql as $funcao$
declare
  v_linhas integer := 0;
begin
  if p_perfil is null or p_perfil not in ('felix', 'neutro') then
    raise exception 'Perfil de semente desconhecido: %. Os perfis são felix e neutro.', coalesce(p_perfil, 'nulo');
  end if;

  if not exists (select 1 from valor.inquilinos i where i.id = p_inquilino_id) then
    raise exception 'Não existe inquilino %. Crie o inquilino antes de semear.', p_inquilino_id;
  end if;

  v_linhas := v_linhas + valor.semear_ofertas(p_inquilino_id, p_perfil);
  v_linhas := v_linhas + valor.semear_configuracoes(p_inquilino_id, p_perfil);
  v_linhas := v_linhas + valor.semear_percentuais(p_inquilino_id);

  -- As outras sementes já moram nas migrações dos seus donos. A porta de entrada
  -- é uma só: quem cria inquilino chama esta função e recebe tudo, sem precisar
  -- lembrar de cinco chamadas na ordem certa. Todas são idempotentes.
  perform valor.semear_modelos_ata(p_inquilino_id);   -- 0009 · ata de sete seções e extensão
  perform valor.semear_banco_pautas(p_inquilino_id);  -- 0009 · temas de governança e famílias de gestão
  perform valor.semear_gtd(p_inquilino_id);           -- 0011 · contexto e coluna do quadro
  perform valor.semear_regras_alerta(p_inquilino_id); -- 0012 · regras, automações e prazos

  if p_perfil = 'neutro' then
    perform valor.neutralizar_identidade(p_inquilino_id);
  end if;

  return v_linhas;
end;
$funcao$;

comment on function valor.semear_inquilino(uuid, text) is
  'Semeia um inquilino inteiro: catálogo do portfólio, configuração, percentual padrão, modelo de ata, banco de pautas, vocabulário de atividades e regras de alerta. O perfil felix traz o catálogo da casa. O perfil neutro traz a mesma estrutura sem conteúdo da casa, que é o que o white label recebe. Idempotente: devolve quantas linhas de catálogo e de configuração nasceram nesta chamada, e zero na segunda.';

-- ------------------------------------------------------- o inquilino que nasce

create or replace function valor.criar_inquilino(
  nome        text,
  apelido     text,
  email_admin text,
  perfil      text default 'felix'
) returns uuid language plpgsql as $funcao$
declare
  v_inquilino uuid;
  v_email     text := lower(btrim(coalesce(email_admin, '')));
begin
  if coalesce(btrim(coalesce(nome, '')), '') = '' then
    raise exception 'O inquilino precisa de nome.';
  end if;
  if coalesce(btrim(coalesce(apelido, '')), '') = '' then
    raise exception 'O inquilino precisa de apelido, que é o identificador curto usado na URL e no convite.';
  end if;
  if position('@' in v_email) < 2 or position('.' in split_part(v_email, '@', 2)) < 2 then
    raise exception 'O endereço do administrador master veio inválido. Nenhum endereço fica escrito na migração: ele chega sempre por parâmetro.';
  end if;

  select i.id into v_inquilino
    from valor.inquilinos i
   where i.apelido = criar_inquilino.apelido;

  if v_inquilino is null then
    -- O conflito é declarado pelo nome da restrição, e não pelo nome da coluna,
    -- porque `apelido` também é o nome de um parâmetro desta função e o alvo de
    -- conflito aceita variável de plpgsql, o que deixaria a referência ambígua.
    insert into valor.inquilinos (nome, apelido)
    values (btrim(criar_inquilino.nome), btrim(criar_inquilino.apelido))
    on conflict on constraint inquilinos_apelido_key do nothing
    returning id into v_inquilino;
  end if;

  if v_inquilino is null then
    select i.id into v_inquilino
      from valor.inquilinos i
     where i.apelido = criar_inquilino.apelido;
  end if;

  perform valor.semear_inquilino(v_inquilino, criar_inquilino.perfil);

  -- Um único administrador master, e só ele. Todo mundo mais entra pela tela de
  -- gestão de usuários, com convite por e-mail e perfil escolhido na hora.
  if not exists (
    select 1 from valor.usuarios u
     where u.inquilino_id = v_inquilino
       and u.perfil = 'admin_master'
       and u.arquivado_em is null
  ) then
    insert into valor.usuarios (inquilino_id, email, nome, perfil, mfa_obrigatorio)
    values (v_inquilino, v_email, 'Administrador master', 'admin_master', true)
    on conflict (inquilino_id, email) do nothing;
  end if;

  return v_inquilino;
end;
$funcao$;

comment on function valor.criar_inquilino(text, text, text, text) is
$doc$Cria o inquilino, semeia o catálogo e a configuração pelo perfil pedido, e cadastra um único usuário administrador master, cujo endereço chega por parâmetro. Nenhum endereço de e-mail fica escrito na migração. Idempotente: rodar de novo com o mesmo apelido devolve o mesmo inquilino e não cria um segundo administrador.

A conta de emergência não nasce aqui. Ela é criada logo depois, pela tela de gestão de usuários, com múltiplo fator obrigatório e com os códigos de recuperação impressos e guardados fisicamente, fora de qualquer sistema. O endereço dessa conta é decidido na hora de publicar e nunca entra no repositório.

A função roda com os direitos de quem chama, e não com os do dono, de propósito. Abrir inquilino não é operação de usuário de aplicação: valor.inquilinos tem segurança de linha e nenhuma política de escrita, então quem chama por uma sessão comum é barrado pelo banco. Quem abre inquilino é o dono das tabelas, na carga inicial, ou a chave de serviço, na publicação.$doc$;

-- ------------------------------------------------- a prova do white label limpo

-- A identidade visual da casa, dez cores fechadas no contrato técnico. Cor de
-- marca dentro de um inquilino white label vaza tanto quanto nome de programa,
-- e vaza mais calado, porque ninguém lê hexadecimal numa revisão de texto.
create or replace function valor.cores_da_casa() returns text[]
language sql immutable as $funcao$
  select array[
    '#5E1E3A',  -- vinho
    '#490B2C',  -- vinho profundo
    '#EFB810',  -- dourado
    '#F9DB5C',  -- dourado claro
    '#C2900A',  -- dourado sobre branco
    '#1D1D1B',  -- tinta
    '#707070',  -- cinza
    '#2E7D4F',  -- alarme verde
    '#C58A00',  -- alarme amarelo
    '#B3261E'   -- alarme vermelho
  ];
$funcao$;

comment on function valor.cores_da_casa() is
  'As dez cores da identidade visual da casa, do contrato técnico. Nenhuma delas pode aparecer num inquilino white label.';

-- As palavras da casa que jamais podem aparecer num inquilino white label.
-- Casadas sem distinguir maiúscula de minúscula.
create or replace function valor.palavras_da_casa() returns text[]
language sql immutable as $funcao$
  select array[
    'felix',
    'conselho de valor',
    'negócios de valor',
    'negocios de valor',
    'mesa do ceo',
    'sprint de valor',
    'liderança de valor',
    'lideranca de valor',
    'gestão de valor',
    'gestao de valor',
    'mentoria de valor',
    'executivo de valor',
    'programas de valor',
    'histórico de valor',
    'historico de valor',
    'plataforma de valor',
    'oswald',
    'montserrat'
  ] || valor.cores_da_casa();
$funcao$;

comment on function valor.palavras_da_casa() is
  'As expressões da casa que reprovam um inquilino white label, junto com as cores da casa. Casadas sem distinguir maiúscula de minúscula.';

-- A marca da casa como palavra inteira e com a caixa que a casa usa. Distingue
-- maiúscula de minúscula de propósito: `proposta de valor` é vocabulário comum
-- de negócio e passa, `Conselho de Valor` é marca e reprova.
create or replace function valor.marcas_da_casa() returns text[]
language sql immutable as $funcao$
  select array['\mValor\M', '\mFelix\M'];
$funcao$;

comment on function valor.marcas_da_casa() is
  'A marca da casa como palavra inteira, casada respeitando a caixa. Serve para separar a palavra comum valor da marca Valor.';

-- Varre toda linha de todo texto de um inquilino procurando palavra da casa.
-- É o que prova que o white label é entregável, e não promessa. Devolve uma
-- linha por ocorrência, com tabela, coluna, chave da linha e o trecho achado.
-- Rodada contra o inquilino da casa, acha muita coisa. Rodada contra o inquilino
-- neutro, precisa devolver vazio.
create or replace function valor.vazamento_de_marca(
  p_inquilino_id uuid,
  p_sem_caixa    text[] default null,
  p_com_caixa    text[] default null
) returns table (
  tabela  text,
  coluna  text,
  linha   uuid,
  achado  text,
  trecho  text
) language plpgsql stable as $funcao$
declare
  r      record;
  l_sem  text[] := coalesce(p_sem_caixa, valor.palavras_da_casa());
  l_com  text[] := coalesce(p_com_caixa, valor.marcas_da_casa());
  -- Lista vazia vira nulo, e a passada correspondente nem roda. Sem isso a
  -- alternância ficaria `()`, que casa com a linha inteira e faria a varredura
  -- reprovar tudo, ou pior, aprovar tudo quando invertida.
  v_sem  text := case when coalesce(array_length(l_sem, 1), 0) = 0
                      then null else '(' || array_to_string(l_sem, '|') || ')' end;
  v_com  text := case when coalesce(array_length(l_com, 1), 0) = 0
                      then null else '(' || array_to_string(l_com, '|') || ')' end;
begin
  for r in
    select c.relname::text as tabela,
           a.attname::text as coluna,
           exists (select 1 from pg_attribute b
                    where b.attrelid = c.oid and b.attname = 'id'
                      and b.attnum > 0 and not b.attisdropped) as tem_id
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
      join pg_type t on t.oid = a.atttypid
     where n.nspname = 'valor'
       and c.relkind = 'r'
       and t.typname in ('text', 'varchar', 'bpchar', 'json', 'jsonb', '_text', '_varchar')
       and exists (select 1 from pg_attribute b
                    where b.attrelid = c.oid and b.attname = 'inquilino_id'
                      and b.attnum > 0 and not b.attisdropped)
     order by 1, 2
  loop
    -- Passada sem caixa: `Felix`, `FELIX` e `felix` reprovam do mesmo jeito.
    if v_sem is not null then
      return query execute format(
        'select %L::text, %L::text, %s, (regexp_match(x.%I::text, %L, ''i''))[1], left(x.%I::text, 160)
           from valor.%I x
          where x.inquilino_id = %L::uuid
            and x.%I::text ~* %L',
        r.tabela, r.coluna,
        case when r.tem_id then 'x.id' else 'null::uuid' end,
        r.coluna, v_sem, r.coluna, r.tabela, p_inquilino_id, r.coluna, v_sem);
    end if;

    -- Passada com caixa: separa a marca `Valor` da palavra comum `valor`.
    if v_com is not null then
      return query execute format(
        'select %L::text, %L::text, %s, (regexp_match(x.%I::text, %L))[1], left(x.%I::text, 160)
           from valor.%I x
          where x.inquilino_id = %L::uuid
            and x.%I::text ~ %L',
        r.tabela, r.coluna,
        case when r.tem_id then 'x.id' else 'null::uuid' end,
        r.coluna, v_com, r.coluna, r.tabela, p_inquilino_id, r.coluna, v_com);
    end if;
  end loop;
end;
$funcao$;

comment on function valor.vazamento_de_marca(uuid, text[], text[]) is
  'Varre toda coluna de texto, de todo vetor de texto e de todo jsonb de toda tabela de um inquilino atrás das palavras e das cores da casa. Devolve uma linha por achado, com a tabela, a coluna, a chave da linha e a primeira ocorrência daquela passada. Zero linha no inquilino neutro é a prova de que o white label sai limpo. Rode com o dono das tabelas, para que a segurança de linha não esconda o que precisa aparecer.';


-- ==========================================================================
-- 0017_historico_de_fases.sql
-- ==========================================================================
-- 0017 · Histórico de fases do negócio
-- Dono: orquestrador. Pedido da frente de operação.
--
-- Por que existe: o alarme de negócio parado nasceu com piso fixo de trinta
-- dias, porque não havia como saber quanto tempo uma fase costuma durar nesta
-- casa. Com esta tabela, o alarme passa a ser duas vezes a mediana histórica da
-- fase, que é a regra que a casa quer. Enquanto não houver histórico bastante,
-- o piso configurado continua valendo.

create table valor.historico_fases (
  id           uuid primary key default gen_random_uuid(),
  inquilino_id uuid not null references valor.inquilinos(id) on delete restrict,
  negocio_id   uuid not null references valor.negocios(id) on delete cascade,
  fase         smallint not null check (fase between 0 and 9),
  entrou_em    date not null,
  saiu_em      date,
  dias_na_fase integer generated always as (saiu_em - entrou_em) stored,
  criado_em    timestamptz not null default now(),
  criado_por   uuid
);

create index on valor.historico_fases (inquilino_id, fase) where saiu_em is not null;
create index on valor.historico_fases (negocio_id, entrou_em);
create unique index historico_fases_aberta_unica on valor.historico_fases (negocio_id)
  where saiu_em is null;

comment on table valor.historico_fases is
  'Uma linha por passagem de um negócio por uma fase. É daqui que sai a mediana de duração por fase.';
comment on column valor.historico_fases.dias_na_fase is
  'Calculado pelo banco. Nulo enquanto o negócio ainda estiver na fase.';

-- Registra a entrada na fase e fecha a anterior, sem que ninguém precise lembrar.
create or replace function valor.registrar_fase() returns trigger
language plpgsql security definer set search_path = valor, pg_catalog as $$
begin
  if tg_op = 'INSERT' then
    insert into valor.historico_fases (inquilino_id, negocio_id, fase, entrou_em, criado_por)
    values (new.inquilino_id, new.id, new.fase, coalesce(new.entrou_na_fase_em, current_date), valor.usuario_atual());
    return new;
  end if;

  if new.fase is distinct from old.fase then
    update valor.historico_fases
       set saiu_em = current_date
     where negocio_id = new.id and saiu_em is null;

    insert into valor.historico_fases (inquilino_id, negocio_id, fase, entrou_em, criado_por)
    values (new.inquilino_id, new.id, new.fase, current_date, valor.usuario_atual());

    new.entrou_na_fase_em := current_date;
  end if;
  return new;
end;
$$;

create trigger registra_fase_ao_nascer after insert on valor.negocios
  for each row execute function valor.registrar_fase();
create trigger registra_fase_ao_mudar before update of fase on valor.negocios
  for each row execute function valor.registrar_fase();

-- A mediana por fase. Devolve nulo quando não há amostra bastante, e aí quem
-- chama usa o piso configurado. Doze passagens é o mínimo para a mediana dizer
-- alguma coisa, e o número fica na configuração do inquilino.
create or replace function valor.mediana_dias_da_fase(p_inquilino uuid, p_fase smallint)
returns integer language sql stable as $$
  with amostra as (
    select dias_na_fase from valor.historico_fases
    where inquilino_id = p_inquilino and fase = p_fase and saiu_em is not null and dias_na_fase >= 0
  )
  select case
    when (select count(*) from amostra) >= coalesce(
           (select (valor->>'valor')::integer from valor.configuracoes
             where inquilino_id = p_inquilino and chave = 'alerta.amostra_minima_mediana'), 12)
    then (select percentile_cont(0.5) within group (order by dias_na_fase)::integer from amostra)
  end;
$$;

alter table valor.historico_fases enable row level security;

-- O histórico de fases é medida interna de funil: quanto tempo cada negócio
-- ficou em cada etapa. É leitura e escrita do time da casa. Gente de fora não
-- entra, nem o parceiro que indicou o negócio, nem o participante da turma.
create policy historico_fases_le on valor.historico_fases for select
  using (inquilino_id = valor.inquilino_atual() and valor.time_da_casa());
create policy historico_fases_escreve on valor.historico_fases for all
  using (inquilino_id = valor.inquilino_atual() and valor.time_da_casa())
  with check (inquilino_id = valor.inquilino_atual() and valor.time_da_casa());

-- Pedido da frente de operação: a validade do Plano de Trabalho vivia dentro do
-- jsonb e o alerta precisava adivinhar. Agora é coluna.
alter table valor.artefatos add column if not exists valido_ate date;
comment on column valor.artefatos.valido_ate is
  'Até quando o artefato vale para o cliente. O alerta de Plano de Trabalho vencendo lê esta coluna.';


-- ==========================================================================
-- 0018_ponte_com_a_autenticacao.sql
-- ==========================================================================
-- 0018 · Ponte com a autenticação do Supabase
-- Dono: orquestrador.
--
-- Por que este arquivo existe, e por que ele é indispensável:
--
-- Toda a segurança desta plataforma pergunta ao token quem é a pessoa, de que
-- inquilino ela é, que perfil ela tem, e, quando for parceiro, qual parceiro.
-- O token que o Supabase emite por padrão **não carrega nada disso**. Sem esta
-- ponte, `valor.perfil_atual()` devolve `nenhum` para todo mundo, toda política
-- nega tudo, e a plataforma sobe muda: ninguém enxerga nada e ninguém entende
-- por quê.
--
-- Duas peças resolvem isso:
--
-- 1. O gancho de emissão de token, que o Supabase chama a cada autenticação e a
--    cada renovação. Ele lê a linha da pessoa em `valor.usuarios` e escreve as
--    claims dentro do token.
-- 2. O vínculo entre `auth.users` e `valor.usuarios`, feito por endereço, no
--    momento em que a pessoa aceita o convite.
--
-- Tudo aqui é condicional: neste contêiner não existe o esquema `auth` nem o
-- papel `supabase_auth_admin`, e o arquivo precisa aplicar mesmo assim, para a
-- cadeia de migrações continuar rodando no teste local.

-- ------------------------------------------------ o gancho de emissão de token

create or replace function valor.gancho_token(evento jsonb)
returns jsonb language plpgsql stable security definer set search_path = valor, pg_catalog as $$
declare
  pessoa   record;
  claims   jsonb;
  parceiro uuid;
begin
  claims := coalesce(evento -> 'claims', '{}'::jsonb);

  select u.id, u.inquilino_id, u.perfil, u.ativo, u.nome
    into pessoa
    from valor.usuarios u
   where u.auth_id = (evento ->> 'user_id')::uuid
     and u.arquivado_em is null
   limit 1;

  if pessoa.id is null or not pessoa.ativo then
    -- Pessoa sem cadastro ativo recebe um token sem poder algum. A sessão
    -- autentica e não enxerga nada, que é o comportamento correto: recusar o
    -- acesso é papel da aplicação, e negar o dado é papel do banco.
    claims := claims
      || jsonb_build_object('perfil', 'nenhum')
      || jsonb_build_object('plataforma_de_valor', 'sem_cadastro_ativo');
    return jsonb_set(evento, '{claims}', claims);
  end if;

  select pu.parceiro_id into parceiro
    from valor.parceiros_usuarios pu
   where pu.usuario_id = pessoa.id
     and pu.arquivado_em is null
   limit 1;

  claims := claims
    || jsonb_build_object('usuario_id',   pessoa.id::text)
    || jsonb_build_object('inquilino_id', pessoa.inquilino_id::text)
    || jsonb_build_object('perfil',       pessoa.perfil::text)
    || jsonb_build_object('nome',         pessoa.nome);

  if parceiro is not null then
    claims := claims || jsonb_build_object('parceiro_id', parceiro::text);
  end if;

  return jsonb_set(evento, '{claims}', claims);
end;
$$;

comment on function valor.gancho_token(jsonb) is
  'Escreve inquilino, perfil, usuário e parceiro dentro do token. Ligar no painel do Supabase, em Autenticação, gancho de emissão de token de acesso.';

-- ------------------------------------------------ o vínculo com o convite

-- Quando a pessoa aceita o convite e nasce em auth.users, amarramos a linha dela
-- em valor.usuarios pelo endereço. Sem isto, o gancho não acha ninguém.
create or replace function valor.vincular_identidade(p_auth_id uuid, p_email text)
returns uuid language plpgsql security definer set search_path = valor, pg_catalog as $$
declare
  alvo uuid;
begin
  update valor.usuarios
     set auth_id = p_auth_id,
         ultimo_acesso = now()
   where lower(email) = lower(p_email)
     and auth_id is null
     and arquivado_em is null
   returning id into alvo;

  if alvo is not null then
    update valor.convites
       set aceito_em = now(), usuario_id = alvo
     where lower(email) = lower(p_email) and aceito_em is null;
  end if;

  return alvo;
end;
$$;

comment on function valor.vincular_identidade(uuid, text) is
  'Amarra a identidade recém criada na autenticação à pessoa já convidada. Casa pelo endereço, e só quando o vínculo ainda não existe.';

-- ------------------------------------------------ o que só existe no Supabase

do $$
begin
  -- O gancho roda com o papel da autenticação, que precisa alcançar o cadastro.
  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant usage on schema valor to supabase_auth_admin';
    execute 'grant execute on function valor.gancho_token(jsonb) to supabase_auth_admin';
    execute 'grant select on valor.usuarios, valor.parceiros_usuarios to supabase_auth_admin';

    -- O gancho é do serviço de autenticação, e de mais ninguém.
    execute 'revoke execute on function valor.gancho_token(jsonb) from authenticated, anon, public';
    execute 'revoke execute on function valor.vincular_identidade(uuid, text) from authenticated, anon, public';

    execute $pol$
      create policy usuario_le_pela_autenticacao on valor.usuarios for select
        to supabase_auth_admin using (true)
    $pol$;
    execute $pol$
      create policy parceiro_usuario_le_pela_autenticacao on valor.parceiros_usuarios for select
        to supabase_auth_admin using (true)
    $pol$;
  end if;

  -- Amarra a identidade no instante em que ela nasce.
  if exists (select 1 from pg_namespace where nspname = 'auth') then
    execute $fn$
      create or replace function valor.ao_nascer_identidade() returns trigger
      language plpgsql security definer set search_path = valor, pg_catalog as $b$
      begin
        perform valor.vincular_identidade(new.id, new.email);
        return new;
      end;
      $b$;
    $fn$;
    execute 'drop trigger if exists vincula_na_plataforma_de_valor on auth.users';
    execute 'create trigger vincula_na_plataforma_de_valor after insert on auth.users
             for each row execute function valor.ao_nascer_identidade()';
  end if;
end $$;


-- ==========================================================================
-- 0080_amarracao_entre_dominios.sql
-- ==========================================================================
-- 0080 · Amarração entre domínios
-- Dono: orquestrador. Roda depois que todas as tabelas existem e antes das permissões.
--
-- Por que este arquivo existe: cinco construtores escreveram em paralelo, e um
-- não pode criar chave estrangeira para tabela que ainda não existia quando ele
-- escreveu. Cada um deixou a coluna solta e registrou o pedido. Aqui as pontas
-- se encontram, num lugar só, onde dá para ver o desenho inteiro.

-- ------------------------------------------------ governança aponta para o BRM
-- A pauta, a ata e a pendência pertencem a uma reunião de uma turma.
-- Todas continuam aceitando nulo, porque existe pendência que nasce fora de
-- reunião e ata de encontro que ainda não foi cadastrado.

alter table valor.pautas
  add constraint pautas_turma_fk     foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint pautas_encontro_fk  foreign key (encontro_id) references valor.encontros(id) on delete restrict;

alter table valor.atas
  add constraint atas_turma_fk       foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint atas_encontro_fk    foreign key (encontro_id) references valor.encontros(id) on delete restrict;

alter table valor.pendencias
  add constraint pendencias_turma_fk    foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint pendencias_encontro_fk foreign key (encontro_id) references valor.encontros(id) on delete restrict;

alter table valor.pesquisas
  add constraint pesquisas_turma_fk    foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint pesquisas_programa_fk foreign key (programa_id) references valor.programas(id) on delete restrict;

-- ------------------------------------------------ BRM aponta para o financeiro
-- Todas aceitam nulo de propósito: a turma pode rodar antes do contrato estar
-- assinado, e isso acontece na prática.

alter table valor.programas
  add constraint programas_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.turmas
  add constraint turmas_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.turmas_contas
  add constraint turmas_contas_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.participantes
  add constraint participantes_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.historico_valor
  add constraint historico_valor_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;

-- ------------------------------------------------ numeração por turma
-- Decisão de arquitetura número 3. No conselho compartilhado, uma turma reúne
-- empresários de contas diferentes e a reunião é uma só. Numerar por conta
-- produziria a mesma reunião com números distintos para cada participante.
-- Onde não há turma, a numeração por conta continua valendo.

drop index if exists valor.pautas_numero_unico;

create unique index pautas_numero_por_turma on valor.pautas (inquilino_id, turma_id, numero)
  where turma_id is not null and numero is not null and arquivado_em is null;
create unique index pautas_numero_por_conta on valor.pautas (inquilino_id, conta_id, numero)
  where turma_id is null and numero is not null and arquivado_em is null;

alter table valor.atas drop constraint if exists atas_inquilino_id_conta_id_numero_key;

create unique index atas_numero_por_turma on valor.atas (inquilino_id, turma_id, numero)
  where turma_id is not null and arquivado_em is null;
create unique index atas_numero_por_conta on valor.atas (inquilino_id, conta_id, numero)
  where turma_id is null and arquivado_em is null;

comment on index valor.atas_numero_por_turma is
  'A ata é numerada por turma. No conselho compartilhado a reunião é uma só para contas diferentes.';


-- ==========================================================================
-- 0090_papeis_e_permissoes.sql
-- ==========================================================================
-- 0090 · Papéis de banco e permissões
-- Dono: orquestrador. Roda por último, depois que todas as tabelas existem.
--
-- Por que este arquivo existe: o dono de uma tabela no PostgreSQL ignora a
-- segurança de linha por padrão. Um teste feito com o dono aprova qualquer
-- política, inclusive uma política quebrada. Aqui nasce o papel sem privilégio
-- que o aplicativo usa de verdade, e é com ele que a segurança é provada.
--
-- No Supabase, o papel equivalente é `authenticated`. As concessões abaixo
-- usam `valor_aplicacao` no ambiente local e `authenticated` quando ele existir.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'valor_aplicacao') then
    create role valor_aplicacao nologin;
  end if;
end $$;

grant usage on schema valor to valor_aplicacao;
grant select, insert, update on all tables in schema valor to valor_aplicacao;
grant execute on all functions in schema valor to valor_aplicacao;
alter default privileges in schema valor
  grant select, insert, update on tables to valor_aplicacao;

-- Ninguém apaga linha. Arquivar é carimbar a data em arquivado_em.
revoke delete on all tables in schema valor from valor_aplicacao;

-- A trilha de auditoria não se reescreve.
revoke update on valor.auditoria from valor_aplicacao;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant usage on schema valor to authenticated';
    execute 'grant select, insert, update on all tables in schema valor to authenticated';
    execute 'grant execute on all functions in schema valor to authenticated';
    execute 'revoke delete on all tables in schema valor from authenticated';
  end if;
end $$;

