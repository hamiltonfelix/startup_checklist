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
