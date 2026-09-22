/**
 * Porta única das telas do BRM de Valor.
 *
 * O orquestrador liga as rotas lendo este arquivo, e não cada tela uma a uma.
 * Quem acrescentar tela aqui acrescenta a linha em `ROTAS_BRM` junto, para que
 * nenhuma tela nasça sem endereço e nenhum endereço aponte para o vazio.
 *
 * As entradas de menu que estas rotas atendem, em `src/layout/menu.ts`, são
 * `programas`, `turmas`, `encontros` e `entregaveis`, todas com `prefixo`
 * verdadeiro, então as fichas abaixo de cada caminho continuam marcando o item
 * certo na navegação.
 */

import type { ComponentType } from 'react'
import { Encontro } from '@/paginas/brm/Encontro'
import { Encontros } from '@/paginas/brm/Encontros'
import { Entregaveis } from '@/paginas/brm/Entregaveis'
import { Programas } from '@/paginas/brm/Programas'
import { Turma } from '@/paginas/brm/Turma'
import { Turmas } from '@/paginas/brm/Turmas'

export { Encontro } from '@/paginas/brm/Encontro'
export { Encontros } from '@/paginas/brm/Encontros'
export { Entregaveis } from '@/paginas/brm/Entregaveis'
export { Programas } from '@/paginas/brm/Programas'
export { Turma } from '@/paginas/brm/Turma'
export { Turmas } from '@/paginas/brm/Turmas'

export interface RotaBrm {
  /** Caminho no padrão do react-router, com o parâmetro quando houver. */
  caminho: string
  componente: ComponentType
  /** Para o orquestrador saber o que está ligando, sem abrir a tela. */
  descricao: string
}

/** As seis rotas do BRM de Valor, na ordem em que o menu as apresenta. */
export const ROTAS_BRM: RotaBrm[] = [
  {
    caminho: '/programas',
    componente: Programas,
    descricao: 'Programas vendidos, com carga oficial e estrutura de cada um.',
  },
  {
    caminho: '/turmas',
    componente: Turmas,
    descricao: 'Turmas com cadeiras ocupadas sobre a capacidade, período e situação.',
  },
  {
    caminho: '/turmas/:turmaId',
    componente: Turma,
    descricao:
      'Ficha da turma, com Participantes, Calendário, Encontros, Entregáveis e Histórico de Valor.',
  },
  {
    caminho: '/encontros',
    componente: Encontros,
    descricao: 'Sequência numerada dos encontros, com tentativa preservada na remarcação.',
  },
  {
    caminho: '/encontros/:encontroId',
    componente: Encontro,
    descricao: 'Ficha do encontro, com presença, ritual semanal, entregáveis e gravação.',
  },
  {
    caminho: '/entregaveis',
    componente: Entregaveis,
    descricao: 'Entregáveis com filtro por visibilidade ao cliente em destaque.',
  },
]
