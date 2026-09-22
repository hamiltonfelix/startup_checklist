import { useCallback, useEffect, useId, useRef, useState } from 'react'
import { Botao } from '@/componentes/Botao'
import { useServicoIA } from '@/ia/contexto'
import type { CampoAssistido, ServicoIA, SugestaoIA } from '@/ia/ServicoIA'

/** Os três estados visíveis do botão, mais o de erro. */
export type EstadoIA = 'parado' | 'pensando' | 'pronto' | 'erro'

export interface PropsBotaoIA {
  /** Qual campo está pedindo ajuda. Define o texto que o serviço devolve. */
  campo: CampoAssistido
  /**
   * A única porta de entrada para o campo. Só é chamada quando a pessoa
   * aperta aceitar, ou usa o texto que ela mesma editou.
   */
  aoAceitar: (texto: string) => void
  /** O que já está escrito no campo, para a sugestão partir dali. */
  textoAtual?: string
  /** Contexto público do registro. Nada confidencial passa por aqui. */
  contexto?: Record<string, string | number | null>
  rotulo?: string
  desabilitado?: boolean
  /** Serviço específico. Sem isso, usa o do provedor. */
  servico?: ServicoIA
  className?: string
}

/**
 * Botão assistido, ao lado de cada campo que aceita ajuda.
 *
 * Três estados: parado, pensando e com sugestão pronta. Com a sugestão na
 * tela, a pessoa aceita, edita ou descarta.
 *
 * A regra que este componente existe para cumprir: nada entra no campo sem a
 * pessoa mandar. O texto proposto vive dentro desta caixa. `aoAceitar` só é
 * chamado por clique em aceitar, ou em usar o texto editado. Fechar a caixa,
 * apertar Escape, descartar ou sair da tela jogam a sugestão fora.
 */
export function BotaoIA({
  campo,
  aoAceitar,
  textoAtual,
  contexto,
  rotulo = 'Sugerir',
  desabilitado = false,
  servico,
  className,
}: PropsBotaoIA) {
  const servicoDoContexto = useServicoIA()
  const emUso = servico ?? servicoDoContexto

  const [estado, setEstado] = useState<EstadoIA>('parado')
  const [sugestao, setSugestao] = useState<SugestaoIA | null>(null)
  const [erro, setErro] = useState<string>('')
  const [editando, setEditando] = useState(false)
  const [rascunho, setRascunho] = useState('')

  const caixa = useRef<HTMLDivElement>(null)
  const botao = useRef<HTMLButtonElement>(null)
  const cancelador = useRef<AbortController | null>(null)
  const idCaixa = useId()

  const encerrar = useCallback(() => {
    cancelador.current?.abort()
    cancelador.current = null
    setEstado('parado')
    setSugestao(null)
    setEditando(false)
    setRascunho('')
    setErro('')
  }, [])

  // Escape fecha a caixa e joga a sugestão fora, sem escrever nada no campo.
  useEffect(() => {
    if (estado !== 'pronto' && estado !== 'erro') return

    const naTecla = (evento: KeyboardEvent) => {
      if (evento.key !== 'Escape') return
      evento.stopPropagation()
      encerrar()
      botao.current?.focus()
    }

    document.addEventListener('keydown', naTecla, true)
    return () => document.removeEventListener('keydown', naTecla, true)
  }, [estado, encerrar])

  // Clique fora também descarta. Nada é aproveitado.
  useEffect(() => {
    if (estado !== 'pronto' && estado !== 'erro') return

    const noClique = (evento: MouseEvent) => {
      const alvo = evento.target as Node
      if (caixa.current?.contains(alvo) || botao.current?.contains(alvo)) return
      encerrar()
    }

    document.addEventListener('mousedown', noClique)
    return () => document.removeEventListener('mousedown', noClique)
  }, [estado, encerrar])

  // Sair da tela com a consulta no ar cancela a consulta.
  useEffect(() => () => cancelador.current?.abort(), [])

  async function consultar() {
    if (!emUso.disponivel) {
      setErro('O assistente não está disponível nesta máquina.')
      setEstado('erro')
      return
    }

    cancelador.current?.abort()
    const controle = new AbortController()
    cancelador.current = controle

    setEstado('pensando')
    setErro('')
    setSugestao(null)

    try {
      const resposta = await emUso.sugerir(
        {
          campo,
          texto_atual: textoAtual,
          contexto,
        },
        controle.signal,
      )
      if (controle.signal.aborted) return
      setSugestao(resposta)
      setRascunho(resposta.texto)
      setEstado('pronto')
    } catch (falha) {
      if (controle.signal.aborted) return
      setErro(falha instanceof Error ? falha.message : 'Não foi possível trazer a sugestão.')
      setEstado('erro')
    }
  }

  function aceitar(texto: string) {
    const limpo = texto.trim()
    if (!limpo) return
    aoAceitar(limpo)
    encerrar()
    botao.current?.focus()
  }

  const classeBotao = [
    'ia__botao',
    estado === 'pensando' ? 'ia__botao--pensando' : '',
    estado === 'pronto' ? 'ia__botao--pronto' : '',
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ')

  const textoBotao =
    estado === 'pensando' ? 'Pensando' : estado === 'pronto' ? 'Sugestão pronta' : rotulo

  return (
    <div className="ia">
      <button
        ref={botao}
        type="button"
        className={classeBotao}
        onClick={() => {
          if (estado === 'pronto' || estado === 'erro') {
            encerrar()
            return
          }
          if (estado === 'pensando') return
          void consultar()
        }}
        disabled={desabilitado}
        aria-busy={estado === 'pensando' || undefined}
        aria-expanded={estado === 'pronto' || estado === 'erro'}
        aria-controls={estado === 'pronto' || estado === 'erro' ? idCaixa : undefined}
        title="Buscar uma sugestão de texto. Nada entra no campo sem você mandar."
      >
        {estado === 'pensando' ? (
          <span className="ia__giro" aria-hidden="true" />
        ) : (
          <span className="ia__faisca" aria-hidden="true">
            &#10022;
          </span>
        )}
        {textoBotao}
      </button>

      {/* O anúncio para leitor de tela acompanha os três estados. */}
      <span className="apenas-leitor" role="status" aria-live="polite">
        {estado === 'pensando' ? 'O assistente está preparando uma sugestão.' : null}
        {estado === 'pronto' ? 'Sugestão pronta. Escolha aceitar, editar ou descartar.' : null}
        {estado === 'erro' ? erro : null}
      </span>

      {estado === 'pronto' && sugestao ? (
        <div className="ia__sugestao" id={idCaixa} ref={caixa}>
          <div className="ia__sugestao-topo">
            <span className="ia__sugestao-rotulo">Sugestão do assistente</span>
            <button
              type="button"
              className="alarme__fechar"
              onClick={() => {
                encerrar()
                botao.current?.focus()
              }}
              aria-label="Descartar sugestão"
            >
              <span aria-hidden="true">&#215;</span>
            </button>
          </div>

          <div className="ia__sugestao-corpo">
            {editando ? (
              <>
                <label className="apenas-leitor" htmlFor={`${idCaixa}-edicao`}>
                  Texto da sugestão, aberto para edição
                </label>
                <textarea
                  id={`${idCaixa}-edicao`}
                  className="ia__sugestao-edicao"
                  value={rascunho}
                  onChange={(evento) => setRascunho(evento.target.value)}
                  autoFocus
                />
              </>
            ) : (
              <p className="ia__sugestao-texto">{sugestao.texto}</p>
            )}

            <p className="ia__aviso">
              {sugestao.origem} · {sugestao.aviso ?? 'Revise antes de aceitar.'} Nada entra no campo
              sem você mandar.
            </p>
          </div>

          <div className="ia__sugestao-acoes">
            {editando ? (
              <>
                <Botao tom="principal" tamanho="p" onClick={() => aceitar(rascunho)}>
                  Usar o texto editado
                </Botao>
                <Botao
                  tom="contorno"
                  tamanho="p"
                  onClick={() => {
                    setRascunho(sugestao.texto)
                    setEditando(false)
                  }}
                >
                  Voltar ao original
                </Botao>
              </>
            ) : (
              <>
                <Botao tom="principal" tamanho="p" onClick={() => aceitar(sugestao.texto)}>
                  Aceitar
                </Botao>
                <Botao tom="contorno" tamanho="p" onClick={() => setEditando(true)}>
                  Editar
                </Botao>
              </>
            )}
            <Botao
              tom="discreto"
              tamanho="p"
              onClick={() => {
                encerrar()
                botao.current?.focus()
              }}
            >
              Descartar
            </Botao>
          </div>
        </div>
      ) : null}

      {estado === 'erro' ? (
        <div className="ia__sugestao" id={idCaixa} ref={caixa}>
          <div className="ia__sugestao-topo">
            <span className="ia__sugestao-rotulo">O assistente não respondeu</span>
            <button
              type="button"
              className="alarme__fechar"
              onClick={() => {
                encerrar()
                botao.current?.focus()
              }}
              aria-label="Fechar aviso"
            >
              <span aria-hidden="true">&#215;</span>
            </button>
          </div>
          <p className="ia__erro">{erro}</p>
          <div className="ia__sugestao-acoes">
            <Botao tom="contorno" tamanho="p" onClick={() => void consultar()}>
              Tentar de novo
            </Botao>
          </div>
        </div>
      ) : null}
    </div>
  )
}
