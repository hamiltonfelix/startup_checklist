import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { ContextoSessao, PerfilUsuario } from '@/tipos/dominio'

/**
 * Contexto de sessão da interface.
 *
 * Espelha os quatro parâmetros da seção 8 do contrato técnico:
 * `app.inquilino_id`, `app.usuario_id`, `app.perfil` e `app.parceiro_id`.
 * Em produção eles vêm do token do Supabase. Enquanto a autenticação não está
 * ligada, a sessão nasce do exemplo abaixo e o perfil pode ser trocado na
 * barra de cima, para conferir como cada um vê a plataforma.
 *
 * Aviso que vale para sempre: o perfil aqui serve para montar o menu e nada
 * mais. Quem decide o que cada um enxerga é a política de linha no banco.
 * A interface nunca esconde dado que o banco já entregou.
 */

const SESSAO_DE_EXEMPLO: ContextoSessao = {
  inquilino_id: '00000000-0000-4000-8000-000000000001',
  inquilino_nome: 'Felix Empresarial',
  usuario_id: '00000000-0000-4000-8000-000000000010',
  usuario_nome: 'Pessoa de Exemplo',
  perfil: 'lider',
  parceiro_id: null,
}

interface ValorSessao {
  sessao: ContextoSessao
  /** Só para conferência de tela enquanto a autenticação não entra. */
  trocarPerfil: (perfil: PerfilUsuario) => void
}

const Contexto = createContext<ValorSessao | null>(null)

export function ProvedorSessao({
  inicial = SESSAO_DE_EXEMPLO,
  children,
}: {
  inicial?: ContextoSessao
  children: ReactNode
}) {
  const [sessao, setSessao] = useState<ContextoSessao>(inicial)

  const trocarPerfil = useCallback((perfil: PerfilUsuario) => {
    setSessao((anterior) => ({
      ...anterior,
      perfil,
      // O `parceiro_id` só existe quando o perfil é parceiro.
      parceiro_id: perfil === 'parceiro' ? '00000000-0000-4000-8000-000000000099' : null,
      usuario_nome: perfil === 'parceiro' ? 'Parceiro de Exemplo' : 'Pessoa de Exemplo',
    }))
  }, [])

  const valor = useMemo<ValorSessao>(() => ({ sessao, trocarPerfil }), [sessao, trocarPerfil])

  return <Contexto.Provider value={valor}>{children}</Contexto.Provider>
}

export function useSessao(): ValorSessao {
  const valor = useContext(Contexto)
  if (!valor) {
    throw new Error('useSessao precisa estar dentro de ProvedorSessao.')
  }
  return valor
}

// ------------------------------------------------------------------- tema

export type Tema = 'claro' | 'escuro' | 'sistema'

const CHAVE_TEMA = 'felix.tema'

interface ValorTema {
  tema: Tema
  definirTema: (tema: Tema) => void
  /** Alterna entre claro e escuro, partindo do que o sistema prefere. */
  alternar: () => void
}

const ContextoTema = createContext<ValorTema | null>(null)

function lerTemaSalvo(): Tema {
  if (typeof window === 'undefined') return 'sistema'
  const salvo = window.localStorage.getItem(CHAVE_TEMA)
  return salvo === 'claro' || salvo === 'escuro' ? salvo : 'sistema'
}

export function ProvedorTema({ children }: { children: ReactNode }) {
  const [tema, setTema] = useState<Tema>(lerTemaSalvo)

  useEffect(() => {
    const raiz = document.documentElement
    if (tema === 'sistema') {
      raiz.removeAttribute('data-tema')
      window.localStorage.removeItem(CHAVE_TEMA)
    } else {
      raiz.setAttribute('data-tema', tema)
      window.localStorage.setItem(CHAVE_TEMA, tema)
    }
  }, [tema])

  const alternar = useCallback(() => {
    setTema((anterior) => {
      if (anterior === 'sistema') {
        const sistemaEscuro = window.matchMedia('(prefers-color-scheme: dark)').matches
        return sistemaEscuro ? 'claro' : 'escuro'
      }
      return anterior === 'claro' ? 'escuro' : 'claro'
    })
  }, [])

  const valor = useMemo<ValorTema>(
    () => ({ tema, definirTema: setTema, alternar }),
    [tema, alternar],
  )

  return <ContextoTema.Provider value={valor}>{children}</ContextoTema.Provider>
}

export function useTema(): ValorTema {
  const valor = useContext(ContextoTema)
  if (!valor) {
    throw new Error('useTema precisa estar dentro de ProvedorTema.')
  }
  return valor
}
