-- 0016 · Semente do inquilino: catálogo do portfólio, configuração e primeiro usuário
-- Dono: Curador de Catálogo. Nenhum outro agente altera este arquivo.
--
-- Por que este arquivo existe: a plataforma precisa nascer sabendo o que a casa
-- vende e como a casa trabalha, sem ninguém digitar nada. E precisa nascer assim
-- para qualquer inquilino, porque a versão white label não é projeto futuro, é
-- entrega do programa Negócios de Valor.
--
-- Por isso a semente é função, e não insert solto:
--
--   valor.semear_inquilino(p_inquilino_id uuid, p_perfil text default 'felix')
--
-- Dois perfis de semente:
--   'felix'   o catálogo completo da casa, com os sete Programas de Valor, os
--             sete serviços fora dos programas e a identidade visual da casa.
--   'neutro'  a mesma estrutura sem uma linha de conteúdo da casa. Oferta
--             genérica, configuração padrão, paleta neutra, nenhum nome de
--             programa da casa.
--
-- Idempotente do começo ao fim: toda inserção termina em on conflict do nothing,
-- e a função devolve quantas linhas nasceram nesta chamada. Rodar de novo devolve
-- zero e não duplica nada.
--
-- Nenhum preço entra aqui, em hipótese nenhuma. Nenhum endereço de e-mail entra
-- aqui: o endereço do administrador master chega por parâmetro de
-- valor.criar_inquilino.
--
-- Sobre o grupo e o rótulo de valor.configuracoes: `chave` e `grupo` são
-- identificadores, então vão em minúscula, sem acento e sem cedilha, no mesmo
-- padrão das chaves que as migrações 0011 e 0012 já semeiam. `rotulo` é texto de
-- tela, então vai em português com acentuação correta.

-- ------------------------------------------------ grava uma linha de configuração

-- Irmã de valor.gravar_configuracao, da migração 0011, com duas diferenças que a
-- semente precisa: aceita quem edita a chave na tela, e devolve quantas linhas
-- nasceram. É esse número que prova a idempotência sem precisar contar a tabela.
create or replace function valor.semear_configuracao(
  p_inquilino_id uuid,
  p_chave        text,
  p_valor        jsonb,
  p_rotulo       text,
  p_grupo        text,
  p_editavel_por valor.perfil_usuario default 'admin_master'
) returns integer language plpgsql as $funcao$
declare
  v_inseridas integer;
begin
  insert into valor.configuracoes
    (inquilino_id, chave, valor, rotulo, grupo, editavel_por)
  values
    (p_inquilino_id, p_chave, p_valor, p_rotulo, p_grupo, p_editavel_por)
  on conflict (inquilino_id, chave) do nothing;

  get diagnostics v_inseridas = row_count;
  return v_inseridas;
end;
$funcao$;

comment on function valor.semear_configuracao(uuid, text, jsonb, text, text, valor.perfil_usuario) is
  'Semeia uma chave de configuração com rótulo, grupo e quem edita. Não sobrescreve o que a casa já ajustou na tela, e devolve quantas linhas nasceram.';

-- ------------------------------------------------------- o catálogo do portfólio

-- Os números são os oficiais da casa, tirados do catálogo de portfólio. Preço
-- nenhum entra: preço vive no Plano de Trabalho e no Contrato de Valor, nunca no
-- catálogo, que é público dentro da plataforma inteira.
create or replace function valor.semear_ofertas(p_inquilino_id uuid, p_perfil text)
returns integer language plpgsql as $funcao$
declare
  v_inseridas integer;
begin
  if p_perfil = 'felix' then

    insert into valor.ofertas (
      inquilino_id, codigo, nome, familia, modalidade, niveis_aceitos,
      gera_turma, publico_alvo, estrutura, ativa, sugerida, ordem
    ) values
    -- ------------------------------------------------- os sete Programas de Valor
    (p_inquilino_id, 'conselho-dedicado', 'Conselho de Valor dedicado',
     'Programas de Valor', 'recorrente', '{n1,n2,n3}', true,
     'Donos e sócios de uma empresa.',
     'Encontros semanais de conselho, encontro semanal de gestão, pauta prioritária mensal e um presencial por mês. Recorrente anual, turma de um cliente.',
     true, true, 10),

    (p_inquilino_id, 'conselho-compartilhado', 'Conselho de Valor compartilhado',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Até 8 empresários de mercados diferentes.',
     '48 reuniões no ano, hotseat por membro, resumo semanal e um presencial por mês. Recorrente anual, turma multiempresa.',
     true, true, 20),

    (p_inquilino_id, 'negocios-de-valor', 'Negócios de Valor',
     'Programas de Valor', 'pontual_com_sustentacao', '{n1}', true,
     'Times comerciais B2B e B2G.',
     '12 encontros de 2h30 mais 8 semanas de sustentação. Variante de 10 encontros. Imersão de 3 dias. De 8 a 16 cadeiras. A unidade de venda é o time, e a turma pode ser dedicada ou compartilhada.',
     true, true, 30),

    (p_inquilino_id, 'lideranca-de-valor', 'Liderança de Valor',
     'Programas de Valor', 'pontual', '{n1}', true,
     'Sócios, C-level e líderes.',
     'Workshop de 2 dias, 8 módulos e 1 plano de desenvolvimento por participante.',
     true, true, 40),

    (p_inquilino_id, 'gestao-de-valor', 'Gestão de Valor',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Sócios e principais executivos.',
     '6 módulos, 48 temas e encontros semanais. Recorrente anual.',
     true, true, 50),

    (p_inquilino_id, 'mentoria-de-valor', 'Mentoria de Valor',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Donos e CEOs.',
     'Encontro semanal, deep-dive mensal e plano em 4 estações. Recorrente anual e individual, turma de um.',
     true, true, 60),

    (p_inquilino_id, 'executivo-de-valor', 'Executivo de Valor',
     'Programas de Valor', 'recorrente', '{n1}', true,
     'Ocupantes de cadeira do C-level.',
     'Mesa do CEO: 12 etapas em 6 meses, encontros quinzenais de 2h e índice próprio medido em T0, T90 e T180.',
     true, true, 70),

    -- Fora do site por decisão de julho de 2026. Continua no catálogo para o
    -- histórico não perder o que já foi vendido, inativo e fora da sugestão.
    (p_inquilino_id, 'sprint-de-valor', 'Sprint de Valor',
     'Programas de Valor', 'pontual', '{n1}', true,
     'Times que precisam de um ciclo curto de execução.',
     'Fora do site por decisão de julho de 2026. Disponível no catálogo para o histórico, inativo e não sugerido. Estrutura a confirmar antes de voltar a ser oferecido.',
     false, false, 80),

    -- --------------------------------------- os sete serviços fora dos programas
    (p_inquilino_id, 'consultoria-pontual', 'Consultoria pontual',
     'Serviços', 'pontual', '{n1}', false,
     'Empresa com um problema de escopo fechado.',
     'Escopo fechado, com entregável definido.',
     true, true, 110),

    (p_inquilino_id, 'consultoria-recorrente', 'Consultoria recorrente',
     'Serviços', 'recorrente', '{n1}', false,
     'Empresa que precisa de acompanhamento continuado.',
     'Mensalidade, com escopo revisto por ciclo.',
     true, true, 120),

    (p_inquilino_id, 'treinamento', 'Treinamento',
     'Serviços', 'pontual', '{n1}', false,
     'Times que precisam de capacitação em tema específico.',
     'Workshop ou palestra contratada. Aceita contratação pontual e contratação recorrente.',
     true, true, 130),

    (p_inquilino_id, 'c-level-as-a-service', 'C-level as a service',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa que precisa de cadeira executiva sem contratar em tempo integral.',
     'Executivo alocado por tempo determinado, com agenda e entregáveis acordados.',
     true, true, 140),

    (p_inquilino_id, 'modelo-por-resultado', 'Modelo por resultado',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa disposta a dividir o resultado gerado.',
     'Honorário menor mais participação nos resultados. Aceita contratação recorrente e pontual.',
     true, true, 150),

    (p_inquilino_id, 'modelo-por-equity', 'Equity',
     'Serviços', 'recorrente', '{n1,n3}', false,
     'Empresa em que a casa entra como sócia.',
     'Honorário mais participação societária. Depende de validação de advogado e de contador antes da assinatura.',
     true, true, 160),

    (p_inquilino_id, 'next-c-level', 'NEXT C-LEVEL',
     'Serviços', 'pontual', '{n1}', false,
     'A confirmar.',
     'Frente própria, catalogada para não se perder no funil. Modalidade, estrutura e nível a confirmar.',
     true, true, 170)

    on conflict (inquilino_id, codigo) do nothing;

  else

    -- O catálogo do perfil neutro. Mesma estrutura, mesma modalidade, mesmos
    -- níveis aceitos e mesma regra de turma. Nenhum nome, nenhum número e
    -- nenhuma história da casa. É este bloco que o white label recebe.
    insert into valor.ofertas (
      inquilino_id, codigo, nome, familia, modalidade, niveis_aceitos,
      gera_turma, publico_alvo, estrutura, ativa, sugerida, ordem
    ) values
    (p_inquilino_id, 'programa-conselho-dedicado', 'Conselho consultivo dedicado',
     'Programas', 'recorrente', '{n1,n2,n3}', true,
     'Donos e sócios de uma empresa.',
     'Encontros semanais de conselho, encontro semanal de gestão, pauta prioritária mensal e um presencial por mês.',
     true, true, 10),

    (p_inquilino_id, 'programa-conselho-compartilhado', 'Conselho consultivo compartilhado',
     'Programas', 'recorrente', '{n1}', true,
     'Grupo fechado de empresários de mercados diferentes.',
     'Reuniões semanais ao longo do ano, rodada individual por membro, resumo semanal e um presencial por mês.',
     true, true, 20),

    (p_inquilino_id, 'programa-comercial', 'Programa comercial',
     'Programas', 'pontual_com_sustentacao', '{n1}', true,
     'Times comerciais.',
     'Ciclo de encontros com semanas de sustentação, com imersão opcional e turma fechada por time.',
     true, true, 30),

    (p_inquilino_id, 'programa-lideranca', 'Programa de liderança',
     'Programas', 'pontual', '{n1}', true,
     'Sócios, executivos e líderes.',
     'Workshop de dois dias, dividido em módulos, com um plano de desenvolvimento por participante.',
     true, true, 40),

    (p_inquilino_id, 'programa-gestao', 'Programa de gestão',
     'Programas', 'recorrente', '{n1}', true,
     'Sócios e principais executivos.',
     'Módulos temáticos com encontros semanais ao longo do ano.',
     true, true, 50),

    (p_inquilino_id, 'programa-mentoria', 'Mentoria individual',
     'Programas', 'recorrente', '{n1}', true,
     'Donos e principais executivos.',
     'Encontro semanal, aprofundamento mensal e plano revisado a cada trimestre.',
     true, true, 60),

    (p_inquilino_id, 'programa-executivo', 'Programa executivo',
     'Programas', 'recorrente', '{n1}', true,
     'Ocupantes de cadeira executiva.',
     'Etapas encadeadas ao longo de seis meses, com encontros quinzenais e medição no início, no meio e no fim.',
     true, true, 70),

    (p_inquilino_id, 'consultoria-pontual', 'Consultoria pontual',
     'Serviços', 'pontual', '{n1}', false,
     'Empresa com um problema de escopo fechado.',
     'Escopo fechado, com entregável definido.',
     true, true, 110),

    (p_inquilino_id, 'consultoria-recorrente', 'Consultoria recorrente',
     'Serviços', 'recorrente', '{n1}', false,
     'Empresa que precisa de acompanhamento continuado.',
     'Mensalidade, com escopo revisto por ciclo.',
     true, true, 120),

    (p_inquilino_id, 'treinamento', 'Treinamento',
     'Serviços', 'pontual', '{n1}', false,
     'Times que precisam de capacitação em tema específico.',
     'Workshop ou palestra contratada. Aceita contratação pontual e contratação recorrente.',
     true, true, 130),

    (p_inquilino_id, 'executivo-alocado', 'Executivo alocado',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa que precisa de cadeira executiva sem contratar em tempo integral.',
     'Executivo alocado por tempo determinado, com agenda e entregáveis acordados.',
     true, true, 140),

    (p_inquilino_id, 'modelo-por-resultado', 'Modelo por resultado',
     'Serviços', 'recorrente', '{n1,n2}', false,
     'Empresa disposta a dividir o resultado gerado.',
     'Honorário menor mais participação nos resultados. Aceita contratação recorrente e pontual.',
     true, true, 150),

    (p_inquilino_id, 'modelo-por-equity', 'Participação societária',
     'Serviços', 'recorrente', '{n1,n3}', false,
     'Empresa em que a contratada entra como sócia.',
     'Honorário mais participação societária. Depende de validação jurídica e contábil antes da assinatura.',
     true, true, 160),

    (p_inquilino_id, 'frente-a-confirmar', 'Frente a confirmar',
     'Serviços', 'pontual', '{n1}', false,
     'A confirmar.',
     'Linha catalogada para não se perder no funil. Modalidade, estrutura e nível a confirmar.',
     true, true, 170)

    on conflict (inquilino_id, codigo) do nothing;

  end if;

  get diagnostics v_inseridas = row_count;
  return v_inseridas;
end;
$funcao$;

comment on function valor.semear_ofertas(uuid, text) is
  'Semeia o catálogo do portfólio de um inquilino. No perfil felix, os sete Programas de Valor, os sete serviços fora dos programas e o Sprint de Valor inativo. No perfil neutro, a mesma estrutura com oferta genérica. Idempotente. Nenhum preço entra.';

-- ------------------------------------------------------- a configuração da casa

-- Tudo que a casa decidiu e que precisa ser trocável em tela, e não em código.
--
-- Os prazos de alerta e o limite de concentração do pipeline não nascem aqui de
-- propósito: eles já moram nas chaves `alerta.*` e `higiene.*` que a migração
-- 0012 semeia, e duas linhas para o mesmo número seriam duas verdades que
-- discordam no primeiro dia de uso. A semente do inquilino garante que elas
-- existam chamando valor.semear_regras_alerta, e o teste confere uma a uma.
create or replace function valor.semear_configuracoes(p_inquilino_id uuid, p_perfil text)
returns integer language plpgsql as $funcao$
declare
  v_linhas integer := 0;
  v_felix  boolean := (p_perfil = 'felix');
begin

  -- ----------------------------------------------------------------- comissão
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.vendedor_interno_percentual', to_jsonb(10),
    'Percentual de comissão do Gerente de Contas, sobre a base líquida', 'comissao', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.parceiro_percentual', to_jsonb(10),
    'Percentual de comissão do parceiro que indica, sobre a base líquida', 'comissao', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.imposto_percentual', to_jsonb(15),
    'Imposto médio descontado do bruto antes da base de comissão', 'comissao', 'financeiro');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.momento_apuracao', to_jsonb('recebimento'::text),
    'Quando a comissão é apurada, no recebimento da parcela', 'comissao', 'financeiro');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'comissao.duracao', to_jsonb('vida_do_contrato'::text),
    'Por quanto tempo a comissão é devida, pela vida do contrato e suas renovações', 'comissao', 'admin_master');

  -- ----------------------------------------------------------------- parceria
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'parceria.protecao_indicacao_dias', to_jsonb(90),
    'Dias de proteção da indicação aceita do parceiro', 'parceria', 'admin_master');

  -- --------------------------------------------------------------------- meta
  -- Nascem vazias de propósito. Sem meta, o painel mostra cobertura de pipeline
  -- como indisponível, e não um número errado. Quem lê estas chaves não usa
  -- valor.configuracao_num com padrão, porque padrão aqui inventaria meta.
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.anual_casa', 'null'::jsonb,
    'Meta anual da casa', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.trimestral_casa', 'null'::jsonb,
    'Meta trimestral da casa', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.anual_por_pessoa', '{}'::jsonb,
    'Meta anual por pessoa, com o identificador do usuário na chave', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.trimestral_por_pessoa', '{}'::jsonb,
    'Meta trimestral por pessoa, com o identificador do usuário na chave', 'meta', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'meta.cobertura_indisponivel_sem_meta', 'true'::jsonb,
    'Mostrar a cobertura de pipeline como indisponível enquanto não houver meta', 'meta', 'lider');

  -- ----------------------------------------------------------------- conselho
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.reunioes_por_ano', to_jsonb(48),
    'Reuniões de conselho previstas no calendário do ano', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.recesso_inicio', to_jsonb('12-15'::text),
    'Início do recesso do calendário de turma, em dia e mês', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.recesso_fim', to_jsonb('01-15'::text),
    'Fim do recesso do calendário de turma, em dia e mês', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.nps_periodicidade_meses', to_jsonb(3),
    'Periodicidade da pesquisa de NPS, em meses', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.nota_conselheiro_periodicidade_meses', to_jsonb(6),
    'Periodicidade da nota do conselheiro respondida pelos sócios do cliente, em meses', 'conselho', 'lider');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'conselho.historico_periodicidade_meses', to_jsonb(3),
    case when v_felix
         then 'Periodicidade obrigatória do registro de Histórico de Valor, em meses'
         else 'Periodicidade obrigatória do registro de histórico de entrega, em meses'
    end, 'conselho', 'lider');

  -- -------------------------------------------------------------- identidade
  -- A marca vive em dado, não em código. Levar a plataforma para outro cliente é
  -- trocar estas duas chaves, e não recompilar a interface.
  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'identidade.cores',
    case when v_felix then jsonb_build_object(
        'marca',            '#5E1E3A',
        'marca_profunda',   '#490B2C',
        'realce',           '#EFB810',
        'realce_claro',     '#F9DB5C',
        'realce_legivel',   '#C2900A',
        'tinta',            '#1D1D1B',
        'cinza',            '#707070',
        'alarme_verde',     '#2E7D4F',
        'alarme_amarelo',   '#C58A00',
        'alarme_vermelho',  '#B3261E')
      else jsonb_build_object(
        'marca',            '#2B3A55',
        'marca_profunda',   '#1B2436',
        'realce',           '#4A6FA5',
        'realce_claro',     '#8FB0D9',
        'realce_legivel',   '#2F5C99',
        'tinta',            '#1A1A1A',
        'cinza',            '#6B6B6B',
        'alarme_verde',     '#1E7A46',
        'alarme_amarelo',   '#B07D00',
        'alarme_vermelho',  '#A32018')
    end,
    'Cores da marca', 'identidade', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'identidade.fontes',
    case when v_felix
         then jsonb_build_object('titulo', 'Oswald', 'texto', 'Montserrat', 'numero', 'Oswald')
         else jsonb_build_object('titulo', 'Inter',  'texto', 'Inter',      'numero', 'Inter')
    end,
    'Fontes do título e do texto', 'identidade', 'admin_master');

  v_linhas := v_linhas + valor.semear_configuracao(p_inquilino_id,
    'identidade.texto_justificado_em_tela', 'false'::jsonb,
    'Texto justificado somente em PDF, nunca na tela', 'identidade', 'admin_master');

  return v_linhas;
end;
$funcao$;

comment on function valor.semear_configuracoes(uuid, text) is
  'Semeia a configuração de um inquilino: comissão, parceria, meta, conselho e identidade. Os prazos de alerta e o limite de concentração do pipeline vêm das chaves alerta ponto e higiene ponto, semeadas pela migração 0012. Idempotente.';

-- ----------------------------------------------- o percentual que a conta usa

-- A conta da comissão lê valor.percentuais_padrao, e levanta exceção quando não
-- encontra linha vigente de escopo inquilino. Um inquilino recém-nascido sem
-- esta linha travaria na primeira parcela recebida, então ela nasce junto.
-- O número é o mesmo das chaves do grupo comissao: 15 de imposto, 10 e 10 de
-- comissão. A tela troca os dois lugares na mesma ação.
create or replace function valor.semear_percentuais(p_inquilino_id uuid)
returns integer language plpgsql as $funcao$
declare
  v_inseridas integer;
begin
  insert into valor.percentuais_padrao (
    inquilino_id, escopo, rotulo, imposto_percentual,
    comissao_vendedor_percentual, comissao_parceiro_percentual, vigencia_inicio
  )
  select p_inquilino_id, 'inquilino', 'Padrão do inquilino',
         15.0000, 10.0000, 10.0000, current_date
  where not exists (
    select 1 from valor.percentuais_padrao pp
     where pp.inquilino_id = p_inquilino_id
       and pp.escopo = 'inquilino'
       and pp.arquivado_em is null
  );

  get diagnostics v_inseridas = row_count;
  return v_inseridas;
end;
$funcao$;

comment on function valor.semear_percentuais(uuid) is
  'Abre a linha de percentual de escopo inquilino, sem a qual a apuração de comissão levanta exceção na primeira parcela. Idempotente: só nasce se ainda não houver percentual vigente do inquilino.';

-- --------------------------------------------- a paleta neutra do white label

-- A semente de GTD da migração 0011 pinta a coluna do quadro com a paleta da
-- casa, escrita no código. Num inquilino neutro isso seria identidade vazando
-- para fora, então a semente repinta com a paleta neutra logo em seguida.
-- O pedido de fundo, que a coluna leia a cor de identidade.cores em vez de
-- trazer a cor escrita, está no relatório do Curador de Catálogo.
create or replace function valor.neutralizar_identidade(p_inquilino_id uuid)
returns integer language plpgsql as $funcao$
declare
  v_pintadas integer;
begin
  update valor.colunas_kanban k
     set cor = n.cor
    from (values
      ('entrada',      '#6B6B6B'),
      ('proxima_acao', '#2B3A55'),
      ('agendada',     '#2F5C99'),
      ('aguardando',   '#B07D00'),
      ('algum_dia',    '#1A1A1A'),
      ('concluida',    '#1E7A46')
    ) as n(estado, cor)
   where k.inquilino_id = p_inquilino_id
     and k.estado_gtd::text = n.estado
     and k.cor is distinct from n.cor;

  get diagnostics v_pintadas = row_count;
  return v_pintadas;
end;
$funcao$;

comment on function valor.neutralizar_identidade(uuid) is
  'Troca a cor de código de qualquer semente pela paleta neutra do inquilino white label. Idempotente: na segunda passada não há linha para trocar.';

-- --------------------------------------------------------- a semente completa

create or replace function valor.semear_inquilino(
  p_inquilino_id uuid,
  p_perfil       text default 'felix'
) returns integer language plpgsql as $funcao$
declare
  v_linhas integer := 0;
begin
  if p_perfil is null or p_perfil not in ('felix', 'neutro') then
    raise exception 'Perfil de semente desconhecido: %. Os perfis são felix e neutro.', coalesce(p_perfil, 'nulo');
  end if;

  if not exists (select 1 from valor.inquilinos i where i.id = p_inquilino_id) then
    raise exception 'Não existe inquilino %. Crie o inquilino antes de semear.', p_inquilino_id;
  end if;

  v_linhas := v_linhas + valor.semear_ofertas(p_inquilino_id, p_perfil);
  v_linhas := v_linhas + valor.semear_configuracoes(p_inquilino_id, p_perfil);
  v_linhas := v_linhas + valor.semear_percentuais(p_inquilino_id);

  -- As outras sementes já moram nas migrações dos seus donos. A porta de entrada
  -- é uma só: quem cria inquilino chama esta função e recebe tudo, sem precisar
  -- lembrar de cinco chamadas na ordem certa. Todas são idempotentes.
  perform valor.semear_modelos_ata(p_inquilino_id);   -- 0009 · ata de sete seções e extensão
  perform valor.semear_banco_pautas(p_inquilino_id);  -- 0009 · temas de governança e famílias de gestão
  perform valor.semear_gtd(p_inquilino_id);           -- 0011 · contexto e coluna do quadro
  perform valor.semear_regras_alerta(p_inquilino_id); -- 0012 · regras, automações e prazos

  if p_perfil = 'neutro' then
    perform valor.neutralizar_identidade(p_inquilino_id);
  end if;

  return v_linhas;
end;
$funcao$;

comment on function valor.semear_inquilino(uuid, text) is
  'Semeia um inquilino inteiro: catálogo do portfólio, configuração, percentual padrão, modelo de ata, banco de pautas, vocabulário de atividades e regras de alerta. O perfil felix traz o catálogo da casa. O perfil neutro traz a mesma estrutura sem conteúdo da casa, que é o que o white label recebe. Idempotente: devolve quantas linhas de catálogo e de configuração nasceram nesta chamada, e zero na segunda.';

-- ------------------------------------------------------- o inquilino que nasce

create or replace function valor.criar_inquilino(
  nome        text,
  apelido     text,
  email_admin text,
  perfil      text default 'felix'
) returns uuid language plpgsql as $funcao$
declare
  v_inquilino uuid;
  v_email     text := lower(btrim(coalesce(email_admin, '')));
begin
  if coalesce(btrim(coalesce(nome, '')), '') = '' then
    raise exception 'O inquilino precisa de nome.';
  end if;
  if coalesce(btrim(coalesce(apelido, '')), '') = '' then
    raise exception 'O inquilino precisa de apelido, que é o identificador curto usado na URL e no convite.';
  end if;
  if position('@' in v_email) < 2 or position('.' in split_part(v_email, '@', 2)) < 2 then
    raise exception 'O endereço do administrador master veio inválido. Nenhum endereço fica escrito na migração: ele chega sempre por parâmetro.';
  end if;

  select i.id into v_inquilino
    from valor.inquilinos i
   where i.apelido = criar_inquilino.apelido;

  if v_inquilino is null then
    -- O conflito é declarado pelo nome da restrição, e não pelo nome da coluna,
    -- porque `apelido` também é o nome de um parâmetro desta função e o alvo de
    -- conflito aceita variável de plpgsql, o que deixaria a referência ambígua.
    insert into valor.inquilinos (nome, apelido)
    values (btrim(criar_inquilino.nome), btrim(criar_inquilino.apelido))
    on conflict on constraint inquilinos_apelido_key do nothing
    returning id into v_inquilino;
  end if;

  if v_inquilino is null then
    select i.id into v_inquilino
      from valor.inquilinos i
     where i.apelido = criar_inquilino.apelido;
  end if;

  perform valor.semear_inquilino(v_inquilino, criar_inquilino.perfil);

  -- Um único administrador master, e só ele. Todo mundo mais entra pela tela de
  -- gestão de usuários, com convite por e-mail e perfil escolhido na hora.
  if not exists (
    select 1 from valor.usuarios u
     where u.inquilino_id = v_inquilino
       and u.perfil = 'admin_master'
       and u.arquivado_em is null
  ) then
    insert into valor.usuarios (inquilino_id, email, nome, perfil, mfa_obrigatorio)
    values (v_inquilino, v_email, 'Administrador master', 'admin_master', true)
    on conflict (inquilino_id, email) do nothing;
  end if;

  return v_inquilino;
end;
$funcao$;

comment on function valor.criar_inquilino(text, text, text, text) is
$doc$Cria o inquilino, semeia o catálogo e a configuração pelo perfil pedido, e cadastra um único usuário administrador master, cujo endereço chega por parâmetro. Nenhum endereço de e-mail fica escrito na migração. Idempotente: rodar de novo com o mesmo apelido devolve o mesmo inquilino e não cria um segundo administrador.

A conta de emergência não nasce aqui. Ela é criada logo depois, pela tela de gestão de usuários, com múltiplo fator obrigatório e com os códigos de recuperação impressos e guardados fisicamente, fora de qualquer sistema. O endereço dessa conta é decidido na hora de publicar e nunca entra no repositório.

A função roda com os direitos de quem chama, e não com os do dono, de propósito. Abrir inquilino não é operação de usuário de aplicação: valor.inquilinos tem segurança de linha e nenhuma política de escrita, então quem chama por uma sessão comum é barrado pelo banco. Quem abre inquilino é o dono das tabelas, na carga inicial, ou a chave de serviço, na publicação.$doc$;

-- ------------------------------------------------- a prova do white label limpo

-- A identidade visual da casa, dez cores fechadas no contrato técnico. Cor de
-- marca dentro de um inquilino white label vaza tanto quanto nome de programa,
-- e vaza mais calado, porque ninguém lê hexadecimal numa revisão de texto.
create or replace function valor.cores_da_casa() returns text[]
language sql immutable as $funcao$
  select array[
    '#5E1E3A',  -- vinho
    '#490B2C',  -- vinho profundo
    '#EFB810',  -- dourado
    '#F9DB5C',  -- dourado claro
    '#C2900A',  -- dourado sobre branco
    '#1D1D1B',  -- tinta
    '#707070',  -- cinza
    '#2E7D4F',  -- alarme verde
    '#C58A00',  -- alarme amarelo
    '#B3261E'   -- alarme vermelho
  ];
$funcao$;

comment on function valor.cores_da_casa() is
  'As dez cores da identidade visual da casa, do contrato técnico. Nenhuma delas pode aparecer num inquilino white label.';

-- As palavras da casa que jamais podem aparecer num inquilino white label.
-- Casadas sem distinguir maiúscula de minúscula.
create or replace function valor.palavras_da_casa() returns text[]
language sql immutable as $funcao$
  select array[
    'felix',
    'conselho de valor',
    'negócios de valor',
    'negocios de valor',
    'mesa do ceo',
    'sprint de valor',
    'liderança de valor',
    'lideranca de valor',
    'gestão de valor',
    'gestao de valor',
    'mentoria de valor',
    'executivo de valor',
    'programas de valor',
    'histórico de valor',
    'historico de valor',
    'plataforma de valor',
    'oswald',
    'montserrat'
  ] || valor.cores_da_casa();
$funcao$;

comment on function valor.palavras_da_casa() is
  'As expressões da casa que reprovam um inquilino white label, junto com as cores da casa. Casadas sem distinguir maiúscula de minúscula.';

-- A marca da casa como palavra inteira e com a caixa que a casa usa. Distingue
-- maiúscula de minúscula de propósito: `proposta de valor` é vocabulário comum
-- de negócio e passa, `Conselho de Valor` é marca e reprova.
create or replace function valor.marcas_da_casa() returns text[]
language sql immutable as $funcao$
  select array['\mValor\M', '\mFelix\M'];
$funcao$;

comment on function valor.marcas_da_casa() is
  'A marca da casa como palavra inteira, casada respeitando a caixa. Serve para separar a palavra comum valor da marca Valor.';

-- Varre toda linha de todo texto de um inquilino procurando palavra da casa.
-- É o que prova que o white label é entregável, e não promessa. Devolve uma
-- linha por ocorrência, com tabela, coluna, chave da linha e o trecho achado.
-- Rodada contra o inquilino da casa, acha muita coisa. Rodada contra o inquilino
-- neutro, precisa devolver vazio.
create or replace function valor.vazamento_de_marca(
  p_inquilino_id uuid,
  p_sem_caixa    text[] default null,
  p_com_caixa    text[] default null
) returns table (
  tabela  text,
  coluna  text,
  linha   uuid,
  achado  text,
  trecho  text
) language plpgsql stable as $funcao$
declare
  r      record;
  l_sem  text[] := coalesce(p_sem_caixa, valor.palavras_da_casa());
  l_com  text[] := coalesce(p_com_caixa, valor.marcas_da_casa());
  -- Lista vazia vira nulo, e a passada correspondente nem roda. Sem isso a
  -- alternância ficaria `()`, que casa com a linha inteira e faria a varredura
  -- reprovar tudo, ou pior, aprovar tudo quando invertida.
  v_sem  text := case when coalesce(array_length(l_sem, 1), 0) = 0
                      then null else '(' || array_to_string(l_sem, '|') || ')' end;
  v_com  text := case when coalesce(array_length(l_com, 1), 0) = 0
                      then null else '(' || array_to_string(l_com, '|') || ')' end;
begin
  for r in
    select c.relname::text as tabela,
           a.attname::text as coluna,
           exists (select 1 from pg_attribute b
                    where b.attrelid = c.oid and b.attname = 'id'
                      and b.attnum > 0 and not b.attisdropped) as tem_id
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
      join pg_type t on t.oid = a.atttypid
     where n.nspname = 'valor'
       and c.relkind = 'r'
       and t.typname in ('text', 'varchar', 'bpchar', 'json', 'jsonb', '_text', '_varchar')
       and exists (select 1 from pg_attribute b
                    where b.attrelid = c.oid and b.attname = 'inquilino_id'
                      and b.attnum > 0 and not b.attisdropped)
     order by 1, 2
  loop
    -- Passada sem caixa: `Felix`, `FELIX` e `felix` reprovam do mesmo jeito.
    if v_sem is not null then
      return query execute format(
        'select %L::text, %L::text, %s, (regexp_match(x.%I::text, %L, ''i''))[1], left(x.%I::text, 160)
           from valor.%I x
          where x.inquilino_id = %L::uuid
            and x.%I::text ~* %L',
        r.tabela, r.coluna,
        case when r.tem_id then 'x.id' else 'null::uuid' end,
        r.coluna, v_sem, r.coluna, r.tabela, p_inquilino_id, r.coluna, v_sem);
    end if;

    -- Passada com caixa: separa a marca `Valor` da palavra comum `valor`.
    if v_com is not null then
      return query execute format(
        'select %L::text, %L::text, %s, (regexp_match(x.%I::text, %L))[1], left(x.%I::text, 160)
           from valor.%I x
          where x.inquilino_id = %L::uuid
            and x.%I::text ~ %L',
        r.tabela, r.coluna,
        case when r.tem_id then 'x.id' else 'null::uuid' end,
        r.coluna, v_com, r.coluna, r.tabela, p_inquilino_id, r.coluna, v_com);
    end if;
  end loop;
end;
$funcao$;

comment on function valor.vazamento_de_marca(uuid, text[], text[]) is
  'Varre toda coluna de texto, de todo vetor de texto e de todo jsonb de toda tabela de um inquilino atrás das palavras e das cores da casa. Devolve uma linha por achado, com a tabela, a coluna, a chave da linha e a primeira ocorrência daquela passada. Zero linha no inquilino neutro é a prova de que o white label sai limpo. Rode com o dono das tabelas, para que a segurança de linha não esconda o que precisa aparecer.';
