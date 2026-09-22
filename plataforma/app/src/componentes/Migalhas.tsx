import { Fragment } from 'react'
import { Link } from 'react-router-dom'

export interface Migalha {
  rotulo: string
  /** Sem `para`, a migalha é o lugar onde a pessoa está agora. */
  para?: string
}

export interface PropsMigalhas {
  itens: Migalha[]
  className?: string
}

/**
 * Trilha de onde a pessoa está. O separador é o ponto médio da casa, nunca
 * traço, conforme a seção 2 do contrato técnico.
 */
export function Migalhas({ itens, className }: PropsMigalhas) {
  if (itens.length === 0) return null

  return (
    <nav className={`migalhas ${className ?? ''}`.trim()} aria-label="Trilha de navegação">
      <ol className="migalhas__lista">
        {itens.map((item, indice) => {
          const ultima = indice === itens.length - 1

          return (
            <Fragment key={`${item.rotulo}-${indice}`}>
              <li className="migalhas__item">
                {item.para && !ultima ? (
                  <Link className="migalhas__elo" to={item.para}>
                    {item.rotulo}
                  </Link>
                ) : (
                  <span className="migalhas__atual" aria-current={ultima ? 'page' : undefined}>
                    {item.rotulo}
                  </span>
                )}
                {!ultima ? (
                  <span className="migalhas__separador" aria-hidden="true">
                    &#183;
                  </span>
                ) : null}
              </li>
            </Fragment>
          )
        })}
      </ol>
    </nav>
  )
}
