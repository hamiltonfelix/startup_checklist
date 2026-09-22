/**
 * Porta única das telas do CRM de Valor.
 *
 * O orquestrador liga as rotas lendo este arquivo. A lista `ROTAS_CRM` diz, em
 * um lugar só, qual caminho leva a qual componente, para que ninguém precise
 * abrir seis arquivos para descobrir isso.
 *
 * Nenhuma tela daqui esconde dado com condição de perfil. Quem decide o que
 * cada um enxerga é a política de linha do banco, conforme a seção 8 do
 * contrato técnico. O que a interface faz é lidar com a ausência sem quebrar
 * e sem inventar zero.
 */

import type { ComponentType } from 'react'
import { Atividades } from '@/paginas/crm/Atividades'
import { Calendario } from '@/paginas/crm/Calendario'
import { Conta } from '@/paginas/crm/Conta'
import { Contas } from '@/paginas/crm/Contas'
import { Negocio } from '@/paginas/crm/Negocio'
import { Negocios } from '@/paginas/crm/Negocios'

export { Atividades } from '@/paginas/crm/Atividades'
export { Calendario } from '@/paginas/crm/Calendario'
export { Conta, ListaDeInteracoes } from '@/paginas/crm/Conta'
export { Contas } from '@/paginas/crm/Contas'
export { Negocio } from '@/paginas/crm/Negocio'
export {
  AvisoDeFonte,
  EtiquetaFase,
  EtiquetaForecast,
  EtiquetaHigiene,
  Negocios,
} from '@/paginas/crm/Negocios'

export interface RotaCrm {
  /** Caminho no formato do react-router. */
  caminho: string
  componente: ComponentType
  /** Entrada de menu à qual esta rota pertence, quando existe uma. */
  itemDeMenu?: string
  descricao: string
}

/**
 * As seis rotas do CRM de Valor.
 *
 * As quatro de lista casam com as entradas de menu `contas`, `negocios`,
 * `atividades` e `calendario`. As duas de ficha moram abaixo das suas listas,
 * e por isso as entradas de menu de Contas e Negócios já nascem com `prefixo`
 * verdadeiro em `src/layout/menu.ts`.
 */
export const ROTAS_CRM: RotaCrm[] = [
  {
    caminho: '/contas',
    componente: Contas,
    itemDeMenu: 'contas',
    descricao: 'Lista de contas com busca, filtro, tier e Power of X',
  },
  {
    caminho: '/contas/:id',
    componente: Conta,
    descricao: 'Ficha da conta em seis abas, com a aba Saúde vinda de vw_saude_da_conta',
  },
  {
    caminho: '/negocios',
    componente: Negocios,
    itemDeMenu: 'negocios',
    descricao: 'O funil em quadro por fase e em tabela, com as duas linhas do pipeline no topo',
  },
  {
    caminho: '/negocios/:id',
    componente: Negocio,
    descricao: 'Ficha do negócio, com higiene, trilha de artefatos, papéis e rota pública',
  },
  {
    caminho: '/atividades',
    componente: Atividades,
    itemDeMenu: 'atividades',
    descricao: 'Quadro por coluna configurável e lista do método GTD, sobre a mesma tabela',
  },
  {
    caminho: '/calendario',
    componente: Calendario,
    itemDeMenu: 'calendario',
    descricao: 'Mês e semana, juntando vw_agenda_da_semana',
  },
]
