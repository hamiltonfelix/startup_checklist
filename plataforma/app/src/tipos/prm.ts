/**
 * Tipos do PRM de Valor: parceiros, acesso ao portal, indicações e comissão.
 *
 * Espelho fiel das migrações do esquema `valor`:
 *   0004_prm_parceiros.sql    · parceiros, parceiros_usuarios e indicacoes
 *   0006_comissoes_e_margem.sql · percentuais_padrao e comissoes
 *   0015_views_paineis.sql    · vw_painel_parceiro
 *
 * Os nomes de campo são exatamente os do banco, em snake_case sem acento, para
 * que o `select` do Supabase case sem tradução no meio do caminho. Os rótulos
 * bonitos de tela ficam nos dicionários do fim do arquivo.
 *
 * Aviso que vale para todo este arquivo: confidencialidade não é trabalho da
 * interface. Quem decide o que cada um enxerga é a política de linha e a
 * máscara de coluna no banco, conforme as seções 8 e 9 do contrato técnico.
 * Campo que pode voltar nulo por máscara está marcado como tal, e a tela
 * mostra o que chegou, sem inventar condição de perfil.
 */

import type { Data, DataHora, Dinheiro, Fase, Uuid } from '@/tipos/dominio'

// ------------------------------------------------------------------ enums
// Cada tipo abaixo repete, na mesma ordem, os valores do `create type` da 0004.

export type ParceiroTipo = 'indicador' | 'canal' | 'consultor_associado' | 'conselheiro_banco'

export type ParceiroTipoPessoa = 'fisica' | 'juridica'

export type ParceiroStatus = 'prospecto' | 'em_credenciamento' | 'ativo' | 'suspenso' | 'encerrado'

export type IndicacaoStatus =
  | 'registrada'
  | 'em_analise'
  | 'aceita'
  | 'recusada'
  | 'duplicada'
  | 'convertida'
  | 'expirada'

/**
 * Espelho de `valor.comissao_beneficiario`, na ordem do `create type` da 0006.
 *
 * Os três valores são copiados do banco sem tradução, porque é assim que eles
 * chegam na coluna `beneficiario_tipo`. Identificador de banco se escreve como
 * o banco escreve, em snake_case sem acento, conforme a seção 2 do contrato
 * técnico. O primeiro deles nomeia a pessoa da casa que fecha o negócio, e o
 * rótulo de tela desse registro é Gerente de Contas, conforme a seção 3. A
 * ponte entre o identificador e o rótulo é o dicionário `ROTULO_BENEFICIARIO`,
 * no fim deste arquivo, e nenhuma tela mostra o identificador cru.
 */
export type ComissaoBeneficiario = 'vendedor_interno' | 'parceiro' | 'conselheiro'

/** Espelho de `valor.comissao_status`. Cancelada não entra em nenhum total. */
export type ComissaoStatus = 'prevista' | 'apurada' | 'paga' | 'cancelada'

// ------------------------------------------------------------- parceiros

export interface Parceiro {
  id: Uuid
  inquilino_id: Uuid
  conta_id: Uuid | null
  nome: string
  razao_social: string | null
  tipo_pessoa: ParceiroTipoPessoa
  /** CONFIDENCIAL no banco. Pode voltar nulo por máscara de coluna. */
  documento: string | null
  tipo: ParceiroTipo
  status: ParceiroStatus
  email_comercial: string | null
  /** CONFIDENCIAL no banco. Pode voltar nulo por máscara de coluna. */
  telefone_comercial: string | null
  cidade: string | null
  uf: string | null
  site: string | null
  responsavel_interno_id: Uuid | null
  credenciado_em: Data | null
  vigencia_inicio: Data | null
  vigencia_fim: Data | null
  contrato_parceria_url: string | null
  /** CONFIDENCIAL no banco. Condição própria, em pontos percentuais. */
  comissao_percentual_negociado: number | null
  /** Dias que a indicação aceita reserva a conta. Padrão da casa: 90. */
  prazo_protecao_dias: number
  /** CONFIDENCIAL no banco. Texto livre do que foi combinado fora da tabela. */
  condicoes_comerciais: string | null
  servicos: string[]
  treinamentos_concluidos: string[]
  autoriza_divulgacao_site: boolean
  observacoes: string | null
  criado_em: DataHora
  atualizado_em: DataHora | null
  arquivado_em: DataHora | null
}

/** Linha da lista de parceiros, com o que ele trouxe já somado. */
export interface ParceiroNaLista {
  id: Uuid
  nome: string
  tipo: ParceiroTipo
  tipo_pessoa: ParceiroTipoPessoa
  status: ParceiroStatus
  cidade: string | null
  uf: string | null
  credenciado_em: Data | null
  vigencia_fim: Data | null
  prazo_protecao_dias: number
  responsavel_interno_nome: string | null
  /** Quantas indicações ele registrou, em qualquer situação. */
  indicacoes: number
  /** Quantas viraram negócio. */
  indicacoes_convertidas: number
  /** Quantas ainda esperam a decisão da casa. */
  indicacoes_em_aberto: number
  /** Soma dos negócios gerados por ele. Pode voltar nulo por máscara. */
  valor_gerado: Dinheiro | null
  /** Soma da comissão dele, sem as linhas canceladas. Pode voltar nula. */
  comissao_total: Dinheiro | null
  ultima_indicacao_em: Data | null
}

/** Quem entra no portal em nome do parceiro. */
export interface UsuarioDoParceiro {
  id: Uuid
  parceiro_id: Uuid
  usuario_id: Uuid
  usuario_nome: string
  /** O endereço de correio do acesso. Pode voltar nulo por máscara. */
  usuario_email: string | null
  /** Um por parceiro, por convenção da tela. */
  principal: boolean
  ativo: boolean
  ultimo_acesso_portal: DataHora | null
}

// ------------------------------------------------------------ indicações

export interface Indicacao {
  id: Uuid
  inquilino_id: Uuid
  parceiro_id: Uuid
  conta_id: Uuid | null
  conta_indicada_nome: string
  conta_indicada_documento: string | null
  conta_indicada_site: string | null
  conta_indicada_cidade: string | null
  conta_indicada_uf: string | null
  contato_nome: string
  contato_cargo: string | null
  /** CONFIDENCIAL no banco. Pode voltar nulo por máscara de coluna. */
  contato_email: string | null
  /** CONFIDENCIAL no banco. Pode voltar nulo por máscara de coluna. */
  contato_telefone: string | null
  oferta_id: Uuid | null
  contexto: string
  necessidade_percebida: string | null
  status: IndicacaoStatus
  analisado_por: Uuid | null
  decidido_em: DataHora | null
  motivo_recusa: string | null
  conflito_com_negocio_id: Uuid | null
  aceita_em: Data | null
  prazo_protecao_dias: number
  /** Calculada no banco: `aceita_em` mais `prazo_protecao_dias`. */
  protecao_expira_em: Data | null
  negocio_id: Uuid | null
  criado_em: DataHora
  arquivado_em: DataHora | null
}

/** A indicação como a tela lê, com o parceiro e o negócio já resolvidos. */
export interface IndicacaoNaTela {
  id: Uuid
  parceiro_id: Uuid
  parceiro_nome: string
  conta: string
  contato_nome: string
  contato_cargo: string | null
  oferta_nome: string | null
  contexto: string
  necessidade_percebida: string | null
  status: IndicacaoStatus
  registrada_em: Data
  decidido_em: DataHora | null
  motivo_recusa: string | null
  aceita_em: Data | null
  prazo_protecao_dias: number
  protecao_expira_em: Data | null
  /** Quantos dias faltam para a proteção vencer. Negativo quando já venceu. */
  dias_para_expirar_protecao: number | null
  negocio_id: Uuid | null
  negocio_titulo: string | null
  negocio_fase: Fase | null
  /** Valor do negócio gerado. Pode voltar nulo por máscara de coluna. */
  negocio_valor: Dinheiro | null
  analisado_por_nome: string | null
}

// --------------------------------------------------------- proteção de conta

/** Em que ponto do prazo de proteção a indicação está. */
export type SituacaoProtecao = 'sem_protecao' | 'em_dia' | 'perto_de_vencer' | 'vencida'

/**
 * Faixa de alarme da proteção. Dez dias ou menos acende o amarelo, porque é o
 * tempo mínimo para a casa correr atrás do negócio antes de a reserva cair.
 */
export const DIAS_ALARME_PROTECAO = 10

export function situacaoDaProtecao(
  dias: number | null | undefined,
  status: IndicacaoStatus,
): SituacaoProtecao {
  if (status !== 'aceita' && status !== 'convertida' && status !== 'expirada') return 'sem_protecao'
  if (dias === null || dias === undefined) return 'sem_protecao'
  if (dias < 0) return 'vencida'
  if (dias <= DIAS_ALARME_PROTECAO) return 'perto_de_vencer'
  return 'em_dia'
}

// -------------------------------------------------------------- comissões

export interface LinhaComissao {
  id: Uuid
  beneficiario_tipo: ComissaoBeneficiario
  /** Nome de quem recebe, seja pessoa da casa ou parceiro. */
  beneficiario_nome: string
  /** Identificador de quem recebe, para agrupar o extrato por pessoa. */
  beneficiario_id: Uuid
  conta_nome: string
  negocio_titulo: string | null
  contrato_codigo: string | null
  /** Qual parcela do contrato gerou esta linha. */
  parcela_numero: number | null
  /** Primeiro dia do mês de competência. */
  competencia: Data
  status: ComissaoStatus
  pago_em: Data | null
  /** Passo 1 da conta: o valor bruto da parcela. */
  valor_bruto: Dinheiro
  /** Passo 2: percentual de imposto, em pontos percentuais. Padrão 15. */
  imposto_percentual: number
  imposto_valor: Dinheiro
  /** Passo 3: bruto menos imposto. É sobre isto que a comissão incide. */
  base_calculo: Dinheiro
  /** Passo 4: percentual sobre a base, em pontos percentuais. Padrão 10. */
  percentual: number | null
  valor: Dinheiro
  /** O mesmo dinheiro lido sobre o bruto. Com 10 sobre a base e 15 de imposto, dá 8,5. */
  percentual_efetivo_sobre_bruto: number | null
  observacao: string | null
}

/** A conta aberta de uma linha, na ordem exata em que a casa decidiu. */
export interface AberturaDoCalculo {
  valor_bruto: Dinheiro
  imposto_percentual: number
  imposto_valor: Dinheiro
  base_calculo: Dinheiro
  percentual_sobre_base: number | null
  valor: Dinheiro
  percentual_efetivo_sobre_bruto: number | null
}

/**
 * Abre o cálculo de uma linha, passo a passo.
 *
 * Os números saem do banco, que é quem apura. O percentual efetivo é
 * recalculado aqui só quando a coluna calculada não veio, para a tela nunca
 * ficar sem o segundo número. Os dois percentuais aparecem juntos, sempre:
 * é isso que faz o extrato de quem recebe bater com o de quem paga.
 */
export function abrirCalculo(linha: LinhaComissao): AberturaDoCalculo {
  const efetivo =
    linha.percentual_efetivo_sobre_bruto ??
    (linha.valor_bruto > 0 ? (linha.valor * 100) / linha.valor_bruto : null)

  return {
    valor_bruto: linha.valor_bruto,
    imposto_percentual: linha.imposto_percentual,
    imposto_valor: linha.imposto_valor,
    base_calculo: linha.base_calculo,
    percentual_sobre_base: linha.percentual,
    valor: linha.valor,
    percentual_efetivo_sobre_bruto: efetivo,
  }
}

/** Totais de uma competência, por situação. Cancelada fica fora de tudo. */
export interface TotalDaCompetencia {
  competencia: Data
  prevista: Dinheiro
  apurada: Dinheiro
  paga: Dinheiro
  /** Prevista mais apurada mais paga. A cancelada não entra. */
  total: Dinheiro
  bruto: Dinheiro
  imposto: Dinheiro
  base: Dinheiro
  quantas: number
}

/** O extrato de uma pessoa, agrupado por competência. */
export interface ExtratoDeComissao {
  beneficiario_id: Uuid
  beneficiario_nome: string
  beneficiario_tipo: ComissaoBeneficiario
  competencias: Array<{ total: TotalDaCompetencia; linhas: LinhaComissao[] }>
  geral: TotalDaCompetencia
}

function totalVazio(competencia: Data): TotalDaCompetencia {
  return {
    competencia,
    prevista: 0,
    apurada: 0,
    paga: 0,
    total: 0,
    bruto: 0,
    imposto: 0,
    base: 0,
    quantas: 0,
  }
}

function acumular(alvo: TotalDaCompetencia, linha: LinhaComissao): void {
  if (linha.status === 'cancelada') return
  if (linha.status === 'prevista') alvo.prevista += linha.valor
  if (linha.status === 'apurada') alvo.apurada += linha.valor
  if (linha.status === 'paga') alvo.paga += linha.valor
  alvo.total += linha.valor
  alvo.bruto += linha.valor_bruto
  alvo.imposto += linha.imposto_valor
  alvo.base += linha.base_calculo
  alvo.quantas += 1
}

/**
 * Monta o extrato por pessoa e por competência a partir do que o banco
 * entregou. Nenhum filtro de perfil acontece aqui, e nenhum pode acontecer:
 * a política de linha já decidiu o que cada um recebe. Se veio, entra.
 */
export function montarExtratos(linhas: LinhaComissao[]): ExtratoDeComissao[] {
  const porPessoa = new Map<string, ExtratoDeComissao>()
  const porCompetencia = new Map<string, { total: TotalDaCompetencia; linhas: LinhaComissao[] }>()

  for (const linha of linhas) {
    const chavePessoa = `${linha.beneficiario_tipo}:${linha.beneficiario_id}`

    let extrato = porPessoa.get(chavePessoa)
    if (!extrato) {
      extrato = {
        beneficiario_id: linha.beneficiario_id,
        beneficiario_nome: linha.beneficiario_nome,
        beneficiario_tipo: linha.beneficiario_tipo,
        competencias: [],
        geral: totalVazio('todas'),
      }
      porPessoa.set(chavePessoa, extrato)
    }

    const chaveCompetencia = `${chavePessoa}|${linha.competencia}`
    let grupo = porCompetencia.get(chaveCompetencia)
    if (!grupo) {
      grupo = { total: totalVazio(linha.competencia), linhas: [] }
      porCompetencia.set(chaveCompetencia, grupo)
      extrato.competencias.push(grupo)
    }

    grupo.linhas.push(linha)
    acumular(grupo.total, linha)
    acumular(extrato.geral, linha)
  }

  const extratos = [...porPessoa.values()]
  for (const extrato of extratos) {
    extrato.competencias.sort((a, b) => b.total.competencia.localeCompare(a.total.competencia))
  }
  extratos.sort((a, b) => a.beneficiario_nome.localeCompare(b.beneficiario_nome, 'pt-BR'))
  return extratos
}

// ---------------------------------------------------------------- rótulos

export const ROTULO_TIPO_PARCEIRO: Record<ParceiroTipo, string> = {
  indicador: 'Indicador',
  canal: 'Canal',
  consultor_associado: 'Consultor associado',
  conselheiro_banco: 'Banco de conselheiros',
}

export const ROTULO_TIPO_PESSOA: Record<ParceiroTipoPessoa, string> = {
  fisica: 'Pessoa física',
  juridica: 'Pessoa jurídica',
}

export const ROTULO_STATUS_PARCEIRO: Record<ParceiroStatus, string> = {
  prospecto: 'Prospecto',
  em_credenciamento: 'Em credenciamento',
  ativo: 'Credenciado e ativo',
  suspenso: 'Suspenso',
  encerrado: 'Encerrado',
}

/** O que cada situação de credenciamento significa na prática. */
export const CRITERIO_STATUS_PARCEIRO: Record<ParceiroStatus, string> = {
  prospecto: 'Conversa iniciada. Ainda não assinou o contrato de parceria.',
  em_credenciamento: 'Documentação e treinamento em andamento. Ainda não pode indicar.',
  ativo: 'Credenciamento concluído, com data registrada. Pode indicar e receber comissão.',
  suspenso: 'Credenciamento parado por decisão da casa. Indicações novas ficam bloqueadas.',
  encerrado: 'Parceria terminada. O histórico fica, as indicações antigas continuam válidas.',
}

export const ROTULO_STATUS_INDICACAO: Record<IndicacaoStatus, string> = {
  registrada: 'Registrada pelo parceiro',
  em_analise: 'Em análise pela casa',
  aceita: 'Aceita',
  recusada: 'Recusada',
  duplicada: 'Duplicada',
  convertida: 'Convertida em negócio',
  expirada: 'Proteção vencida',
}

/**
 * A ponte entre o identificador do banco e o rótulo de tela.
 *
 * A chave é o valor do enum, escrita como o banco a escreve. O valor é o que a
 * pessoa lê, no vocabulário obrigatório da seção 3 do contrato técnico.
 */
export const ROTULO_BENEFICIARIO: Record<ComissaoBeneficiario, string> = {
  vendedor_interno: 'Gerente de Contas',
  parceiro: 'Parceiro',
  conselheiro: 'Conselheiro',
}

export const ROTULO_STATUS_COMISSAO: Record<ComissaoStatus, string> = {
  prevista: 'Prevista',
  apurada: 'Apurada',
  paga: 'Paga',
  cancelada: 'Cancelada',
}

export const CRITERIO_STATUS_COMISSAO: Record<ComissaoStatus, string> = {
  prevista: 'A parcela existe no contrato e ainda não foi recebida.',
  apurada: 'A parcela foi recebida e a comissão está calculada, aguardando pagamento.',
  paga: 'O dinheiro saiu, com data de pagamento registrada.',
  cancelada: 'Linha anulada. Não entra em nenhum total desta tela.',
}

export const ROTULO_SITUACAO_PROTECAO: Record<SituacaoProtecao, string> = {
  sem_protecao: 'Sem proteção corrente',
  em_dia: 'Proteção em dia',
  perto_de_vencer: 'Proteção perto de vencer',
  vencida: 'Proteção vencida',
}

/** Percentual em pontos, escrito como a casa escreve. */
export function pontosPercentuais(valor: number | null | undefined): string {
  if (valor === null || valor === undefined || Number.isNaN(valor)) return 'sem percentual'
  const texto = new Intl.NumberFormat('pt-BR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(valor)
  return `${texto} por cento`
}

/** Competência escrita como mês e ano, que é como o financeiro lê. */
export function competencia(valor: string | null | undefined): string {
  if (!valor) return 'sem competência'
  if (valor === 'todas') return 'Todas as competências'
  const d = new Date(`${valor.slice(0, 10)}T12:00:00`)
  if (Number.isNaN(d.getTime())) return 'sem competência'
  const texto = new Intl.DateTimeFormat('pt-BR', { month: 'long', year: 'numeric' }).format(d)
  return texto.charAt(0).toUpperCase() + texto.slice(1)
}
