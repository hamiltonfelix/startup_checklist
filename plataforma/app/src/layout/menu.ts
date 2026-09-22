/**
 * Configuração da navegação, por perfil.
 *
 * O menu é dado, não código. Cada entrada declara quais perfis a enxergam, e
 * a casca só filtra. Não existe, e não pode existir, cascata de `if` de perfil
 * espalhada pelas telas.
 *
 * O que o parceiro vê é curto de propósito: o painel dele, as indicações que
 * ele trouxe e a comissão dele. Nada de entrega e nada do financeiro da casa.
 * Isso aqui é só a navegação. A garantia de verdade é a política de linha no
 * banco, conforme as seções 8 e 9 do contrato técnico.
 */

import type { PerfilUsuario } from '@/tipos/dominio'

export interface ItemMenu {
  chave: string
  rotulo: string
  para: string
  /** Caractere usado como ícone. Some quando a barra está recolhida. */
  icone: string
  /** Quem enxerga esta entrada na navegação. */
  perfis: PerfilUsuario[]
  /** Texto do `title`, para quem passa o ponteiro por cima. */
  descricao?: string
  /** Casa também os caminhos abaixo deste, para marcar o item como atual. */
  prefixo?: boolean
}

export interface GrupoMenu {
  chave: string
  titulo: string
  itens: ItemMenu[]
}

/** Toda a casa, ou seja, todo mundo menos o parceiro. */
const CASA: PerfilUsuario[] = [
  'admin_master',
  'emergencia',
  'lider',
  'comercial',
  'gerente_contas',
  'conselheiro',
  'assessor',
  'financeiro',
]

/** Quem toca o funil no dia a dia. */
const COMERCIAL: PerfilUsuario[] = [
  'admin_master',
  'emergencia',
  'lider',
  'comercial',
  'gerente_contas',
]

/** Quem entrega: conselho, turmas, encontros e atas. */
const ENTREGA: PerfilUsuario[] = [
  'admin_master',
  'emergencia',
  'lider',
  'conselheiro',
  'assessor',
]

/** Quem administra o inquilino. */
const ADMINISTRACAO: PerfilUsuario[] = ['admin_master', 'emergencia']

export const MENU: GrupoMenu[] = [
  {
    chave: 'crm',
    titulo: 'CRM de Valor',
    itens: [
      {
        chave: 'painel',
        rotulo: 'Painel',
        para: '/painel',
        icone: '▦',
        perfis: [...CASA, 'parceiro'],
        descricao: 'Pipeline declarado e auditado, forecast por artefato e higiene',
      },
      {
        chave: 'contas',
        rotulo: 'Contas',
        para: '/contas',
        icone: '◎',
        perfis: CASA,
        prefixo: true,
        descricao: 'As empresas com quem a casa fala',
      },
      {
        chave: 'negocios',
        rotulo: 'Negócios',
        para: '/negocios',
        icone: '△',
        perfis: CASA,
        prefixo: true,
        descricao: 'O funil nas nove fases do método',
      },
      {
        chave: 'atividades',
        rotulo: 'Atividades',
        para: '/atividades',
        icone: '✓',
        perfis: [...COMERCIAL, 'conselheiro', 'assessor'],
        descricao: 'Próximos passos com data e dono',
      },
      {
        chave: 'calendario',
        rotulo: 'Calendário',
        para: '/calendario',
        icone: '▤',
        perfis: [...COMERCIAL, 'conselheiro', 'assessor'],
        descricao: 'A agenda da semana',
      },
    ],
  },
  {
    chave: 'prm',
    titulo: 'PRM de Valor',
    itens: [
      {
        chave: 'meus-parceiros',
        rotulo: 'Meus Parceiros',
        para: '/parceiros',
        icone: '◈',
        perfis: COMERCIAL,
        prefixo: true,
        descricao: 'O canal de indicação da casa',
      },
      {
        chave: 'indicacoes',
        rotulo: 'Indicações',
        para: '/indicacoes',
        icone: '↗',
        perfis: [...COMERCIAL, 'parceiro'],
        prefixo: true,
        descricao: 'Negócios trazidos pelo canal',
      },
      {
        chave: 'comissoes',
        rotulo: 'Comissões',
        para: '/comissoes',
        icone: '%',
        perfis: ['admin_master', 'emergencia', 'lider', 'financeiro', 'parceiro'],
        descricao: 'O que cada indicação gera de comissão',
      },
    ],
  },
  {
    chave: 'brm',
    titulo: 'BRM de Valor',
    itens: [
      {
        chave: 'programas',
        rotulo: 'Programas',
        para: '/programas',
        icone: '▣',
        perfis: ENTREGA,
        prefixo: true,
      },
      {
        chave: 'turmas',
        rotulo: 'Turmas',
        para: '/turmas',
        icone: '☷',
        perfis: ENTREGA,
        prefixo: true,
      },
      {
        chave: 'encontros',
        rotulo: 'Encontros',
        para: '/encontros',
        icone: '◔',
        perfis: ENTREGA,
        prefixo: true,
      },
      {
        chave: 'atas',
        rotulo: 'Atas',
        para: '/atas',
        icone: '☰',
        perfis: ENTREGA,
        prefixo: true,
        descricao: 'Ata restrita nunca sai da casa',
      },
      {
        chave: 'entregaveis',
        rotulo: 'Entregáveis',
        para: '/entregaveis',
        icone: '◧',
        perfis: ENTREGA,
        prefixo: true,
      },
    ],
  },
  {
    chave: 'governanca',
    titulo: 'Governança',
    itens: [
      {
        chave: 'pendencias',
        rotulo: 'Pendências',
        para: '/pendencias',
        icone: '⚠',
        perfis: [...ENTREGA, 'gerente_contas', 'comercial'],
        descricao: 'O que reaparece até fechar',
      },
      {
        chave: 'pesquisas',
        rotulo: 'Pesquisas',
        para: '/pesquisas',
        icone: '☆',
        perfis: [...ENTREGA, 'gerente_contas'],
      },
      {
        chave: 'historico-de-valor',
        rotulo: 'Histórico de Valor',
        para: '/historico-de-valor',
        icone: '◴',
        perfis: [...ENTREGA, 'gerente_contas'],
        descricao: 'O que a casa entregou, em ordem',
      },
    ],
  },
  {
    chave: 'configuracao',
    titulo: 'Configuração',
    itens: [
      {
        chave: 'usuarios',
        rotulo: 'Usuários',
        para: '/configuracao/usuarios',
        icone: '☺',
        perfis: ADMINISTRACAO,
      },
      {
        chave: 'ofertas',
        rotulo: 'Ofertas',
        para: '/configuracao/ofertas',
        icone: '◇',
        perfis: [...ADMINISTRACAO, 'lider'],
        descricao: 'O catálogo do portfólio',
      },
      {
        chave: 'regras-e-alertas',
        rotulo: 'Regras e Alertas',
        para: '/configuracao/regras-e-alertas',
        icone: '⚙',
        perfis: [...ADMINISTRACAO, 'lider'],
      },
      {
        chave: 'identidade',
        rotulo: 'Identidade',
        para: '/configuracao/identidade',
        icone: '◑',
        perfis: [...ADMINISTRACAO, 'lider'],
        descricao: 'Cores, tipografia e componentes da casa',
      },
    ],
  },
]

/**
 * Devolve o menu que este perfil enxerga, já sem grupo vazio.
 * É a única função que decide navegação. Nenhuma tela repete esta regra.
 */
export function montarMenu(perfil: PerfilUsuario): GrupoMenu[] {
  return MENU.map((grupo) => ({
    ...grupo,
    itens: grupo.itens.filter((item) => item.perfis.includes(perfil)),
  })).filter((grupo) => grupo.itens.length > 0)
}

/** Todos os caminhos que algum perfil alcança. Serve para montar as rotas. */
export function todosOsItens(): ItemMenu[] {
  return MENU.flatMap((grupo) => grupo.itens)
}

/** Acha o item de menu que corresponde ao caminho atual. */
export function itemDoCaminho(caminho: string): ItemMenu | undefined {
  return todosOsItens().find((item) =>
    item.prefixo ? caminho === item.para || caminho.startsWith(`${item.para}/`) : caminho === item.para,
  )
}

/** Acha o grupo a que um item pertence, para montar a trilha de migalhas. */
export function grupoDoItem(chaveDoItem: string): GrupoMenu | undefined {
  return MENU.find((grupo) => grupo.itens.some((item) => item.chave === chaveDoItem))
}
