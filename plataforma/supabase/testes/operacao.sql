-- Prova de operação · atividades no método GTD, alertas, automações e auditoria
-- Dono: engenheiro de operação. Cobre as migrações 0011, 0012 e 0013.
--
-- Este arquivo é teste de regressão, não prova de uma vez só. Roda quantas
-- vezes quiser: tudo acontece dentro de uma transação que termina em rollback,
-- então o banco volta exatamente ao estado anterior. Nenhum registro é apagado
-- e nenhum dado real entra aqui: inquilino, pessoa, conta e negócio são
-- ficção, com identificadores fixos e valores redondos inventados.
--
-- Como rodar:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d fab_ops \
--     -f plataforma/supabase/testes/operacao.sql
--
-- As leituras rodam com o papel valor_aplicacao, criado na migração 0090, e
-- não com o dono das tabelas. O dono ignora a segurança de linha, então provar
-- com ele aprovaria política quebrada.

\set ON_ERROR_STOP on
\pset pager off
\pset null '(nulo)'
-- O nível de mensagem fica em notice de propósito: é por notice que as
-- tentativas barradas se mostram na saída.
set client_min_messages = notice;

begin;

-- =====================================================================
-- Cenário de ficção
-- =====================================================================

insert into valor.inquilinos (id, nome, apelido)
values ('11111111-1111-4111-8111-111111111111', 'Inquilino de Prova', 'prova');

insert into valor.usuarios (id, inquilino_id, email, nome, perfil)
values ('22222222-2222-4222-8222-222222222222',
        '11111111-1111-4111-8111-111111111111',
        'lider@exemplo.invalido', 'Pessoa Fictícia da Prova', 'admin_master');

insert into valor.contas (id, inquilino_id, nome, tier, prioridade, gerente_contas_id)
values ('33333333-3333-4333-8333-333333333333',
        '11111111-1111-4111-8111-111111111111',
        'Conta Fictícia Alfa', 't2', 2, '22222222-2222-4222-8222-222222222222');

-- Um negócio na Exploração Profunda, sem próximo passo, sem artefato da fase e
-- com a última interação sessenta dias atrás.
insert into valor.negocios (
  id, inquilino_id, conta_id, titulo, fase, valor_total,
  data_decisao_cliente, proximo_passo, proximo_passo_data,
  ultima_interacao, entrou_na_fase_em)
values ('44444444-4444-4444-8444-444444444444',
        '11111111-1111-4111-8111-111111111111',
        '33333333-3333-4333-8333-333333333333',
        'Negócio Fictício Parado', 2, 200000.00,
        current_date + 30, null, null,
        current_date - 60, current_date - 60);

-- O vocabulário e as regras que a casa já decidiu, semeados para o inquilino
-- novo. As duas funções são idempotentes.
select valor.semear_gtd('11111111-1111-4111-8111-111111111111');
select valor.semear_regras_alerta('11111111-1111-4111-8111-111111111111');

-- A partir daqui, papel de aplicativo e contexto de sessão.
set local role valor_aplicacao;
select set_config('app.inquilino_id', '11111111-1111-4111-8111-111111111111', true),
       set_config('app.usuario_id',   '22222222-2222-4222-8222-222222222222', true),
       set_config('app.perfil',       'admin_master', true),
       set_config('app.origem',       'teste.operacao', true);
select current_user as papel_em_uso;

\echo ''
\echo '====================================================================='
\echo 'PROVA 1 · negócio sem próximo passo e parado há 60 dias, alarme vermelho'
\echo '====================================================================='

\echo '--- as quatro invariantes de higiene, lidas linha a linha'
select titulo, fase,
       tem_proximo_passo, decisao_no_futuro, interacao_recente, tem_artefato_da_fase,
       array_to_string(invariantes_quebradas, ' · ') as quebradas
  from valor.negocios_fora_da_higiene('11111111-1111-4111-8111-111111111111');

\echo '--- dias parado contra o limite configurado da fase'
select n.titulo,
       (current_date - n.ultima_interacao) as dias_parado,
       valor.limite_dias_parado(n.inquilino_id, n.fase) as limite_dias
  from valor.negocios n
 where n.id = '44444444-4444-4444-8444-444444444444';

\echo '--- rodada 1 de valor.avaliar_alertas'
select regra, criticidade, novos, ja_abertos, resolvidos, situacao
  from valor.avaliar_alertas('11111111-1111-4111-8111-111111111111');

\echo '--- os alarmes vermelhos abertos'
select r.codigo as regra, a.criticidade, a.status, a.mensagem
  from valor.alertas a
  join valor.regras_alerta r on r.id = a.regra_id
 where a.inquilino_id = '11111111-1111-4111-8111-111111111111'
   and a.criticidade = 'vermelho'
 order by r.ordem;

\echo '--- o detalhe gravado no alerta de negócio parado'
select jsonb_pretty(a.detalhe) as detalhe
  from valor.alertas a
  join valor.regras_alerta r on r.id = a.regra_id
 where r.codigo = 'negocio_parado'
   and a.inquilino_id = '11111111-1111-4111-8111-111111111111';

\echo ''
\echo '====================================================================='
\echo 'PROVA 2 · idempotência: rodar duas vezes e continuar com um alerta só'
\echo '====================================================================='

\echo '--- quantos alertas existem depois da rodada 1'
select count(*) as alertas_no_total,
       count(*) filter (where status = 'aberto') as abertos
  from valor.alertas
 where inquilino_id = '11111111-1111-4111-8111-111111111111';

\echo '--- rodada 2, no mesmo dia'
select regra, criticidade, novos, ja_abertos, resolvidos, situacao
  from valor.avaliar_alertas('11111111-1111-4111-8111-111111111111');

\echo '--- quantos alertas existem depois da rodada 2'
select count(*) as alertas_no_total,
       count(*) filter (where status = 'aberto') as abertos
  from valor.alertas
 where inquilino_id = '11111111-1111-4111-8111-111111111111';

\echo '--- um alerta aberto por regra e por entidade, nunca dois'
select r.codigo as regra, a.entidade, a.entidade_chave, count(*) as alertas_abertos
  from valor.alertas a
  join valor.regras_alerta r on r.id = a.regra_id
 where a.inquilino_id = '11111111-1111-4111-8111-111111111111'
   and a.status = 'aberto'
 group by r.codigo, a.entidade, a.entidade_chave
 order by r.codigo;

\echo '--- a restrição que garante isso'
select indexdef as restricao
  from pg_indexes
 where schemaname = 'valor' and indexname = 'alertas_um_aberto_por_entidade';

\echo ''
\echo '====================================================================='
\echo 'PROVA 3 · atividade recorrente concluída gerando a próxima'
\echo '====================================================================='

insert into valor.atividades_recorrencia (id, inquilino_id, nome, frequencia, intervalo)
values ('55555555-5555-4555-8555-555555555555',
        '11111111-1111-4111-8111-111111111111',
        'Encontro semanal de gestão', 'semanal', 1);

insert into valor.atividades (
  id, inquilino_id, titulo, estado, contexto_id, energia, tempo_estimado_min,
  prazo, responsavel_id, prioridade, negocio_id, recorrencia_id)
values ('66666666-6666-4666-8666-666666666666',
        '11111111-1111-4111-8111-111111111111',
        'Encontro semanal de gestão', 'proxima_acao',
        (select id from valor.contextos_gtd
          where inquilino_id = '11111111-1111-4111-8111-111111111111' and codigo = '@reuniao'),
        'media', 90, current_date, '22222222-2222-4222-8222-222222222222', 1,
        '44444444-4444-4444-8444-444444444444',
        '55555555-5555-4555-8555-555555555555');

insert into valor.atividades_checklist (inquilino_id, atividade_id, descricao, ordem)
values ('11111111-1111-4111-8111-111111111111',
        '66666666-6666-4666-8666-666666666666', 'Rever Highlights e Lowlights', 10),
       ('11111111-1111-4111-8111-111111111111',
        '66666666-6666-4666-8666-666666666666', 'Fechar metas e prioridades da semana', 20);

-- Mais duas atividades, para a caixa de entrada mostrar os quatro montes.
insert into valor.atividades (
  inquilino_id, titulo, estado, energia, tempo_estimado_min, prazo, responsavel_id, prioridade)
values ('11111111-1111-4111-8111-111111111111',
        'Revisar o Plano de Conta fictício', 'proxima_acao', 'alta', 45,
        current_date - 4, '22222222-2222-4222-8222-222222222222', 1);

insert into valor.atividades (
  inquilino_id, titulo, estado, energia, tempo_estimado_min, responsavel_id,
  delegado_para_externo, aguardando_desde, conta_id)
values ('11111111-1111-4111-8111-111111111111',
        'Receber o retorno do cliente fictício', 'aguardando', 'baixa', 15,
        '22222222-2222-4222-8222-222222222222',
        'Contato Fictício da Conta Alfa', current_date - 10,
        '33333333-3333-4333-8333-333333333333');

\echo '--- antes de concluir'
select count(*) as atividades_da_serie
  from valor.atividades
 where recorrencia_id = '55555555-5555-4555-8555-555555555555';

update valor.atividades
   set estado = 'concluida', resultado = 'Encontro realizado'
 where id = '66666666-6666-4666-8666-666666666666';

\echo '--- depois de concluir: a anterior fica, a próxima nasce'
select case when a.id = '66666666-6666-4666-8666-666666666666'
            then 'ocorrência concluída' else 'próxima ocorrência' end as qual,
       a.titulo, a.estado, a.prazo,
       (a.concluida_em is not null) as tem_carimbo_de_conclusao,
       (a.origem_atividade_id is not distinct from '66666666-6666-4666-8666-666666666666'::uuid) as veio_da_anterior,
       (a.proxima_ocorrencia_id is not null) as aponta_para_a_proxima
  from valor.atividades a
 where a.recorrencia_id = '55555555-5555-4555-8555-555555555555'
 order by a.prazo;

\echo '--- o checklist viajou junto, e voltou a zero'
select a.prazo, c.descricao, c.concluido
  from valor.atividades_checklist c
  join valor.atividades a on a.id = c.atividade_id
 where a.recorrencia_id = '55555555-5555-4555-8555-555555555555'
 order by a.prazo, c.ordem;

\echo '--- a série contou a ocorrência gerada'
select nome, frequencia, intervalo, ocorrencias_geradas, ultima_ocorrencia_em
  from valor.atividades_recorrencia
 where id = '55555555-5555-4555-8555-555555555555';

\echo '--- a caixa de entrada do usuário, os quatro montes do método'
select grupo, rotulo, titulo, prazo, dias
  from valor.caixa_de_entrada
 where usuario_id = '22222222-2222-4222-8222-222222222222'
 order by ordem_grupo, prazo;

\echo '--- o mesmo dado desenhado como quadro, sem duplicar linha'
select coluna, coluna_ordem, titulo, estado
  from valor.quadro_kanban
 where inquilino_id = '11111111-1111-4111-8111-111111111111'
 order by coluna_ordem, titulo;

\echo ''
\echo '====================================================================='
\echo 'PROVA 4 · auditoria com só a coluna alterada e o confidencial omitido'
\echo '====================================================================='

\echo '--- as colunas confidenciais de valor.negocios, descobertas nos comentários'
select valor.colunas_confidenciais('valor.negocios'::regclass) as confidenciais;

\echo '--- quantas colunas a tabela tem no total'
select count(*) as colunas_da_tabela
  from information_schema.columns
 where table_schema = 'valor' and table_name = 'negocios';

update valor.negocios
   set proximo_passo = 'Enviar o Plano de Negócio revisado'
 where id = '44444444-4444-4444-8444-444444444444';

update valor.negocios
   set valor_total = 250000.00
 where id = '44444444-4444-4444-8444-444444444444';

\echo '--- as duas atualizações na trilha, uma coluna cada'
select a.operacao,
       a.perfil,
       a.origem,
       (select count(*) from jsonb_object_keys(a.mudancas)) as colunas_no_diff,
       jsonb_pretty(a.mudancas) as mudancas
  from valor.auditoria a
 where a.tabela = 'negocios'
   and a.chave = '44444444-4444-4444-8444-444444444444'
   and a.operacao = 'atualizacao'
 order by a.momento;

\echo '--- quem assinou a mudança'
select a.tabela, a.operacao, u.nome as usuario, a.perfil, a.origem
  from valor.auditoria a
  join valor.usuarios u on u.id = a.usuario_id
 where a.tabela = 'negocios' and a.operacao = 'atualizacao'
 order by a.momento;

\echo '--- arquivar é carimbar, e a trilha registra a operação como arquivamento'
insert into valor.negocios (id, inquilino_id, conta_id, titulo, fase)
values ('77777777-7777-4777-8777-777777777777',
        '11111111-1111-4111-8111-111111111111',
        '33333333-3333-4333-8333-333333333333',
        'Negócio Fictício a Arquivar', 1);

update valor.negocios
   set arquivado_em = now()
 where id = '77777777-7777-4777-8777-777777777777';

select a.operacao, (select count(*) from jsonb_object_keys(a.mudancas)) as colunas_no_diff,
       jsonb_pretty(a.mudancas) as mudancas
  from valor.auditoria a
 where a.tabela = 'negocios'
   and a.chave = '77777777-7777-4777-8777-777777777777'
   and a.operacao = 'arquivamento';

\echo '--- o papel do aplicativo não atualiza linha de auditoria: barrado pela concessão'
do $$
begin
  update valor.auditoria set perfil = 'invasor' where tabela = 'negocios';
  raise exception 'FALHA: a trilha aceitou atualização.';
exception
  when insufficient_privilege or restrict_violation then
    raise notice 'barrado como esperado: %', sqlerrm;
end;
$$;

\echo '--- o papel do aplicativo não remove linha de negócio: barrado pela concessão'
do $$
begin
  delete from valor.negocios where id = '44444444-4444-4444-8444-444444444444';
  raise exception 'FALHA: a tabela aceitou remoção.';
exception
  when insufficient_privilege or restrict_violation then
    raise notice 'barrado como esperado: %', sqlerrm;
end;
$$;

-- O dono da tabela ignora concessão e segurança de linha. Contra ele vale o
-- gatilho, e é isso que as duas tentativas abaixo provam.
reset role;

\echo '--- nem o dono da tabela atualiza a trilha: o gatilho de imutabilidade barra'
do $$
begin
  update valor.auditoria set perfil = 'invasor' where tabela = 'negocios';
  raise exception 'FALHA: a trilha aceitou atualização do dono.';
exception
  when restrict_violation then
    raise notice 'barrado como esperado: %', sqlerrm;
end;
$$;

\echo '--- nem o dono da tabela remove linha de negócio: o gatilho de auditoria barra'
do $$
begin
  delete from valor.negocios where id = '44444444-4444-4444-8444-444444444444';
  raise exception 'FALHA: a tabela aceitou remoção do dono.';
exception
  when restrict_violation then
    raise notice 'barrado como esperado: %', sqlerrm;
end;
$$;

set local role valor_aplicacao;

\echo ''
\echo '====================================================================='
\echo 'PROVA 5 · alerta resolvido é carimbado, nunca removido'
\echo '====================================================================='

update valor.negocios
   set proximo_passo_data = current_date + 7,
       ultima_interacao   = current_date
 where id = '44444444-4444-4444-8444-444444444444';

insert into valor.artefatos (inquilino_id, negocio_id, tipo, status, titulo)
values ('11111111-1111-4111-8111-111111111111',
        '44444444-4444-4444-8444-444444444444',
        'plano_negocio', 'validado_com_cliente', 'Plano de Negócio Fictício');

\echo '--- higiene consertada, rodada 3'
select regra, criticidade, novos, ja_abertos, resolvidos, situacao
  from valor.avaliar_alertas('11111111-1111-4111-8111-111111111111');

\echo '--- os alertas continuam na tabela, carimbados'
select r.codigo as regra, a.criticidade, a.status,
       (a.resolvido_em is not null) as tem_carimbo,
       a.nota_resolucao
  from valor.alertas a
  join valor.regras_alerta r on r.id = a.regra_id
 where a.inquilino_id = '11111111-1111-4111-8111-111111111111'
 order by r.ordem;

\echo ''
\echo '====================================================================='
\echo 'PROVA 6 · automações rodam e deixam log, e a regra sem tabela é adiada'
\echo '====================================================================='

select automacao, resultado, afetados, mensagem
  from valor.executar_automacoes('11111111-1111-4111-8111-111111111111');

select a.codigo, e.resultado, e.registros_afetados, e.mensagem, (e.erro is null) as sem_erro
  from valor.execucoes_automacao e
  join valor.automacoes a on a.id = e.automacao_id
 where e.inquilino_id = '11111111-1111-4111-8111-111111111111'
 order by a.codigo;


\echo ''
\echo '====================================================================='
\echo 'PROVA 7 · regra montada na tela em jsonb, e regra adiada por tabela ausente'
\echo '====================================================================='

insert into valor.regras_alerta
  (inquilino_id, codigo, nome, descricao, entidade_alvo, tipo_condicao, condicao_jsonb,
   criticidade, canal, destinatario_perfil, ordem)
values ('11111111-1111-4111-8111-111111111111', 'conta_sem_tier_confirmado',
        'Conta sem tier confirmado',
        'Regra declarativa, montada na tela, sem uma linha de sql escrita à mão.',
        'contas', 'jsonb',
        $json$ {"tabela": "contas",
                "chave": "id",
                "mensagem": "Conta com tier ainda não confirmado por gente",
                "criticidade": "amarelo",
                "filtros": [{"coluna": "tier_confirmado_em", "operador": "nulo"},
                            {"coluna": "arquivado_em",       "operador": "nulo"}]} $json$::jsonb,
        'amarelo', 'painel', 'lider', 80);

insert into valor.regras_alerta
  (inquilino_id, codigo, nome, descricao, entidade_alvo, tipo_condicao, condicao_sql,
   tabelas_requeridas, criticidade, ordem)
values ('11111111-1111-4111-8111-111111111111', 'demonstracao_de_regra_adiada',
        'Regra que depende de tabela futura',
        'Existe só para provar que a rodada adia a regra em vez de quebrar.',
        'historico_fases', 'sql',
        $sql$ select h.inquilino_id, h.id as entidade_chave,
                     'nunca avaliada'::text as mensagem,
                     'verde'::valor.criticidade as criticidade,
                     '{}'::jsonb as detalhe
                from valor.historico_fases h
               where ($1::uuid is null or h.inquilino_id = $1::uuid) $sql$,
        array['valor.historico_fases'], 'verde', 90);

\echo '--- o sql que o banco monta a partir da condição declarativa'
select valor.montar_sql_condicao(condicao_jsonb) as sql_gerado
  from valor.regras_alerta
 where codigo = 'conta_sem_tier_confirmado'
   and inquilino_id = '11111111-1111-4111-8111-111111111111';

\echo '--- rodada 4: a declarativa dispara, a que depende de tabela ausente é adiada'
select regra, criticidade, novos, ja_abertos, resolvidos, situacao
  from valor.avaliar_alertas('11111111-1111-4111-8111-111111111111')
 where regra in ('conta_sem_tier_confirmado', 'demonstracao_de_regra_adiada');

select r.codigo as regra, a.criticidade, a.status, a.mensagem
  from valor.alertas a
  join valor.regras_alerta r on r.id = a.regra_id
 where r.codigo = 'conta_sem_tier_confirmado'
   and a.inquilino_id = '11111111-1111-4111-8111-111111111111';

\echo ''
\echo '====================================================================='
\echo 'PROVA 8 · contrato vencendo e negócio de renovação aberto pela automação'
\echo '====================================================================='

insert into valor.contratos (
  inquilino_id, conta_id, negocio_id, numero, titulo, modalidade, nivel, situacao,
  assinado, assinado_em, vigencia_inicio, vigencia_fim, valor_total)
values ('11111111-1111-4111-8111-111111111111',
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
        'CT-FICCAO-001', 'Contrato Fictício Alfa', 'recorrente', 'n1', 'vigente',
        true, current_date - 320, current_date - 320, current_date + 45, 300000.00);

\echo '--- rodada 5: o aviso de contrato vencendo'
select regra, criticidade, novos, ja_abertos, resolvidos, situacao
  from valor.avaliar_alertas('11111111-1111-4111-8111-111111111111')
 where regra = 'contrato_vencendo';

select r.codigo as regra, a.criticidade, a.status, a.mensagem
  from valor.alertas a
  join valor.regras_alerta r on r.id = a.regra_id
 where r.codigo = 'contrato_vencendo'
   and a.inquilino_id = '11111111-1111-4111-8111-111111111111';

\echo '--- a automação abre o negócio de renovação, a 90 dias do fim'
select automacao, resultado, afetados, mensagem
  from valor.executar_automacoes('11111111-1111-4111-8111-111111111111')
 where automacao = 'criar_negocios_renovacao';

select titulo, fase, origem, data_decisao_cliente
  from valor.negocios
 where inquilino_id = '11111111-1111-4111-8111-111111111111'
   and fase = 7;


\echo ''
\echo '====================================================================='
\echo 'PROVA 9 · o parceiro não roda a cobrança interna da casa'
\echo '====================================================================='

select set_config('app.perfil', 'parceiro', true);
do $$
begin
  perform valor.avaliar_alertas('11111111-1111-4111-8111-111111111111');
  raise exception 'FALHA: o parceiro rodou a avaliação de alertas.';
exception
  when insufficient_privilege then
    raise notice 'barrado como esperado: %', sqlerrm;
end;
$$;
do $$
begin
  perform valor.executar_automacoes('11111111-1111-4111-8111-111111111111');
  raise exception 'FALHA: o parceiro rodou as automações.';
exception
  when insufficient_privilege then
    raise notice 'barrado como esperado: %', sqlerrm;
end;
$$;
select set_config('app.perfil', 'admin_master', true);

reset role;
rollback;

\echo ''
\echo 'Prova encerrada com rollback. O banco voltou ao estado anterior.'
