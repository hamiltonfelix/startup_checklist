export interface PropsCarregando {
  texto?: string
  /** Versão em linha, para ficar ao lado de um rótulo em vez de ocupar o bloco. */
  emLinha?: boolean
  className?: string
}

/**
 * Espera. O texto é anunciado por leitor de tela através de `role="status"`,
 * e o giro some quando a pessoa pediu menos movimento no sistema, pela regra
 * de `prefers-reduced-motion` em `base.css`.
 */
export function Carregando({ texto = 'Carregando', emLinha = false, className }: PropsCarregando) {
  return (
    <div
      className={`carregando${emLinha ? ' carregando--linha' : ''} ${className ?? ''}`.trim()}
      role="status"
      aria-live="polite"
    >
      <span className="carregando__giro" aria-hidden="true" />
      <span className="carregando__texto">{texto}</span>
    </div>
  )
}

export interface PropsEsqueleto {
  /** Quantas barras cinzentas desenhar. */
  linhas?: number
  className?: string
}

/** Esqueleto de conteúdo, para quando já se sabe a forma do que vai chegar. */
export function Esqueleto({ linhas = 4, className }: PropsEsqueleto) {
  const larguras = ['100%', '86%', '92%', '74%', '96%', '68%']

  return (
    <div className={`esqueleto ${className ?? ''}`.trim()} aria-hidden="true">
      {Array.from({ length: linhas }, (_, indice) => (
        <span
          key={indice}
          className="esqueleto__barra"
          style={{ width: larguras[indice % larguras.length] }}
        />
      ))}
    </div>
  )
}
