/**
 * Rótulos de tela, com acento correto, e os formatadores da interface.
 *
 * O banco fala em `snake_case` sem acento. A tela fala português do Brasil.
 * Este arquivo é a única ponte entre os dois. Vocabulário conforme a seção 3
 * do contrato técnico: Negócio, Gerente de Contas, Plano de Trabalho,
 * Contrato de Valor, Confirmação de Compromisso, Data da decisão do cliente.
 */

import type {
  CanalInteracao,
  ChaveInvariante,
  Criticidade,
  DesfechoNegocio,
  Fase,
  ForecastCategoria,
  ModalidadeOferta,
  NivelContrato,
  OrigemLead,
  PapelNegocio,
  PerfilUsuario,
  Probabilidade,
  RotaNegocio,
  StatusArtefato,
  TierConta,
  TipoArtefato,
} from '@/tipos/dominio'

/** As nove fases do funil do método Negócios de Valor. */
export const ROTULO_FASE: Record<Fase, string> = {
  0: 'Lead',
  1: 'Seleção Estratégica',
  2: 'Exploração Profunda',
  3: 'Conexão de Valor',
  4: 'Confirmação de Compromisso',
  5: 'Execução de Excelência',
  6: 'Cultivo de Valor',
  7: 'Parceria de Crescimento',
  9: 'Arquivo',
}

/** O artefato que comprova a saída de cada fase. */
export const ARTEFATO_DA_FASE: Partial<Record<Fase, TipoArtefato>> = {
  1: 'plano_conta',
  2: 'plano_negocio',
  3: 'plano_trabalho',
  4: 'contrato_valor',
  5: 'entrega_valor',
  6: 'monitoria_valor',
  7: 'renovacao_valor',
}

export const ROTULO_ARTEFATO: Record<TipoArtefato, string> = {
  plano_conta: 'Plano de Conta',
  plano_negocio: 'Plano de Negócio',
  plano_trabalho: 'Plano de Trabalho',
  contrato_valor: 'Contrato de Valor',
  entrega_valor: 'Entrega do Valor',
  monitoria_valor: 'Monitoria do Valor',
  renovacao_valor: 'Renovação do Valor',
}

export const ROTULO_STATUS_ARTEFATO: Record<StatusArtefato, string> = {
  rascunho: 'Rascunho',
  interno_pronto: 'Pronto por dentro',
  validado_com_cliente: 'Validado com o cliente',
  superado: 'Superado',
}

export const ROTULO_FORECAST: Record<ForecastCategoria, string> = {
  compromisso: 'Compromisso',
  possivel: 'Possível',
  aberto: 'Aberto',
  fora: 'Fora',
}

/** O critério de cada categoria. Sai do artefato, nunca de percentual. */
export const CRITERIO_FORECAST: Record<ForecastCategoria, string> = {
  compromisso: 'Existe Contrato de Valor validado com o cliente.',
  possivel: 'Existe Plano de Trabalho validado com o cliente.',
  aberto: 'Existe Plano de Negócio validado com o cliente.',
  fora: 'Nenhum artefato validado com o cliente.',
}

export const ROTULO_PERFIL: Record<PerfilUsuario, string> = {
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

export const ROTULO_PAPEL: Record<PapelNegocio, string> = {
  gerente_contas: 'Gerente de Contas',
  conselheiro: 'Conselheiro',
  pre_vendas: 'Pré-vendas consultiva',
  gerente_projetos: 'Gerente de Projetos',
  assessor: 'Assessor executivo',
  parceiro: 'Parceiro',
}

export const ROTULO_TIER: Record<TierConta, string> = {
  t1: 'Tier 1',
  t2: 'Tier 2',
  t3: 'Tier 3',
}

export const ROTULO_NIVEL: Record<NivelContrato, string> = {
  n1: 'Nível 1',
  n2: 'Nível 2',
  n3: 'Nível 3',
}

export const ROTULO_MODALIDADE: Record<ModalidadeOferta, string> = {
  pontual: 'Pontual',
  recorrente: 'Recorrente',
  pontual_com_sustentacao: 'Pontual com sustentação',
}

export const ROTULO_ROTA: Record<RotaNegocio, string> = {
  privada: 'Rota privada',
  publica: 'Rota pública',
}

export const ROTULO_ORIGEM: Record<OrigemLead, string> = {
  evento: 'Evento',
  indicacao_parceiro: 'Indicação de parceiro',
  indicacao_cliente: 'Indicação de cliente',
  prospeccao_ativa: 'Prospecção ativa',
  inbound: 'Procura espontânea',
  rede_pessoal: 'Rede pessoal',
  licitacao_publica: 'Licitação pública',
  base_instalada: 'Base instalada',
  outro: 'Outro',
}

export const ROTULO_CANAL: Record<CanalInteracao, string> = {
  reuniao_presencial: 'Reunião presencial',
  reuniao_online: 'Reunião on-line',
  ligacao: 'Ligação',
  email: 'Correio eletrônico',
  whatsapp: 'Mensagem',
  evento: 'Evento',
  visita: 'Visita',
  outro: 'Outro',
}

export const ROTULO_DESFECHO: Record<DesfechoNegocio, string> = {
  concluido: 'Concluído',
  vencido: 'Vencido',
  cancelado: 'Cancelado',
  perdido: 'Perdido',
}

/**
 * Leitura qualitativa do time. Existe no banco e aparece como leitura, com
 * estas três palavras. Jamais como percentual, e jamais multiplicando valor
 * para virar previsão de receita.
 */
export const ROTULO_PROBABILIDADE: Record<Probabilidade, string> = {
  alta: 'Leitura alta',
  media: 'Leitura média',
  baixa: 'Leitura baixa',
}

export const ROTULO_CRITICIDADE: Record<Criticidade, string> = {
  verde: 'Em dia',
  amarelo: 'Atenção',
  vermelho: 'Fora do pipeline auditado',
}

/** As quatro invariantes de higiene, na ordem da seção 6 do contrato. */
export const ROTULO_INVARIANTE: Record<ChaveInvariante, string> = {
  proximo_passo_com_data: 'Próximo passo com data',
  data_decisao_no_futuro: 'Data da decisão do cliente no futuro',
  interacao_em_30_dias: 'Interação nos últimos 30 dias',
  artefato_da_fase_registrado: 'Artefato da fase registrado',
}

// ----------------------------------------------------------- formatadores

const MOEDA = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
  maximumFractionDigits: 0,
})

const MOEDA_CENTAVOS = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})

const INTEIRO = new Intl.NumberFormat('pt-BR')

const DATA_CURTA = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
})

const DATA_LONGA = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: 'long',
  year: 'numeric',
})

/** Valor em reais, sem centavos. Para placar e cartão de painel. */
export function dinheiro(valor: number | null | undefined): string {
  if (valor === null || valor === undefined || Number.isNaN(valor)) return 'sem valor'
  return MOEDA.format(valor)
}

/** Valor em reais com centavos. Para linha de contrato e de parcela. */
export function dinheiroExato(valor: number | null | undefined): string {
  if (valor === null || valor === undefined || Number.isNaN(valor)) return 'sem valor'
  return MOEDA_CENTAVOS.format(valor)
}

export function inteiro(valor: number | null | undefined): string {
  if (valor === null || valor === undefined || Number.isNaN(valor)) return '0'
  return INTEIRO.format(valor)
}

export function data(valor: string | null | undefined): string {
  if (!valor) return 'sem data'
  const d = new Date(`${valor.slice(0, 10)}T12:00:00`)
  if (Number.isNaN(d.getTime())) return 'sem data'
  return DATA_CURTA.format(d)
}

export function dataPorExtenso(valor: string | null | undefined): string {
  if (!valor) return 'sem data'
  const d = new Date(`${valor.slice(0, 10)}T12:00:00`)
  if (Number.isNaN(d.getTime())) return 'sem data'
  return DATA_LONGA.format(d)
}

/**
 * Intervalo de datas escrito com a palavra `a`, nunca com traço.
 * Seção 2 do contrato técnico.
 */
export function periodo(inicio: string, fim: string): string {
  return `${data(inicio)} a ${data(fim)}`
}

/** Proporção em percentual, para barra de cumprimento de invariante. */
export function proporcao(parte: number, total: number): number {
  if (!total) return 0
  return Math.round((parte / total) * 100)
}

/** Iniciais para o avatar do cabeçalho. */
export function iniciais(nome: string): string {
  const partes = nome.trim().split(/\s+/).filter(Boolean)
  const primeira = partes[0]?.[0] ?? ''
  const ultima = partes.length > 1 ? (partes[partes.length - 1]?.[0] ?? '') : ''
  return `${primeira}${ultima}`.toUpperCase() || '?'
}
