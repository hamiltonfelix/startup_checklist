/**
 * Cliente Supabase da interface.
 *
 * Lê `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` do ambiente. Nenhuma chave
 * mora no repositório: o modelo fica em `.env.exemplo`, sem valor, e cada
 * máquina preenche o próprio `.env.local`, que o `.gitignore` bloqueia.
 *
 * Enquanto o banco não estiver ligado, `temBanco()` devolve falso e as telas
 * caem nos dados de exemplo de `src/dados/exemplo.ts`. A interface nunca
 * inventa permissão: quem decide o que cada um vê é a política de linha,
 * conforme a seção 8 do contrato técnico.
 */

import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL?.trim() ?? ''
const chaveAnonima = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim() ?? ''

/** Verdadeiro quando as duas variáveis de ambiente chegaram preenchidas. */
export function temBanco(): boolean {
  return url.length > 0 && chaveAnonima.length > 0
}

let instancia: SupabaseClient | null = null

/**
 * Devolve o cliente Supabase, ou `null` quando falta configuração.
 * Quem chama trata o nulo e mostra o aviso de banco desligado. Assim a tela
 * roda em qualquer máquina sem derrubar a aplicação inteira.
 */
export function obterCliente(): SupabaseClient | null {
  if (!temBanco()) return null
  if (instancia) return instancia

  instancia = createClient(url, chaveAnonima, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
    db: {
      // Todo o produto vive no esquema `valor`.
      schema: 'valor',
    },
    global: {
      headers: {
        'x-aplicacao': 'plataforma-de-valor',
      },
    },
  })

  return instancia
}

/**
 * Mesmo cliente, exigido. Use nas consultas que só rodam quando já se sabe
 * que o banco está ligado.
 */
export function exigirCliente(): SupabaseClient {
  const cliente = obterCliente()
  if (!cliente) {
    throw new Error(
      'Banco não configurado. Preencha VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY no ambiente.',
    )
  }
  return cliente
}

/** Mensagem única para a tela quando falta configuração de ambiente. */
export const AVISO_SEM_BANCO =
  'O banco ainda não está ligado nesta máquina. A tela mostra dados de exemplo, com empresas fictícias.'
