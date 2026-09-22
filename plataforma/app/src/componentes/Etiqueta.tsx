import type { HTMLAttributes, ReactNode } from 'react'

export type TomEtiqueta =
  | 'neutra'
  | 'marca'
  | 'realce'
  | 'verde'
  | 'amarela'
  | 'vermelha'
  | 'solida'

export interface PropsEtiqueta extends HTMLAttributes<HTMLSpanElement> {
  tom?: TomEtiqueta
  /** Ponto redondo à esquerda, para status que se lê de relance. */
  ponto?: boolean
  children: ReactNode
}

/**
 * Etiqueta de status. A cor nunca carrega sozinha o significado: o texto
 * dentro dela diz o que é, para quem não distingue as cores.
 */
export function Etiqueta({ tom = 'neutra', ponto = false, className, children, ...resto }: PropsEtiqueta) {
  return (
    <span {...resto} className={`etiqueta etiqueta--${tom} ${className ?? ''}`.trim()}>
      {ponto ? <span className="etiqueta__ponto" aria-hidden="true" /> : null}
      {children}
    </span>
  )
}
