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
