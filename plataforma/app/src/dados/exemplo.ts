/**
 * Dados de exemplo da interface.
 *
 * Servem enquanto o banco não está ligado nesta máquina. Toda empresa aqui é
 * claramente fictícia, e todo valor é redondo e inventado. Nenhum dado real de
 * cliente, nenhum telefone, nenhum endereço eletrônico, nenhum valor de
 * contrato de verdade, conforme a seção 11 do contrato técnico.
 *
 * O painel não guarda número pronto: ele calcula tudo a partir da lista de
 * negócios abaixo, com as mesmas regras que o banco aplica. Assim o exemplo
 * nunca fica incoerente consigo mesmo.
 */

import type {
  ChaveInvariante,
  Fase,
  ForecastCategoria,
  InvarianteHigiene,
  LinhaFase,
  LinhaForecast,
  NegocioEmRisco,
  OrigemLead,
  PainelPipeline,
  TipoArtefato,
} from '@/tipos/dominio'
import { ARTEFATO_DA_FASE } from '@/tipos/rotulos'

/** Um negócio de exemplo, com o bastante para o painel calcular tudo. */
export interface NegocioExemplo {
  id: string
  titulo: string
  conta_nome: string
  gerente_contas: string
  fase: Fase
  origem: OrigemLead
  valor_total: number
  data_decisao_cliente: string | null
  proximo_passo: string | null
  proximo_passo_data: string | null
  ultima_interacao: string | null
  /** Artefatos existentes no negócio, em qualquer status. */
  artefatos_registrados: TipoArtefato[]
  /** Artefatos validados com o cliente. Só estes contam para o forecast. */
  artefatos_validados: TipoArtefato[]
}

// ------------------------------------------------------------- datas úteis

const HOJE = new Date()

/** Data ISO a tantos dias de hoje. Número negativo anda para trás. */
function emDias(dias: number): string {
  const d = new Date(HOJE)
  d.setDate(d.getDate() + dias)
  return d.toISOString().slice(0, 10)
}

// --------------------------------------------------------- os negócios

export const NEGOCIOS_EXEMPLO: NegocioExemplo[] = [
  {
    id: 'ex-01',
    titulo: 'Conselho dedicado · ciclo de doze meses',
    conta_nome: 'Metalúrgica Aurora Fictícia',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 4,
    origem: 'indicacao_cliente',
    valor_total: 480000,
    data_decisao_cliente: emDias(21),
    proximo_passo: 'Reunião de assinatura com a diretoria',
    proximo_passo_data: emDias(7),
    ultima_interacao: emDias(-4),
    artefatos_registrados: ['plano_conta', 'plano_negocio', 'plano_trabalho', 'contrato_valor'],
    artefatos_validados: ['plano_conta', 'plano_negocio', 'plano_trabalho', 'contrato_valor'],
  },
  {
    id: 'ex-02',
    titulo: 'Negócios de Valor · turma dedicada',
    conta_nome: 'Transportes Serra Modelo',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 4,
    origem: 'evento',
    valor_total: 320000,
    data_decisao_cliente: emDias(14),
    proximo_passo: 'Conferir o nível do Contrato de Valor com o financeiro do cliente',
    proximo_passo_data: emDias(3),
    ultima_interacao: emDias(-9),
    artefatos_registrados: ['plano_conta', 'plano_negocio', 'plano_trabalho', 'contrato_valor'],
    artefatos_validados: ['plano_conta', 'plano_negocio', 'plano_trabalho', 'contrato_valor'],
  },
  {
    id: 'ex-03',
    titulo: 'Gestão de Valor · implantação do ciclo',
    conta_nome: 'Clínica Bem Viver Exemplo',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 3,
    origem: 'indicacao_parceiro',
    valor_total: 260000,
    data_decisao_cliente: emDias(38),
    proximo_passo: 'Validar o Plano de Trabalho com a sócia responsável',
    proximo_passo_data: emDias(5),
    ultima_interacao: emDias(-11),
    artefatos_registrados: ['plano_conta', 'plano_negocio', 'plano_trabalho'],
    artefatos_validados: ['plano_conta', 'plano_negocio', 'plano_trabalho'],
  },
  {
    id: 'ex-04',
    titulo: 'Liderança de Valor · turma compartilhada',
    conta_nome: 'Agro Vale Fictício',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 3,
    origem: 'prospeccao_ativa',
    valor_total: 180000,
    data_decisao_cliente: emDias(45),
    proximo_passo: 'Enviar a agenda da reunião de valor',
    proximo_passo_data: emDias(2),
    // Passou dos trinta dias sem conversa. Cai fora do pipeline auditado.
    ultima_interacao: emDias(-52),
    artefatos_registrados: ['plano_conta', 'plano_negocio', 'plano_trabalho'],
    artefatos_validados: ['plano_conta', 'plano_negocio'],
  },
  {
    id: 'ex-05',
    titulo: 'Mentoria de Valor para a diretoria',
    conta_nome: 'Construtora Horizonte Modelo',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 2,
    origem: 'rede_pessoal',
    valor_total: 140000,
    // Data da decisão do cliente no passado. Isso é dívida, não pipeline.
    data_decisao_cliente: emDias(-12),
    proximo_passo: 'Reapresentar o Plano de Negócio com os números do trimestre',
    proximo_passo_data: emDias(9),
    ultima_interacao: emDias(-6),
    artefatos_registrados: ['plano_conta', 'plano_negocio'],
    artefatos_validados: ['plano_conta', 'plano_negocio'],
  },
  {
    id: 'ex-06',
    titulo: 'Executivo de Valor · acompanhamento anual',
    conta_nome: 'Rede Sabor Fictícia',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 2,
    origem: 'inbound',
    valor_total: 120000,
    data_decisao_cliente: emDias(60),
    // Sem próximo passo com data. Falha a primeira invariante.
    proximo_passo: null,
    proximo_passo_data: null,
    ultima_interacao: emDias(-3),
    artefatos_registrados: ['plano_conta', 'plano_negocio'],
    artefatos_validados: ['plano_conta'],
  },
  {
    id: 'ex-07',
    titulo: 'Diagnóstico de gestão e desenho do ciclo',
    conta_nome: 'Softworks Exemplo',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 1,
    origem: 'base_instalada',
    valor_total: 90000,
    data_decisao_cliente: emDias(75),
    proximo_passo: 'Montar o Plano de Conta com a hipótese de valor',
    proximo_passo_data: emDias(4),
    ultima_interacao: emDias(-2),
    // Sem o Plano de Conta registrado, o artefato da fase 1 falta.
    artefatos_registrados: [],
    artefatos_validados: [],
  },
  {
    id: 'ex-08',
    titulo: 'Conselho compartilhado · vaga na turma da manhã',
    conta_nome: 'Têxtil Canção Fictícia',
    gerente_contas: 'Gerente de Contas de Exemplo',
    fase: 1,
    origem: 'licitacao_publica',
    valor_total: 60000,
    data_decisao_cliente: emDias(52),
    proximo_passo: 'Confirmar o porte e o tier sugerido da conta',
    proximo_passo_data: emDias(10),
    ultima_interacao: emDias(-16),
    artefatos_registrados: ['plano_conta'],
    artefatos_validados: [],
  },
]

// --------------------------------------------------- as regras do contrato

/**
 * Forecast por artefato validado com o cliente, nunca por probabilidade.
 * Seção 5 do contrato técnico.
 */
export function categoriaForecast(negocio: NegocioExemplo): ForecastCategoria {
  if (negocio.artefatos_validados.includes('contrato_valor')) return 'compromisso'
  if (negocio.artefatos_validados.includes('plano_trabalho')) return 'possivel'
  if (negocio.artefatos_validados.includes('plano_negocio')) return 'aberto'
  return 'fora'
}

/** As quatro invariantes de higiene, avaliadas uma a uma. Seção 6. */
export function avaliarInvariantes(negocio: NegocioExemplo): Record<ChaveInvariante, boolean> {
  const hoje = HOJE.toISOString().slice(0, 10)
  const limiteInteracao = emDias(-30)
  const artefatoDaFase = ARTEFATO_DA_FASE[negocio.fase]

  return {
    proximo_passo_com_data: Boolean(negocio.proximo_passo && negocio.proximo_passo_data),
    data_decisao_no_futuro: Boolean(
      negocio.data_decisao_cliente && negocio.data_decisao_cliente > hoje,
    ),
    interacao_em_30_dias: Boolean(
      negocio.ultima_interacao && negocio.ultima_interacao >= limiteInteracao,
    ),
    artefato_da_fase_registrado: Boolean(
      artefatoDaFase && negocio.artefatos_registrados.includes(artefatoDaFase),
    ),
  }
}

/** Verdadeiro quando o negócio passa nas quatro. Só então ele é auditado. */
export function passaNaHigiene(negocio: NegocioExemplo): boolean {
  return Object.values(avaliarInvariantes(negocio)).every(Boolean)
}

const DESCRICAO_INVARIANTE: Record<ChaveInvariante, { explicacao: string; pendencia: string }> = {
  proximo_passo_com_data: {
    explicacao: 'Todo negócio ativo tem próximo passo escrito e com data marcada.',
    pendencia: 'Sem próximo passo com data, o negócio para e ninguém percebe.',
  },
  data_decisao_no_futuro: {
    explicacao: 'A data da decisão do cliente está adiante de hoje.',
    pendencia: 'Data da decisão no passado é dívida, não pipeline. Renegocie ou arquive.',
  },
  interacao_em_30_dias: {
    explicacao: 'Houve conversa registrada com o cliente nos últimos trinta dias.',
    pendencia: 'Mais de trinta dias sem conversa significa negócio esfriando.',
  },
  artefato_da_fase_registrado: {
    explicacao: 'O artefato que comprova a fase atual já existe no sistema.',
    pendencia: 'Sem o artefato da fase, não há critério de saída verificável.',
  },
}

// ------------------------------------------------------- montagem do painel

/** Só as fases 1 a 4 entram no pipeline, conforme a seção 6. */
const FASES_DO_PIPELINE: Fase[] = [1, 2, 3, 4]

/** Monta o painel inteiro a partir da lista de negócios de exemplo. */
export function montarPainelDeExemplo(
  negocios: NegocioExemplo[] = NEGOCIOS_EXEMPLO,
): PainelPipeline {
  const ativos = negocios.filter((negocio) => FASES_DO_PIPELINE.includes(negocio.fase))
  const auditados = ativos.filter(passaNaHigiene)

  const somar = (lista: NegocioExemplo[]) =>
    lista.reduce((total, negocio) => total + negocio.valor_total, 0)

  const categorias: ForecastCategoria[] = ['compromisso', 'possivel', 'aberto', 'fora']
  const forecast: LinhaForecast[] = categorias.map((categoria) => {
    const daCategoria = ativos.filter((negocio) => categoriaForecast(negocio) === categoria)
    return { categoria, valor: somar(daCategoria), quantos: daCategoria.length }
  })

  const chaves: ChaveInvariante[] = [
    'proximo_passo_com_data',
    'data_decisao_no_futuro',
    'interacao_em_30_dias',
    'artefato_da_fase_registrado',
  ]

  const invariantes: InvarianteHigiene[] = chaves.map((chave) => {
    const cumprem = ativos.filter((negocio) => avaliarInvariantes(negocio)[chave]).length
    const descricao = DESCRICAO_INVARIANTE[chave]
    return {
      chave,
      nome: chave,
      explicacao: descricao.explicacao,
      cumprem,
      avaliados: ativos.length,
      pendencia: descricao.pendencia,
    }
  })

  const fases: LinhaFase[] = FASES_DO_PIPELINE.map((fase) => {
    const daFase = ativos.filter((negocio) => negocio.fase === fase)
    return {
      fase,
      declarado: somar(daFase),
      auditado: somar(daFase.filter(passaNaHigiene)),
      quantos: daFase.length,
    }
  })

  const negocios_em_risco: NegocioEmRisco[] = ativos
    .filter((negocio) => !passaNaHigiene(negocio))
    .map((negocio): NegocioEmRisco => {
      const leitura = avaliarInvariantes(negocio)
      const falhas = chaves.filter((chave) => !leitura[chave])
      return {
        id: negocio.id,
        titulo: negocio.titulo,
        conta_nome: negocio.conta_nome,
        fase: negocio.fase,
        valor_total: negocio.valor_total,
        data_decisao_cliente: negocio.data_decisao_cliente,
        proximo_passo: negocio.proximo_passo,
        proximo_passo_data: negocio.proximo_passo_data,
        ultima_interacao: negocio.ultima_interacao,
        criticidade: falhas.length >= 2 ? 'vermelho' : 'amarelo',
        falhas,
      }
    })
    .sort((a, b) => (b.valor_total ?? 0) - (a.valor_total ?? 0))

  return {
    resumo: {
      declarado: somar(ativos),
      auditado: somar(auditados),
      negocios_declarados: ativos.length,
      negocios_auditados: auditados.length,
      periodo_inicio: emDias(-30),
      periodo_fim: emDias(60),
    },
    forecast,
    invariantes,
    fases,
    negocios_em_risco,
  }
}
