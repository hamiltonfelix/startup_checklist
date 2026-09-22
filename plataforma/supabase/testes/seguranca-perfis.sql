-- Teste de regressão · o que cada perfil enxerga, o que cada perfil grava
-- Dono: auditor de segurança. Nenhum outro agente altera este arquivo.
--
-- Como rodar, num banco onde as migrações já aplicaram:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d fab -f testes/seguranca-perfis.sql
--
-- O teste inteiro vive dentro de uma transação e desfaz tudo no final. Pode
-- rodar quantas vezes quiser, no mesmo banco, sem deixar resíduo.
--
-- Todo dado aqui é fictício, com nome inventado e domínio .invalido. Nenhuma
-- conta, nenhum contrato, nenhum valor e nenhuma pessoa de verdade.
--
-- Por que este teste existe. A plataforma tem dez perfis no enum, e por muito
-- tempo quase toda política de linha foi escrita como `not valor.eh_parceiro()`,
-- que nomeia quem não pode em vez de nomear quem pode. Enquanto o único perfil
-- de fora era o parceiro isso funcionava. Quando o perfil `participante` entrou,
-- que é a pessoa do cliente ocupando cadeira numa turma, toda essa política
-- passou a valer para ele sem que ninguém tivesse decidido, inclusive as de
-- escrita: gente do cliente gravava conta e negócio no CRM. Este arquivo existe
-- para que um perfil novo no enum nunca mais entre por omissão, e para que a
-- resposta de cada perfil seja um número escrito, conferido e defendido.
--
-- A carga entra como dono do banco, que ignora a segurança de linha de
-- propósito. Toda conferência roda com `set role valor_aplicacao`, que é o papel
-- sem privilégio que o aplicativo usa de verdade, porque o dono aprovaria até
-- uma política quebrada.
--
-- Cada bloco carrega dado nas duas pontas. Contar zero em tabela vazia não prova
-- nada, então nenhuma tabela conferida aqui está vazia, e para cada zero
-- esperado existe pelo menos uma linha que outro perfil enxerga.

\set ON_ERROR_STOP on
\pset border 2
\pset null 'nulo'

begin;

-- ---------------------------------------------------------------- os dois inquilinos

insert into valor.inquilinos (id, nome, apelido) values
  ('a0a00000-0000-4000-8000-000000000001', 'Casa de Prova dos Perfis', 'prova-perfis'),
  ('b0b00000-0000-4000-8000-000000000001', 'Casa Vizinha de Prova', 'prova-vizinha');

-- Uma pessoa por perfil, mais uma segunda participante, sentada em outra turma.
insert into valor.usuarios (id, inquilino_id, email, nome, perfil) values
 ('a0a00000-0000-4000-8000-000000000011','a0a00000-0000-4000-8000-000000000001','admin@exemplo.invalido','Pessoa Administradora','admin_master'),
 ('a0a00000-0000-4000-8000-000000000012','a0a00000-0000-4000-8000-000000000001','lider@exemplo.invalido','Pessoa Líder','lider'),
 ('a0a00000-0000-4000-8000-000000000013','a0a00000-0000-4000-8000-000000000001','comercial@exemplo.invalido','Pessoa Comercial','comercial'),
 ('a0a00000-0000-4000-8000-000000000014','a0a00000-0000-4000-8000-000000000001','gerente@exemplo.invalido','Pessoa Gerente de Contas','gerente_contas'),
 ('a0a00000-0000-4000-8000-000000000015','a0a00000-0000-4000-8000-000000000001','conselheiro@exemplo.invalido','Pessoa Conselheira','conselheiro'),
 ('a0a00000-0000-4000-8000-000000000016','a0a00000-0000-4000-8000-000000000001','assessor@exemplo.invalido','Pessoa Assessora','assessor'),
 ('a0a00000-0000-4000-8000-000000000017','a0a00000-0000-4000-8000-000000000001','financeiro@exemplo.invalido','Pessoa Financeira','financeiro'),
 ('a0a00000-0000-4000-8000-000000000018','a0a00000-0000-4000-8000-000000000001','parceiro@exemplo.invalido','Pessoa Parceira','parceiro'),
 ('a0a00000-0000-4000-8000-000000000019','a0a00000-0000-4000-8000-000000000001','participante1@exemplo.invalido','Pessoa Participante Um','participante'),
 ('a0a00000-0000-4000-8000-00000000001a','a0a00000-0000-4000-8000-000000000001','emergencia@exemplo.invalido','Pessoa de Emergência','emergencia'),
 ('a0a00000-0000-4000-8000-00000000001b','a0a00000-0000-4000-8000-000000000001','participante2@exemplo.invalido','Pessoa Participante Dois','participante'),
 ('b0b00000-0000-4000-8000-000000000011','b0b00000-0000-4000-8000-000000000001','admin@vizinha.invalido','Pessoa Administradora Vizinha','admin_master');

insert into valor.contas (id, inquilino_id, nome, gerente_contas_id, eh_cliente) values
 ('a0a00000-0000-4000-8000-0000000000c1','a0a00000-0000-4000-8000-000000000001','Conta Fictícia Um','a0a00000-0000-4000-8000-000000000014', true),
 ('a0a00000-0000-4000-8000-0000000000c2','a0a00000-0000-4000-8000-000000000001','Conta Fictícia Dois', null, true),
 ('b0b00000-0000-4000-8000-0000000000c1','b0b00000-0000-4000-8000-000000000001','Conta da Vizinha', null, true);

insert into valor.parceiros (id, inquilino_id, nome, tipo, status, credenciado_em) values
 ('a0a00000-0000-4000-8000-0000000000f1','a0a00000-0000-4000-8000-000000000001','Parceiro Fictício Um','indicador','ativo', date '2026-01-02'),
 ('a0a00000-0000-4000-8000-0000000000f2','a0a00000-0000-4000-8000-000000000001','Parceiro Fictício Dois','indicador','ativo', date '2026-01-03');

insert into valor.parceiros_usuarios (inquilino_id, parceiro_id, usuario_id, principal) values
 ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000f1','a0a00000-0000-4000-8000-000000000018', true);

-- Três negócios: um de cada parceiro, e um sem parceiro nenhum. É essa terceira
-- linha que transforma o zero do parceiro em prova, e não em coincidência.
insert into valor.negocios (id, inquilino_id, conta_id, parceiro_id, titulo, valor_total) values
 ('a0a00000-0000-4000-8000-0000000000d1','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','a0a00000-0000-4000-8000-0000000000f1','Negócio do parceiro um', 100000),
 ('a0a00000-0000-4000-8000-0000000000d2','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c2','a0a00000-0000-4000-8000-0000000000f2','Negócio do parceiro dois', 200000),
 ('a0a00000-0000-4000-8000-0000000000d3','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1', null,'Negócio sem parceiro', 300000),
 ('b0b00000-0000-4000-8000-0000000000d1','b0b00000-0000-4000-8000-000000000001','b0b00000-0000-4000-8000-0000000000c1', null,'Negócio da vizinha', 400000);

insert into valor.contatos (id, inquilino_id, conta_id, nome) values
 ('a0a00000-0000-4000-8000-000000000101','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','Contato Fictício Um'),
 ('a0a00000-0000-4000-8000-000000000102','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c2','Contato Fictício Dois');

-- Uma conversa reservada e uma comum, para o recorte de confidencial morder.
insert into valor.interacoes (id, inquilino_id, conta_id, negocio_id, assunto, restrita) values
 ('a0a00000-0000-4000-8000-000000000201','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','a0a00000-0000-4000-8000-0000000000d1','Conversa reservada', true),
 ('a0a00000-0000-4000-8000-000000000202','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c2','a0a00000-0000-4000-8000-0000000000d2','Conversa comum', false);

insert into valor.artefatos (id, inquilino_id, negocio_id, tipo) values
 ('a0a00000-0000-4000-8000-000000000301','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d1','plano_conta'),
 ('a0a00000-0000-4000-8000-000000000302','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d1','plano_negocio'),
 ('a0a00000-0000-4000-8000-000000000303','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d2','plano_conta');

-- O papel no negócio é o que leva o conselheiro ao contrato da conta dele e ao
-- programa dela. Sem ele, metade das linhas abaixo daria zero por falta de
-- vínculo, e não por política.
insert into valor.papeis_negocio (id, inquilino_id, negocio_id, usuario_id, papel) values
 ('a0a00000-0000-4000-8000-000000000401','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d1','a0a00000-0000-4000-8000-000000000015','conselheiro'),
 ('a0a00000-0000-4000-8000-000000000402','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d1','a0a00000-0000-4000-8000-000000000014','gerente_contas'),
 ('a0a00000-0000-4000-8000-000000000403','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d2','a0a00000-0000-4000-8000-000000000013','pre_vendas');

insert into valor.indicacoes (id, inquilino_id, parceiro_id, conta_indicada_nome, contato_nome, contexto) values
 ('a0a00000-0000-4000-8000-000000000501','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000f1','Empresa Indicada Um','Contato Um','Indicação fictícia um'),
 ('a0a00000-0000-4000-8000-000000000502','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000f2','Empresa Indicada Dois','Contato Dois','Indicação fictícia dois');

insert into valor.contratos (id, inquilino_id, conta_id, negocio_id, numero, vigencia_inicio, situacao, assinado, assinado_em) values
 ('a0a00000-0000-4000-8000-000000000601','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','a0a00000-0000-4000-8000-0000000000d1','CT-9001', date '2026-01-05','vigente', true, date '2026-01-04'),
 ('a0a00000-0000-4000-8000-000000000602','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c2','a0a00000-0000-4000-8000-0000000000d2','CT-9002', date '2026-01-06','vigente', true, date '2026-01-05');

insert into valor.parcelas (id, inquilino_id, contrato_id, numero, competencia, vencimento, valor_bruto, status) values
 ('a0a00000-0000-4000-8000-000000000701','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000601',1, date '2026-02-01', date '2026-02-10', 10000, 'prevista'),
 ('a0a00000-0000-4000-8000-000000000702','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000602',1, date '2026-02-01', date '2026-02-10', 20000, 'prevista');

insert into valor.contratos_conselheiros (id, inquilino_id, contrato_id, usuario_id, modelo, percentual) values
 ('a0a00000-0000-4000-8000-000000000801','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000601','a0a00000-0000-4000-8000-000000000015','percentual_contrato', 20);

-- Uma comissão de cada beneficiário, para cada um enxergar a própria e só ela.
insert into valor.comissoes (id, inquilino_id, beneficiario_tipo, usuario_id, parceiro_id, contrato_id, parcela_id,
                             valor_bruto, imposto_percentual, imposto_valor, base_calculo, valor, competencia) values
 ('a0a00000-0000-4000-8000-000000000901','a0a00000-0000-4000-8000-000000000001','vendedor_interno','a0a00000-0000-4000-8000-000000000014', null,'a0a00000-0000-4000-8000-000000000601','a0a00000-0000-4000-8000-000000000701',10000,15,1500,8500, 850, date '2026-02-01'),
 ('a0a00000-0000-4000-8000-000000000902','a0a00000-0000-4000-8000-000000000001','parceiro', null,'a0a00000-0000-4000-8000-0000000000f1','a0a00000-0000-4000-8000-000000000601','a0a00000-0000-4000-8000-000000000701',10000,15,1500,8500, 850, date '2026-02-01'),
 ('a0a00000-0000-4000-8000-000000000903','a0a00000-0000-4000-8000-000000000001','conselheiro','a0a00000-0000-4000-8000-000000000015', null,'a0a00000-0000-4000-8000-000000000601','a0a00000-0000-4000-8000-000000000701',10000,15,1500,8500,1700, date '2026-02-01');

insert into valor.percentuais_padrao (id, inquilino_id, escopo, vigencia_inicio,
                                      imposto_percentual, comissao_vendedor_percentual, comissao_parceiro_percentual) values
 ('a0a00000-0000-4000-8000-000000000a01','a0a00000-0000-4000-8000-000000000001','inquilino', date '2026-01-01', 15, 10, 10);

-- Dois programas com uma turma cada. A segunda turma existe para provar que o
-- participante de uma não alcança a outra.
insert into valor.programas (id, inquilino_id, conta_id, negocio_id, codigo, nome, modalidade, status, responsavel_id) values
 ('a0a00000-0000-4000-8000-000000000b01','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','a0a00000-0000-4000-8000-0000000000d1','prog-prova-um','Programa Fictício Um','compartilhada','ativo','a0a00000-0000-4000-8000-000000000016'),
 ('a0a00000-0000-4000-8000-000000000b02','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c2','a0a00000-0000-4000-8000-0000000000d2','prog-prova-dois','Programa Fictício Dois','dedicada','ativo', null);

insert into valor.turmas (id, inquilino_id, programa_id, codigo, nome, status, facilitador_id) values
 ('a0a00000-0000-4000-8000-000000000e01','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000b01','turma-prova-um','Turma Fictícia Um','em_andamento','a0a00000-0000-4000-8000-000000000016'),
 ('a0a00000-0000-4000-8000-000000000e02','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000b02','turma-prova-dois','Turma Fictícia Dois','em_andamento', null);

insert into valor.turmas_contas (id, inquilino_id, turma_id, conta_id) values
 ('a0a00000-0000-4000-8000-000000001001','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01','a0a00000-0000-4000-8000-0000000000c1'),
 ('a0a00000-0000-4000-8000-000000001002','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e02','a0a00000-0000-4000-8000-0000000000c2');

insert into valor.participantes (id, inquilino_id, turma_id, conta_id, usuario_id, nome, papel, status) values
 ('a0a00000-0000-4000-8000-000000001101','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01','a0a00000-0000-4000-8000-0000000000c1','a0a00000-0000-4000-8000-000000000019','Pessoa Participante Um','socio','ativo'),
 ('a0a00000-0000-4000-8000-000000001102','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e02','a0a00000-0000-4000-8000-0000000000c2','a0a00000-0000-4000-8000-00000000001b','Pessoa Participante Dois','socio','ativo');

-- Na turma um, um encontro aberto e um reservado, e um entregável visível ao
-- cliente e um interno. É esse par que separa o portal do participante do que é
-- da cozinha da casa.
insert into valor.encontros (id, inquilino_id, turma_id, numero, tema, data_prevista, restrito) values
 ('a0a00000-0000-4000-8000-000000001201','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01',1,'Encontro aberto da turma um', date '2026-03-02', false),
 ('a0a00000-0000-4000-8000-000000001202','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01',2,'Encontro reservado da turma um', date '2026-03-09', true),
 ('a0a00000-0000-4000-8000-000000001203','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e02',1,'Encontro aberto da turma dois', date '2026-03-03', false);

insert into valor.entregaveis (id, inquilino_id, turma_id, titulo, visivel_ao_cliente) values
 ('a0a00000-0000-4000-8000-000000001301','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01','Entregável aberto da turma um', true),
 ('a0a00000-0000-4000-8000-000000001302','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01','Entregável interno da turma um', false),
 ('a0a00000-0000-4000-8000-000000001303','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e02','Entregável aberto da turma dois', true);

insert into valor.atividades (id, inquilino_id, titulo, estado) values
 ('a0a00000-0000-4000-8000-000000001401','a0a00000-0000-4000-8000-000000000001','Atividade fictícia um','entrada'),
 ('a0a00000-0000-4000-8000-000000001402','a0a00000-0000-4000-8000-000000000001','Atividade fictícia dois','proxima_acao'),
 ('b0b00000-0000-4000-8000-000000001401','b0b00000-0000-4000-8000-000000000001','Atividade da vizinha','entrada');

insert into valor.regras_alerta (id, inquilino_id, codigo, nome, entidade_alvo, tipo_condicao, condicao_jsonb) values
 ('a0a00000-0000-4000-8000-000000001501','a0a00000-0000-4000-8000-000000000001','regra-de-prova','Regra Fictícia de Prova','negocio','jsonb','{"campo": "fase", "operador": "igual", "valor": 1}'::jsonb);

insert into valor.alertas (id, inquilino_id, regra_id, entidade, entidade_chave, mensagem) values
 ('a0a00000-0000-4000-8000-000000001601','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000001501','negocio','a0a00000-0000-4000-8000-0000000000d1','Alerta fictício um'),
 ('a0a00000-0000-4000-8000-000000001602','a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000001501','negocio','a0a00000-0000-4000-8000-0000000000d2','Alerta fictício dois');

insert into valor.ofertas (id, inquilino_id, codigo, nome, familia, modalidade) values
 ('a0a00000-0000-4000-8000-000000001701','a0a00000-0000-4000-8000-000000000001','oferta-de-prova','Oferta Fictícia de Prova','Família Fictícia','recorrente'),
 ('b0b00000-0000-4000-8000-000000001701','b0b00000-0000-4000-8000-000000000001','oferta-da-vizinha','Oferta da Vizinha','Família Fictícia','recorrente');

insert into valor.configuracoes (id, inquilino_id, chave, valor, rotulo) values
 ('a0a00000-0000-4000-8000-000000001801','a0a00000-0000-4000-8000-000000000001','prova.chave_ficticia','{"valor": 1}'::jsonb,'Chave fictícia de prova'),
 ('b0b00000-0000-4000-8000-000000001801','b0b00000-0000-4000-8000-000000000001','prova.chave_ficticia','{"valor": 2}'::jsonb,'Chave fictícia da vizinha');

-- valor.historico_fases não é semeado à mão. O gatilho registra_fase_ao_nascer
-- grava uma linha por negócio que entra, então o inquilino de prova tem três.

-- ------------------------------------------------ 0 · controle da carga
-- Sem este bloco, todo zero adiante seria zero de tabela vazia.

do $$
declare v_qtd integer;
begin
  select count(*) into v_qtd from valor.negocios where inquilino_id = 'a0a00000-0000-4000-8000-000000000001';
  if v_qtd <> 3 then
    raise exception 'REPROVADO: a carga do inquilino de prova falhou, o dono do banco enxerga % negócios e esperava 3.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.historico_fases where inquilino_id = 'a0a00000-0000-4000-8000-000000000001';
  if v_qtd <> 3 then
    raise exception 'REPROVADO: o gatilho de fase deveria ter gravado 3 linhas de histórico e gravou %.', v_qtd;
  end if;
  raise notice 'APROVADO · a carga entrou nas duas pontas, então os zeros adiante significam alguma coisa.';
end $$;

-- ------------------------------------------------ 1 · o que cada perfil enxerga
-- Uma linha por tabela, uma coluna por perfil, e o número é a resposta esperada.
-- Colunas, na ordem: administrador, líder, comercial, gerente de contas,
-- conselheiro, assessor, financeiro, parceiro, participante, emergência.

create temporary table esperado_leitura (
  tabela text primary key,
  adm integer not null, lid integer not null, com integer not null, ger integer not null,
  con integer not null, ass integer not null, fin integer not null, par integer not null,
  pai integer not null, eme integer not null,
  porque text not null
) on commit drop;

insert into esperado_leitura values
 ('usuarios',               11,11,11,11,11,11,11, 0, 0,11, 'O time da casa conhece o time. Gente de fora não conhece o time por dentro.'),
 ('contas',                  2, 2, 2, 2, 2, 2, 2, 1, 0, 2, 'O parceiro alcança só a conta do negócio que ele indicou. O participante não alcança o CRM.'),
 ('contatos',                2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 'A agenda do cliente é da casa. Quem indica não fica com ela, e quem senta na turma também não.'),
 ('negocios',                3, 3, 3, 3, 3, 3, 3, 1, 0, 3, 'O parceiro enxerga o próprio negócio, não o do outro parceiro nem o que nasceu sem parceiro.'),
 ('interacoes',              2, 2, 1, 1, 1, 1, 2, 0, 0, 2, 'A conversa reservada é só de quem vê confidencial. As demais são de toda a casa. Gente de fora não lê nenhuma.'),
 ('artefatos',               3, 3, 3, 3, 3, 3, 3, 2, 0, 3, 'O artefato segue a visibilidade do negócio, então o parceiro vê os dois do negócio dele.'),
 ('papeis_negocio',          3, 3, 3, 3, 3, 3, 3, 2, 0, 3, 'O papel segue a visibilidade do negócio, pela mesma função.'),
 ('parceiros',               2, 2, 2, 2, 2, 2, 2, 1, 0, 2, 'O parceiro enxerga o próprio cadastro e jamais o de outro parceiro. O participante não enxerga cadastro nenhum.'),
 ('indicacoes',              2, 2, 2, 2, 2, 2, 2, 1, 0, 2, 'Cada parceiro enxerga apenas as indicações que ele mesmo registrou.'),
 ('contratos',               2, 2, 2, 2, 1, 2, 2, 0, 0, 2, 'O conselheiro entra só no contrato da conta em que ele tem papel. Parceiro e participante ficam fora do faturamento.'),
 ('parcelas',                2, 2, 2, 2, 1, 2, 2, 0, 0, 2, 'A parcela herda o filtro do contrato, então o recorte do conselheiro vale igual.'),
 ('contratos_conselheiros',  1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 'Remuneração de conselheiro é confidencial. O próprio avaliado vê a dele, e mais ninguém.'),
 ('comissoes',               3, 3, 0, 1, 1, 0, 3, 1, 0, 3, 'Cada beneficiário enxerga a própria linha e só ela. Quem não é beneficiário e não vê confidencial lê zero.'),
 ('percentuais_padrao',      1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 'O percentual é regra comercial da casa. Nem o parceiro que ganha comissão sobre ele o lê.'),
 ('programas',               2, 2, 1, 1, 1, 1, 0, 0, 1, 2, 'Cada um alcança o programa em que tem vínculo. O participante alcança o programa da turma dele, que é o portal.'),
 ('turmas',                  2, 2, 1, 1, 1, 1, 0, 0, 1, 2, 'O participante alcança a própria turma, e não a turma irmã do mesmo programa.'),
 ('turmas_contas',           2, 2, 1, 1, 1, 1, 0, 0, 1, 2, 'A amarração de conta na turma segue a visibilidade da turma.'),
 ('participantes',           2, 2, 1, 1, 1, 1, 0, 0, 1, 2, 'A casa vê a turma que conduz. O participante vê a própria linha, e nenhuma outra cadeira.'),
 ('encontros',               3, 3, 1, 2, 2, 2, 0, 0, 1, 3, 'O participante lê o encontro aberto da turma dele, e não lê o encontro reservado.'),
 ('entregaveis',             3, 3, 1, 2, 2, 2, 0, 0, 1, 3, 'O participante lê apenas o entregável marcado como visível ao cliente.'),
 ('atividades',              2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 'A agenda interna é da casa inteira e de mais ninguém.'),
 ('alertas',                 2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 'O alerta é cobrança interna. Gente de fora não recebe cobrança da casa.'),
 ('regras_alerta',           1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 'A regra que dispara o alerta é da casa, pelo mesmo motivo.'),
 ('historico_fases',         3, 3, 3, 3, 3, 3, 3, 0, 0, 3, 'O tempo de cada negócio em cada fase é medida interna de funil.'),
 ('configuracoes',           1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 'DECISÃO: a configuração do inquilino é lida por todo mundo do inquilino, inclusive de fora, porque é ajuste de comportamento da tela e não dado de cliente. A escrita continua só do administrador. Se um dia entrar chave sensível aqui, esta linha é o lugar de apertar.'),
 ('ofertas',                 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 'DECISÃO: o catálogo do que a casa vende é lido por todo o inquilino, porque o parceiro precisa dele para indicar. A escrita continua só do administrador.'),
 ('margem_contrato',         2, 2, 0, 0, 0, 0, 2, 0, 0, 2, 'Margem é confidencial: líder, financeiro e administrador. A visão é em modo invocador e fica vazia para o resto.');

do $$
declare
  v_tabelas text[]; v_perfis text[]; v_usuarios text[]; v_esperado integer[]; v_porques text[];
  v_qtd integer; v_falhas integer := 0; v_conferidas integer := 0; i integer;
begin
  select array_agg(x.tabela order by x.tabela, x.ordem),
         array_agg(x.perfil order by x.tabela, x.ordem),
         array_agg(x.usuario order by x.tabela, x.ordem),
         array_agg(x.linhas order by x.tabela, x.ordem),
         array_agg(x.porque order by x.tabela, x.ordem)
    into v_tabelas, v_perfis, v_usuarios, v_esperado, v_porques
  from esperado_leitura e
  cross join lateral (values
      (1,'admin_master',  'a0a00000-0000-4000-8000-000000000011', e.adm, e.tabela, e.porque),
      (2,'lider',         'a0a00000-0000-4000-8000-000000000012', e.lid, e.tabela, e.porque),
      (3,'comercial',     'a0a00000-0000-4000-8000-000000000013', e.com, e.tabela, e.porque),
      (4,'gerente_contas','a0a00000-0000-4000-8000-000000000014', e.ger, e.tabela, e.porque),
      (5,'conselheiro',   'a0a00000-0000-4000-8000-000000000015', e.con, e.tabela, e.porque),
      (6,'assessor',      'a0a00000-0000-4000-8000-000000000016', e.ass, e.tabela, e.porque),
      (7,'financeiro',    'a0a00000-0000-4000-8000-000000000017', e.fin, e.tabela, e.porque),
      (8,'parceiro',      'a0a00000-0000-4000-8000-000000000018', e.par, e.tabela, e.porque),
      (9,'participante',  'a0a00000-0000-4000-8000-000000000019', e.pai, e.tabela, e.porque),
     (10,'emergencia',    'a0a00000-0000-4000-8000-00000000001a', e.eme, e.tabela, e.porque)
    ) as x(ordem, perfil, usuario, linhas, tabela, porque);

  execute 'set role valor_aplicacao';
  for i in 1 .. array_length(v_tabelas, 1) loop
    perform set_config('app.inquilino_id', 'a0a00000-0000-4000-8000-000000000001', true);
    perform set_config('app.usuario_id',   v_usuarios[i], true);
    perform set_config('app.perfil',       v_perfis[i], true);
    perform set_config('app.parceiro_id',
      case when v_perfis[i] = 'parceiro' then 'a0a00000-0000-4000-8000-0000000000f1' else '' end, true);
    execute format('select count(*) from valor.%I', v_tabelas[i]) into v_qtd;
    v_conferidas := v_conferidas + 1;
    if v_qtd <> v_esperado[i] then
      v_falhas := v_falhas + 1;
      raise warning 'LEITURA: perfil % em valor.% leu % linhas e esperava %. Regra: %',
        v_perfis[i], v_tabelas[i], v_qtd, v_esperado[i], v_porques[i];
    end if;
  end loop;
  execute 'reset role';

  if v_falhas > 0 then
    raise exception 'REPROVADO: % de % conferências de leitura não bateram com o esperado.', v_falhas, v_conferidas;
  end if;
  raise notice 'APROVADO · % conferências de leitura, 10 perfis em 27 tabelas, todas no número exato.', v_conferidas;
end $$;

-- ------------------------------------------------ 2 · o que cada perfil grava
-- Cada sondagem tenta uma linha válida, e o único motivo para o banco recusar é
-- a segurança de linha. A gravação que passa é desfeita na hora, por uma exceção
-- de sentinela, para que a contagem do bloco seguinte continue valendo.
-- `s` é grava, `n` é o banco recusa.

create temporary table esperado_escrita (
  rotulo text primary key,
  comando text not null,
  adm boolean not null, lid boolean not null, com boolean not null, ger boolean not null,
  con boolean not null, ass boolean not null, fin boolean not null, par boolean not null,
  pai boolean not null, eme boolean not null,
  porque text not null
) on commit drop;

insert into esperado_escrita values
 ('contas',
  $c$insert into valor.contas (inquilino_id, nome) values ('a0a00000-0000-4000-8000-000000000001','Conta de sondagem')$c$,
  true,true,true,true,true,true,true,false,false,true,
  'O CRM é do time da casa. Foi aqui que o participante gravou antes da correção.'),
 ('negocios',
  $c$insert into valor.negocios (inquilino_id, conta_id, titulo) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','Negócio de sondagem')$c$,
  true,true,true,true,true,true,true,false,false,true,
  'Mesmo motivo do CRM. O parceiro indica pela tabela de indicações, não gravando negócio.'),
 ('contatos',
  $c$insert into valor.contatos (inquilino_id, conta_id, nome) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','Contato de sondagem')$c$,
  true,true,true,true,true,true,true,false,false,true,
  'A agenda do cliente é da casa, para ler e para escrever.'),
 ('interacoes',
  $c$insert into valor.interacoes (inquilino_id, conta_id, assunto) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','Interação de sondagem')$c$,
  true,true,true,true,true,true,true,false,false,true,
  'O registro da conversa é da casa.'),
 ('artefatos',
  $c$insert into valor.artefatos (inquilino_id, negocio_id, tipo) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d1','plano_trabalho')$c$,
  true,true,true,true,true,true,true,false,false,true,
  'O artefato do negócio é produzido pela casa, mesmo no negócio que o parceiro indicou.'),
 ('atividades',
  $c$insert into valor.atividades (inquilino_id, titulo) values ('a0a00000-0000-4000-8000-000000000001','Atividade de sondagem')$c$,
  true,true,true,true,true,true,true,false,false,true,
  'A agenda interna é da casa.'),
 ('historico_fases',
  $c$insert into valor.historico_fases (inquilino_id, negocio_id, fase, entrou_em, saiu_em) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000d1', 2, date '2026-04-01', date '2026-04-20')$c$,
  true,true,true,true,true,true,true,false,false,true,
  'A medida de funil é gravada pela casa e pelos gatilhos dela.'),
 ('usuarios',
  $c$insert into valor.usuarios (inquilino_id, email, nome, perfil) values ('a0a00000-0000-4000-8000-000000000001','sondagem@exemplo.invalido','Pessoa de Sondagem','comercial')$c$,
  true,false,false,false,false,false,false,false,false,true,
  'Criar gente é do administrador. Nem o líder cria conta de acesso.'),
 ('ofertas',
  $c$insert into valor.ofertas (inquilino_id, codigo, nome, familia, modalidade) values ('a0a00000-0000-4000-8000-000000000001','oferta-de-sondagem','Oferta de Sondagem','Família Fictícia','pontual')$c$,
  true,false,false,false,false,false,false,false,false,true,
  'O catálogo é lido por todos e escrito só pelo administrador.'),
 ('regras_alerta',
  $c$insert into valor.regras_alerta (inquilino_id, codigo, nome, entidade_alvo, tipo_condicao, condicao_jsonb) values ('a0a00000-0000-4000-8000-000000000001','regra-de-sondagem','Regra de Sondagem','negocio','jsonb','{"campo": "fase"}'::jsonb)$c$,
  true,false,false,false,false,false,false,false,false,true,
  'Quem define o que dispara alerta é o administrador.'),
 ('alertas',
  $c$insert into valor.alertas (inquilino_id, regra_id, entidade, entidade_chave, mensagem) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000001501','negocio','a0a00000-0000-4000-8000-0000000000d3','Alerta de sondagem')$c$,
  true,false,false,false,false,false,false,false,false,true,
  'O alerta nasce do motor, que roda como administrador. A casa carimba o alerta, não o cria.'),
 ('contratos',
  $c$insert into valor.contratos (inquilino_id, conta_id, negocio_id, numero, vigencia_inicio) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000c1','a0a00000-0000-4000-8000-0000000000d1','CT-9099', date '2026-05-01')$c$,
  true,true,true,true,false,false,true,false,false,true,
  'Contrato é de quem fecha e de quem cuida do dinheiro. Conselheiro e assessor entregam, não contratam.'),
 ('parcelas',
  $c$insert into valor.parcelas (inquilino_id, contrato_id, numero, competencia, vencimento, valor_bruto) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000601', 9, date '2026-05-01', date '2026-05-10', 1000)$c$,
  true,true,false,false,false,false,true,false,false,true,
  'Faturamento é privativo de quem vê confidencial.'),
 ('comissoes',
  $c$insert into valor.comissoes (inquilino_id, beneficiario_tipo, usuario_id, contrato_id, parcela_id, valor_bruto, imposto_percentual, imposto_valor, base_calculo, valor, competencia) values ('a0a00000-0000-4000-8000-000000000001','vendedor_interno','a0a00000-0000-4000-8000-000000000014','a0a00000-0000-4000-8000-000000000602','a0a00000-0000-4000-8000-000000000702', 1000, 15, 150, 850, 85, date '2026-05-01')$c$,
  true,true,false,false,false,false,true,false,false,true,
  'A apuração é privativa de quem vê confidencial, senão o beneficiário escreveria a própria comissão.'),
 ('percentuais_padrao',
  $c$insert into valor.percentuais_padrao (inquilino_id, escopo, vigencia_inicio, imposto_percentual) values ('a0a00000-0000-4000-8000-000000000001','inquilino', date '2026-06-01', 12)$c$,
  true,true,false,false,false,false,true,false,false,true,
  'Mexer no percentual muda o que todo mundo recebe, então é confidencial.'),
 ('contratos_conselheiros',
  $c$insert into valor.contratos_conselheiros (inquilino_id, contrato_id, usuario_id, modelo, valor_fixo_mensal) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000602','a0a00000-0000-4000-8000-000000000015','fixo_mensal', 5000)$c$,
  true,true,false,false,false,false,true,false,false,true,
  'O conselheiro lê a própria remuneração e não a define.'),
 ('indicacoes',
  $c$insert into valor.indicacoes (inquilino_id, parceiro_id, conta_indicada_nome, contato_nome, contexto, status) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-0000000000f1','Empresa de Sondagem','Contato de Sondagem','Indicação de sondagem','registrada')$c$,
  true,true,true,false,false,false,true,true,false,true,
  'Aqui o de fora ENTRA de propósito: registrar indicação é o trabalho do parceiro, amarrado ao parceiro_id dele e ao status registrada. Do lado de dentro, quem gerencia parceiros. O participante não indica.'),
 ('turmas',
  $c$insert into valor.turmas (inquilino_id, programa_id, codigo, nome) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000b01','turma-de-sondagem','Turma de Sondagem')$c$,
  true,true,false,false,true,true,false,false,false,true,
  'Quem monta turma é quem conduz entrega, e só no programa que alcança.'),
 ('encontros',
  $c$insert into valor.encontros (inquilino_id, turma_id, numero, tema, data_prevista) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01', 9,'Encontro de sondagem', date '2026-06-01')$c$,
  true,true,false,false,true,true,false,false,false,true,
  'Marcar encontro é da equipe da turma. O participante ocupa a cadeira, não escreve a agenda.'),
 ('entregaveis',
  $c$insert into valor.entregaveis (inquilino_id, turma_id, titulo) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01','Entregável de sondagem')$c$,
  true,true,false,false,true,true,false,false,false,true,
  'O entregável é produzido pela casa e liberado ao cliente por marcação, nunca escrito pelo cliente.'),
 ('participantes',
  $c$insert into valor.participantes (inquilino_id, turma_id, conta_id, nome, papel) values ('a0a00000-0000-4000-8000-000000000001','a0a00000-0000-4000-8000-000000000e01','a0a00000-0000-4000-8000-0000000000c1','Pessoa de Sondagem','membro')$c$,
  true,true,false,false,true,true,false,false,false,true,
  'Quem senta gente na turma é a casa. Se o participante gravasse aqui, ele se convidaria para a turma do vizinho.');

do $$
declare
  v_rotulos text[]; v_comandos text[]; v_perfis text[]; v_usuarios text[];
  v_pode boolean[]; v_porques text[];
  v_gravou boolean; v_falhas integer := 0; v_conferidas integer := 0; i integer;
begin
  select array_agg(x.rotulo order by x.rotulo, x.ordem),
         array_agg(x.comando order by x.rotulo, x.ordem),
         array_agg(x.perfil order by x.rotulo, x.ordem),
         array_agg(x.usuario order by x.rotulo, x.ordem),
         array_agg(x.pode order by x.rotulo, x.ordem),
         array_agg(x.porque order by x.rotulo, x.ordem)
    into v_rotulos, v_comandos, v_perfis, v_usuarios, v_pode, v_porques
  from esperado_escrita e
  cross join lateral (values
      (1,'admin_master',  'a0a00000-0000-4000-8000-000000000011', e.adm, e.rotulo, e.comando, e.porque),
      (2,'lider',         'a0a00000-0000-4000-8000-000000000012', e.lid, e.rotulo, e.comando, e.porque),
      (3,'comercial',     'a0a00000-0000-4000-8000-000000000013', e.com, e.rotulo, e.comando, e.porque),
      (4,'gerente_contas','a0a00000-0000-4000-8000-000000000014', e.ger, e.rotulo, e.comando, e.porque),
      (5,'conselheiro',   'a0a00000-0000-4000-8000-000000000015', e.con, e.rotulo, e.comando, e.porque),
      (6,'assessor',      'a0a00000-0000-4000-8000-000000000016', e.ass, e.rotulo, e.comando, e.porque),
      (7,'financeiro',    'a0a00000-0000-4000-8000-000000000017', e.fin, e.rotulo, e.comando, e.porque),
      (8,'parceiro',      'a0a00000-0000-4000-8000-000000000018', e.par, e.rotulo, e.comando, e.porque),
      (9,'participante',  'a0a00000-0000-4000-8000-000000000019', e.pai, e.rotulo, e.comando, e.porque),
     (10,'emergencia',    'a0a00000-0000-4000-8000-00000000001a', e.eme, e.rotulo, e.comando, e.porque)
    ) as x(ordem, perfil, usuario, pode, rotulo, comando, porque);

  execute 'set role valor_aplicacao';
  for i in 1 .. array_length(v_rotulos, 1) loop
    perform set_config('app.inquilino_id', 'a0a00000-0000-4000-8000-000000000001', true);
    perform set_config('app.usuario_id',   v_usuarios[i], true);
    perform set_config('app.perfil',       v_perfis[i], true);
    perform set_config('app.parceiro_id',
      case when v_perfis[i] = 'parceiro' then 'a0a00000-0000-4000-8000-0000000000f1' else '' end, true);

    begin
      execute v_comandos[i];
      -- A linha entrou. A sentinela desfaz a subtransação e não deixa resíduo.
      raise exception 'sondagem desfeita' using errcode = 'ZZ999';
    exception
      when sqlstate 'ZZ999' then v_gravou := true;
      -- 42501 é a recusa da segurança de linha, e é o caminho normal.
      when insufficient_privilege then v_gravou := false;
      -- P0001 é um gatilho de guarda recusando antes da política. Acontece em
      -- valor.contratos: validar_contrato_negocio lê valor.negocios com a visão
      -- de quem chama, e para quem não enxerga o negócio ele reclama primeiro.
      -- A porta fica fechada do mesmo jeito, e por dois cadeados em vez de um.
      when raise_exception then v_gravou := false;
    end;

    v_conferidas := v_conferidas + 1;
    if v_gravou <> v_pode[i] then
      v_falhas := v_falhas + 1;
      if v_gravou then
        raise warning 'ESCRITA: perfil % GRAVOU em valor.% e o banco deveria ter recusado. Regra: %',
          v_perfis[i], v_rotulos[i], v_porques[i];
      else
        raise warning 'ESCRITA: perfil % foi RECUSADO em valor.% e deveria conseguir gravar. Regra: %',
          v_perfis[i], v_rotulos[i], v_porques[i];
      end if;
    end if;
  end loop;
  execute 'reset role';

  if v_falhas > 0 then
    raise exception 'REPROVADO: % de % sondagens de escrita não bateram com o esperado.', v_falhas, v_conferidas;
  end if;
  raise notice 'APROVADO · % sondagens de escrita, 10 perfis em 22 tabelas, cada porta abrindo só para quem foi nomeado.', v_conferidas;
end $$;

-- ------------------------------------------------ 3 · a trilha de auditoria
-- A trilha não tem política de escrita: quem grava é o gatilho, como dono. O que
-- se prova aqui é a leitura, que tem duas portas, e só duas.

do $$
declare v_total integer; v_do_gerente integer; v_qtd integer; v_falhas integer := 0;
begin
  -- Uma pegada com dono conhecido, para o zero dos outros ter contraponto.
  perform set_config('app.inquilino_id', 'a0a00000-0000-4000-8000-000000000001', true);
  perform set_config('app.usuario_id',   'a0a00000-0000-4000-8000-000000000014', true);
  perform set_config('app.perfil',       'gerente_contas', true);
  update valor.negocios set proximo_passo = 'Passo fictício de sondagem'
   where id = 'a0a00000-0000-4000-8000-0000000000d1';

  select count(*) into v_total from valor.auditoria
   where inquilino_id = 'a0a00000-0000-4000-8000-000000000001';
  select count(*) into v_do_gerente from valor.auditoria
   where inquilino_id = 'a0a00000-0000-4000-8000-000000000001'
     and usuario_id = 'a0a00000-0000-4000-8000-000000000014';

  if v_total < 1 or v_do_gerente < 1 then
    raise exception 'REPROVADO: a carga da trilha falhou, % linhas no total e % do gerente.', v_total, v_do_gerente;
  end if;
  if v_do_gerente >= v_total then
    raise exception 'REPROVADO: a prova é oca, toda a trilha é do gerente. Total %, dele %.', v_total, v_do_gerente;
  end if;

  execute 'set role valor_aplicacao';

  perform set_config('app.perfil', 'admin_master', true);
  perform set_config('app.usuario_id', 'a0a00000-0000-4000-8000-000000000011', true);
  select count(*) into v_qtd from valor.auditoria;
  if v_qtd <> v_total then
    raise warning 'AUDITORIA: o administrador leu % linhas da trilha e a trilha tem %.', v_qtd, v_total;
    v_falhas := v_falhas + 1;
  end if;

  perform set_config('app.perfil', 'gerente_contas', true);
  perform set_config('app.usuario_id', 'a0a00000-0000-4000-8000-000000000014', true);
  select count(*) into v_qtd from valor.auditoria;
  if v_qtd <> v_do_gerente then
    raise warning 'AUDITORIA: o gerente leu % linhas e só a própria pegada são %.', v_qtd, v_do_gerente;
    v_falhas := v_falhas + 1;
  end if;

  perform set_config('app.perfil', 'comercial', true);
  perform set_config('app.usuario_id', 'a0a00000-0000-4000-8000-000000000013', true);
  select count(*) into v_qtd from valor.auditoria;
  if v_qtd <> 0 then
    raise warning 'AUDITORIA: o comercial, que não deixou pegada, leu % linhas.', v_qtd;
    v_falhas := v_falhas + 1;
  end if;

  -- Gente de fora não alcança a trilha nem com a própria pegada, porque a pegada
  -- revela o que a casa fez com o dado do cliente.
  perform set_config('app.perfil', 'parceiro', true);
  perform set_config('app.usuario_id', 'a0a00000-0000-4000-8000-000000000018', true);
  perform set_config('app.parceiro_id', 'a0a00000-0000-4000-8000-0000000000f1', true);
  select count(*) into v_qtd from valor.auditoria;
  if v_qtd <> 0 then
    raise warning 'AUDITORIA: o parceiro leu % linhas da trilha.', v_qtd;
    v_falhas := v_falhas + 1;
  end if;

  perform set_config('app.perfil', 'participante', true);
  perform set_config('app.usuario_id', 'a0a00000-0000-4000-8000-000000000019', true);
  perform set_config('app.parceiro_id', '', true);
  select count(*) into v_qtd from valor.auditoria;
  if v_qtd <> 0 then
    raise warning 'AUDITORIA: o participante leu % linhas da trilha.', v_qtd;
    v_falhas := v_falhas + 1;
  end if;

  execute 'reset role';

  if v_falhas > 0 then
    raise exception 'REPROVADO: % conferências da trilha de auditoria não bateram.', v_falhas;
  end if;
  raise notice 'APROVADO · a trilha tem % linhas: o administrador lê todas, o gerente lê as % dele, e o resto lê zero.', v_total, v_do_gerente;
end $$;

-- ------------------------------------------------ 4 · dois inquilinos não se alcançam
-- A varredura é sobre TODA tabela do esquema que carrega inquilino_id, e não
-- sobre uma lista escrita à mão, para que uma tabela nova entre na prova sozinha.

do $$
declare
  v_tabelas text[]; v_qtd integer; v_falhas integer := 0; i integer;
  v_perfis text[] := array['admin_master','lider','comercial','gerente_contas','conselheiro',
                           'assessor','financeiro','parceiro','participante','emergencia'];
  j integer;
begin
  select array_agg(c.relname order by c.relname) into v_tabelas
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attname = 'inquilino_id' and a.attnum > 0
   where n.nspname = 'valor' and c.relkind = 'r';

  if array_length(v_tabelas, 1) is null or array_length(v_tabelas, 1) < 20 then
    raise exception 'REPROVADO: a varredura achou % tabelas com inquilino_id, e isso é pouco demais para ser verdade.',
      coalesce(array_length(v_tabelas, 1), 0);
  end if;

  execute 'set role valor_aplicacao';
  for j in 1 .. array_length(v_perfis, 1) loop
    perform set_config('app.inquilino_id', 'b0b00000-0000-4000-8000-000000000001', true);
    perform set_config('app.usuario_id',   'b0b00000-0000-4000-8000-000000000011', true);
    perform set_config('app.perfil',       v_perfis[j], true);
    perform set_config('app.parceiro_id',  'a0a00000-0000-4000-8000-0000000000f1', true);
    for i in 1 .. array_length(v_tabelas, 1) loop
      execute format(
        'select count(*) from valor.%I where inquilino_id = %L',
        v_tabelas[i], 'a0a00000-0000-4000-8000-000000000001') into v_qtd;
      if v_qtd <> 0 then
        v_falhas := v_falhas + 1;
        raise warning 'VAZAMENTO: sessão do inquilino vizinho, perfil %, leu % linhas do inquilino de prova em valor.%.',
          v_perfis[j], v_qtd, v_tabelas[i];
      end if;
    end loop;
  end loop;

  -- E a volta: a casa de prova não alcança a vizinha, inclusive com o
  -- parceiro_id do vizinho na mão, que é a tentativa mais barata de travessia.
  perform set_config('app.inquilino_id', 'a0a00000-0000-4000-8000-000000000001', true);
  perform set_config('app.usuario_id',   'a0a00000-0000-4000-8000-000000000011', true);
  perform set_config('app.perfil',       'admin_master', true);
  for i in 1 .. array_length(v_tabelas, 1) loop
    execute format(
      'select count(*) from valor.%I where inquilino_id = %L',
      v_tabelas[i], 'b0b00000-0000-4000-8000-000000000001') into v_qtd;
    if v_qtd <> 0 then
      v_falhas := v_falhas + 1;
      raise warning 'VAZAMENTO: o administrador da casa de prova leu % linhas da casa vizinha em valor.%.', v_qtd, v_tabelas[i];
    end if;
  end loop;

  -- A tabela de inquilinos não tem inquilino_id, então entra à parte.
  perform set_config('app.perfil', 'admin_master', true);
  select count(*) into v_qtd from valor.inquilinos;
  if v_qtd <> 1 then
    v_falhas := v_falhas + 1;
    raise warning 'VAZAMENTO: a sessão enxergou % inquilinos e deveria enxergar apenas o próprio.', v_qtd;
  end if;

  execute 'reset role';

  if v_falhas > 0 then
    raise exception 'REPROVADO: % travessias entre inquilinos.', v_falhas;
  end if;
  raise notice 'APROVADO · % tabelas com inquilino_id varridas nos dois sentidos, em 10 perfis, e nenhuma travessia.',
    array_length(v_tabelas, 1);
end $$;

-- ------------------------------------------------ 5 · sessão sem inquilino não lê nada
-- Não é uma amostra: é toda tabela do esquema, porque a sessão sem contexto é o
-- que sobra quando o token expira ou quando a claim não chega.

do $$
declare
  v_tabelas text[]; v_qtd integer; v_falhas integer := 0; i integer; j integer;
  v_perfis text[] := array['admin_master','emergencia','lider','parceiro','participante'];
begin
  select array_agg(c.relname order by c.relname) into v_tabelas
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'valor' and c.relkind = 'r';

  if array_length(v_tabelas, 1) is null or array_length(v_tabelas, 1) < 20 then
    raise exception 'REPROVADO: a varredura achou % tabelas no esquema valor, e isso é pouco demais para ser verdade.',
      coalesce(array_length(v_tabelas, 1), 0);
  end if;

  execute 'set role valor_aplicacao';
  for j in 1 .. array_length(v_perfis, 1) loop
    perform set_config('app.inquilino_id', '', true);
    perform set_config('app.usuario_id',   '', true);
    perform set_config('app.parceiro_id',  '', true);
    perform set_config('app.perfil',       v_perfis[j], true);
    for i in 1 .. array_length(v_tabelas, 1) loop
      execute format('select count(*) from valor.%I', v_tabelas[i]) into v_qtd;
      if v_qtd <> 0 then
        v_falhas := v_falhas + 1;
        raise warning 'SEM INQUILINO: perfil % leu % linhas em valor.% sem contexto de inquilino.',
          v_perfis[j], v_qtd, v_tabelas[i];
      end if;
    end loop;
  end loop;
  execute 'reset role';

  if v_falhas > 0 then
    raise exception 'REPROVADO: % tabelas devolveram linha para uma sessão sem inquilino.', v_falhas;
  end if;
  raise notice 'APROVADO · % tabelas lidas em 5 perfis sem contexto de inquilino, e todas devolveram zero.',
    array_length(v_tabelas, 1);
end $$;

-- ------------------------------------------------ 6 · nenhuma política de escrita por omissão
-- A prova anterior é empírica e vale para as tabelas sondadas. Esta lê o catálogo
-- do PostgreSQL e vale para TODA política do esquema, inclusive as que ainda não
-- existiam quando este arquivo foi escrito. É a rede que pega o defeito original
-- de novo, se alguém voltar a escrever quem não pode em vez de quem pode.

-- Uma única exceção está registrada abaixo, pelo nome, e ela NÃO foi afrouxada
-- aqui: a política continua como está, e o portão do orquestrador continua
-- apontando o dedo para ela na seção 2c. A exceção existe porque a política mora
-- em 0010_nps_e_avaliacoes.sql, que esta auditoria foi instruída a não tocar, e
-- porque a abertura dela é intencional: quem responde avaliação de conselheiro é
-- o sócio do cliente, que pode ter perfil participante. O que falta lá é o que a
-- 0010 já fez em resposta_insere, amarrar a escrita ao identificador de quem
-- responde. Enquanto isso não for feito pelo dono daquele arquivo, qualquer
-- pessoa do inquilino que não seja parceiro grava avaliação sobre qualquer
-- conselheiro. Se a lista abaixo ganhar um segundo nome, este bloco reprova.

do $$
declare
  v_fracas text; v_qtd integer; v_pendentes text;
  v_conhecidas text[] := array['avaliacoes_conselheiro.avaliacao_conselheiro_insere'];
begin
  select string_agg(c.relname || '.' || p.polname, ', ' order by c.relname, p.polname), count(*)
    into v_fracas, v_qtd
  from pg_policy p
  join pg_class c on c.oid = p.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'valor'
    and p.polcmd in ('*', 'a', 'w')
    and coalesce(pg_get_expr(p.polwithcheck, p.polrelid), pg_get_expr(p.polqual, p.polrelid), '') like '%eh_parceiro%'
    and coalesce(pg_get_expr(p.polwithcheck, p.polrelid), pg_get_expr(p.polqual, p.polrelid), '') not like '%time_da_casa%'
    and coalesce(pg_get_expr(p.polwithcheck, p.polrelid), pg_get_expr(p.polqual, p.polrelid), '') not like '%participante%'
    and not (c.relname || '.' || p.polname = any (v_conhecidas));

  if coalesce(v_qtd, 0) > 0 then
    raise exception 'REPROVADO: % política(s) de escrita guardadas só por eh_parceiro, então um perfil novo do enum entra por omissão: %', v_qtd, v_fracas;
  end if;

  select string_agg(c.relname || '.' || p.polname, ', ' order by c.relname, p.polname)
    into v_pendentes
  from pg_policy p
  join pg_class c on c.oid = p.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'valor'
    and c.relname || '.' || p.polname = any (v_conhecidas);

  if v_pendentes is not null then
    raise notice 'PENDENTE, e de propósito · segue em aberto, para o dono de 0010 fechar amarrando a escrita a quem responde: %', v_pendentes;
  end if;
  raise notice 'APROVADO · fora a pendência registrada acima, toda política de escrita do esquema nomeia quem pode, e não apenas quem não pode.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'Teste de regressão concluído. O rollback abaixo não deixa dado no banco.'
\echo '=================================================================='

rollback;
