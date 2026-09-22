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
  case when a.prazo is not null and a.prazo < current_date
       then current_date - a.prazo end       as dias_de_atraso,
  case when a.prazo is null                    then 'sem_prazo'
       when a.prazo < current_date             then 'vencida'
       when a.prazo = current_date             then 'vence_hoje'
       when a.prazo <= current_date + 7        then 'vence_na_semana'
       else                                        'no_prazo'
  end                                        as situacao,
  case when a.prazo is null                    then 'Sem prazo definido'
       when a.prazo < current_date             then 'Vencida'
       when a.prazo = current_date             then 'Vence hoje'
       when a.prazo <= current_date + 7        then 'Vence nesta semana'
       else                                        'No prazo'
  end                                        as situacao_rotulo,
  case when a.prazo is not null and a.prazo < current_date  then 1
       when a.prazo = current_date                          then 2
       when a.prazo is not null and a.prazo <= current_date + 7 then 3
       when a.prazo is not null                             then 4
       else                                                      5
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
