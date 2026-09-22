import { useId, useRef, type ReactNode } from 'react'

export interface Aba {
  chave: string
  rotulo: string
  /** Número à direita do rótulo, do tipo quantos itens a aba tem. */
  contagem?: number
  desabilitada?: boolean
  conteudo: ReactNode
}

export interface PropsAbas {
  abas: Aba[]
  ativa: string
  aoTrocar: (chave: string) => void
  /** Nome do conjunto, lido por leitor de tela. */
  rotulo: string
  className?: string
}

/**
 * Abas no padrão da plataforma, com o teclado que o padrão manda: seta para
 * os lados anda de aba em aba, Início e Fim pulam para as pontas, e a aba
 * desabilitada é saltada.
 */
export function Abas({ abas, ativa, aoTrocar, rotulo, className }: PropsAbas) {
  const base = useId()
  const tiras = useRef<HTMLDivElement>(null)

  const habilitadas = abas.filter((aba) => !aba.desabilitada)

  function andar(passo: number) {
    if (habilitadas.length === 0) return
    const atual = habilitadas.findIndex((aba) => aba.chave === ativa)
    const proximo = habilitadas[(atual + passo + habilitadas.length) % habilitadas.length]
    if (!proximo) return
    aoTrocar(proximo.chave)
    tiras.current?.querySelector<HTMLButtonElement>(`#${CSS.escape(`${base}-tira-${proximo.chave}`)}`)?.focus()
  }

  function pularPara(posicao: 'inicio' | 'fim') {
    const alvo = posicao === 'inicio' ? habilitadas[0] : habilitadas[habilitadas.length - 1]
    if (!alvo) return
    aoTrocar(alvo.chave)
    tiras.current?.querySelector<HTMLButtonElement>(`#${CSS.escape(`${base}-tira-${alvo.chave}`)}`)?.focus()
  }

  const abaAtiva = abas.find((aba) => aba.chave === ativa)

  return (
    <div className={`abas ${className ?? ''}`.trim()}>
      <div
        className="abas__tiras"
        role="tablist"
        aria-label={rotulo}
        ref={tiras}
        onKeyDown={(evento) => {
          switch (evento.key) {
            case 'ArrowRight':
              evento.preventDefault()
              andar(1)
              break
            case 'ArrowLeft':
              evento.preventDefault()
              andar(-1)
              break
            case 'Home':
              evento.preventDefault()
              pularPara('inicio')
              break
            case 'End':
              evento.preventDefault()
              pularPara('fim')
              break
            default:
              break
          }
        }}
      >
        {abas.map((aba) => {
          const selecionada = aba.chave === ativa
          return (
            <button
              key={aba.chave}
              id={`${base}-tira-${aba.chave}`}
              type="button"
              role="tab"
              className="abas__tira"
              aria-selected={selecionada}
              aria-controls={`${base}-painel-${aba.chave}`}
              tabIndex={selecionada ? 0 : -1}
              disabled={aba.desabilitada}
              onClick={() => aoTrocar(aba.chave)}
            >
              {aba.rotulo}
              {typeof aba.contagem === 'number' ? (
                <span className="abas__contagem">{aba.contagem}</span>
              ) : null}
            </button>
          )
        })}
      </div>

      {abaAtiva ? (
        <div
          className="abas__painel"
          role="tabpanel"
          id={`${base}-painel-${abaAtiva.chave}`}
          aria-labelledby={`${base}-tira-${abaAtiva.chave}`}
          tabIndex={0}
        >
          {abaAtiva.conteudo}
        </div>
      ) : null}
    </div>
  )
}
