-- testes/brm.sql · Teste de regressão do BRM de Valor
-- Dono: engenheiro de BRM. Nenhum outro agente altera este arquivo.
--
-- O que este arquivo prova, com dados fictícios:
--   1. uma turma compartilhada de Conselho de Valor com 3 empresários de 3 contas diferentes
--   2. 4 encontros, sendo um remarcado, sem perder a numeração original
--   3. a presença por participante, e a presença acumulada recalculada pelo gatilho
--   4. o entregável de cada encontro
--   5. o ritual semanal com Highlights, Lowlights, Metas e Prioridades
--   6. a capacidade de cadeiras, que é restrição de banco e não de interface
--   7. as políticas de linha: o parceiro não lê nada, o conselheiro lê o que conduz,
--      o participante lê só a própria turma e só o entregável visível ao cliente
--
-- Como rodar, num banco com as migrações aplicadas:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d <banco> -f testes/brm.sql
--
-- Tudo roda dentro de uma transação que termina em rollback. O banco fica como
-- estava, e o teste pode rodar quantas vezes quiser. Nenhuma linha é apagada:
-- o que some é a transação inteira, que nunca chegou a existir.
--
-- A segurança é provada com o papel valor_aplicacao, da migração 0090, e nunca
-- com o dono das tabelas, que ignora a segurança de linha por definição.

\set ON_ERROR_STOP on
\pset border 2
\pset null '.'

begin;

-- Papel sem privilégio, o mesmo da migração 0090. O papel é do agrupamento e a
-- concessão é do banco, então uma coisa é conferida e a outra é reafirmada. Se a
-- 0090 já rodou neste banco, nada aqui muda. Como tudo vive dentro da transação
-- que termina em rollback, o teste não deixa rastro de permissão.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'valor_aplicacao') then
    create role valor_aplicacao nologin;
  end if;
end $$;

grant usage on schema valor to valor_aplicacao;
grant select, insert, update on all tables in schema valor to valor_aplicacao;
grant execute on all functions in schema valor to valor_aplicacao;
revoke delete on all tables in schema valor from valor_aplicacao;

-- =========================================================== dados fictícios

insert into valor.inquilinos (id, nome, apelido)
values ('11111111-1111-1111-1111-111111111111', 'Felix Empresarial', 'felix-teste-brm');

insert into valor.usuarios (id, inquilino_id, email, nome, perfil) values
 ('a0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','adm@exemplo.invalido','Pessoa Administradora','admin_master'),
 ('a0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','cons@exemplo.invalido','Pessoa Conselheira','conselheiro'),
 ('a0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','asse@exemplo.invalido','Pessoa Assessora','assessor'),
 ('a0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','parc@exemplo.invalido','Pessoa Parceira','parceiro'),
 ('a0000000-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111','part@exemplo.invalido','Pessoa da Cadeira Um','comercial'),
 ('a0000000-0000-0000-0000-000000000006','11111111-1111-1111-1111-111111111111','fora@exemplo.invalido','Pessoa Conselheira de Fora','conselheiro');

insert into valor.contas (id, inquilino_id, nome, setor, eh_cliente, eh_prospecto) values
 ('c0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','Empresa Alfa Ficticia','Metalurgia', true, false),
 ('c0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','Empresa Beta Ficticia','Logistica',  true, false),
 ('c0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','Empresa Gama Ficticia','Alimentos',  true, false);

insert into valor.contatos (id, inquilino_id, conta_id, nome, cargo, eh_principal) values
 ('d0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','c0000000-0000-0000-0000-000000000001','Sócio Fictício Um','Sócio', true),
 ('d0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','c0000000-0000-0000-0000-000000000002','Sócia Fictícia Dois','Sócia', true),
 ('d0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','c0000000-0000-0000-0000-000000000003','Sócio Fictício Três','Sócio', true);

insert into valor.ofertas (id, inquilino_id, codigo, nome, familia, modalidade, gera_turma, estrutura)
values ('e0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
        'CVC','Conselho de Valor compartilhado','Programas de Valor','recorrente', true,
        '48 reuniões no ano, até 8 empresários de mercados diferentes, hotseat por membro, resumo semanal, um presencial por mês');

-- O programa nasce sem contrato de propósito: a Felix pode rodar a turma antes
-- de a assinatura sair, e a modelagem tem que aguentar isso.
insert into valor.programas (
  id, inquilino_id, oferta_id, contrato_id, negocio_id, conta_id,
  codigo, nome, ano, modalidade, status, responsavel_id,
  cadencia, encontros_previstos, presenciais_por_mes,
  hotseat_por_membro, resumo_semanal, meses_duracao, marcos_indice
) values (
  'f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
  'e0000000-0000-0000-0000-000000000001', null, null, null,
  'PRG-CVC-2026','Conselho de Valor compartilhado 2026', 2026, 'compartilhada', 'ativo',
  'a0000000-0000-0000-0000-000000000002',
  'semanal', 48, 1, true, true, 12, '{T0,T90,T180}'
);

insert into valor.turmas (
  id, inquilino_id, programa_id, codigo, nome,
  cadeiras_minimas, cadeiras_maximas, data_inicio, data_fim, status,
  cadencia, formato, dia_semana, horario_inicio, horario_fim,
  encontros_previstos, recesso_inicio, recesso_fim,
  facilitador_id, coordenador_id
) values (
  '50000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
  'f0000000-0000-0000-0000-000000000001','CVC01','Conselho compartilhado, turma 01',
  3, 8, date '2026-02-05', date '2027-02-11', 'planejada',
  'semanal','online', 4, time '08:00', time '10:00',
  48, date '2026-12-15', date '2027-01-15',
  'a0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000003'
);

update valor.turmas t
   set calendario_base = (
     select array_agg(d order by d)
     from valor.brm_calendario_turma(t.data_inicio, t.encontros_previstos,
                                     t.cadencia, t.recesso_inicio, t.recesso_fim) d
   )
 where t.id = '50000000-0000-0000-0000-000000000001';

-- Três contas de mercados diferentes, uma cadeira cada. É isto que faz a turma
-- ser compartilhada de verdade, e não uma turma dedicada disfarçada.
insert into valor.turmas_contas (inquilino_id, turma_id, conta_id, cadeiras_contratadas) values
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001',1),
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000002',1),
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000003',1);

insert into valor.participantes (
  id, inquilino_id, turma_id, conta_id, contato_id, usuario_id, papel, cadeira, entrou_em
) values
 ('60000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000005','socio',1, date '2026-02-05'),
 ('60000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002', null,'socio',2, date '2026-02-05'),
 ('60000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000003', null,'socio',3, date '2026-02-05');

-- O piso de cadeiras é conferido no momento de começar, não no de montar.
update valor.turmas set status = 'em_andamento' where id = '50000000-0000-0000-0000-000000000001';

-- Encontro 1
insert into valor.encontros (id, inquilino_id, turma_id, numero, tema, data_prevista,
  hora_prevista_inicio, hora_prevista_fim, data_realizada, formato, link, status, conselheiro_id, gravacao_url)
values ('70000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
        '50000000-0000-0000-0000-000000000001', 1, 'Abertura do ciclo e contrato de convivência',
        date '2026-02-05', time '08:00', time '10:00', date '2026-02-05', 'online',
        'https://reuniao.exemplo.invalido/cvc01-01','realizado','a0000000-0000-0000-0000-000000000002',
        'https://arquivo.exemplo.invalido/cvc01-01');

-- Encontro 2, primeira marcação, que será remarcada
insert into valor.encontros (id, inquilino_id, turma_id, numero, tema, data_prevista,
  hora_prevista_inicio, hora_prevista_fim, formato, link, status, conselheiro_id)
values ('70000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
        '50000000-0000-0000-0000-000000000001', 2, 'Hotseat da cadeira 1 e leitura de indicadores',
        date '2026-02-12', time '08:00', time '10:00','online',
        'https://reuniao.exemplo.invalido/cvc01-02','previsto','a0000000-0000-0000-0000-000000000002');

-- A remarcação do encontro 2. Vai com numero 99 de propósito, para provar que o
-- gatilho devolve o número da sequência oficial e só soma uma tentativa.
insert into valor.encontros (id, inquilino_id, turma_id, numero, tema, data_prevista,
  hora_prevista_inicio, hora_prevista_fim, data_realizada, formato, link, status,
  conselheiro_id, remarcado_de, motivo_remarcacao, eh_hotseat, hotseat_participante_id)
values ('70000000-0000-0000-0000-000000000012','11111111-1111-1111-1111-111111111111',
        '50000000-0000-0000-0000-000000000001', 99, 'Hotseat da cadeira 1 e leitura de indicadores',
        date '2026-02-17', time '08:00', time '10:00', date '2026-02-17','online',
        'https://reuniao.exemplo.invalido/cvc01-02b','realizado','a0000000-0000-0000-0000-000000000002',
        '70000000-0000-0000-0000-000000000002','Feriado local na semana da primeira marcação',
        true,'60000000-0000-0000-0000-000000000001');

-- Encontro 3
insert into valor.encontros (id, inquilino_id, turma_id, numero, tema, data_prevista,
  hora_prevista_inicio, hora_prevista_fim, data_realizada, formato, link, status,
  conselheiro_id, eh_hotseat, hotseat_participante_id)
values ('70000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
        '50000000-0000-0000-0000-000000000001', 3, 'Hotseat da cadeira 2 e pendências do ciclo',
        date '2026-02-19', time '08:00', time '10:00', date '2026-02-19','online',
        'https://reuniao.exemplo.invalido/cvc01-03','realizado','a0000000-0000-0000-0000-000000000002',
        true,'60000000-0000-0000-0000-000000000002');

-- Encontro 4, o presencial do mês
insert into valor.encontros (id, inquilino_id, turma_id, numero, tema, data_prevista,
  hora_prevista_inicio, hora_prevista_fim, data_realizada, formato, local, status,
  conselheiro_id, assessor_id, eh_presencial_do_mes)
values ('70000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
        '50000000-0000-0000-0000-000000000001', 4, 'Presencial do mês: plano de 90 dias por cadeira',
        date '2026-02-26', time '09:00', time '17:00', date '2026-02-26','presencial',
        'Sala de conselho, endereço fictício','realizado','a0000000-0000-0000-0000-000000000002',
        'a0000000-0000-0000-0000-000000000003', true);

insert into valor.presencas (inquilino_id, encontro_id, participante_id, situacao, justificativa, registrada_por)
select '11111111-1111-1111-1111-111111111111', v.encontro, v.participante, v.situacao, v.justificativa,
       'a0000000-0000-0000-0000-000000000003'
from (values
  ('70000000-0000-0000-0000-000000000001'::uuid,'60000000-0000-0000-0000-000000000001'::uuid,'presente'::valor.brm_situacao_presenca, null::text),
  ('70000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000002','presente', null),
  ('70000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','presente', null),
  ('70000000-0000-0000-0000-000000000012','60000000-0000-0000-0000-000000000001','presente', null),
  ('70000000-0000-0000-0000-000000000012','60000000-0000-0000-0000-000000000002','ausente_justificado','Viagem avisada com antecedência'),
  ('70000000-0000-0000-0000-000000000012','60000000-0000-0000-0000-000000000003','presente', null),
  ('70000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000001','presente', null),
  ('70000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000002','presente', null),
  ('70000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000003','ausente', null),
  ('70000000-0000-0000-0000-000000000004','60000000-0000-0000-0000-000000000001','presente', null),
  ('70000000-0000-0000-0000-000000000004','60000000-0000-0000-0000-000000000002','presente', null),
  ('70000000-0000-0000-0000-000000000004','60000000-0000-0000-0000-000000000003','presente', null)
) as v(encontro, participante, situacao, justificativa);

insert into valor.itens_ritual_semanal
  (inquilino_id, encontro_id, turma_id, conta_id, tipo, ordem, topico,
   responsavel_participante_id, responsavel_usuario_id, data_alvo)
values
 ('11111111-1111-1111-1111-111111111111','70000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001','highlight',1,'Time comercial fechou o primeiro ciclo de cadência',
  '60000000-0000-0000-0000-000000000001', null, date '2026-02-05'),
 ('11111111-1111-1111-1111-111111111111','70000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000002','lowlight',1,'Falta de dado confiável de margem por linha',
  '60000000-0000-0000-0000-000000000002', null, date '2026-02-12'),
 ('11111111-1111-1111-1111-111111111111','70000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000003','meta',1,'Fechar o mapa de contas do trimestre',
  '60000000-0000-0000-0000-000000000003', null, date '2026-03-31'),
 ('11111111-1111-1111-1111-111111111111','70000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
  null,'prioridade',1,'Montar o painel de pendências da turma',
  null,'a0000000-0000-0000-0000-000000000003', date '2026-02-19');

insert into valor.entregaveis (inquilino_id, turma_id, encontro_id, participante_id, conta_id,
  tipo, titulo, arquivo_url, data_entrega, status, visivel_ao_cliente, aprovado_em, aprovado_por,
  produzido_por_usuario_id, devolutiva)
values
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001',
  null, null,'ata','Ata do encontro 1, abertura do ciclo','https://arquivo.exemplo.invalido/ata-01',
  date '2026-02-06','aprovado', true, date '2026-02-07','a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003', null),
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000012',
  '60000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','resumo_semanal',
  'Resumo semanal do hotseat da cadeira 1','https://arquivo.exemplo.invalido/resumo-02',
  date '2026-02-18','entregue', true, null, null,'a0000000-0000-0000-0000-000000000003', null),
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000002','diagnostico',
  'Diagnóstico de governança da cadeira 2','https://arquivo.exemplo.invalido/diag-03',
  date '2026-02-20','entregue', false, null, null,'a0000000-0000-0000-0000-000000000002',
  'Devolutiva interna sobre a cadeira, fora da visão do cliente'),
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000004',
  null, null,'plano_de_acao','Plano de 90 dias da turma','https://arquivo.exemplo.invalido/plano-04',
  date '2026-02-27','aprovado', true, date '2026-02-28','a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003', null);

insert into valor.historico_valor (inquilino_id, conta_id, programa_id, turma_id, ano, trimestre,
  data_referencia, entregue, resultado, evidencia, registrado_por)
values
 ('11111111-1111-1111-1111-111111111111','c0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001', 2026, 1, date '2026-03-31',
  'Hotseat da cadeira 1 e plano de 90 dias','Cadência comercial implantada em todo o time',
  'Ata do encontro 1 e plano aprovado no encontro 4','a0000000-0000-0000-0000-000000000002'),
 ('11111111-1111-1111-1111-111111111111','c0000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001', 2026, 1, date '2026-03-31',
  'Diagnóstico de governança','Primeiro painel de margem por linha em operação',
  'Diagnóstico do encontro 3','a0000000-0000-0000-0000-000000000002'),
 ('11111111-1111-1111-1111-111111111111','c0000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001', 2026, 1, date '2026-03-31',
  'Mapa de contas do trimestre','Carteira repriorizada em três faixas',
  'Mapa anexado ao encontro 4','a0000000-0000-0000-0000-000000000002');

set constraints all immediate;

-- ================================================== 1. a turma compartilhada
\echo ''
\echo '===== 1. Turma compartilhada de Conselho de Valor, 3 contas diferentes ====='
select p.codigo as programa, p.modalidade, t.codigo as turma, t.status,
       t.cadeiras_minimas as cadeiras_min, t.cadeiras_maximas as cadeiras_max,
       count(distinct tc.conta_id) as contas,
       count(distinct pa.id) as cadeiras_ocupadas
from valor.programas p
join valor.turmas t          on t.programa_id = p.id
join valor.turmas_contas tc  on tc.turma_id = t.id
join valor.participantes pa  on pa.turma_id = t.id and pa.status <> 'desligado'
group by p.codigo, p.modalidade, t.codigo, t.status, t.cadeiras_minimas, t.cadeiras_maximas;

\echo ''
\echo '===== 1b. Quem senta em cada cadeira, e de que conta ====='
select pa.cadeira, ct.nome as pessoa, c.nome as conta, c.setor,
       pa.papel, tc.cadeiras_contratadas, pa.status
from valor.participantes pa
join valor.contatos ct      on ct.id = pa.contato_id
join valor.contas c         on c.id = pa.conta_id
join valor.turmas_contas tc on tc.turma_id = pa.turma_id and tc.conta_id = pa.conta_id
order by pa.cadeira;

do $$
declare v_contas integer; v_cadeiras integer; v_modalidade valor.brm_modalidade_turma;
begin
  select count(distinct tc.conta_id), p.modalidade into v_contas, v_modalidade
  from valor.turmas_contas tc
  join valor.turmas t on t.id = tc.turma_id
  join valor.programas p on p.id = t.programa_id
  where t.codigo = 'CVC01' group by p.modalidade;

  select count(*) into v_cadeiras from valor.participantes pa
  join valor.turmas t on t.id = pa.turma_id
  where t.codigo = 'CVC01' and pa.status = 'ativo';

  if v_modalidade <> 'compartilhada' then raise exception 'A turma CVC01 deixou de ser compartilhada.'; end if;
  if v_contas <> 3 then raise exception 'Esperava 3 contas na turma CVC01 e achei %.', v_contas; end if;
  if v_cadeiras <> 3 then raise exception 'Esperava 3 cadeiras ocupadas e achei %.', v_cadeiras; end if;
end $$;

-- ============================================ 2. os 4 encontros e a remarcação
\echo ''
\echo '===== 2. Agenda da turma. O encontro 2 foi remarcado e o número resistiu ====='
select e.numero, e.tentativa, e.status,
       e.data_prevista_original as prevista_na_origem,
       e.data_prevista, e.data_realizada, e.formato, e.tema, e.motivo_remarcacao
from valor.encontros e
join valor.turmas t on t.id = e.turma_id
where t.codigo = 'CVC01'
order by e.numero, e.tentativa;

\echo ''
\echo '===== 2b. Calendário base, com recesso de meados de dezembro a meados de janeiro ====='
select t.codigo, t.recesso_inicio, t.recesso_fim,
       array_length(t.calendario_base, 1) as datas_geradas,
       t.calendario_base[1:4]   as quatro_primeiras,
       t.calendario_base[43:48] as seis_ultimas
from valor.turmas t where t.codigo = 'CVC01';

select 'datas do calendário que caem no recesso' as confere, count(*) as total
from valor.turmas t, unnest(t.calendario_base) d
where t.codigo = 'CVC01' and valor.brm_em_recesso(d, t.recesso_inicio, t.recesso_fim);

do $$
declare v_vivos integer; v_orig date; v_nova date; v_tent smallint; v_recesso integer;
begin
  select count(*) into v_vivos from valor.encontros e
  join valor.turmas t on t.id = e.turma_id
  where t.codigo = 'CVC01' and e.status in ('previsto','realizado');
  if v_vivos <> 4 then raise exception 'Esperava 4 encontros vivos e achei %.', v_vivos; end if;

  select e.data_prevista_original, e.data_prevista, e.tentativa into v_orig, v_nova, v_tent
  from valor.encontros e join valor.turmas t on t.id = e.turma_id
  where t.codigo = 'CVC01' and e.numero = 2 and e.status = 'realizado';

  if v_tent <> 2 then raise exception 'A remarcação devia ser a tentativa 2 e é a %.', v_tent; end if;
  if v_orig <> date '2026-02-12' then raise exception 'A data da primeira marcação se perdeu: %.', v_orig; end if;
  if v_nova <> date '2026-02-17' then raise exception 'A data da remarcação está errada: %.', v_nova; end if;

  if not exists (select 1 from valor.encontros e join valor.turmas t on t.id = e.turma_id
                 where t.codigo = 'CVC01' and e.numero = 2 and e.tentativa = 1 and e.status = 'remarcado') then
    raise exception 'A primeira marcação do encontro 2 não ficou como remarcada.';
  end if;

  select count(*) into v_recesso
  from valor.turmas t, unnest(t.calendario_base) d
  where t.codigo = 'CVC01' and valor.brm_em_recesso(d, t.recesso_inicio, t.recesso_fim);
  if v_recesso <> 0 then raise exception 'O calendário caiu dentro do recesso em % datas.', v_recesso; end if;
end $$;

-- ============================================================= 3. a presença
\echo ''
\echo '===== 3. Presença por participante e por encontro ====='
select ct.nome as pessoa, c.nome as conta,
       max(case when e.numero = 1 then pr.situacao::text end) as enc_1,
       max(case when e.numero = 2 then pr.situacao::text end) as enc_2,
       max(case when e.numero = 3 then pr.situacao::text end) as enc_3,
       max(case when e.numero = 4 then pr.situacao::text end) as enc_4
from valor.presencas pr
join valor.encontros e      on e.id = pr.encontro_id
join valor.participantes pa on pa.id = pr.participante_id
join valor.contatos ct      on ct.id = pa.contato_id
join valor.contas c         on c.id = pa.conta_id
group by ct.nome, c.nome, pa.cadeira
order by pa.cadeira;

\echo ''
\echo '===== 3b. Presença acumulada, recalculada pelo gatilho ====='
select pa.cadeira, ct.nome as pessoa, pa.encontros_convocados, pa.encontros_presentes,
       pa.presenca_percentual
from valor.participantes pa join valor.contatos ct on ct.id = pa.contato_id
order by pa.cadeira;

do $$
declare v numeric;
begin
  select presenca_percentual into v from valor.participantes where cadeira = 1;
  if v <> 1.0000 then raise exception 'A cadeira 1 devia ter presença 1.0000 e tem %.', v; end if;
  select presenca_percentual into v from valor.participantes where cadeira = 2;
  if v <> 0.7500 then raise exception 'A cadeira 2 devia ter presença 0.7500 e tem %.', v; end if;
  select presenca_percentual into v from valor.participantes where cadeira = 3;
  if v <> 0.7500 then raise exception 'A cadeira 3 devia ter presença 0.7500 e tem %.', v; end if;
end $$;

-- ========================================================== 4. os entregáveis
\echo ''
\echo '===== 4. Entregável de cada encontro ====='
select e.numero, e.tentativa, e.data_realizada, en.tipo, en.titulo, en.status,
       en.visivel_ao_cliente, coalesce(c.nome, 'turma inteira') as dono
from valor.encontros e
join valor.entregaveis en on en.encontro_id = e.id
left join valor.contas c  on c.id = en.conta_id
order by e.numero, e.tentativa;

do $$
declare v integer;
begin
  select count(distinct e.numero) into v
  from valor.encontros e join valor.entregaveis en on en.encontro_id = e.id
  where e.status in ('previsto','realizado');
  if v <> 4 then raise exception 'Esperava entregável nos 4 encontros vivos e achei em %.', v; end if;
end $$;

-- ======================================================= 5. o ritual semanal
\echo ''
\echo '===== 5. Ritual semanal: Highlights, Lowlights, Metas e Prioridades ====='
select i.tipo, i.topico, coalesce(ct.nome, u.nome) as responsavel, i.data_alvo
from valor.itens_ritual_semanal i
left join valor.participantes pa on pa.id = i.responsavel_participante_id
left join valor.contatos ct      on ct.id = pa.contato_id
left join valor.usuarios u       on u.id = i.responsavel_usuario_id
order by i.tipo, i.ordem;

do $$
declare v integer;
begin
  select count(distinct tipo) into v from valor.itens_ritual_semanal;
  if v <> 4 then raise exception 'O ritual semanal devia ter os 4 tipos e tem %.', v; end if;
  if exists (select 1 from valor.itens_ritual_semanal where data_alvo is null) then
    raise exception 'Todo item do ritual precisa de data.';
  end if;
end $$;

\echo ''
\echo '===== 6. Histórico de Valor do trimestre, por conta e por programa ====='
select hv.competencia, c.nome as conta, p.codigo as programa,
       hv.entregue, hv.resultado, hv.evidencia
from valor.historico_valor hv
join valor.contas c    on c.id = hv.conta_id
join valor.programas p on p.id = hv.programa_id
order by c.nome;

-- ============================================ 7. a capacidade como restrição
\echo ''
\echo '===== 7. A capacidade de cadeiras é restrição de banco, não de interface ====='
\set ON_ERROR_STOP off

savepoint prova_a;
\echo '--- 7a. cadeira além do que a conta contratou ---'
insert into valor.participantes (inquilino_id, turma_id, conta_id, nome, papel, cadeira)
values ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001',
        'c0000000-0000-0000-0000-000000000001','Convidado Fictício','convidado', 4);
rollback to savepoint prova_a;

savepoint prova_b;
\echo '--- 7b. cadeiras acima do teto da turma ---'
insert into valor.contas (id, inquilino_id, nome, eh_cliente)
values ('c0000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','Empresa Delta Ficticia', true);
insert into valor.turmas_contas (inquilino_id, turma_id, conta_id, cadeiras_contratadas)
values ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000004', 6);
insert into valor.participantes (inquilino_id, turma_id, conta_id, nome, papel, cadeira)
select '11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001',
       'c0000000-0000-0000-0000-000000000004','Pessoa Fictícia ' || g,'membro', 3 + g
from generate_series(1,6) g;
rollback to savepoint prova_b;

savepoint prova_c;
\echo '--- 7c. turma dedicada com duas contas ---'
insert into valor.programas (id, inquilino_id, codigo, nome, ano, modalidade, status, responsavel_id)
values ('f0000000-0000-0000-0000-000000000009','11111111-1111-1111-1111-111111111111',
        'PRG-CVD-2026','Conselho de Valor dedicado 2026', 2026,'dedicada','ativo',
        'a0000000-0000-0000-0000-000000000002');
insert into valor.turmas (id, inquilino_id, programa_id, codigo, cadeiras_minimas, cadeiras_maximas)
values ('50000000-0000-0000-0000-000000000009','11111111-1111-1111-1111-111111111111',
        'f0000000-0000-0000-0000-000000000009','CVD01', 1, 6);
insert into valor.turmas_contas (inquilino_id, turma_id, conta_id, cadeiras_contratadas, eh_anfitria) values
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000009','c0000000-0000-0000-0000-000000000001',6, true),
 ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000009','c0000000-0000-0000-0000-000000000002',1, false);
rollback to savepoint prova_c;

savepoint prova_d;
\echo '--- 7d. turma que tenta começar abaixo do piso de cadeiras ---'
insert into valor.programas (id, inquilino_id, codigo, nome, ano, modalidade, status, responsavel_id)
values ('f0000000-0000-0000-0000-000000000008','11111111-1111-1111-1111-111111111111',
        'PRG-NDV-2026','Negócios de Valor 2026', 2026,'compartilhada','ativo',
        'a0000000-0000-0000-0000-000000000002');
insert into valor.turmas (id, inquilino_id, programa_id, codigo, cadeiras_minimas, cadeiras_maximas)
values ('50000000-0000-0000-0000-000000000008','11111111-1111-1111-1111-111111111111',
        'f0000000-0000-0000-0000-000000000008','NDV01', 8, 16);
update valor.turmas set status = 'em_andamento' where id = '50000000-0000-0000-0000-000000000008';
rollback to savepoint prova_d;

\set ON_ERROR_STOP on
set constraints all immediate;

-- ================================================= 8. as políticas de linha
-- Daqui para baixo nada roda como dono de tabela. O papel valor_aplicacao não
-- tem privilégio nenhum, então é ele que prova a política de verdade.

\echo ''
\echo '===== 8. Políticas de linha, com o papel valor_aplicacao ====='
set role valor_aplicacao;

\echo ''
\echo '--- 8a. PARCEIRO: não lê uma linha sequer de BRM ---'
select set_config('app.inquilino_id','11111111-1111-1111-1111-111111111111', true),
       set_config('app.usuario_id','a0000000-0000-0000-0000-000000000004', true),
       set_config('app.perfil','parceiro', true),
       set_config('app.parceiro_id','b0000000-0000-0000-0000-000000000001', true) \gset

select current_user as papel_do_banco, valor.perfil_atual() as perfil_da_sessao,
       valor.eh_parceiro() as eh_parceiro;

select 'programas' as tabela, count(*) as linhas_visiveis from valor.programas
union all select 'turmas',               count(*) from valor.turmas
union all select 'turmas_contas',        count(*) from valor.turmas_contas
union all select 'participantes',        count(*) from valor.participantes
union all select 'encontros',            count(*) from valor.encontros
union all select 'presencas',            count(*) from valor.presencas
union all select 'itens_ritual_semanal', count(*) from valor.itens_ritual_semanal
union all select 'entregaveis',          count(*) from valor.entregaveis
union all select 'historico_valor',      count(*) from valor.historico_valor
union all select 'vw_agenda_turma',      count(*) from valor.vw_agenda_turma
union all select 'vw_historico_valor_devido', count(*) from valor.vw_historico_valor_devido
order by 1;

do $$
declare v integer := 0;
begin
  select (select count(*) from valor.programas) + (select count(*) from valor.turmas)
       + (select count(*) from valor.turmas_contas) + (select count(*) from valor.participantes)
       + (select count(*) from valor.encontros) + (select count(*) from valor.presencas)
       + (select count(*) from valor.itens_ritual_semanal) + (select count(*) from valor.entregaveis)
       + (select count(*) from valor.historico_valor) + (select count(*) from valor.vw_agenda_turma)
       + (select count(*) from valor.vw_historico_valor_devido) into v;
  if v <> 0 then raise exception 'O parceiro alcançou % linhas de BRM. Devia ser zero.', v; end if;
end $$;

\echo ''
\echo '--- 8b. PARCEIRO: escrever também não dá ---'
\set ON_ERROR_STOP off
savepoint prova_parceiro;
insert into valor.entregaveis (inquilino_id, turma_id, tipo, titulo)
values ('11111111-1111-1111-1111-111111111111','50000000-0000-0000-0000-000000000001','ata','Tentativa do parceiro');
rollback to savepoint prova_parceiro;
\set ON_ERROR_STOP on

\echo ''
\echo '--- 8c. CONSELHEIRO responsável pelo programa ---'
select set_config('app.usuario_id','a0000000-0000-0000-0000-000000000002', true),
       set_config('app.perfil','conselheiro', true),
       set_config('app.parceiro_id','', true) \gset
select 'programas' as tabela, count(*) as linhas_visiveis from valor.programas
union all select 'turmas',          count(*) from valor.turmas
union all select 'participantes',   count(*) from valor.participantes
union all select 'encontros',       count(*) from valor.encontros
union all select 'entregaveis',     count(*) from valor.entregaveis
union all select 'historico_valor', count(*) from valor.historico_valor
order by 1;

\echo ''
\echo '--- 8d. CONSELHEIRO sem papel nesta turma ---'
select set_config('app.usuario_id','a0000000-0000-0000-0000-000000000006', true),
       set_config('app.perfil','conselheiro', true) \gset
select 'programas' as tabela, count(*) as linhas_visiveis from valor.programas
union all select 'turmas',      count(*) from valor.turmas
union all select 'encontros',   count(*) from valor.encontros
union all select 'entregaveis', count(*) from valor.entregaveis
order by 1;

do $$
declare v integer;
begin
  select (select count(*) from valor.programas) + (select count(*) from valor.turmas)
       + (select count(*) from valor.encontros) + (select count(*) from valor.entregaveis) into v;
  if v <> 0 then raise exception 'O conselheiro de fora alcançou % linhas. Devia ser zero.', v; end if;
end $$;

\echo ''
\echo '--- 8e. PARTICIPANTE do cliente com login: só a própria turma ---'
select set_config('app.usuario_id','a0000000-0000-0000-0000-000000000005', true),
       set_config('app.perfil','comercial', true) \gset
select 'turmas' as tabela, count(*) as linhas_visiveis from valor.turmas
union all select 'participantes',   count(*) from valor.participantes
union all select 'encontros',       count(*) from valor.encontros
union all select 'entregaveis',     count(*) from valor.entregaveis
union all select 'historico_valor', count(*) from valor.historico_valor
order by 1;

\echo ''
\echo '--- 8f. PARTICIPANTE: só o entregável marcado como visível ao cliente ---'
select titulo, tipo, status, visivel_ao_cliente from valor.entregaveis order by titulo;

\echo ''
\echo '--- 8g. PARTICIPANTE: só a própria linha em participantes ---'
select cadeira, papel, status from valor.participantes;

do $$
declare v_turmas integer; v_part integer; v_ent integer; v_hist integer; v_escondido integer;
begin
  select count(*) into v_turmas from valor.turmas;
  select count(*) into v_part   from valor.participantes;
  select count(*) into v_ent    from valor.entregaveis;
  select count(*) into v_hist   from valor.historico_valor;
  select count(*) into v_escondido from valor.entregaveis where not visivel_ao_cliente;

  if v_turmas <> 1 then raise exception 'O participante devia alcançar 1 turma e alcançou %.', v_turmas; end if;
  if v_part <> 1 then raise exception 'O participante devia ver só a própria linha e vê %.', v_part; end if;
  if v_ent <> 3 then raise exception 'O participante devia ver 3 entregáveis visíveis e vê %.', v_ent; end if;
  if v_escondido <> 0 then raise exception 'O participante alcançou % entregáveis não visíveis.', v_escondido; end if;
  if v_hist <> 0 then raise exception 'O participante alcançou % linhas de Histórico de Valor.', v_hist; end if;
end $$;

reset role;

-- ====================================== 9. apagar não é forma de remover
\echo ''
\echo '===== 9. Apagar não é forma de remover ====='
select c.relname as tabela,
       count(*) filter (where p.polcmd = 'd') as politicas_de_delete,
       has_table_privilege('valor_aplicacao', c.oid, 'delete') as papel_pode_apagar
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policy p on p.polrelid = c.oid
where n.nspname = 'valor' and c.relkind = 'r'
  and c.relname in ('programas','turmas','turmas_contas','participantes',
                    'encontros','presencas','itens_ritual_semanal','entregaveis','historico_valor')
group by c.relname, c.oid
order by c.relname;

do $$
declare v integer;
begin
  select count(*) into v
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_policy p on p.polrelid = c.oid
  where n.nspname = 'valor' and p.polcmd = 'd'
    and c.relname in ('programas','turmas','turmas_contas','participantes',
                      'encontros','presencas','itens_ritual_semanal','entregaveis','historico_valor');
  if v <> 0 then raise exception 'Alguma tabela do BRM ganhou política de delete: %.', v; end if;
end $$;

\echo ''
\echo '===== 10. Toda tabela do BRM com RLS ligada e ao menos uma política ====='
select c.relname as tabela, c.relrowsecurity as rls_ligada, count(p.polname) as politicas
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policy p on p.polrelid = c.oid
where n.nspname = 'valor' and c.relkind = 'r'
  and c.relname in ('programas','turmas','turmas_contas','participantes',
                    'encontros','presencas','itens_ritual_semanal','entregaveis','historico_valor')
group by c.relname, c.relrowsecurity
order by c.relname;

do $$
declare v integer;
begin
  select count(*) into v
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'valor' and c.relkind = 'r'
    and c.relname in ('programas','turmas','turmas_contas','participantes',
                      'encontros','presencas','itens_ritual_semanal','entregaveis','historico_valor')
    and (not c.relrowsecurity
         or not exists (select 1 from pg_policy p where p.polrelid = c.oid));
  if v <> 0 then raise exception '% tabelas do BRM estão sem RLS ou sem política.', v; end if;
end $$;

\echo ''
\echo '===== 11. Colunas de avaliação de pessoa e anotação sobre cliente, marcadas CONFIDENCIAL ====='
select c.relname as tabela, a.attname as coluna
from pg_description d
join pg_class c      on c.oid = d.objoid
join pg_namespace n  on n.oid = c.relnamespace
join pg_attribute a  on a.attrelid = c.oid and a.attnum = d.objsubid
where n.nspname = 'valor' and d.description like 'CONFIDENCIAL%'
  and c.relname in ('programas','turmas','turmas_contas','participantes',
                    'encontros','presencas','itens_ritual_semanal','entregaveis','historico_valor')
order by c.relname, a.attname;

do $$
declare v integer;
begin
  select count(*) into v from (values
    ('participantes','indices'), ('participantes','observacoes'), ('participantes','motivo_saida'),
    ('presencas','justificativa'), ('presencas','observacao'),
    ('entregaveis','avaliacao'), ('entregaveis','devolutiva'), ('entregaveis','nota'),
    ('encontros','transcricao_texto'), ('encontros','observacoes_restritas')
  ) as esperado(tabela, coluna)
  where not exists (
    select 1 from pg_description d
    join pg_class c on c.oid = d.objoid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attnum = d.objsubid
    where n.nspname = 'valor' and c.relname = esperado.tabela and a.attname = esperado.coluna
      and d.description like 'CONFIDENCIAL%'
  );
  if v <> 0 then raise exception '% colunas confidenciais perderam a marca CONFIDENCIAL.', v; end if;
end $$;

\echo ''
\echo '=========================================================================='
\echo 'BRM: todas as provas passaram. A transação volta atrás e o banco fica limpo.'
\echo '=========================================================================='

rollback;
