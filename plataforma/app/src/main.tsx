import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import { App } from '@/App'
import { ProvedorIA } from '@/ia/contexto'
import { ProvedorSessao, ProvedorTema } from '@/sessao/contexto'

import '@/estilo/tokens.css'
import '@/estilo/base.css'
import '@/estilo/componentes.css'
import '@/estilo/layout.css'
import '@/estilo/paginas.css'

/**
 * Ponto de entrada da interface.
 *
 * A ordem dos provedores importa: tema por fora, porque ele mexe no elemento
 * raiz; depois a sessão, que o menu lê; depois o estado de servidor; e por
 * último o serviço de IA, que qualquer campo assistido alcança.
 */

const clienteDeConsultas = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 30_000,
    },
  },
})

const raiz = document.getElementById('raiz')
if (!raiz) {
  throw new Error('Elemento raiz não encontrado no documento.')
}

createRoot(raiz).render(
  <StrictMode>
    <ProvedorTema>
      <ProvedorSessao>
        <QueryClientProvider client={clienteDeConsultas}>
          <ProvedorIA>
            <BrowserRouter>
              <App />
            </BrowserRouter>
          </ProvedorIA>
        </QueryClientProvider>
      </ProvedorSessao>
    </ProvedorTema>
  </StrictMode>,
)
