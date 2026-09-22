import { createContext, useContext, useMemo, type ReactNode } from 'react'
import type { ServicoIA } from '@/ia/ServicoIA'
import { servicoIADeMentira } from '@/ia/servico-de-mentira'

const ContextoIA = createContext<ServicoIA>(servicoIADeMentira)

export interface PropsProvedorIA {
  /** Troque aqui quando a chave da API existir. Nenhum componente muda. */
  servico?: ServicoIA
  children: ReactNode
}

/** Entrega o serviço de IA para toda a árvore. O padrão é o de mentira. */
export function ProvedorIA({ servico, children }: PropsProvedorIA) {
  const valor = useMemo(() => servico ?? servicoIADeMentira, [servico])
  return <ContextoIA.Provider value={valor}>{children}</ContextoIA.Provider>
}

/** Serviço de IA em uso. */
export function useServicoIA(): ServicoIA {
  return useContext(ContextoIA)
}
