import { forwardRef, useId, type ReactNode, type TextareaHTMLAttributes } from 'react'
import type { InputHTMLAttributes } from 'react'

type AtributosComuns = {
  rotulo: string
  auxilio?: string
  erro?: string
  obrigatorio?: boolean
  /** Espaço à direita do controle. É onde o `BotaoIA` mora. */
  acessorio?: ReactNode
  /** Mostra o contador de caracteres quando existe `maxLength`. */
  contador?: boolean
  valorAtual?: string
}

export interface PropsCampo
  extends AtributosComuns,
    Omit<InputHTMLAttributes<HTMLInputElement>, 'required'> {
  multiplas_linhas?: false
}

export interface PropsCampoTexto
  extends AtributosComuns,
    Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, 'required'> {
  multiplas_linhas: true
}

function Envoltorio({
  id,
  rotulo,
  auxilio,
  erro,
  obrigatorio,
  acessorio,
  contador,
  valorAtual,
  limite,
  children,
}: {
  id: string
  rotulo: string
  auxilio?: string
  erro?: string
  obrigatorio?: boolean
  acessorio?: ReactNode
  contador?: boolean
  valorAtual?: string
  limite?: number
  children: ReactNode
}) {
  return (
    <div className={`campo${erro ? ' campo--invalido' : ''}`}>
      <div className="campo__topo">
        <label className="campo__rotulo" htmlFor={id}>
          {rotulo}
          {obrigatorio ? (
            <span className="campo__obrigatorio" aria-hidden="true">
              *
            </span>
          ) : null}
          {obrigatorio ? <span className="apenas-leitor"> campo obrigatório</span> : null}
        </label>
        {contador && limite ? (
          <span className="campo__contador" aria-hidden="true">
            {(valorAtual ?? '').length} de {limite}
          </span>
        ) : null}
      </div>

      <div className="campo__linha">
        {children}
        {acessorio}
      </div>

      {auxilio && !erro ? (
        <p className="campo__auxilio" id={`${id}-auxilio`}>
          {auxilio}
        </p>
      ) : null}

      {erro ? (
        <p className="campo__erro" id={`${id}-erro`} role="alert">
          <span aria-hidden="true">!</span>
          {erro}
        </p>
      ) : null}
    </div>
  )
}

/**
 * Campo de texto de uma linha. O rótulo é sempre visível, nunca só a dica
 * dentro da caixa, porque a dica some quando a pessoa começa a digitar.
 */
export const Campo = forwardRef<HTMLInputElement, PropsCampo>(function Campo(
  {
    rotulo,
    auxilio,
    erro,
    obrigatorio,
    acessorio,
    contador,
    valorAtual,
    id,
    className,
    maxLength,
    ...resto
  },
  referencia,
) {
  const gerado = useId()
  const idCampo = id ?? gerado

  return (
    <Envoltorio
      id={idCampo}
      rotulo={rotulo}
      auxilio={auxilio}
      erro={erro}
      obrigatorio={obrigatorio}
      acessorio={acessorio}
      contador={contador}
      valorAtual={valorAtual}
      limite={maxLength}
    >
      <input
        {...resto}
        ref={referencia}
        id={idCampo}
        maxLength={maxLength}
        required={obrigatorio}
        aria-required={obrigatorio || undefined}
        aria-invalid={erro ? true : undefined}
        aria-describedby={erro ? `${idCampo}-erro` : auxilio ? `${idCampo}-auxilio` : undefined}
        className={`campo__controle ${className ?? ''}`.trim()}
      />
    </Envoltorio>
  )
})

/** Campo de texto de várias linhas, para próximo passo, resumo e descrição. */
export const CampoTexto = forwardRef<HTMLTextAreaElement, PropsCampoTexto>(function CampoTexto(
  {
    rotulo,
    auxilio,
    erro,
    obrigatorio,
    acessorio,
    contador,
    valorAtual,
    id,
    className,
    maxLength,
    multiplas_linhas: _multiplasLinhas,
    ...resto
  },
  referencia,
) {
  const gerado = useId()
  const idCampo = id ?? gerado

  return (
    <Envoltorio
      id={idCampo}
      rotulo={rotulo}
      auxilio={auxilio}
      erro={erro}
      obrigatorio={obrigatorio}
      acessorio={acessorio}
      contador={contador}
      valorAtual={valorAtual}
      limite={maxLength}
    >
      <textarea
        {...resto}
        ref={referencia}
        id={idCampo}
        maxLength={maxLength}
        required={obrigatorio}
        aria-required={obrigatorio || undefined}
        aria-invalid={erro ? true : undefined}
        aria-describedby={erro ? `${idCampo}-erro` : auxilio ? `${idCampo}-auxilio` : undefined}
        className={`campo__controle ${className ?? ''}`.trim()}
      />
    </Envoltorio>
  )
})
