import { forwardRef, useId, type ReactNode, type SelectHTMLAttributes } from 'react'

export interface OpcaoSelecao {
  valor: string
  rotulo: string
  desabilitada?: boolean
}

export interface PropsSelecao extends Omit<SelectHTMLAttributes<HTMLSelectElement>, 'required'> {
  rotulo: string
  opcoes: OpcaoSelecao[]
  auxilio?: string
  erro?: string
  obrigatorio?: boolean
  /** Primeira linha neutra, do tipo "Todas as fases". */
  vazio?: string
  acessorio?: ReactNode
}

/**
 * Selecão de uma opção. Usa o `select` do sistema de propósito: ele já resolve
 * teclado, leitor de tela e o teclado do telefone melhor que qualquer lista
 * desenhada à mão.
 */
export const Selecao = forwardRef<HTMLSelectElement, PropsSelecao>(function Selecao(
  { rotulo, opcoes, auxilio, erro, obrigatorio, vazio, acessorio, id, className, ...resto },
  referencia,
) {
  const gerado = useId()
  const idCampo = id ?? gerado

  return (
    <div className={`campo${erro ? ' selecao--invalida campo--invalido' : ''}`}>
      <div className="campo__topo">
        <label className="campo__rotulo" htmlFor={idCampo}>
          {rotulo}
          {obrigatorio ? (
            <span className="campo__obrigatorio" aria-hidden="true">
              *
            </span>
          ) : null}
          {obrigatorio ? <span className="apenas-leitor"> campo obrigatório</span> : null}
        </label>
      </div>

      <div className="campo__linha">
        <div className="selecao__caixa">
          <select
            {...resto}
            ref={referencia}
            id={idCampo}
            required={obrigatorio}
            aria-required={obrigatorio || undefined}
            aria-invalid={erro ? true : undefined}
            aria-describedby={
              erro ? `${idCampo}-erro` : auxilio ? `${idCampo}-auxilio` : undefined
            }
            className={`selecao__controle ${className ?? ''}`.trim()}
          >
            {vazio ? <option value="">{vazio}</option> : null}
            {opcoes.map((opcao) => (
              <option key={opcao.valor} value={opcao.valor} disabled={opcao.desabilitada}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
          <span className="selecao__seta" aria-hidden="true">
            &#9662;
          </span>
        </div>
        {acessorio}
      </div>

      {auxilio && !erro ? (
        <p className="campo__auxilio" id={`${idCampo}-auxilio`}>
          {auxilio}
        </p>
      ) : null}

      {erro ? (
        <p className="campo__erro" id={`${idCampo}-erro`} role="alert">
          <span aria-hidden="true">!</span>
          {erro}
        </p>
      ) : null}
    </div>
  )
})
