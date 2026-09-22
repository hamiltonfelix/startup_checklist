-- Teste de regressão · a conta da comissão, a idempotência da apuração e a margem
-- Dono: agente de PRM e Financeiro. Nenhum outro agente altera este arquivo.
--
-- Como rodar, num banco onde as migrações já aplicaram:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d fab_prm -f testes/comissoes.sql
--
-- O teste inteiro vive dentro de uma transação e desfaz tudo no final. Pode
-- rodar quantas vezes quiser, no mesmo banco, sem deixar resíduo.
--
-- Todo dado aqui é fictício, com valores redondos inventados. Nenhum contrato,
-- nenhuma comissão, nenhum telefone e nenhum endereço de cliente de verdade.
--
-- O que este teste prova, com uma parcela de 10000,00:
--   imposto              1500,00
--   base de comissão     8500,00
--   comissão do vendedor  850,00   efetivo 8,5% do bruto
--   comissão do parceiro  850,00   efetivo 8,5% do bruto
--   margem               6800,00   antes do custo do conselheiro
--   margem               5100,00   depois de um conselheiro a 20% da base
-- E prova que apurar duas vezes não duplica linha nenhuma.

\set ON_ERROR_STOP on
\pset border 2
\pset null 'nulo'

begin;

-- A sessão que semeia é a do financeiro. A apuração é privativa dele, do líder
-- e do administrador, e é isso que o gatilho da parcela vai exercer.
select set_config('app.inquilino_id', 'aaaaaaaa-0000-4000-8000-000000000001', true) as ignorado;
select set_config('app.usuario_id',   'aaaaaaaa-0000-4000-8000-000000000011', true) as ignorado;
select set_config('app.perfil',       'financeiro', true) as ignorado;

-- ------------------------------------------------------------ dados fictícios

insert into valor.inquilinos (id, nome, apelido) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'Inquilino de Teste', 'teste-comissoes');

insert into valor.usuarios (id, inquilino_id, email, nome, perfil) values
  ('aaaaaaaa-0000-4000-8000-000000000011', 'aaaaaaaa-0000-4000-8000-000000000001',
   'financeiro@exemplo.invalido', 'Pessoa Financeiro', 'financeiro'),
  ('aaaaaaaa-0000-4000-8000-000000000012', 'aaaaaaaa-0000-4000-8000-000000000001',
   'gerente@exemplo.invalido', 'Pessoa Gerente de Contas', 'gerente_contas'),
  ('aaaaaaaa-0000-4000-8000-000000000013', 'aaaaaaaa-0000-4000-8000-000000000001',
   'conselheiro@exemplo.invalido', 'Pessoa Conselheiro', 'conselheiro'),
  ('aaaaaaaa-0000-4000-8000-000000000014', 'aaaaaaaa-0000-4000-8000-000000000001',
   'parceiro@exemplo.invalido', 'Pessoa Parceiro', 'parceiro');

insert into valor.parceiros (id, inquilino_id, nome, tipo, status, credenciado_em) values
  ('aaaaaaaa-0000-4000-8000-000000000021', 'aaaaaaaa-0000-4000-8000-000000000001',
   'Parceiro de Teste', 'indicador', 'ativo', date '2026-01-10');

insert into valor.parceiros_usuarios (inquilino_id, parceiro_id, usuario_id, principal) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000021',
   'aaaaaaaa-0000-4000-8000-000000000014', true);

insert into valor.ofertas (id, inquilino_id, codigo, nome, familia, modalidade) values
  ('aaaaaaaa-0000-4000-8000-000000000031', 'aaaaaaaa-0000-4000-8000-000000000001',
   'teste-conselho', 'Conselho de Valor dedicado', 'Programas de Valor', 'recorrente');

insert into valor.contas (id, inquilino_id, nome, gerente_contas_id) values
  ('aaaaaaaa-0000-4000-8000-000000000041', 'aaaaaaaa-0000-4000-8000-000000000001',
   'Conta de Teste', 'aaaaaaaa-0000-4000-8000-000000000012');

-- O negócio tem vendedor interno e parceiro ao mesmo tempo. É o caso que faz
-- nascerem duas linhas de comissão sobre a mesma base líquida.
insert into valor.negocios (id, inquilino_id, conta_id, oferta_id, parceiro_id, titulo, fase, nivel_contrato) values
  ('aaaaaaaa-0000-4000-8000-000000000051', 'aaaaaaaa-0000-4000-8000-000000000001',
   'aaaaaaaa-0000-4000-8000-000000000041', 'aaaaaaaa-0000-4000-8000-000000000031',
   'aaaaaaaa-0000-4000-8000-000000000021', 'Negócio de teste', 4, 'n1');

insert into valor.papeis_negocio (inquilino_id, negocio_id, usuario_id, papel, entrou_na_fase, principal) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000051',
   'aaaaaaaa-0000-4000-8000-000000000012', 'gerente_contas', 1, true),
  ('aaaaaaaa-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000051',
   'aaaaaaaa-0000-4000-8000-000000000013', 'conselheiro', 3, false);

-- Os percentuais da casa: 15 de imposto, 10 de vendedor, 10 de parceiro.
insert into valor.percentuais_padrao
  (inquilino_id, escopo, rotulo, imposto_percentual,
   comissao_vendedor_percentual, comissao_parceiro_percentual, vigencia_inicio) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'inquilino', 'Padrão da casa',
   15.0000, 10.0000, 10.0000, date '2026-01-01');

insert into valor.contratos
  (id, inquilino_id, conta_id, negocio_id, oferta_id, numero, titulo, modalidade, nivel,
   situacao, assinado, assinado_em, vigencia_inicio, vigencia_fim, valor_mensal,
   indexador_reajuste, renovacao_automatica, aviso_previo_dias) values
  ('aaaaaaaa-0000-4000-8000-000000000061', 'aaaaaaaa-0000-4000-8000-000000000001',
   'aaaaaaaa-0000-4000-8000-000000000041', 'aaaaaaaa-0000-4000-8000-000000000051',
   'aaaaaaaa-0000-4000-8000-000000000031', 'TESTE-0001', 'Contrato de teste',
   'recorrente', 'n1', 'vigente', true, date '2026-03-01', date '2026-03-01',
   date '2027-02-28', 10000.00, 'IPCA', true, 30);

\echo ''
\echo '=================================================================='
\echo 'TESTE 1 · a conta, na ordem da casa, com uma parcela de 10000,00'
\echo '=================================================================='

-- A parcela nasce recebida, e o gatilho apura a comissão no recebimento.
insert into valor.parcelas
  (id, inquilino_id, contrato_id, numero, competencia, vencimento, valor_bruto, status, recebida_em) values
  ('aaaaaaaa-0000-4000-8000-000000000071', 'aaaaaaaa-0000-4000-8000-000000000001',
   'aaaaaaaa-0000-4000-8000-000000000061', 1, date '2026-03-01', date '2026-03-10',
   10000.00, 'recebida', date '2026-03-10');

select
  case k.beneficiario_tipo
    when 'vendedor_interno' then 'Comissão do vendedor'
    when 'parceiro'         then 'Comissão do parceiro'
    else                         'Custo do conselheiro'
  end                              as linha,
  k.valor_bruto                    as bruto,
  k.imposto_percentual             as imposto_pct,
  k.imposto_valor                  as imposto,
  k.base_calculo                   as base,
  k.percentual                     as pct_sobre_base,
  k.valor                          as valor,
  k.percentual_efetivo_sobre_bruto as efetivo_sobre_bruto,
  k.status                         as status
from valor.comissoes k
where k.parcela_id = 'aaaaaaaa-0000-4000-8000-000000000071'
order by k.beneficiario_tipo;

\echo ''
\echo 'Margem do contrato, antes de existir custo de conselheiro:'
select numero, valor_bruto, imposto_valor, base_calculo,
       comissao_vendedor, comissao_parceiro, custo_conselheiro,
       margem, margem_percentual_sobre_bruto
from valor.margem_contrato
where contrato_id = 'aaaaaaaa-0000-4000-8000-000000000061';

do $$
declare
  v_venda   valor.comissoes%rowtype;
  v_parc    valor.comissoes%rowtype;
  v_margem  numeric(14,2);
  v_linhas  integer;
begin
  select * into v_venda from valor.comissoes
   where parcela_id = 'aaaaaaaa-0000-4000-8000-000000000071'
     and beneficiario_tipo = 'vendedor_interno';
  select * into v_parc from valor.comissoes
   where parcela_id = 'aaaaaaaa-0000-4000-8000-000000000071'
     and beneficiario_tipo = 'parceiro';
  select count(*) into v_linhas from valor.comissoes
   where parcela_id = 'aaaaaaaa-0000-4000-8000-000000000071';
  select margem into v_margem from valor.margem_contrato
   where contrato_id = 'aaaaaaaa-0000-4000-8000-000000000061';

  if v_linhas <> 2 then
    raise exception 'Esperava 2 linhas de comissão, uma do vendedor e uma do parceiro. Vieram %.', v_linhas;
  end if;
  if v_venda.imposto_valor <> 1500.00 then
    raise exception 'Imposto errado no vendedor. Esperava 1500,00 e veio %.', v_venda.imposto_valor;
  end if;
  if v_venda.base_calculo <> 8500.00 then
    raise exception 'Base de comissão errada. Esperava 8500,00 e veio %.', v_venda.base_calculo;
  end if;
  if v_venda.valor <> 850.00 then
    raise exception 'Comissão do vendedor errada. Esperava 850,00 e veio %.', v_venda.valor;
  end if;
  if v_parc.valor <> 850.00 then
    raise exception 'Comissão do parceiro errada. Esperava 850,00 e veio %.', v_parc.valor;
  end if;
  if v_venda.percentual_efetivo_sobre_bruto <> 8.5000 then
    raise exception 'Efetivo do vendedor errado. Esperava 8,5 por cento e veio %.', v_venda.percentual_efetivo_sobre_bruto;
  end if;
  if v_parc.percentual_efetivo_sobre_bruto <> 8.5000 then
    raise exception 'Efetivo do parceiro errado. Esperava 8,5 por cento e veio %.', v_parc.percentual_efetivo_sobre_bruto;
  end if;
  if v_margem <> 6800.00 then
    raise exception 'Margem errada antes do conselheiro. Esperava 6800,00 e veio %.', v_margem;
  end if;

  raise notice 'TESTE 1 passou: imposto 1500,00 · base 8500,00 · vendedor 850,00 · parceiro 850,00 · efetivo 8,5 por cento em cada · margem 6800,00.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 2 · idempotência: apurar de novo não duplica nem soma'
\echo '=================================================================='

select valor.apurar_comissoes('aaaaaaaa-0000-4000-8000-000000000071') as linhas_na_segunda_apuracao;
select valor.apurar_comissoes('aaaaaaaa-0000-4000-8000-000000000071') as linhas_na_terceira_apuracao;
select valor.apurar_comissoes('aaaaaaaa-0000-4000-8000-000000000071') as linhas_na_quarta_apuracao;

select count(*) as linhas_na_parcela,
       sum(valor) as soma_das_comissoes,
       count(distinct (beneficiario_tipo, beneficiario_id)) as beneficiarios_distintos
from valor.comissoes
where parcela_id = 'aaaaaaaa-0000-4000-8000-000000000071';

do $$
declare
  v_linhas integer;
  v_soma   numeric(14,2);
begin
  select count(*), sum(valor) into v_linhas, v_soma
    from valor.comissoes where parcela_id = 'aaaaaaaa-0000-4000-8000-000000000071';
  if v_linhas <> 2 then
    raise exception 'Apuração duplicou linha. Depois de quatro apurações da mesma parcela esperava 2 linhas e há %.', v_linhas;
  end if;
  if v_soma <> 1700.00 then
    raise exception 'Soma das comissões mudou entre apurações. Esperava 1700,00 e veio %.', v_soma;
  end if;
  raise notice 'TESTE 2 passou: quatro apurações da mesma parcela, ainda 2 linhas e 1700,00 no total.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 3 · o custo do conselheiro entra e a margem cai'
\echo '=================================================================='

insert into valor.contratos_conselheiros
  (inquilino_id, contrato_id, usuario_id, modelo, percentual, vigencia_inicio) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000061',
   'aaaaaaaa-0000-4000-8000-000000000013', 'percentual_contrato', 20.0000, date '2026-03-01');

select valor.apurar_comissoes('aaaaaaaa-0000-4000-8000-000000000071') as linhas_com_o_conselheiro;

select beneficiario_tipo, percentual as pct_sobre_base, valor,
       percentual_efetivo_sobre_bruto as efetivo_sobre_bruto
from valor.comissoes
where parcela_id = 'aaaaaaaa-0000-4000-8000-000000000071'
order by beneficiario_tipo;

select numero, valor_bruto, imposto_valor, base_calculo,
       comissao_vendedor, comissao_parceiro, custo_conselheiro, margem
from valor.margem_contrato
where contrato_id = 'aaaaaaaa-0000-4000-8000-000000000061';

do $$
declare
  v_custo  numeric(14,2);
  v_margem numeric(14,2);
begin
  select custo_conselheiro, margem into v_custo, v_margem
    from valor.margem_contrato where contrato_id = 'aaaaaaaa-0000-4000-8000-000000000061';
  if v_custo <> 1700.00 then
    raise exception 'Custo do conselheiro errado. Esperava 1700,00, que é 20 por cento de 8500,00, e veio %.', v_custo;
  end if;
  if v_margem <> 5100.00 then
    raise exception 'Margem errada depois do conselheiro. Esperava 5100,00 e veio %.', v_margem;
  end if;
  raise notice 'TESTE 3 passou: custo do conselheiro 1700,00 e margem 5100,00.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 4 · quem enxerga qual linha, no papel sem privilégio'
\echo '=================================================================='

set role valor_aplicacao;

select set_config('app.usuario_id',  'aaaaaaaa-0000-4000-8000-000000000012', true) as ignorado;
select set_config('app.perfil',      'gerente_contas', true) as ignorado;
select set_config('app.parceiro_id', '', true) as ignorado;

\echo 'Sessão do vendedor:'
select current_user as papel_do_banco, valor.perfil_atual() as perfil,
       count(*) as comissoes_visiveis,
       count(*) filter (where beneficiario_tipo = 'vendedor_interno') as proprias,
       count(*) filter (where beneficiario_tipo <> 'vendedor_interno') as de_terceiros,
       (select count(*) from valor.margem_contrato) as linhas_de_margem
from valor.comissoes;

select set_config('app.usuario_id',  'aaaaaaaa-0000-4000-8000-000000000014', true) as ignorado;
select set_config('app.perfil',      'parceiro', true) as ignorado;
select set_config('app.parceiro_id', 'aaaaaaaa-0000-4000-8000-000000000021', true) as ignorado;

\echo 'Sessão do parceiro:'
select current_user as papel_do_banco, valor.perfil_atual() as perfil,
       count(*) as comissoes_visiveis,
       count(*) filter (where beneficiario_tipo = 'parceiro') as proprias,
       count(*) filter (where beneficiario_tipo <> 'parceiro') as de_terceiros,
       (select count(*) from valor.contratos) as contratos_visiveis,
       (select count(*) from valor.parcelas) as parcelas_visiveis,
       (select count(*) from valor.margem_contrato) as linhas_de_margem
from valor.comissoes;

select set_config('app.usuario_id',  'aaaaaaaa-0000-4000-8000-000000000013', true) as ignorado;
select set_config('app.perfil',      'conselheiro', true) as ignorado;
select set_config('app.parceiro_id', '', true) as ignorado;

\echo 'Sessão do conselheiro:'
select current_user as papel_do_banco, valor.perfil_atual() as perfil,
       count(*) as comissoes_visiveis,
       count(*) filter (where beneficiario_tipo = 'conselheiro') as proprias,
       count(*) filter (where beneficiario_tipo <> 'conselheiro') as de_terceiros,
       (select count(*) from valor.contratos) as contratos_visiveis,
       (select count(*) from valor.contratos_conselheiros) as remuneracoes_visiveis,
       (select count(*) from valor.margem_contrato) as linhas_de_margem
from valor.comissoes;

do $$
declare
  v_qtd integer;
begin
  -- Vendedor: só a própria linha, e nenhuma margem.
  perform set_config('app.usuario_id',  'aaaaaaaa-0000-4000-8000-000000000012', true);
  perform set_config('app.perfil',      'gerente_contas', true);
  perform set_config('app.parceiro_id', '', true);
  select count(*) into v_qtd from valor.comissoes where beneficiario_tipo <> 'vendedor_interno';
  if v_qtd <> 0 then
    raise exception 'O vendedor enxergou % linha de comissão que não é dele.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.margem_contrato;
  if v_qtd <> 0 then
    raise exception 'O vendedor enxergou margem, e não deveria.';
  end if;

  -- Parceiro: só a própria linha, nenhum contrato, nenhuma parcela, nenhuma margem.
  perform set_config('app.usuario_id',  'aaaaaaaa-0000-4000-8000-000000000014', true);
  perform set_config('app.perfil',      'parceiro', true);
  perform set_config('app.parceiro_id', 'aaaaaaaa-0000-4000-8000-000000000021', true);
  select count(*) into v_qtd from valor.comissoes where beneficiario_tipo <> 'parceiro';
  if v_qtd <> 0 then
    raise exception 'O parceiro enxergou % linha de comissão de terceiro.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.contratos;
  if v_qtd <> 0 then
    raise exception 'O parceiro enxergou contrato, e não pode.';
  end if;
  select count(*) into v_qtd from valor.parcelas;
  if v_qtd <> 0 then
    raise exception 'O parceiro enxergou parcela, e não pode.';
  end if;
  select count(*) into v_qtd from valor.margem_contrato;
  if v_qtd <> 0 then
    raise exception 'O parceiro enxergou margem, e não pode.';
  end if;

  -- Conselheiro: o contrato da conta dele, a própria remuneração, nenhuma margem.
  perform set_config('app.usuario_id',  'aaaaaaaa-0000-4000-8000-000000000013', true);
  perform set_config('app.perfil',      'conselheiro', true);
  perform set_config('app.parceiro_id', '', true);
  select count(*) into v_qtd from valor.comissoes where beneficiario_tipo <> 'conselheiro';
  if v_qtd <> 0 then
    raise exception 'O conselheiro enxergou % linha de comissão de terceiro.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.contratos;
  if v_qtd <> 1 then
    raise exception 'O conselheiro deveria enxergar o contrato da conta dele. Enxergou %.', v_qtd;
  end if;
  select count(*) into v_qtd
    from valor.contratos_conselheiros
   where usuario_id <> 'aaaaaaaa-0000-4000-8000-000000000013';
  if v_qtd <> 0 then
    raise exception 'O conselheiro enxergou a remuneração de outro conselheiro.';
  end if;
  select count(*) into v_qtd from valor.margem_contrato;
  if v_qtd <> 0 then
    raise exception 'O conselheiro enxergou margem, e não deveria.';
  end if;

  raise notice 'TESTE 4 passou: cada um enxerga a própria linha, o parceiro não alcança contrato, parcela nem margem, e margem é só de quem vê confidencial.';
end $$;

reset role;

\echo ''
\echo '=================================================================='
\echo 'TESTE 5 · a apuração é privativa de quem cuida do dinheiro'
\echo '=================================================================='

do $$
declare
  v_erro text;
begin
  perform set_config('app.perfil', 'gerente_contas', true);
  begin
    perform valor.apurar_comissoes('aaaaaaaa-0000-4000-8000-000000000071');
    raise exception 'A apuração aceitou uma sessão de gerente de contas, e não deveria.';
  exception when sqlstate 'P0001' then
    get stacked diagnostics v_erro = message_text;
    if v_erro not like 'Apurar comissão é privativo%' then
      raise;
    end if;
    raise notice 'TESTE 5 passou: %', v_erro;
  end;
  perform set_config('app.perfil', 'financeiro', true);
end $$;

\echo ''
\echo 'Todos os testes passaram. Nada foi gravado: a transação é desfeita agora.'

rollback;
