import { useId } from 'react'

export interface PropsPaginacao {
  /** Página atual, contada a partir de 1. */
  pagina: number
  /** Quantos registros existem ao todo. */
  total: number
  /** Quantos registros cabem numa página. */
  porPagina: number
  aoTrocarPagina: (pagina: number) => void
  aoTrocarTamanho?: (porPagina: number) => void
  tamanhos?: number[]
  className?: string
}

/**
 * Monta a lista de páginas a mostrar, com reticência no meio quando são muitas.
 * O valor 0 marca a reticência.
 */
function montarPaginas(pagina: number, paginas: number): number[] {
  if (paginas <= 7) {
    return Array.from({ length: paginas }, (_, i) => i + 1)
  }

  const lista = new Set<number>([1, paginas, pagina, pagina - 1, pagina + 1])
  const ordenadas = [...lista].filter((n) => n >= 1 && n <= paginas).sort((a, b) => a - b)

  const saida: number[] = []
  let anterior = 0
  for (const numero of ordenadas) {
    if (anterior && numero - anterior > 1) saida.push(0)
    saida.push(numero)
    anterior = numero
  }
  return saida
}

/** Navegação entre páginas de uma lista. */
export function Paginacao({
  pagina,
  total,
  porPagina,
  aoTrocarPagina,
  aoTrocarTamanho,
  tamanhos = [10, 25, 50, 100],
  className,
}: PropsPaginacao) {
  const idTamanho = useId()
  const paginas = Math.max(1, Math.ceil(total / porPagina))
  const primeiro = total === 0 ? 0 : (pagina - 1) * porPagina + 1
  const ultimo = Math.min(pagina * porPagina, total)
  const lista = montarPaginas(pagina, paginas)

  return (
    <nav className={`paginacao ${className ?? ''}`.trim()} aria-label="Navegação entre páginas">
      <p className="paginacao__resumo">
        {total === 0
          ? 'Nenhum registro'
          : `Mostrando ${primeiro} a ${ultimo} de ${total} registros`}
      </p>

      <div className="paginacao__controles">
        <button
          type="button"
          className="paginacao__numero"
          onClick={() => aoTrocarPagina(pagina - 1)}
          disabled={pagina <= 1}
          aria-label="Página anterior"
        >
          <span aria-hidden="true">&#8249;</span>
        </button>

        {lista.map((numero, indice) =>
          numero === 0 ? (
            <span key={`reticencia-${indice}`} className="paginacao__reticencia" aria-hidden="true">
              &#8230;
            </span>
          ) : (
            <button
              key={numero}
              type="button"
              className="paginacao__numero"
              onClick={() => aoTrocarPagina(numero)}
              aria-current={numero === pagina ? 'page' : undefined}
              aria-label={`Página ${numero}`}
            >
              {numero}
            </button>
          ),
        )}

        <button
          type="button"
          className="paginacao__numero"
          onClick={() => aoTrocarPagina(pagina + 1)}
          disabled={pagina >= paginas}
          aria-label="Próxima página"
        >
          <span aria-hidden="true">&#8250;</span>
        </button>
      </div>

      {aoTrocarTamanho ? (
        <div className="paginacao__tamanho">
          <label htmlFor={idTamanho}>Por página</label>
          <select
            id={idTamanho}
            value={porPagina}
            onChange={(evento) => aoTrocarTamanho(Number(evento.target.value))}
          >
            {tamanhos.map((tamanho) => (
              <option key={tamanho} value={tamanho}>
                {tamanho}
              </option>
            ))}
          </select>
        </div>
      ) : null}
    </nav>
  )
}
