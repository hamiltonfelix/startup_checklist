/// <reference types="vite/client" />

/** As únicas variáveis de ambiente que a interface lê. Nenhuma tem valor aqui. */
interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string
  readonly VITE_SUPABASE_ANON_KEY?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
