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
