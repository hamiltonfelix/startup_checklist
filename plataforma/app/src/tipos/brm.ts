/**
 * Tipos do BRM de Valor, a entrega do conselheiro.
 *
 * Espelho fiel das migrações do esquema `valor`:
 *   0007_brm_programas_e_turmas.sql    · programa, turma, conta na turma e participante
 *   0008_brm_encontros_e_entregaveis.sql · encontro, presença, ritual semanal,
 *                                          entregável e Histórico de Valor
 *   0015_views_paineis.sql             · o painel do conselheiro
 *
 * Os nomes de campo são exatamente os do banco, em snake_case sem acento, para
 * que o `select` do Supabase case sem tradução no meio do caminho. Os rótulos
 * de tela, com acento correto, vivem nos dicionários do fim deste arquivo.
 */

import type { Data, DataHora, Dinheiro, Uuid } from '@/tipos/dominio'

// ------------------------------------------------------------------- enums
// Cada tipo abaixo repete, na mesma ordem, os valores do `create type` da 0007
// e da 0008.

export type BrmModalidadeTurma = 'dedicada' | 'compartilhada'

export type BrmStatusPrograma = 'planejado' | 'ativo' | 'suspenso' | 'concluido' | 'cancelado'

export type BrmStatusTurma =
  | 'planejada'
  | 'em_andamento'
  | 'suspensa'
  | 'concluida'
  | 'cancelada'

export type BrmCadencia =
  | 'semanal'
  | 'quinzenal'
  | 'mensal'
  | 'bimestral'
  | 'trimestral'
  | 'modular'
  | 'imersao'
  | 'sob_demanda'

export type BrmFormatoEncontro = 'presencial' | 'online' | 'hibrido'

export type BrmPapelParticipante = 'membro' | 'socio' | 'executivo' | 'convidado' | 'observador'

export type BrmStatusParticipante = 'ativo' | 'pausado' | 'concluido' | 'desligado'

export type BrmStatusEncontro = 'previsto' | 'realizado' | 'remarcado' | 'cancelado'

export type BrmSituacaoPresenca = 'presente' | 'ausente_justificado' | 'ausente'

export type BrmTipoItemRitual = 'highlight' | 'lowlight' | 'meta' | 'prioridade'

export type BrmTipoEntregavel =
  | 'ata'
  | 'pre_pauta'
  | 'resumo_semanal'
  | 'plano_de_conta'
  | 'plano_de_negocio'
  | 'plano_de_trabalho'
  | 'plano_de_acao'
  | 'plano_de_desenvolvimento'
  | 'diagnostico'
  | 'relatorio'
  | 'material_de_apoio'
  | 'certificado'
  | 'outro'

export type BrmStatusEntregavel = 'rascunho' | 'entregue' | 'aprovado'

// --------------------------------------------------------- 0007 · programas

/** A instância vendida de uma oferta, para um ano e uma modalidade. */
export interface Programa {
  id: Uuid
  inquilino_id: Uuid
  oferta_id: Uuid | null
  contrato_id: Uuid | null
  negocio_id: Uuid | null
  conta_id: Uuid | null
  codigo: string
  nome: string
  ano: number
  modalidade: BrmModalidadeTurma
  status: BrmStatusPrograma
  responsavel_id: Uuid | null
  data_inicio: Data | null
  data_fim: Data | null
  // A carga oficial da oferta, como está no catálogo da casa.
  cadencia: BrmCadencia
  encontros_previstos: number | null
  duracao_encontro_minutos: number | null
  semanas_sustentacao: number | null
  dias_imersao: number | null
  modulos_previstos: number | null
  temas_previstos: number | null
  etapas_previstas: number | null
  meses_duracao: number | null
  presenciais_por_mes: number
  estacoes_plano: number | null
  encontro_gestao_semanal: boolean
  pauta_prioritaria_mensal: boolean
  hotseat_por_membro: boolean
  resumo_semanal: boolean
  deep_dive_mensal: boolean
  plano_por_participante: boolean
  certificacao: boolean
  /** Marcos do índice próprio do programa, por exemplo T0, T90 e T180. */
  marcos_indice: string[]
  /** Sobras da carga oficial que não têm coluna própria. */
  carga_extra: Record<string, unknown>
  /** CONFIDENCIAL: equipe de entrega da casa. */
  observacoes: string | null
  criado_em: DataHora
  arquivado_em: DataHora | null
}

/** Um programa com os nomes que a lista precisa mostrar já resolvidos. */
export interface ProgramaNaLista extends Programa {
  oferta_nome: string
  oferta_codigo: string | null
  conta_nome: string | null
  responsavel_nome: string
  /** Turmas vivas deste programa. */
  turmas: number
  /** Cadeiras ocupadas somadas em todas as turmas do programa. */
  cadeiras_ocupadas: number
}

// ------------------------------------------------------------ 0007 · turmas

export interface Turma {
  id: Uuid
  inquilino_id: Uuid
  programa_id: Uuid
  contrato_id: Uuid | null
  negocio_id: Uuid | null
  codigo: string
  nome: string | null
  cadeiras_minimas: number
  cadeiras_maximas: number
  data_inicio: Data | null
  data_fim: Data | null
  status: BrmStatusTurma
  cadencia: BrmCadencia
  formato: BrmFormatoEncontro
  dia_semana: number | null
  horario_inicio: string | null
  horario_fim: string | null
  encontros_previstos: number | null
  /** No conselho é meados de dezembro. O ano da data é ignorado na comparação. */
  recesso_inicio: Data | null
  /** No conselho é meados de janeiro. O ano da data é ignorado na comparação. */
  recesso_fim: Data | null
  /** Datas previstas, já saltando o recesso, como faz `valor.brm_calendario_turma`. */
  calendario_base: Data[]
  facilitador_id: Uuid | null
  coordenador_id: Uuid | null
  /** CONFIDENCIAL: equipe de entrega da casa. */
  observacoes: string | null
  criado_em: DataHora
  arquivado_em: DataHora | null
}

/** Uma conta presente na turma, com as cadeiras que contratou. */
export interface TurmaConta {
  id: Uuid
  turma_id: Uuid
  conta_id: Uuid
  conta_nome: string
  cadeiras_contratadas: number
  eh_anfitria: boolean
  entrou_em: Data
  saiu_em: Data | null
}

/** A turma com o que a lista e a ficha precisam mostrar já resolvido. */
export interface TurmaNaLista extends Turma {
  programa_nome: string
  programa_codigo: string
  oferta_nome: string
  modalidade: BrmModalidadeTurma
  facilitador_nome: string
  coordenador_nome: string
  /** As contas da turma. Na compartilhada são várias, de mercados diferentes. */
  contas: TurmaConta[]
  /** Participantes vivos, ou seja, cadeiras ocupadas de verdade. */
  cadeiras_ocupadas: number
  encontros_realizados: number
  encontros_restantes: number
}

// ---------------------------------------------------- 0007 · participantes

export interface Participante {
  id: Uuid
  inquilino_id: Uuid
  turma_id: Uuid
  conta_id: Uuid | null
  contato_id: Uuid | null
  usuario_id: Uuid | null
  nome: string | null
  papel: BrmPapelParticipante
  cadeira: number | null
  entrou_em: Data
  saiu_em: Data | null
  motivo_saida: string | null
  status: BrmStatusParticipante
  encontros_convocados: number
  encontros_presentes: number
  /** `numeric(6,4)` gerado no banco. Chega entre 0 e 1, ou nulo. */
  presenca_percentual: number | null
  indices: Record<string, unknown>
  certificado_em: Data | null
  certificado_url: string | null
  /** CONFIDENCIAL: equipe de entrega da casa. */
  observacoes: string | null
  arquivado_em: DataHora | null
}

/**
 * O participante com a conta dele já resolvida.
 *
 * A conta é obrigatória na tela porque num conselho compartilhado sentam
 * empresários de mercados distintos, e saber de quem é cada cadeira é o
 * primeiro dado que o conselheiro procura.
 */
export interface ParticipanteNaFicha extends Participante {
  conta_nome: string
  nome_exibido: string
}

// ---------------------------------------------------------- 0008 · encontros

export interface Encontro {
  id: Uuid
  inquilino_id: Uuid
  turma_id: Uuid
  /** Posição na sequência oficial. A remarcação preserva este número. */
  numero: number
  /** A primeira marcação é 1. Cada remarcação soma um. */
  tentativa: number
  tema: string
  pauta: string[]
  data_prevista: Data
  hora_prevista_inicio: string | null
  hora_prevista_fim: string | null
  /** A data da primeira marcação deste número. Nunca é reescrita. */
  data_prevista_original: Data | null
  data_realizada: Data | null
  hora_realizada_inicio: string | null
  hora_realizada_fim: string | null
  formato: BrmFormatoEncontro
  local: string | null
  link: string | null
  status: BrmStatusEncontro
  conselheiro_id: Uuid | null
  assessor_id: Uuid | null
  /** CONFIDENCIAL: equipe de entrega e participantes da própria turma. */
  gravacao_url: string | null
  /** CONFIDENCIAL: equipe de entrega da casa. */
  transcricao_url: string | null
  /** CONFIDENCIAL: equipe de entrega da casa. */
  transcricao_texto: string | null
  /** O encontro que esta linha substitui. Quem tem isto preenchido é a remarcação. */
  remarcado_de: Uuid | null
  remarcado_para: Uuid | null
  motivo_remarcacao: string | null
  eh_presencial_do_mes: boolean
  eh_pauta_prioritaria: boolean
  eh_encontro_de_gestao: boolean
  eh_hotseat: boolean
  hotseat_participante_id: Uuid | null
  /** Encontro sobre pessoas do cliente. O banco decide quem recebe a linha. */
  restrito: boolean
  /** CONFIDENCIAL: equipe de entrega da casa. */
  observacoes_restritas: string | null
  arquivado_em: DataHora | null
}

export interface EncontroNaLista extends Encontro {
  turma_codigo: string
  programa_nome: string
  conselheiro_nome: string
  assessor_nome: string
  /** Quantos entregáveis este encontro gerou. */
  entregaveis: number
}

// ----------------------------------------------------------- 0008 · presença

export interface Presenca {
  id: Uuid
  encontro_id: Uuid
  participante_id: Uuid
  situacao: BrmSituacaoPresenca
  minutos_presentes: number | null
  /** CONFIDENCIAL: equipe de entrega da casa e o próprio participante. */
  justificativa: string | null
  /** CONFIDENCIAL: equipe de entrega da casa. */
  observacao: string | null
  arquivado_em: DataHora | null
}

/** A presença já casada com quem é a pessoa e de que conta ela vem. */
export interface PresencaNaFicha extends Presenca {
  participante_nome: string
  conta_nome: string
  cadeira: number | null
}

// ---------------------------------------------------- 0008 · ritual semanal

/**
 * O ritual semanal da turma, nos quatro tipos do template do Conselho de
 * Valor: Highlights, Lowlights, Metas e Prioridades. Todo item tem tópico,
 * responsável e data.
 */
export interface ItemRitualSemanal {
  id: Uuid
  encontro_id: Uuid
  turma_id: Uuid
  conta_id: Uuid | null
  tipo: BrmTipoItemRitual
  ordem: number
  topico: string
  /** CONFIDENCIAL: equipe de entrega da casa e a própria turma. */
  detalhe: string | null
  responsavel_usuario_id: Uuid | null
  responsavel_participante_id: Uuid | null
  responsavel_nome: string | null
  data_alvo: Data
  concluido_em: Data | null
  evidencia: string | null
  arquivado_em: DataHora | null
}

/** O item do ritual com o nome do responsável já resolvido. */
export interface ItemRitualNaFicha extends ItemRitualSemanal {
  responsavel_exibido: string
}

// -------------------------------------------------------- 0008 · entregáveis

export interface Entregavel {
  id: Uuid
  turma_id: Uuid
  encontro_id: Uuid | null
  participante_id: Uuid | null
  conta_id: Uuid | null
  tipo: BrmTipoEntregavel
  tipo_detalhe: string | null
  titulo: string
  descricao: string | null
  arquivo_url: string | null
  versao: number
  prazo: Data | null
  data_entrega: Data | null
  produzido_por_usuario_id: Uuid | null
  produzido_por_participante_id: Uuid | null
  produzido_por_nome: string | null
  status: BrmStatusEntregavel
  /** A marca que decide o que o participante enxerga no portal dele. */
  visivel_ao_cliente: boolean
  aprovado_em: Data | null
  aprovado_por: Uuid | null
  arquivado_em: DataHora | null
}

export interface EntregavelNaLista extends Entregavel {
  turma_codigo: string
  conta_nome: string | null
  encontro_numero: number | null
  produzido_por_exibido: string
}

// ------------------------------------------------- 0008 · Histórico de Valor

/** O registro obrigatório por trimestre, por conta e por programa. */
export interface RegistroHistoricoValor {
  id: Uuid
  conta_id: Uuid
  programa_id: Uuid
  turma_id: Uuid | null
  ano: number
  trimestre: number
  /** `ano`, traço, letra T e número. Gerado no banco, por exemplo 2026-T3. */
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
  arquivado_em: DataHora | null
}

export interface RegistroHistoricoNaFicha extends RegistroHistoricoValor {
  conta_nome: string
  registrado_por_nome: string
}

/** Uma linha de `valor.vw_historico_valor_devido`, a fila de cobrança. */
export interface HistoricoValorDevido {
  programa_id: Uuid
  programa_codigo: string
  programa_nome: string
  responsavel_id: Uuid | null
  conta_id: Uuid
  conta_nome: string
  ano: number
  trimestre: number
}

// ------------------------------------------- leitura derivada do calendário

/** Um dia do calendário base da turma, ou o recesso que vem antes dele. */
export interface DiaDoCalendario {
  /** Posição na sequência oficial, contada a partir de 1. */
  numero: number
  data: Data
  /** Verdadeiro quando o encontro já saiu do calendário e virou linha própria. */
  temEncontro: boolean
  encontro_id: Uuid | null
  status: BrmStatusEncontro | null
  tema: string | null
  /**
   * Preenchido quando a data anterior e esta estão separadas pelo recesso.
   * O salto é a regra do conselho, não defeito de dado.
   */
  saltoDeRecesso: { inicio: Data; fim: Data; semanas: number } | null
}

/** Uma linha da carga oficial do programa, pronta para a tela. */
export interface ItemDaEstrutura {
  chave: string
  rotulo: string
  valor: string
}

// ------------------------------------------------------------------ rótulos
// O banco fala snake_case sem acento. A tela fala português do Brasil.

export const ROTULO_MODALIDADE_TURMA: Record<BrmModalidadeTurma, string> = {
  dedicada: 'Dedicada',
  compartilhada: 'Compartilhada',
}

/** O que cada modalidade significa na prática da entrega. */
export const EXPLICACAO_MODALIDADE: Record<BrmModalidadeTurma, string> = {
  dedicada: 'Uma única conta na turma inteira.',
  compartilhada: 'Contas diferentes na mesma turma, de mercados distintos.',
}

export const ROTULO_STATUS_PROGRAMA: Record<BrmStatusPrograma, string> = {
  planejado: 'Planejado',
  ativo: 'Ativo',
  suspenso: 'Suspenso',
  concluido: 'Concluído',
  cancelado: 'Cancelado',
}

export const ROTULO_STATUS_TURMA: Record<BrmStatusTurma, string> = {
  planejada: 'Planejada',
  em_andamento: 'Em andamento',
  suspensa: 'Suspensa',
  concluida: 'Concluída',
  cancelada: 'Cancelada',
}

export const ROTULO_CADENCIA: Record<BrmCadencia, string> = {
  semanal: 'Semanal',
  quinzenal: 'Quinzenal',
  mensal: 'Mensal',
  bimestral: 'Bimestral',
  trimestral: 'Trimestral',
  modular: 'Modular',
  imersao: 'Imersão',
  sob_demanda: 'Sob demanda',
}

export const ROTULO_FORMATO: Record<BrmFormatoEncontro, string> = {
  presencial: 'Presencial',
  online: 'On-line',
  hibrido: 'Híbrido',
}

export const ROTULO_PAPEL_PARTICIPANTE: Record<BrmPapelParticipante, string> = {
  membro: 'Membro',
  socio: 'Sócio',
  executivo: 'Executivo',
  convidado: 'Convidado',
  observador: 'Observador',
}

export const ROTULO_STATUS_PARTICIPANTE: Record<BrmStatusParticipante, string> = {
  ativo: 'Ativo',
  pausado: 'Pausado',
  concluido: 'Concluído',
  desligado: 'Desligado',
}

export const ROTULO_STATUS_ENCONTRO: Record<BrmStatusEncontro, string> = {
  previsto: 'Previsto',
  realizado: 'Realizado',
  remarcado: 'Remarcado',
  cancelado: 'Cancelado',
}

export const ROTULO_PRESENCA: Record<BrmSituacaoPresenca, string> = {
  presente: 'Presente',
  ausente_justificado: 'Ausência justificada',
  ausente: 'Ausente',
}

/** Os quatro tipos do ritual semanal, com o nome que a turma usa. */
export const ROTULO_ITEM_RITUAL: Record<BrmTipoItemRitual, string> = {
  highlight: 'Highlights',
  lowlight: 'Lowlights',
  meta: 'Metas',
  prioridade: 'Prioridades',
}

export const EXPLICACAO_ITEM_RITUAL: Record<BrmTipoItemRitual, string> = {
  highlight: 'O que andou bem desde o encontro anterior.',
  lowlight: 'O que travou e precisa de decisão.',
  meta: 'O número que a turma persegue, com data.',
  prioridade: 'O que entra primeiro na semana que começa.',
}

export const ROTULO_TIPO_ENTREGAVEL: Record<BrmTipoEntregavel, string> = {
  ata: 'Ata',
  pre_pauta: 'Pré-pauta',
  resumo_semanal: 'Resumo semanal',
  plano_de_conta: 'Plano de Conta',
  plano_de_negocio: 'Plano de Negócio',
  plano_de_trabalho: 'Plano de Trabalho',
  plano_de_acao: 'Plano de ação',
  plano_de_desenvolvimento: 'Plano de desenvolvimento',
  diagnostico: 'Diagnóstico',
  relatorio: 'Relatório',
  material_de_apoio: 'Material de apoio',
  certificado: 'Certificado',
  outro: 'Outro',
}

export const ROTULO_STATUS_ENTREGAVEL: Record<BrmStatusEntregavel, string> = {
  rascunho: 'Rascunho',
  entregue: 'Entregue',
  aprovado: 'Aprovado',
}

/** Só duas opções, e as duas com nome inteiro, para o filtro não ficar mudo. */
export const ROTULO_VISIBILIDADE: Record<'sim' | 'nao', string> = {
  sim: 'Visível ao cliente',
  nao: 'Só dentro de casa',
}

// ------------------------------------------------------------ formatadores

/** Minutos vindos do banco escritos como a casa fala: 2h30, 2h, 45min. */
export function duracao(minutos: number | null | undefined): string {
  if (minutos === null || minutos === undefined || minutos <= 0) return 'sem duração'
  const horas = Math.floor(minutos / 60)
  const resto = minutos % 60
  if (horas === 0) return `${resto}min`
  if (resto === 0) return `${horas}h`
  return `${horas}h${String(resto).padStart(2, '0')}`
}

/** `presenca_percentual` chega entre 0 e 1. A tela mostra inteiro por cento. */
export function presencaEmPorCento(valor: number | null | undefined): string {
  if (valor === null || valor === undefined || Number.isNaN(valor)) return 'sem registro'
  return `${Math.round(valor * 100)} por cento`
}

/** O trimestre escrito como o banco gera a competência, por exemplo 2026-T3. */
export function competencia(ano: number, trimestre: number): string {
  return `${ano}-T${trimestre}`
}

/** O número do encontro com a tentativa, quando houve mais de uma. */
export function numeroDoEncontro(numero: number, tentativa: number): string {
  return tentativa > 1 ? `${numero} · tentativa ${tentativa}` : String(numero)
}

// -------------------------------------------------- a estrutura do programa

/**
 * A estrutura oficial do programa, montada das colunas de carga da 0007.
 *
 * Cada programa da casa tem a sua, e a tela mostra a do programa em vez de
 * repetir um texto genérico. O conselho dedicado mostra encontro semanal,
 * encontro de gestão, pauta prioritária e presencial do mês. O Negócios de
 * Valor mostra os 12 encontros de 2h30 e as 8 semanas de sustentação. E assim
 * por diante, sempre lendo o que está gravado, nunca adivinhando pelo nome.
 */
export function estruturaOficial(programa: Programa): ItemDaEstrutura[] {
  const itens: ItemDaEstrutura[] = []

  const juntar = (chave: string, rotulo: string, valor: string) =>
    itens.push({ chave, rotulo, valor })

  if (programa.encontros_previstos) {
    const duracaoDoEncontro = programa.duracao_encontro_minutos
      ? ` de ${duracao(programa.duracao_encontro_minutos)}`
      : ''
    juntar(
      'encontros',
      'Encontros previstos',
      `${programa.encontros_previstos} encontros${duracaoDoEncontro}, em cadência ${ROTULO_CADENCIA[programa.cadencia].toLowerCase()}`,
    )
  } else {
    juntar('cadencia', 'Cadência', ROTULO_CADENCIA[programa.cadencia])
  }

  if (programa.encontro_gestao_semanal) {
    juntar(
      'gestao',
      'Encontro de gestão',
      'Um encontro semanal de gestão, ao lado do encontro de conselho',
    )
  }

  if (programa.pauta_prioritaria_mensal) {
    juntar('pauta', 'Pauta prioritária', 'Uma pauta prioritária por mês')
  }

  if (programa.hotseat_por_membro) {
    juntar('hotseat', 'Hotseat', 'Um hotseat por membro ao longo do ciclo')
  }

  if (programa.resumo_semanal) {
    juntar('resumo', 'Resumo semanal', 'Um resumo escrito a cada semana')
  }

  if (programa.deep_dive_mensal) {
    juntar('deepdive', 'Deep-dive', 'Um deep-dive por mês, além do encontro semanal')
  }

  if (programa.presenciais_por_mes > 0) {
    juntar(
      'presenciais',
      'Presencial',
      programa.presenciais_por_mes === 1
        ? 'Um presencial por mês'
        : `${programa.presenciais_por_mes} presenciais por mês`,
    )
  }

  if (programa.semanas_sustentacao) {
    juntar(
      'sustentacao',
      'Sustentação',
      `${programa.semanas_sustentacao} semanas de sustentação depois dos encontros`,
    )
  }

  if (programa.dias_imersao) {
    juntar(
      'imersao',
      'Imersão',
      programa.dias_imersao === 1
        ? 'Imersão de 1 dia'
        : `Imersão de ${programa.dias_imersao} dias`,
    )
  }

  if (programa.modulos_previstos) {
    const comTemas = programa.temas_previstos
      ? `${programa.modulos_previstos} módulos e ${programa.temas_previstos} temas`
      : `${programa.modulos_previstos} módulos`
    juntar('modulos', 'Módulos', comTemas)
  } else if (programa.temas_previstos) {
    juntar('temas', 'Temas', `${programa.temas_previstos} temas`)
  }

  if (programa.etapas_previstas) {
    const emMeses = programa.meses_duracao
      ? `${programa.etapas_previstas} etapas em ${programa.meses_duracao} meses`
      : `${programa.etapas_previstas} etapas`
    juntar('etapas', 'Etapas', emMeses)
  } else if (programa.meses_duracao) {
    juntar('duracao', 'Duração', `${programa.meses_duracao} meses`)
  }

  if (programa.estacoes_plano) {
    juntar('estacoes', 'Plano', `Plano em ${programa.estacoes_plano} estações`)
  }

  if (programa.plano_por_participante) {
    juntar('plano', 'Plano individual', 'Um plano de desenvolvimento por participante')
  }

  if (programa.marcos_indice.length > 0) {
    juntar('indice', 'Índice próprio', `Medido em ${programa.marcos_indice.join(', ')}`)
  }

  if (programa.certificacao) {
    juntar('certificacao', 'Certificação', 'Certificado ao fim do ciclo')
  }

  return itens
}

/** Uma linha curta da estrutura, para caber numa célula de tabela. */
export function resumoDaEstrutura(programa: Programa): string {
  const itens = estruturaOficial(programa)
  if (itens.length === 0) return 'Carga oficial ainda não registrada'
  return itens
    .slice(0, 3)
    .map((item) => item.valor)
    .join(' · ')
}
