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
