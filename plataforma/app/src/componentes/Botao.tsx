import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react'

export type TomBotao = 'principal' | 'realce' | 'contorno' | 'discreto' | 'perigo'
export type TamanhoBotao = 'pp' | 'p' | 'm' | 'g'

export interface PropsBotao extends ButtonHTMLAttributes<HTMLButtonElement> {
  tom?: TomBotao
  tamanho?: TamanhoBotao
  /** Troca o ícone por um giro e desliga o clique, sem mudar a largura de lugar. */
  carregando?: boolean
  largo?: boolean
  icone?: ReactNode
}

/**
 * Botão da casa. Sempre elemento `button` de verdade, então tabulação, Enter,
 * barra de espaço e leitor de tela funcionam sem remendo.
 */
export const Botao = forwardRef<HTMLButtonElement, PropsBotao>(function Botao(
  {
    tom = 'contorno',
    tamanho = 'm',
    carregando = false,
    largo = false,
    icone,
    className,
    children,
    disabled,
    type = 'button',
    ...resto
  },
  referencia,
) {
  const classes = [
    'botao',
    `botao--${tom}`,
    tamanho === 'm' ? '' : `botao--${tamanho}`,
    largo ? 'botao--largo' : '',
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <button
      {...resto}
      ref={referencia}
      type={type}
      className={classes}
      disabled={disabled || carregando}
      aria-busy={carregando || undefined}
    >
      {carregando ? <span className="botao__giro" aria-hidden="true" /> : icone}
      {children}
    </button>
  )
})
