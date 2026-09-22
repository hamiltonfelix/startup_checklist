import type { ReactNode } from 'react'

export interface PropsEstadoVazio {
  titulo: string
  texto?: string
  /** Marca redonda com um caractere. O padrão é o ponto médio da casa. */
  marca?: string
  acoes?: ReactNode
  className?: string
}

/**
 * Tela sem conteúdo. Nunca fica só um espaço em branco: diz o que houve e,
 * quando faz sentido, oferece a ação que resolve.
 */
export function EstadoVazio({
  titulo,
  texto,
  marca = '·',
  acoes,
  className,
}: PropsEstadoVazio) {
  return (
    <div className={`estado-vazio ${className ?? ''}`.trim()}>
      <span className="estado-vazio__marca" aria-hidden="true">
        {marca}
      </span>
      <p className="estado-vazio__titulo">{titulo}</p>
      {texto ? <p className="estado-vazio__texto">{texto}</p> : null}
      {acoes ? <div className="estado-vazio__acoes">{acoes}</div> : null}
    </div>
  )
}
