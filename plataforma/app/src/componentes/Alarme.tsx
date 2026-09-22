import type { ReactNode } from 'react'

export type TomAlarme = 'informacao' | 'verde' | 'amarelo' | 'vermelho'

export interface PropsAlarme {
  tom?: TomAlarme
  titulo?: string
  children: ReactNode
  acoes?: ReactNode
  /** Quando existe, mostra o botão de fechar. */
  aoFechar?: () => void
  className?: string
}

const SINAL: Record<TomAlarme, string> = {
  informacao: 'i',
  verde: '✓',
  amarelo: '!',
  vermelho: '!',
}

const LEITURA: Record<TomAlarme, string> = {
  informacao: 'Aviso',
  verde: 'Tudo certo',
  amarelo: 'Atenção',
  vermelho: 'Alarme',
}

/**
 * Faixa de aviso nas três cores de alarme da casa, mais a de informação.
 * O vermelho entra como `alert`, que o leitor de tela anuncia na hora. Os
 * demais entram como `status`, que espera a pessoa terminar o que está fazendo.
 */
export function Alarme({ tom = 'informacao', titulo, children, acoes, aoFechar, className }: PropsAlarme) {
  return (
    <div
      className={`alarme alarme--${tom} ${className ?? ''}`.trim()}
      role={tom === 'vermelho' ? 'alert' : 'status'}
    >
      <span className="alarme__icone" aria-hidden="true">
        {SINAL[tom]}
      </span>

      <div className="alarme__conteudo">
        <span className="apenas-leitor">{LEITURA[tom]}. </span>
        {titulo ? <p className="alarme__titulo">{titulo}</p> : null}
        <div className="alarme__texto">{children}</div>
        {acoes ? <div className="alarme__acoes">{acoes}</div> : null}
      </div>

      {aoFechar ? (
        <button type="button" className="alarme__fechar" onClick={aoFechar} aria-label="Fechar aviso">
          <span aria-hidden="true">&#215;</span>
        </button>
      ) : null}
    </div>
  )
}
