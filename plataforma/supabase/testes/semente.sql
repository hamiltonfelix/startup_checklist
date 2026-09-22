-- Teste de regressão · a semente do inquilino, a idempotência e o white label limpo
-- Dono: Curador de Catálogo. Nenhum outro agente altera este arquivo.
--
-- Como rodar, num banco onde as migrações já aplicaram:
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d fab_sem -f testes/semente.sql
--
-- O teste inteiro vive dentro de uma transação e desfaz tudo no final. Pode
-- rodar quantas vezes quiser, no mesmo banco, sem deixar resíduo.
--
-- Todo dado aqui é fictício. Os dois endereços de e-mail terminam em domínio
-- reservado para exemplo, e não existem. Nenhum preço, nenhum valor de contrato
-- e nenhum telefone entram neste arquivo.
--
-- O que este teste prova:
--   1. valor.criar_inquilino no perfil felix produz o catálogo completo da casa,
--      a configuração da casa e um único administrador master.
--   2. A mesma função rodando duas vezes não duplica nada.
--   3. Dois inquilinos lado a lado, um felix e um neutro, com o papel sem
--      privilégio, e nenhum dado de um alcançando o outro.
--   4. A prova do white label: a varredura de toda linha semeada do inquilino
--      neutro procurando as palavras e as cores da casa devolve zero ocorrência,
--      e a mesma varredura acha as palavras no inquilino da casa, o que mostra
--      que o varredor funciona e não está calado.
--   5. A meta nasce vazia, e nenhum preço entra no catálogo.

\set ON_ERROR_STOP on
\pset border 2
\pset null 'nulo'

begin;

-- ------------------------------------------------------------ os dois inquilinos

select valor.criar_inquilino(
  'Casa de Teste', 'casa-de-teste',
  'administrador@exemplo.invalido', 'felix') as id_felix \gset

select valor.criar_inquilino(
  'Cliente White Label de Teste', 'cliente-white-label-de-teste',
  'administrador@outroexemplo.invalido', 'neutro') as id_neutro \gset

select id as usuario_felix  from valor.usuarios where inquilino_id = :'id_felix'  \gset
select id as usuario_neutro from valor.usuarios where inquilino_id = :'id_neutro' \gset

-- Os identificadores viajam por parâmetro de sessão porque o psql não substitui
-- variável dentro de bloco com aspas em cifrão, e os blocos abaixo precisam deles.
select set_config('teste.id_felix',       :'id_felix',       true) as ignorado;
select set_config('teste.id_neutro',      :'id_neutro',      true) as ignorado;
select set_config('teste.usuario_felix',  :'usuario_felix',  true) as ignorado;
select set_config('teste.usuario_neutro', :'usuario_neutro', true) as ignorado;

\echo ''
\echo '=================================================================='
\echo 'TESTE 1 · o perfil felix nasce com o catálogo e o administrador master'
\echo '=================================================================='

\echo ''
\echo 'O catálogo do portfólio:'
select o.ordem, o.codigo, o.nome, o.familia, o.modalidade,
       o.niveis_aceitos, o.gera_turma, o.ativa, o.sugerida
  from valor.ofertas o
 where o.inquilino_id = :'id_felix'
 order by o.ordem;

\echo ''
\echo 'A configuração da casa, sem os prazos que a migração 0012 já semeia:'
select c.grupo, c.chave, c.valor, c.rotulo, c.editavel_por
  from valor.configuracoes c
 where c.inquilino_id = :'id_felix'
   and c.grupo in ('comissao', 'parceria', 'meta', 'conselho', 'identidade')
 order by c.grupo, c.chave;

\echo ''
\echo 'Os prazos e o limite de concentração, garantidos pela semente:'
select c.chave, c.valor, c.rotulo
  from valor.configuracoes c
 where c.inquilino_id = :'id_felix'
   and c.grupo in ('alertas', 'higiene')
 order by c.chave;

\echo ''
\echo 'O primeiro usuário:'
select u.nome, u.perfil, u.mfa_obrigatorio, u.ativo, u.auth_id
  from valor.usuarios u
 where u.inquilino_id = :'id_felix';

\echo ''
\echo 'O percentual de escopo inquilino, sem o qual a apuração de comissão trava:'
select p.escopo, p.rotulo, p.imposto_percentual,
       p.comissao_vendedor_percentual, p.comissao_parceiro_percentual
  from valor.percentuais_padrao p
 where p.inquilino_id = :'id_felix';

do $$
declare
  v_felix   uuid := current_setting('teste.id_felix')::uuid;
  v_qtd     integer;
  v_texto   text;
  v_niveis  valor.nivel_contrato[];
  v_admin   valor.usuarios%rowtype;
begin
  -- O catálogo inteiro: sete programas, sete serviços e o Sprint inativo.
  select count(*) into v_qtd from valor.ofertas where inquilino_id = v_felix;
  if v_qtd <> 15 then
    raise exception 'Esperava 15 ofertas no perfil felix, sete programas mais sete serviços mais o Sprint inativo. Vieram %.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and familia = 'Programas de Valor' and ativa;
  if v_qtd <> 7 then
    raise exception 'Esperava 7 Programas de Valor ativos. Vieram %.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and familia = 'Serviços';
  if v_qtd <> 7 then
    raise exception 'Esperava 7 serviços fora dos programas. Vieram %.', v_qtd;
  end if;

  -- Todo programa gera turma no BRM. Nenhum serviço gera.
  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and familia = 'Programas de Valor' and ativa and not gera_turma;
  if v_qtd <> 0 then
    raise exception '% programa ativo não gera turma, e todo programa gera.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and familia = 'Serviços' and gera_turma;
  if v_qtd <> 0 then
    raise exception '% serviço fora dos programas gera turma, e nenhum deveria.', v_qtd;
  end if;

  -- Os níveis aceitos por oferta, exatamente como o catálogo fechou.
  select niveis_aceitos into v_niveis from valor.ofertas
   where inquilino_id = v_felix and codigo = 'conselho-dedicado';
  if v_niveis <> '{n1,n2,n3}'::valor.nivel_contrato[] then
    raise exception 'O conselho dedicado aceita N1, N2 e N3. Veio %.', v_niveis;
  end if;

  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and 'n2' = any (niveis_aceitos);
  if v_qtd <> 3 then
    raise exception 'O N2 vale para conselho dedicado, C-level as a service e modelo por resultado, três ofertas. Vieram %.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and 'n3' = any (niveis_aceitos);
  if v_qtd <> 2 then
    raise exception 'O N3 vale para conselho dedicado e modelo por equity, duas ofertas. Vieram %.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and not ('n1' = any (niveis_aceitos));
  if v_qtd <> 0 then
    raise exception 'O N1 vale para todas as ofertas, e % ficou de fora.', v_qtd;
  end if;

  -- O Sprint de Valor entra inativo e fora da sugestão.
  select count(*) into v_qtd from valor.ofertas
   where inquilino_id = v_felix and codigo = 'sprint-de-valor'
     and not ativa and not sugerida;
  if v_qtd <> 1 then
    raise exception 'O Sprint de Valor precisa estar no catálogo, inativo e não sugerido.';
  end if;

  -- A configuração da casa.
  select count(*) into v_qtd from valor.configuracoes
   where inquilino_id = v_felix
     and grupo in ('comissao', 'parceria', 'meta', 'conselho', 'identidade');
  if v_qtd <> 20 then
    raise exception 'Esperava 20 chaves de configuração da casa, e vieram %.', v_qtd;
  end if;

  if valor.configuracao_num(v_felix, 'comissao.vendedor_interno_percentual', -1) <> 10 then
    raise exception 'A comissão do Gerente de Contas precisa nascer em 10 por cento.';
  end if;
  if valor.configuracao_num(v_felix, 'comissao.parceiro_percentual', -1) <> 10 then
    raise exception 'A comissão do parceiro precisa nascer em 10 por cento.';
  end if;
  if valor.configuracao_num(v_felix, 'comissao.imposto_percentual', -1) <> 15 then
    raise exception 'O imposto médio precisa nascer em 15 por cento.';
  end if;
  if valor.configuracao_num(v_felix, 'parceria.protecao_indicacao_dias', -1) <> 90 then
    raise exception 'A proteção de indicação precisa nascer em 90 dias.';
  end if;
  if valor.configuracao_num(v_felix, 'conselho.reunioes_por_ano', -1) <> 48 then
    raise exception 'O calendário de conselho precisa nascer com 48 reuniões no ano.';
  end if;
  if valor.configuracao_num(v_felix, 'conselho.nps_periodicidade_meses', -1) <> 3 then
    raise exception 'O NPS precisa nascer trimestral.';
  end if;
  if valor.configuracao_num(v_felix, 'conselho.nota_conselheiro_periodicidade_meses', -1) <> 6 then
    raise exception 'A nota do conselheiro precisa nascer semestral.';
  end if;
  if valor.configuracao_num(v_felix, 'conselho.historico_periodicidade_meses', -1) <> 3 then
    raise exception 'O Histórico de Valor precisa nascer obrigatório por trimestre.';
  end if;

  -- O recesso de meados de dezembro a meados de janeiro, em dia e mês.
  select valor #>> '{}' into v_texto from valor.configuracoes
   where inquilino_id = v_felix and chave = 'conselho.recesso_inicio';
  if v_texto <> '12-15' then
    raise exception 'O recesso começa em meados de dezembro. Veio %.', coalesce(v_texto, 'nulo');
  end if;
  select valor #>> '{}' into v_texto from valor.configuracoes
   where inquilino_id = v_felix and chave = 'conselho.recesso_fim';
  if v_texto <> '01-15' then
    raise exception 'O recesso termina em meados de janeiro. Veio %.', coalesce(v_texto, 'nulo');
  end if;

  -- Os prazos que a semente garante ao chamar a semeadura de alertas.
  if valor.configuracao_num(v_felix, 'alerta.lead_sem_dono_dias', -1) <> 3 then
    raise exception 'O alerta de lead sem dono precisa nascer em 3 dias.';
  end if;
  if valor.configuracao_num(v_felix, 'alerta.negocio_parado_dias_piso', -1) <> 30 then
    raise exception 'O alarme de negócio parado precisa nascer em 30 dias.';
  end if;
  if valor.configuracao_num(v_felix, 'alerta.plano_trabalho_aviso_amarelo_dias', -1) <> 7
     or valor.configuracao_num(v_felix, 'alerta.plano_trabalho_aviso_vermelho_dias', -1) <> 1 then
    raise exception 'O Plano de Trabalho vencendo avisa a 7 e a 1 dia.';
  end if;
  if valor.configuracao_num(v_felix, 'alerta.contrato_renovacao_dias', -1) <> 90
     or valor.configuracao_num(v_felix, 'alerta.contrato_aviso_amarelo_dias', -1) <> 60
     or valor.configuracao_num(v_felix, 'alerta.contrato_aviso_vermelho_dias', -1) <> 30 then
    raise exception 'O contrato vencendo avisa a 90, a 60 e a 30 dias.';
  end if;
  if valor.configuracao_num(v_felix, 'alerta.ata_nao_enviada_horas', -1) <> 24 then
    raise exception 'A ata não enviada alerta em 24 horas.';
  end if;
  if valor.configuracao_num(v_felix, 'alerta.concentracao_limite', -1) <> 0.5 then
    raise exception 'O alarme de concentração dispara quando os dois maiores passam de 50 por cento.';
  end if;

  -- A identidade visual da casa entra em dado, não em código.
  select valor #>> '{marca}' into v_texto from valor.configuracoes
   where inquilino_id = v_felix and chave = 'identidade.cores';
  if v_texto <> '#5E1E3A' then
    raise exception 'A cor de marca do perfil felix é o vinho. Veio %.', coalesce(v_texto, 'nulo');
  end if;
  select valor #>> '{titulo}' into v_texto from valor.configuracoes
   where inquilino_id = v_felix and chave = 'identidade.fontes';
  if v_texto <> 'Oswald' then
    raise exception 'A fonte de título do perfil felix é Oswald. Veio %.', coalesce(v_texto, 'nulo');
  end if;

  -- O primeiro usuário, um só, administrador master, com múltiplo fator exigido.
  select count(*) into v_qtd from valor.usuarios where inquilino_id = v_felix;
  if v_qtd <> 1 then
    raise exception 'O inquilino nasce com um único usuário. Nasceu com %.', v_qtd;
  end if;
  select * into v_admin from valor.usuarios where inquilino_id = v_felix;
  if v_admin.perfil <> 'admin_master' then
    raise exception 'O primeiro usuário precisa ser administrador master. Veio %.', v_admin.perfil;
  end if;
  if not v_admin.mfa_obrigatorio then
    raise exception 'O administrador master nasce com múltiplo fator obrigatório.';
  end if;
  if v_admin.auth_id is not null then
    raise exception 'O administrador master nasce sem identidade no provedor: ela chega quando ele aceita o convite.';
  end if;

  -- O percentual de escopo inquilino, que a conta da comissão exige.
  select count(*) into v_qtd from valor.percentuais_padrao
   where inquilino_id = v_felix and escopo = 'inquilino'
     and imposto_percentual = 15.0000
     and comissao_vendedor_percentual = 10.0000
     and comissao_parceiro_percentual = 10.0000;
  if v_qtd <> 1 then
    raise exception 'A linha de percentual de escopo inquilino precisa nascer com 15, 10 e 10.';
  end if;

  -- O que as outras migrações semeiam, garantido pela mesma porta de entrada.
  select count(*) into v_qtd from valor.banco_pautas where inquilino_id = v_felix;
  if v_qtd < 21 then
    raise exception 'O banco de pautas precisa nascer com os 15 temas de governança e as 6 famílias de gestão. Vieram %.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.modelos_ata where inquilino_id = v_felix;
  if v_qtd < 1 then
    raise exception 'O modelo de ata precisa nascer junto com o inquilino.';
  end if;
  select count(*) into v_qtd from valor.regras_alerta where inquilino_id = v_felix;
  if v_qtd < 1 then
    raise exception 'As regras de alerta precisam nascer junto com o inquilino.';
  end if;
  select count(*) into v_qtd from valor.contextos_gtd where inquilino_id = v_felix;
  if v_qtd < 1 then
    raise exception 'O vocabulário de atividades precisa nascer junto com o inquilino.';
  end if;

  raise notice 'TESTE 1 passou: 15 ofertas, sendo 7 programas, 7 serviços e o Sprint inativo · 20 chaves da casa mais os prazos · 15, 10 e 10 de percentual · um administrador master com múltiplo fator.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 2 · idempotência: criar e semear de novo não duplica nada'
\echo '=================================================================='

select valor.semear_inquilino(:'id_felix', 'felix')  as linhas_na_segunda_semeadura;
select valor.semear_inquilino(:'id_felix', 'felix')  as linhas_na_terceira_semeadura;
select valor.semear_inquilino(:'id_neutro', 'neutro') as linhas_na_segunda_semeadura_neutra;

select valor.criar_inquilino(
  'Casa de Teste', 'casa-de-teste',
  'administrador@exemplo.invalido', 'felix') = :'id_felix' as devolveu_o_mesmo_inquilino;

select
  (select count(*) from valor.inquilinos    where id           = :'id_felix') as inquilinos,
  (select count(*) from valor.ofertas       where inquilino_id = :'id_felix') as ofertas,
  (select count(*) from valor.configuracoes where inquilino_id = :'id_felix') as configuracoes,
  (select count(*) from valor.usuarios      where inquilino_id = :'id_felix') as usuarios,
  (select count(*) from valor.percentuais_padrao where inquilino_id = :'id_felix') as percentuais,
  (select count(*) from valor.banco_pautas  where inquilino_id = :'id_felix') as pautas,
  (select count(*) from valor.colunas_kanban where inquilino_id = :'id_felix') as colunas;

do $$
declare
  v_felix  uuid := current_setting('teste.id_felix')::uuid;
  v_neutro uuid := current_setting('teste.id_neutro')::uuid;
  v_novas  integer;
  v_qtd    integer;
begin
  v_novas := valor.semear_inquilino(v_felix, 'felix');
  if v_novas <> 0 then
    raise exception 'A quinta semeadura criou % linha, e devia criar zero.', v_novas;
  end if;

  select count(*) into v_qtd from valor.ofertas where inquilino_id = v_felix;
  if v_qtd <> 15 then
    raise exception 'Depois de cinco semeaduras o catálogo tem % ofertas, e devia ter 15.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.ofertas where inquilino_id = v_neutro;
  if v_qtd <> 14 then
    raise exception 'Depois de duas semeaduras o catálogo neutro tem % ofertas, e devia ter 14.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.usuarios where inquilino_id = v_felix;
  if v_qtd <> 1 then
    raise exception 'Criar o inquilino de novo cadastrou um segundo usuário. Há % usuários.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.inquilinos;
  if v_qtd <> 2 then
    raise exception 'Criar o inquilino de novo criou uma segunda linha em valor.inquilinos. Há % inquilinos.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.percentuais_padrao where inquilino_id = v_felix;
  if v_qtd <> 1 then
    raise exception 'A semente abriu % linhas de percentual do inquilino, e devia abrir uma só.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.colunas_kanban where inquilino_id = v_felix;
  if v_qtd <> 6 then
    raise exception 'A semente do quadro duplicou coluna: há %, e deviam ser 6.', v_qtd;
  end if;

  select count(*) into v_qtd
    from (select chave from valor.configuracoes where inquilino_id = v_felix
           group by chave having count(*) > 1) d;
  if v_qtd <> 0 then
    raise exception '% chave de configuração aparece mais de uma vez.', v_qtd;
  end if;

  raise notice 'TESTE 2 passou: cinco semeaduras do mesmo inquilino, ainda 15 ofertas, 1 usuário, 1 linha de percentual, 6 colunas e nenhuma chave repetida.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 3 · dois inquilinos lado a lado, no papel sem privilégio'
\echo '=================================================================='

set role valor_aplicacao;

select set_config('app.inquilino_id', current_setting('teste.id_felix'), true) as ignorado;
select set_config('app.usuario_id',   current_setting('teste.usuario_felix'), true) as ignorado;
select set_config('app.perfil',       'admin_master', true) as ignorado;
select set_config('app.parceiro_id',  '', true) as ignorado;

\echo ''
\echo 'Sessão do administrador da casa:'
select (select count(*) from valor.inquilinos)    as inquilinos_visiveis,
       (select count(*) from valor.ofertas)       as ofertas_visiveis,
       (select count(*) from valor.configuracoes) as configuracoes_visiveis,
       (select count(*) from valor.usuarios)      as usuarios_visiveis,
       (select count(*) from valor.banco_pautas)  as pautas_visiveis;

select set_config('app.inquilino_id', current_setting('teste.id_neutro'), true) as ignorado;
select set_config('app.usuario_id',   current_setting('teste.usuario_neutro'), true) as ignorado;

\echo ''
\echo 'Sessão do administrador do inquilino white label:'
select (select count(*) from valor.inquilinos)    as inquilinos_visiveis,
       (select count(*) from valor.ofertas)       as ofertas_visiveis,
       (select count(*) from valor.configuracoes) as configuracoes_visiveis,
       (select count(*) from valor.usuarios)      as usuarios_visiveis,
       (select count(*) from valor.banco_pautas)  as pautas_visiveis;

\echo ''
\echo 'O catálogo que o inquilino white label enxerga:'
select o.ordem, o.codigo, o.nome, o.familia, o.modalidade, o.niveis_aceitos, o.gera_turma
  from valor.ofertas o order by o.ordem;

do $$
declare
  v_felix  uuid := current_setting('teste.id_felix')::uuid;
  v_neutro uuid := current_setting('teste.id_neutro')::uuid;
  v_qtd    integer;
begin
  -- Sessão da casa: enxerga o próprio inquilino e nada do vizinho.
  perform set_config('app.inquilino_id', v_felix::text, true);
  perform set_config('app.usuario_id', current_setting('teste.usuario_felix'), true);

  select count(*) into v_qtd from valor.ofertas;
  if v_qtd <> 15 then
    raise exception 'O administrador da casa enxerga % ofertas, e o catálogo dele tem 15.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.ofertas where inquilino_id = v_neutro;
  if v_qtd <> 0 then
    raise exception 'O administrador da casa alcançou % oferta do inquilino vizinho.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.configuracoes where inquilino_id = v_neutro;
  if v_qtd <> 0 then
    raise exception 'O administrador da casa alcançou % configuração do inquilino vizinho.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.usuarios where inquilino_id = v_neutro;
  if v_qtd <> 0 then
    raise exception 'O administrador da casa alcançou o usuário do inquilino vizinho.';
  end if;
  select count(*) into v_qtd from valor.inquilinos;
  if v_qtd <> 1 then
    raise exception 'O administrador da casa enxerga % inquilinos, e deveria enxergar só o próprio.', v_qtd;
  end if;

  -- Sessão do white label: enxerga o próprio catálogo e nada da casa.
  perform set_config('app.inquilino_id', v_neutro::text, true);
  perform set_config('app.usuario_id', current_setting('teste.usuario_neutro'), true);

  select count(*) into v_qtd from valor.ofertas;
  if v_qtd <> 14 then
    raise exception 'O inquilino white label enxerga % ofertas, e o catálogo dele tem 14.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.ofertas where inquilino_id = v_felix;
  if v_qtd <> 0 then
    raise exception 'O inquilino white label alcançou % oferta da casa.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.configuracoes where inquilino_id = v_felix;
  if v_qtd <> 0 then
    raise exception 'O inquilino white label alcançou % configuração da casa.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.usuarios where inquilino_id = v_felix;
  if v_qtd <> 0 then
    raise exception 'O inquilino white label alcançou o usuário da casa.';
  end if;
  select count(*) into v_qtd from valor.banco_pautas where inquilino_id = v_felix;
  if v_qtd <> 0 then
    raise exception 'O inquilino white label alcançou % tema de pauta da casa.', v_qtd;
  end if;
  select count(*) into v_qtd from valor.inquilinos;
  if v_qtd <> 1 then
    raise exception 'O inquilino white label enxerga % inquilinos, e deveria enxergar só o próprio.', v_qtd;
  end if;

  -- Abrir inquilino não é operação de usuário de aplicação, e isso é decidido
  -- no banco: valor.inquilinos tem segurança de linha e nenhuma política de
  -- escrita, então só o dono das tabelas, ou a chave de serviço do Supabase,
  -- consegue criar. A função é invocadora de propósito, e não definidora.
  begin
    perform valor.criar_inquilino(
      'Inquilino Clandestino', 'inquilino-clandestino',
      'clandestino@exemplo.invalido', 'neutro');
    raise exception 'O papel sem privilégio abriu um inquilino novo, e não deveria.';
  exception when insufficient_privilege then
    raise notice 'O papel sem privilégio não abre inquilino: a segurança de linha barra a escrita em valor.inquilinos.';
  end;

  raise notice 'TESTE 3 passou: cada inquilino enxerga o próprio catálogo, a própria configuração, o próprio usuário e o próprio banco de pautas, nenhuma linha atravessa para o vizinho, e o papel sem privilégio não abre inquilino.';
end $$;

reset role;

\echo ''
\echo '=================================================================='
\echo 'TESTE 4 · a prova do white label: nenhuma palavra da casa no neutro'
\echo '=================================================================='

\echo ''
\echo 'A varredura roda com o dono das tabelas, para que a segurança de linha'
\echo 'não esconda justamente a linha que precisaria aparecer.'

\echo ''
\echo 'O que a varredura acha no inquilino da casa, que prova que ela funciona:'
select v.tabela, v.coluna, v.achado, count(*) as ocorrencias
  from valor.vazamento_de_marca(:'id_felix') v
 group by 1, 2, 3
 order by 1, 2, 3;

\echo ''
\echo 'O que a varredura acha no inquilino white label:'
select v.tabela, v.coluna, v.achado, v.trecho
  from valor.vazamento_de_marca(:'id_neutro') v
 order by 1, 2, 3;

-- ------------------------------------------------------------------- a sonda
-- Varredura que nunca acha nada não prova coisa alguma. Antes da prova de
-- verdade, uma oferta de mentira, carregando as cinco palavras do pedido, entra
-- no inquilino white label. A varredura precisa acusar todas. Em seguida a sonda
-- é desfeita pelo ponto de retorno, sem apagar linha nenhuma.

savepoint sonda;

insert into valor.ofertas
  (inquilino_id, codigo, nome, familia, modalidade, publico_alvo, estrutura)
values
  (:'id_neutro', 'sonda-do-teste',
   'Conselho de Valor e Negócios de Valor da Felix',
   'Programas de Valor', 'pontual',
   'Sonda do teste, que precisa ser acusada pela varredura.',
   'Mesa do CEO, com a cor #5E1E3A e a fonte Oswald.');

\echo ''
\echo 'Com a sonda dentro, a varredura precisa acusar o vazamento:'
select v.tabela, v.coluna, v.achado from valor.vazamento_de_marca(:'id_neutro') v order by 3;

do $$
declare
  v_neutro uuid := current_setting('teste.id_neutro')::uuid;
  v_qtd    integer;
  v_termo  text;
begin
  foreach v_termo in array array['felix', 'conselho de valor', 'negócios de valor', 'mesa do ceo', 'oswald', '#5E1E3A']
  loop
    select count(*) into v_qtd
      from valor.vazamento_de_marca(v_neutro, array[v_termo], array[]::text[]);
    if v_qtd = 0 then
      raise exception 'A varredura não acusou a sonda que carrega %. Com o varredor cego, a prova do white label não vale nada.', v_termo;
    end if;
  end loop;

  select count(*) into v_qtd
    from valor.vazamento_de_marca(v_neutro, array[]::text[], array['\mValor\M']);
  if v_qtd = 0 then
    raise exception 'A varredura não acusou a marca Valor como palavra inteira dentro da sonda.';
  end if;

  raise notice 'A sonda foi acusada em todas as palavras do pedido. O varredor enxerga.';
end $$;

rollback to savepoint sonda;
release savepoint sonda;

\echo ''
\echo 'Sonda desfeita. O catálogo neutro voltou ao tamanho de origem:'
select count(*) as ofertas_no_inquilino_neutro from valor.ofertas where inquilino_id = :'id_neutro';

\echo ''
\echo 'A varredura com as cinco palavras do pedido, escritas à mão:'
select count(*) as ocorrencias_no_inquilino_neutro
  from valor.vazamento_de_marca(
    :'id_neutro',
    array['Felix', 'Conselho de Valor', 'Negócios de Valor', 'Mesa do CEO'],
    array['\mValor\M']);

do $$
declare
  v_felix   uuid := current_setting('teste.id_felix')::uuid;
  v_neutro  uuid := current_setting('teste.id_neutro')::uuid;
  v_qtd     integer;
  v_primeiro record;
begin
  -- A sonda saiu, então o catálogo neutro voltou às 14 ofertas de origem.
  select count(*) into v_qtd from valor.ofertas where inquilino_id = v_neutro;
  if v_qtd <> 14 then
    raise exception 'A sonda não foi desfeita: o catálogo neutro tem % ofertas, e devia ter 14.', v_qtd;
  end if;

  -- O varredor precisa continuar achando as palavras da casa no inquilino da
  -- casa, onde elas são legítimas.
  select count(*) into v_qtd from valor.vazamento_de_marca(v_felix);
  if v_qtd = 0 then
    raise exception 'A varredura não achou nenhuma palavra da casa no inquilino da casa. O varredor está quebrado.';
  end if;

  -- Agora a prova que importa: zero ocorrência no inquilino neutro.
  select count(*) into v_qtd from valor.vazamento_de_marca(v_neutro);
  if v_qtd <> 0 then
    select * into v_primeiro from valor.vazamento_de_marca(v_neutro) limit 1;
    raise exception 'O perfil neutro vazou % ocorrência de palavra da casa. A primeira está em %.%, com o achado %, no trecho %.',
      v_qtd, v_primeiro.tabela, v_primeiro.coluna, v_primeiro.achado, v_primeiro.trecho;
  end if;

  -- E a mesma prova só com as cinco palavras do pedido, escritas à mão, para
  -- não depender da lista que a própria migração mantém.
  select count(*) into v_qtd from valor.vazamento_de_marca(
    v_neutro,
    array['Felix', 'Conselho de Valor', 'Negócios de Valor', 'Mesa do CEO'],
    array['\mValor\M']);
  if v_qtd <> 0 then
    raise exception 'O perfil neutro vazou % ocorrência das palavras Felix, Conselho de Valor, Negócios de Valor, Mesa do CEO ou Valor.', v_qtd;
  end if;

  -- Nenhuma cor da casa dentro do inquilino white label, inclusive a cor que
  -- outra semente pinta no quadro de atividades.
  select count(*) into v_qtd from valor.vazamento_de_marca(
    v_neutro, valor.cores_da_casa(), array[]::text[]);
  if v_qtd <> 0 then
    select * into v_primeiro from valor.vazamento_de_marca(v_neutro, valor.cores_da_casa(), array[]::text[]) limit 1;
    raise exception 'O perfil neutro vazou a cor % em %.%.', v_primeiro.achado, v_primeiro.tabela, v_primeiro.coluna;
  end if;

  raise notice 'TESTE 4 passou: a varredura acha as palavras da casa no inquilino da casa e devolve zero ocorrência no inquilino white label, tanto pela lista completa quanto pelas cinco palavras do pedido, e nenhuma das dez cores da casa aparece.';
end $$;

\echo ''
\echo '=================================================================='
\echo 'TESTE 5 · a meta nasce vazia e nenhum preço entra no catálogo'
\echo '=================================================================='

\echo ''
\echo 'As metas do período, como nascem:'
select c.chave, c.valor, jsonb_typeof(c.valor) as tipo, c.rotulo
  from valor.configuracoes c
 where c.inquilino_id = :'id_felix' and c.grupo = 'meta'
 order by c.chave;

\echo ''
\echo 'Colunas numéricas em valor.ofertas, onde um preço poderia se esconder:'
select a.attname as coluna, format_type(a.atttypid, a.atttypmod) as tipo
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'valor' and c.relname = 'ofertas'
   and a.attnum > 0 and not a.attisdropped
   and format_type(a.atttypid, a.atttypmod) like 'numeric%';

do $$
declare
  v_felix uuid := current_setting('teste.id_felix')::uuid;
  v_qtd   integer;
begin
  -- A meta nasce vazia: sem ela o painel mostra cobertura como indisponível,
  -- e não um número errado.
  select count(*) into v_qtd from valor.configuracoes
   where inquilino_id = v_felix
     and chave in ('meta.anual_casa', 'meta.trimestral_casa')
     and jsonb_typeof(valor) = 'null';
  if v_qtd <> 2 then
    raise exception 'A meta anual e a meta trimestral da casa nascem vazias. % delas nasceu preenchida.', 2 - v_qtd;
  end if;

  select count(*) into v_qtd from valor.configuracoes
   where inquilino_id = v_felix
     and chave in ('meta.anual_por_pessoa', 'meta.trimestral_por_pessoa')
     and valor = '{}'::jsonb;
  if v_qtd <> 2 then
    raise exception 'A meta por pessoa nasce vazia, sem ninguém dentro.';
  end if;

  -- Nenhum preço no catálogo, nem em coluna nem em texto.
  select count(*) into v_qtd
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'valor' and c.relname = 'ofertas'
     and a.attnum > 0 and not a.attisdropped
     and format_type(a.atttypid, a.atttypmod) like 'numeric%';
  if v_qtd <> 0 then
    raise exception 'A tabela de ofertas ganhou % coluna numérica, e preço não mora no catálogo.', v_qtd;
  end if;

  select count(*) into v_qtd from valor.ofertas
   where coalesce(nome, '') || ' ' || coalesce(publico_alvo, '') || ' ' || coalesce(estrutura, '')
         ~* 'R\$|pre[çc]o|mensalidade de|[0-9],[0-9][0-9]\M';
  if v_qtd <> 0 then
    raise exception '% oferta traz algo com cara de preço no texto, e nenhum preço entra no catálogo.', v_qtd;
  end if;

  raise notice 'TESTE 5 passou: as quatro chaves de meta nascem vazias, a tabela de ofertas não tem coluna numérica e nenhum texto do catálogo traz preço.';
end $$;

\echo ''
\echo 'Todos os testes passaram. Nada foi gravado: a transação é desfeita agora.'

rollback;
