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
