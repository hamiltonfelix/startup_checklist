/**
 * Dados da Configuração: usuários, convites, ofertas, regras e prazos.
 *
 * Mesma regra de `src/dados/consultas.ts`: quando o banco está ligado, lê do
 * banco. Quando não está, cai nos exemplos deste arquivo e diz isso na tela.
 *
 * Toda pessoa aqui é fictícia, e nenhum endereço de correio deste arquivo
 * existe: o domínio `exemplo.invalido` não é, e nunca será, um domínio de
 * verdade. Nenhum endereço de pessoa real entra no repositório, conforme a
 * seção 11 do contrato técnico.
 *
 * Os prazos e as metas não são constante de código. Eles são lidos da tabela
 * `valor.configuracoes`, chave por chave, e a lista abaixo só descreve o que
 * cada chave significa. Trocar o número é trocar a linha do banco.
 */

import { useQuery, type UseQueryResult } from '@tanstack/react-query'
import { obterCliente, temBanco } from '@/dados/cliente'
import type {
  ConviteNaTela,
  MetaConfigurada,
  OfertaNaTela,
  PrazoConfiguravel,
  RegraNaTela,
  UsuarioNaTela,
} from '@/tipos/configuracao'

// ------------------------------------------------------------- datas úteis

const HOJE = new Date()

function emDias(dias: number): string {
  const d = new Date(HOJE)
  d.setDate(d.getDate() + dias)
  return d.toISOString()
}

// ------------------------------------------------------ usuários de exemplo

export const USUARIOS_EXEMPLO: UsuarioNaTela[] = [
  {
    id: 'uex-01',
    nome: 'Administradora de Exemplo',
    email: 'administradora@exemplo.invalido',
    perfil: 'admin_master',
    ativo: true,
    mfa_obrigatorio: true,
    ultimo_acesso: emDias(-0.2),
    auth_id: 'auth-uex-01',
    contas_atribuidas: 0,
    contas: [],
    parceiro_nome: null,
    criado_em: emDias(-730),
  },
  {
    id: 'uex-99',
    nome: 'Conta de emergência da casa',
    email: 'emergencia@exemplo.invalido',
    perfil: 'emergencia',
    ativo: true,
    mfa_obrigatorio: true,
    ultimo_acesso: null,
    auth_id: 'auth-uex-99',
    contas_atribuidas: 0,
    contas: [],
    parceiro_nome: null,
    criado_em: emDias(-730),
  },
  {
    id: 'uex-02',
    nome: 'Gerente de Contas de Exemplo',
    email: 'gerente.contas@exemplo.invalido',
    perfil: 'gerente_contas',
    ativo: true,
    mfa_obrigatorio: true,
    ultimo_acesso: emDias(-1),
    auth_id: 'auth-uex-02',
    contas_atribuidas: 6,
    contas: [
      'Metalúrgica Aurora Fictícia',
      'Transportes Serra Modelo',
      'Clínica Bem Viver Exemplo',
      'Agro Vale Fictício',
      'Construtora Horizonte Modelo',
      'Rede Sabor Fictícia',
    ],
    parceiro_nome: null,
    criado_em: emDias(-400),
  },
  {
    id: 'uex-03',
    nome: 'Liderança de Exemplo',
    email: 'lideranca@exemplo.invalido',
    perfil: 'lider',
    ativo: true,
    mfa_obrigatorio: true,
    ultimo_acesso: emDias(-3),
    auth_id: 'auth-uex-03',
    contas_atribuidas: 0,
    contas: [],
    parceiro_nome: null,
    criado_em: emDias(-380),
  },
  {
    id: 'uex-04',
    nome: 'Conselheiro Fictício',
    email: 'conselheiro@exemplo.invalido',
    perfil: 'conselheiro',
    ativo: true,
    mfa_obrigatorio: false,
    ultimo_acesso: emDias(-9),
    auth_id: 'auth-uex-04',
    contas_atribuidas: 2,
    contas: ['Metalúrgica Aurora Fictícia', 'Clínica Bem Viver Exemplo'],
    parceiro_nome: null,
    criado_em: emDias(-300),
  },
  {
    id: 'uex-05',
    nome: 'Assessora Fictícia',
    email: 'assessoria@exemplo.invalido',
    perfil: 'assessor',
    ativo: true,
    mfa_obrigatorio: false,
    ultimo_acesso: emDias(-2),
    auth_id: 'auth-uex-05',
    contas_atribuidas: 2,
    contas: ['Metalúrgica Aurora Fictícia', 'Clínica Bem Viver Exemplo'],
    parceiro_nome: null,
    criado_em: emDias(-260),
  },
  {
    id: 'uex-06',
    nome: 'Financeiro de Exemplo',
    email: 'financeiro@exemplo.invalido',
    perfil: 'financeiro',
    ativo: true,
    mfa_obrigatorio: true,
    ultimo_acesso: emDias(-5),
    auth_id: 'auth-uex-06',
    contas_atribuidas: 0,
    contas: [],
    parceiro_nome: null,
    criado_em: emDias(-250),
  },
  {
    id: 'uex-07',
    nome: 'Comercial de Exemplo',
    email: 'comercial@exemplo.invalido',
    perfil: 'comercial',
    ativo: false,
    mfa_obrigatorio: false,
    ultimo_acesso: emDias(-120),
    auth_id: 'auth-uex-07',
    contas_atribuidas: 0,
    contas: [],
    parceiro_nome: null,
    criado_em: emDias(-220),
  },
  {
    id: 'uex-20',
    nome: 'Parceiro de Exemplo',
    email: 'parceiro.exemplo@aurora.exemplo.invalido',
    perfil: 'parceiro',
    ativo: true,
    mfa_obrigatorio: false,
    ultimo_acesso: emDias(-2),
    auth_id: 'auth-uex-20',
    contas_atribuidas: 0,
    contas: [],
    parceiro_nome: 'Consultoria Aurora Fictícia',
    criado_em: emDias(-410),
  },
  {
    id: 'uex-30',
    nome: 'Participante Fictício da turma da manhã',
    email: 'participante@exemplo.invalido',
    perfil: 'participante',
    ativo: true,
    mfa_obrigatorio: false,
    ultimo_acesso: emDias(-16),
    auth_id: 'auth-uex-30',
    contas_atribuidas: 1,
    contas: ['Têxtil Canção Fictícia'],
    parceiro_nome: null,
    criado_em: emDias(-120),
  },
  {
    id: 'uex-08',
    nome: 'Pessoa Convidada Fictícia',
    email: 'convidada@exemplo.invalido',
    perfil: 'gerente_contas',
    ativo: true,
    mfa_obrigatorio: true,
    // Sem `auth_id`: o convite foi enviado e ainda não virou acesso.
    ultimo_acesso: null,
    auth_id: null,
    contas_atribuidas: 0,
    contas: [],
    parceiro_nome: null,
    criado_em: emDias(-4),
  },
]

export const CONVITES_EXEMPLO: ConviteNaTela[] = [
  {
    id: 'cvx-01',
    nome: 'Pessoa Convidada Fictícia',
    email: 'convidada@exemplo.invalido',
    perfil: 'gerente_contas',
    expira_em: emDias(3),
    aceito_em: null,
    reenviado_em: null,
    reenvios: 0,
    criado_em: emDias(-4),
  },
  {
    id: 'cvx-02',
    nome: 'Segunda Pessoa Convidada',
    email: 'segunda.convidada@exemplo.invalido',
    perfil: 'assessor',
    expira_em: emDias(-2),
    aceito_em: null,
    reenviado_em: emDias(-6),
    reenvios: 1,
    criado_em: emDias(-12),
  },
  {
    id: 'cvx-03',
    nome: 'Contato Meridiano Fictício',
    email: 'contato@meridiano.exemplo.invalido',
    perfil: 'parceiro',
    expira_em: emDias(5),
    aceito_em: null,
    reenviado_em: null,
    reenvios: 0,
    criado_em: emDias(-2),
  },
  {
    id: 'cvx-04',
    nome: 'Financeiro de Exemplo',
    email: 'financeiro@exemplo.invalido',
    perfil: 'financeiro',
    expira_em: emDias(-240),
    aceito_em: emDias(-248),
    reenviado_em: null,
    reenvios: 0,
    criado_em: emDias(-250),
  },
]

// ------------------------------------------------------- ofertas de exemplo

/** Espelho do catálogo semeado na migração 0016, com a contagem de histórico. */
export const OFERTAS_EXEMPLO: OfertaNaTela[] = [
  {
    id: 'ofx-01',
    codigo: 'conselho-dedicado',
    nome: 'Conselho de Valor dedicado',
    familia: 'Programas de Valor',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1', 'n2', 'n3'],
    gera_turma: true,
    publico_alvo: 'Donos e sócios de uma empresa.',
    estrutura:
      'Encontros semanais de conselho, encontro semanal de gestão, pauta prioritária mensal e um presencial por mês. Recorrente anual, turma de um cliente.',
    ativa: true,
    sugerida: true,
    ordem: 10,
    negocios_no_historico: 4,
  },
  {
    id: 'ofx-02',
    codigo: 'conselho-compartilhado',
    nome: 'Conselho de Valor compartilhado',
    familia: 'Programas de Valor',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1'],
    gera_turma: true,
    publico_alvo: 'Até 8 empresários de mercados diferentes.',
    estrutura:
      '48 reuniões no ano, hotseat por membro, resumo semanal e um presencial por mês. Recorrente anual, turma multiempresa.',
    ativa: true,
    sugerida: true,
    ordem: 20,
    negocios_no_historico: 2,
  },
  {
    id: 'ofx-03',
    codigo: 'negocios-de-valor',
    nome: 'Negócios de Valor',
    familia: 'Programas de Valor',
    modalidade: 'pontual_com_sustentacao',
    niveis_aceitos: ['n1'],
    gera_turma: true,
    publico_alvo: 'Times comerciais B2B e B2G.',
    estrutura:
      '12 encontros de 2h30 mais 8 semanas de sustentação. Variante de 10 encontros. Imersão de 3 dias. De 8 a 16 cadeiras. A unidade de venda é o time, e a turma pode ser dedicada ou compartilhada.',
    ativa: true,
    sugerida: true,
    ordem: 30,
    negocios_no_historico: 5,
  },
  {
    id: 'ofx-04',
    codigo: 'lideranca-de-valor',
    nome: 'Liderança de Valor',
    familia: 'Programas de Valor',
    modalidade: 'pontual',
    niveis_aceitos: ['n1'],
    gera_turma: true,
    publico_alvo: 'Sócios, C-level e líderes.',
    estrutura: 'Workshop de 2 dias, 8 módulos e 1 plano de desenvolvimento por participante.',
    ativa: true,
    sugerida: true,
    ordem: 40,
    negocios_no_historico: 3,
  },
  {
    id: 'ofx-05',
    codigo: 'gestao-de-valor',
    nome: 'Gestão de Valor',
    familia: 'Programas de Valor',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1'],
    gera_turma: true,
    publico_alvo: 'Sócios e principais executivos.',
    estrutura: '6 módulos, 48 temas e encontros semanais. Recorrente anual.',
    ativa: true,
    sugerida: true,
    ordem: 50,
    negocios_no_historico: 2,
  },
  {
    id: 'ofx-06',
    codigo: 'mentoria-de-valor',
    nome: 'Mentoria de Valor',
    familia: 'Programas de Valor',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1'],
    gera_turma: true,
    publico_alvo: 'Donos e CEOs.',
    estrutura:
      'Encontro semanal, deep-dive mensal e plano em 4 estações. Recorrente anual e individual, turma de um.',
    ativa: true,
    sugerida: true,
    ordem: 60,
    negocios_no_historico: 1,
  },
  {
    id: 'ofx-07',
    codigo: 'executivo-de-valor',
    nome: 'Executivo de Valor',
    familia: 'Programas de Valor',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1'],
    gera_turma: true,
    publico_alvo: 'Ocupantes de cadeira do C-level.',
    estrutura:
      'Mesa do CEO: 12 etapas em 6 meses, encontros quinzenais de 2h e índice próprio medido em T0, T90 e T180.',
    ativa: true,
    sugerida: true,
    ordem: 70,
    negocios_no_historico: 1,
  },
  {
    id: 'ofx-08',
    codigo: 'sprint-de-valor',
    nome: 'Sprint de Valor',
    familia: 'Programas de Valor',
    modalidade: 'pontual',
    niveis_aceitos: ['n1'],
    gera_turma: true,
    publico_alvo: 'Times que precisam de um ciclo curto de execução.',
    estrutura:
      'Fora do site por decisão de julho de 2026. Continua no catálogo para o histórico, inativo e não sugerido. Estrutura a confirmar antes de voltar a ser oferecido.',
    ativa: false,
    sugerida: false,
    ordem: 80,
    negocios_no_historico: 3,
  },
  {
    id: 'ofx-09',
    codigo: 'consultoria-pontual',
    nome: 'Consultoria pontual',
    familia: 'Serviços',
    modalidade: 'pontual',
    niveis_aceitos: ['n1'],
    gera_turma: false,
    publico_alvo: 'Empresa com um problema de escopo fechado.',
    estrutura: 'Escopo fechado, com entregável definido.',
    ativa: true,
    sugerida: true,
    ordem: 110,
    negocios_no_historico: 6,
  },
  {
    id: 'ofx-10',
    codigo: 'consultoria-recorrente',
    nome: 'Consultoria recorrente',
    familia: 'Serviços',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1'],
    gera_turma: false,
    publico_alvo: 'Empresa que precisa de acompanhamento continuado.',
    estrutura: 'Mensalidade, com escopo revisto por ciclo.',
    ativa: true,
    sugerida: true,
    ordem: 120,
    negocios_no_historico: 2,
  },
  {
    id: 'ofx-11',
    codigo: 'treinamento',
    nome: 'Treinamento',
    familia: 'Serviços',
    modalidade: 'pontual',
    niveis_aceitos: ['n1'],
    gera_turma: false,
    publico_alvo: 'Times que precisam de capacitação em tema específico.',
    estrutura:
      'Workshop ou palestra contratada. Aceita contratação pontual e contratação recorrente.',
    ativa: true,
    sugerida: true,
    ordem: 130,
    negocios_no_historico: 4,
  },
  {
    id: 'ofx-12',
    codigo: 'c-level-as-a-service',
    nome: 'C-level as a service',
    familia: 'Serviços',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1', 'n2'],
    gera_turma: false,
    publico_alvo: 'Empresa que precisa de cadeira executiva sem contratar em tempo integral.',
    estrutura: 'Executivo alocado por tempo determinado, com agenda e entregáveis acordados.',
    ativa: true,
    sugerida: true,
    ordem: 140,
    negocios_no_historico: 1,
  },
  {
    id: 'ofx-13',
    codigo: 'modelo-por-resultado',
    nome: 'Modelo por resultado',
    familia: 'Serviços',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1', 'n2'],
    gera_turma: false,
    publico_alvo: 'Empresa disposta a dividir o resultado gerado.',
    estrutura: 'Honorário menor mais participação nos resultados. Aceita recorrente e pontual.',
    ativa: true,
    sugerida: true,
    ordem: 150,
    negocios_no_historico: 0,
  },
  {
    id: 'ofx-14',
    codigo: 'modelo-por-equity',
    nome: 'Equity',
    familia: 'Serviços',
    modalidade: 'recorrente',
    niveis_aceitos: ['n1', 'n3'],
    gera_turma: false,
    publico_alvo: 'Empresa em que a casa entra como sócia.',
    estrutura:
      'Honorário mais participação societária. Depende de validação de advogado e de contador antes da assinatura.',
    ativa: true,
    sugerida: true,
    ordem: 160,
    negocios_no_historico: 0,
  },
  {
    id: 'ofx-15',
    codigo: 'next-c-level',
    nome: 'NEXT C-LEVEL',
    familia: 'Serviços',
    modalidade: 'pontual',
    niveis_aceitos: ['n1'],
    gera_turma: false,
    publico_alvo: 'A confirmar.',
    estrutura:
      'Frente própria, catalogada para não se perder no funil. Modalidade, estrutura e nível a confirmar.',
    ativa: true,
    sugerida: true,
    ordem: 170,
    negocios_no_historico: 0,
  },
]

// -------------------------------------------------------- regras de exemplo

/** Espelho das sete regras semeadas na migração 0012. */
export const REGRAS_EXEMPLO: RegraNaTela[] = [
  {
    id: 'rgx-01',
    codigo: 'lead_sem_dono',
    nome: 'Lead sem dono',
    descricao: 'Lead parado sem Gerente de Contas além do prazo configurado.',
    entidade_alvo: 'negocios',
    criticidade: 'amarelo',
    canal: 'painel',
    destinatario_perfil: 'comercial',
    destinatario_papel: null,
    ativa: true,
    configuravel: true,
    ordem: 10,
    mensagem: 'Lead sem dono há mais dias que o prazo da casa. Atribua um Gerente de Contas.',
    prazos_que_usa: ['alerta.lead_sem_dono_dias'],
    alertas_abertos: 2,
  },
  {
    id: 'rgx-02',
    codigo: 'negocio_parado',
    nome: 'Negócio parado',
    descricao:
      'Negócio sem interação acima do piso configurado, ou acima do fator sobre a mediana histórica da fase.',
    entidade_alvo: 'negocios',
    criticidade: 'amarelo',
    canal: 'painel',
    destinatario_perfil: null,
    destinatario_papel: 'gerente_contas',
    ativa: true,
    configuravel: true,
    ordem: 20,
    mensagem: 'Negócio sem interação registrada além do prazo. Marque o próximo passo com data.',
    prazos_que_usa: [
      'alerta.negocio_parado_dias_piso',
      'alerta.negocio_parado_fator_mediana',
      'alerta.negocio_parado_amostra_minima',
    ],
    alertas_abertos: 3,
  },
  {
    id: 'rgx-03',
    codigo: 'plano_trabalho_vencendo',
    nome: 'Plano de Trabalho vencendo',
    descricao:
      'Plano de Trabalho validado com o cliente chegando ao fim da validade. Amarelo no primeiro aviso, vermelho no último.',
    entidade_alvo: 'artefatos',
    criticidade: 'amarelo',
    canal: 'painel',
    destinatario_perfil: null,
    destinatario_papel: 'gerente_contas',
    ativa: true,
    configuravel: true,
    ordem: 30,
    mensagem: 'O Plano de Trabalho validado com o cliente está chegando ao fim da validade.',
    prazos_que_usa: [
      'alerta.plano_trabalho_aviso_amarelo_dias',
      'alerta.plano_trabalho_aviso_vermelho_dias',
    ],
    alertas_abertos: 1,
  },
  {
    id: 'rgx-04',
    codigo: 'contrato_vencendo',
    nome: 'Contrato vencendo',
    descricao:
      'Contrato chegando ao fim da vigência. Primeiro aviso em amarelo, último em vermelho. O negócio de renovação é aberto pela automação.',
    entidade_alvo: 'contratos',
    criticidade: 'amarelo',
    canal: 'painel',
    destinatario_perfil: 'lider',
    destinatario_papel: null,
    ativa: true,
    configuravel: true,
    ordem: 40,
    mensagem: 'Contrato chegando ao fim da vigência. Abra o negócio de renovação.',
    prazos_que_usa: [
      'alerta.contrato_renovacao_dias',
      'alerta.contrato_aviso_amarelo_dias',
      'alerta.contrato_aviso_vermelho_dias',
    ],
    alertas_abertos: 1,
  },
  {
    id: 'rgx-05',
    codigo: 'ata_nao_enviada',
    nome: 'Ata não enviada',
    descricao:
      'Reunião de conselho realizada e ata ainda não enviada além do prazo configurado. A ata restrita fica de fora, porque ela nunca é enviada.',
    entidade_alvo: 'atas',
    criticidade: 'vermelho',
    canal: 'painel',
    destinatario_perfil: 'assessor',
    destinatario_papel: null,
    ativa: true,
    configuravel: true,
    ordem: 50,
    mensagem: 'A ata do encontro ainda não saiu. Revise, aprove e envie.',
    prazos_que_usa: ['alerta.ata_nao_enviada_horas'],
    alertas_abertos: 0,
  },
  {
    id: 'rgx-06',
    codigo: 'higiene_quebrada',
    nome: 'Invariante de higiene quebrada',
    descricao:
      'Negócio ativo nas fases 1 a 4 que quebra pelo menos uma das quatro invariantes de higiene. Alarme imediato no painel.',
    entidade_alvo: 'negocios',
    criticidade: 'vermelho',
    canal: 'painel',
    destinatario_perfil: null,
    destinatario_papel: 'gerente_contas',
    ativa: true,
    // Estrutural: as quatro invariantes são lei do contrato, não preferência.
    configuravel: false,
    ordem: 60,
    mensagem: 'Este negócio saiu do pipeline auditado. Veja qual invariante está quebrada.',
    prazos_que_usa: ['higiene.dias_sem_interacao'],
    alertas_abertos: 4,
  },
  {
    id: 'rgx-07',
    codigo: 'concentracao_de_pipeline',
    nome: 'Concentração de pipeline',
    descricao: 'Os dois maiores negócios passam da fração configurada do pipeline declarado.',
    entidade_alvo: 'inquilinos',
    criticidade: 'amarelo',
    canal: 'painel',
    destinatario_perfil: 'lider',
    destinatario_papel: null,
    ativa: true,
    configuravel: true,
    ordem: 70,
    mensagem: 'O pipeline está concentrado em poucos negócios. Vale abrir a base.',
    prazos_que_usa: ['alerta.concentracao_limite'],
    alertas_abertos: 1,
  },
]

// --------------------------------------------- o catálogo de chaves de prazo

/**
 * O que cada chave de `valor.configuracoes` significa.
 *
 * Esta lista é descrição, não valor. O número vem do banco. Quando o banco não
 * está ligado, o padrão da semente entra como exemplo e a tela avisa.
 */
interface DescricaoDePrazo {
  chave: string
  rotulo: string
  grupo: string
  unidade: PrazoConfiguravel['unidade']
  explicacao: string
  regra: string | null
  editavel_por: PrazoConfiguravel['editavel_por']
  /** O padrão semeado pelas migrações 0012 e 0016. Serve só de exemplo. */
  padrao: number
}

export const CATALOGO_DE_PRAZOS: DescricaoDePrazo[] = [
  {
    chave: 'alerta.lead_sem_dono_dias',
    rotulo: 'Lead sem dono',
    grupo: 'alertas',
    unidade: 'dias',
    explicacao: 'Dias que um lead pode ficar sem Gerente de Contas antes de o alerta acender.',
    regra: 'lead_sem_dono',
    editavel_por: 'admin_master',
    padrao: 3,
  },
  {
    chave: 'alerta.negocio_parado_dias_piso',
    rotulo: 'Negócio parado, piso',
    grupo: 'alertas',
    unidade: 'dias',
    explicacao:
      'Piso de dias sem interação antes do alarme, enquanto não houver mediana histórica da fase.',
    regra: 'negocio_parado',
    editavel_por: 'admin_master',
    padrao: 30,
  },
  {
    chave: 'alerta.negocio_parado_fator_mediana',
    rotulo: 'Negócio parado, fator sobre a mediana',
    grupo: 'alertas',
    unidade: 'fator',
    explicacao:
      'Quantas vezes a mediana histórica da fase o negócio pode ficar parado antes do alarme.',
    regra: 'negocio_parado',
    editavel_por: 'admin_master',
    padrao: 2,
  },
  {
    chave: 'alerta.negocio_parado_amostra_minima',
    rotulo: 'Negócio parado, amostra mínima',
    grupo: 'alertas',
    unidade: 'quantidade',
    explicacao: 'Quantos negócios a fase precisa ter no histórico para a mediana valer.',
    regra: 'negocio_parado',
    editavel_por: 'admin_master',
    padrao: 5,
  },
  {
    chave: 'alerta.plano_trabalho_aviso_amarelo_dias',
    rotulo: 'Plano de Trabalho vencendo, primeiro aviso',
    grupo: 'alertas',
    unidade: 'dias',
    explicacao: 'Dias antes do fim da validade em que o primeiro aviso acende, em amarelo.',
    regra: 'plano_trabalho_vencendo',
    editavel_por: 'admin_master',
    padrao: 7,
  },
  {
    chave: 'alerta.plano_trabalho_aviso_vermelho_dias',
    rotulo: 'Plano de Trabalho vencendo, último aviso',
    grupo: 'alertas',
    unidade: 'dias',
    explicacao: 'Dias antes do fim da validade em que o último aviso acende, em vermelho.',
    regra: 'plano_trabalho_vencendo',
    editavel_por: 'admin_master',
    padrao: 1,
  },
  {
    chave: 'alerta.contrato_renovacao_dias',
    rotulo: 'Contrato vencendo, abertura da renovação',
    grupo: 'alertas',
    unidade: 'dias',
    explicacao: 'Antecedência com que o negócio de renovação nasce sozinho.',
    regra: 'contrato_vencendo',
    editavel_por: 'admin_master',
    padrao: 90,
  },
  {
    chave: 'alerta.contrato_aviso_amarelo_dias',
    rotulo: 'Contrato vencendo, primeiro aviso',
    grupo: 'alertas',
    unidade: 'dias',
    explicacao: 'Dias antes do fim da vigência em que o primeiro aviso acende, em amarelo.',
    regra: 'contrato_vencendo',
    editavel_por: 'admin_master',
    padrao: 60,
  },
  {
    chave: 'alerta.contrato_aviso_vermelho_dias',
    rotulo: 'Contrato vencendo, último aviso',
    grupo: 'alertas',
    unidade: 'dias',
    explicacao: 'Dias antes do fim da vigência em que o último aviso acende, em vermelho.',
    regra: 'contrato_vencendo',
    editavel_por: 'admin_master',
    padrao: 30,
  },
  {
    chave: 'alerta.ata_nao_enviada_horas',
    rotulo: 'Ata não enviada',
    grupo: 'alertas',
    unidade: 'horas',
    explicacao: 'Horas entre o encontro realizado e o alerta de ata que ainda não saiu.',
    regra: 'ata_nao_enviada',
    editavel_por: 'admin_master',
    padrao: 24,
  },
  {
    chave: 'alerta.concentracao_limite',
    rotulo: 'Concentração de pipeline',
    grupo: 'alertas',
    unidade: 'fracao',
    explicacao: 'Fração do pipeline declarado que os dois maiores negócios podem ocupar.',
    regra: 'concentracao_de_pipeline',
    editavel_por: 'admin_master',
    padrao: 0.5,
  },
  {
    chave: 'higiene.dias_sem_interacao',
    rotulo: 'Dias sem interação',
    grupo: 'higiene',
    unidade: 'dias',
    explicacao: 'Dias sem conversa registrada que quebram a terceira invariante de higiene.',
    regra: 'higiene_quebrada',
    editavel_por: 'admin_master',
    padrao: 30,
  },
  {
    chave: 'parceria.protecao_indicacao_dias',
    rotulo: 'Proteção da indicação',
    grupo: 'parceria',
    unidade: 'dias',
    explicacao:
      'Dias que a indicação aceita reserva a conta ao parceiro. Cada indicação copia o prazo vigente no momento do registro.',
    regra: null,
    editavel_por: 'admin_master',
    padrao: 90,
  },
]

/** As quatro chaves de meta. Nascem vazias de propósito. */
interface DescricaoDeMeta {
  chave: string
  rotulo: string
  periodo: MetaConfigurada['periodo']
  escopo: MetaConfigurada['escopo']
  editavel_por: MetaConfigurada['editavel_por']
}

export const CATALOGO_DE_METAS: DescricaoDeMeta[] = [
  {
    chave: 'meta.anual_casa',
    rotulo: 'Meta anual da casa',
    periodo: 'anual',
    escopo: 'casa',
    editavel_por: 'lider',
  },
  {
    chave: 'meta.trimestral_casa',
    rotulo: 'Meta trimestral da casa',
    periodo: 'trimestral',
    escopo: 'casa',
    editavel_por: 'lider',
  },
  {
    chave: 'meta.anual_por_pessoa',
    rotulo: 'Meta anual por pessoa',
    periodo: 'anual',
    escopo: 'por_pessoa',
    editavel_por: 'lider',
  },
  {
    chave: 'meta.trimestral_por_pessoa',
    rotulo: 'Meta trimestral por pessoa',
    periodo: 'trimestral',
    escopo: 'por_pessoa',
    editavel_por: 'lider',
  },
]

/** Os prazos de exemplo, montados a partir do padrão semeado nas migrações. */
export const PRAZOS_EXEMPLO: PrazoConfiguravel[] = CATALOGO_DE_PRAZOS.map((linha) => ({
  chave: linha.chave,
  rotulo: linha.rotulo,
  grupo: linha.grupo,
  valor: linha.padrao,
  unidade: linha.unidade,
  explicacao: linha.explicacao,
  regra: linha.regra,
  editavel_por: linha.editavel_por,
}))

/** As metas de exemplo, todas vazias, exatamente como a semente as cria. */
export const METAS_EXEMPLO: MetaConfigurada[] = CATALOGO_DE_METAS.map((linha) => ({
  chave: linha.chave,
  rotulo: linha.rotulo,
  periodo: linha.periodo,
  escopo: linha.escopo,
  valor: null,
  pessoas_com_meta: 0,
  editavel_por: linha.editavel_por,
}))

// ------------------------------------------------------ leitura do banco

interface LinhaUsuarioBanco {
  id: string
  nome: string
  email: string | null
  perfil: UsuarioNaTela['perfil']
  ativo: boolean
  mfa_obrigatorio: boolean
  ultimo_acesso: string | null
  auth_id: string | null
  criado_em: string
}

interface LinhaConviteBanco {
  id: string
  nome: string
  email: string | null
  perfil: ConviteNaTela['perfil']
  expira_em: string
  aceito_em: string | null
  reenviado_em: string | null
  reenvios: number
  criado_em: string
}

interface LinhaOfertaBanco {
  id: string
  codigo: string
  nome: string
  familia: string
  modalidade: OfertaNaTela['modalidade']
  niveis_aceitos: OfertaNaTela['niveis_aceitos']
  gera_turma: boolean
  publico_alvo: string | null
  estrutura: string | null
  ativa: boolean
  sugerida: boolean
  ordem: number
}

interface LinhaRegraBanco {
  id: string
  codigo: string
  nome: string
  descricao: string | null
  entidade_alvo: string
  criticidade: RegraNaTela['criticidade']
  canal: RegraNaTela['canal']
  destinatario_perfil: RegraNaTela['destinatario_perfil']
  destinatario_papel: RegraNaTela['destinatario_papel']
  ativa: boolean
  configuravel: boolean
  ordem: number
}

interface LinhaConfiguracaoBanco {
  chave: string
  valor: unknown
  rotulo: string
  grupo: string
}

/** Lê um número do jsonb de `valor.configuracoes`. Nulo quando está vazio. */
function lerNumero(valor: unknown): number | null {
  if (typeof valor === 'number' && !Number.isNaN(valor)) return valor
  if (typeof valor === 'string' && valor.trim() !== '') {
    const lido = Number(valor)
    return Number.isNaN(lido) ? null : lido
  }
  return null
}

/** Conta quantas chaves um objeto de meta por pessoa já tem preenchidas. */
function contarPessoas(valor: unknown): number {
  if (valor && typeof valor === 'object' && !Array.isArray(valor)) {
    return Object.keys(valor as Record<string, unknown>).length
  }
  return 0
}

// -------------------------------------------------------------- consultas

export interface RespostaUsuarios {
  usuarios: UsuarioNaTela[]
  convites: ConviteNaTela[]
  deExemplo: boolean
}

export function useUsuarios(): UseQueryResult<RespostaUsuarios, Error> {
  return useQuery<RespostaUsuarios, Error>({
    queryKey: ['configuracao', 'usuarios', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        return { usuarios: USUARIOS_EXEMPLO, convites: CONVITES_EXEMPLO, deExemplo: true }
      }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      const { data: usuarios, error: erroUsuarios } = await cliente
        .from('usuarios')
        .select('id, nome, email, perfil, ativo, mfa_obrigatorio, ultimo_acesso, auth_id, criado_em')
        .is('arquivado_em', null)
        .order('nome')
        .returns<LinhaUsuarioBanco[]>()

      if (erroUsuarios) throw new Error(erroUsuarios.message)

      const { data: convites, error: erroConvites } = await cliente
        .from('convites')
        .select('id, nome, email, perfil, expira_em, aceito_em, reenviado_em, reenvios, criado_em')
        .is('arquivado_em', null)
        .order('criado_em', { ascending: false })
        .returns<LinhaConviteBanco[]>()

      if (erroConvites) throw new Error(erroConvites.message)

      return {
        usuarios: (usuarios ?? []).map((linha) => ({
          id: linha.id,
          nome: linha.nome,
          email: linha.email,
          perfil: linha.perfil,
          ativo: linha.ativo,
          mfa_obrigatorio: linha.mfa_obrigatorio,
          ultimo_acesso: linha.ultimo_acesso,
          auth_id: linha.auth_id,
          contas_atribuidas: 0,
          contas: [],
          parceiro_nome: null,
          criado_em: linha.criado_em,
        })),
        convites: convites ?? [],
        deExemplo: false,
      }
    },
  })
}

export interface RespostaOfertas {
  ofertas: OfertaNaTela[]
  deExemplo: boolean
}

export function useOfertas(): UseQueryResult<RespostaOfertas, Error> {
  return useQuery<RespostaOfertas, Error>({
    queryKey: ['configuracao', 'ofertas', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { ofertas: OFERTAS_EXEMPLO, deExemplo: true }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      const { data, error } = await cliente
        .from('ofertas')
        .select(
          'id, codigo, nome, familia, modalidade, niveis_aceitos, gera_turma, publico_alvo, estrutura, ativa, sugerida, ordem',
        )
        .is('arquivado_em', null)
        .order('ordem')
        .returns<LinhaOfertaBanco[]>()

      if (error) throw new Error(error.message)

      return {
        ofertas: (data ?? []).map((linha) => ({ ...linha, negocios_no_historico: 0 })),
        deExemplo: false,
      }
    },
  })
}

export interface RespostaRegrasEPrazos {
  regras: RegraNaTela[]
  prazos: PrazoConfiguravel[]
  metas: MetaConfigurada[]
  deExemplo: boolean
}

export function useRegrasEPrazos(): UseQueryResult<RespostaRegrasEPrazos, Error> {
  return useQuery<RespostaRegrasEPrazos, Error>({
    queryKey: ['configuracao', 'regras-e-prazos', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        return {
          regras: REGRAS_EXEMPLO,
          prazos: PRAZOS_EXEMPLO,
          metas: METAS_EXEMPLO,
          deExemplo: true,
        }
      }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      const { data: regras, error: erroRegras } = await cliente
        .from('regras_alerta')
        .select(
          'id, codigo, nome, descricao, entidade_alvo, criticidade, canal, destinatario_perfil, destinatario_papel, ativa, configuravel, ordem',
        )
        .is('arquivado_em', null)
        .order('ordem')
        .returns<LinhaRegraBanco[]>()

      if (erroRegras) throw new Error(erroRegras.message)

      const { data: configuracoes, error: erroConfiguracoes } = await cliente
        .from('configuracoes')
        .select('chave, valor, rotulo, grupo')
        .is('arquivado_em', null)
        .returns<LinhaConfiguracaoBanco[]>()

      if (erroConfiguracoes) throw new Error(erroConfiguracoes.message)

      const porChave = new Map<string, LinhaConfiguracaoBanco>()
      for (const linha of configuracoes ?? []) porChave.set(linha.chave, linha)

      const prazos: PrazoConfiguravel[] = CATALOGO_DE_PRAZOS.map((descricao) => {
        const doBanco = porChave.get(descricao.chave)
        return {
          chave: descricao.chave,
          rotulo: doBanco?.rotulo ?? descricao.rotulo,
          grupo: doBanco?.grupo ?? descricao.grupo,
          valor: doBanco ? lerNumero(doBanco.valor) : null,
          unidade: descricao.unidade,
          explicacao: descricao.explicacao,
          regra: descricao.regra,
          editavel_por: descricao.editavel_por,
        }
      })

      const metas: MetaConfigurada[] = CATALOGO_DE_METAS.map((descricao) => {
        const doBanco = porChave.get(descricao.chave)
        return {
          chave: descricao.chave,
          rotulo: doBanco?.rotulo ?? descricao.rotulo,
          periodo: descricao.periodo,
          escopo: descricao.escopo,
          valor: descricao.escopo === 'casa' && doBanco ? lerNumero(doBanco.valor) : null,
          pessoas_com_meta:
            descricao.escopo === 'por_pessoa' && doBanco ? contarPessoas(doBanco.valor) : 0,
          editavel_por: descricao.editavel_por,
        }
      })

      return {
        regras: (regras ?? []).map((linha) => ({
          ...linha,
          mensagem: linha.descricao,
          prazos_que_usa:
            CATALOGO_DE_PRAZOS.filter((prazo) => prazo.regra === linha.codigo).map(
              (prazo) => prazo.chave,
            ) ?? [],
          alertas_abertos: 0,
        })),
        prazos,
        metas,
        deExemplo: false,
      }
    },
  })
}
