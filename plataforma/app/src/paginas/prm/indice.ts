/**
 * Porta única das telas do PRM de Valor.
 *
 * O orquestrador liga as rotas lendo este arquivo:
 *
 *   /parceiros       → Parceiros
 *   /parceiros/:id   → Parceiro
 *   /indicacoes      → Indicacoes
 *   /comissoes       → Comissoes
 *
 * A entrada de menu `meus-parceiros` já nasce com `prefixo: true`, então o
 * caminho `/parceiros/*` cobre a lista e a ficha.
 */

export { Comissoes, ExtratosDeComissao, ReguaDaCasa, type PropsExtratos } from '@/paginas/prm/Comissoes'
export { Indicacoes, Protecao } from '@/paginas/prm/Indicacoes'
export { Parceiro } from '@/paginas/prm/Parceiro'
export { Parceiros } from '@/paginas/prm/Parceiros'
