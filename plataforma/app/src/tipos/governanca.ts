/**
 * Tipos do conselho e da governança.
 *
 * Espelho fiel das migrações do esquema `valor`:
 *   0008_brm_encontros_e_entregaveis.sql · valor.historico_valor
 *   0009_conselho_pautas_e_atas.sql      · modelo de ata, pauta, ata, pendência,
 *                                          banco de pautas e a função
 *                                          valor.montar_pre_pauta
 *   0010_nps_e_avaliacoes.sql            · pesquisa, questão, resposta,
 *                                          avaliação do conselheiro e ciclo
 *
 * Os nomes são exatamente os do banco, em snake_case sem acento, para que o
 * `select` do Supabase case sem tradução no meio do caminho. Os rótulos de
 * tela, com acento correto, ficam nos dicionários do fim do arquivo.
 *
 * Regra que atravessa este arquivo inteiro: a interface nunca esconde nada que
 * o banco tenha entregado, e nunca inventa o que o banco não entregou. Quem
 * decide quem vê avaliação de pessoa e ata restrita é a política de linha,
 * conforme as seções 8 e 9 do contrato técnico.
 */

import type { Carimbo, Data, DataHora, Dinheiro, DoInquilino, Uuid } from '@/tipos/dominio'

// ------------------------------------------------------------------ enums
// Repetem, na mesma ordem, os valores do `create type` das migrações 0009 e 0010.

export type AtaModeloTipo = 'padrao_sete_secoes' | 'extensao_dezesseis_blocos'

/** O assessor escreve, o conselheiro aprova, o sistema envia. */
export type AtaStatus = 'rascunho' | 'em_aprovacao' | 'aprovada' | 'enviada'

export type PendenciaStatus = 'aberta' | 'em_andamento' | 'concluida' | 'cancelada'

export type PendenciaOrigem =
  | 'deliberacao'
  | 'proximo_passo'
  | 'tarefa_do_conselheiro'
  | 'tarefa_do_assessor'
  | 'tarefa_do_cliente'

export type PautaStatus = 'rascunho' | 'publicada' | 'usada' | 'cancelada'

export type PautaItemTipo = 'deliberativo' | 'informativo' | 'consultivo'

export type PautaOrigem =
  | 'pendencia_aberta'
  | 'banco_de_pautas'
  | 'ritual_semanal'
  | 'pedido_do_cliente'
  | 'conselheiro'
  | 'assessor'

export type PautaFamilia = 'governanca' | 'gestao' | 'tendencias'

export type PesquisaTipo = 'nps_trimestral' | 'nota_conselheiro_semestral' | 'avulsa'

export type PesquisaStatus = 'rascunho' | 'agendada' | 'aberta' | 'fechada' | 'cancelada'

export type QuestaoTipo = 'nota_0_10' | 'escala' | 'texto_livre' | 'multipla_escolha'

export type QuestaoBloco =
  | 'recomendacao'
  | 'qualidade'
  | 'atendimento'
  | 'relacionamento_comercial'
  | 'entrega'
  | 'valor_percebido'
  | 'lealdade'
  | 'inovacao'

export type NpsFaixa = 'promotor' | 'neutro' | 'detrator'

/** Situação devolvida por `valor.alertas_ciclo_avaliacao`. */
export type SituacaoCiclo = 'vencido' | 'a vencer' | 'em dia'

/** Situação devolvida por `valor.pendencias_abertas` e pela pré-pauta. */
export type SituacaoPendencia = 'atrasada' | 'no prazo' | 'sem prazo definido'

// ---------------------------------------------------- as seções do modelo
// O padrão da casa tem sete seções, nesta ordem, em uso desde setembro de 2026.
// A extensão opcional de 16 blocos é ligada por cliente em
// `valor.modelos_ata_por_conta`.

export type ChaveSecaoAta =
  | 'identificacao'
  | 'participantes'
  | 'pauta'
  | 'resumo_discussoes'
  | 'deliberacoes'
  | 'proximos_passos'
  | 'proxima_reuniao'

export type ChaveBlocoExtensao =
  | ChaveSecaoAta
  | 'quorum_e_abertura'
  | 'aprovacao_ata_anterior'
  | 'contexto_e_cenario'
  | 'indicadores_do_periodo'
  | 'highlights'
  | 'lowlights'
  | 'riscos_e_mitigacoes'
  | 'metas_e_prioridades'
  | 'insight_conselho'

export interface SecaoModeloAta {
  chave: ChaveBlocoExtensao
  ordem: number
  rotulo: string
  obrigatoria: boolean
  /** Texto de apoio que a tela mostra debaixo do rótulo. */
  apoio?: string
}

/** O conteúdo da ata: uma chave por seção do modelo. */
export type ConteudoAta = Partial<Record<ChaveBlocoExtensao, string>>

// ------------------------------------------------- 0009 · tabelas do rito

export interface ModeloAta extends DoInquilino, Carimbo {
  id: Uuid
  codigo: string
  nome: string
  tipo: AtaModeloTipo
  versao: number
  estrutura: { secoes: SecaoModeloAta[] }
  quantidade_secoes: number
  padrao_da_casa: boolean
  vigente_desde: Data
  ativo: boolean
  observacao: string | null
}

export interface ModeloAtaPorConta extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  modelo_ata_id: Uuid
  usa_extensao: boolean
  extensao_modelo_id: Uuid | null
  vigente_desde: Data
  observacao: string | null
}

export interface BancoPauta extends DoInquilino, Carimbo {
  id: Uuid
  familia: PautaFamilia
  codigo: string
  tema: string
  descricao: string | null
  perguntas_orientadoras: string[]
  materiais: string[]
  tipo_sugerido: PautaItemTipo
  tempo_sugerido_minutos: number
  ordem: number
  ativo: boolean
}

export interface Pauta extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  turma_id: Uuid | null
  encontro_id: Uuid | null
  numero: number | null
  titulo: string
  data_reuniao: Data
  hora_inicio: string | null
  status: PautaStatus
  observacao: string | null
  publicada_em: DataHora | null
  enviada_em: DataHora | null
  gerada_com_ia: boolean
}

export interface PautaItem extends DoInquilino, Carimbo {
  id: Uuid
  pauta_id: Uuid
  ordem: number
  tema: string
  detalhe: string | null
  tipo: PautaItemTipo
  tempo_previsto_minutos: number
  responsavel_usuario_id: Uuid | null
  responsavel_nome: string | null
  origem: PautaOrigem
  pendencia_id: Uuid | null
  banco_pauta_id: Uuid | null
  /** Verdadeiro quando o item entrou sozinho, pela regra da pendência. */
  automatico: boolean
  tratado: boolean
}

export interface Ata extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  pauta_id: Uuid | null
  modelo_ata_id: Uuid | null
  turma_id: Uuid | null
  encontro_id: Uuid | null
  numero: number
  titulo: string | null
  data_reuniao: Data
  conteudo: ConteudoAta
  status: AtaStatus
  /**
   * CONFIDENCIAL. A reunião tratou de pessoas do cliente. Ata restrita não é
   * enviada, e a restrição de verificação do banco impede o contrário.
   */
  restrita: boolean
  ata_anterior_aprovada: boolean
  escrita_por: Uuid | null
  escrita_em: DataHora | null
  aprovada_por: Uuid | null
  aprovada_em: DataHora | null
  enviada_em: DataHora | null
  /** Vinte e quatro horas depois da reunião a ata precisa ter saído. */
  prazo_envio: DataHora
  destinatarios: string[]
  arquivo_pdf_url: string | null
  arquivo_docx_url: string | null
  gerada_com_ia: boolean
  proxima_data: Data | null
  pre_pauta: LinhaPrePauta[]
  /** CONFIDENCIAL: time interno. Não vai na ata enviada. */
  insight_conselho: string | null
}

export interface Pendencia extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  turma_id: Uuid | null
  encontro_id: Uuid | null
  ata_id: Uuid | null
  ata_secao: string | null
  origem: PendenciaOrigem
  descricao: string
  dono_usuario_id: Uuid | null
  /** Usado quando o dono é pessoa do cliente, sem usuário na plataforma. */
  dono_nome: string | null
  prazo: Data | null
  status: PendenciaStatus
  /** Padrão verdadeiro. A pendência reaparece na pré-pauta até fechar. */
  reaparece_na_pauta: boolean
  concluida_em: Data | null
  /** Uma pendência nunca some: ela fecha com evidência. */
  evidencia: string | null
}

// ---------------------------------------------- 0010 · pesquisa e avaliação

export interface Pesquisa extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid | null
  turma_id: Uuid | null
  programa_id: Uuid | null
  tipo: PesquisaTipo
  titulo: string
  /** Rótulo do ciclo, por exemplo 2026-T3 no trimestre e 2026-S2 no semestre. */
  periodo: string
  periodo_inicio: Data
  periodo_fim: Data
  publico_alvo: string
  status: PesquisaStatus
  abertura_em: DataHora | null
  encerrada_em: DataHora | null
  anonima: boolean
  observacao: string | null
}

export interface PesquisaQuestao extends DoInquilino, Carimbo {
  id: Uuid
  pesquisa_id: Uuid
  ordem: number
  bloco: QuestaoBloco
  tipo: QuestaoTipo
  enunciado: string
  ajuda: string | null
  obrigatoria: boolean
  escala_minimo: number | null
  escala_maximo: number | null
  opcoes: string[]
  /** A pergunta de recomendação de 0 a 10, a que calcula o NPS. */
  eh_pergunta_classica: boolean
}

export interface AvaliacaoConselheiro extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  conselheiro_usuario_id: Uuid
  pesquisa_id: Uuid | null
  periodo: string
  periodo_inicio: Data
  periodo_fim: Data
  /** CONFIDENCIAL. Avaliação de pessoa. Quem decide quem vê é o banco. */
  nota: number
  pontos_fortes: string | null
  criticas_construtivas: string | null
  comentario_livre: string | null
  respondida_em: DataHora
  liberada_para_avaliado: boolean
  liberada_em: DataHora | null
  devolutiva_do_lider: string | null
}

export interface CicloAvaliacao extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  tipo: PesquisaTipo
  periodicidade_meses: number
  ultima_aplicacao: Data | null
  proxima_aplicacao: Data
  responsavel_usuario_id: Uuid | null
  dias_de_antecedencia: number
  ativo: boolean
  observacao: string | null
}

// --------------------------------------- 0008 · Histórico de Valor

export interface HistoricoValor extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  programa_id: Uuid
  turma_id: Uuid | null
  encontro_id: Uuid | null
  entregavel_id: Uuid | null
  contrato_id: Uuid | null
  ano: number
  trimestre: number
  /** Trimestre em texto, por exemplo 2026-T3. */
  competencia: string
  data_referencia: Data
  entregue: string
  resultado: string
  evidencia: string
  valor_numero: Dinheiro | null
  valor_unidade: string | null
  arquivo_url: string | null
  registrado_por: Uuid | null
  confirmado_por_contato_id: Uuid | null
  confirmado_em: Data | null
  /** CONFIDENCIAL: equipe de entrega da casa. */
  observacao_interna: string | null
}

// ------------------------------------------------------- linhas de visão
// O que as visões e a função do banco devolvem prontas.

/** Uma linha de `valor.montar_pre_pauta(turma_id, data_referencia)`. */
export interface LinhaPrePauta {
  ordem_item: number
  /** `pendencia` primeiro, `tema_sugerido` depois. */
  bloco: 'pendencia' | 'tema_sugerido'
  tema: string
  detalhe: string | null
  dono: string | null
  prazo: Data | null
  situacao: string
  tempo_previsto_minutos: number
  tipo: PautaItemTipo
  pendencia_id: Uuid | null
  banco_pauta_id: Uuid | null
}

/** Uma linha de `valor.pendencias_abertas`. */
export interface LinhaPendenciaAberta {
  id: Uuid
  inquilino_id: Uuid
  conta_id: Uuid
  turma_id: Uuid | null
  ata_id: Uuid | null
  descricao: string
  dono: string | null
  prazo: Data | null
  status: PendenciaStatus
  situacao: string
  dias_de_atraso: number | null
}

/** Uma linha de `valor.atas_atrasadas`. */
export interface LinhaAtaAtrasada {
  id: Uuid
  numero: number
  data_reuniao: Data
  status: AtaStatus
  prazo_envio: DataHora
  restrita: boolean
  horas_de_atraso: number
  motivo: string
}

/** Uma linha de `valor.nps_por_conta`: a última nota de cada pessoa. */
export interface LinhaNpsPessoa {
  conta_id: Uuid
  respondente_chave: string
  respondente: string
  anonima: boolean
  /** A última nota desta pessoa. Nunca a média. */
  nota: number
  data_da_nota: Data
  faixa: NpsFaixa
  /** A motivação escrita da nota. CONFIDENCIAL: time interno da conta. */
  motivacao: string | null
  periodo: string
}

/** Uma linha de `valor.nps_consolidado_por_conta`. */
export interface ConsolidadoNps {
  conta_id: Uuid
  respondentes: number
  promotores: number
  neutros: number
  detratores: number
  /** Promotores menos detratores, sobre o total. Não é média de nota. */
  nps: number
  ultima_resposta: Data | null
}

/** Uma linha de `valor.alertas_ciclo_avaliacao`. */
export interface AlertaCiclo {
  id: Uuid
  conta_id: Uuid
  tipo: PesquisaTipo
  periodicidade_meses: number
  ultima_aplicacao: Data | null
  proxima_aplicacao: Data
  dias_para_o_ciclo: number
  situacao: SituacaoCiclo
}

/** Uma linha de `valor.vw_historico_valor_devido`. */
export interface HistoricoDevido {
  programa_id: Uuid
  programa_codigo: string
  programa_nome: string
  conta_id: Uuid
  ano: number
  trimestre: number
}

// -------------------------------------------------- montagens para a tela
// Não são tabelas. São o que cada tela consome de uma vez só.

/** Conta, com o nome já resolvido, do jeito que a lista precisa. */
export interface ContaResumida {
  id: Uuid
  nome: string
}

/** Uma ata da lista, com o nome da conta e o passo do fluxo já calculado. */
export interface AtaNaLista extends Ata {
  conta_nome: string
  turma_nome: string | null
  escrita_por_nome: string | null
  aprovada_por_nome: string | null
}

/** Uma pendência da lista, com conta, turma e ata de origem por extenso. */
export interface PendenciaNaLista extends Pendencia {
  conta_nome: string
  turma_nome: string | null
  ata_numero: number | null
  dono: string
}

export interface ItemPautaNaTela extends PautaItem {
  responsavel: string | null
}

/** O que a tela da pauta consome. */
export interface PautaMontada {
  pauta: Pauta
  conta_nome: string
  turma_nome: string | null
  itens: ItemPautaNaTela[]
  /** Vem de `valor.montar_pre_pauta`: pendências primeiro, temas depois. */
  pre_pauta: LinhaPrePauta[]
  banco: BancoPauta[]
}

/** O que a tela de pesquisas consome, por conta. */
export interface PainelNps {
  conta: ContaResumida
  pesquisa: Pesquisa | null
  questoes: PesquisaQuestao[]
  pessoas: LinhaNpsPessoa[]
  consolidado: ConsolidadoNps
  ciclos: AlertaCiclo[]
  /** Vazio quando o banco não entregou avaliação de pessoa. */
  avaliacoes: AvaliacaoConselheiro[]
}

/** O que a tela de Histórico de Valor consome, por conta. */
export interface HistoricoDaConta {
  conta: ContaResumida
  registros: HistoricoValor[]
  devidos: HistoricoDevido[]
}

// ---------------------------------------------------------- rótulos de tela
// O banco fala em snake_case sem acento. A tela fala português do Brasil.

export const ROTULO_ATA_STATUS: Record<AtaStatus, string> = {
  rascunho: 'Rascunho do assessor',
  em_aprovacao: 'Em aprovação do conselheiro',
  aprovada: 'Aprovada, à espera do envio',
  enviada: 'Enviada ao cliente',
}

export const ROTULO_ATA_MODELO: Record<AtaModeloTipo, string> = {
  padrao_sete_secoes: 'Padrão de sete seções',
  extensao_dezesseis_blocos: 'Extensão de 16 blocos',
}

export const ROTULO_PENDENCIA_STATUS: Record<PendenciaStatus, string> = {
  aberta: 'Aberta',
  em_andamento: 'Em andamento',
  concluida: 'Concluída com evidência',
  cancelada: 'Cancelada',
}

export const ROTULO_PENDENCIA_ORIGEM: Record<PendenciaOrigem, string> = {
  deliberacao: 'Deliberação da ata',
  proximo_passo: 'Próximo passo da ata',
  tarefa_do_conselheiro: 'Tarefa do conselheiro',
  tarefa_do_assessor: 'Tarefa do assessor',
  tarefa_do_cliente: 'Tarefa do cliente',
}

export const ROTULO_PAUTA_STATUS: Record<PautaStatus, string> = {
  rascunho: 'Rascunho',
  publicada: 'Publicada',
  usada: 'Usada na reunião',
  cancelada: 'Cancelada',
}

export const ROTULO_PAUTA_TIPO: Record<PautaItemTipo, string> = {
  deliberativo: 'Deliberativo',
  informativo: 'Informativo',
  consultivo: 'Consultivo',
}

export const ROTULO_PAUTA_ORIGEM: Record<PautaOrigem, string> = {
  pendencia_aberta: 'Pendência em aberto',
  banco_de_pautas: 'Banco de pautas',
  ritual_semanal: 'Ritual semanal da turma',
  pedido_do_cliente: 'Solicitação do cliente',
  conselheiro: 'Conselheiro',
  assessor: 'Assessor executivo',
}

export const ROTULO_PAUTA_FAMILIA: Record<PautaFamilia, string> = {
  governanca: 'Temas de governança',
  gestao: 'Famílias de gestão do método',
  tendencias: 'Tendências',
}

export const ROTULO_PESQUISA_TIPO: Record<PesquisaTipo, string> = {
  nps_trimestral: 'NPS trimestral',
  nota_conselheiro_semestral: 'Nota do conselheiro, semestral',
  avulsa: 'Pesquisa avulsa',
}

export const ROTULO_PESQUISA_STATUS: Record<PesquisaStatus, string> = {
  rascunho: 'Rascunho',
  agendada: 'Agendada',
  aberta: 'Aberta para resposta',
  fechada: 'Encerrada',
  cancelada: 'Cancelada',
}

export const ROTULO_QUESTAO_BLOCO: Record<QuestaoBloco, string> = {
  recomendacao: 'Recomendação',
  qualidade: 'Qualidade',
  atendimento: 'Atendimento',
  relacionamento_comercial: 'Relacionamento comercial',
  entrega: 'Entrega',
  valor_percebido: 'Valor percebido',
  lealdade: 'Lealdade',
  inovacao: 'Inovação',
}

export const ROTULO_QUESTAO_TIPO: Record<QuestaoTipo, string> = {
  nota_0_10: 'Nota de 0 a 10',
  escala: 'Escala',
  texto_livre: 'Texto livre',
  multipla_escolha: 'Múltipla escolha',
}

export const ROTULO_NPS_FAIXA: Record<NpsFaixa, string> = {
  promotor: 'Promotor',
  neutro: 'Neutro',
  detrator: 'Detrator',
}

export const CRITERIO_NPS_FAIXA: Record<NpsFaixa, string> = {
  promotor: 'Última nota 9 ou 10.',
  neutro: 'Última nota 7 ou 8.',
  detrator: 'Última nota de 0 a 6.',
}

export const ROTULO_SITUACAO_CICLO: Record<SituacaoCiclo, string> = {
  vencido: 'Ciclo vencido',
  'a vencer': 'Ciclo a vencer',
  'em dia': 'Ciclo em dia',
}

// ------------------------------------------------------- o modelo da casa
// As sete seções em uso desde setembro de 2026, na ordem, como estão semeadas
// em `valor.semear_modelos_ata`.

export const SECOES_PADRAO: SecaoModeloAta[] = [
  {
    chave: 'identificacao',
    ordem: 1,
    rotulo: 'Identificação',
    obrigatoria: true,
    apoio: 'Conta, turma, número da ata, data, hora e local da reunião.',
  },
  {
    chave: 'participantes',
    ordem: 2,
    rotulo: 'Participantes',
    obrigatoria: true,
    apoio: 'Quem esteve presente, quem faltou e quem justificou.',
  },
  {
    chave: 'pauta',
    ordem: 3,
    rotulo: 'Pauta',
    obrigatoria: true,
    apoio: 'Os itens tratados, na ordem em que foram tratados.',
  },
  {
    chave: 'resumo_discussoes',
    ordem: 4,
    rotulo: 'Resumo das discussões',
    obrigatoria: true,
    apoio: 'O que foi debatido em cada item, com os argumentos que pesaram.',
  },
  {
    chave: 'deliberacoes',
    ordem: 5,
    rotulo: 'Deliberações',
    obrigatoria: true,
    apoio: 'O que o conselho decidiu. Cada decisão com dono e prazo.',
  },
  {
    chave: 'proximos_passos',
    ordem: 6,
    rotulo: 'Próximos passos',
    obrigatoria: true,
    apoio: 'O que vira pendência, com dono e prazo. Cada linha daqui cobra até fechar.',
  },
  {
    chave: 'proxima_reuniao',
    ordem: 7,
    rotulo: 'Próxima reunião com pré-pauta',
    obrigatoria: true,
    apoio: 'A data combinada e a pré-pauta que já nasce das pendências em aberto.',
  },
]

/** A extensão opcional, ligada por cliente. Os 16 blocos na ordem do banco. */
export const SECOES_EXTENSAO: SecaoModeloAta[] = [
  { chave: 'identificacao', ordem: 1, rotulo: 'Identificação', obrigatoria: true },
  { chave: 'participantes', ordem: 2, rotulo: 'Participantes', obrigatoria: true },
  { chave: 'quorum_e_abertura', ordem: 3, rotulo: 'Quórum e abertura', obrigatoria: true },
  { chave: 'aprovacao_ata_anterior', ordem: 4, rotulo: 'Aprovação da ata anterior', obrigatoria: true },
  { chave: 'pauta', ordem: 5, rotulo: 'Pauta', obrigatoria: true },
  { chave: 'contexto_e_cenario', ordem: 6, rotulo: 'Contexto e cenário', obrigatoria: false },
  { chave: 'indicadores_do_periodo', ordem: 7, rotulo: 'Indicadores do período', obrigatoria: false },
  { chave: 'highlights', ordem: 8, rotulo: 'Highlights', obrigatoria: false },
  { chave: 'lowlights', ordem: 9, rotulo: 'Lowlights', obrigatoria: false },
  { chave: 'resumo_discussoes', ordem: 10, rotulo: 'Resumo das discussões', obrigatoria: true },
  { chave: 'deliberacoes', ordem: 11, rotulo: 'Deliberações', obrigatoria: true },
  { chave: 'riscos_e_mitigacoes', ordem: 12, rotulo: 'Riscos e mitigações', obrigatoria: false },
  { chave: 'metas_e_prioridades', ordem: 13, rotulo: 'Metas e prioridades', obrigatoria: false },
  { chave: 'proximos_passos', ordem: 14, rotulo: 'Próximos passos', obrigatoria: true },
  { chave: 'insight_conselho', ordem: 15, rotulo: 'Insight do conselho', obrigatoria: false },
  { chave: 'proxima_reuniao', ordem: 16, rotulo: 'Próxima reunião com pré-pauta', obrigatoria: true },
]

// ----------------------------------------------------- leituras do fluxo

/** Os três passos do rito, na ordem. */
export const PASSOS_DO_FLUXO: Array<{ chave: AtaStatus; rotulo: string; quem: string }> = [
  { chave: 'rascunho', rotulo: 'O assessor escreve', quem: 'Assessor executivo' },
  { chave: 'em_aprovacao', rotulo: 'O conselheiro aprova', quem: 'Conselheiro' },
  { chave: 'aprovada', rotulo: 'O sistema envia', quem: 'Sistema, em até 24 horas' },
]

/** Em que passo a ata está, contado a partir de 0. Enviada devolve 3. */
export function passoDaAta(status: AtaStatus): number {
  switch (status) {
    case 'rascunho':
      return 0
    case 'em_aprovacao':
      return 1
    case 'aprovada':
      return 2
    case 'enviada':
      return 3
    default:
      return 0
  }
}

/** Quem a ata está esperando agora. */
export function quemFalta(ata: Pick<Ata, 'status' | 'restrita'>): string {
  if (ata.restrita) {
    return 'Ninguém envia: a ata é restrita e não sai da casa.'
  }
  switch (ata.status) {
    case 'rascunho':
      return 'Falta o assessor fechar o rascunho e mandar para aprovação.'
    case 'em_aprovacao':
      return 'Falta o conselheiro aprovar.'
    case 'aprovada':
      return 'Falta o envio ao cliente.'
    case 'enviada':
      return 'Nada falta. A ata já saiu.'
    default:
      return 'Passo do fluxo não reconhecido.'
  }
}

/**
 * Horas passadas do prazo de envio. Zero quando ainda está dentro do prazo.
 * O rito manda a ata sair em 24 horas depois da reunião.
 */
export function horasDeAtraso(prazo_envio: DataHora, agora: Date = new Date()): number {
  const prazo = new Date(prazo_envio).getTime()
  if (Number.isNaN(prazo)) return 0
  const diferenca = (agora.getTime() - prazo) / 3_600_000
  return diferenca > 0 ? Math.round(diferenca * 10) / 10 : 0
}

/** Verdadeiro quando a ata passou das 24 horas sem sair. */
export function ataAtrasada(ata: Pick<Ata, 'status' | 'prazo_envio'>, agora: Date = new Date()): boolean {
  return ata.status !== 'enviada' && horasDeAtraso(ata.prazo_envio, agora) > 0
}

/** A faixa de NPS de uma nota, com o mesmo corte da visão do banco. */
export function faixaDaNota(nota: number): NpsFaixa {
  if (nota >= 9) return 'promotor'
  if (nota >= 7) return 'neutro'
  return 'detrator'
}

/** Situação de uma pendência diante da data de referência. */
export function situacaoDaPendencia(
  prazo: Data | null,
  referencia: Data,
): SituacaoPendencia {
  if (!prazo) return 'sem prazo definido'
  return prazo < referencia ? 'atrasada' : 'no prazo'
}
