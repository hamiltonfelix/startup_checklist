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
