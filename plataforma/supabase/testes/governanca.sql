-- Teste de regressão do domínio de governança · migrações 0009 e 0010
-- Dono: engenheiro de governança. Nenhum outro agente altera este arquivo.
--
-- O que este teste prova, e volta a provar a cada rodada:
--   1. Pendência aberta reaparece na pré-pauta da reunião seguinte, e a pendência
--      concluída não reaparece. A prova é a saída de valor.montar_pre_pauta.
--   2. A pauta nova da turma já nasce com a pendência aberta dentro, sem ninguém
--      pedir, porque a regra vive no banco e não na tela.
--   3. O NPS sai de promotores, neutros e detratores, e cada pessoa entra com a
--      última nota que deu, nunca com a média das notas dela.
--
-- Como rodar, depois de aplicar as migrações num banco limpo:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -d fab_gov -f testes/governanca.sql
--
-- O teste roda dentro de uma transação e termina em rollback, então não deixa
-- dado no banco e pode ser repetido quantas vezes quiser. A carga roda com o
-- papel valor_aplicacao, criado na migração 0090, que não é dono de tabela e
-- portanto obedece a segurança de linha. Testar como dono aprova política
-- quebrada, então o teste não faz isso.
--
-- Dados fictícios, nomes inventados. Nenhum cliente real, nenhuma avaliação real.

\set ON_ERROR_STOP on
\pset border 2
\timing off

begin;

-- ---------------------------------------------------------------- carga fictícia

-- O inquilino nasce pelo papel provisionador, porque valor.inquilinos não tem
-- política de escrita: quem cria inquilino é a instalação, não o aplicativo.
insert into valor.inquilinos (id, nome, apelido) values
 ('0e57e000-0000-4000-8000-000000000001', 'Inquilino de Teste de Governanca', 'teste_governanca');

set role valor_aplicacao;

select set_config('app.inquilino_id', '0e57e000-0000-4000-8000-000000000001', true);
select set_config('app.usuario_id',   '0e57e000-0000-4000-8000-0000000000a0', true);
select set_config('app.perfil',       'admin_master', true);

insert into valor.usuarios (id, inquilino_id, email, nome, perfil) values
 ('0e57e000-0000-4000-8000-0000000000a0','0e57e000-0000-4000-8000-000000000001','admin@exemplo.invalido','Pessoa Administradora','admin_master'),
 ('0e57e000-0000-4000-8000-0000000000a1','0e57e000-0000-4000-8000-000000000001','lider@exemplo.invalido','Pessoa Lider','lider'),
 ('0e57e000-0000-4000-8000-0000000000a2','0e57e000-0000-4000-8000-000000000001','assessor@exemplo.invalido','Pessoa Assessor','assessor'),
 ('0e57e000-0000-4000-8000-0000000000a3','0e57e000-0000-4000-8000-000000000001','conselheiro@exemplo.invalido','Pessoa Conselheiro','conselheiro'),
 ('0e57e000-0000-4000-8000-0000000000a5','0e57e000-0000-4000-8000-000000000001','cadeira1@exemplo.invalido','Pessoa Cadeira da Turma','participante'),
 ('0e57e000-0000-4000-8000-0000000000a6','0e57e000-0000-4000-8000-000000000001','cadeira2@exemplo.invalido','Pessoa Cadeira de Outra Turma','participante');

insert into valor.contas (id, inquilino_id, nome, eh_cliente, eh_prospecto) values
 ('0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-000000000001','Conta Ficticia Alfa', true, false);

insert into valor.contatos (id, inquilino_id, conta_id, nome, cargo) values
 ('0e57e000-0000-4000-8000-0000000000d1','0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-0000000000c1','Pessoa Socia Um','Socia'),
 ('0e57e000-0000-4000-8000-0000000000d2','0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-0000000000c1','Pessoa Socia Dois','Socio'),
 ('0e57e000-0000-4000-8000-0000000000d3','0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-0000000000c1','Pessoa Diretora','Diretora'),
 ('0e57e000-0000-4000-8000-0000000000d4','0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-0000000000c1','Pessoa Gerente','Gerente'),
 ('0e57e000-0000-4000-8000-0000000000d5','0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-0000000000c1','Pessoa Convidada','Convidada');

select valor.semear_modelos_ata('0e57e000-0000-4000-8000-000000000001') as modelos_de_ata_semeados;
select valor.semear_banco_pautas('0e57e000-0000-4000-8000-000000000001') as temas_do_banco_semeados;

-- O rito do conselho acontece dentro de uma turma, então a carga monta programa,
-- turma e encontros de verdade, do BRM, e usa os identificadores reais. Desde a
-- migração 0080 as chaves estrangeiras cobram isso, e é bom que cobrem.
insert into valor.programas (
  id, inquilino_id, conta_id, codigo, nome, ano, modalidade, status,
  responsavel_id, data_inicio, data_fim, cadencia, encontros_previstos,
  pauta_prioritaria_mensal, presenciais_por_mes)
values ('0e57e000-0000-4000-8000-000000000021','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-0000000000c1','PRG-TESTE-GOV','Conselho de Valor dedicado · teste',
        2026,'dedicada','ativo','0e57e000-0000-4000-8000-0000000000a3',
        date '2026-01-12', date '2026-12-11','semanal', 48, true, 1);

insert into valor.turmas (
  id, inquilino_id, programa_id, codigo, nome, cadeiras_minimas, cadeiras_maximas,
  data_inicio, data_fim, status, cadencia, formato, dia_semana,
  horario_inicio, horario_fim, encontros_previstos,
  recesso_inicio, recesso_fim, facilitador_id, coordenador_id)
values ('0e57e000-0000-4000-8000-0000000000e1','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-000000000021','TRM-TESTE-GOV','Turma de teste de governanca',
        1, 8, date '2026-01-12', date '2026-12-11','em_andamento','semanal','online', 2,
        time '09:00', time '11:00', 48,
        date '2026-12-15', date '2027-01-15',
        '0e57e000-0000-4000-8000-0000000000a3','0e57e000-0000-4000-8000-0000000000a2');

insert into valor.encontros (
  id, inquilino_id, turma_id, numero, tema, data_prevista, data_realizada,
  hora_prevista_inicio, hora_prevista_fim, formato, status,
  conselheiro_id, assessor_id)
values
 ('0e57e000-0000-4000-8000-000000000031','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000e1', 1,'Indicadores do periodo e caixa',
  date '2026-09-08', date '2026-09-08', time '09:00', time '11:00','online','realizado',
  '0e57e000-0000-4000-8000-0000000000a3','0e57e000-0000-4000-8000-0000000000a2'),
 ('0e57e000-0000-4000-8000-000000000032','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000e1', 2,'Pendencias e tabela de precos',
  date '2026-09-22', null, time '09:00', time '11:00','online','previsto',
  '0e57e000-0000-4000-8000-0000000000a3','0e57e000-0000-4000-8000-0000000000a2');

-- Uma segunda turma, de outra conta, para provar que o participante de uma
-- turma nao alcanca a turma alheia. A conta Beta existe so para isso.
insert into valor.contas (id, inquilino_id, nome, eh_cliente, eh_prospecto) values
 ('0e57e000-0000-4000-8000-0000000000c2','0e57e000-0000-4000-8000-000000000001','Conta Ficticia Beta', true, false);

insert into valor.programas (
  id, inquilino_id, conta_id, codigo, nome, ano, modalidade, status,
  responsavel_id, cadencia)
values ('0e57e000-0000-4000-8000-000000000022','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-0000000000c2','PRG-TESTE-GOV-2','Conselho de Valor dedicado · turma alheia',
        2026,'dedicada','ativo','0e57e000-0000-4000-8000-0000000000a3','semanal');

insert into valor.turmas (
  id, inquilino_id, programa_id, codigo, nome, status, cadencia, formato,
  facilitador_id, coordenador_id)
values ('0e57e000-0000-4000-8000-0000000000e2','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-000000000022','TRM-TESTE-GOV-2','Turma alheia de teste',
        'em_andamento','semanal','online',
        '0e57e000-0000-4000-8000-0000000000a3','0e57e000-0000-4000-8000-0000000000a2');

-- Cada participante na sua cadeira, em turmas diferentes.
insert into valor.participantes (
  id, inquilino_id, turma_id, conta_id, contato_id, usuario_id, nome, papel, cadeira)
values
 ('0e57e000-0000-4000-8000-000000000041','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000e1','0e57e000-0000-4000-8000-0000000000c1',
  '0e57e000-0000-4000-8000-0000000000d1','0e57e000-0000-4000-8000-0000000000a5',
  'Pessoa Cadeira da Turma','socio', 1),
 ('0e57e000-0000-4000-8000-000000000042','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000e2','0e57e000-0000-4000-8000-0000000000c2',
  null,'0e57e000-0000-4000-8000-0000000000a6',
  'Pessoa Cadeira de Outra Turma','socio', 1);

-- Uma ata na turma alheia, para o participante da turma 1 nao poder ler.
insert into valor.atas (
  id, inquilino_id, conta_id, turma_id, numero, titulo, data_reuniao, status, conteudo)
values ('0e57e000-0000-4000-8000-0000000000b9','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-0000000000c2','0e57e000-0000-4000-8000-0000000000e2',
        1,'Ata da turma alheia', date '2026-09-08','rascunho','{}'::jsonb);

-- ================================================================
-- PARTE 1 · a pendência que reaparece
-- ================================================================

\echo ''
\echo '================================================================'
\echo 'PARTE 1 · uma ata com duas pendencias, e a pre-pauta seguinte'
\echo '================================================================'

-- O assessor escreve a ata da reunião 1.
select set_config('app.usuario_id','0e57e000-0000-4000-8000-0000000000a2', true);
select set_config('app.perfil','assessor', true);

insert into valor.pautas (id, inquilino_id, conta_id, turma_id, encontro_id, numero, titulo, data_reuniao, status)
values ('0e57e000-0000-4000-8000-0000000000f1','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
        '0e57e000-0000-4000-8000-000000000031',
        1,'Conselho de Valor · reuniao 1', date '2026-09-08','publicada');

insert into valor.atas (
  id, inquilino_id, conta_id, pauta_id, modelo_ata_id, turma_id, encontro_id, numero, titulo,
  data_reuniao, status, conteudo)
select '0e57e000-0000-4000-8000-0000000000b1','0e57e000-0000-4000-8000-000000000001',
       '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000f1',
       m.id,'0e57e000-0000-4000-8000-0000000000e1',
       '0e57e000-0000-4000-8000-000000000031', 1,'Ata da reuniao 1',
       date '2026-09-08','rascunho',
       jsonb_build_object(
         'identificacao','Reuniao 1 do Conselho de Valor, em 08/09/2026',
         'participantes', jsonb_build_array('Pessoa Socia Um','Pessoa Socia Dois','Pessoa Conselheiro'),
         'pauta', jsonb_build_array('Indicadores do periodo','Caixa e margem'),
         'resumo_discussoes','Discussao sobre margem por linha de servico.',
         'deliberacoes', jsonb_build_array('Revisar a tabela de precos','Fechar o painel de caixa'),
         'proximos_passos', jsonb_build_array('Dois donos, dois prazos'),
         'proxima_reuniao','Em 22/09/2026')
from valor.modelos_ata m
where m.inquilino_id = '0e57e000-0000-4000-8000-000000000001' and m.padrao_da_casa;

-- Duas pendências nascem da mesma ata. Uma vai fechar, a outra vai continuar.
insert into valor.pendencias (
  id, inquilino_id, conta_id, turma_id, encontro_id, ata_id, ata_secao, origem,
  descricao, dono_usuario_id, dono_nome, prazo, status)
values
 ('0e57e000-0000-4000-8000-000000000091','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
  '0e57e000-0000-4000-8000-000000000031',
  '0e57e000-0000-4000-8000-0000000000b1','deliberacoes','deliberacao',
  'Revisar a tabela de precos da linha de servicos recorrentes',
  null,'Pessoa Socia Dois', date '2026-09-15','aberta'),
 ('0e57e000-0000-4000-8000-000000000092','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
  '0e57e000-0000-4000-8000-000000000031',
  '0e57e000-0000-4000-8000-0000000000b1','proximos_passos','proximo_passo',
  'Fechar o painel de caixa com projecao de doze meses',
  '0e57e000-0000-4000-8000-0000000000a3', null, date '2026-09-12','aberta');

-- O conselheiro aprova, e a ata sai.
select set_config('app.usuario_id','0e57e000-0000-4000-8000-0000000000a3', true);
select set_config('app.perfil','conselheiro', true);
update valor.atas set status = 'em_aprovacao' where id = '0e57e000-0000-4000-8000-0000000000b1';
update valor.atas set status = 'aprovada'     where id = '0e57e000-0000-4000-8000-0000000000b1';
update valor.atas set status = 'enviada', destinatarios = '["socios da conta"]'::jsonb
 where id = '0e57e000-0000-4000-8000-0000000000b1';

-- Uma das duas fecha, com data de conclusão e evidência.
update valor.pendencias
   set status = 'concluida', concluida_em = date '2026-09-11',
       evidencia = 'Painel publicado e conferido na reuniao de gestao'
 where id = '0e57e000-0000-4000-8000-000000000092';

\echo ''
\echo 'As duas pendencias da ata 1, uma concluida e uma aberta:'
select p.descricao,
       coalesce(u.nome, p.dono_nome) as dono,
       p.prazo, p.status, p.concluida_em
from valor.pendencias p
left join valor.usuarios u on u.id = p.dono_usuario_id
where p.ata_id = '0e57e000-0000-4000-8000-0000000000b1'
order by p.criado_em;

\echo ''
\echo 'A pre-pauta da reuniao seguinte, montada por valor.montar_pre_pauta:'
select ordem_item, bloco, tema, detalhe, dono, prazo, situacao,
       tempo_previsto_minutos, tipo
from valor.montar_pre_pauta('0e57e000-0000-4000-8000-0000000000e1', date '2026-09-22');

\echo ''
\echo 'So a pendencia aberta entrou no bloco de pendencia:'
select count(*) filter (where bloco = 'pendencia')     as pendencias_na_pre_pauta,
       count(*) filter (where bloco = 'tema_sugerido') as temas_sugeridos
from valor.montar_pre_pauta('0e57e000-0000-4000-8000-0000000000e1', date '2026-09-22');

do $$
declare
  qtd      integer;
  o_dono   text;
  o_prazo  date;
  o_texto  text;
begin
  select count(*) into qtd
  from valor.montar_pre_pauta('0e57e000-0000-4000-8000-0000000000e1', date '2026-09-22')
  where bloco = 'pendencia';
  if qtd <> 1 then
    raise exception 'REPROVADO: a pre-pauta trouxe % pendencias, esperava exatamente 1.', qtd;
  end if;

  select dono, prazo, detalhe into o_dono, o_prazo, o_texto
  from valor.montar_pre_pauta('0e57e000-0000-4000-8000-0000000000e1', date '2026-09-22')
  where bloco = 'pendencia';

  if o_texto not like 'Revisar a tabela de precos%' then
    raise exception 'REPROVADO: a pendencia que reapareceu nao e a que ficou aberta. Veio: %', o_texto;
  end if;
  if o_dono is null or o_prazo is null then
    raise exception 'REPROVADO: a pendencia reapareceu sem dono ou sem prazo.';
  end if;

  -- A pendência concluída não pode reaparecer de jeito nenhum.
  if exists (
    select 1 from valor.montar_pre_pauta('0e57e000-0000-4000-8000-0000000000e1', date '2026-09-22')
    where detalhe like 'Fechar o painel de caixa%'
  ) then
    raise exception 'REPROVADO: a pendencia concluida reapareceu na pre-pauta.';
  end if;

  raise notice 'APROVADO · so a pendencia aberta reapareceu, com dono % e prazo %.', o_dono, o_prazo;
end;
$$;

\echo ''
\echo 'A pauta da reuniao 2 nasce com a pendencia aberta ja dentro:'
select set_config('app.usuario_id','0e57e000-0000-4000-8000-0000000000a2', true);
select set_config('app.perfil','assessor', true);

insert into valor.pautas (id, inquilino_id, conta_id, turma_id, encontro_id, numero, titulo, data_reuniao, status)
values ('0e57e000-0000-4000-8000-0000000000f2','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
        '0e57e000-0000-4000-8000-000000000032',
        2,'Conselho de Valor · reuniao 2', date '2026-09-22','rascunho');

select i.ordem, i.tema, i.detalhe, i.responsavel_nome as dono,
       i.origem, i.automatico, i.tempo_previsto_minutos
from valor.pautas_itens i
where i.pauta_id = '0e57e000-0000-4000-8000-0000000000f2'
order by i.ordem;

do $$
declare qtd integer;
begin
  select count(*) into qtd from valor.pautas_itens
  where pauta_id = '0e57e000-0000-4000-8000-0000000000f2'
    and origem = 'pendencia_aberta' and automatico;
  if qtd <> 1 then
    raise exception 'REPROVADO: a pauta nova nasceu com % itens automaticos, esperava 1.', qtd;
  end if;
  raise notice 'APROVADO · a pendencia aberta entrou sozinha na pauta da reuniao seguinte.';
end;
$$;

-- ================================================================
-- PARTE 2 · o NPS
-- ================================================================

\echo ''
\echo '================================================================'
\echo 'PARTE 2 · uma rodada de NPS com cinco respondentes ficticios'
\echo '================================================================'

select set_config('app.usuario_id','0e57e000-0000-4000-8000-0000000000a1', true);
select set_config('app.perfil','lider', true);

insert into valor.pesquisas (id, inquilino_id, conta_id, turma_id, programa_id, tipo, titulo, periodo,
  periodo_inicio, periodo_fim, publico_alvo, status, abertura_em, fechamento_em)
values
 ('0e57e000-0000-4000-8000-000000000071','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
  '0e57e000-0000-4000-8000-000000000021','nps_trimestral','NPS 2026 · segundo trimestre','2026-T2',
  date '2026-04-01', date '2026-06-30','Socios e diretores da conta','fechada',
  timestamptz '2026-06-20 09:00', timestamptz '2026-06-30 18:00'),
 ('0e57e000-0000-4000-8000-000000000072','0e57e000-0000-4000-8000-000000000001',
  '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
  '0e57e000-0000-4000-8000-000000000021','nps_trimestral','NPS 2026 · terceiro trimestre','2026-T3',
  date '2026-07-01', date '2026-09-30','Socios e diretores da conta','aberta',
  timestamptz '2026-09-15 09:00', null);

select valor.semear_questoes_nps('0e57e000-0000-4000-8000-000000000071') as questoes_do_segundo_trimestre;
select valor.semear_questoes_nps('0e57e000-0000-4000-8000-000000000072') as questoes_do_terceiro_trimestre;

\echo ''
\echo 'O instrumento da casa, bloco a bloco:'
select ordem, bloco, tipo, eh_pergunta_classica, enunciado
from valor.pesquisas_questoes
where pesquisa_id = '0e57e000-0000-4000-8000-000000000072'
order by ordem;

-- Rodada anterior: a Pessoa Socia Um deu 3, nota de detratora.
-- Serve para provar que a última nota vence, e que a média não entra na conta.
insert into valor.respostas (inquilino_id, pesquisa_id, questao_id, conta_id, contato_id, nota, respondida_em)
select '0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-000000000071', q.id,
       '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000d1',
       3, timestamptz '2026-06-25 10:00'
from valor.pesquisas_questoes q
where q.pesquisa_id = '0e57e000-0000-4000-8000-000000000071' and q.eh_pergunta_classica;

-- Rodada atual: cinco respondentes, e a Pessoa Socia Um agora dá 10.
insert into valor.respostas (inquilino_id, pesquisa_id, questao_id, conta_id, contato_id, nota, respondida_em)
select '0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-000000000072', q.id,
       '0e57e000-0000-4000-8000-0000000000c1', v.contato, v.nota, v.quando
from valor.pesquisas_questoes q
cross join (values
  ('0e57e000-0000-4000-8000-0000000000d1'::uuid, 10::smallint, timestamptz '2026-09-16 09:10'),
  ('0e57e000-0000-4000-8000-0000000000d2'::uuid,  9::smallint, timestamptz '2026-09-16 11:30'),
  ('0e57e000-0000-4000-8000-0000000000d3'::uuid,  9::smallint, timestamptz '2026-09-17 08:45'),
  ('0e57e000-0000-4000-8000-0000000000d4'::uuid,  7::smallint, timestamptz '2026-09-17 14:20'),
  ('0e57e000-0000-4000-8000-0000000000d5'::uuid,  3::smallint, timestamptz '2026-09-18 16:05')
) as v(contato, nota, quando)
where q.pesquisa_id = '0e57e000-0000-4000-8000-000000000072' and q.eh_pergunta_classica;

-- A motivação escrita de cada um, que a visão carrega ao lado da nota.
insert into valor.respostas (inquilino_id, pesquisa_id, questao_id, conta_id, contato_id, texto, respondida_em)
select '0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-000000000072', q.id,
       '0e57e000-0000-4000-8000-0000000000c1', v.contato, v.texto, v.quando
from valor.pesquisas_questoes q
cross join (values
  ('0e57e000-0000-4000-8000-0000000000d1'::uuid,'O conselho mudou a forma como decidimos preco.', timestamptz '2026-09-16 09:11'),
  ('0e57e000-0000-4000-8000-0000000000d2'::uuid,'Cadencia em dia e pauta sempre pronta.',         timestamptz '2026-09-16 11:31'),
  ('0e57e000-0000-4000-8000-0000000000d3'::uuid,'A leitura de numero puxou decisao que estava parada.', timestamptz '2026-09-17 08:46'),
  ('0e57e000-0000-4000-8000-0000000000d4'::uuid,'Bom, mas a ata poderia sair mais rapido.',       timestamptz '2026-09-17 14:21'),
  ('0e57e000-0000-4000-8000-0000000000d5'::uuid,'Sinto pouca conexao com a minha area.',          timestamptz '2026-09-18 16:06')
) as v(contato, texto, quando)
where q.pesquisa_id = '0e57e000-0000-4000-8000-000000000072'
  and q.bloco = 'recomendacao' and q.tipo = 'texto_livre';

\echo ''
\echo 'valor.nps_por_conta · a ultima nota de cada pessoa, a data, a motivacao e o calculo:'
select respondente, nota, data_da_nota, faixa, motivacao,
       respondentes, promotores, neutros, detratores, nps
from valor.nps_por_conta
order by nota desc, respondente;

\echo ''
\echo 'A Pessoa Socia Um respondeu duas vezes. A visao pega a ultima, nao a media:'
select p.periodo, r.respondida_em::date as data, r.nota
from valor.respostas r
join valor.pesquisas_questoes q on q.id = r.questao_id and q.eh_pergunta_classica
join valor.pesquisas p on p.id = r.pesquisa_id
where r.contato_id = '0e57e000-0000-4000-8000-0000000000d1'
order by r.respondida_em;

select respondente, nota as nota_considerada, data_da_nota, faixa
from valor.nps_por_conta
where respondente = 'Pessoa Socia Um';

\echo ''
\echo 'Consolidado da conta:'
select respondentes, promotores, neutros, detratores, nps, ultima_resposta
from valor.nps_consolidado_por_conta;

do $$
declare
  r record;
  nota_da_socia smallint;
begin
  select * into r from valor.nps_consolidado_por_conta
  where conta_id = '0e57e000-0000-4000-8000-0000000000c1';

  if r.respondentes <> 5 then
    raise exception 'REPROVADO: % respondentes na conta, esperava 5.', r.respondentes;
  end if;
  if r.promotores <> 3 or r.neutros <> 1 or r.detratores <> 1 then
    raise exception 'REPROVADO: promotores %, neutros %, detratores %. Esperava 3, 1 e 1.',
      r.promotores, r.neutros, r.detratores;
  end if;
  -- Notas 10, 9, 9, 7 e 3: tres promotores, um neutro, um detrator, NPS 40,0.
  if r.nps <> 40.0 then
    raise exception 'REPROVADO: NPS %, esperava 40,0.', r.nps;
  end if;

  -- A prova de que não é média: a Pessoa Socia Um deu 3 e depois 10. Pela média
  -- ela seria detratora, com 6,5, e o NPS da conta cairia para 0,0.
  select nota into nota_da_socia from valor.nps_por_conta
  where respondente = 'Pessoa Socia Um';
  if nota_da_socia <> 10 then
    raise exception 'REPROVADO: a pessoa entrou com nota %, esperava a ultima, que e 10.', nota_da_socia;
  end if;

  if not exists (
    select 1 from valor.nps_por_conta
    where respondente = 'Pessoa Socia Um' and motivacao is not null
  ) then
    raise exception 'REPROVADO: a ultima nota veio sem a motivacao escrita.';
  end if;

  raise notice 'APROVADO · NPS % com % promotores, % neutros e % detratores, cada pessoa com a ultima nota.',
    r.nps, r.promotores, r.neutros, r.detratores;
end;
$$;


-- ================================================================
-- PARTE 3 · o perfil participante
-- ================================================================

\echo ''
\echo '================================================================'
\echo 'PARTE 3 · o que o participante le e o que nao le'
\echo '================================================================'

-- Uma ata restrita na turma do participante, para provar que ela nao chega nele.
select set_config('app.usuario_id','0e57e000-0000-4000-8000-0000000000a2', true);
select set_config('app.perfil','assessor', true);
insert into valor.atas (
  id, inquilino_id, conta_id, turma_id, encontro_id, numero, titulo,
  data_reuniao, status, restrita, conteudo)
values ('0e57e000-0000-4000-8000-0000000000b2','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
        '0e57e000-0000-4000-8000-000000000032', 9,'Ata restrita sobre pessoas do cliente',
        date '2026-09-22','rascunho', true,'{"identificacao":"Sessao reservada"}'::jsonb);

-- Uma pendencia nascida dessa ata restrita. Ela e da turma do participante, mas
-- veio de reuniao sobre pessoas do cliente, entao nao pode chegar nele.
insert into valor.pendencias (
  id, inquilino_id, conta_id, turma_id, ata_id, ata_secao, origem,
  descricao, dono_nome, prazo, status)
values ('0e57e000-0000-4000-8000-000000000093','0e57e000-0000-4000-8000-000000000001',
        '0e57e000-0000-4000-8000-0000000000c1','0e57e000-0000-4000-8000-0000000000e1',
        '0e57e000-0000-4000-8000-0000000000b2','deliberacoes','deliberacao',
        'Tratativa reservada sobre o quadro de lideranca','Pessoa Lider', date '2026-10-15','aberta');

select set_config('app.usuario_id','0e57e000-0000-4000-8000-0000000000a5', true);
select set_config('app.perfil','participante', true);

\echo ''
\echo 'As atas que o participante da turma 1 enxerga:'
select numero, titulo, restrita, turma_id = '0e57e000-0000-4000-8000-0000000000e1' as eh_da_minha_turma
from valor.atas order by numero;

\echo ''
\echo 'O que o participante enxerga em cada tabela do meu dominio:'
select 'atas'                   as tabela, count(*) as linhas from valor.atas
union all select 'pautas',                 count(*) from valor.pautas
union all select 'pendencias',             count(*) from valor.pendencias
union all select 'pautas_itens',           count(*) from valor.pautas_itens
union all select 'banco_pautas',           count(*) from valor.banco_pautas
union all select 'modelos_ata',            count(*) from valor.modelos_ata
union all select 'modelos_ata_por_conta',  count(*) from valor.modelos_ata_por_conta
union all select 'pesquisas',              count(*) from valor.pesquisas
union all select 'pesquisas_questoes',     count(*) from valor.pesquisas_questoes
union all select 'respostas',              count(*) from valor.respostas
union all select 'avaliacoes_conselheiro', count(*) from valor.avaliacoes_conselheiro
union all select 'ciclos_avaliacao',       count(*) from valor.ciclos_avaliacao
union all select 'nps_por_conta',          count(*) from valor.nps_por_conta
order by 1;

do $$
declare
  minhas       integer;
  alheias      integer;
  restritas    integer;
  interno      integer;
  apuracao     integer;
begin
  -- 1 · le a ata nao restrita da propria turma
  select count(*) into minhas from valor.atas
  where turma_id = '0e57e000-0000-4000-8000-0000000000e1' and not restrita;
  if minhas < 1 then
    raise exception 'REPROVADO: o participante ficou cego na propria turma, leu % atas.', minhas;
  end if;

  -- 2 · nao le nada de turma alheia
  select count(*) into alheias from valor.atas
  where turma_id is distinct from '0e57e000-0000-4000-8000-0000000000e1';
  if alheias <> 0 then
    raise exception 'REPROVADO: o participante leu % atas de turma alheia, esperava 0.', alheias;
  end if;

  -- 3 · nao le a ata restrita nem da propria turma
  select count(*) into restritas from valor.atas where restrita;
  if restritas <> 0 then
    raise exception 'REPROVADO: o participante leu % atas restritas, esperava 0.', restritas;
  end if;

  -- 4 · nao le a pendencia nascida de ata restrita, mesmo sendo da turma dele
  if exists (select 1 from valor.pendencias
             where ata_id = '0e57e000-0000-4000-8000-0000000000b2') then
    raise exception 'REPROVADO: o participante leu pendencia nascida de ata restrita.';
  end if;
  if (select count(*) from valor.pendencias) <> 2 then
    raise exception 'REPROVADO: o participante leu % pendencias, esperava as 2 da ata aberta.',
      (select count(*) from valor.pendencias);
  end if;

  -- 5 · nao le material interno da casa
  select (select count(*) from valor.banco_pautas)
       + (select count(*) from valor.modelos_ata)
       + (select count(*) from valor.modelos_ata_por_conta)
       + (select count(*) from valor.pautas_itens)
    into interno;
  if interno <> 0 then
    raise exception 'REPROVADO: o participante leu % linhas de material interno, esperava 0.', interno;
  end if;

  -- 6 · nao le apuracao de pesquisa nem avaliacao de pessoa
  select (select count(*) from valor.respostas)
       + (select count(*) from valor.pesquisas)
       + (select count(*) from valor.pesquisas_questoes)
       + (select count(*) from valor.avaliacoes_conselheiro)
       + (select count(*) from valor.ciclos_avaliacao)
       + (select count(*) from valor.nps_por_conta)
    into apuracao;
  if apuracao <> 0 then
    raise exception 'REPROVADO: o participante leu % linhas de apuracao, esperava 0.', apuracao;
  end if;

  raise notice 'APROVADO · participante le % ata da propria turma, 0 de turma alheia, 0 restrita, 0 interna, 0 de apuracao.', minhas;
end;
$$;

\echo ''
\echo 'O participante tenta escrever no rito:'
do $$
begin
  insert into valor.pendencias (inquilino_id, conta_id, turma_id, descricao, dono_nome)
  values ('0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-0000000000c1',
          '0e57e000-0000-4000-8000-0000000000e1','Tentativa do participante','Pessoa Cadeira da Turma');
  raise exception 'REPROVADO: o participante gravou pendencia';
exception
  when insufficient_privilege or check_violation then
    raise notice 'BLOQUEADO como esperado: %', sqlerrm;
  when others then
    if sqlerrm like '%row-level security%' then
      raise notice 'BLOQUEADO como esperado: %', sqlerrm;
    else
      raise;
    end if;
end;
$$;

do $$
begin
  insert into valor.atas (inquilino_id, conta_id, turma_id, numero, data_reuniao, status, conteudo)
  values ('0e57e000-0000-4000-8000-000000000001','0e57e000-0000-4000-8000-0000000000c1',
          '0e57e000-0000-4000-8000-0000000000e1', 77, date '2026-09-22','rascunho','{}');
  raise exception 'REPROVADO: o participante gravou ata';
exception
  when others then
    if sqlerrm like '%row-level security%' then
      raise notice 'BLOQUEADO como esperado: %', sqlerrm;
    else
      raise;
    end if;
end;
$$;

\echo ''
\echo 'E o participante da turma alheia enxerga a turma dele, e so ela:'
select set_config('app.usuario_id','0e57e000-0000-4000-8000-0000000000a6', true);
select set_config('app.perfil','participante', true);
select numero, titulo, turma_id = '0e57e000-0000-4000-8000-0000000000e2' as eh_da_minha_turma
from valor.atas order by numero;

do $$
declare qtd integer; fora integer;
begin
  select count(*) into qtd  from valor.atas where turma_id = '0e57e000-0000-4000-8000-0000000000e2';
  select count(*) into fora from valor.atas where turma_id is distinct from '0e57e000-0000-4000-8000-0000000000e2';
  if qtd < 1 then
    raise exception 'REPROVADO: o participante da turma alheia ficou cego, leu % atas.', qtd;
  end if;
  if fora <> 0 then
    raise exception 'REPROVADO: o participante da turma alheia leu % atas de fora, esperava 0.', fora;
  end if;
  raise notice 'APROVADO · cada participante enxerga a propria turma e nenhuma outra.';
end;
$$;

\echo ''
\echo '================================================================'
\echo 'Teste de regressao concluido. O rollback abaixo nao deixa dado no banco.'
\echo '================================================================'

reset role;
rollback;
