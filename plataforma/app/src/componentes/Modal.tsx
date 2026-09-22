import { useCallback, useEffect, useId, useRef, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

export type TamanhoModal = 'p' | 'm' | 'g'

export interface PropsModal {
  aberto: boolean
  aoFechar: () => void
  titulo: string
  legenda?: string
  children: ReactNode
  rodape?: ReactNode
  tamanho?: TamanhoModal
  /** Quando falso, clicar fora não fecha. Use em formulário com texto digitado. */
  fechaNoFundo?: boolean
}

const FOCAVEIS = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled]):not([type="hidden"])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(', ')

/**
 * Janela sobreposta. Cumpre o básico de acessibilidade sem biblioteca:
 * fecha com Escape, prende a tabulação dentro dela enquanto está aberta,
 * devolve o foco a quem a abriu, e trava a rolagem do fundo.
 */
export function Modal({
  aberto,
  aoFechar,
  titulo,
  legenda,
  children,
  rodape,
  tamanho = 'm',
  fechaNoFundo = true,
}: PropsModal) {
  const caixa = useRef<HTMLDivElement>(null)
  const focoAnterior = useRef<HTMLElement | null>(null)
  const idTitulo = useId()
  const idLegenda = useId()

  const prenderFoco = useCallback((evento: KeyboardEvent) => {
    const raiz = caixa.current
    if (!raiz) return

    const lista = Array.from(raiz.querySelectorAll<HTMLElement>(FOCAVEIS)).filter(
      (elemento) => elemento.offsetParent !== null || elemento === document.activeElement,
    )
    if (lista.length === 0) {
      evento.preventDefault()
      return
    }

    const primeiro = lista[0]
    const ultimo = lista[lista.length - 1]
    if (!primeiro || !ultimo) return

    if (evento.shiftKey && document.activeElement === primeiro) {
      evento.preventDefault()
      ultimo.focus()
    } else if (!evento.shiftKey && document.activeElement === ultimo) {
      evento.preventDefault()
      primeiro.focus()
    }
  }, [])

  useEffect(() => {
    if (!aberto) return

    focoAnterior.current = document.activeElement as HTMLElement | null

    const naTecla = (evento: KeyboardEvent) => {
      if (evento.key === 'Escape') {
        evento.stopPropagation()
        aoFechar()
        return
      }
      if (evento.key === 'Tab') {
        prenderFoco(evento)
      }
    }

    document.addEventListener('keydown', naTecla, true)

    const rolagemAnterior = document.body.style.overflow
    document.body.style.overflow = 'hidden'

    // Foco no primeiro elemento útil da janela, ou na própria janela.
    const relogio = window.setTimeout(() => {
      const raiz = caixa.current
      const alvo = raiz?.querySelector<HTMLElement>(FOCAVEIS)
      ;(alvo ?? raiz)?.focus()
    }, 0)

    return () => {
      window.clearTimeout(relogio)
      document.removeEventListener('keydown', naTecla, true)
      document.body.style.overflow = rolagemAnterior
      focoAnterior.current?.focus()
    }
  }, [aberto, aoFechar, prenderFoco])

  if (!aberto) return null

  return createPortal(
    <div
      className="modal__fundo"
      onMouseDown={(evento) => {
        if (fechaNoFundo && evento.target === evento.currentTarget) aoFechar()
      }}
    >
      <div
        className={`modal${tamanho === 'm' ? '' : ` modal--${tamanho}`}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={idTitulo}
        aria-describedby={legenda ? idLegenda : undefined}
        ref={caixa}
        tabIndex={-1}
      >
        <header className="modal__cabecalho">
          <div>
            <h2 className="modal__titulo" id={idTitulo}>
              {titulo}
            </h2>
            {legenda ? (
              <p className="modal__legenda" id={idLegenda}>
                {legenda}
              </p>
            ) : null}
          </div>
          <button type="button" className="modal__fechar" onClick={aoFechar} aria-label="Fechar janela">
            <span aria-hidden="true">&#215;</span>
          </button>
        </header>

        <div className="modal__corpo">{children}</div>

        {rodape ? <footer className="modal__rodape">{rodape}</footer> : null}
      </div>
    </div>,
    document.body,
  )
}
