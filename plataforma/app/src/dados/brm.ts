/**
 * Dados do BRM de Valor: programas, turmas, encontros e entregáveis.
 *
 * A regra é a mesma de `src/dados/consultas.ts`: quando o banco está ligado,
 * lê do banco; quando não está, cai nos dados de exemplo e a tela diz que está
 * em exemplo. Nunca mistura os dois sem avisar.
 *
 * Toda empresa e toda pessoa deste arquivo são claramente fictícias, e nenhum
 * campo de avaliação de gente é preenchido, conforme a seção 11 do contrato
 * técnico: nota, devolutiva e rubrica ficam vazias de propósito.
 *
 * O calendário de exemplo é montado pela mesma regra de
 * `valor.brm_calendario_turma`, ou seja, pulando o recesso de meados de
 * dezembro a meados de janeiro. Assim o exemplo nunca fica incoerente com o
 * banco, e o salto do recesso aparece na tela como o que é.
 */

import { useQuery, type UseQueryResult } from '@tanstack/react-query'
import { obterCliente, temBanco, type ClienteValor } from '@/dados/cliente'
import type {
  BrmCadencia,
  BrmSituacaoPresenca,
  BrmStatusEncontro,
  DiaDoCalendario,
  Encontro,
  EncontroNaLista,
  Entregavel,
  EntregavelNaLista,
  HistoricoValorDevido,
  ItemRitualNaFicha,
  ItemRitualSemanal,
  Participante,
  ParticipanteNaFicha,
  Presenca,
  PresencaNaFicha,
  Programa,
  ProgramaNaLista,
  RegistroHistoricoNaFicha,
  RegistroHistoricoValor,
  Turma,
  TurmaConta,
  TurmaNaLista,
} from '@/tipos/brm'

// ----------------------------------------------------------- datas e calendário

const HOJE = new Date()
const HOJE_ISO = HOJE.toISOString().slice(0, 10)

/** O ano civil corrente, que é o ano dos programas de exemplo. */
const ANO = HOJE.getFullYear()

/** O trimestre corrente, do jeito que `extract(quarter from current_date)` faz. */
const TRIMESTRE = Math.floor(HOJE.getMonth() / 3) + 1

function iso(quando: Date): string {
  return quando.toISOString().slice(0, 10)
}

function comoData(valor: string): Date {
  return new Date(`${valor.slice(0, 10)}T12:00:00Z`)
}

/** Data ISO a tantos dias de outra data. Número negativo anda para trás. */
function maisDias(valor: string, dias: number): string {
  const quando = comoData(valor)
  quando.setUTCDate(quando.getUTCDate() + dias)
  return iso(quando)
}

/** Chave de dia no ano, mês vezes cem mais dia, igual a `valor.brm_chave_dia`. */
function chaveDia(valor: string): number {
  const quando = comoData(valor)
  return (quando.getUTCMonth() + 1) * 100 + quando.getUTCDate()
}

/**
 * Verdadeiro quando a data cai no recesso, igual a `valor.brm_em_recesso`.
 * A janela é lida por dia e mês, nunca por ano, porque o recesso do conselho
 * atravessa a virada do ano.
 */
function emRecesso(valor: string, inicio: string | null, fim: string | null): boolean {
  if (!inicio || !fim) return false
  const dia = chaveDia(valor)
  const de = chaveDia(inicio)
  const ate = chaveDia(fim)
  if (de <= ate) return dia >= de && dia <= ate
  return dia >= de || dia <= ate
}

/** O passo de cada cadência, em dias. O mensal e os maiores andam por mês. */
const PASSO_EM_DIAS: Partial<Record<BrmCadencia, number>> = {
  semanal: 7,
  quinzenal: 14,
  imersao: 1,
}

const PASSO_EM_MESES: Partial<Record<BrmCadencia, number>> = {
  mensal: 1,
  bimestral: 2,
  trimestral: 3,
}

function proximaData(valor: string, cadencia: BrmCadencia): string {
  const meses = PASSO_EM_MESES[cadencia]
  if (meses) {
    const quando = comoData(valor)
    quando.setUTCMonth(quando.getUTCMonth() + meses)
    return iso(quando)
  }
  return maisDias(valor, PASSO_EM_DIAS[cadencia] ?? 7)
}

/**
 * Calendário base da turma, saltando o recesso. Mesma regra de
 * `valor.brm_calendario_turma`, que é quem manda quando o banco está ligado.
 */
export function montarCalendario(
  inicio: string,
  quantidade: number,
  cadencia: BrmCadencia,
  recessoInicio: string | null,
  recessoFim: string | null,
): string[] {
  const datas: string[] = []
  let atual = inicio
  let voltas = 0

  while (datas.length < quantidade && voltas < 5000) {
    voltas += 1
    if (emRecesso(atual, recessoInicio, recessoFim)) {
      atual = proximaData(atual, cadencia)
      continue
    }
    datas.push(atual)
    atual = proximaData(atual, cadencia)
  }

  return datas
}

// ------------------------------------------------------------- gente e contas
// Nomes claramente fictícios, como manda a seção 11 do contrato técnico.

interface Registro {
  id: string
  nome: string
}

const CONTAS: Registro[] = [
  { id: 'ct-aurora', nome: 'Metalúrgica Aurora Fictícia' },
  { id: 'ct-serra', nome: 'Transportes Serra Modelo' },
  { id: 'ct-bemviver', nome: 'Clínica Bem Viver Exemplo' },
  { id: 'ct-agrovale', nome: 'Agro Vale Fictício' },
  { id: 'ct-sabor', nome: 'Rede Sabor Fictícia' },
  { id: 'ct-softworks', nome: 'Softworks Exemplo' },
  { id: 'ct-cancao', nome: 'Têxtil Canção Fictícia' },
  { id: 'ct-horizonte', nome: 'Construtora Horizonte Modelo' },
]

const NOME_DA_CONTA = new Map(CONTAS.map((conta) => [conta.id, conta.nome]))

const CASA: Registro[] = [
  { id: 'us-conselheira', nome: 'Conselheira de Exemplo' },
  { id: 'us-conselheiro', nome: 'Conselheiro de Exemplo' },
  { id: 'us-assessora', nome: 'Assessora de Exemplo' },
  { id: 'us-coordenadora', nome: 'Coordenadora de Exemplo' },
]

const NOME_DA_CASA = new Map(CASA.map((pessoa) => [pessoa.id, pessoa.nome]))

function nomeDaCasa(id: string | null): string {
  if (!id) return 'sem responsável'
  return NOME_DA_CASA.get(id) ?? 'sem responsável'
}

function nomeDaConta(id: string | null): string {
  if (!id) return 'sem conta'
  return NOME_DA_CONTA.get(id) ?? 'sem conta'
}

// ---------------------------------------------------------------- programas
// Os sete Programas de Valor, cada um com a carga oficial do catálogo da casa,
// gravada nas colunas da 0007. A tela lê estas colunas, não o nome do programa.

/** Os campos de carga que todo programa tem, para não repetir nulo em cada um. */
const CARGA_VAZIA = {
  encontros_previstos: null,
  duracao_encontro_minutos: null,
  semanas_sustentacao: null,
  dias_imersao: null,
  modulos_previstos: null,
  temas_previstos: null,
  etapas_previstas: null,
  meses_duracao: null,
  presenciais_por_mes: 0,
  estacoes_plano: null,
  encontro_gestao_semanal: false,
  pauta_prioritaria_mensal: false,
  hotseat_por_membro: false,
  resumo_semanal: false,
  deep_dive_mensal: false,
  plano_por_participante: false,
  certificacao: false,
  marcos_indice: [] as string[],
  carga_extra: {} as Record<string, unknown>,
} satisfies Partial<Programa>

const COMUM = {
  inquilino_id: 'iq-exemplo',
  contrato_id: null,
  negocio_id: null,
  observacoes: null,
  criado_em: `${ANO}-01-05T12:00:00Z`,
  arquivado_em: null,
} satisfies Partial<Programa>

export const PROGRAMAS_EXEMPLO: Programa[] = [
  {
    ...COMUM,
    ...CARGA_VAZIA,
    id: 'pg-conselho-dedicado',
    oferta_id: 'of-conselho-dedicado',
    conta_id: 'ct-aurora',
    codigo: `CVD-${ANO}`,
    nome: 'Conselho de Valor dedicado',
    ano: ANO,
    modalidade: 'dedicada',
    status: 'ativo',
    responsavel_id: 'us-conselheira',
    data_inicio: `${ANO}-02-03`,
    data_fim: `${ANO}-12-08`,
    cadencia: 'semanal',
    encontros_previstos: 48,
    meses_duracao: 12,
    presenciais_por_mes: 1,
    encontro_gestao_semanal: true,
    pauta_prioritaria_mensal: true,
  },
  {
    ...COMUM,
    ...CARGA_VAZIA,
    id: 'pg-conselho-compartilhado',
    oferta_id: 'of-conselho-compartilhado',
    conta_id: null,
    codigo: `CVC-${ANO}`,
    nome: 'Conselho de Valor compartilhado',
    ano: ANO,
    modalidade: 'compartilhada',
    status: 'ativo',
    responsavel_id: 'us-conselheiro',
    data_inicio: `${ANO}-01-20`,
    data_fim: `${ANO + 1}-02-09`,
    cadencia: 'semanal',
    encontros_previstos: 48,
    meses_duracao: 12,
    presenciais_por_mes: 1,
    hotseat_por_membro: true,
    resumo_semanal: true,
  },
  {
    ...COMUM,
    ...CARGA_VAZIA,
    id: 'pg-negocios-de-valor',
    oferta_id: 'of-negocios-de-valor',
    conta_id: 'ct-serra',
    codigo: `NV-${ANO}`,
    nome: 'Negócios de Valor',
    ano: ANO,
    modalidade: 'dedicada',
    status: 'ativo',
    responsavel_id: 'us-conselheiro',
    data_inicio: `${ANO}-03-10`,
    data_fim: `${ANO}-09-29`,
    cadencia: 'semanal',
    encontros_previstos: 12,
    duracao_encontro_minutos: 150,
    semanas_sustentacao: 8,
    dias_imersao: 3,
  },
  {
    ...COMUM,
    ...CARGA_VAZIA,
    id: 'pg-lideranca-de-valor',
    oferta_id: 'of-lideranca-de-valor',
    conta_id: null,
    codigo: `LV-${ANO}`,
    nome: 'Liderança de Valor',
    ano: ANO,
    modalidade: 'compartilhada',
    status: 'planejado',
    responsavel_id: 'us-coordenadora',
    data_inicio: `${ANO}-10-06`,
    data_fim: `${ANO}-11-24`,
    cadencia: 'modular',
    dias_imersao: 2,
    modulos_previstos: 8,
    plano_por_participante: true,
    certificacao: true,
  },
  {
    ...COMUM,
    ...CARGA_VAZIA,
    id: 'pg-gestao-de-valor',
    oferta_id: 'of-gestao-de-valor',
    conta_id: 'ct-bemviver',
    codigo: `GV-${ANO}`,
    nome: 'Gestão de Valor',
    ano: ANO,
    modalidade: 'dedicada',
    status: 'ativo',
    responsavel_id: 'us-coordenadora',
    data_inicio: `${ANO}-02-17`,
    data_fim: `${ANO + 1}-02-23`,
    cadencia: 'semanal',
    encontros_previstos: 48,
    modulos_previstos: 6,
    temas_previstos: 48,
    meses_duracao: 12,
  },
  {
    ...COMUM,
    ...CARGA_VAZIA,
    id: 'pg-mentoria-de-valor',
    oferta_id: 'of-mentoria-de-valor',
    conta_id: 'ct-horizonte',
    codigo: `MV-${ANO}`,
    nome: 'Mentoria de Valor',
    ano: ANO,
    modalidade: 'dedicada',
    status: 'ativo',
    responsavel_id: 'us-conselheira',
    data_inicio: `${ANO}-02-10`,
    data_fim: `${ANO + 1}-02-16`,
    cadencia: 'semanal',
    encontros_previstos: 44,
    meses_duracao: 12,
    deep_dive_mensal: true,
    estacoes_plano: 4,
  },
  {
    ...COMUM,
    ...CARGA_VAZIA,
    id: 'pg-executivo-de-valor',
    oferta_id: 'of-executivo-de-valor',
    conta_id: null,
    codigo: `EV-${ANO}`,
    nome: 'Executivo de Valor',
    ano: ANO,
    modalidade: 'compartilhada',
    status: 'ativo',
    responsavel_id: 'us-conselheira',
    data_inicio: `${ANO}-04-07`,
    data_fim: `${ANO}-10-06`,
    cadencia: 'quinzenal',
    encontros_previstos: 12,
    duracao_encontro_minutos: 120,
    etapas_previstas: 12,
    meses_duracao: 6,
    marcos_indice: ['T0', 'T90', 'T180'],
  },
]

/** O nome da oferta de origem, que na tela aparece ao lado do programa. */
const OFERTA_DO_PROGRAMA: Record<string, string> = {
  'pg-conselho-dedicado': 'Conselho de Valor dedicado',
  'pg-conselho-compartilhado': 'Conselho de Valor compartilhado',
  'pg-negocios-de-valor': 'Negócios de Valor',
  'pg-lideranca-de-valor': 'Liderança de Valor',
  'pg-gestao-de-valor': 'Gestão de Valor',
  'pg-mentoria-de-valor': 'Mentoria de Valor',
  'pg-executivo-de-valor': 'Executivo de Valor',
}

// -------------------------------------------------------------------- turmas

const TURMA_COMUM = {
  inquilino_id: 'iq-exemplo',
  contrato_id: null,
  negocio_id: null,
  observacoes: null,
  criado_em: `${ANO}-01-05T12:00:00Z`,
  arquivado_em: null,
} satisfies Partial<Turma>

/** O recesso do conselho: meados de dezembro a meados de janeiro. */
const RECESSO_INICIO = `${ANO}-12-15`
const RECESSO_FIM = `${ANO + 1}-01-15`

interface TurmaDeExemplo extends Omit<Turma, 'calendario_base'> {
  calendario_base: string[]
}

function comCalendario(turma: Omit<Turma, 'calendario_base'>, quantidade: number): TurmaDeExemplo {
  return {
    ...turma,
    calendario_base: montarCalendario(
      turma.data_inicio ?? HOJE_ISO,
      quantidade,
      turma.cadencia,
      turma.recesso_inicio,
      turma.recesso_fim,
    ),
  }
}

export const TURMAS_EXEMPLO: Turma[] = [
  comCalendario(
    {
      ...TURMA_COMUM,
      id: 'tu-cvc-a',
      programa_id: 'pg-conselho-compartilhado',
      codigo: `CVC-${ANO}-A`,
      nome: 'Conselho compartilhado da manhã',
      cadeiras_minimas: 4,
      cadeiras_maximas: 8,
      data_inicio: `${ANO}-01-20`,
      data_fim: `${ANO + 1}-02-09`,
      status: 'em_andamento',
      cadencia: 'semanal',
      formato: 'online',
      dia_semana: 2,
      horario_inicio: '08:00',
      horario_fim: '10:00',
      encontros_previstos: 48,
      recesso_inicio: RECESSO_INICIO,
      recesso_fim: RECESSO_FIM,
      facilitador_id: 'us-conselheiro',
      coordenador_id: 'us-coordenadora',
    },
    48,
  ),
  comCalendario(
    {
      ...TURMA_COMUM,
      id: 'tu-cvd-aurora',
      programa_id: 'pg-conselho-dedicado',
      codigo: `CVD-${ANO}-AURORA`,
      nome: 'Conselho dedicado da Aurora',
      cadeiras_minimas: 3,
      cadeiras_maximas: 8,
      data_inicio: `${ANO}-02-03`,
      data_fim: `${ANO + 1}-02-23`,
      status: 'em_andamento',
      cadencia: 'semanal',
      formato: 'hibrido',
      dia_semana: 2,
      horario_inicio: '14:00',
      horario_fim: '16:30',
      encontros_previstos: 48,
      recesso_inicio: RECESSO_INICIO,
      recesso_fim: RECESSO_FIM,
      facilitador_id: 'us-conselheira',
      coordenador_id: 'us-assessora',
    },
    48,
  ),
  comCalendario(
    {
      ...TURMA_COMUM,
      id: 'tu-nv-serra',
      programa_id: 'pg-negocios-de-valor',
      codigo: `NV-${ANO}-SERRA`,
      nome: 'Time comercial da Serra',
      cadeiras_minimas: 8,
      cadeiras_maximas: 16,
      data_inicio: `${ANO}-03-10`,
      data_fim: `${ANO}-09-29`,
      status: 'em_andamento',
      cadencia: 'semanal',
      formato: 'presencial',
      dia_semana: 2,
      horario_inicio: '09:00',
      horario_fim: '11:30',
      encontros_previstos: 12,
      recesso_inicio: null,
      recesso_fim: null,
      facilitador_id: 'us-conselheiro',
      coordenador_id: 'us-assessora',
    },
    12,
  ),
  comCalendario(
    {
      ...TURMA_COMUM,
      id: 'tu-lv-t1',
      programa_id: 'pg-lideranca-de-valor',
      codigo: `LV-${ANO}-T1`,
      nome: 'Liderança de Valor, primeira turma',
      cadeiras_minimas: 6,
      cadeiras_maximas: 20,
      data_inicio: `${ANO}-10-06`,
      data_fim: `${ANO}-11-24`,
      status: 'planejada',
      cadencia: 'modular',
      formato: 'presencial',
      dia_semana: 2,
      horario_inicio: '08:30',
      horario_fim: '17:30',
      encontros_previstos: 8,
      recesso_inicio: null,
      recesso_fim: null,
      facilitador_id: 'us-coordenadora',
      coordenador_id: 'us-assessora',
    },
    8,
  ),
  comCalendario(
    {
      ...TURMA_COMUM,
      id: 'tu-mv-horizonte',
      programa_id: 'pg-mentoria-de-valor',
      codigo: `MV-${ANO}-HORIZONTE`,
      nome: 'Mentoria da Horizonte',
      cadeiras_minimas: 1,
      cadeiras_maximas: 1,
      data_inicio: `${ANO}-02-10`,
      data_fim: `${ANO + 1}-02-16`,
      status: 'em_andamento',
      cadencia: 'semanal',
      formato: 'online',
      dia_semana: 2,
      horario_inicio: '07:30',
      horario_fim: '08:30',
      encontros_previstos: 44,
      recesso_inicio: RECESSO_INICIO,
      recesso_fim: RECESSO_FIM,
      facilitador_id: 'us-conselheira',
      coordenador_id: null,
    },
    44,
  ),
]

/**
 * As contas de cada turma.
 *
 * Na turma compartilhada elas são várias, de mercados distintos, e é por isso
 * que a ficha da turma mostra a conta de cada participante.
 */
const CADEIRAS_POR_CONTA: Record<string, number> = {
  'tu-cvd-aurora': 4,
  'tu-nv-serra': 11,
  'tu-lv-t1': 4,
}

const VINCULOS: Array<[string, string, boolean]> = [
  ['tu-cvc-a', 'ct-agrovale', true],
  ['tu-cvc-a', 'ct-sabor', false],
  ['tu-cvc-a', 'ct-softworks', false],
  ['tu-cvc-a', 'ct-cancao', false],
  ['tu-cvc-a', 'ct-bemviver', false],
  ['tu-cvc-a', 'ct-horizonte', false],
  ['tu-cvd-aurora', 'ct-aurora', true],
  ['tu-nv-serra', 'ct-serra', true],
  ['tu-lv-t1', 'ct-softworks', true],
  ['tu-lv-t1', 'ct-sabor', false],
  ['tu-mv-horizonte', 'ct-horizonte', true],
]

export const TURMAS_CONTAS_EXEMPLO: TurmaConta[] = VINCULOS.map(
  ([turmaId, contaId, anfitria]): TurmaConta => ({
    id: `tc-${turmaId}-${contaId}`,
    turma_id: turmaId,
    conta_id: contaId,
    conta_nome: nomeDaConta(contaId),
    cadeiras_contratadas: CADEIRAS_POR_CONTA[turmaId] ?? 1,
    eh_anfitria: anfitria,
    entrou_em: `${ANO}-01-12`,
    saiu_em: null,
  }),
)

// -------------------------------------------------------------- participantes

const PARTICIPANTE_COMUM = {
  inquilino_id: 'iq-exemplo',
  contato_id: null,
  usuario_id: null,
  saiu_em: null,
  motivo_saida: null,
  encontros_convocados: 0,
  encontros_presentes: 0,
  presenca_percentual: null,
  indices: {} as Record<string, unknown>,
  certificado_em: null,
  certificado_url: null,
  observacoes: null,
  arquivado_em: null,
} satisfies Partial<Participante>

/** Nome, conta, papel e cadeira de cada pessoa das turmas de exemplo. */
const GENTE: Array<[string, string, string, Participante['papel'], number]> = [
  ['tu-cvc-a', 'Alice Fictícia', 'ct-agrovale', 'socio', 1],
  ['tu-cvc-a', 'Bruno Exemplo', 'ct-sabor', 'socio', 2],
  ['tu-cvc-a', 'Carla Modelo', 'ct-softworks', 'executivo', 3],
  ['tu-cvc-a', 'Décio Fictício', 'ct-cancao', 'socio', 4],
  ['tu-cvc-a', 'Elisa Exemplo', 'ct-bemviver', 'socio', 5],
  ['tu-cvc-a', 'Fábio Modelo', 'ct-horizonte', 'executivo', 6],
  ['tu-cvd-aurora', 'Gilda Fictícia', 'ct-aurora', 'socio', 1],
  ['tu-cvd-aurora', 'Hélio Exemplo', 'ct-aurora', 'socio', 2],
  ['tu-cvd-aurora', 'Iara Modelo', 'ct-aurora', 'executivo', 3],
  ['tu-cvd-aurora', 'Jonas Fictício', 'ct-aurora', 'executivo', 4],
  ['tu-nv-serra', 'Lúcia Exemplo', 'ct-serra', 'executivo', 1],
  ['tu-nv-serra', 'Mário Fictício', 'ct-serra', 'membro', 2],
  ['tu-nv-serra', 'Nara Modelo', 'ct-serra', 'membro', 3],
  ['tu-nv-serra', 'Otávio Exemplo', 'ct-serra', 'membro', 4],
  ['tu-nv-serra', 'Paula Fictícia', 'ct-serra', 'membro', 5],
  ['tu-lv-t1', 'Rita Modelo', 'ct-softworks', 'executivo', 1],
  ['tu-lv-t1', 'Sérgio Exemplo', 'ct-softworks', 'membro', 2],
  ['tu-lv-t1', 'Tânia Fictícia', 'ct-sabor', 'executivo', 3],
  ['tu-lv-t1', 'Ulisses Modelo', 'ct-sabor', 'membro', 4],
  ['tu-mv-horizonte', 'Vera Exemplo', 'ct-horizonte', 'socio', 1],
]

export const PARTICIPANTES_EXEMPLO: Participante[] = GENTE.map(
  ([turma_id, nome, conta_id, papel, cadeira]) => ({
    ...PARTICIPANTE_COMUM,
    id: `pa-${turma_id}-${cadeira}`,
    turma_id,
    conta_id,
    nome,
    papel,
    cadeira,
    entrou_em: `${ANO}-01-15`,
    status: 'ativo',
  }),
)

// ------------------------------------------------------------------ encontros
// Os temas saem do banco de pautas do método: os temas de governança e as
// famílias de gestão. Nenhum deles cita cliente real.

const TEMAS_DE_CONSELHO: string[] = [
  'Painel de indicadores do trimestre',
  'Caixa, capital de giro e ciclo financeiro',
  'Estrutura societária e sucessão',
  'Governança do conselho e os ritos da casa',
  'Pessoas, papéis e banco de sucessores',
  'Mercado, concorrência e posicionamento',
  'Portfólio e rentabilidade por linha',
  'Funil comercial e previsibilidade',
  'Operação, capacidade instalada e gargalos',
  'Tecnologia, dados e indicadores de gestão',
  'Riscos, contratos e conformidade',
  'Cultura, comunicação e clima',
  'Plano de investimento do ano',
  'Clientes, retenção e expansão',
  'Orçamento do ciclo seguinte',
  'Revisão do plano e encerramento do ciclo',
]

const TEMAS_DE_NEGOCIOS: string[] = [
  'Seleção Estratégica e mapa de contas',
  'Exploração Profunda e hipótese de valor',
  'Conexão de Valor e Plano de Trabalho',
  'Confirmação de Compromisso e Contrato de Valor',
  'Execução de Excelência na conta âncora',
  'Cultivo de Valor e base instalada',
  'Parceria de Crescimento e renovação',
  'Higiene do funil e as quatro invariantes',
  'Forecast por artefato',
  'Rota pública e licitação',
  'Cadência de gestão do time',
  'Encerramento do ciclo e plano de sustentação',
]

function temaDoEncontro(turmaId: string, numero: number): string {
  const banco = turmaId === 'tu-nv-serra' ? TEMAS_DE_NEGOCIOS : TEMAS_DE_CONSELHO
  return banco[(numero - 1) % banco.length] ?? 'Tema a definir'
}

const ENCONTRO_COMUM = {
  inquilino_id: 'iq-exemplo',
  hora_realizada_inicio: null,
  hora_realizada_fim: null,
  link: null,
  hotseat_participante_id: null,
  observacoes_restritas: null,
  arquivado_em: null,
} satisfies Partial<Encontro>

/** O programa de uma turma de exemplo, para ler a carga oficial dele. */
function programaDaTurma(turma: Turma): Programa | undefined {
  return PROGRAMAS_EXEMPLO.find((programa) => programa.id === turma.programa_id)
}

function participantesDaTurma(turmaId: string): Participante[] {
  return PARTICIPANTES_EXEMPLO.filter((pessoa) => pessoa.turma_id === turmaId)
}

/**
 * Os encontros de uma turma, montados do calendário base.
 *
 * O encontro 2 da turma compartilhada nasce remarcado de propósito, para a
 * tela mostrar o que a 0008 garante: a remarcação não perde a numeração
 * original, ela apenas soma uma tentativa.
 */
function montarEncontrosDaTurma(turma: Turma): Encontro[] {
  const programa = programaDaTurma(turma)
  const limite = maisDias(HOJE_ISO, 60)
  const gente = participantesDaTurma(turma.id)
  const encontros: Encontro[] = []

  turma.calendario_base.forEach((dataPrevista, indice) => {
    if (dataPrevista > limite) return

    const numero = indice + 1
    const realizado = dataPrevista < HOJE_ISO
    const presencial = numero % 4 === 0
    const hotseat = Boolean(programa?.hotseat_por_membro) && numero % 6 === 0
    const gravado = realizado && numero % 3 === 0
    const restrito = turma.id === 'tu-cvd-aurora' && numero === 9

    const base: Encontro = {
      ...ENCONTRO_COMUM,
      id: `en-${turma.id}-${numero}`,
      turma_id: turma.id,
      numero,
      tentativa: 1,
      tema: temaDoEncontro(turma.id, numero),
      pauta: [
        'Leitura dos indicadores da semana',
        'Ritual semanal: Highlights, Lowlights, Metas e Prioridades',
        'Pendências que vieram do encontro anterior',
      ],
      data_prevista: dataPrevista,
      hora_prevista_inicio: turma.horario_inicio,
      hora_prevista_fim: turma.horario_fim,
      data_prevista_original: dataPrevista,
      data_realizada: realizado ? dataPrevista : null,
      formato: presencial ? 'presencial' : turma.formato,
      local: presencial ? 'Sala de conselho da casa' : null,
      status: realizado ? 'realizado' : 'previsto',
      conselheiro_id: turma.facilitador_id,
      assessor_id: turma.coordenador_id,
      gravacao_url: gravado
        ? `https://arquivo.exemplo.invalid/gravacoes/${turma.codigo.toLowerCase()}/encontro-${numero}`
        : null,
      transcricao_url: gravado
        ? `https://arquivo.exemplo.invalid/transcricoes/${turma.codigo.toLowerCase()}/encontro-${numero}`
        : null,
      transcricao_texto: gravado
        ? 'Transcrição de exemplo. A turma revisou os indicadores da semana, discutiu o tema da pauta e registrou as decisões no ritual semanal. Texto fictício, sem nenhuma avaliação de pessoa.'
        : null,
      remarcado_de: null,
      remarcado_para: null,
      motivo_remarcacao: null,
      eh_presencial_do_mes: presencial,
      eh_pauta_prioritaria: Boolean(programa?.pauta_prioritaria_mensal) && numero % 4 === 2,
      eh_encontro_de_gestao: Boolean(programa?.encontro_gestao_semanal) && numero % 4 === 3,
      eh_hotseat: hotseat,
      hotseat_participante_id: hotseat
        ? (gente[(numero / 6 - 1) % Math.max(1, gente.length)]?.id ?? null)
        : null,
      restrito,
      observacoes_restritas: restrito
        ? 'Encontro sobre pessoas do cliente. O banco decide quem recebe esta linha, a tela não esconde o que chegou.'
        : null,
    }

    // A remarcação do encontro 2 da turma compartilhada. A primeira tentativa
    // sai da disputa, mantém o número e guarda a data que estava marcada.
    if (turma.id === 'tu-cvc-a' && numero === 2) {
      // A remarcação cai fora da grade base, e não em cima da data seguinte.
      const adiada = maisDias(dataPrevista, 3)
      encontros.push({
        ...base,
        status: 'remarcado',
        data_realizada: null,
        gravacao_url: null,
        transcricao_url: null,
        transcricao_texto: null,
        remarcado_para: `${base.id}-t2`,
        motivo_remarcacao: 'Viagem do anfitrião da semana. O número do encontro continua sendo o 2.',
      })
      encontros.push({
        ...base,
        id: `${base.id}-t2`,
        tentativa: 2,
        data_prevista: adiada,
        data_prevista_original: dataPrevista,
        data_realizada: adiada < HOJE_ISO ? adiada : null,
        status: adiada < HOJE_ISO ? 'realizado' : 'previsto',
        remarcado_de: base.id,
        motivo_remarcacao: 'Viagem do anfitrião da semana. O número do encontro continua sendo o 2.',
      })
      return
    }

    encontros.push(base)
  })

  return encontros
}

export const ENCONTROS_EXEMPLO: Encontro[] = TURMAS_EXEMPLO.flatMap(montarEncontrosDaTurma)

// ------------------------------------------------------------------ presenças

/**
 * A presença de exemplo é determinística de propósito: a mesma tela mostra o
 * mesmo número a cada abertura, e ninguém confunde exemplo com dado real.
 */
function situacaoDaPresenca(numero: number, cadeira: number): BrmSituacaoPresenca {
  if ((numero * 7 + cadeira * 3) % 17 === 0) return 'ausente'
  if ((numero + cadeira * 2) % 11 === 0) return 'ausente_justificado'
  return 'presente'
}

export const PRESENCAS_EXEMPLO: Presenca[] = ENCONTROS_EXEMPLO.filter(
  (encontro) => encontro.status === 'realizado',
).flatMap((encontro) =>
  participantesDaTurma(encontro.turma_id).map((pessoa): Presenca => {
    const situacao = situacaoDaPresenca(encontro.numero, pessoa.cadeira ?? 1)
    return {
      id: `pr-${encontro.id}-${pessoa.id}`,
      encontro_id: encontro.id,
      participante_id: pessoa.id,
      situacao,
      minutos_presentes: situacao === 'presente' ? 120 : null,
      justificativa:
        situacao === 'ausente_justificado' ? 'Compromisso na agenda da empresa.' : null,
      observacao: null,
      arquivado_em: null,
    }
  }),
)

// ------------------------------------------------------------- ritual semanal

const TOPICOS_RITUAL: Record<ItemRitualSemanal['tipo'], string[]> = {
  highlight: [
    'Caixa do mês acima do plano',
    'Contrato renovado na conta âncora',
    'Time de operação com a escala completa',
    'Indicador de retrabalho no menor patamar do ano',
  ],
  lowlight: [
    'Margem da linha nova abaixo do plano',
    'Prazo de entrega estourado em duas contas',
    'Rotatividade acima do aceitável na operação',
    'Painel de indicadores sem atualização há duas semanas',
  ],
  meta: [
    'Margem de contribuição em 32 por cento até o encerramento do trimestre',
    'Ciclo de caixa em 45 dias',
    'Receita recorrente em 40 por cento do total',
    'Índice de retenção de clientes em 92 por cento',
  ],
  prioridade: [
    'Reunião com o banco sobre a linha de capital de giro',
    'Desenho do plano de sucessão da diretoria',
    'Revisão da tabela de custos da linha nova',
    'Contratação do líder de operações',
  ],
}

const TIPOS_RITUAL: Array<ItemRitualSemanal['tipo']> = [
  'highlight',
  'highlight',
  'lowlight',
  'meta',
  'prioridade',
  'prioridade',
]

/** O ritual dos últimos encontros realizados de cada turma. */
function montarRitualDaTurma(turmaId: string): ItemRitualSemanal[] {
  const realizados = ENCONTROS_EXEMPLO.filter(
    (encontro) => encontro.turma_id === turmaId && encontro.status === 'realizado',
  ).slice(-5)
  const gente = participantesDaTurma(turmaId)
  if (gente.length === 0) return []

  return realizados.flatMap((encontro) =>
    TIPOS_RITUAL.map((tipo, ordem): ItemRitualSemanal => {
      const banco = TOPICOS_RITUAL[tipo]
      const responsavel = gente[(encontro.numero + ordem) % gente.length]
      return {
        id: `ri-${encontro.id}-${ordem + 1}`,
        encontro_id: encontro.id,
        turma_id: turmaId,
        conta_id: responsavel?.conta_id ?? null,
        tipo,
        ordem: ordem + 1,
        topico: banco[(encontro.numero + ordem) % banco.length] ?? 'Item do ritual',
        detalhe: null,
        responsavel_usuario_id: null,
        responsavel_participante_id: responsavel?.id ?? null,
        responsavel_nome: responsavel?.nome ?? null,
        data_alvo: maisDias(encontro.data_realizada ?? encontro.data_prevista, 7),
        concluido_em: tipo === 'highlight' ? encontro.data_realizada : null,
        evidencia: tipo === 'highlight' ? 'Registrado na ata do encontro.' : null,
        arquivado_em: null,
      }
    }),
  )
}

export const RITUAL_EXEMPLO: ItemRitualSemanal[] = TURMAS_EXEMPLO.flatMap((turma) =>
  montarRitualDaTurma(turma.id),
)

// ------------------------------------------------------------- entregáveis

const ENTREGAVEL_COMUM = {
  tipo_detalhe: null,
  arquivo_url: null,
  versao: 1,
  produzido_por_participante_id: null,
  produzido_por_nome: null,
  aprovado_por: null,
  arquivado_em: null,
} satisfies Partial<Entregavel>

function montarEntregaveisDaTurma(turma: Turma): Entregavel[] {
  const programa = programaDaTurma(turma)
  const gente = participantesDaTurma(turma.id)
  const saida: Entregavel[] = []

  const daTurma = ENCONTROS_EXEMPLO.filter((encontro) => encontro.turma_id === turma.id)

  for (const encontro of daTurma) {
    if (encontro.status === 'realizado') {
      const entrega = maisDias(encontro.data_realizada ?? encontro.data_prevista, 1)
      saida.push({
        ...ENTREGAVEL_COMUM,
        id: `ev-ata-${encontro.id}`,
        turma_id: turma.id,
        encontro_id: encontro.id,
        participante_id: null,
        conta_id: programa?.conta_id ?? null,
        tipo: 'ata',
        titulo: `Ata do encontro ${encontro.numero} · ${encontro.tema}`,
        descricao:
          'As sete seções da ata da casa: identificação, participantes, pauta, resumo das discussões, deliberações, próximos passos e próxima reunião com pré-pauta.',
        prazo: maisDias(encontro.data_realizada ?? encontro.data_prevista, 1),
        data_entrega: entrega,
        produzido_por_usuario_id: turma.coordenador_id,
        status: 'aprovado',
        visivel_ao_cliente: true,
        aprovado_em: maisDias(entrega, 1),
      })

      if (programa?.resumo_semanal && encontro.numero % 2 === 0) {
        saida.push({
          ...ENTREGAVEL_COMUM,
          id: `ev-resumo-${encontro.id}`,
          turma_id: turma.id,
          encontro_id: encontro.id,
          participante_id: null,
          conta_id: null,
          tipo: 'resumo_semanal',
          titulo: `Resumo semanal da semana ${encontro.numero}`,
          descricao: 'O resumo escrito que a turma recebe toda semana.',
          prazo: entrega,
          data_entrega: entrega,
          produzido_por_usuario_id: turma.facilitador_id,
          status: 'entregue',
          visivel_ao_cliente: true,
          aprovado_em: null,
        })
      }

      if (encontro.numero % 6 === 0 && gente.length > 0) {
        const autor = gente[encontro.numero % gente.length]
        saida.push({
          ...ENTREGAVEL_COMUM,
          id: `ev-plano-${encontro.id}`,
          turma_id: turma.id,
          encontro_id: encontro.id,
          participante_id: autor?.id ?? null,
          conta_id: autor?.conta_id ?? null,
          tipo: 'plano_de_acao',
          titulo: `Plano de ação do encontro ${encontro.numero}`,
          descricao: 'Plano de ação que a pessoa leva do encontro, com dono e prazo.',
          prazo: maisDias(entrega, 14),
          data_entrega: null,
          produzido_por_usuario_id: null,
          produzido_por_participante_id: autor?.id ?? null,
          status: 'rascunho',
          visivel_ao_cliente: false,
          aprovado_em: null,
        })
      }
    }
  }

  // A pré-pauta do próximo encontro previsto. É o que puxa as pendências.
  const proximo = daTurma.find((encontro) => encontro.status === 'previsto')
  if (proximo) {
    saida.push({
      ...ENTREGAVEL_COMUM,
      id: `ev-prepauta-${proximo.id}`,
      turma_id: turma.id,
      encontro_id: proximo.id,
      participante_id: null,
      conta_id: null,
      tipo: 'pre_pauta',
      titulo: `Pré-pauta do encontro ${proximo.numero}`,
      descricao:
        'Pré-pauta com as pendências que voltam do encontro anterior, cada uma com dono e prazo.',
      prazo: maisDias(proximo.data_prevista, -2),
      data_entrega: null,
      produzido_por_usuario_id: turma.coordenador_id,
      status: 'rascunho',
      visivel_ao_cliente: false,
      aprovado_em: null,
    })
  }

  return saida
}

export const ENTREGAVEIS_EXEMPLO: Entregavel[] = TURMAS_EXEMPLO.flatMap(montarEntregaveisDaTurma)

// ----------------------------------------------------- Histórico de Valor

const TEXTOS_HISTORICO: Array<[string, string, string]> = [
  [
    'Ciclo de encontros do trimestre, com a pauta prioritária em caixa e margem.',
    'A conta passou a rodar o painel de indicadores toda semana, com dono definido por linha.',
    'Ata do encontro 9 e painel de indicadores do trimestre.',
  ],
  [
    'Desenho do plano de sucessão da diretoria, em quatro estações.',
    'Dois sucessores mapeados e um plano de desenvolvimento aberto para cada um.',
    'Plano de desenvolvimento registrado e ata do presencial do mês.',
  ],
  [
    'Revisão do portfólio e da rentabilidade por linha.',
    'Duas linhas de menor margem foram repreçadas e uma foi encerrada.',
    'Relatório de rentabilidade por linha, anexo à ata.',
  ],
]

function montarHistoricoDeExemplo(): RegistroHistoricoValor[] {
  const registros: RegistroHistoricoValor[] = []
  let contador = 0

  for (const programa of PROGRAMAS_EXEMPLO) {
    if (programa.status !== 'ativo') continue

    const turmas = TURMAS_EXEMPLO.filter((turma) => turma.programa_id === programa.id)
    const contas = new Set<string>()
    for (const turma of turmas) {
      for (const vinculo of TURMAS_CONTAS_EXEMPLO) {
        if (vinculo.turma_id === turma.id) contas.add(vinculo.conta_id)
      }
    }

    for (const contaId of contas) {
      const turma = turmas[0]
      for (let trimestre = 1; trimestre <= TRIMESTRE; trimestre += 1) {
        // O trimestre corrente fica em aberto para parte das contas, que é o
        // que alimenta a fila de `valor.vw_historico_valor_devido`.
        if (trimestre === TRIMESTRE && contador % 2 === 1) {
          contador += 1
          continue
        }
        const texto = TEXTOS_HISTORICO[contador % TEXTOS_HISTORICO.length]
        registros.push({
          id: `hv-${programa.id}-${contaId}-${trimestre}`,
          conta_id: contaId,
          programa_id: programa.id,
          turma_id: turma?.id ?? null,
          ano: ANO,
          trimestre,
          competencia: `${ANO}-T${trimestre}`,
          data_referencia: `${ANO}-${String(trimestre * 3).padStart(2, '0')}-20`,
          entregue: texto?.[0] ?? 'Entrega do trimestre.',
          resultado: texto?.[1] ?? 'Resultado do trimestre.',
          evidencia: texto?.[2] ?? 'Evidência registrada na ata.',
          valor_numero: null,
          valor_unidade: null,
          arquivo_url: null,
          registrado_por: programa.responsavel_id,
          confirmado_por_contato_id: null,
          confirmado_em: trimestre < TRIMESTRE ? `${ANO}-${String(trimestre * 3).padStart(2, '0')}-28` : null,
          observacao_interna: null,
          arquivado_em: null,
        })
        contador += 1
      }
    }
  }

  return registros
}

export const HISTORICO_EXEMPLO: RegistroHistoricoValor[] = montarHistoricoDeExemplo()

/**
 * A fila de `valor.vw_historico_valor_devido`: conta e programa ativos que
 * ainda não têm registro no trimestre corrente.
 */
function montarDevidoDeExemplo(): HistoricoValorDevido[] {
  const devido: HistoricoValorDevido[] = []

  for (const programa of PROGRAMAS_EXEMPLO) {
    if (programa.status !== 'ativo') continue

    const turmas = TURMAS_EXEMPLO.filter((turma) => turma.programa_id === programa.id)
    const contas = new Set<string>()
    for (const turma of turmas) {
      for (const vinculo of TURMAS_CONTAS_EXEMPLO) {
        if (vinculo.turma_id === turma.id) contas.add(vinculo.conta_id)
      }
    }

    for (const contaId of contas) {
      const jaTem = HISTORICO_EXEMPLO.some(
        (registro) =>
          registro.programa_id === programa.id &&
          registro.conta_id === contaId &&
          registro.ano === ANO &&
          registro.trimestre === TRIMESTRE,
      )
      if (jaTem) continue

      devido.push({
        programa_id: programa.id,
        programa_codigo: programa.codigo,
        programa_nome: programa.nome,
        responsavel_id: programa.responsavel_id,
        conta_id: contaId,
        conta_nome: nomeDaConta(contaId),
        ano: ANO,
        trimestre: TRIMESTRE,
      })
    }
  }

  return devido
}

export const DEVIDO_EXEMPLO: HistoricoValorDevido[] = montarDevidoDeExemplo()

// ---------------------------------------------- leituras prontas para a tela

function participanteNaFicha(pessoa: Participante): ParticipanteNaFicha {
  const minhas = PRESENCAS_EXEMPLO.filter((presenca) => presenca.participante_id === pessoa.id)
  const convocados = minhas.length
  const presentes = minhas.filter((presenca) => presenca.situacao === 'presente').length

  return {
    ...pessoa,
    encontros_convocados: convocados,
    encontros_presentes: presentes,
    presenca_percentual: convocados > 0 ? presentes / convocados : null,
    conta_nome: nomeDaConta(pessoa.conta_id),
    nome_exibido: pessoa.nome ?? 'Participante sem nome',
  }
}

function encontroNaLista(encontro: Encontro): EncontroNaLista {
  const turma = TURMAS_EXEMPLO.find((linha) => linha.id === encontro.turma_id)
  const programa = turma ? programaDaTurma(turma) : undefined

  return {
    ...encontro,
    turma_codigo: turma?.codigo ?? 'sem turma',
    programa_nome: programa?.nome ?? 'sem programa',
    conselheiro_nome: nomeDaCasa(encontro.conselheiro_id),
    assessor_nome: nomeDaCasa(encontro.assessor_id),
    entregaveis: ENTREGAVEIS_EXEMPLO.filter((item) => item.encontro_id === encontro.id).length,
  }
}

function entregavelNaLista(entregavel: Entregavel): EntregavelNaLista {
  const turma = TURMAS_EXEMPLO.find((linha) => linha.id === entregavel.turma_id)
  const encontro = ENCONTROS_EXEMPLO.find((linha) => linha.id === entregavel.encontro_id)
  const autor = PARTICIPANTES_EXEMPLO.find(
    (pessoa) => pessoa.id === entregavel.produzido_por_participante_id,
  )

  const exibido = entregavel.produzido_por_usuario_id
    ? nomeDaCasa(entregavel.produzido_por_usuario_id)
    : (autor?.nome ?? entregavel.produzido_por_nome ?? 'sem registro')

  return {
    ...entregavel,
    turma_codigo: turma?.codigo ?? 'sem turma',
    conta_nome: entregavel.conta_id ? nomeDaConta(entregavel.conta_id) : null,
    encontro_numero: encontro?.numero ?? null,
    produzido_por_exibido: exibido,
  }
}

function turmaNaLista(turma: Turma): TurmaNaLista {
  const programa = programaDaTurma(turma)
  const gente = participantesDaTurma(turma.id).filter((pessoa) => pessoa.status !== 'desligado')
  const meus = ENCONTROS_EXEMPLO.filter((encontro) => encontro.turma_id === turma.id)
  const realizados = meus.filter((encontro) => encontro.status === 'realizado').length
  const previstos = turma.encontros_previstos ?? meus.length

  return {
    ...turma,
    programa_nome: programa?.nome ?? 'sem programa',
    programa_codigo: programa?.codigo ?? '',
    oferta_nome: programa ? (OFERTA_DO_PROGRAMA[programa.id] ?? programa.nome) : 'sem oferta',
    modalidade: programa?.modalidade ?? 'dedicada',
    facilitador_nome: nomeDaCasa(turma.facilitador_id),
    coordenador_nome: nomeDaCasa(turma.coordenador_id),
    contas: TURMAS_CONTAS_EXEMPLO.filter((vinculo) => vinculo.turma_id === turma.id),
    cadeiras_ocupadas: gente.length,
    encontros_realizados: realizados,
    encontros_restantes: Math.max(0, previstos - realizados),
  }
}

/**
 * O salto entre duas datas do calendário, quando o que separa as duas é o
 * recesso. Sem isto o calendário do conselho parece ter buraco de dado, e o
 * recesso é regra, não defeito.
 */
function saltoDeRecesso(
  anterior: string,
  atual: string,
  turma: Turma,
): DiaDoCalendario['saltoDeRecesso'] {
  const inicioRecesso = turma.recesso_inicio
  const fimRecesso = turma.recesso_fim
  if (!inicioRecesso || !fimRecesso) return null

  const passo = PASSO_EM_DIAS[turma.cadencia] ?? 7
  const distancia = Math.round(
    (comoData(atual).getTime() - comoData(anterior).getTime()) / 86400000,
  )
  if (distancia <= passo) return null

  let cursor = maisDias(anterior, 1)
  let pisouNoRecesso = false
  while (cursor < atual) {
    if (emRecesso(cursor, inicioRecesso, fimRecesso)) {
      pisouNoRecesso = true
      break
    }
    cursor = maisDias(cursor, 1)
  }
  if (!pisouNoRecesso) return null

  // A janela atravessa a virada do ano, então o início fica no ano da data
  // anterior e o fim no ano da data seguinte.
  const cruzaOAno = chaveDia(inicioRecesso) > chaveDia(fimRecesso)
  const inicio = `${cruzaOAno ? anterior.slice(0, 4) : atual.slice(0, 4)}-${inicioRecesso.slice(5)}`
  const fim = `${atual.slice(0, 4)}-${fimRecesso.slice(5)}`

  return { inicio, fim, semanas: Math.max(1, Math.round(distancia / passo) - 1) }
}

/** O calendário base da turma, com o salto do recesso marcado onde ele existe. */
export function montarDiasDoCalendario(turma: Turma, encontros: Encontro[]): DiaDoCalendario[] {
  const porData = new Map<string, Encontro>()
  for (const encontro of encontros) {
    if (encontro.status === 'remarcado' || encontro.status === 'cancelado') continue
    porData.set(encontro.data_prevista, encontro)
  }

  return turma.calendario_base.map((quando, indice): DiaDoCalendario => {
    const anterior = indice > 0 ? turma.calendario_base[indice - 1] : undefined
    const encontro = porData.get(quando)

    return {
      numero: indice + 1,
      data: quando,
      temEncontro: Boolean(encontro),
      encontro_id: encontro?.id ?? null,
      status: encontro?.status ?? null,
      tema: encontro?.tema ?? null,
      saltoDeRecesso: anterior ? saltoDeRecesso(anterior, quando, turma) : null,
    }
  })
}

// ------------------------------------------------------------- as respostas

export interface RespostaProgramas {
  programas: ProgramaNaLista[]
  /** Verdadeiro quando o que está na tela veio do arquivo de exemplo. */
  deExemplo: boolean
}

export interface RespostaTurmas {
  turmas: TurmaNaLista[]
  deExemplo: boolean
}

export interface FichaDaTurma {
  turma: TurmaNaLista
  participantes: ParticipanteNaFicha[]
  calendario: DiaDoCalendario[]
  encontros: EncontroNaLista[]
  entregaveis: EntregavelNaLista[]
  historico: RegistroHistoricoNaFicha[]
  /** A fila de `valor.vw_historico_valor_devido` para este programa. */
  devido: HistoricoValorDevido[]
}

export interface RespostaTurma {
  ficha: FichaDaTurma | null
  deExemplo: boolean
}

export interface RespostaEncontros {
  encontros: EncontroNaLista[]
  deExemplo: boolean
}

export interface FichaDoEncontro {
  encontro: EncontroNaLista
  turma: TurmaNaLista
  presencas: PresencaNaFicha[]
  ritual: ItemRitualNaFicha[]
  entregaveis: EntregavelNaLista[]
  /** As outras tentativas do mesmo número, da mais nova para a mais antiga. */
  tentativas: Encontro[]
}

export interface RespostaEncontro {
  ficha: FichaDoEncontro | null
  deExemplo: boolean
}

export interface RespostaEntregaveis {
  entregaveis: EntregavelNaLista[]
  deExemplo: boolean
}

// ------------------------------------------------------- montagem do exemplo

function programasDeExemplo(): ProgramaNaLista[] {
  return PROGRAMAS_EXEMPLO.map((programa): ProgramaNaLista => {
    const turmas = TURMAS_EXEMPLO.filter((turma) => turma.programa_id === programa.id)
    const cadeiras = turmas.reduce(
      (total, turma) =>
        total +
        participantesDaTurma(turma.id).filter((pessoa) => pessoa.status !== 'desligado').length,
      0,
    )

    return {
      ...programa,
      oferta_nome: OFERTA_DO_PROGRAMA[programa.id] ?? programa.nome,
      oferta_codigo: programa.oferta_id,
      conta_nome: programa.conta_id ? nomeDaConta(programa.conta_id) : null,
      responsavel_nome: nomeDaCasa(programa.responsavel_id),
      turmas: turmas.length,
      cadeiras_ocupadas: cadeiras,
    }
  })
}

function turmasDeExemplo(): TurmaNaLista[] {
  return TURMAS_EXEMPLO.map(turmaNaLista)
}

function fichaDaTurmaDeExemplo(turmaId: string): FichaDaTurma | null {
  const turma = TURMAS_EXEMPLO.find((linha) => linha.id === turmaId)
  if (!turma) return null

  const encontros = ENCONTROS_EXEMPLO.filter((encontro) => encontro.turma_id === turmaId)
  const programa = programaDaTurma(turma)

  const historico: RegistroHistoricoNaFicha[] = HISTORICO_EXEMPLO.filter(
    (registro) => registro.programa_id === turma.programa_id,
  ).map((registro) => ({
    ...registro,
    conta_nome: nomeDaConta(registro.conta_id),
    registrado_por_nome: nomeDaCasa(registro.registrado_por),
  }))

  return {
    turma: turmaNaLista(turma),
    participantes: participantesDaTurma(turmaId).map(participanteNaFicha),
    calendario: montarDiasDoCalendario(turma, encontros),
    encontros: encontros.map(encontroNaLista),
    entregaveis: ENTREGAVEIS_EXEMPLO.filter((item) => item.turma_id === turmaId).map(
      entregavelNaLista,
    ),
    historico,
    devido: DEVIDO_EXEMPLO.filter((linha) => linha.programa_id === (programa?.id ?? '')),
  }
}

function fichaDoEncontroDeExemplo(encontroId: string): FichaDoEncontro | null {
  const encontro = ENCONTROS_EXEMPLO.find((linha) => linha.id === encontroId)
  if (!encontro) return null

  const turma = TURMAS_EXEMPLO.find((linha) => linha.id === encontro.turma_id)
  if (!turma) return null

  const gente = new Map(participantesDaTurma(turma.id).map((pessoa) => [pessoa.id, pessoa]))

  const presencas: PresencaNaFicha[] = PRESENCAS_EXEMPLO.filter(
    (presenca) => presenca.encontro_id === encontroId,
  ).map((presenca) => {
    const pessoa = gente.get(presenca.participante_id)
    return {
      ...presenca,
      participante_nome: pessoa?.nome ?? 'Participante sem nome',
      conta_nome: nomeDaConta(pessoa?.conta_id ?? null),
      cadeira: pessoa?.cadeira ?? null,
    }
  })

  const ritual: ItemRitualNaFicha[] = RITUAL_EXEMPLO.filter(
    (item) => item.encontro_id === encontroId,
  ).map((item) => ({
    ...item,
    responsavel_exibido:
      (item.responsavel_participante_id
        ? gente.get(item.responsavel_participante_id)?.nome
        : null) ??
      item.responsavel_nome ??
      nomeDaCasa(item.responsavel_usuario_id),
  }))

  return {
    encontro: encontroNaLista(encontro),
    turma: turmaNaLista(turma),
    presencas,
    ritual,
    entregaveis: ENTREGAVEIS_EXEMPLO.filter((item) => item.encontro_id === encontroId).map(
      entregavelNaLista,
    ),
    tentativas: ENCONTROS_EXEMPLO.filter(
      (linha) =>
        linha.turma_id === encontro.turma_id &&
        linha.numero === encontro.numero &&
        linha.id !== encontro.id,
    ).sort((a, b) => b.tentativa - a.tentativa),
  }
}

function entregaveisDeExemplo(): EntregavelNaLista[] {
  return ENTREGAVEIS_EXEMPLO.map(entregavelNaLista)
}

function encontrosDeExemplo(): EncontroNaLista[] {
  return ENCONTROS_EXEMPLO.map(encontroNaLista)
}

// ------------------------------------------------------------ leitura do banco
// Quando o banco está ligado, é ele quem manda. Os nomes de conta, de oferta e
// de gente da casa são resolvidos em consulta própria e casados aqui, em vez de
// dependerem de apelido de chave estrangeira, que muda de nome com facilidade.

interface LinhaNome {
  id: string
  nome: string
}

function clienteDoBanco(): ClienteValor {
  const instancia = obterCliente()
  if (!instancia) throw new Error('Banco não configurado.')
  return instancia
}

async function mapaDeNomes(
  conexao: ClienteValor,
  tabela: string,
  ids: Array<string | null>,
): Promise<Map<string, string>> {
  const mapa = new Map<string, string>()
  const lista = Array.from(new Set(ids.filter((id): id is string => Boolean(id))))
  if (lista.length === 0) return mapa

  const { data, error } = await conexao
    .from(tabela)
    .select('id, nome')
    .in('id', lista)
    .returns<LinhaNome[]>()

  if (error) throw new Error(error.message)
  for (const linha of data ?? []) mapa.set(linha.id, linha.nome)
  return mapa
}

interface LinhaProgramaCurto {
  id: string
  codigo: string
  nome: string
  modalidade: TurmaNaLista['modalidade']
  oferta_id: string | null
  conta_id: string | null
}

interface LinhaEncontroCurto {
  id: string
  turma_id: string
  numero: number
  status: BrmStatusEncontro
}

/** Resolve tudo que a lista de turmas precisa mostrar, a partir das linhas cruas. */
async function completarTurmas(
  conexao: ClienteValor,
  turmas: Turma[],
): Promise<TurmaNaLista[]> {
  if (turmas.length === 0) return []

  const idsDeTurma = turmas.map((turma) => turma.id)

  const { data: programas, error: erroProgramas } = await conexao
    .from('programas')
    .select('id, codigo, nome, modalidade, oferta_id, conta_id')
    .in('id', Array.from(new Set(turmas.map((turma) => turma.programa_id))))
    .returns<LinhaProgramaCurto[]>()
  if (erroProgramas) throw new Error(erroProgramas.message)

  const { data: vinculos, error: erroVinculos } = await conexao
    .from('turmas_contas')
    .select('id, turma_id, conta_id, cadeiras_contratadas, eh_anfitria, entrou_em, saiu_em')
    .in('turma_id', idsDeTurma)
    .is('arquivado_em', null)
    .returns<Array<Omit<TurmaConta, 'conta_nome'>>>()
  if (erroVinculos) throw new Error(erroVinculos.message)

  const { data: gente, error: erroGente } = await conexao
    .from('participantes')
    .select('id, turma_id, status')
    .in('turma_id', idsDeTurma)
    .is('arquivado_em', null)
    .returns<Array<{ id: string; turma_id: string; status: string }>>()
  if (erroGente) throw new Error(erroGente.message)

  const { data: encontros, error: erroEncontros } = await conexao
    .from('encontros')
    .select('id, turma_id, numero, status')
    .in('turma_id', idsDeTurma)
    .is('arquivado_em', null)
    .returns<LinhaEncontroCurto[]>()
  if (erroEncontros) throw new Error(erroEncontros.message)

  const listaDeProgramas = programas ?? []
  const listaDeVinculos = vinculos ?? []

  const nomesDeConta = await mapaDeNomes(
    conexao,
    'contas',
    listaDeVinculos.map((vinculo) => vinculo.conta_id),
  )
  const nomesDeOferta = await mapaDeNomes(
    conexao,
    'ofertas',
    listaDeProgramas.map((programa) => programa.oferta_id),
  )
  const nomesDaCasa = await mapaDeNomes(conexao, 'usuarios', [
    ...turmas.map((turma) => turma.facilitador_id),
    ...turmas.map((turma) => turma.coordenador_id),
  ])

  return turmas.map((turma): TurmaNaLista => {
    const programa = listaDeProgramas.find((linha) => linha.id === turma.programa_id)
    const meus = (encontros ?? []).filter((encontro) => encontro.turma_id === turma.id)
    const realizados = meus.filter((encontro) => encontro.status === 'realizado').length
    const previstos = turma.encontros_previstos ?? meus.length

    return {
      ...turma,
      programa_nome: programa?.nome ?? 'sem programa',
      programa_codigo: programa?.codigo ?? '',
      oferta_nome: nomesDeOferta.get(programa?.oferta_id ?? '') ?? (programa?.nome ?? 'sem oferta'),
      modalidade: programa?.modalidade ?? 'dedicada',
      facilitador_nome: nomesDaCasa.get(turma.facilitador_id ?? '') ?? 'sem responsável',
      coordenador_nome: nomesDaCasa.get(turma.coordenador_id ?? '') ?? 'sem responsável',
      contas: listaDeVinculos
        .filter((vinculo) => vinculo.turma_id === turma.id)
        .map((vinculo) => ({
          ...vinculo,
          conta_nome: nomesDeConta.get(vinculo.conta_id) ?? 'sem conta',
        })),
      cadeiras_ocupadas: (gente ?? []).filter(
        (pessoa) => pessoa.turma_id === turma.id && pessoa.status !== 'desligado',
      ).length,
      encontros_realizados: realizados,
      encontros_restantes: Math.max(0, previstos - realizados),
    }
  })
}

/** Resolve o que a lista de encontros precisa, a partir das linhas cruas. */
async function completarEncontros(
  conexao: ClienteValor,
  encontros: Encontro[],
): Promise<EncontroNaLista[]> {
  if (encontros.length === 0) return []

  const idsDeTurma = Array.from(new Set(encontros.map((encontro) => encontro.turma_id)))

  const { data: turmas, error: erroTurmas } = await conexao
    .from('turmas')
    .select('id, codigo, programa_id')
    .in('id', idsDeTurma)
    .returns<Array<{ id: string; codigo: string; programa_id: string }>>()
  if (erroTurmas) throw new Error(erroTurmas.message)

  const listaDeTurmas = turmas ?? []

  const { data: programas, error: erroProgramas } = await conexao
    .from('programas')
    .select('id, nome')
    .in('id', Array.from(new Set(listaDeTurmas.map((turma) => turma.programa_id))))
    .returns<LinhaNome[]>()
  if (erroProgramas) throw new Error(erroProgramas.message)

  const { data: entregaveis, error: erroEntregaveis } = await conexao
    .from('entregaveis')
    .select('id, encontro_id')
    .in(
      'encontro_id',
      encontros.map((encontro) => encontro.id),
    )
    .is('arquivado_em', null)
    .returns<Array<{ id: string; encontro_id: string | null }>>()
  if (erroEntregaveis) throw new Error(erroEntregaveis.message)

  const nomesDaCasa = await mapaDeNomes(conexao, 'usuarios', [
    ...encontros.map((encontro) => encontro.conselheiro_id),
    ...encontros.map((encontro) => encontro.assessor_id),
  ])

  return encontros.map((encontro): EncontroNaLista => {
    const turma = listaDeTurmas.find((linha) => linha.id === encontro.turma_id)
    const programa = (programas ?? []).find((linha) => linha.id === turma?.programa_id)

    return {
      ...encontro,
      turma_codigo: turma?.codigo ?? 'sem turma',
      programa_nome: programa?.nome ?? 'sem programa',
      conselheiro_nome: nomesDaCasa.get(encontro.conselheiro_id ?? '') ?? 'sem responsável',
      assessor_nome: nomesDaCasa.get(encontro.assessor_id ?? '') ?? 'sem responsável',
      entregaveis: (entregaveis ?? []).filter((item) => item.encontro_id === encontro.id).length,
    }
  })
}

/** Resolve o que a lista de entregáveis precisa, a partir das linhas cruas. */
async function completarEntregaveis(
  conexao: ClienteValor,
  entregaveis: Entregavel[],
): Promise<EntregavelNaLista[]> {
  if (entregaveis.length === 0) return []

  const { data: turmas, error: erroTurmas } = await conexao
    .from('turmas')
    .select('id, codigo')
    .in('id', Array.from(new Set(entregaveis.map((item) => item.turma_id))))
    .returns<Array<{ id: string; codigo: string }>>()
  if (erroTurmas) throw new Error(erroTurmas.message)

  const idsDeEncontro = Array.from(
    new Set(entregaveis.map((item) => item.encontro_id).filter((id): id is string => Boolean(id))),
  )

  let encontros: Array<{ id: string; numero: number }> = []
  if (idsDeEncontro.length > 0) {
    const { data, error } = await conexao
      .from('encontros')
      .select('id, numero')
      .in('id', idsDeEncontro)
      .returns<Array<{ id: string; numero: number }>>()
    if (error) throw new Error(error.message)
    encontros = data ?? []
  }

  const idsDeParticipante = entregaveis.map((item) => item.produzido_por_participante_id)
  const nomesDeParticipante = await mapaDeNomes(conexao, 'participantes', idsDeParticipante)
  const nomesDaCasa = await mapaDeNomes(
    conexao,
    'usuarios',
    entregaveis.map((item) => item.produzido_por_usuario_id),
  )
  const nomesDeConta = await mapaDeNomes(
    conexao,
    'contas',
    entregaveis.map((item) => item.conta_id),
  )

  return entregaveis.map((item): EntregavelNaLista => ({
    ...item,
    turma_codigo: (turmas ?? []).find((turma) => turma.id === item.turma_id)?.codigo ?? 'sem turma',
    conta_nome: item.conta_id ? (nomesDeConta.get(item.conta_id) ?? 'sem conta') : null,
    encontro_numero: encontros.find((encontro) => encontro.id === item.encontro_id)?.numero ?? null,
    produzido_por_exibido:
      nomesDaCasa.get(item.produzido_por_usuario_id ?? '') ??
      nomesDeParticipante.get(item.produzido_por_participante_id ?? '') ??
      item.produzido_por_nome ??
      'sem registro',
  }))
}

async function lerProgramasDoBanco(): Promise<ProgramaNaLista[]> {
  const conexao = clienteDoBanco()

  const { data, error } = await conexao
    .from('programas')
    .select('*')
    .is('arquivado_em', null)
    .order('ano', { ascending: false })
    .returns<Programa[]>()
  if (error) throw new Error(error.message)

  const programas = data ?? []
  if (programas.length === 0) return []

  const { data: turmas, error: erroTurmas } = await conexao
    .from('turmas')
    .select('id, programa_id')
    .is('arquivado_em', null)
    .returns<Array<{ id: string; programa_id: string }>>()
  if (erroTurmas) throw new Error(erroTurmas.message)

  const listaDeTurmas = turmas ?? []

  const { data: gente, error: erroGente } = await conexao
    .from('participantes')
    .select('id, turma_id, status')
    .is('arquivado_em', null)
    .returns<Array<{ id: string; turma_id: string; status: string }>>()
  if (erroGente) throw new Error(erroGente.message)

  const nomesDeOferta = await mapaDeNomes(
    conexao,
    'ofertas',
    programas.map((programa) => programa.oferta_id),
  )
  const nomesDeConta = await mapaDeNomes(
    conexao,
    'contas',
    programas.map((programa) => programa.conta_id),
  )
  const nomesDaCasa = await mapaDeNomes(
    conexao,
    'usuarios',
    programas.map((programa) => programa.responsavel_id),
  )

  return programas.map((programa): ProgramaNaLista => {
    const minhas = listaDeTurmas.filter((turma) => turma.programa_id === programa.id)
    const meus = minhas.map((turma) => turma.id)

    return {
      ...programa,
      oferta_nome: nomesDeOferta.get(programa.oferta_id ?? '') ?? programa.nome,
      oferta_codigo: programa.oferta_id,
      conta_nome: programa.conta_id ? (nomesDeConta.get(programa.conta_id) ?? null) : null,
      responsavel_nome: nomesDaCasa.get(programa.responsavel_id ?? '') ?? 'sem responsável',
      turmas: minhas.length,
      cadeiras_ocupadas: (gente ?? []).filter(
        (pessoa) => meus.includes(pessoa.turma_id) && pessoa.status !== 'desligado',
      ).length,
    }
  })
}

async function lerTurmasDoBanco(): Promise<TurmaNaLista[]> {
  const conexao = clienteDoBanco()

  const { data, error } = await conexao
    .from('turmas')
    .select('*')
    .is('arquivado_em', null)
    .order('codigo')
    .returns<Turma[]>()
  if (error) throw new Error(error.message)

  return completarTurmas(conexao, data ?? [])
}

async function lerFichaDaTurmaDoBanco(turmaId: string): Promise<FichaDaTurma | null> {
  const conexao = clienteDoBanco()

  const { data, error } = await conexao
    .from('turmas')
    .select('*')
    .eq('id', turmaId)
    .is('arquivado_em', null)
    .returns<Turma[]>()
  if (error) throw new Error(error.message)

  const turma = (data ?? [])[0]
  if (!turma) return null

  const [completa] = await completarTurmas(conexao, [turma])
  if (!completa) return null

  const { data: gente, error: erroGente } = await conexao
    .from('participantes')
    .select('*')
    .eq('turma_id', turmaId)
    .is('arquivado_em', null)
    .order('cadeira')
    .returns<Participante[]>()
  if (erroGente) throw new Error(erroGente.message)

  const { data: encontros, error: erroEncontros } = await conexao
    .from('encontros')
    .select('*')
    .eq('turma_id', turmaId)
    .is('arquivado_em', null)
    .order('numero')
    .returns<Encontro[]>()
  if (erroEncontros) throw new Error(erroEncontros.message)

  const { data: entregaveis, error: erroEntregaveis } = await conexao
    .from('entregaveis')
    .select('*')
    .eq('turma_id', turmaId)
    .is('arquivado_em', null)
    .returns<Entregavel[]>()
  if (erroEntregaveis) throw new Error(erroEntregaveis.message)

  const { data: historico, error: erroHistorico } = await conexao
    .from('historico_valor')
    .select('*')
    .eq('programa_id', turma.programa_id)
    .is('arquivado_em', null)
    .order('ano', { ascending: false })
    .returns<RegistroHistoricoValor[]>()
  if (erroHistorico) throw new Error(erroHistorico.message)

  const { data: devido, error: erroDevido } = await conexao
    .from('vw_historico_valor_devido')
    .select('*')
    .eq('programa_id', turma.programa_id)
    .returns<Array<Omit<HistoricoValorDevido, 'conta_nome'>>>()
  if (erroDevido) throw new Error(erroDevido.message)

  const listaDeGente = gente ?? []
  const listaDoHistorico = historico ?? []
  const listaDoDevido = devido ?? []

  const nomesDeConta = await mapaDeNomes(conexao, 'contas', [
    ...listaDeGente.map((pessoa) => pessoa.conta_id),
    ...listaDoHistorico.map((registro) => registro.conta_id),
    ...listaDoDevido.map((linha) => linha.conta_id),
  ])
  const nomesDaCasa = await mapaDeNomes(
    conexao,
    'usuarios',
    listaDoHistorico.map((registro) => registro.registrado_por),
  )

  return {
    turma: completa,
    participantes: listaDeGente.map((pessoa) => ({
      ...pessoa,
      conta_nome: nomesDeConta.get(pessoa.conta_id ?? '') ?? 'sem conta',
      nome_exibido: pessoa.nome ?? 'Participante sem nome',
    })),
    calendario: montarDiasDoCalendario(turma, encontros ?? []),
    encontros: await completarEncontros(conexao, encontros ?? []),
    entregaveis: await completarEntregaveis(conexao, entregaveis ?? []),
    historico: listaDoHistorico.map((registro) => ({
      ...registro,
      conta_nome: nomesDeConta.get(registro.conta_id) ?? 'sem conta',
      registrado_por_nome: nomesDaCasa.get(registro.registrado_por ?? '') ?? 'sem responsável',
    })),
    devido: listaDoDevido.map((linha) => ({
      ...linha,
      conta_nome: nomesDeConta.get(linha.conta_id) ?? 'sem conta',
    })),
  }
}

async function lerEncontrosDoBanco(): Promise<EncontroNaLista[]> {
  const conexao = clienteDoBanco()

  const { data, error } = await conexao
    .from('encontros')
    .select('*')
    .is('arquivado_em', null)
    .order('data_prevista')
    .returns<Encontro[]>()
  if (error) throw new Error(error.message)

  return completarEncontros(conexao, data ?? [])
}

async function lerFichaDoEncontroDoBanco(encontroId: string): Promise<FichaDoEncontro | null> {
  const conexao = clienteDoBanco()

  const { data, error } = await conexao
    .from('encontros')
    .select('*')
    .eq('id', encontroId)
    .is('arquivado_em', null)
    .returns<Encontro[]>()
  if (error) throw new Error(error.message)

  const encontro = (data ?? [])[0]
  if (!encontro) return null

  const { data: turmas, error: erroTurma } = await conexao
    .from('turmas')
    .select('*')
    .eq('id', encontro.turma_id)
    .returns<Turma[]>()
  if (erroTurma) throw new Error(erroTurma.message)

  const turma = (turmas ?? [])[0]
  if (!turma) return null

  const [completa] = await completarTurmas(conexao, [turma])
  const [encontroCompleto] = await completarEncontros(conexao, [encontro])
  if (!completa || !encontroCompleto) return null

  const { data: presencas, error: erroPresencas } = await conexao
    .from('presencas')
    .select('*')
    .eq('encontro_id', encontroId)
    .is('arquivado_em', null)
    .returns<Presenca[]>()
  if (erroPresencas) throw new Error(erroPresencas.message)

  const { data: ritual, error: erroRitual } = await conexao
    .from('itens_ritual_semanal')
    .select('*')
    .eq('encontro_id', encontroId)
    .is('arquivado_em', null)
    .order('ordem')
    .returns<ItemRitualSemanal[]>()
  if (erroRitual) throw new Error(erroRitual.message)

  const { data: entregaveis, error: erroEntregaveis } = await conexao
    .from('entregaveis')
    .select('*')
    .eq('encontro_id', encontroId)
    .is('arquivado_em', null)
    .returns<Entregavel[]>()
  if (erroEntregaveis) throw new Error(erroEntregaveis.message)

  const { data: tentativas, error: erroTentativas } = await conexao
    .from('encontros')
    .select('*')
    .eq('turma_id', encontro.turma_id)
    .eq('numero', encontro.numero)
    .returns<Encontro[]>()
  if (erroTentativas) throw new Error(erroTentativas.message)

  const { data: gente, error: erroGente } = await conexao
    .from('participantes')
    .select('id, nome, conta_id, cadeira')
    .eq('turma_id', encontro.turma_id)
    .is('arquivado_em', null)
    .returns<Array<{ id: string; nome: string | null; conta_id: string | null; cadeira: number | null }>>()
  if (erroGente) throw new Error(erroGente.message)

  const listaDeGente = gente ?? []
  const nomesDeConta = await mapaDeNomes(
    conexao,
    'contas',
    listaDeGente.map((pessoa) => pessoa.conta_id),
  )
  const nomesDaCasa = await mapaDeNomes(
    conexao,
    'usuarios',
    (ritual ?? []).map((item) => item.responsavel_usuario_id),
  )

  return {
    encontro: encontroCompleto,
    turma: completa,
    presencas: (presencas ?? []).map((presenca): PresencaNaFicha => {
      const pessoa = listaDeGente.find((linha) => linha.id === presenca.participante_id)
      return {
        ...presenca,
        participante_nome: pessoa?.nome ?? 'Participante sem nome',
        conta_nome: nomesDeConta.get(pessoa?.conta_id ?? '') ?? 'sem conta',
        cadeira: pessoa?.cadeira ?? null,
      }
    }),
    ritual: (ritual ?? []).map((item): ItemRitualNaFicha => ({
      ...item,
      responsavel_exibido:
        listaDeGente.find((linha) => linha.id === item.responsavel_participante_id)?.nome ??
        item.responsavel_nome ??
        nomesDaCasa.get(item.responsavel_usuario_id ?? '') ??
        'sem responsável',
    })),
    entregaveis: await completarEntregaveis(conexao, entregaveis ?? []),
    tentativas: (tentativas ?? [])
      .filter((linha) => linha.id !== encontro.id)
      .sort((a, b) => b.tentativa - a.tentativa),
  }
}

async function lerEntregaveisDoBanco(): Promise<EntregavelNaLista[]> {
  const conexao = clienteDoBanco()

  const { data, error } = await conexao
    .from('entregaveis')
    .select('*')
    .is('arquivado_em', null)
    .order('data_entrega', { ascending: false })
    .returns<Entregavel[]>()
  if (error) throw new Error(error.message)

  return completarEntregaveis(conexao, data ?? [])
}

// ------------------------------------------------------------------ consultas
// Uma consulta por tela. Todas com a mesma promessa: banco primeiro, exemplo
// depois, e a tela sempre sabendo em qual dos dois está.

export function useProgramas(): UseQueryResult<RespostaProgramas, Error> {
  return useQuery<RespostaProgramas, Error>({
    queryKey: ['brm', 'programas', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { programas: programasDeExemplo(), deExemplo: true }
      return { programas: await lerProgramasDoBanco(), deExemplo: false }
    },
  })
}

export function useTurmas(): UseQueryResult<RespostaTurmas, Error> {
  return useQuery<RespostaTurmas, Error>({
    queryKey: ['brm', 'turmas', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { turmas: turmasDeExemplo(), deExemplo: true }
      return { turmas: await lerTurmasDoBanco(), deExemplo: false }
    },
  })
}

export function useTurma(turmaId: string | undefined): UseQueryResult<RespostaTurma, Error> {
  return useQuery<RespostaTurma, Error>({
    queryKey: ['brm', 'turma', turmaId ?? '', temBanco()],
    staleTime: 60_000,
    enabled: Boolean(turmaId),
    queryFn: async () => {
      if (!turmaId) return { ficha: null, deExemplo: !temBanco() }
      if (!temBanco()) return { ficha: fichaDaTurmaDeExemplo(turmaId), deExemplo: true }
      return { ficha: await lerFichaDaTurmaDoBanco(turmaId), deExemplo: false }
    },
  })
}

export function useEncontros(): UseQueryResult<RespostaEncontros, Error> {
  return useQuery<RespostaEncontros, Error>({
    queryKey: ['brm', 'encontros', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { encontros: encontrosDeExemplo(), deExemplo: true }
      return { encontros: await lerEncontrosDoBanco(), deExemplo: false }
    },
  })
}

export function useEncontro(encontroId: string | undefined): UseQueryResult<RespostaEncontro, Error> {
  return useQuery<RespostaEncontro, Error>({
    queryKey: ['brm', 'encontro', encontroId ?? '', temBanco()],
    staleTime: 60_000,
    enabled: Boolean(encontroId),
    queryFn: async () => {
      if (!encontroId) return { ficha: null, deExemplo: !temBanco() }
      if (!temBanco()) return { ficha: fichaDoEncontroDeExemplo(encontroId), deExemplo: true }
      return { ficha: await lerFichaDoEncontroDoBanco(encontroId), deExemplo: false }
    },
  })
}

export function useEntregaveis(): UseQueryResult<RespostaEntregaveis, Error> {
  return useQuery<RespostaEntregaveis, Error>({
    queryKey: ['brm', 'entregaveis', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { entregaveis: entregaveisDeExemplo(), deExemplo: true }
      return { entregaveis: await lerEntregaveisDoBanco(), deExemplo: false }
    },
  })
}
