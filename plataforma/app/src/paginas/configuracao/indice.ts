/**
 * Porta única das telas de Configuração.
 *
 * O orquestrador liga as rotas lendo este arquivo:
 *
 *   /configuracao/usuarios          → Usuarios
 *   /configuracao/ofertas           → Ofertas
 *   /configuracao/regras-e-alertas  → RegrasEAlertas
 *
 * A tela de Identidade já existe, em `src/paginas/Estilo.tsx`, e não é destas.
 */

export { Ofertas } from '@/paginas/configuracao/Ofertas'
export { RegrasEAlertas, valorDoPrazo } from '@/paginas/configuracao/RegrasEAlertas'
export { Usuarios } from '@/paginas/configuracao/Usuarios'
