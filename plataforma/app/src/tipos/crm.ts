/**
 * Tipos e rótulos das telas do CRM de Valor.
 *
 * Complementa `src/tipos/dominio.ts` e `src/tipos/rotulos.ts`, que continuam
 * sendo a fonte do núcleo. Aqui moram apenas as leituras que as telas do CRM
 * consomem: as linhas das visões do banco, com os nomes exatos das colunas, e
 * os rótulos de tela que ainda não existiam.
 *
 * Espelho fiel das migrações:
 *   0003_nucleo_crm.sql           · conta, contato, negócio, papel, artefato, interação
 *   0005_contratos_e_faturamento.sql · contrato
 *   0011_atividades_gtd.sql       · atividade, contexto, coluna do quadro, caixa de entrada
 *   0014_views_forecast_e_higiene.sql · vw_negocios_forecast, vw_pipeline_higiene
 *   0015_views_paineis.sql        · vw_saude_da_conta, vw_contratos_em_curso,
 *                                   vw_agenda_da_semana, vw_alertas_abertos
 *
 * Nenhum campo é renomeado, para que o `select` do Supabase case sem tradução
 * no meio do caminho.
 */

import type {
  CanalInteracao,
  ChaveInvariante,
  Criticidade,
  Data,
  DataHora,
  DesfechoNegocio,
  DesfechoPublico,
  Dinheiro,
  Fase,
  ForecastCategoria,
  ModalidadeOferta,
  NivelContrato,
  OrigemLead,
  PapelNegocio,
  Probabilidade,
  RotaNegocio,
  StatusArtefato,
  TierConta,
  TipoArtefato,
  Uuid,
} from '@/tipos/dominio'
import { ARTEFATO_DA_FASE } from '@/tipos/rotulos'

// ------------------------------------------------------------------ enums
// Repetem, na mesma ordem, os `create type` das migrações 0005 e 0011.

export type EstadoGtd =
  | 'entrada'
  | 'proxima_acao'
  | 'aguardando'
  | 'agendada'
  | 'algum_dia'
  | 'concluida'
  | 'cancelada'

export type EnergiaAtividade = 'alta' | 'media' | 'baixa'

export type SituacaoContrato =
  | 'minuta'
  | 'pendente_assinatura'
  | 'vigente'
  | 'pausado'
  | 'encerrado'
  | 'cancelado'
  | 'vencido'

/** Os quatro montes de `valor.caixa_de_entrada`. */
export type GrupoCaixaDeEntrada =
  | 'entrou_hoje'
  | 'vencida'
  | 'vence_na_janela'
  | 'aguardando_terceiro'

/** Os três tipos que `valor.vw_agenda_da_semana` junta numa lista só. */
export type TipoItemAgenda = 'encontro' | 'reuniao' | 'compromisso'

/** Sinal de vencimento de contrato, de `valor.vw_contratos_em_curso`. */
export type SinalDeVencimento = 'sem_vigencia_fim' | 'vencido' | 'vermelho' | 'amarelo' | 'verde'

// ------------------------------------------------------- linhas das tabelas

/** Uma linha de `valor.contas`, com o nome do Gerente de Contas já resolvido. */
export interface LinhaConta {
  id: Uuid
  nome: string
  razao_social: string | null
  cnpj: string | null
  setor: string | null
  porte: string | null
  cidade: string | null
  uf: string | null
  site: string | null
  /** Tier em vigor. Nulo enquanto ninguém confirmou nada. */
  tier: TierConta | null
  /** O que o sistema calculou. Coisa diferente do tier confirmado. */
  tier_sugerido: TierConta | null
  /** Quando existe, o tier foi confirmado por gente, não pelo sistema. */
  tier_confirmado_em: DataHora | null
  prioridade: 1 | 2 | 3 | null
  /** Quantas linhas do portfólio esta conta já comprou. */
  power_of_x: number
  eh_cliente: boolean
  eh_prospecto: boolean
  eh_fornecedor: boolean
  eh_parceiro: boolean
  gerente_contas_id: Uuid | null
  gerente_contas_nome: string | null
  observacoes: string | null
  criado_em: DataHora
}

/** Uma linha de `valor.contatos`. Telefone e endereço eletrônico podem voltar nulos por máscara. */
export interface LinhaContato {
  id: Uuid
  conta_id: Uuid
  nome: string
  cargo: string | null
  /** Papel na decisão: decisor, influenciador, usuário, guardião, patrocinador. */
  papel_decisao: string | null
  email: string | null
  telefone: string | null
  linkedin: string | null
  eh_principal: boolean
  observacoes: string | null
}

/** Uma linha de `valor.interacoes`, com quem falou e por qual contato. */
export interface LinhaInteracao {
  id: Uuid
  conta_id: Uuid
  negocio_id: Uuid | null
  contato_id: Uuid | null
  contato_nome: string | null
  usuario_id: Uuid | null
  usuario_nome: string | null
  canal: CanalInteracao
  ocorrida_em: DataHora
  assunto: string
  resumo: string | null
  restrita: boolean
  gerado_com_ia: boolean
}

/** Uma linha de `valor.artefatos`. */
export interface LinhaArtefato {
  id: Uuid
  negocio_id: Uuid
  tipo: TipoArtefato
  status: StatusArtefato
  versao: number
  titulo: string | null
  arquivo_url: string | null
  validado_em: Data | null
  gerado_com_ia: boolean
  criado_em: DataHora
}

/** Uma linha de `valor.papeis_negocio`, com o nome de quem ocupa o papel. */
export interface LinhaPapelNegocio {
  id: Uuid
  negocio_id: Uuid
  usuario_id: Uuid | null
  usuario_nome: string | null
  parceiro_id: Uuid | null
  parceiro_nome: string | null
  papel: PapelNegocio
  /** A partir de que fase esta pessoa entrou no negócio. */
  entrou_na_fase: Fase
  principal: boolean
  ativo: boolean
}

/** Uma linha de `valor.negocios_rota_publica`, o bloco da Lei 14.133. */
export interface LinhaRotaPublica {
  negocio_id: Uuid
  identificador_pncp: string | null
  orgao: string | null
  modalidade: string | null
  fase_administrativa: string | null
  data_sessao: Data | null
  data_publicacao: Data | null
  desfecho_publico: DesfechoPublico | null
}

/** Uma linha de `valor.atividades`, com contexto e responsável resolvidos. */
export interface LinhaAtividade {
  id: Uuid
  titulo: string
  descricao: string | null
  estado: EstadoGtd
  contexto_id: Uuid | null
  contexto_codigo: string | null
  contexto_rotulo: string | null
  energia: EnergiaAtividade | null
  tempo_estimado_min: number | null
  prazo: Data | null
  agendada_para: DataHora | null
  responsavel_id: Uuid | null
  responsavel_nome: string | null
  delegado_para_id: Uuid | null
  delegado_para_externo: string | null
  aguardando_desde: Data | null
  prioridade: 1 | 2 | 3 | null
  ordem_kanban: number
  conta_id: Uuid | null
  conta_nome: string | null
  negocio_id: Uuid | null
  negocio_titulo: string | null
  /** Quando existe, a atividade pertence a uma série que se repete. */
  recorrencia_id: Uuid | null
  recorrencia_nome: string | null
  /** Preenchido pelo gatilho do banco quando a próxima ocorrência nasce. */
  proxima_ocorrencia_id: Uuid | null
  concluida_em: DataHora | null
}

/** Uma linha de `valor.colunas_kanban`. A coluna é configuração, não código. */
export interface ColunaDoQuadro {
  id: Uuid
  nome: string
  estado_gtd: EstadoGtd
  ordem: number
  cor: string | null
  limite_wip: number | null
}

/** Uma linha de `valor.contextos_gtd`. */
export interface ContextoGtd {
  id: Uuid
  codigo: string
  rotulo: string
  descricao: string | null
  ordem: number
}

// -------------------------------------------------------- linhas das visões

/** Uma linha de `valor.vw_negocios_forecast`. */
export interface LinhaNegocioForecast {
  negocio_id: Uuid
  titulo: string
  conta_id: Uuid
  conta_nome: string
  conta_tier: TierConta | null
  oferta_id: Uuid | null
  oferta_nome: string | null
  fase: Fase
  fase_rotulo: string
  rota: RotaNegocio
  origem: OrigemLead
  nivel_contrato: NivelContrato
  valor_total: Dinheiro | null
  valor_recorrente_mes: Dinheiro | null
  meses_recorrencia: number | null
  /** O valor que a visão usa nas somas. Pode vir zerado por máscara de coluna. */
  valor_considerado: Dinheiro | null

  categoria: ForecastCategoria
  /** O artefato validado com o cliente que sustenta a categoria. */
  artefato_que_sustenta: TipoArtefato | null
  artefato_validado_em: Data | null

  tem_proximo_passo: boolean
  decisao_no_futuro: boolean
  interacao_recente: boolean
  tem_artefato_da_fase: boolean
  /** Só as fases 1 a 4 respondem pelas quatro invariantes. */
  exige_higiene: boolean
  na_higiene: boolean | null
  quantas_invariantes_quebradas: number

  proximo_passo: string | null
  proximo_passo_data: Data | null
  proximo_passo_responsavel: Uuid | null
  proximo_passo_responsavel_nome: string | null
  data_decisao_cliente: Data | null
  dias_ate_decisao: number | null
  ultima_interacao: Data | null
  entrou_na_fase_em: Data
  dias_parado: number | null
  limite_dias: number | null
  esta_parado: boolean | null

  gerente_contas_id: Uuid | null
  gerente_contas_nome: string | null
  conselheiro_id: Uuid | null
  conselheiro_nome: string | null
  /** O conselheiro entra na Conexão de Valor, a fase 3, e segue até o fim. */
  conselheiro_entrou_na_fase: Fase | null
  parceiro_id: Uuid | null
  parceiro_nome: string | null
  papeis_ativos: number

  /** Leitura qualitativa do time, de `valor.negocios`. Nunca vira dinheiro. */
  probabilidade: Probabilidade | null
  descricao: string | null
  desfecho: DesfechoNegocio | null
}

/** A linha única de `valor.vw_pipeline_higiene`, com as duas somas lado a lado. */
export interface LinhaPipelineHigiene {
  negocios_declarados: number
  pipeline_declarado: Dinheiro | null
  negocios_auditados: number
  pipeline_auditado: Dinheiro | null
  negocios_travados: number
  valor_travado: Dinheiro | null
  percentual_negocios_auditados: number | null
  percentual_valor_auditado: number | null
  quebra_proximo_passo: number
  quebra_decisao_no_futuro: number
  quebra_interacao_recente: number
  quebra_artefato_da_fase: number
  travado_por_proximo_passo: Dinheiro | null
  travado_por_decisao_no_futuro: Dinheiro | null
  travado_por_interacao_recente: Dinheiro | null
  travado_por_artefato_da_fase: Dinheiro | null
}

/** Uma linha de `valor.vw_saude_da_conta`. */
export interface LinhaSaudeDaConta {
  conta_id: Uuid
  conta_nome: string
  setor: string | null
  cidade: string | null
  uf: string | null
  tier: TierConta | null
  tier_rotulo: string
  tier_sugerido: TierConta | null
  tier_confirmado_em: DataHora | null
  tier_diverge_da_sugestao: boolean
  prioridade: 1 | 2 | 3 | null
  power_of_x: number
  eh_cliente: boolean
  eh_prospecto: boolean
  gerente_contas_nome: string | null
  nps: number | null
  nps_respondentes: number | null
  nps_ultima_resposta: Data | null
  contratos_vigentes: number
  valor_mensal_vigente: Dinheiro | null
  proximo_vencimento_de_contrato: Data | null
  ultimo_contato_em: Data | null
  dias_sem_contato: number | null
  negocios_ativos: number
  pipeline_da_conta: Dinheiro | null
  alertas_abertos: number
  alertas_vermelhos: number
  turmas_ativas: number
  pendencias_vencidas: number
}

/** Uma linha de `valor.vw_contratos_em_curso`. */
export interface LinhaContratoEmCurso {
  contrato_id: Uuid
  numero: string
  titulo: string | null
  conta_id: Uuid
  conta_nome: string
  oferta_nome: string | null
  modalidade: ModalidadeOferta
  nivel: NivelContrato
  situacao: SituacaoContrato
  assinado: boolean
  assinado_em: Data | null
  vigencia_inicio: Data
  vigencia_fim: Data | null
  meses_vigencia: number | null
  valor_total: Dinheiro | null
  valor_mensal: Dinheiro | null
  renovacao_automatica: boolean
  dias_para_vencer: number | null
  na_janela_de_renovacao: boolean | null
  sinal_de_vencimento: SinalDeVencimento
  tem_negocio_de_renovacao: boolean
  negocio_renovacao_id: Uuid | null
}

/** Uma linha de `valor.vw_alertas_abertos`. */
export interface LinhaAlertaAberto {
  alerta_id: Uuid
  regra_nome: string | null
  criticidade: Criticidade
  criticidade_rotulo: string
  mensagem: string
  dias_aberto: number | null
  conta_id: Uuid | null
  negocio_id: Uuid | null
  negocio_titulo: string | null
  quem_age_nome: string | null
}

/** Uma linha de `valor.caixa_de_entrada`. */
export interface LinhaCaixaDeEntrada {
  atividade_id: Uuid
  titulo: string
  estado: EstadoGtd
  prazo: Data | null
  prioridade: 1 | 2 | 3 | null
  grupo: GrupoCaixaDeEntrada
  rotulo: string
  ordem_grupo: number
  dias: number | null
}

/** Uma linha de `valor.vw_agenda_da_semana`. */
export interface LinhaAgenda {
  tipo: TipoItemAgenda
  tipo_rotulo: string
  referencia_id: Uuid
  titulo: string
  quando_em: Data | null
  hora_inicio: string | null
  hora_fim: string | null
  local: string | null
  link: string | null
  status: string | null
  turma_id: Uuid | null
  turma_nome: string | null
  conta_id: Uuid | null
  conta_nome: string | null
  dias_ate: number | null
}

// ------------------------------------------------------------- agrupamentos
// O que cada tela consome de uma vez só.

export interface FichaDaConta {
  conta: LinhaConta
  contatos: LinhaContato[]
  negocios: LinhaNegocioForecast[]
  contratos: LinhaContratoEmCurso[]
  interacoes: LinhaInteracao[]
  saude: LinhaSaudeDaConta | null
  alertas: LinhaAlertaAberto[]
}

export interface FichaDoNegocio {
  negocio: LinhaNegocioForecast
  artefatos: LinhaArtefato[]
  papeis: LinhaPapelNegocio[]
  interacoes: LinhaInteracao[]
  rota_publica: LinhaRotaPublica | null
}

export interface QuadroDeAtividades {
  atividades: LinhaAtividade[]
  colunas: ColunaDoQuadro[]
  contextos: ContextoGtd[]
  caixa: LinhaCaixaDeEntrada[]
  /** Janela da caixa de entrada, em dias, lida de `valor.configuracoes`. */
  janela_dias: number
}

export interface PainelDeNegocios {
  negocios: LinhaNegocioForecast[]
  pipeline: LinhaPipelineHigiene | null
}

// ------------------------------------------------------------------ rótulos

export const ROTULO_ESTADO_GTD: Record<EstadoGtd, string> = {
  entrada: 'Entrada',
  proxima_acao: 'Próxima ação',
  aguardando: 'Aguardando',
  agendada: 'Agendada',
  algum_dia: 'Algum dia',
  concluida: 'Concluída',
  cancelada: 'Cancelada',
}

/** A ordem em que os estados do método GTD aparecem na tela. */
export const ORDEM_ESTADO_GTD: EstadoGtd[] = [
  'entrada',
  'proxima_acao',
  'agendada',
  'aguardando',
  'algum_dia',
  'concluida',
  'cancelada',
]

export const ROTULO_ENERGIA: Record<EnergiaAtividade, string> = {
  alta: 'Energia alta',
  media: 'Energia média',
  baixa: 'Energia baixa',
}

export const ROTULO_GRUPO_CAIXA: Record<GrupoCaixaDeEntrada, string> = {
  entrou_hoje: 'Caiu hoje',
  vencida: 'Venceu',
  vence_na_janela: 'Vence na janela',
  aguardando_terceiro: 'Aguardando terceiro',
}

export const EXPLICACAO_GRUPO_CAIXA: Record<GrupoCaixaDeEntrada, string> = {
  entrou_hoje: 'Entrou hoje e ainda não foi tratada.',
  vencida: 'O prazo já passou. É a fila que primeiro enche.',
  vence_na_janela: 'Vence dentro da janela configurada pela casa.',
  aguardando_terceiro: 'Está na mão de terceiro além da janela e pede cobrança.',
}

export const ROTULO_TIPO_AGENDA: Record<TipoItemAgenda, string> = {
  encontro: 'Encontro de turma',
  reuniao: 'Reunião de conselho',
  compromisso: 'Compromisso',
}

export const ROTULO_SITUACAO_CONTRATO: Record<SituacaoContrato, string> = {
  minuta: 'Minuta',
  pendente_assinatura: 'Aguardando assinatura',
  vigente: 'Vigente',
  pausado: 'Pausado',
  encerrado: 'Encerrado',
  cancelado: 'Cancelado',
  vencido: 'Vencido',
}

export const ROTULO_PRIORIDADE: Record<1 | 2 | 3, string> = {
  1: 'Prioridade 1',
  2: 'Prioridade 2',
  3: 'Prioridade 3',
}

/** As nove fases do funil, na ordem da seção 4 do contrato técnico. */
export const ORDEM_DAS_FASES: Fase[] = [0, 1, 2, 3, 4, 5, 6, 7, 9]

/** A trilha dos sete artefatos do método, na ordem em que nascem. */
export const TRILHA_DE_ARTEFATOS: TipoArtefato[] = [
  'plano_conta',
  'plano_negocio',
  'plano_trabalho',
  'contrato_valor',
  'entrega_valor',
  'monitoria_valor',
  'renovacao_valor',
]

/** O que fazer com cada invariante quebrada. Texto de tela, não de banco. */
export const PENDENCIA_INVARIANTE: Record<ChaveInvariante, string> = {
  proximo_passo_com_data:
    'Falta escrever o próximo passo, ou falta a data dele. Sem os dois, o negócio para e ninguém percebe.',
  data_decisao_no_futuro:
    'A data da decisão do cliente está em branco ou já passou. Combine uma data nova com o cliente, ou arquive o negócio.',
  interacao_em_30_dias:
    'Passou a janela de higiene sem conversa registrada. Registre a última conversa, ou marque uma nova.',
  artefato_da_fase_registrado:
    'Falta registrar o artefato que comprova a fase atual. Sem ele não existe critério de saída verificável.',
}

/** A frase que explica, em cada tela, de onde a categoria de forecast sai. */
export const AVISO_FORECAST =
  'A categoria de forecast sai do artefato validado com o cliente. Só artefato validado conta. Leitura qualitativa do time nunca vira previsão de receita.'

/** A frase que acompanha a etiqueta de leitura qualitativa. */
export const AVISO_PROBABILIDADE =
  'Leitura qualitativa do time sobre o negócio. Serve de conversa, nunca de conta: nenhuma tela multiplica esta leitura por valor.'

// ------------------------------------------------------------- utilidades

/** Converte o `smallint` do banco na fase do domínio, sem inventar valor. */
export function comoFase(numero: number | null | undefined): Fase {
  const inteira = Number(numero ?? 0)
  return (ORDEM_DAS_FASES.includes(inteira as Fase) ? inteira : 0) as Fase
}

/**
 * Dinheiro que pode não ter vindo. O banco decide quem enxerga valor, margem e
 * comissão. Quando a coluna volta nula, a tela diz que não veio, e jamais
 * escreve zero no lugar.
 */
export function dinheiroOuAusente(valor: number | null | undefined): string {
  if (valor === null || valor === undefined || Number.isNaN(Number(valor))) {
    return 'não informado'
  }
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(Number(valor))
}

/** Texto que pode não ter vindo. */
export function textoOuAusente(texto: string | null | undefined, ausente = 'não informado'): string {
  const limpo = (texto ?? '').trim()
  return limpo.length > 0 ? limpo : ausente
}

/** Tempo estimado em minutos, escrito como a casa fala. */
export function tempoEstimado(minutos: number | null | undefined): string {
  if (minutos === null || minutos === undefined || minutos <= 0) return 'sem estimativa'
  if (minutos < 60) return `${minutos} min`
  const horas = Math.floor(minutos / 60)
  const resto = minutos % 60
  return resto === 0 ? `${horas} h` : `${horas} h ${resto} min`
}

/** Hora do banco, no formato HH:MM, sem os segundos. */
export function hora(valor: string | null | undefined): string {
  if (!valor) return ''
  return valor.slice(0, 5)
}

/** Dia no formato AAAA-MM-DD, a partir de uma data do navegador. */
export function chaveDoDia(quando: Date): string {
  const ano = quando.getFullYear()
  const mes = `${quando.getMonth() + 1}`.padStart(2, '0')
  const dia = `${quando.getDate()}`.padStart(2, '0')
  return `${ano}-${mes}-${dia}`
}

/** A leitura das quatro invariantes de um negócio, já pronta para a tela. */
export interface LeituraInvariante {
  chave: ChaveInvariante
  cumpre: boolean
  pendencia: string
}

/**
 * As quatro invariantes de higiene de um negócio, na ordem da seção 6 do
 * contrato técnico. Fora das fases 1 a 4 a higiene não é exigida, e a tela
 * precisa dizer isso em vez de pintar tudo de vermelho.
 */
export function invariantesDoNegocio(linha: LinhaNegocioForecast): LeituraInvariante[] {
  const leitura: Array<[ChaveInvariante, boolean]> = [
    ['proximo_passo_com_data', linha.tem_proximo_passo],
    ['data_decisao_no_futuro', linha.decisao_no_futuro],
    ['interacao_em_30_dias', linha.interacao_recente],
    ['artefato_da_fase_registrado', linha.tem_artefato_da_fase],
  ]

  return leitura.map(([chave, cumpre]) => ({
    chave,
    cumpre,
    pendencia: PENDENCIA_INVARIANTE[chave],
  }))
}

/**
 * O sinal de higiene de um negócio, nas três cores da casa. Fora das fases
 * 1 a 4 devolve nulo, porque ali a higiene não é exigida.
 */
export function sinalDeHigiene(linha: LinhaNegocioForecast): Criticidade | null {
  if (!linha.exige_higiene) return null
  if (linha.na_higiene) return 'verde'
  return linha.quantas_invariantes_quebradas >= 2 ? 'vermelho' : 'amarelo'
}

/** O artefato que a fase atual exige, quando a fase exige algum. */
export function artefatoExigidoNaFase(fase: Fase): TipoArtefato | null {
  return ARTEFATO_DA_FASE[fase] ?? null
}

/** Como o tier chegou: confirmado por gente, ou apenas sugerido pelo sistema. */
export type OrigemDoTier = 'confirmado' | 'sugerido' | 'ausente'

export function origemDoTier(conta: {
  tier: TierConta | null
  tier_sugerido: TierConta | null
  tier_confirmado_em: DataHora | null
}): OrigemDoTier {
  if (conta.tier && conta.tier_confirmado_em) return 'confirmado'
  if (conta.tier || conta.tier_sugerido) return 'sugerido'
  return 'ausente'
}

export const ROTULO_ORIGEM_TIER: Record<OrigemDoTier, string> = {
  confirmado: 'Confirmado por gente',
  sugerido: 'Sugerido pelo sistema',
  ausente: 'Sem tier',
}

/** Situação da conta em uma palavra, do jeito que a lista mostra. */
export function situacaoDaConta(conta: { eh_cliente: boolean; eh_prospecto: boolean }): string {
  if (conta.eh_cliente && conta.eh_prospecto) return 'Cliente e prospecto'
  if (conta.eh_cliente) return 'Cliente'
  if (conta.eh_prospecto) return 'Prospecto'
  return 'Sem situação'
}
