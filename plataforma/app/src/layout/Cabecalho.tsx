import { useId, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Selecao } from '@/componentes/Selecao'
import { useSessao, useTema } from '@/sessao/contexto'
import { iniciais, ROTULO_PERFIL } from '@/tipos/rotulos'
import type { PerfilUsuario } from '@/tipos/dominio'

export interface PropsCabecalho {
  aoAbrirGaveta: () => void
  aoRecolher: () => void
  recolhida: boolean
}

const PERFIS: PerfilUsuario[] = [
  'admin_master',
  'lider',
  'comercial',
  'gerente_contas',
  'conselheiro',
  'assessor',
  'financeiro',
  'parceiro',
]

/**
 * Barra de cima: abre a gaveta no telefone, recolhe a lateral no computador,
 * carrega a busca e mostra quem está dentro.
 *
 * O seletor de perfil existe só enquanto a autenticação não entra, para
 * conferir como cada um vê a plataforma. Ele sai quando o token do Supabase
 * passar a mandar no contexto de sessão.
 */
export function Cabecalho({ aoAbrirGaveta, aoRecolher, recolhida }: PropsCabecalho) {
  const { sessao, trocarPerfil } = useSessao()
  const { tema, alternar } = useTema()
  const navegar = useNavigate()
  const idBusca = useId()
  const [termo, setTermo] = useState('')

  return (
    <header className="cabecalho">
      <button
        type="button"
        className="cabecalho__botao-icone"
        onClick={aoAbrirGaveta}
        aria-label="Abrir a navegação"
      >
        <span aria-hidden="true">&#9776;</span>
      </button>

      <button
        type="button"
        className="cabecalho__botao-icone"
        onClick={aoRecolher}
        aria-label={recolhida ? 'Expandir a barra lateral' : 'Recolher a barra lateral'}
        aria-pressed={recolhida}
      >
        <span aria-hidden="true">{recolhida ? '»' : '«'}</span>
      </button>

      <form
        className="cabecalho__busca"
        role="search"
        onSubmit={(evento) => {
          evento.preventDefault()
          const limpo = termo.trim()
          if (limpo) navegar(`/busca?termo=${encodeURIComponent(limpo)}`)
        }}
      >
        <label className="apenas-leitor" htmlFor={idBusca}>
          Buscar conta, negócio ou pessoa
        </label>
        <span className="cabecalho__busca-lupa" aria-hidden="true">
          &#9906;
        </span>
        <input
          id={idBusca}
          type="search"
          value={termo}
          onChange={(evento) => setTermo(evento.target.value)}
          placeholder="Buscar conta, negócio ou pessoa"
          autoComplete="off"
        />
      </form>

      <span className="cabecalho__espaco" />

      <div className="cabecalho__direita">
        {/* Conferência de perfil. Sai quando a autenticação entrar. */}
        <div className="cabecalho__perfil">
          <Selecao
            rotulo="Ver como"
            value={sessao.perfil}
            onChange={(evento) => trocarPerfil(evento.target.value as PerfilUsuario)}
            opcoes={PERFIS.map((perfil) => ({ valor: perfil, rotulo: ROTULO_PERFIL[perfil] }))}
          />
        </div>

        <button
          type="button"
          className="cabecalho__botao-icone"
          onClick={alternar}
          aria-label={`Trocar o tema. Agora está em ${tema}.`}
          title={`Tema ${tema}`}
        >
          <span aria-hidden="true">{tema === 'escuro' ? '◑' : '◐'}</span>
        </button>

        <button type="button" className="cabecalho__usuario">
          <span className="cabecalho__avatar" aria-hidden="true">
            {iniciais(sessao.usuario_nome)}
          </span>
          <span className="cabecalho__identidade">
            <b>{sessao.usuario_nome}</b>
            <span>{ROTULO_PERFIL[sessao.perfil]}</span>
          </span>
        </button>
      </div>
    </header>
  )
}
