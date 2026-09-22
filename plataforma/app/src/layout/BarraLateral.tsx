import { NavLink, Link } from 'react-router-dom'
import { montarMenu } from '@/layout/menu'
import { useSessao } from '@/sessao/contexto'

export interface PropsBarraLateral {
  /** Em tela pequena, a barra vira gaveta e precisa fechar ao navegar. */
  aoNavegar?: () => void
  recolhida?: boolean
}

/**
 * Barra lateral com a navegação dos três produtos, mais Governança e
 * Configuração. O que aparece sai de `montarMenu`, que lê o perfil da sessão.
 * Nenhuma condição de perfil mora neste arquivo.
 */
export function BarraLateral({ aoNavegar, recolhida = false }: PropsBarraLateral) {
  const { sessao } = useSessao()
  const grupos = montarMenu(sessao.perfil)

  return (
    <aside className="lateral" aria-label="Navegação principal">
      <Link className="lateral__marca" to="/painel" onClick={aoNavegar}>
        <span className="lateral__selo" aria-hidden="true">
          F
        </span>
        <span className="lateral__nome">
          <b>Felix</b>
          <span>Plataforma de Valor</span>
        </span>
      </Link>

      <nav className="lateral__navegacao">
        {grupos.map((grupo) => (
          <div className="lateral__grupo" key={grupo.chave}>
            <span className="lateral__grupo-titulo" id={`grupo-${grupo.chave}`}>
              {grupo.titulo}
            </span>
            <ul aria-labelledby={`grupo-${grupo.chave}`}>
              {grupo.itens.map((item) => (
                <li key={item.chave}>
                  <NavLink
                    to={item.para}
                    end={!item.prefixo}
                    className={({ isActive }) =>
                      `lateral__item${isActive ? ' esta-em' : ''}`
                    }
                    onClick={aoNavegar}
                    title={recolhida ? item.rotulo : item.descricao}
                  >
                    <span className="lateral__icone" aria-hidden="true">
                      {item.icone}
                    </span>
                    <span className="lateral__texto">{item.rotulo}</span>
                    {recolhida ? <span className="apenas-leitor">{item.rotulo}</span> : null}
                  </NavLink>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </nav>

      <p className="lateral__rodape">
        {sessao.inquilino_nome}
        {sessao.parceiro_id ? ' · Portal do parceiro' : null}
      </p>
    </aside>
  )
}
