-- Teste de regressão · forecast por artefato, higiene do funil e os painéis
-- Dono: agente de painéis. Nenhum outro agente altera este arquivo.
--
-- Como rodar, num banco onde as migrações já aplicaram:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d fab_pai -f testes/paineis.sql
--
-- O teste inteiro vive dentro de uma transação e desfaz tudo no final. Pode
-- rodar quantas vezes quiser, no mesmo banco, sem deixar resíduo.
--
-- Todo dado aqui é fictício, com valores redondos inventados. Nenhuma conta,
-- nenhum contrato, nenhum telefone e nenhum endereço de cliente de verdade.
--
-- A carteira fictícia, com cinco negócios no pipeline:
--   Contrato de Valor validado    400000,00   compromisso   higiene inteira
--   Plano de Trabalho validado    300000,00   possível      higiene inteira
--   Plano de Negócio validado     200000,00   aberto        higiene inteira
--   sem próximo passo, parado     100000,00   fora          quebra 2 invariantes
--   sem o artefato da fase 1       50000,00   fora          quebra 1 invariante
--   pipeline declarado           1050000,00
--   pipeline auditado             900000,00
--   valor travado                 150000,00
-- E dez negócios já decididos, sendo 3 ganhos, 5 perdidos e 2 vencidos sem o
-- cliente decidir. A não decisão entra no denominador: a taxa de ganho é
-- 3 dividido por 10, e a cobertura necessária é 10 dividido por 3.

\set ON_ERROR_STOP on
\pset border 2
\pset null 'nulo'

begin;

-- A sessão que semeia é a do líder, porque a apuração da comissão no
-- recebimento da parcela é privativa de quem cuida do dinheiro.
select set_config('app.inquilino_id', 'bbbbbbbb-0000-4000-8000-000000000001', true) as ignorado;
select set_config('app.usuario_id',   'bbbbbbbb-0000-4000-8000-000000000011', true) as ignorado;
select set_config('app.perfil',       'lider', true) as ignorado;
select set_config('app.parceiro_id',  '', true) as ignorado;

-- ------------------------------------------------------------ dados fictícios

insert into valor.inquilinos (id, nome, apelido) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'Inquilino de Teste dos Painéis', 'teste-paineis');

insert into valor.usuarios (id, inquilino_id, email, nome, perfil) values
  ('bbbbbbbb-0000-4000-8000-000000000011', 'bbbbbbbb-0000-4000-8000-000000000001',
   'lider@exemplo.invalido', 'Pessoa Líder', 'lider'),
  ('bbbbbbbb-0000-4000-8000-000000000012', 'bbbbbbbb-0000-4000-8000-000000000001',
   'gerente@exemplo.invalido', 'Pessoa Gerente de Contas', 'gerente_contas'),
  ('bbbbbbbb-0000-4000-8000-000000000013', 'bbbbbbbb-0000-4000-8000-000000000001',
   'conselheiro@exemplo.invalido', 'Pessoa Conselheiro', 'conselheiro'),
  ('bbbbbbbb-0000-4000-8000-000000000014', 'bbbbbbbb-0000-4000-8000-000000000001',
   'parceiro.alfa@exemplo.invalido', 'Pessoa Parceiro Alfa', 'parceiro'),
  ('bbbbbbbb-0000-4000-8000-000000000015', 'bbbbbbbb-0000-4000-8000-000000000001',
   'parceiro.beta@exemplo.invalido', 'Pessoa Parceiro Beta', 'parceiro');

insert into valor.parceiros (id, inquilino_id, nome, tipo, status, credenciado_em) values
  ('bbbbbbbb-0000-4000-8000-000000000021', 'bbbbbbbb-0000-4000-8000-000000000001',
   'Parceiro Alfa de Teste', 'indicador', 'ativo', current_date - 400),
  ('bbbbbbbb-0000-4000-8000-000000000022', 'bbbbbbbb-0000-4000-8000-000000000001',
   'Parceiro Beta de Teste', 'indicador', 'ativo', current_date - 400);

insert into valor.parceiros_usuarios (inquilino_id, parceiro_id, usuario_id, principal) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000021',
   'bbbbbbbb-0000-4000-8000-000000000014', true),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000022',
   'bbbbbbbb-0000-4000-8000-000000000015', true);

insert into valor.ofertas (id, inquilino_id, codigo, nome, familia, modalidade, gera_turma) values
  ('bbbbbbbb-0000-4000-8000-000000000031', 'bbbbbbbb-0000-4000-8000-000000000001',
   'teste-conselho', 'Conselho de Valor dedicado', 'Programas de Valor', 'recorrente', true);

insert into valor.contas (id, inquilino_id, nome, gerente_contas_id, tier, prioridade,
                          power_of_x, eh_cliente, eh_prospecto) values
  ('bbbbbbbb-0000-4000-8000-000000000041', 'bbbbbbbb-0000-4000-8000-000000000001',
   'Conta Alfa de Teste',  'bbbbbbbb-0000-4000-8000-000000000012', 't1', 1, 3, true,  false),
  ('bbbbbbbb-0000-4000-8000-000000000042', 'bbbbbbbb-0000-4000-8000-000000000001',
   'Conta Beta de Teste',  'bbbbbbbb-0000-4000-8000-000000000012', 't2', 2, 1, false, true),
  ('bbbbbbbb-0000-4000-8000-000000000043', 'bbbbbbbb-0000-4000-8000-000000000001',
   'Conta Gama de Teste',  'bbbbbbbb-0000-4000-8000-000000000012', 't3', 3, 0, false, true),
  ('bbbbbbbb-0000-4000-8000-000000000044', 'bbbbbbbb-0000-4000-8000-000000000001',
   'Conta Delta de Teste', 'bbbbbbbb-0000-4000-8000-000000000012', 't3', 3, 0, false, true);

-- ---------------------------------------------------------- pipeline fictício
-- Toda decisão do cliente cai no mesmo dia, cinco dias à frente, para o teste
-- não depender da virada de trimestre nem da virada de ano.

insert into valor.negocios
  (id, inquilino_id, conta_id, oferta_id, parceiro_id, titulo, fase, valor_total,
   data_decisao_cliente, proximo_passo, proximo_passo_data, proximo_passo_responsavel,
   ultima_interacao, entrou_na_fase_em) values

  ('bbbbbbbb-0000-4000-8000-000000000051', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000041', 'bbbbbbbb-0000-4000-8000-000000000031',
   'bbbbbbbb-0000-4000-8000-000000000021',
   'Negócio com Contrato de Valor validado', 4, 400000.00,
   current_date + 5, 'Assinatura do Contrato de Valor', current_date + 2,
   'bbbbbbbb-0000-4000-8000-000000000012', current_date, current_date - 20),

  ('bbbbbbbb-0000-4000-8000-000000000052', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000042', 'bbbbbbbb-0000-4000-8000-000000000031', null,
   'Negócio com Plano de Trabalho validado', 3, 300000.00,
   current_date + 5, 'Reunião de Conexão de Valor', current_date + 3,
   'bbbbbbbb-0000-4000-8000-000000000012', current_date, current_date - 15),

  ('bbbbbbbb-0000-4000-8000-000000000053', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000043', 'bbbbbbbb-0000-4000-8000-000000000031', null,
   'Negócio com Plano de Negócio validado', 2, 200000.00,
   current_date + 5, 'Aprofundar o diagnóstico', current_date + 4,
   'bbbbbbbb-0000-4000-8000-000000000012', current_date - 5, current_date - 10),

  -- Sem próximo passo e sem interação há 60 dias. Reprova em duas invariantes,
  -- e só em duas: a decisão está no futuro e o artefato da fase 2 existe, ainda
  -- que em rascunho, que é o bastante para a invariante de registro.
  ('bbbbbbbb-0000-4000-8000-000000000054', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000044', 'bbbbbbbb-0000-4000-8000-000000000031', null,
   'Negócio parado sem próximo passo', 2, 100000.00,
   current_date + 5, null, null, null, current_date - 60, current_date - 60),

  -- Falta o Plano de Conta, o artefato da fase 1. Reprova só nessa invariante.
  ('bbbbbbbb-0000-4000-8000-000000000055', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000044', 'bbbbbbbb-0000-4000-8000-000000000031', null,
   'Negócio sem o artefato da fase', 1, 50000.00,
   current_date + 5, 'Montar o Plano de Conta', current_date + 6,
   'bbbbbbbb-0000-4000-8000-000000000012', current_date, current_date - 5);

-- O negócio de renovação da Conta Alfa, na fase 7. Fica fora do pipeline das
-- fases 1 a 4 e fora da higiene, e aparece amarrado ao contrato em curso.
insert into valor.negocios
  (id, inquilino_id, conta_id, oferta_id, titulo, fase, origem,
   data_decisao_cliente, entrou_na_fase_em) values
  ('bbbbbbbb-0000-4000-8000-000000000056', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000041', 'bbbbbbbb-0000-4000-8000-000000000031',
   'Renovação do contrato da Conta Alfa de Teste', 7, 'base_instalada',
   current_date + 45, current_date);

-- Dez negócios já decididos, com dias na fase de 10 em 10, para a mediana da
-- fase de arquivo fechar em 55 dias e o limite sugerido virar 110.
insert into valor.negocios
  (id, inquilino_id, conta_id, parceiro_id, titulo, fase, valor_total,
   desfecho, data_desfecho, entrou_na_fase_em)
select
  ('bbbbbbbb-0000-4000-8000-0000000000' || (60 + g)::text)::uuid,
  'bbbbbbbb-0000-4000-8000-000000000001',
  -- O único negócio do parceiro Beta fica numa conta só dele, para o teste de
  -- isolamento entre parceiros não se confundir com a carteira do parceiro Alfa.
  case when g = 1 then 'bbbbbbbb-0000-4000-8000-000000000043'::uuid
       else 'bbbbbbbb-0000-4000-8000-000000000041'::uuid end,
  case when g = 1 then 'bbbbbbbb-0000-4000-8000-000000000022'::uuid end,
  'Negócio decidido número ' || g::text,
  9, 10000.00,
  (case when g <= 3 then 'concluido'
        when g <= 8 then 'perdido'
        else 'vencido' end)::valor.desfecho_negocio,
  current_date - 200 + (g * 10),
  current_date - 200
from generate_series(1, 10) as g;

insert into valor.papeis_negocio
  (inquilino_id, negocio_id, usuario_id, papel, entrou_na_fase, principal)
select 'bbbbbbbb-0000-4000-8000-000000000001', n.id,
       'bbbbbbbb-0000-4000-8000-000000000012', 'gerente_contas', 1, true
  from valor.negocios n
 where n.inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
   and n.fase between 1 and 7;

insert into valor.papeis_negocio
  (inquilino_id, negocio_id, usuario_id, papel, entrou_na_fase, principal) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000051',
   'bbbbbbbb-0000-4000-8000-000000000013', 'conselheiro', 3, false);

-- ------------------------------------------------------------------ artefatos
-- Só validado_com_cliente conta para o forecast. Pronto por dentro não é
-- compromisso do cliente, e por isso o rascunho da fase 2 não muda a categoria.

insert into valor.artefatos
  (inquilino_id, negocio_id, tipo, status, titulo, validado_em) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000051',
   'contrato_valor', 'validado_com_cliente', 'Contrato de Valor', current_date - 3),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000051',
   'plano_trabalho', 'validado_com_cliente', 'Plano de Trabalho', current_date - 20),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000052',
   'plano_trabalho', 'validado_com_cliente', 'Plano de Trabalho', current_date - 6),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000053',
   'plano_negocio',  'validado_com_cliente', 'Plano de Negócio', current_date - 9),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000054',
   'plano_negocio',  'rascunho',            'Plano de Negócio em rascunho', null);

-- ------------------------------------------------------- contrato e comissão

insert into valor.percentuais_padrao
  (inquilino_id, escopo, rotulo, imposto_percentual,
   comissao_vendedor_percentual, comissao_parceiro_percentual, vigencia_inicio) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'inquilino', 'Padrão da casa',
   15.0000, 10.0000, 10.0000, current_date - 400);

insert into valor.contratos
  (id, inquilino_id, conta_id, negocio_id, oferta_id, numero, titulo, modalidade, nivel,
   situacao, assinado, assinado_em, vigencia_inicio, vigencia_fim, valor_mensal,
   indexador_reajuste, renovacao_automatica, aviso_previo_dias) values
  ('bbbbbbbb-0000-4000-8000-000000000071', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000041', 'bbbbbbbb-0000-4000-8000-000000000051',
   'bbbbbbbb-0000-4000-8000-000000000031', 'TESTE-PAINEL-0001', 'Contrato de teste',
   'recorrente', 'n1', 'vigente', true, current_date - 300, current_date - 300,
   current_date + 45, 10000.00, 'IPCA', true, 30);

insert into valor.contratos_conselheiros
  (inquilino_id, contrato_id, usuario_id, modelo, percentual, vigencia_inicio) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000071',
   'bbbbbbbb-0000-4000-8000-000000000013', 'percentual_contrato', 20.0000, current_date - 300);

insert into valor.parcelas
  (inquilino_id, contrato_id, numero, competencia, vencimento, valor_bruto, status, recebida_em) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000071',
   1, date_trunc('month', current_date)::date, date_trunc('month', current_date)::date + 9,
   10000.00, 'recebida', date_trunc('month', current_date)::date + 9);

-- --------------------------------------------------------------- indicações

insert into valor.indicacoes
  (id, inquilino_id, parceiro_id, conta_id, conta_indicada_nome, contato_nome,
   contexto, status, aceita_em, prazo_protecao_dias, negocio_id) values
  ('bbbbbbbb-0000-4000-8000-000000000081', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000021', 'bbbbbbbb-0000-4000-8000-000000000041',
   'Conta Alfa de Teste', 'Contato Fictício Alfa',
   'Indicação fictícia do parceiro Alfa', 'convertida', current_date - 100, 90,
   'bbbbbbbb-0000-4000-8000-000000000051'),
  ('bbbbbbbb-0000-4000-8000-000000000082', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000022', null,
   'Conta Fictícia do Parceiro Beta', 'Contato Fictício Beta',
   'Indicação fictícia do parceiro Beta', 'registrada', null, 90, null);

-- ------------------------------------------------------------- entrega e BRM

insert into valor.programas
  (id, inquilino_id, oferta_id, contrato_id, negocio_id, conta_id, codigo, nome,
   modalidade, status, responsavel_id, data_inicio) values
  ('bbbbbbbb-0000-4000-8000-000000000091', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000031', 'bbbbbbbb-0000-4000-8000-000000000071',
   'bbbbbbbb-0000-4000-8000-000000000051', 'bbbbbbbb-0000-4000-8000-000000000041',
   'PROG-TESTE-01', 'Programa de teste da Conta Alfa', 'dedicada', 'ativo',
   'bbbbbbbb-0000-4000-8000-000000000013', current_date - 200);

insert into valor.turmas
  (id, inquilino_id, programa_id, contrato_id, negocio_id, codigo, nome, status,
   cadencia, formato, cadeiras_minimas, cadeiras_maximas, facilitador_id, data_inicio) values
  ('bbbbbbbb-0000-4000-8000-000000000092', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000091', 'bbbbbbbb-0000-4000-8000-000000000071',
   'bbbbbbbb-0000-4000-8000-000000000051', 'TURMA-TESTE-01', 'Turma de teste da Conta Alfa',
   'planejada', 'mensal', 'hibrido', 1, 8,
   'bbbbbbbb-0000-4000-8000-000000000013', current_date - 200);

insert into valor.turmas_contas
  (inquilino_id, turma_id, conta_id, contrato_id, cadeiras_contratadas, eh_anfitria, entrou_em) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000092',
   'bbbbbbbb-0000-4000-8000-000000000041', 'bbbbbbbb-0000-4000-8000-000000000071',
   4, true, current_date - 200);

insert into valor.participantes
  (inquilino_id, turma_id, conta_id, contrato_id, nome, papel, cadeira, entrou_em, status) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000092',
   'bbbbbbbb-0000-4000-8000-000000000041', 'bbbbbbbb-0000-4000-8000-000000000071',
   'Participante Fictício Um', 'socio', 1, current_date - 200, 'ativo'),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000092',
   'bbbbbbbb-0000-4000-8000-000000000041', 'bbbbbbbb-0000-4000-8000-000000000071',
   'Participante Fictício Dois', 'executivo', 2, current_date - 200, 'ativo');

insert into valor.encontros
  (id, inquilino_id, turma_id, numero, tema, data_prevista, data_realizada, formato,
   status, conselheiro_id, hora_prevista_inicio, hora_prevista_fim) values
  ('bbbbbbbb-0000-4000-8000-000000000093', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000092', 1, 'Encontro já realizado',
   current_date - 10, current_date - 10, 'online', 'realizado',
   'bbbbbbbb-0000-4000-8000-000000000013', time '09:00', time '11:00'),
  ('bbbbbbbb-0000-4000-8000-000000000094', 'bbbbbbbb-0000-4000-8000-000000000001',
   'bbbbbbbb-0000-4000-8000-000000000092', 2, 'Encontro da semana que vem',
   current_date + 3, null, 'hibrido', 'previsto',
   'bbbbbbbb-0000-4000-8000-000000000013', time '09:00', time '11:00');

insert into valor.atas
  (inquilino_id, conta_id, turma_id, encontro_id, numero, titulo, data_reuniao, status) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000041',
   'bbbbbbbb-0000-4000-8000-000000000092', 'bbbbbbbb-0000-4000-8000-000000000093',
   1, 'Ata do encontro já realizado', current_date - 10, 'rascunho');

insert into valor.pendencias
  (inquilino_id, conta_id, turma_id, encontro_id, origem, descricao,
   dono_usuario_id, prazo, status) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000041',
   'bbbbbbbb-0000-4000-8000-000000000092', 'bbbbbbbb-0000-4000-8000-000000000093',
   'deliberacao', 'Pendência fictícia já vencida',
   'bbbbbbbb-0000-4000-8000-000000000013', current_date - 5, 'aberta'),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000041',
   'bbbbbbbb-0000-4000-8000-000000000092', 'bbbbbbbb-0000-4000-8000-000000000093',
   'deliberacao', 'Pendência fictícia ainda no prazo',
   'bbbbbbbb-0000-4000-8000-000000000013', current_date + 10, 'aberta');

insert into valor.pautas
  (inquilino_id, conta_id, turma_id, numero, titulo, data_reuniao, hora_inicio, status) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000041',
   'bbbbbbbb-0000-4000-8000-000000000092', 1, 'Reunião de conselho da semana',
   current_date + 5, time '14:00', 'publicada');

insert into valor.interacoes
  (inquilino_id, conta_id, negocio_id, usuario_id, canal, ocorrida_em, assunto) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000041',
   'bbbbbbbb-0000-4000-8000-000000000051', 'bbbbbbbb-0000-4000-8000-000000000012',
   'reuniao_online', now() - interval '2 days', 'Conversa fictícia com a Conta Alfa');

-- ------------------------------------------------------- atividades e alertas

insert into valor.atividades
  (inquilino_id, titulo, estado, responsavel_id, prazo, agendada_para, conta_id, negocio_id) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'Atividade fictícia vencida', 'proxima_acao',
   'bbbbbbbb-0000-4000-8000-000000000012', current_date - 3, null,
   null, 'bbbbbbbb-0000-4000-8000-000000000054'),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'Atividade fictícia da própria casa', 'proxima_acao',
   'bbbbbbbb-0000-4000-8000-000000000011', null, null, null, null),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'Compromisso fictício desta semana', 'agendada',
   'bbbbbbbb-0000-4000-8000-000000000012', null,
   (current_date + 2)::timestamptz + interval '15 hours',
   'bbbbbbbb-0000-4000-8000-000000000041', null);

-- As regras abaixo existem só para o alerta ter de onde pendurar. A condição
-- nunca devolve linha, então nada aqui dispara avaliação de verdade.
insert into valor.regras_alerta
  (id, inquilino_id, codigo, nome, descricao, entidade_alvo, tipo_condicao, condicao_sql,
   ativa, criticidade, canal, destinatario_perfil) values
  ('bbbbbbbb-0000-4000-8000-0000000000a1', 'bbbbbbbb-0000-4000-8000-000000000001',
   'teste_negocio_parado', 'Negócio parado', 'Regra fictícia para o teste do painel',
   'negocios', 'sql', 'select null::uuid, null::uuid, null::text, null::valor.criticidade, null::jsonb where false and $1::uuid is null',
   false, 'vermelho', 'painel', 'gerente_contas'),
  ('bbbbbbbb-0000-4000-8000-0000000000a2', 'bbbbbbbb-0000-4000-8000-000000000001',
   'teste_contrato_vencendo', 'Contrato vencendo', 'Regra fictícia para o teste do painel',
   'contratos', 'sql', 'select null::uuid, null::uuid, null::text, null::valor.criticidade, null::jsonb where false and $1::uuid is null',
   false, 'amarelo', 'painel', 'lider');

insert into valor.alertas
  (inquilino_id, regra_id, entidade, entidade_chave, criticidade, mensagem, status,
   destinatario_id, disparado_em) values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-0000000000a1',
   'negocios', 'bbbbbbbb-0000-4000-8000-000000000054', 'vermelho',
   'Negócio parado há 60 dias, acima do limite de 30 dias', 'aberto',
   null, now() - interval '2 days'),
  ('bbbbbbbb-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-0000000000a2',
   'contratos', 'bbbbbbbb-0000-4000-8000-000000000071', 'amarelo',
   'Contrato vence em 45 dias', 'aberto',
   'bbbbbbbb-0000-4000-8000-000000000011', now() - interval '1 day');

\echo ''
\echo '=================================================================='
\echo 'TESTE 1 · a categoria sai do artefato validado, nunca da probabilidade'
\echo '=================================================================='

select titulo, fase, fase_rotulo, valor_considerado,
       categoria, artefato_que_sustenta, artefato_validado_em
from valor.vw_negocios_forecast
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by fase desc, titulo;

do $$
declare
  v_categoria    valor.forecast_categoria;
  v_artefato     valor.tipo_artefato;
  v_linhas       integer;
begin
  select categoria, artefato_que_sustenta into v_categoria, v_artefato
    from valor.vw_negocios_forecast
   where negocio_id = 'bbbbbbbb-0000-4000-8000-000000000051';
  if v_categoria <> 'compromisso' then
    raise exception 'O negócio com Contrato de Valor validado precisa ser compromisso. Veio %.', v_categoria;
  end if;
  if v_artefato <> 'contrato_valor' then
    raise exception 'O artefato que sustenta o compromisso precisa ser o Contrato de Valor. Veio %.', v_artefato;
  end if;

  select categoria, artefato_que_sustenta into v_categoria, v_artefato
    from valor.vw_negocios_forecast
   where negocio_id = 'bbbbbbbb-0000-4000-8000-000000000052';
  if v_categoria <> 'possivel' then
    raise exception 'O negócio com Plano de Trabalho validado precisa ser possível. Veio %.', v_categoria;
  end if;
  if v_artefato <> 'plano_trabalho' then
    raise exception 'O artefato que sustenta o possível precisa ser o Plano de Trabalho. Veio %.', v_artefato;
  end if;

  select categoria into v_categoria from valor.vw_negocios_forecast
   where negocio_id = 'bbbbbbbb-0000-4000-8000-000000000053';
  if v_categoria <> 'aberto' then
    raise exception 'O negócio com Plano de Negócio validado precisa ser aberto. Veio %.', v_categoria;
  end if;

  -- O rascunho da fase 2 não vale como compromisso do cliente.
  select categoria into v_categoria from valor.vw_negocios_forecast
   where negocio_id = 'bbbbbbbb-0000-4000-8000-000000000054';
  if v_categoria <> 'fora' then
    raise exception 'Artefato em rascunho não sustenta forecast. Esperava fora e veio %.', v_categoria;
  end if;

  select count(*) into v_linhas from valor.vw_negocios_forecast
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_linhas <> 6 then
    raise exception 'Esperava 6 negócios ativos na visão de forecast e vieram %.', v_linhas;
  end if;

  raise notice 'TESTE 1 passou: Contrato de Valor validado vira compromisso, Plano de Trabalho vira possível, Plano de Negócio vira aberto, rascunho fica fora.';
end $$;

\echo ''
\echo 'Valor e contagem por categoria, somando todos os períodos de decisão:'
select categoria, categoria_rotulo, sum(negocios) as negocios, sum(valor) as valor
from valor.vw_forecast_por_categoria
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
group by categoria, categoria_rotulo
order by min(ordem_categoria);

\echo ''
\echo 'O mesmo forecast quebrado pelo período da decisão do cliente:'
select periodo_codigo, periodo_rotulo, categoria, negocios, valor, valor_auditado
from valor.vw_forecast_por_categoria
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by periodo_codigo, ordem_categoria;

do $$
declare
  v_compromisso numeric;
  v_possivel    numeric;
  v_aberto      numeric;
  v_fora        numeric;
begin
  select coalesce(sum(valor) filter (where categoria = 'compromisso'), 0),
         coalesce(sum(valor) filter (where categoria = 'possivel'), 0),
         coalesce(sum(valor) filter (where categoria = 'aberto'), 0),
         coalesce(sum(valor) filter (where categoria = 'fora'), 0)
    into v_compromisso, v_possivel, v_aberto, v_fora
    from valor.vw_forecast_por_categoria
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

  if v_compromisso <> 400000.00 then
    raise exception 'Compromisso errado. Esperava 400000,00 e veio %.', v_compromisso;
  end if;
  if v_possivel <> 300000.00 then
    raise exception 'Possível errado. Esperava 300000,00 e veio %.', v_possivel;
  end if;
  if v_aberto <> 200000.00 then
    raise exception 'Aberto errado. Esperava 200000,00 e veio %.', v_aberto;
  end if;
  if v_fora <> 150000.00 then
    raise exception 'Fora errado. Esperava 150000,00 e veio %.', v_fora;
  end if;

  raise notice 'TESTE 1 passou também no agregado: compromisso 400000,00 · possível 300000,00 · aberto 200000,00 · fora 150000,00.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 2 · pipeline declarado maior que o auditado, e o valor travado'
\echo '=================================================================='

select negocios_declarados, pipeline_declarado,
       negocios_auditados,  pipeline_auditado,
       negocios_travados,   valor_travado,
       percentual_valor_auditado
from valor.vw_pipeline_higiene
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

\echo ''
\echo 'A contagem de cada invariante quebrada e o valor que cada uma trava:'
select quebra_proximo_passo,    travado_por_proximo_passo,
       quebra_decisao_no_futuro, travado_por_decisao_no_futuro,
       quebra_interacao_recente, travado_por_interacao_recente,
       quebra_artefato_da_fase,  travado_por_artefato_da_fase
from valor.vw_pipeline_higiene
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

\echo ''
\echo 'Os negócios que travam o pipeline, um a um:'
select titulo, fase, valor_considerado, invariantes_quebradas
from valor.vw_negocios_forecast
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
  and exige_higiene and not na_higiene
order by valor_considerado desc;

do $$
declare
  v_h       valor.vw_pipeline_higiene%rowtype;
  v_soma    numeric(14,2);
begin
  select * into v_h from valor.vw_pipeline_higiene
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

  select coalesce(sum(valor_considerado), 0) into v_soma
    from valor.vw_negocios_forecast
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
     and exige_higiene and not na_higiene;

  if v_h.pipeline_declarado <> 1050000.00 then
    raise exception 'Pipeline declarado errado. Esperava 1050000,00 e veio %.', v_h.pipeline_declarado;
  end if;
  if v_h.pipeline_auditado <> 900000.00 then
    raise exception 'Pipeline auditado errado. Esperava 900000,00 e veio %.', v_h.pipeline_auditado;
  end if;
  if not (v_h.pipeline_declarado > v_h.pipeline_auditado) then
    raise exception 'O pipeline declarado precisa ser maior que o auditado nesta carteira.';
  end if;
  if v_h.valor_travado <> 150000.00 then
    raise exception 'Valor travado errado. Esperava 150000,00 e veio %.', v_h.valor_travado;
  end if;
  if v_h.valor_travado <> v_soma then
    raise exception 'O valor travado não bate com a soma dos negócios que quebram invariante. Visão % e soma %.',
      v_h.valor_travado, v_soma;
  end if;
  if v_h.pipeline_declarado - v_h.pipeline_auditado <> v_h.valor_travado then
    raise exception 'A diferença entre declarado e auditado precisa ser o valor travado.';
  end if;
  if v_h.negocios_declarados <> 5 or v_h.negocios_auditados <> 3 or v_h.negocios_travados <> 2 then
    raise exception 'Contagem errada. Esperava 5 declarados, 3 auditados e 2 travados. Vieram %, % e %.',
      v_h.negocios_declarados, v_h.negocios_auditados, v_h.negocios_travados;
  end if;
  if v_h.quebra_proximo_passo <> 1 or v_h.quebra_decisao_no_futuro <> 0
     or v_h.quebra_interacao_recente <> 1 or v_h.quebra_artefato_da_fase <> 1 then
    raise exception 'Contagem de invariante quebrada errada: % · % · % · %.',
      v_h.quebra_proximo_passo, v_h.quebra_decisao_no_futuro,
      v_h.quebra_interacao_recente, v_h.quebra_artefato_da_fase;
  end if;
  if v_h.travado_por_proximo_passo <> 100000.00
     or v_h.travado_por_interacao_recente <> 100000.00
     or v_h.travado_por_artefato_da_fase <> 50000.00 then
    raise exception 'Valor travado por invariante errado: % · % · %.',
      v_h.travado_por_proximo_passo, v_h.travado_por_interacao_recente,
      v_h.travado_por_artefato_da_fase;
  end if;
  if v_h.percentual_valor_auditado <> 85.7 then
    raise exception 'Percentual de valor auditado errado. Esperava 85,7 e veio %.', v_h.percentual_valor_auditado;
  end if;

  raise notice 'TESTE 2 passou: declarado 1050000,00 · auditado 900000,00 · travado 150000,00, e o travado é a soma exata dos dois negócios fora da higiene.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 3 · o negócio sem próximo passo e parado há 60 dias'
\echo '=================================================================='

select titulo, fase, dias_parado, limite_dias, esta_parado,
       tem_proximo_passo, decisao_no_futuro, interacao_recente, tem_artefato_da_fase,
       quantas_invariantes_quebradas, invariantes_quebradas, dias_ate_decisao
from valor.vw_negocios_forecast
where negocio_id = 'bbbbbbbb-0000-4000-8000-000000000054';

do $$
declare
  v_n valor.vw_negocios_forecast%rowtype;
begin
  select * into v_n from valor.vw_negocios_forecast
   where negocio_id = 'bbbbbbbb-0000-4000-8000-000000000054';

  if v_n.quantas_invariantes_quebradas <> 2 then
    raise exception 'Esperava exatamente 2 invariantes quebradas e vieram %.', v_n.quantas_invariantes_quebradas;
  end if;
  if v_n.tem_proximo_passo then
    raise exception 'O negócio não tem próximo passo, a invariante precisa reprovar.';
  end if;
  if v_n.interacao_recente then
    raise exception 'O negócio está sem interação há 60 dias, a invariante precisa reprovar.';
  end if;
  if not v_n.decisao_no_futuro then
    raise exception 'A data da decisão do cliente está no futuro, esta invariante precisa passar.';
  end if;
  if not v_n.tem_artefato_da_fase then
    raise exception 'O artefato da fase 2 está registrado, esta invariante precisa passar.';
  end if;
  if v_n.dias_parado <> 60 then
    raise exception 'Dias parado errado. Esperava 60 e veio %.', v_n.dias_parado;
  end if;
  if v_n.limite_dias <> 30 then
    raise exception 'Sem histórico de fase, o limite precisa ser o piso de 30 dias. Veio %.', v_n.limite_dias;
  end if;
  if not v_n.esta_parado then
    raise exception 'Com 60 dias parado e limite de 30, o negócio precisa aparecer como parado.';
  end if;
  if v_n.dias_ate_decisao <> 5 then
    raise exception 'Dias até a decisão errado. Esperava 5 e veio %.', v_n.dias_ate_decisao;
  end if;
  if v_n.na_higiene then
    raise exception 'O negócio quebra invariante, não pode aparecer dentro da higiene.';
  end if;

  raise notice 'TESTE 3 passou: 60 dias parado contra um limite de 30, duas invariantes quebradas e duas mantidas.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 4 · cobertura indisponível sem meta, e um número com meta'
\echo '=================================================================='

\echo 'Antes de cadastrar meta nenhuma:'
select escopo, granularidade, periodo_codigo, meta_valor,
       negocios_decididos, negocios_ganhos, negocios_sem_decisao,
       taxa_ganho, cobertura_necessaria, pipeline_necessario, situacao, motivo_indisponivel
from valor.vw_cobertura
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

do $$
declare
  v_c valor.vw_cobertura%rowtype;
  v_linhas integer;
begin
  select count(*) into v_linhas from valor.vw_cobertura
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_linhas <> 1 then
    raise exception 'Sem meta, a visão precisa devolver uma linha por inquilino. Vieram %.', v_linhas;
  end if;

  select * into v_c from valor.vw_cobertura
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_c.situacao <> 'indisponivel' then
    raise exception 'Sem meta cadastrada a situação precisa ser indisponivel. Veio %.', v_c.situacao;
  end if;
  if v_c.meta_valor is not null or v_c.pipeline_necessario is not null
     or v_c.cobertura_atual is not null then
    raise exception 'Sem meta, nenhum número pode sair. Vieram meta %, necessário % e atual %.',
      v_c.meta_valor, v_c.pipeline_necessario, v_c.cobertura_atual;
  end if;
  if v_c.motivo_indisponivel is null then
    raise exception 'A visão precisa dizer por que está indisponível.';
  end if;

  raise notice 'TESTE 4 passou na primeira metade: sem meta cadastrada a cobertura é indisponível e nenhum número sai, com o motivo escrito.';
end $$;

\echo ''
\echo 'Cadastrando a meta anual da casa em 3000000,00:'
select valor.gravar_meta('bbbbbbbb-0000-4000-8000-000000000001', 'anual',
                         extract(year from current_date)::integer::text, 3000000.00) as meta_do_ano_corrente;
select valor.gravar_meta('bbbbbbbb-0000-4000-8000-000000000001', 'anual',
                         extract(year from current_date + 5)::integer::text, 3000000.00) as meta_do_ano_da_decisao;

select escopo, granularidade, periodo_codigo, meta_valor,
       negocios_decididos, negocios_ganhos, negocios_perdidos, negocios_sem_decisao,
       taxa_ganho, cobertura_necessaria, pipeline_necessario,
       pipeline_disponivel, cobertura_atual, situacao
from valor.vw_cobertura
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by periodo_codigo;

do $$
declare
  v_c valor.vw_cobertura%rowtype;
begin
  select * into v_c from valor.vw_cobertura
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
     and periodo_codigo = extract(year from current_date + 5)::integer::text;

  if v_c.meta_valor <> 3000000.00 then
    raise exception 'Meta errada. Esperava 3000000,00 e veio %.', v_c.meta_valor;
  end if;
  if v_c.negocios_decididos <> 10 or v_c.negocios_ganhos <> 3
     or v_c.negocios_perdidos <> 5 or v_c.negocios_sem_decisao <> 2 then
    raise exception 'Histórico errado. Esperava 10 decididos, 3 ganhos, 5 perdidos e 2 sem decisão. Vieram %, %, % e %.',
      v_c.negocios_decididos, v_c.negocios_ganhos, v_c.negocios_perdidos, v_c.negocios_sem_decisao;
  end if;
  -- A não decisão fica no denominador: 3 sobre 10, e não 3 sobre 8.
  if v_c.taxa_ganho <> 0.3000 then
    raise exception 'Taxa de ganho errada. Com a não decisão no denominador esperava 0,3000 e veio %.', v_c.taxa_ganho;
  end if;
  if v_c.cobertura_necessaria <> 3.33 then
    raise exception 'Cobertura necessária errada. Esperava 3,33 e veio %.', v_c.cobertura_necessaria;
  end if;
  if v_c.pipeline_necessario <> 9990000.00 then
    raise exception 'Pipeline necessário errado. Esperava 9990000,00 e veio %.', v_c.pipeline_necessario;
  end if;
  if v_c.pipeline_disponivel <> 1050000.00 then
    raise exception 'Pipeline disponível errado. Esperava 1050000,00 e veio %.', v_c.pipeline_disponivel;
  end if;
  if v_c.cobertura_atual <> 0.35 then
    raise exception 'Cobertura atual errada. Esperava 0,35 e veio %.', v_c.cobertura_atual;
  end if;
  if v_c.situacao <> 'insuficiente' then
    raise exception 'Com 1050000,00 de pipeline contra 9990000,00 de necessidade, a situação é insuficiente. Veio %.', v_c.situacao;
  end if;

  raise notice 'TESTE 4 passou na segunda metade: taxa de ganho 0,3000 com a não decisão no denominador, cobertura necessária 3,33, pipeline necessário 9990000,00 contra 1050000,00 disponíveis.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 5 · concentração nos dois maiores e mediana de dias por fase'
\echo '=================================================================='

select negocios_no_pipeline, pipeline_declarado, valor_dos_dois_maiores,
       percentual_nos_dois_maiores, limite_percentual, alarme, leitura
from valor.vw_concentracao
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

\echo ''
select fase, fase_rotulo, artefato_da_fase, negocios_ativos, negocios_no_historico,
       valor_ativo, mediana_dias_na_fase, limite_vigente_dias, limite_sugerido_dias,
       origem_do_limite
from valor.vw_funil_por_fase
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by fase;

do $$
declare
  v_co valor.vw_concentracao%rowtype;
  v_f9 valor.vw_funil_por_fase%rowtype;
  v_f2 valor.vw_funil_por_fase%rowtype;
  v_linhas integer;
begin
  select * into v_co from valor.vw_concentracao
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_co.valor_dos_dois_maiores <> 700000.00 then
    raise exception 'Os dois maiores somam 700000,00. Veio %.', v_co.valor_dos_dois_maiores;
  end if;
  if v_co.percentual_nos_dois_maiores <> 66.7 then
    raise exception 'Concentração errada. Esperava 66,7 por cento e veio %.', v_co.percentual_nos_dois_maiores;
  end if;
  if not v_co.alarme then
    raise exception 'Com 66,7 por cento nos dois maiores, o alarme de concentração precisa acender.';
  end if;

  select count(*) into v_linhas from valor.vw_funil_por_fase
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_linhas <> 9 then
    raise exception 'O funil precisa ter as nove fases do método. Vieram % linhas.', v_linhas;
  end if;

  select * into v_f9 from valor.vw_funil_por_fase
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and fase = 9;
  if v_f9.negocios_no_historico <> 10 then
    raise exception 'A fase de arquivo precisa ter os 10 negócios decididos. Vieram %.', v_f9.negocios_no_historico;
  end if;
  if v_f9.mediana_dias_na_fase <> 55 then
    raise exception 'Mediana da fase de arquivo errada. Esperava 55 dias e veio %.', v_f9.mediana_dias_na_fase;
  end if;
  if v_f9.limite_sugerido_dias <> 110 then
    raise exception 'Com mediana de 55 dias o limite sugerido é 110, duas vezes a mediana. Veio %.', v_f9.limite_sugerido_dias;
  end if;
  if v_f9.origem_do_limite <> 'mediana' then
    raise exception 'Com 10 negócios no histórico a origem do limite é a mediana. Veio %.', v_f9.origem_do_limite;
  end if;

  select * into v_f2 from valor.vw_funil_por_fase
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and fase = 2;
  if v_f2.negocios_ativos <> 2 then
    raise exception 'A fase 2 tem 2 negócios ativos. Vieram %.', v_f2.negocios_ativos;
  end if;
  if v_f2.origem_do_limite <> 'piso' then
    raise exception 'Com amostra abaixo do mínimo a fase 2 fica no piso. Veio %.', v_f2.origem_do_limite;
  end if;
  if v_f2.limite_sugerido_dias <> 30 then
    raise exception 'O piso configurado é 30 dias. Veio %.', v_f2.limite_sugerido_dias;
  end if;

  raise notice 'TESTE 5 passou: concentração de 66,7 por cento em alarme, nove fases no funil, mediana de 55 dias na fase de arquivo virando limite de 110 e fase 2 ainda no piso de 30.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 6 · os painéis da casa, cada um na sessão de quem o usa'
\echo '=================================================================='

select set_config('app.usuario_id', 'bbbbbbbb-0000-4000-8000-000000000012', true) as ignorado;
select set_config('app.perfil',     'gerente_contas', true) as ignorado;

\echo 'Painel do gerente de contas:'
select titulo, fase_rotulo, categoria, valor_considerado, dias_ate_decisao,
       decide_esta_semana, esta_parado, na_higiene, grupo_rotulo
from valor.vw_painel_gerente_contas
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by ordem_grupo, valor_considerado desc;

select set_config('app.usuario_id', 'bbbbbbbb-0000-4000-8000-000000000013', true) as ignorado;
select set_config('app.perfil',     'conselheiro', true) as ignorado;

\echo ''
\echo 'Painel do conselheiro:'
select turma_nome, contas_da_turma, participantes_ativos,
       encontros_realizados, encontros_da_semana, proximo_encontro_em,
       atas_pendentes, atas_atrasadas, pendencias_abertas, pendencias_vencidas,
       remuneracao_modelo, remuneracao_percentual, remuneracao_mes_referencia
from valor.vw_painel_conselheiro where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

select set_config('app.usuario_id', 'bbbbbbbb-0000-4000-8000-000000000011', true) as ignorado;
select set_config('app.perfil',     'lider', true) as ignorado;

\echo ''
\echo 'Painel do dono, o número da casa:'
select pipeline_declarado, pipeline_auditado, valor_travado, percentual_valor_auditado,
       forecast_compromisso, forecast_possivel, forecast_aberto, forecast_fora
from valor.vw_painel_dono where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

select percentual_nos_dois_maiores, concentracao_em_alarme,
       meta_do_periodo, cobertura_necessaria, cobertura_atual, cobertura_situacao,
       faturamento_bruto, margem, margem_percentual,
       contratos_vigentes, receita_mensal_contratada, alertas_vermelhos, alertas_amarelos
from valor.vw_painel_dono where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

\echo ''
\echo 'Alertas abertos, por criticidade, com quem precisa agir:'
select criticidade_rotulo, regra_nome, mensagem, dias_aberto,
       quem_age_nome, quem_age_perfil, conta_nome, negocio_titulo
from valor.vw_alertas_abertos
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by ordem_criticidade, dias_aberto desc;

\echo ''
\echo 'Caixa de entrada, vencidas primeiro:'
select usuario_nome, titulo, estado, prazo, agendada_para, data_referencia,
       situacao_rotulo, dias_de_atraso, conta_nome
from valor.vw_atividades_pendentes
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by ordem, data_referencia nulls last;

\echo ''
\echo 'Contratos em curso, com vencimento e negócio de renovação:'
select numero, conta_nome, situacao, vigencia_fim, dias_para_vencer,
       sinal_de_vencimento, na_janela_de_renovacao, data_limite_aviso_previo,
       tem_negocio_de_renovacao, negocio_renovacao_titulo,
       parcelas_recebidas, valor_recebido
from valor.vw_contratos_em_curso where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';

\echo ''
\echo 'Agenda dos próximos sete dias:'
select tipo_rotulo, titulo, quando_em, hora_inicio, dias_ate, turma_nome, conta_nome
from valor.vw_agenda_da_semana
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by quando_em, hora_inicio nulls last;

\echo ''
\echo 'Saúde da conta:'
select conta_nome, tier_rotulo, power_of_x, nps, contratos_vigentes,
       valor_mensal_vigente, dias_sem_contato, negocios_ativos, pipeline_da_conta,
       alertas_abertos, turmas_ativas, pendencias_vencidas
from valor.vw_saude_da_conta
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by conta_nome;

\echo ''
\echo 'Trabalho da casa separado do trabalho de cliente:'
select escopo_rotulo, tipo, titulo, responsavel_nome, situacao, data_alvo, conta_nome
from valor.vw_trabalho_da_casa
where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
order by escopo, tipo, titulo;

do $$
declare
  v_d  valor.vw_painel_dono%rowtype;
  v_qtd integer;
  v_conselheiro record;
  v_contrato   record;
begin
  -- Painel do gerente de contas.
  perform set_config('app.usuario_id', 'bbbbbbbb-0000-4000-8000-000000000012', true);
  perform set_config('app.perfil',     'gerente_contas', true);

  select count(*) into v_qtd from valor.vw_painel_gerente_contas where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 6 then
    raise exception 'O gerente de contas cuida de 6 negócios nesta carteira. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_gerente_contas where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and grupo = 'decide_esta_semana';
  if v_qtd <> 3 then
    raise exception 'Esperava 3 negócios decidindo nesta semana. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_gerente_contas where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and grupo = 'parado';
  if v_qtd <> 1 then
    raise exception 'Esperava 1 negócio parado. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_gerente_contas where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and grupo = 'fora_da_higiene';
  if v_qtd <> 1 then
    raise exception 'Esperava 1 negócio fora da higiene. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_dono where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 0 then
    raise exception 'O gerente de contas não vê o painel do dono, que carrega margem. Vieram % linhas.', v_qtd;
  end if;

  -- Painel do conselheiro.
  perform set_config('app.usuario_id', 'bbbbbbbb-0000-4000-8000-000000000013', true);
  perform set_config('app.perfil',     'conselheiro', true);

  select * into v_conselheiro from valor.vw_painel_conselheiro where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_conselheiro.turma_id is null then
    raise exception 'O conselheiro precisa enxergar a turma dele.';
  end if;
  if v_conselheiro.encontros_da_semana <> 1 then
    raise exception 'Esperava 1 encontro na semana. Vieram %.', v_conselheiro.encontros_da_semana;
  end if;
  if v_conselheiro.atas_pendentes <> 1 or v_conselheiro.atas_atrasadas <> 1 then
    raise exception 'Esperava 1 ata pendente e 1 atrasada. Vieram % e %.',
      v_conselheiro.atas_pendentes, v_conselheiro.atas_atrasadas;
  end if;
  if v_conselheiro.pendencias_vencidas <> 1 or v_conselheiro.pendencias_abertas <> 2 then
    raise exception 'Esperava 2 pendências abertas e 1 vencida. Vieram % e %.',
      v_conselheiro.pendencias_abertas, v_conselheiro.pendencias_vencidas;
  end if;
  if v_conselheiro.remuneracao_mes_referencia <> 2000.00 then
    raise exception 'Remuneração do conselheiro errada. Esperava 2000,00, que é 20 por cento de 10000,00, e veio %.',
      v_conselheiro.remuneracao_mes_referencia;
  end if;
  select count(*) into v_qtd from valor.vw_painel_dono where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 0 then
    raise exception 'O conselheiro não vê o painel do dono. Vieram % linhas.', v_qtd;
  end if;

  -- Painel do dono.
  perform set_config('app.usuario_id', 'bbbbbbbb-0000-4000-8000-000000000011', true);
  perform set_config('app.perfil',     'lider', true);

  select * into v_d from valor.vw_painel_dono where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_d.pipeline_declarado <> 1050000.00 or v_d.pipeline_auditado <> 900000.00
     or v_d.valor_travado <> 150000.00 then
    raise exception 'Números do painel do dono errados: declarado %, auditado %, travado %.',
      v_d.pipeline_declarado, v_d.pipeline_auditado, v_d.valor_travado;
  end if;
  if v_d.forecast_compromisso <> 400000.00 or v_d.forecast_possivel <> 300000.00
     or v_d.forecast_aberto <> 200000.00 or v_d.forecast_fora <> 150000.00 then
    raise exception 'Forecast do painel do dono errado: % · % · % · %.',
      v_d.forecast_compromisso, v_d.forecast_possivel, v_d.forecast_aberto, v_d.forecast_fora;
  end if;
  if not v_d.concentracao_em_alarme then
    raise exception 'A concentração precisa chegar em alarme no painel do dono.';
  end if;
  if v_d.meta_do_periodo <> 3000000.00 then
    raise exception 'Meta do período errada no painel do dono. Veio %.', v_d.meta_do_periodo;
  end if;
  if v_d.cobertura_situacao = 'indisponivel' then
    raise exception 'Com meta cadastrada a cobertura do painel do dono não pode ser indisponível.';
  end if;
  if v_d.cobertura_necessaria <> 3.33 then
    raise exception 'Cobertura necessária errada no painel do dono. Veio %.', v_d.cobertura_necessaria;
  end if;
  if v_d.margem <> 5100.00 then
    raise exception 'Margem errada. Esperava 5100,00, que é 8500,00 menos 850,00, 850,00 e 1700,00, e veio %.', v_d.margem;
  end if;
  if v_d.contratos_vigentes <> 1 or v_d.receita_mensal_contratada <> 10000.00 then
    raise exception 'Contrato vigente errado: % contratos e % de receita mensal.',
      v_d.contratos_vigentes, v_d.receita_mensal_contratada;
  end if;
  if v_d.alertas_vermelhos <> 1 or v_d.alertas_amarelos <> 1 then
    raise exception 'Alertas errados no painel do dono: % vermelhos e % amarelos.',
      v_d.alertas_vermelhos, v_d.alertas_amarelos;
  end if;

  -- Alertas, atividades, contratos, agenda, saúde da conta e trabalho da casa.
  select count(*) into v_qtd from valor.vw_alertas_abertos where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 2 then
    raise exception 'Esperava 2 alertas abertos. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_alertas_abertos
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
     and criticidade = 'vermelho' and conta_nome = 'Conta Delta de Teste';
  if v_qtd <> 1 then
    raise exception 'O alerta vermelho precisa chegar amarrado à Conta Delta de Teste. Vieram %.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.vw_atividades_pendentes where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 3 then
    raise exception 'Esperava 3 atividades pendentes. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_atividades_pendentes where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and situacao = 'vencida' and ordem = 1;
  if v_qtd <> 1 then
    raise exception 'Esperava 1 atividade vencida na primeira posição da ordem. Vieram %.', v_qtd;
  end if;

  select * into v_contrato from valor.vw_contratos_em_curso where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_contrato.dias_para_vencer <> 45 then
    raise exception 'Dias para vencer errado. Esperava 45 e veio %.', v_contrato.dias_para_vencer;
  end if;
  if not v_contrato.na_janela_de_renovacao then
    raise exception 'A 45 dias do fim, o contrato está dentro da janela de renovação de 90 dias.';
  end if;
  if v_contrato.sinal_de_vencimento <> 'amarelo' then
    raise exception 'O sinal de vencimento a 45 dias é amarelo. Veio %.', v_contrato.sinal_de_vencimento;
  end if;
  if not v_contrato.tem_negocio_de_renovacao then
    raise exception 'A Conta Alfa tem um negócio de renovação na fase 7, o contrato precisa mostrá-lo.';
  end if;
  if v_contrato.parcelas_recebidas <> 1 or v_contrato.valor_recebido <> 10000.00 then
    raise exception 'Parcela recebida errada: % parcelas e % recebidos.',
      v_contrato.parcelas_recebidas, v_contrato.valor_recebido;
  end if;

  select count(*) into v_qtd from valor.vw_agenda_da_semana where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 3 then
    raise exception 'Esperava 3 itens na agenda da semana, um de cada tipo. Vieram %.', v_qtd;
  end if;
  select count(distinct tipo) into v_qtd from valor.vw_agenda_da_semana where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 3 then
    raise exception 'A agenda precisa juntar encontro, reunião e compromisso. Vieram % tipos.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.vw_saude_da_conta where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001';
  if v_qtd <> 4 then
    raise exception 'Esperava 4 contas na saúde da conta. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_saude_da_conta
   where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001'
     and conta_nome = 'Conta Alfa de Teste'
     and contratos_vigentes = 1 and dias_sem_contato = 2 and turmas_ativas = 1
     and pendencias_vencidas = 1;
  if v_qtd <> 1 then
    raise exception 'A linha da Conta Alfa de Teste não bateu na saúde da conta.';
  end if;

  select count(*) into v_qtd from valor.vw_trabalho_da_casa where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and escopo = 'casa';
  if v_qtd <> 1 then
    raise exception 'Esperava 1 item de trabalho da própria casa. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_trabalho_da_casa where inquilino_id = 'bbbbbbbb-0000-4000-8000-000000000001' and escopo = 'cliente';
  if v_qtd <> 3 then
    raise exception 'Esperava 3 itens de trabalho de cliente. Vieram %.', v_qtd;
  end if;

  raise notice 'TESTE 6 passou: os dez painéis respondem, e o painel do dono fica vazio para quem não pode ver margem.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 7 · a prova do vazamento que não aconteceu'
\echo '=================================================================='
\echo 'Papel sem privilégio, perfil parceiro, no portal do parceiro Alfa.'

-- O dono de uma tabela ignora a segurança de linha. Daqui para baixo o teste
-- roda com o papel que o aplicativo usa de verdade, e é ele que prova a regra.
set role valor_aplicacao;

select set_config('app.usuario_id',  'bbbbbbbb-0000-4000-8000-000000000014', true) as ignorado;
select set_config('app.perfil',      'parceiro', true) as ignorado;
select set_config('app.parceiro_id', 'bbbbbbbb-0000-4000-8000-000000000021', true) as ignorado;

select current_user as papel_do_banco, valor.perfil_atual() as perfil,
       valor.parceiro_atual() as parceiro_da_sessao;

\echo ''
\echo 'O que o parceiro Alfa enxerga no painel dele:'
select linha, conta, status_indicacao, protecao_expira_em, dias_para_expirar_protecao,
       negocio_titulo, fase_rotulo, aprovado, valor_total, comissao_total, proxima_competencia
from valor.vw_painel_parceiro;

\echo ''
\echo 'O que o parceiro Alfa enxerga em cada visão da casa:'
select 'vw_painel_parceiro'        as visao, count(*) as linhas from valor.vw_painel_parceiro
union all select 'vw_painel_dono',        count(*) from valor.vw_painel_dono
union all select 'vw_painel_conselheiro', count(*) from valor.vw_painel_conselheiro
union all select 'vw_painel_gerente_contas', count(*) from valor.vw_painel_gerente_contas
union all select 'vw_negocios_forecast',  count(*) from valor.vw_negocios_forecast
union all select 'vw_pipeline_higiene',   count(*) from valor.vw_pipeline_higiene
union all select 'vw_forecast_por_categoria', count(*) from valor.vw_forecast_por_categoria
union all select 'vw_cobertura',          count(*) from valor.vw_cobertura
union all select 'vw_concentracao',       count(*) from valor.vw_concentracao
union all select 'vw_funil_por_fase',     count(*) from valor.vw_funil_por_fase
union all select 'vw_alertas_abertos',    count(*) from valor.vw_alertas_abertos
union all select 'vw_atividades_pendentes', count(*) from valor.vw_atividades_pendentes
union all select 'vw_contratos_em_curso', count(*) from valor.vw_contratos_em_curso
union all select 'vw_agenda_da_semana',   count(*) from valor.vw_agenda_da_semana
union all select 'vw_saude_da_conta',     count(*) from valor.vw_saude_da_conta
union all select 'vw_trabalho_da_casa',   count(*) from valor.vw_trabalho_da_casa
order by visao;

do $$
declare
  v_qtd integer;
  v_p   record;
begin
  -- O painel do parceiro mostra o negócio dele, e só ele.
  select count(*) into v_qtd from valor.vw_painel_parceiro;
  if v_qtd <> 1 then
    raise exception 'O parceiro Alfa tem uma indicação convertida. Esperava 1 linha e vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_parceiro
   where parceiro_id <> 'bbbbbbbb-0000-4000-8000-000000000021';
  if v_qtd <> 0 then
    raise exception 'O parceiro Alfa enxergou % linha de outro parceiro. Faltou security_invoker.', v_qtd;
  end if;

  select * into v_p from valor.vw_painel_parceiro;
  if v_p.negocio_id <> 'bbbbbbbb-0000-4000-8000-000000000051' then
    raise exception 'O parceiro Alfa precisa enxergar o negócio dele. Veio %.', v_p.negocio_id;
  end if;
  if not v_p.aprovado then
    raise exception 'A indicação do parceiro Alfa virou negócio, precisa aparecer como aprovada.';
  end if;
  if v_p.comissao_total <> 850.00 then
    raise exception 'Comissão do parceiro errada. Esperava 850,00 e veio %.', v_p.comissao_total;
  end if;
  if v_p.protecao_expira_em is null then
    raise exception 'A data de vencimento da proteção precisa aparecer no painel do parceiro.';
  end if;

  -- O painel do dono e o do conselheiro não devolvem uma linha sequer.
  select count(*) into v_qtd from valor.vw_painel_dono;
  if v_qtd <> 0 then
    raise exception 'VAZAMENTO: o parceiro leu % linha do painel do dono.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_conselheiro;
  if v_qtd <> 0 then
    raise exception 'VAZAMENTO: o parceiro leu % linha do painel do conselheiro.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_gerente_contas;
  if v_qtd <> 0 then
    raise exception 'VAZAMENTO: o parceiro leu % linha do painel do gerente de contas.', v_qtd;
  end if;

  -- O negócio do outro parceiro e o negócio sem parceiro ficam fora.
  select count(*) into v_qtd from valor.vw_negocios_forecast;
  if v_qtd <> 1 then
    raise exception 'VAZAMENTO: o parceiro leu % negócios no forecast, e só um é dele.', v_qtd;
  end if;

  -- As visões da casa ficam vazias, porque número de casa não é dele.
  select count(*) into v_qtd from valor.vw_pipeline_higiene;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: pipeline da casa chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_forecast_por_categoria;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: forecast da casa chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_cobertura;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: cobertura da casa chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_concentracao;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: concentração da casa chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_funil_por_fase;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: funil da casa chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_alertas_abertos;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: alerta interno chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_atividades_pendentes;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: atividade interna chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_contratos_em_curso;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: contrato chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_agenda_da_semana;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: agenda interna chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_saude_da_conta;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: saúde da conta chegou ao parceiro.'; end if;
  select count(*) into v_qtd from valor.vw_trabalho_da_casa;
  if v_qtd <> 0 then raise exception 'VAZAMENTO: trabalho da casa chegou ao parceiro.'; end if;

  raise notice 'TESTE 7 passou: o parceiro enxerga só o negócio dele e a comissão dele, e as visões da casa devolvem zero linha.';
end $$;

\echo ''
\echo 'Agora o outro parceiro, na mesma sessão de banco, para provar o isolamento:'

select set_config('app.usuario_id',  'bbbbbbbb-0000-4000-8000-000000000015', true) as ignorado;
select set_config('app.perfil',      'parceiro', true) as ignorado;
select set_config('app.parceiro_id', 'bbbbbbbb-0000-4000-8000-000000000022', true) as ignorado;

select linha, conta, status_indicacao, negocio_titulo, aprovado, comissao_total
from valor.vw_painel_parceiro;

do $$
declare
  v_qtd integer;
begin
  select count(*) into v_qtd from valor.vw_painel_parceiro
   where parceiro_id <> 'bbbbbbbb-0000-4000-8000-000000000022';
  if v_qtd <> 0 then
    raise exception 'VAZAMENTO: o parceiro Beta enxergou % linha do parceiro Alfa.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.vw_painel_parceiro
   where negocio_id = 'bbbbbbbb-0000-4000-8000-000000000051';
  if v_qtd <> 0 then
    raise exception 'VAZAMENTO: o parceiro Beta enxergou o negócio do parceiro Alfa.';
  end if;
  raise notice 'TESTE 7 passou também no isolamento entre parceiros: cada portal mostra apenas a carteira do próprio parceiro.';
end $$;

reset role;

\echo ''
\echo '=================================================================='
\echo 'TESTE 8 · nenhuma visão nasceu sem security_invoker'
\echo '=================================================================='

select c.relname as visao,
       coalesce(array_to_string(c.reloptions, ', '), 'nenhuma opção') as opcoes
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'valor'
  and c.relkind = 'v'
  and c.relname in (
    'vw_negocios_forecast', 'vw_pipeline_higiene', 'vw_forecast_por_categoria',
    'vw_cobertura', 'vw_concentracao', 'vw_funil_por_fase',
    'vw_painel_gerente_contas', 'vw_painel_dono', 'vw_painel_parceiro',
    'vw_painel_conselheiro', 'vw_alertas_abertos', 'vw_atividades_pendentes',
    'vw_contratos_em_curso', 'vw_agenda_da_semana', 'vw_saude_da_conta',
    'vw_trabalho_da_casa')
order by c.relname;

do $$
declare
  v_faltando text;
  v_quantas  integer;
begin
  select string_agg(c.relname, ', ' order by c.relname), count(*)
    into v_faltando, v_quantas
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'valor'
     and c.relkind = 'v'
     and c.relname in (
       'vw_negocios_forecast', 'vw_pipeline_higiene', 'vw_forecast_por_categoria',
       'vw_cobertura', 'vw_concentracao', 'vw_funil_por_fase',
       'vw_painel_gerente_contas', 'vw_painel_dono', 'vw_painel_parceiro',
       'vw_painel_conselheiro', 'vw_alertas_abertos', 'vw_atividades_pendentes',
       'vw_contratos_em_curso', 'vw_agenda_da_semana', 'vw_saude_da_conta',
       'vw_trabalho_da_casa')
     and not coalesce('security_invoker=true' = any (c.reloptions), false);

  if v_quantas > 0 then
    raise exception 'Visão sem security_invoker: %. Sem isso o parceiro lê pela visão o que a política proíbe na tabela.', v_faltando;
  end if;

  select count(*) into v_quantas
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'valor' and c.relkind = 'v'
     and c.relname in (
       'vw_negocios_forecast', 'vw_pipeline_higiene', 'vw_forecast_por_categoria',
       'vw_cobertura', 'vw_concentracao', 'vw_funil_por_fase',
       'vw_painel_gerente_contas', 'vw_painel_dono', 'vw_painel_parceiro',
       'vw_painel_conselheiro', 'vw_alertas_abertos', 'vw_atividades_pendentes',
       'vw_contratos_em_curso', 'vw_agenda_da_semana', 'vw_saude_da_conta',
       'vw_trabalho_da_casa');
  if v_quantas <> 16 then
    raise exception 'Esperava as 16 visões de painel criadas. Estão criadas %.', v_quantas;
  end if;

  raise notice 'TESTE 8 passou: as 16 visões existem e todas nasceram com security_invoker igual a true.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'Fim. O rollback abaixo apaga tudo o que este teste criou.'
\echo '=================================================================='

rollback;
