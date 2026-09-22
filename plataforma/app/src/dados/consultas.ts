/**
 * Consultas de servidor, com TanStack Query.
 *
 * Uma regra só: quando o banco está ligado, lê do banco. Quando não está,
 * cai nos dados de exemplo e diz isso na tela. Nunca mistura os dois sem
 * avisar, e nunca finge que exemplo é dado real.
 *
 * O cálculo do pipeline vive aqui porque ainda não existe visão de banco para
 * ele. Quando a visão nascer, esta função passa a só ler a visão, e as regras
 * de `src/dados/exemplo.ts` continuam servindo de conferência.
 */

import { useQuery, type UseQueryResult } from '@tanstack/react-query'
import { obterCliente, temBanco } from '@/dados/cliente'
import {
  montarPainelDeExemplo,
  type NegocioExemplo,
} from '@/dados/exemplo'
import type { Fase, PainelPipeline, TipoArtefato } from '@/tipos/dominio'

export interface RespostaPainel {
  painel: PainelPipeline
  /** Verdadeiro quando o que está na tela veio do arquivo de exemplo. */
  deExemplo: boolean
}

/** Linha crua de `valor.negocios` com o mínimo que o painel precisa. */
interface LinhaNegocio {
  id: string
  titulo: string
  fase: number
  valor_total: number | string | null
  data_decisao_cliente: string | null
  proximo_passo: string | null
  proximo_passo_data: string | null
  ultima_interacao: string | null
  contas: { nome: string } | { nome: string }[] | null
}

/** Linha crua de `valor.artefatos`. */
interface LinhaArtefato {
  negocio_id: string
  tipo: TipoArtefato
  status: string
}

function nomeDaConta(contas: LinhaNegocio['contas']): string {
  if (!contas) return 'Conta sem nome'
  if (Array.isArray(contas)) return contas[0]?.nome ?? 'Conta sem nome'
  return contas.nome
}

async function lerDoBanco(): Promise<PainelPipeline> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data: negocios, error: erroNegocios } = await cliente
    .from('negocios')
    .select(
      'id, titulo, fase, valor_total, data_decisao_cliente, proximo_passo, proximo_passo_data, ultima_interacao, contas(nome)',
    )
    .is('arquivado_em', null)
    .gte('fase', 1)
    .lte('fase', 4)
    .returns<LinhaNegocio[]>()

  if (erroNegocios) throw new Error(erroNegocios.message)

  const identificadores = (negocios ?? []).map((linha) => linha.id)

  let artefatos: LinhaArtefato[] = []
  if (identificadores.length > 0) {
    const { data, error } = await cliente
      .from('artefatos')
      .select('negocio_id, tipo, status')
      .is('arquivado_em', null)
      .in('negocio_id', identificadores)
      .returns<LinhaArtefato[]>()

    if (error) throw new Error(error.message)
    artefatos = data ?? []
  }

  const comoExemplo: NegocioExemplo[] = (negocios ?? []).map((linha) => {
    const meus = artefatos.filter((artefato) => artefato.negocio_id === linha.id)
    return {
      id: linha.id,
      titulo: linha.titulo,
      conta_nome: nomeDaConta(linha.contas),
      gerente_contas: '',
      fase: linha.fase as Fase,
      origem: 'outro',
      valor_total: Number(linha.valor_total ?? 0),
      data_decisao_cliente: linha.data_decisao_cliente,
      proximo_passo: linha.proximo_passo,
      proximo_passo_data: linha.proximo_passo_data,
      ultima_interacao: linha.ultima_interacao,
      artefatos_registrados: meus.map((artefato) => artefato.tipo),
      artefatos_validados: meus
        .filter((artefato) => artefato.status === 'validado_com_cliente')
        .map((artefato) => artefato.tipo),
    }
  })

  return montarPainelDeExemplo(comoExemplo)
}

/** O painel do pipeline, do banco ou do exemplo. */
export function usePainelPipeline(): UseQueryResult<RespostaPainel, Error> {
  return useQuery<RespostaPainel, Error>({
    queryKey: ['painel', 'pipeline', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        return { painel: montarPainelDeExemplo(), deExemplo: true }
      }
      return { painel: await lerDoBanco(), deExemplo: false }
    },
  })
}
