/**
 * Tipos da Configuração: usuários, convites, ofertas, regras e prazos.
 *
 * Espelho fiel das migrações do esquema `valor`:
 *   0001_tipos_e_funcoes.sql       · o enum `valor.perfil_usuario`, com dez valores
 *   0002_inquilinos_e_usuarios.sql · usuarios, convites e configuracoes
 *   0003_nucleo_crm.sql            · ofertas
 *   0012_alertas_e_automacoes.sql  · regras_alerta e as chaves `alerta.` e `higiene.`
 *   0016_semente_do_inquilino.sql  · as chaves `parceria.` e `meta.`
 *
 * O contrato é claro na seção 8: o banco decide o que cada um vê. Esta tela
 * descreve o alcance de cada perfil para quem convida entender o que está
 * entregando, e nada mais. Nenhuma linha daqui esconde dado.
 */

import type { DataHora, ModalidadeOferta, NivelContrato, PerfilUsuario } from '@/tipos/dominio'
import type { Criticidade, Data, PapelNegocio, Uuid } from '@/tipos/dominio'

/**
 * Os dez perfis do enum `valor.perfil_usuario`.
 *
 * O `participante` nasceu na migração 0001 e é a pessoa do cliente que ocupa
 * cadeira numa turma. Ele ainda não existe em `PerfilUsuario` de
 * `src/tipos/dominio.ts`, que é arquivo de outro dono, então a tela de
 * usuários trabalha com este apelido, que cobre os dez.
 */
export type PerfilPlataforma = PerfilUsuario | 'participante'

/** Os dez, na ordem em que a tela os apresenta: da casa para fora. */
export const PERFIS: PerfilPlataforma[] = [
  'admin_master',
  'lider',
  'comercial',
  'gerente_contas',
  'conselheiro',
  'assessor',
  'financeiro',
  'parceiro',
  'participante',
  'emergencia',
]

export const ROTULO_PERFIL_PLATAFORMA: Record<PerfilPlataforma, string> = {
  admin_master: 'Administrador',
  lider: 'Líder',
  comercial: 'Comercial',
  gerente_contas: 'Gerente de Contas',
  conselheiro: 'Conselheiro',
  assessor: 'Assessor executivo',
  financeiro: 'Financeiro',
  parceiro: 'Parceiro',
  participante: 'Participante de turma',
  emergencia: 'Conta de emergência',
}

/** Onde a pessoa com este perfil trabalha. Serve para agrupar a lista. */
export type OrigemDoPerfil = 'casa' | 'fora'

export interface AlcanceDoPerfil {
  perfil: PerfilPlataforma
  origem: OrigemDoPerfil
  /** Uma linha, para caber ao lado do nome do perfil na hora de convidar. */
  resumo: string
  /** O que este perfil alcança, item a item, em texto claro. */
  alcanca: string[]
  /** O que este perfil não alcança, para quem convida não se enganar. */
  nao_alcanca: string[]
}

/**
 * O alcance de cada perfil, escrito para quem convida.
 *
 * Isto é documentação de tela, não regra de acesso. A regra vive nas políticas
 * de linha do banco, e este texto descreve o que elas fazem. Se as duas coisas
 * divergirem, quem está errado é este texto, e não o banco.
 */
export const ALCANCE: Record<PerfilPlataforma, AlcanceDoPerfil> = {
  admin_master: {
    perfil: 'admin_master',
    origem: 'casa',
    resumo: 'Alcança tudo, inclusive convidar gente e trocar as regras da casa.',
    alcanca: [
      'Toda conta, todo negócio e todo contrato do inquilino',
      'Margem, comissão de qualquer pessoa e custo de conselheiro',
      'Convite, perfil, ativação, múltiplo fator e revogação de sessão',
      'Catálogo de ofertas, regras de alerta e prazos configuráveis',
    ],
    nao_alcanca: ['Dado de outro inquilino, em nenhuma hipótese'],
  },
  lider: {
    perfil: 'lider',
    origem: 'casa',
    resumo: 'Enxerga a casa inteira e os números do dono, mas não administra acesso.',
    alcanca: [
      'Todo negócio, contrato e painel do inquilino',
      'Margem, comissão de terceiros e custo de conselheiro',
      'Meta do período, catálogo de ofertas e regras de alerta',
    ],
    nao_alcanca: ['Convidar pessoas, trocar perfil ou revogar sessão'],
  },
  comercial: {
    perfil: 'comercial',
    origem: 'casa',
    resumo: 'Toca o funil inteiro e o canal de parceiros, sem ver margem.',
    alcanca: [
      'Contas, negócios e atividades de toda a casa',
      'Cadastro de parceiros e análise das indicações',
    ],
    nao_alcanca: ['Margem, comissão de terceiros e custo de conselheiro'],
  },
  gerente_contas: {
    perfil: 'gerente_contas',
    origem: 'casa',
    resumo: 'Trabalha as contas em que tem papel, e vê a própria comissão.',
    alcanca: [
      'As contas e os negócios em que tem papel registrado',
      'O próprio extrato de comissão, com o cálculo aberto',
      'A lista de colegas da casa, com nome e perfil',
    ],
    nao_alcanca: ['Comissão de outra pessoa, margem e custo de conselheiro'],
  },
  conselheiro: {
    perfil: 'conselheiro',
    origem: 'casa',
    resumo: 'Entrega o conselho: turmas, encontros, atas e pendências.',
    alcanca: [
      'As turmas e os encontros em que atua',
      'Atas, pendências e entregáveis das suas turmas',
      'A própria remuneração e o valor do contrato da conta em que atua',
    ],
    nao_alcanca: ['Margem, comissão de terceiros e avaliação de pessoas'],
  },
  assessor: {
    perfil: 'assessor',
    origem: 'casa',
    resumo: 'Escreve ata, organiza agenda e cuida do que a entrega exige.',
    alcanca: [
      'Encontros, atas em preparo e pendências das turmas que apoia',
      'Agenda e entregáveis do conselho',
    ],
    nao_alcanca: ['Margem, comissão de qualquer pessoa e ata marcada como restrita'],
  },
  financeiro: {
    perfil: 'financeiro',
    origem: 'casa',
    resumo: 'Cuida de contrato, parcela, apuração e pagamento de comissão.',
    alcanca: [
      'Contratos, parcelas e recebimentos',
      'Comissão de todo mundo, com o cálculo aberto, e margem',
      'O percentual de imposto e os percentuais padrão da casa',
    ],
    nao_alcanca: ['Convidar pessoas, trocar perfil ou revogar sessão'],
  },
  parceiro: {
    perfil: 'parceiro',
    origem: 'fora',
    resumo: 'Portal do canal: as indicações dele, os negócios que saíram delas e a comissão dele.',
    alcanca: [
      'As próprias indicações e a data em que a proteção vence',
      'Os negócios gerados pelas indicações dele',
      'O próprio extrato de comissão, com o cálculo aberto',
    ],
    nao_alcanca: [
      'Margem, comissão de terceiros e custo de conselheiro',
      'Negócio de outro parceiro e conta em que não tem papel',
      'Ata restrita, avaliação de pessoas e a lista do time da casa',
    ],
  },
  participante: {
    perfil: 'participante',
    origem: 'fora',
    resumo: 'Pessoa do cliente sentada numa cadeira de turma. Alcance mínimo, de propósito.',
    alcanca: [
      'A própria turma e o calendário dela',
      'Somente o entregável marcado como visível ao cliente',
    ],
    nao_alcanca: [
      'Funil, contratos, comissão, margem e qualquer número da casa',
      'Ata restrita e a lista do time da casa',
    ],
  },
  emergencia: {
    perfil: 'emergencia',
    origem: 'casa',
    resumo: 'A porta de trás da casa. Mesmo alcance do administrador, uso excepcional.',
    alcanca: ['Tudo que o administrador alcança, para o caso de ninguém mais conseguir entrar'],
    nao_alcanca: ['Uso no dia a dia. Toda entrada dela fica registrada na auditoria'],
  },
}

/**
 * O aviso permanente da conta de emergência.
 *
 * Decisão da casa, registrada na seção 1 do catálogo de regras: a conta nasce
 * no primeiro dia, com múltiplo fator ligado e códigos de recuperação
 * impressos e guardados em envelope lacrado, fisicamente.
 */
export const AVISO_CONTA_DE_EMERGENCIA = [
  'A conta de emergência é criada no primeiro dia de vida do inquilino, e não depois.',
  'Ela tem múltiplo fator obrigatório, sem exceção.',
  'Os códigos de recuperação são impressos em papel e guardados em envelope lacrado, em lugar físico combinado.',
  'Ninguém usa esta conta no dia a dia. Toda entrada dela fica registrada na auditoria.',
]

// ------------------------------------------------------------- usuários

export interface UsuarioNaTela {
  id: Uuid
  nome: string
  /** O endereço de correio do acesso. Pode voltar nulo por máscara de coluna. */
  email: string | null
  perfil: PerfilPlataforma
  ativo: boolean
  mfa_obrigatorio: boolean
  ultimo_acesso: DataHora | null
  /** Nulo enquanto o convite não foi aceito. É o que separa convidado de ativo. */
  auth_id: Uuid | null
  /** Quantas contas a pessoa alcança por papel registrado. */
  contas_atribuidas: number
  /** Nomes das contas atribuídas, para a ficha e para o cartão do telefone. */
  contas: string[]
  /** Preenchido quando o perfil é parceiro. */
  parceiro_nome: string | null
  criado_em: DataHora
}

export interface ConviteNaTela {
  id: Uuid
  nome: string
  /** Endereço para onde o convite foi enviado. Pode voltar nulo por máscara. */
  email: string | null
  perfil: PerfilPlataforma
  expira_em: DataHora
  aceito_em: DataHora | null
  reenviado_em: DataHora | null
  reenvios: number
  criado_em: DataHora
}

export type SituacaoConvite = 'aguardando' | 'aceito' | 'vencido'

export function situacaoDoConvite(convite: ConviteNaTela, agora = new Date()): SituacaoConvite {
  if (convite.aceito_em) return 'aceito'
  return new Date(convite.expira_em).getTime() < agora.getTime() ? 'vencido' : 'aguardando'
}

export const ROTULO_SITUACAO_CONVITE: Record<SituacaoConvite, string> = {
  aguardando: 'Aguardando aceite',
  aceito: 'Aceito',
  vencido: 'Convite vencido',
}

// --------------------------------------------------------------- ofertas

export interface OfertaNaTela {
  id: Uuid
  codigo: string
  nome: string
  familia: string
  modalidade: ModalidadeOferta
  niveis_aceitos: NivelContrato[]
  gera_turma: boolean
  publico_alvo: string | null
  estrutura: string | null
  /** Oferta inativa continua no catálogo, para o histórico não perder nada. */
  ativa: boolean
  /** Só oferta ativa aparece como sugestão ao montar negócio. */
  sugerida: boolean
  ordem: number
  /** Quantos negócios já usaram esta oferta. É por isso que ela nunca some. */
  negocios_no_historico: number
}

/** O que cada nível de contrato significa, conforme a seção 5 do catálogo. */
export const EXPLICACAO_NIVEL: Record<NivelContrato, string> = {
  n1: 'Honorário. Aceito por todas as ofertas.',
  n2: 'Honorário mais participação nos resultados.',
  n3: 'Honorário, participação e equity. Depende de validação de advogado e de contador.',
}

// ----------------------------------------------------- regras e alertas

export interface RegraNaTela {
  id: Uuid
  codigo: string
  nome: string
  descricao: string | null
  /** A tabela do banco que a regra varre, como `negocios` ou `contratos`. */
  entidade_alvo: string
  criticidade: Criticidade
  /** Onde o alerta chega: painel, correio, mensagem ou aviso no telefone. */
  canal: CanalDoAlerta
  /** Perfil que recebe. Nulo quando quem recebe é o papel no negócio. */
  destinatario_perfil: PerfilPlataforma | null
  /** Papel no negócio que recebe. Nulo quando quem recebe é o perfil. */
  destinatario_papel: PapelNegocio | null
  ativa: boolean
  /** Falso quando a regra é estrutural e a tela não deixa mexer na condição. */
  configuravel: boolean
  ordem: number
  /**
   * O texto que chega a quem recebe o alerta. Mora na condição da regra: em
   * `condicao_jsonb.mensagem` quando a condição é declarativa, e no `descricao`
   * quando a condição é consulta escrita à mão.
   */
  mensagem: string | null
  /** Chaves de `valor.configuracoes` que esta regra lê para decidir o prazo. */
  prazos_que_usa: string[]
  /** Quantos alertas desta regra estão abertos agora. */
  alertas_abertos: number
}

export type CanalDoAlerta = 'painel' | 'email' | 'whatsapp' | 'push'

export const ROTULO_CANAL_ALERTA: Record<CanalDoAlerta, string> = {
  painel: 'Painel',
  email: 'Correio eletrônico',
  whatsapp: 'Mensagem',
  push: 'Aviso no telefone',
}

/** Como o número do prazo se lê: dias, horas, fração ou dinheiro. */
export type UnidadeDoPrazo = 'dias' | 'horas' | 'fracao' | 'fator' | 'quantidade' | 'dinheiro'

/**
 * Um prazo configurável, lido de `valor.configuracoes`.
 *
 * Nada aqui é constante de código. Cada linha é uma chave do banco, e trocar
 * o número é trocar a linha, não recompilar a interface.
 */
export interface PrazoConfiguravel {
  chave: string
  rotulo: string
  grupo: string
  /** O conteúdo de `valor.configuracoes.valor`, que é jsonb. Nulo quando vazio. */
  valor: number | null
  unidade: UnidadeDoPrazo
  /** Para que serve, em uma frase. */
  explicacao: string
  /** Código da regra de alerta que lê esta chave. Nulo quando nenhuma lê. */
  regra: string | null
  editavel_por: PerfilPlataforma
}

export type PeriodoDaMeta = 'anual' | 'trimestral'
export type EscopoDaMeta = 'casa' | 'por_pessoa'

/**
 * Uma meta do período, lida de `valor.configuracoes`.
 *
 * As metas nascem vazias de propósito. Sem meta, o painel mostra a cobertura
 * de pipeline como indisponível, e não um número errado.
 */
export interface MetaConfigurada {
  chave: string
  rotulo: string
  periodo: PeriodoDaMeta
  escopo: EscopoDaMeta
  /** Nulo quando a meta da casa ainda não foi informada. */
  valor: number | null
  /** Quantas pessoas já têm meta própria. Só vale no escopo por pessoa. */
  pessoas_com_meta: number
  editavel_por: PerfilPlataforma
}

/** Verdadeiro quando esta meta ainda está em branco. */
export function metaEmBranco(meta: MetaConfigurada): boolean {
  return meta.escopo === 'casa' ? meta.valor === null : meta.pessoas_com_meta === 0
}

/**
 * O que a casa decidiu mostrar no lugar da cobertura enquanto falta meta.
 * Repetido em tela, palavra por palavra, onde a meta estiver vazia.
 */
export const SEM_META_SEM_COBERTURA =
  'Sem meta informada, o painel mostra a cobertura de pipeline como indisponível, e não um número errado.'

export const ROTULO_PERIODO_META: Record<PeriodoDaMeta, string> = {
  anual: 'Anual',
  trimestral: 'Trimestral',
}

export const ROTULO_ESCOPO_META: Record<EscopoDaMeta, string> = {
  casa: 'Da casa',
  por_pessoa: 'Por pessoa',
}

/** Data de acesso lida como a casa lê, com hora e minuto. */
export function dataHora(valor: string | null | undefined): string {
  if (!valor) return 'nunca entrou'
  const d = new Date(valor)
  if (Number.isNaN(d.getTime())) return 'nunca entrou'
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(d)
}

/** Quantos dias separam a data de hoje. Negativo quando a data já passou. */
export function diasAte(valor: Data | DataHora | null | undefined, agora = new Date()): number | null {
  if (!valor) return null
  const alvo = new Date(valor.length <= 10 ? `${valor}T12:00:00` : valor)
  if (Number.isNaN(alvo.getTime())) return null
  const umDia = 24 * 60 * 60 * 1000
  return Math.round((alvo.getTime() - agora.getTime()) / umDia)
}
