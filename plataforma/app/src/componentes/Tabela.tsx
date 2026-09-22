import type { ReactNode } from 'react'
import { Carregando } from '@/componentes/Carregando'
import { EstadoVazio } from '@/componentes/EstadoVazio'

export type AlinhamentoColuna = 'texto' | 'numero' | 'acoes'
export type SentidoOrdem = 'crescente' | 'decrescente'

export interface ColunaTabela<T> {
  /** Identificador da coluna. Serve de chave de React e de chave de ordenação. */
  chave: string
  rotulo: string
  alinhamento?: AlinhamentoColuna
  ordenavel?: boolean
  largura?: string
  conteudo: (linha: T, indice: number) => ReactNode
}

export interface PropsTabela<T> {
  colunas: Array<ColunaTabela<T>>
  linhas: T[]
  chaveDaLinha: (linha: T, indice: number) => string
  /** Frase curta acima da tabela, lida por leitor de tela junto com ela. */
  legenda?: string
  carregando?: boolean
  vazioTitulo?: string
  vazioTexto?: string
  vazioAcoes?: ReactNode
  ordenadaPor?: string
  sentido?: SentidoOrdem
  aoOrdenar?: (chave: string) => void
  aoEscolherLinha?: (linha: T, indice: number) => void
  linhaSelecionada?: (linha: T, indice: number) => boolean
  className?: string
}

const ARIA_ORDEM: Record<SentidoOrdem, 'ascending' | 'descending'> = {
  crescente: 'ascending',
  decrescente: 'descending',
}

/**
 * Tabela da casa. No telefone ela vira lista de fichas, e cada célula leva o
 * próprio rótulo pelo atributo `data-rotulo`, então nada de rolagem lateral
 * infinita em tela pequena.
 *
 * A ordenação é controlada de fora: o componente só avisa qual coluna foi
 * clicada. Quem ordena é quem tem os dados.
 */
export function Tabela<T>({
  colunas,
  linhas,
  chaveDaLinha,
  legenda,
  carregando = false,
  vazioTitulo = 'Nada por aqui',
  vazioTexto = 'Nenhum registro encontrado com os filtros atuais.',
  vazioAcoes,
  ordenadaPor,
  sentido = 'crescente',
  aoOrdenar,
  aoEscolherLinha,
  linhaSelecionada,
  className,
}: PropsTabela<T>) {
  if (carregando) {
    return <Carregando texto="Carregando registros" />
  }

  if (linhas.length === 0) {
    return <EstadoVazio titulo={vazioTitulo} texto={vazioTexto} acoes={vazioAcoes} />
  }

  return (
    <div className="tabela-envoltorio">
      <table className={`tabela tabela--responsiva ${className ?? ''}`.trim()}>
        {legenda ? <caption className="tabela__legenda">{legenda}</caption> : null}

        <thead>
          <tr>
            {colunas.map((coluna) => {
              const estaOrdenada = ordenadaPor === coluna.chave
              const classeColuna =
                coluna.alinhamento === 'numero'
                  ? 'tabela__coluna--numero'
                  : coluna.alinhamento === 'acoes'
                    ? 'tabela__coluna--acoes'
                    : ''

              return (
                <th
                  key={coluna.chave}
                  scope="col"
                  className={classeColuna}
                  style={coluna.largura ? { width: coluna.largura } : undefined}
                  aria-sort={
                    coluna.ordenavel
                      ? estaOrdenada
                        ? ARIA_ORDEM[sentido]
                        : 'none'
                      : undefined
                  }
                >
                  {coluna.ordenavel && aoOrdenar ? (
                    <button
                      type="button"
                      className="tabela__ordenar"
                      data-ordenada={estaOrdenada ? 'sim' : 'nao'}
                      onClick={() => aoOrdenar(coluna.chave)}
                    >
                      {coluna.rotulo}
                      <span className="tabela__seta" aria-hidden="true">
                        {estaOrdenada ? (sentido === 'crescente' ? '▴' : '▾') : '⇅'}
                      </span>
                    </button>
                  ) : (
                    coluna.rotulo
                  )}
                </th>
              )
            })}
          </tr>
        </thead>

        <tbody>
          {linhas.map((linha, indice) => {
            const selecionada = linhaSelecionada?.(linha, indice) ?? false
            const clicavel = Boolean(aoEscolherLinha)

            return (
              <tr
                key={chaveDaLinha(linha, indice)}
                aria-selected={selecionada || undefined}
                className={clicavel ? 'tabela__linha-clicavel' : undefined}
                tabIndex={clicavel ? 0 : undefined}
                onClick={clicavel ? () => aoEscolherLinha?.(linha, indice) : undefined}
                onKeyDown={
                  clicavel
                    ? (evento) => {
                        if (evento.key === 'Enter' || evento.key === ' ') {
                          evento.preventDefault()
                          aoEscolherLinha?.(linha, indice)
                        }
                      }
                    : undefined
                }
              >
                {colunas.map((coluna) => (
                  <td
                    key={coluna.chave}
                    data-rotulo={coluna.rotulo}
                    className={
                      coluna.alinhamento === 'numero'
                        ? 'tabela__celula--numero'
                        : coluna.alinhamento === 'acoes'
                          ? 'tabela__celula--acoes'
                          : undefined
                    }
                  >
                    {coluna.conteudo(linha, indice)}
                  </td>
                ))}
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
