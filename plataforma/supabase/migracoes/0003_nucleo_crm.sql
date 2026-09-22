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
