/**
 * Porta única das telas de governança do conselho.
 *
 * O orquestrador liga as rotas lendo este arquivo. As telas nunca são
 * importadas uma a uma de fora desta pasta, para que trocar a implementação de
 * uma delas não obrigue a mexer na tabela de rotas.
 *
 * Rotas que estas telas atendem:
 *
 *   /atas                  → Atas
 *   /atas/:id              → Ata
 *   /pautas                → Pauta
 *   /pautas/:id            → Pauta
 *   /pendencias            → Pendencias
 *   /pesquisas             → Pesquisas
 *   /historico-de-valor    → HistoricoDeValor
 *
 * As telas de `Ata` e `Pauta` leem o parâmetro `id` com `useParams`, e as duas
 * funcionam sem ele: sem parâmetro, `Ata` abre a mais recente e `Pauta` abre a
 * próxima reunião da turma.
 */

export { Ata } from '@/paginas/governanca/Ata'
export { Atas } from '@/paginas/governanca/Atas'
export { HistoricoDeValor } from '@/paginas/governanca/HistoricoDeValor'
export { Pauta } from '@/paginas/governanca/Pauta'
export { Pendencias } from '@/paginas/governanca/Pendencias'
export { Pesquisas } from '@/paginas/governanca/Pesquisas'
