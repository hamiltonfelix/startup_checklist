import type { HTMLAttributes, ReactNode } from 'react'

export type TomCartao = 'simples' | 'marca' | 'realce' | 'plano'

export interface PropsCartao extends Omit<HTMLAttributes<HTMLElement>, 'title'> {
  titulo?: ReactNode
  legenda?: ReactNode
  acoes?: ReactNode
  rodape?: ReactNode
  tom?: TomCartao
  /** Tira o respiro interno, para quando o corpo é uma tabela que vai de ponta a ponta. */
  semRespiro?: boolean
  children?: ReactNode
}

/** Caixa de conteúdo da casa: fio fino, topo colorido opcional, sombra discreta. */
export function Cartao({
  titulo,
  legenda,
  acoes,
  rodape,
  tom = 'simples',
  semRespiro = false,
  className,
  children,
  ...resto
}: PropsCartao) {
  const classes = [
    'cartao',
    tom === 'simples' ? '' : `cartao--${tom}`,
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <section {...resto} className={classes}>
      {titulo || acoes ? (
        <header className="cartao__cabecalho">
          <div className="cartao__titulos">
            {titulo ? <h3 className="cartao__titulo">{titulo}</h3> : null}
            {legenda ? <p className="cartao__legenda">{legenda}</p> : null}
          </div>
          {acoes ? <div className="cartao__acoes">{acoes}</div> : null}
        </header>
      ) : null}

      <div className={`cartao__corpo${semRespiro ? ' cartao__corpo--sem-respiro' : ''}`}>
        {children}
      </div>

      {rodape ? <footer className="cartao__rodape">{rodape}</footer> : null}
    </section>
  )
}
