/**
 * Consultas e dados de exemplo das telas do CRM de Valor.
 *
 * Segue à risca o padrão de `src/dados/consultas.ts`: quando o banco está
 * ligado, lê do banco; quando não está, cai no exemplo e devolve `deExemplo`
 * verdadeiro, para a tela dizer isso em voz alta. Nunca mistura os dois sem
 * avisar, e nunca finge que exemplo é dado real.
 *
 * Toda empresa deste arquivo é claramente fictícia e todo valor é redondo e
 * inventado. Nenhum telefone, nenhum endereço eletrônico, nenhum documento e
 * nenhum valor de contrato de verdade, conforme a seção 11 do contrato técnico.
 *
 * Confidencialidade não se resolve aqui. Quem decide quem vê margem, comissão
 * e valor é a política de linha do banco. Esta camada só repassa o que chegou,
 * e deixa nulo o que não chegou, sem inventar zero.
 */

import {
  useMutation,
  useQuery,
  useQueryClient,
  type UseMutationResult,
  type UseQueryResult,
} from '@tanstack/react-query'
import { obterCliente, temBanco } from '@/dados/cliente'
import type { Fase, TipoArtefato, Uuid } from '@/tipos/dominio'
import {
  comoFase,
  type ColunaDoQuadro,
  type ContextoGtd,
  type EstadoGtd,
  type FichaDaConta,
  type FichaDoNegocio,
  type LinhaAgenda,
  type LinhaAlertaAberto,
  type LinhaArtefato,
  type LinhaAtividade,
  type LinhaCaixaDeEntrada,
  type LinhaConta,
  type LinhaContato,
  type LinhaContratoEmCurso,
  type LinhaInteracao,
  type LinhaNegocioForecast,
  type LinhaPapelNegocio,
  type LinhaPipelineHigiene,
  type LinhaRotaPublica,
  type LinhaSaudeDaConta,
  type PainelDeNegocios,
  type QuadroDeAtividades,
} from '@/tipos/crm'
import { ARTEFATO_DA_FASE } from '@/tipos/rotulos'

/** O que toda consulta desta camada devolve. */
export interface RespostaCrm<T> {
  dados: T
  /** Verdadeiro quando o que está na tela veio do arquivo de exemplo. */
  deExemplo: boolean
}

/** Entra na chave de cada consulta, para trocar de fonte recarregar tudo. */
function fonte(): 'banco' | 'exemplo' {
  return temBanco() ? 'banco' : 'exemplo'
}

// ============================================================ datas úteis

const HOJE = new Date()

/** Data ISO a tantos dias de hoje. Número negativo anda para trás. */
function emDias(dias: number): string {
  const d = new Date(HOJE)
  d.setDate(d.getDate() + dias)
  return d.toISOString().slice(0, 10)
}

/** Momento ISO a tantos dias de hoje, com hora cheia. */
function momento(dias: number, horaDoDia = 10): string {
  const d = new Date(HOJE)
  d.setDate(d.getDate() + dias)
  d.setHours(horaDoDia, 0, 0, 0)
  return d.toISOString()
}

const HOJE_ISO = emDias(0)

// ============================================================ contas exemplo

const CONTAS_EXEMPLO: LinhaConta[] = [
  {
    id: 'conta-01',
    nome: 'Metalúrgica Aurora Fictícia',
    razao_social: 'Metalúrgica Aurora Fictícia Ltda',
    cnpj: null,
    setor: 'Indústria',
    porte: 'Média',
    cidade: 'Joinville',
    uf: 'SC',
    site: null,
    tier: 't1',
    tier_sugerido: 't1',
    tier_confirmado_em: momento(-120),
    prioridade: 1,
    power_of_x: 3,
    eh_cliente: true,
    eh_prospecto: false,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-01',
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    observacoes: 'Conta de exemplo. Conselho dedicado desde o ciclo passado.',
    criado_em: momento(-400),
  },
  {
    id: 'conta-02',
    nome: 'Transportes Serra Modelo',
    razao_social: 'Transportes Serra Modelo S.A.',
    cnpj: null,
    setor: 'Logística',
    porte: 'Grande',
    cidade: 'Caxias do Sul',
    uf: 'RS',
    site: null,
    tier: 't2',
    tier_sugerido: 't1',
    tier_confirmado_em: null,
    prioridade: 1,
    power_of_x: 1,
    eh_cliente: false,
    eh_prospecto: true,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-01',
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    observacoes: null,
    criado_em: momento(-260),
  },
  {
    id: 'conta-03',
    nome: 'Clínica Bem Viver Exemplo',
    razao_social: 'Clínica Bem Viver Exemplo Ltda',
    cnpj: null,
    setor: 'Saúde',
    porte: 'Pequena',
    cidade: 'Belo Horizonte',
    uf: 'MG',
    site: null,
    tier: 't2',
    tier_sugerido: 't2',
    tier_confirmado_em: momento(-60),
    prioridade: 2,
    power_of_x: 2,
    eh_cliente: true,
    eh_prospecto: true,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-02',
    gerente_contas_nome: 'Segunda Pessoa de Exemplo',
    observacoes: null,
    criado_em: momento(-300),
  },
  {
    id: 'conta-04',
    nome: 'Agro Vale Fictício',
    razao_social: 'Agro Vale Fictício Agropecuária Ltda',
    cnpj: null,
    setor: 'Agronegócio',
    porte: 'Média',
    cidade: 'Rio Verde',
    uf: 'GO',
    site: null,
    tier: null,
    tier_sugerido: 't3',
    tier_confirmado_em: null,
    prioridade: 3,
    power_of_x: 0,
    eh_cliente: false,
    eh_prospecto: true,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-02',
    gerente_contas_nome: 'Segunda Pessoa de Exemplo',
    observacoes: null,
    criado_em: momento(-90),
  },
  {
    id: 'conta-05',
    nome: 'Construtora Horizonte Modelo',
    razao_social: 'Construtora Horizonte Modelo S.A.',
    cnpj: null,
    setor: 'Construção',
    porte: 'Grande',
    cidade: 'Recife',
    uf: 'PE',
    site: null,
    tier: 't1',
    tier_sugerido: 't2',
    tier_confirmado_em: momento(-30),
    prioridade: 1,
    power_of_x: 4,
    eh_cliente: true,
    eh_prospecto: false,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-01',
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    observacoes: 'A casa confirmou Tier 1 apesar da sugestão do sistema.',
    criado_em: momento(-520),
  },
  {
    id: 'conta-06',
    nome: 'Rede Sabor Fictícia',
    razao_social: 'Rede Sabor Fictícia Alimentação Ltda',
    cnpj: null,
    setor: 'Alimentação',
    porte: 'Média',
    cidade: 'Salvador',
    uf: 'BA',
    site: null,
    tier: 't3',
    tier_sugerido: 't3',
    tier_confirmado_em: momento(-15),
    prioridade: 3,
    power_of_x: 1,
    eh_cliente: false,
    eh_prospecto: true,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-02',
    gerente_contas_nome: 'Segunda Pessoa de Exemplo',
    observacoes: null,
    criado_em: momento(-140),
  },
  {
    id: 'conta-07',
    nome: 'Softworks Exemplo',
    razao_social: 'Softworks Exemplo Tecnologia Ltda',
    cnpj: null,
    setor: 'Tecnologia',
    porte: 'Pequena',
    cidade: 'Florianópolis',
    uf: 'SC',
    site: null,
    tier: 't2',
    tier_sugerido: 't2',
    tier_confirmado_em: null,
    prioridade: 2,
    power_of_x: 2,
    eh_cliente: true,
    eh_prospecto: true,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-01',
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    observacoes: null,
    criado_em: momento(-210),
  },
  {
    id: 'conta-08',
    nome: 'Instituto Vila Exemplo',
    razao_social: 'Instituto Vila Exemplo de Gestão Pública',
    cnpj: null,
    setor: 'Setor público',
    porte: 'Grande',
    cidade: 'Vila Exemplo',
    uf: 'SP',
    site: null,
    tier: 't2',
    tier_sugerido: 't2',
    tier_confirmado_em: momento(-7),
    prioridade: 2,
    power_of_x: 0,
    eh_cliente: false,
    eh_prospecto: true,
    eh_fornecedor: false,
    eh_parceiro: false,
    gerente_contas_id: 'usuario-01',
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    observacoes: 'Rota pública. Acompanhar a sessão no portal do PNCP.',
    criado_em: momento(-70),
  },
]

const CONTATOS_EXEMPLO: LinhaContato[] = [
  {
    id: 'contato-01',
    conta_id: 'conta-01',
    nome: 'Diretora de Exemplo',
    cargo: 'Diretora Geral',
    papel_decisao: 'Decisora',
    email: null,
    telefone: null,
    linkedin: null,
    eh_principal: true,
    observacoes: 'Quem assina. Prefere conversa curta com número na mesa.',
  },
  {
    id: 'contato-02',
    conta_id: 'conta-01',
    nome: 'Gerente Industrial de Exemplo',
    cargo: 'Gerente Industrial',
    papel_decisao: 'Influenciador',
    email: null,
    telefone: null,
    linkedin: null,
    eh_principal: false,
    observacoes: null,
  },
  {
    id: 'contato-03',
    conta_id: 'conta-01',
    nome: 'Controller de Exemplo',
    cargo: 'Controller',
    papel_decisao: 'Guardião',
    email: null,
    telefone: null,
    linkedin: null,
    eh_principal: false,
    observacoes: 'Pede tudo por escrito antes de liberar o orçamento.',
  },
  {
    id: 'contato-04',
    conta_id: 'conta-02',
    nome: 'Sócio Fundador de Exemplo',
    cargo: 'Sócio Fundador',
    papel_decisao: 'Patrocinador',
    email: null,
    telefone: null,
    linkedin: null,
    eh_principal: true,
    observacoes: null,
  },
  {
    id: 'contato-05',
    conta_id: 'conta-03',
    nome: 'Sócia Responsável de Exemplo',
    cargo: 'Sócia Responsável',
    papel_decisao: 'Decisora',
    email: null,
    telefone: null,
    linkedin: null,
    eh_principal: true,
    observacoes: null,
  },
  {
    id: 'contato-06',
    conta_id: 'conta-05',
    nome: 'Diretor de Operações de Exemplo',
    cargo: 'Diretor de Operações',
    papel_decisao: 'Usuário',
    email: null,
    telefone: null,
    linkedin: null,
    eh_principal: true,
    observacoes: null,
  },
  {
    id: 'contato-07',
    conta_id: 'conta-08',
    nome: 'Pregoeiro de Exemplo',
    cargo: 'Pregoeiro',
    papel_decisao: 'Guardião',
    email: null,
    telefone: null,
    linkedin: null,
    eh_principal: true,
    observacoes: 'Conduz a sessão. Toda conversa passa pelo processo.',
  },
]

// ==================================================== negócios de exemplo

interface ArtefatoSemente {
  tipo: TipoArtefato
  status: LinhaArtefato['status']
  versao: number
  validado_em: string | null
}

interface SementeNegocio {
  id: string
  titulo: string
  conta_id: string
  oferta_nome: string | null
  fase: Fase
  rota: LinhaNegocioForecast['rota']
  origem: LinhaNegocioForecast['origem']
  nivel_contrato: LinhaNegocioForecast['nivel_contrato']
  valor_total: number | null
  valor_recorrente_mes: number | null
  meses_recorrencia: number | null
  data_decisao_cliente: string | null
  proximo_passo: string | null
  proximo_passo_data: string | null
  proximo_passo_responsavel_nome: string | null
  ultima_interacao: string | null
  entrou_na_fase_em: string
  gerente_contas_nome: string | null
  conselheiro_nome: string | null
  parceiro_nome: string | null
  probabilidade: LinhaNegocioForecast['probabilidade']
  descricao: string | null
  desfecho: LinhaNegocioForecast['desfecho']
  artefatos: ArtefatoSemente[]
}

const SEMENTES: SementeNegocio[] = [
  {
    id: 'negocio-01',
    titulo: 'Conselho dedicado · ciclo de doze meses',
    conta_id: 'conta-01',
    oferta_nome: 'Conselho de Valor dedicado',
    fase: 4,
    rota: 'privada',
    origem: 'indicacao_cliente',
    nivel_contrato: 'n3',
    valor_total: 480000,
    valor_recorrente_mes: 40000,
    meses_recorrencia: 12,
    data_decisao_cliente: emDias(21),
    proximo_passo: 'Reunião de assinatura com a diretoria',
    proximo_passo_data: emDias(7),
    proximo_passo_responsavel_nome: 'Gerente de Contas de Exemplo',
    ultima_interacao: emDias(-4),
    entrou_na_fase_em: emDias(-18),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: 'Conselheiro de Exemplo',
    parceiro_nome: null,
    probabilidade: 'alta',
    descricao:
      'Ciclo anual de conselho dedicado, com reunião mensal e acompanhamento do plano de gestão.',
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 2, validado_em: emDias(-95) },
      { tipo: 'plano_negocio', status: 'validado_com_cliente', versao: 3, validado_em: emDias(-62) },
      { tipo: 'plano_trabalho', status: 'validado_com_cliente', versao: 2, validado_em: emDias(-33) },
      { tipo: 'contrato_valor', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-5) },
    ],
  },
  {
    id: 'negocio-02',
    titulo: 'Negócios de Valor · turma dedicada',
    conta_id: 'conta-02',
    oferta_nome: 'Negócios de Valor',
    fase: 4,
    rota: 'privada',
    origem: 'evento',
    nivel_contrato: 'n2',
    valor_total: 320000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(14),
    proximo_passo: 'Conferir o nível do Contrato de Valor com o financeiro do cliente',
    proximo_passo_data: emDias(3),
    proximo_passo_responsavel_nome: 'Gerente de Contas de Exemplo',
    ultima_interacao: emDias(-9),
    entrou_na_fase_em: emDias(-12),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: 'Conselheiro de Exemplo',
    parceiro_nome: 'Parceiro Exemplo Consultoria',
    probabilidade: 'alta',
    descricao: 'Turma dedicada para a liderança de operações, com doze encontros.',
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-120) },
      { tipo: 'plano_negocio', status: 'validado_com_cliente', versao: 2, validado_em: emDias(-70) },
      { tipo: 'plano_trabalho', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-24) },
      { tipo: 'contrato_valor', status: 'interno_pronto', versao: 1, validado_em: null },
    ],
  },
  {
    id: 'negocio-03',
    titulo: 'Gestão de Valor · implantação do ciclo',
    conta_id: 'conta-03',
    oferta_nome: 'Gestão de Valor',
    fase: 3,
    rota: 'privada',
    origem: 'indicacao_parceiro',
    nivel_contrato: 'n2',
    valor_total: 260000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(38),
    proximo_passo: 'Validar o Plano de Trabalho com a sócia responsável',
    proximo_passo_data: emDias(5),
    proximo_passo_responsavel_nome: 'Segunda Pessoa de Exemplo',
    ultima_interacao: emDias(-11),
    entrou_na_fase_em: emDias(-20),
    gerente_contas_nome: 'Segunda Pessoa de Exemplo',
    conselheiro_nome: 'Conselheiro de Exemplo',
    parceiro_nome: 'Parceiro Exemplo Consultoria',
    probabilidade: 'media',
    descricao: 'Implantação do ciclo de gestão com ritual semanal e painel de indicadores.',
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-88) },
      { tipo: 'plano_negocio', status: 'validado_com_cliente', versao: 2, validado_em: emDias(-40) },
      { tipo: 'plano_trabalho', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-9) },
    ],
  },
  {
    id: 'negocio-04',
    titulo: 'Liderança de Valor · turma compartilhada',
    conta_id: 'conta-04',
    oferta_nome: 'Liderança de Valor',
    fase: 3,
    rota: 'privada',
    origem: 'prospeccao_ativa',
    nivel_contrato: 'n1',
    valor_total: 180000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(45),
    proximo_passo: 'Enviar a agenda da reunião de valor',
    proximo_passo_data: emDias(2),
    proximo_passo_responsavel_nome: 'Segunda Pessoa de Exemplo',
    // Passou da janela de higiene sem conversa. Cai fora do pipeline auditado.
    ultima_interacao: emDias(-52),
    entrou_na_fase_em: emDias(-55),
    gerente_contas_nome: 'Segunda Pessoa de Exemplo',
    conselheiro_nome: 'Conselheiro de Exemplo',
    parceiro_nome: null,
    probabilidade: 'baixa',
    descricao: null,
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-140) },
      { tipo: 'plano_negocio', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-100) },
      { tipo: 'plano_trabalho', status: 'rascunho', versao: 1, validado_em: null },
    ],
  },
  {
    id: 'negocio-05',
    titulo: 'Mentoria de Valor para a diretoria',
    conta_id: 'conta-05',
    oferta_nome: 'Mentoria de Valor',
    fase: 2,
    rota: 'privada',
    origem: 'rede_pessoal',
    nivel_contrato: 'n2',
    valor_total: 140000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    // Data da decisão do cliente no passado. Isso é dívida, não pipeline.
    data_decisao_cliente: emDias(-12),
    proximo_passo: 'Reapresentar o Plano de Negócio com os números do trimestre',
    proximo_passo_data: emDias(9),
    proximo_passo_responsavel_nome: 'Gerente de Contas de Exemplo',
    ultima_interacao: emDias(-6),
    entrou_na_fase_em: emDias(-45),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: null,
    parceiro_nome: null,
    probabilidade: 'media',
    descricao: 'Mentoria mensal da diretoria, com pauta de decisão e acompanhamento de metas.',
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-160) },
      { tipo: 'plano_negocio', status: 'validado_com_cliente', versao: 2, validado_em: emDias(-30) },
    ],
  },
  {
    id: 'negocio-06',
    titulo: 'Executivo de Valor · acompanhamento anual',
    conta_id: 'conta-06',
    oferta_nome: 'Executivo de Valor',
    fase: 2,
    rota: 'privada',
    origem: 'inbound',
    nivel_contrato: 'n1',
    valor_total: 120000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(60),
    // Sem próximo passo com data. Falha a primeira invariante.
    proximo_passo: null,
    proximo_passo_data: null,
    proximo_passo_responsavel_nome: null,
    ultima_interacao: emDias(-3),
    entrou_na_fase_em: emDias(-14),
    gerente_contas_nome: 'Segunda Pessoa de Exemplo',
    conselheiro_nome: null,
    parceiro_nome: null,
    probabilidade: 'media',
    descricao: null,
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-75) },
      { tipo: 'plano_negocio', status: 'interno_pronto', versao: 1, validado_em: null },
    ],
  },
  {
    id: 'negocio-07',
    titulo: 'Diagnóstico de gestão e desenho do ciclo',
    conta_id: 'conta-07',
    oferta_nome: 'Diagnóstico de Valor',
    fase: 1,
    rota: 'privada',
    origem: 'base_instalada',
    nivel_contrato: 'n1',
    valor_total: 90000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(75),
    proximo_passo: 'Montar o Plano de Conta com a hipótese de valor',
    proximo_passo_data: emDias(4),
    proximo_passo_responsavel_nome: 'Gerente de Contas de Exemplo',
    ultima_interacao: emDias(-2),
    entrou_na_fase_em: emDias(-9),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: null,
    parceiro_nome: null,
    probabilidade: 'alta',
    descricao: null,
    desfecho: null,
    // Sem o Plano de Conta registrado, o artefato da fase 1 falta.
    artefatos: [],
  },
  {
    id: 'negocio-08',
    titulo: 'Programa de gestão para a rede de unidades',
    conta_id: 'conta-08',
    oferta_nome: 'Gestão de Valor',
    fase: 2,
    rota: 'publica',
    origem: 'licitacao_publica',
    nivel_contrato: 'n2',
    valor_total: 350000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(28),
    proximo_passo: 'Conferir a minuta do edital publicada no portal',
    proximo_passo_data: emDias(6),
    proximo_passo_responsavel_nome: 'Gerente de Contas de Exemplo',
    ultima_interacao: emDias(-8),
    entrou_na_fase_em: emDias(-22),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: null,
    parceiro_nome: null,
    probabilidade: 'media',
    descricao: 'Rota pública. Segue a Lei 14.133, com sessão marcada e acompanhamento no PNCP.',
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-50) },
      { tipo: 'plano_negocio', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-16) },
    ],
  },
  {
    id: 'negocio-09',
    titulo: 'Sondagem de conselho compartilhado',
    conta_id: 'conta-06',
    oferta_nome: null,
    fase: 0,
    rota: 'privada',
    origem: 'evento',
    nivel_contrato: 'n1',
    valor_total: null,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: null,
    proximo_passo: 'Marcar a primeira conversa de qualificação',
    proximo_passo_data: emDias(1),
    proximo_passo_responsavel_nome: 'Segunda Pessoa de Exemplo',
    ultima_interacao: emDias(-1),
    entrou_na_fase_em: emDias(-3),
    gerente_contas_nome: 'Segunda Pessoa de Exemplo',
    conselheiro_nome: null,
    parceiro_nome: null,
    probabilidade: null,
    descricao: null,
    desfecho: null,
    artefatos: [],
  },
  {
    id: 'negocio-10',
    titulo: 'Entrega do conselho dedicado · primeiro semestre',
    conta_id: 'conta-05',
    oferta_nome: 'Conselho de Valor dedicado',
    fase: 5,
    rota: 'privada',
    origem: 'base_instalada',
    nivel_contrato: 'n3',
    valor_total: 600000,
    valor_recorrente_mes: 50000,
    meses_recorrencia: 12,
    data_decisao_cliente: emDias(-200),
    proximo_passo: 'Encontro de turma número sete',
    proximo_passo_data: emDias(5),
    proximo_passo_responsavel_nome: 'Conselheiro de Exemplo',
    ultima_interacao: emDias(-7),
    entrou_na_fase_em: emDias(-180),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: 'Conselheiro de Exemplo',
    parceiro_nome: null,
    probabilidade: null,
    descricao: 'Ciclo em entrega. Acompanhamento mensal com a diretoria.',
    desfecho: null,
    artefatos: [
      { tipo: 'plano_conta', status: 'validado_com_cliente', versao: 2, validado_em: emDias(-330) },
      { tipo: 'plano_negocio', status: 'validado_com_cliente', versao: 2, validado_em: emDias(-300) },
      { tipo: 'plano_trabalho', status: 'validado_com_cliente', versao: 3, validado_em: emDias(-250) },
      { tipo: 'contrato_valor', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-205) },
      { tipo: 'entrega_valor', status: 'interno_pronto', versao: 4, validado_em: null },
    ],
  },
  {
    id: 'negocio-11',
    titulo: 'Cultivo de valor · leitura do ciclo entregue',
    conta_id: 'conta-01',
    oferta_nome: 'Monitoria de Valor',
    fase: 6,
    rota: 'privada',
    origem: 'base_instalada',
    nivel_contrato: 'n2',
    valor_total: 90000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(-60),
    proximo_passo: 'Rodar a pesquisa de valor percebido com a diretoria',
    proximo_passo_data: emDias(12),
    proximo_passo_responsavel_nome: 'Conselheiro de Exemplo',
    ultima_interacao: emDias(-10),
    entrou_na_fase_em: emDias(-40),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: 'Conselheiro de Exemplo',
    parceiro_nome: null,
    probabilidade: null,
    descricao: null,
    desfecho: null,
    artefatos: [
      { tipo: 'monitoria_valor', status: 'interno_pronto', versao: 1, validado_em: null },
    ],
  },
  {
    id: 'negocio-12',
    titulo: 'Renovação do ciclo de conselho',
    conta_id: 'conta-05',
    oferta_nome: 'Conselho de Valor dedicado',
    fase: 7,
    rota: 'privada',
    origem: 'base_instalada',
    nivel_contrato: 'n3',
    valor_total: 660000,
    valor_recorrente_mes: 55000,
    meses_recorrencia: 12,
    data_decisao_cliente: emDias(80),
    proximo_passo: 'Apresentar a leitura do valor entregue no ciclo atual',
    proximo_passo_data: emDias(15),
    proximo_passo_responsavel_nome: 'Gerente de Contas de Exemplo',
    ultima_interacao: emDias(-5),
    entrou_na_fase_em: emDias(-11),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: 'Conselheiro de Exemplo',
    parceiro_nome: null,
    probabilidade: 'alta',
    descricao: null,
    desfecho: null,
    artefatos: [
      { tipo: 'renovacao_valor', status: 'rascunho', versao: 1, validado_em: null },
    ],
  },
  {
    id: 'negocio-13',
    titulo: 'Turma compartilhada da manhã · ciclo anterior',
    conta_id: 'conta-07',
    oferta_nome: 'Negócios de Valor',
    fase: 9,
    rota: 'privada',
    origem: 'indicacao_cliente',
    nivel_contrato: 'n1',
    valor_total: 60000,
    valor_recorrente_mes: null,
    meses_recorrencia: null,
    data_decisao_cliente: emDias(-150),
    proximo_passo: null,
    proximo_passo_data: null,
    proximo_passo_responsavel_nome: null,
    ultima_interacao: emDias(-150),
    entrou_na_fase_em: emDias(-148),
    gerente_contas_nome: 'Gerente de Contas de Exemplo',
    conselheiro_nome: null,
    parceiro_nome: null,
    probabilidade: null,
    descricao: null,
    desfecho: 'concluido',
    artefatos: [
      { tipo: 'plano_conta', status: 'superado', versao: 1, validado_em: emDias(-260) },
      { tipo: 'contrato_valor', status: 'validado_com_cliente', versao: 1, validado_em: emDias(-200) },
    ],
  },
]

/** Aplica as regras do contrato sobre uma semente e devolve a linha da visão. */
function montarLinhaDeExemplo(semente: SementeNegocio): LinhaNegocioForecast {
  const conta = CONTAS_EXEMPLO.find((linha) => linha.id === semente.conta_id)
  const validados = semente.artefatos
    .filter((artefato) => artefato.status === 'validado_com_cliente')
    .map((artefato) => artefato.tipo)
  const registrados = semente.artefatos.map((artefato) => artefato.tipo)

  const categoria = validados.includes('contrato_valor')
    ? 'compromisso'
    : validados.includes('plano_trabalho')
      ? 'possivel'
      : validados.includes('plano_negocio')
        ? 'aberto'
        : 'fora'

  const tipoQueSustenta: TipoArtefato | null =
    categoria === 'compromisso'
      ? 'contrato_valor'
      : categoria === 'possivel'
        ? 'plano_trabalho'
        : categoria === 'aberto'
          ? 'plano_negocio'
          : null

  const validadoEm =
    tipoQueSustenta === null
      ? null
      : (semente.artefatos.find((artefato) => artefato.tipo === tipoQueSustenta)?.validado_em ?? null)

  const artefatoDaFase = ARTEFATO_DA_FASE[semente.fase]
  const limiteInteracao = emDias(-30)

  const temProximoPasso = Boolean(
    semente.proximo_passo && semente.proximo_passo_data && semente.proximo_passo_data >= HOJE_ISO,
  )
  const decisaoNoFuturo = Boolean(
    semente.data_decisao_cliente && semente.data_decisao_cliente >= HOJE_ISO,
  )
  const interacaoRecente = Boolean(
    semente.ultima_interacao && semente.ultima_interacao >= limiteInteracao,
  )
  const temArtefatoDaFase = Boolean(artefatoDaFase && registrados.includes(artefatoDaFase))

  const exigeHigiene = semente.fase >= 1 && semente.fase <= 4
  const quebradas = exigeHigiene
    ? [temProximoPasso, decisaoNoFuturo, interacaoRecente, temArtefatoDaFase].filter(
        (cumpre) => !cumpre,
      ).length
    : 0

  const diasParado = Math.round(
    (Date.now() - new Date(`${semente.ultima_interacao ?? semente.entrou_na_fase_em}T12:00:00`).getTime()) /
      86_400_000,
  )

  return {
    negocio_id: semente.id,
    titulo: semente.titulo,
    conta_id: semente.conta_id,
    conta_nome: conta?.nome ?? 'Conta de exemplo',
    conta_tier: conta?.tier ?? null,
    oferta_id: null,
    oferta_nome: semente.oferta_nome,
    fase: semente.fase,
    fase_rotulo: '',
    rota: semente.rota,
    origem: semente.origem,
    nivel_contrato: semente.nivel_contrato,
    valor_total: semente.valor_total,
    valor_recorrente_mes: semente.valor_recorrente_mes,
    meses_recorrencia: semente.meses_recorrencia,
    valor_considerado:
      semente.valor_total ??
      (semente.valor_recorrente_mes !== null && semente.meses_recorrencia !== null
        ? semente.valor_recorrente_mes * semente.meses_recorrencia
        : null),
    categoria,
    artefato_que_sustenta: tipoQueSustenta,
    artefato_validado_em: validadoEm,
    tem_proximo_passo: temProximoPasso,
    decisao_no_futuro: decisaoNoFuturo,
    interacao_recente: interacaoRecente,
    tem_artefato_da_fase: temArtefatoDaFase,
    exige_higiene: exigeHigiene,
    na_higiene: exigeHigiene ? quebradas === 0 : null,
    quantas_invariantes_quebradas: quebradas,
    proximo_passo: semente.proximo_passo,
    proximo_passo_data: semente.proximo_passo_data,
    proximo_passo_responsavel: null,
    proximo_passo_responsavel_nome: semente.proximo_passo_responsavel_nome,
    data_decisao_cliente: semente.data_decisao_cliente,
    dias_ate_decisao: semente.data_decisao_cliente
      ? Math.round(
          (new Date(`${semente.data_decisao_cliente}T12:00:00`).getTime() - Date.now()) / 86_400_000,
        )
      : null,
    ultima_interacao: semente.ultima_interacao,
    entrou_na_fase_em: semente.entrou_na_fase_em,
    dias_parado: diasParado,
    limite_dias: 30,
    esta_parado: diasParado > 30,
    gerente_contas_id: null,
    gerente_contas_nome: semente.gerente_contas_nome,
    conselheiro_id: null,
    conselheiro_nome: semente.conselheiro_nome,
    // O conselheiro entra na Conexão de Valor, a fase 3, e segue até o fim.
    conselheiro_entrou_na_fase: semente.conselheiro_nome ? 3 : null,
    parceiro_id: semente.parceiro_nome ? 'parceiro-01' : null,
    parceiro_nome: semente.parceiro_nome,
    papeis_ativos:
      1 + (semente.conselheiro_nome ? 1 : 0) + (semente.parceiro_nome ? 1 : 0),
    probabilidade: semente.probabilidade,
    descricao: semente.descricao,
    desfecho: semente.desfecho,
  }
}

function negociosDeExemplo(): LinhaNegocioForecast[] {
  return SEMENTES.map(montarLinhaDeExemplo)
}

/** Refaz as duas linhas do pipeline sobre a lista de exemplo, com as mesmas regras. */
function pipelineDeExemplo(negocios: LinhaNegocioForecast[]): LinhaPipelineHigiene {
  const daHigiene = negocios.filter((linha) => linha.exige_higiene)
  const soma = (lista: LinhaNegocioForecast[]) =>
    lista.reduce((total, linha) => total + (linha.valor_considerado ?? 0), 0)
  const auditados = daHigiene.filter((linha) => linha.na_higiene === true)
  const travados = daHigiene.filter((linha) => linha.na_higiene !== true)
  const declarado = soma(daHigiene)
  const auditado = soma(auditados)

  return {
    negocios_declarados: daHigiene.length,
    pipeline_declarado: declarado,
    negocios_auditados: auditados.length,
    pipeline_auditado: auditado,
    negocios_travados: travados.length,
    valor_travado: declarado - auditado,
    percentual_negocios_auditados: daHigiene.length
      ? Math.round((auditados.length / daHigiene.length) * 1000) / 10
      : null,
    percentual_valor_auditado: declarado ? Math.round((auditado / declarado) * 1000) / 10 : null,
    quebra_proximo_passo: daHigiene.filter((linha) => !linha.tem_proximo_passo).length,
    quebra_decisao_no_futuro: daHigiene.filter((linha) => !linha.decisao_no_futuro).length,
    quebra_interacao_recente: daHigiene.filter((linha) => !linha.interacao_recente).length,
    quebra_artefato_da_fase: daHigiene.filter((linha) => !linha.tem_artefato_da_fase).length,
    travado_por_proximo_passo: soma(daHigiene.filter((linha) => !linha.tem_proximo_passo)),
    travado_por_decisao_no_futuro: soma(daHigiene.filter((linha) => !linha.decisao_no_futuro)),
    travado_por_interacao_recente: soma(daHigiene.filter((linha) => !linha.interacao_recente)),
    travado_por_artefato_da_fase: soma(daHigiene.filter((linha) => !linha.tem_artefato_da_fase)),
  }
}

function artefatosDeExemplo(negocioId: string): LinhaArtefato[] {
  const semente = SEMENTES.find((linha) => linha.id === negocioId)
  if (!semente) return []
  return semente.artefatos.map((artefato, indice) => ({
    id: `${negocioId}-artefato-${indice + 1}`,
    negocio_id: negocioId,
    tipo: artefato.tipo,
    status: artefato.status,
    versao: artefato.versao,
    titulo: null,
    arquivo_url: null,
    validado_em: artefato.validado_em,
    gerado_com_ia: false,
    criado_em: momento(-200),
  }))
}

function papeisDeExemplo(negocioId: string): LinhaPapelNegocio[] {
  const semente = SEMENTES.find((linha) => linha.id === negocioId)
  if (!semente) return []

  const papeis: LinhaPapelNegocio[] = [
    {
      id: `${negocioId}-papel-1`,
      negocio_id: negocioId,
      usuario_id: 'usuario-01',
      usuario_nome: semente.gerente_contas_nome,
      parceiro_id: null,
      parceiro_nome: null,
      papel: 'gerente_contas',
      entrou_na_fase: 1,
      principal: true,
      ativo: true,
    },
  ]

  if (semente.fase >= 2) {
    papeis.push({
      id: `${negocioId}-papel-2`,
      negocio_id: negocioId,
      usuario_id: 'usuario-03',
      usuario_nome: 'Pré-vendas de Exemplo',
      parceiro_id: null,
      parceiro_nome: null,
      papel: 'pre_vendas',
      entrou_na_fase: 2,
      principal: false,
      ativo: true,
    })
  }

  if (semente.conselheiro_nome) {
    papeis.push({
      id: `${negocioId}-papel-3`,
      negocio_id: negocioId,
      usuario_id: 'usuario-04',
      usuario_nome: semente.conselheiro_nome,
      parceiro_id: null,
      parceiro_nome: null,
      papel: 'conselheiro',
      // Regra do método: o conselheiro entra na Conexão de Valor, a fase 3.
      entrou_na_fase: 3,
      principal: true,
      ativo: true,
    })
  }

  if (semente.fase >= 5) {
    papeis.push({
      id: `${negocioId}-papel-4`,
      negocio_id: negocioId,
      usuario_id: 'usuario-05',
      usuario_nome: 'Gerente de Projetos de Exemplo',
      parceiro_id: null,
      parceiro_nome: null,
      papel: 'gerente_projetos',
      entrou_na_fase: 5,
      principal: false,
      ativo: true,
    })
  }

  if (semente.parceiro_nome) {
    papeis.push({
      id: `${negocioId}-papel-5`,
      negocio_id: negocioId,
      usuario_id: null,
      usuario_nome: null,
      parceiro_id: 'parceiro-01',
      parceiro_nome: semente.parceiro_nome,
      papel: 'parceiro',
      entrou_na_fase: 0,
      principal: false,
      ativo: true,
    })
  }

  return papeis
}

const INTERACOES_EXEMPLO: LinhaInteracao[] = [
  {
    id: 'interacao-01',
    conta_id: 'conta-01',
    negocio_id: 'negocio-01',
    contato_id: 'contato-01',
    contato_nome: 'Diretora de Exemplo',
    usuario_id: 'usuario-01',
    usuario_nome: 'Gerente de Contas de Exemplo',
    canal: 'reuniao_presencial',
    ocorrida_em: momento(-4, 14),
    assunto: 'Leitura final do Contrato de Valor',
    resumo:
      'A diretoria pediu ajuste no calendário de encontros e confirmou a data da decisão do cliente.',
    restrita: false,
    gerado_com_ia: false,
  },
  {
    id: 'interacao-02',
    conta_id: 'conta-01',
    negocio_id: 'negocio-01',
    contato_id: 'contato-03',
    contato_nome: 'Controller de Exemplo',
    usuario_id: 'usuario-01',
    usuario_nome: 'Gerente de Contas de Exemplo',
    canal: 'email',
    ocorrida_em: momento(-12, 9),
    assunto: 'Envio do cronograma de parcelas',
    resumo: 'Cronograma enviado por escrito, como o guardião do orçamento pediu.',
    restrita: false,
    gerado_com_ia: false,
  },
  {
    id: 'interacao-03',
    conta_id: 'conta-01',
    negocio_id: 'negocio-11',
    contato_id: 'contato-02',
    contato_nome: 'Gerente Industrial de Exemplo',
    usuario_id: 'usuario-04',
    usuario_nome: 'Conselheiro de Exemplo',
    canal: 'reuniao_online',
    ocorrida_em: momento(-10, 16),
    assunto: 'Encontro mensal de conselho',
    resumo: 'Revisão do plano de gestão e leitura dos indicadores do mês.',
    restrita: false,
    gerado_com_ia: false,
  },
  {
    id: 'interacao-04',
    conta_id: 'conta-02',
    negocio_id: 'negocio-02',
    contato_id: 'contato-04',
    contato_nome: 'Sócio Fundador de Exemplo',
    usuario_id: 'usuario-01',
    usuario_nome: 'Gerente de Contas de Exemplo',
    canal: 'ligacao',
    ocorrida_em: momento(-9, 11),
    assunto: 'Conferência do nível do Contrato de Valor',
    resumo: null,
    restrita: false,
    gerado_com_ia: false,
  },
  {
    id: 'interacao-05',
    conta_id: 'conta-03',
    negocio_id: 'negocio-03',
    contato_id: 'contato-05',
    contato_nome: 'Sócia Responsável de Exemplo',
    usuario_id: 'usuario-02',
    usuario_nome: 'Segunda Pessoa de Exemplo',
    canal: 'reuniao_online',
    ocorrida_em: momento(-11, 15),
    assunto: 'Leitura do Plano de Trabalho',
    resumo: 'A sócia validou o escopo e pediu uma versão com os prazos por frente.',
    restrita: false,
    gerado_com_ia: false,
  },
  {
    id: 'interacao-06',
    conta_id: 'conta-05',
    negocio_id: 'negocio-05',
    contato_id: 'contato-06',
    contato_nome: 'Diretor de Operações de Exemplo',
    usuario_id: 'usuario-01',
    usuario_nome: 'Gerente de Contas de Exemplo',
    canal: 'visita',
    ocorrida_em: momento(-6, 10),
    assunto: 'Visita à obra e leitura do ciclo de gestão',
    resumo: null,
    restrita: false,
    gerado_com_ia: false,
  },
  {
    id: 'interacao-07',
    conta_id: 'conta-08',
    negocio_id: 'negocio-08',
    contato_id: 'contato-07',
    contato_nome: 'Pregoeiro de Exemplo',
    usuario_id: 'usuario-01',
    usuario_nome: 'Gerente de Contas de Exemplo',
    canal: 'outro',
    ocorrida_em: momento(-8, 13),
    assunto: 'Esclarecimento sobre a minuta do edital',
    resumo: 'Esclarecimento protocolado no portal, dentro do prazo do processo.',
    restrita: false,
    gerado_com_ia: false,
  },
]

const ROTAS_PUBLICAS_EXEMPLO: LinhaRotaPublica[] = [
  {
    negocio_id: 'negocio-08',
    identificador_pncp: '00000000000000-1-000001/2026',
    orgao: 'Instituto Vila Exemplo de Gestão Pública',
    modalidade: 'Pregão eletrônico',
    fase_administrativa: 'Publicação do edital',
    data_sessao: emDias(18),
    data_publicacao: emDias(-10),
    desfecho_publico: null,
  },
]

const CONTRATOS_EXEMPLO: LinhaContratoEmCurso[] = [
  {
    contrato_id: 'contrato-01',
    numero: 'CV-EXEMPLO-0001',
    titulo: 'Conselho dedicado · ciclo anual',
    conta_id: 'conta-05',
    conta_nome: 'Construtora Horizonte Modelo',
    oferta_nome: 'Conselho de Valor dedicado',
    modalidade: 'recorrente',
    nivel: 'n3',
    situacao: 'vigente',
    assinado: true,
    assinado_em: emDias(-205),
    vigencia_inicio: emDias(-200),
    vigencia_fim: emDias(165),
    meses_vigencia: 12,
    valor_total: 600000,
    valor_mensal: 50000,
    renovacao_automatica: false,
    dias_para_vencer: 165,
    na_janela_de_renovacao: false,
    sinal_de_vencimento: 'verde',
    tem_negocio_de_renovacao: true,
    negocio_renovacao_id: 'negocio-12',
  },
  {
    contrato_id: 'contrato-02',
    numero: 'CV-EXEMPLO-0002',
    titulo: 'Monitoria de valor · semestre',
    conta_id: 'conta-01',
    conta_nome: 'Metalúrgica Aurora Fictícia',
    oferta_nome: 'Monitoria de Valor',
    modalidade: 'pontual_com_sustentacao',
    nivel: 'n2',
    situacao: 'vigente',
    assinado: true,
    assinado_em: emDias(-120),
    vigencia_inicio: emDias(-118),
    vigencia_fim: emDias(45),
    meses_vigencia: 6,
    valor_total: 90000,
    valor_mensal: 15000,
    renovacao_automatica: true,
    dias_para_vencer: 45,
    na_janela_de_renovacao: true,
    sinal_de_vencimento: 'amarelo',
    tem_negocio_de_renovacao: false,
    negocio_renovacao_id: null,
  },
]

const SAUDE_EXEMPLO: LinhaSaudeDaConta[] = CONTAS_EXEMPLO.map((conta) => {
  const negocios = SEMENTES.filter(
    (semente) => semente.conta_id === conta.id && semente.fase >= 1 && semente.fase <= 4,
  )
  const contratos = CONTRATOS_EXEMPLO.filter((contrato) => contrato.conta_id === conta.id)
  const interacoes = INTERACOES_EXEMPLO.filter((linha) => linha.conta_id === conta.id)
  const ultimo = interacoes
    .map((linha) => linha.ocorrida_em.slice(0, 10))
    .sort()
    .at(-1)

  return {
    conta_id: conta.id,
    conta_nome: conta.nome,
    setor: conta.setor,
    cidade: conta.cidade,
    uf: conta.uf,
    tier: conta.tier,
    tier_rotulo:
      conta.tier === 't1'
        ? 'Tier 1, ouro'
        : conta.tier === 't2'
          ? 'Tier 2, prata'
          : conta.tier === 't3'
            ? 'Tier 3, bronze'
            : 'Tier a confirmar',
    tier_sugerido: conta.tier_sugerido,
    tier_confirmado_em: conta.tier_confirmado_em,
    tier_diverge_da_sugestao: conta.tier !== conta.tier_sugerido,
    prioridade: conta.prioridade,
    power_of_x: conta.power_of_x,
    eh_cliente: conta.eh_cliente,
    eh_prospecto: conta.eh_prospecto,
    gerente_contas_nome: conta.gerente_contas_nome,
    nps: conta.eh_cliente ? 70 : null,
    nps_respondentes: conta.eh_cliente ? 10 : null,
    nps_ultima_resposta: conta.eh_cliente ? emDias(-35) : null,
    contratos_vigentes: contratos.length,
    valor_mensal_vigente: contratos.reduce((total, linha) => total + (linha.valor_mensal ?? 0), 0),
    proximo_vencimento_de_contrato: contratos[0]?.vigencia_fim ?? null,
    ultimo_contato_em: ultimo ?? null,
    dias_sem_contato: ultimo
      ? Math.round((Date.now() - new Date(`${ultimo}T12:00:00`).getTime()) / 86_400_000)
      : null,
    negocios_ativos: negocios.length,
    pipeline_da_conta: negocios.reduce((total, linha) => total + (linha.valor_total ?? 0), 0),
    alertas_abertos: conta.id === 'conta-04' ? 2 : conta.id === 'conta-06' ? 1 : 0,
    alertas_vermelhos: conta.id === 'conta-04' ? 1 : 0,
    turmas_ativas: conta.eh_cliente ? 1 : 0,
    pendencias_vencidas: conta.id === 'conta-04' ? 1 : 0,
  }
})

const ALERTAS_EXEMPLO: LinhaAlertaAberto[] = [
  {
    alerta_id: 'alerta-01',
    regra_nome: 'Negócio parado além do limite da fase',
    criticidade: 'vermelho',
    criticidade_rotulo: 'Vermelho, age hoje',
    mensagem: 'Passaram cinquenta e dois dias sem conversa registrada neste negócio.',
    dias_aberto: 12,
    conta_id: 'conta-04',
    negocio_id: 'negocio-04',
    negocio_titulo: 'Liderança de Valor · turma compartilhada',
    quem_age_nome: 'Segunda Pessoa de Exemplo',
  },
  {
    alerta_id: 'alerta-02',
    regra_nome: 'Artefato da fase em rascunho',
    criticidade: 'amarelo',
    criticidade_rotulo: 'Amarelo, age esta semana',
    mensagem: 'O Plano de Trabalho da fase atual ainda está em rascunho.',
    dias_aberto: 5,
    conta_id: 'conta-04',
    negocio_id: 'negocio-04',
    negocio_titulo: 'Liderança de Valor · turma compartilhada',
    quem_age_nome: 'Segunda Pessoa de Exemplo',
  },
  {
    alerta_id: 'alerta-03',
    regra_nome: 'Negócio sem próximo passo com data',
    criticidade: 'amarelo',
    criticidade_rotulo: 'Amarelo, age esta semana',
    mensagem: 'Este negócio está sem próximo passo com data definida.',
    dias_aberto: 3,
    conta_id: 'conta-06',
    negocio_id: 'negocio-06',
    negocio_titulo: 'Executivo de Valor · acompanhamento anual',
    quem_age_nome: 'Segunda Pessoa de Exemplo',
  },
]

// ==================================================== atividades de exemplo

const CONTEXTOS_EXEMPLO: ContextoGtd[] = [
  { id: 'ctx-01', codigo: '@ligar', rotulo: 'Ligar', descricao: 'Tudo que se resolve com uma ligação.', ordem: 10 },
  { id: 'ctx-02', codigo: '@escrever', rotulo: 'Escrever', descricao: 'Documento ou artefato para redigir.', ordem: 20 },
  { id: 'ctx-03', codigo: '@reuniao', rotulo: 'Reunião', descricao: 'Só avança com gente junto.', ordem: 30 },
  { id: 'ctx-04', codigo: '@decidir', rotulo: 'Decidir', descricao: 'Espera uma decisão da casa.', ordem: 40 },
  { id: 'ctx-05', codigo: '@esperar', rotulo: 'Esperar', descricao: 'Está na mão de terceiro.', ordem: 50 },
]

const COLUNAS_EXEMPLO: ColunaDoQuadro[] = [
  { id: 'coluna-01', nome: 'Entrada', estado_gtd: 'entrada', ordem: 10, cor: '#707070', limite_wip: null },
  { id: 'coluna-02', nome: 'Próxima ação', estado_gtd: 'proxima_acao', ordem: 20, cor: '#5E1E3A', limite_wip: 5 },
  { id: 'coluna-03', nome: 'Agendada', estado_gtd: 'agendada', ordem: 30, cor: '#C2900A', limite_wip: null },
  { id: 'coluna-04', nome: 'Aguardando', estado_gtd: 'aguardando', ordem: 40, cor: '#C58A00', limite_wip: null },
  { id: 'coluna-05', nome: 'Algum dia', estado_gtd: 'algum_dia', ordem: 50, cor: '#1D1D1B', limite_wip: null },
  { id: 'coluna-06', nome: 'Concluída', estado_gtd: 'concluida', ordem: 60, cor: '#2E7D4F', limite_wip: null },
]

function atividadesDeExemplo(): LinhaAtividade[] {
  const base = (
    parcial: Partial<LinhaAtividade> & Pick<LinhaAtividade, 'id' | 'titulo' | 'estado'>,
  ): LinhaAtividade => ({
    descricao: null,
    contexto_id: null,
    contexto_codigo: null,
    contexto_rotulo: null,
    energia: null,
    tempo_estimado_min: null,
    prazo: null,
    agendada_para: null,
    responsavel_id: 'usuario-01',
    responsavel_nome: 'Gerente de Contas de Exemplo',
    delegado_para_id: null,
    delegado_para_externo: null,
    aguardando_desde: null,
    prioridade: null,
    ordem_kanban: 0,
    conta_id: null,
    conta_nome: null,
    negocio_id: null,
    negocio_titulo: null,
    recorrencia_id: null,
    recorrencia_nome: null,
    proxima_ocorrencia_id: null,
    concluida_em: null,
    ...parcial,
  })

  return [
    base({
      id: 'atividade-01',
      titulo: 'Montar o Plano de Conta com a hipótese de valor',
      estado: 'proxima_acao',
      contexto_id: 'ctx-02',
      contexto_codigo: '@escrever',
      contexto_rotulo: 'Escrever',
      energia: 'alta',
      tempo_estimado_min: 90,
      prazo: emDias(4),
      prioridade: 1,
      ordem_kanban: 1,
      conta_id: 'conta-07',
      conta_nome: 'Softworks Exemplo',
      negocio_id: 'negocio-07',
      negocio_titulo: 'Diagnóstico de gestão e desenho do ciclo',
    }),
    base({
      id: 'atividade-02',
      titulo: 'Reunião de assinatura com a diretoria',
      estado: 'agendada',
      contexto_id: 'ctx-03',
      contexto_codigo: '@reuniao',
      contexto_rotulo: 'Reunião',
      energia: 'alta',
      tempo_estimado_min: 60,
      prazo: emDias(7),
      agendada_para: momento(7, 15),
      prioridade: 1,
      ordem_kanban: 1,
      conta_id: 'conta-01',
      conta_nome: 'Metalúrgica Aurora Fictícia',
      negocio_id: 'negocio-01',
      negocio_titulo: 'Conselho dedicado · ciclo de doze meses',
    }),
    base({
      id: 'atividade-03',
      titulo: 'Cobrar a devolutiva do controller sobre o cronograma',
      estado: 'aguardando',
      contexto_id: 'ctx-05',
      contexto_codigo: '@esperar',
      contexto_rotulo: 'Esperar',
      energia: 'baixa',
      tempo_estimado_min: 15,
      prazo: emDias(-3),
      aguardando_desde: emDias(-12),
      delegado_para_externo: 'Controller de Exemplo',
      prioridade: 2,
      ordem_kanban: 1,
      conta_id: 'conta-01',
      conta_nome: 'Metalúrgica Aurora Fictícia',
    }),
    base({
      id: 'atividade-04',
      titulo: 'Ligar para a sócia responsável sobre o Plano de Trabalho',
      estado: 'proxima_acao',
      contexto_id: 'ctx-01',
      contexto_codigo: '@ligar',
      contexto_rotulo: 'Ligar',
      energia: 'media',
      tempo_estimado_min: 20,
      prazo: emDias(2),
      prioridade: 1,
      ordem_kanban: 2,
      responsavel_id: 'usuario-02',
      responsavel_nome: 'Segunda Pessoa de Exemplo',
      conta_id: 'conta-03',
      conta_nome: 'Clínica Bem Viver Exemplo',
      negocio_id: 'negocio-03',
      negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    }),
    base({
      id: 'atividade-05',
      titulo: 'Revisar a pauta do encontro mensal de conselho',
      estado: 'proxima_acao',
      contexto_id: 'ctx-02',
      contexto_codigo: '@escrever',
      contexto_rotulo: 'Escrever',
      energia: 'media',
      tempo_estimado_min: 45,
      prazo: emDias(0),
      prioridade: 2,
      ordem_kanban: 3,
      recorrencia_id: 'recorrencia-01',
      recorrencia_nome: 'Pauta mensal do conselho',
      conta_id: 'conta-05',
      conta_nome: 'Construtora Horizonte Modelo',
    }),
    base({
      id: 'atividade-06',
      titulo: 'Decidir o nível do Contrato de Valor da turma dedicada',
      estado: 'entrada',
      contexto_id: 'ctx-04',
      contexto_codigo: '@decidir',
      contexto_rotulo: 'Decidir',
      energia: 'alta',
      tempo_estimado_min: 30,
      prazo: emDias(3),
      prioridade: 1,
      ordem_kanban: 1,
      conta_id: 'conta-02',
      conta_nome: 'Transportes Serra Modelo',
      negocio_id: 'negocio-02',
      negocio_titulo: 'Negócios de Valor · turma dedicada',
    }),
    base({
      id: 'atividade-07',
      titulo: 'Estudar o portfólio de gestão pública para a rota pública',
      estado: 'algum_dia',
      contexto_id: 'ctx-02',
      contexto_codigo: '@escrever',
      contexto_rotulo: 'Escrever',
      energia: 'baixa',
      tempo_estimado_min: 120,
      ordem_kanban: 1,
    }),
    base({
      id: 'atividade-08',
      titulo: 'Conferir a minuta do edital publicada no portal',
      estado: 'agendada',
      contexto_id: 'ctx-04',
      contexto_codigo: '@decidir',
      contexto_rotulo: 'Decidir',
      energia: 'media',
      tempo_estimado_min: 60,
      prazo: emDias(6),
      agendada_para: momento(6, 9),
      prioridade: 1,
      ordem_kanban: 2,
      conta_id: 'conta-08',
      conta_nome: 'Instituto Vila Exemplo',
      negocio_id: 'negocio-08',
      negocio_titulo: 'Programa de gestão para a rede de unidades',
    }),
    base({
      id: 'atividade-09',
      titulo: 'Registrar a conversa de qualificação da sondagem',
      estado: 'entrada',
      contexto_id: 'ctx-02',
      contexto_codigo: '@escrever',
      contexto_rotulo: 'Escrever',
      energia: 'baixa',
      tempo_estimado_min: 15,
      prazo: emDias(1),
      ordem_kanban: 2,
      responsavel_id: 'usuario-02',
      responsavel_nome: 'Segunda Pessoa de Exemplo',
      conta_id: 'conta-06',
      conta_nome: 'Rede Sabor Fictícia',
      negocio_id: 'negocio-09',
      negocio_titulo: 'Sondagem de conselho compartilhado',
    }),
    base({
      id: 'atividade-10',
      titulo: 'Enviar o resumo do encontro de turma número seis',
      estado: 'concluida',
      contexto_id: 'ctx-02',
      contexto_codigo: '@escrever',
      contexto_rotulo: 'Escrever',
      energia: 'baixa',
      tempo_estimado_min: 20,
      prazo: emDias(-2),
      ordem_kanban: 1,
      concluida_em: momento(-2, 18),
      responsavel_id: 'usuario-04',
      responsavel_nome: 'Conselheiro de Exemplo',
      conta_id: 'conta-05',
      conta_nome: 'Construtora Horizonte Modelo',
    }),
    base({
      id: 'atividade-11',
      titulo: 'Cobrar o parceiro sobre a indicação da semana passada',
      estado: 'aguardando',
      contexto_id: 'ctx-05',
      contexto_codigo: '@esperar',
      contexto_rotulo: 'Esperar',
      energia: 'baixa',
      tempo_estimado_min: 10,
      prazo: emDias(5),
      aguardando_desde: emDias(-9),
      delegado_para_externo: 'Parceiro Exemplo Consultoria',
      ordem_kanban: 2,
    }),
  ]
}

const JANELA_PADRAO = 7

/** Refaz os quatro montes da caixa de entrada com as regras da visão do banco. */
function caixaDeExemplo(atividades: LinhaAtividade[], janela: number): LinhaCaixaDeEntrada[] {
  const abertas = atividades.filter(
    (linha) => linha.estado !== 'concluida' && linha.estado !== 'cancelada',
  )
  const limiteJanela = emDias(janela)
  const caixa: LinhaCaixaDeEntrada[] = []

  const dias = (de: string, para: string) =>
    Math.round(
      (new Date(`${para}T12:00:00`).getTime() - new Date(`${de}T12:00:00`).getTime()) / 86_400_000,
    )

  for (const linha of abertas) {
    const comum = {
      atividade_id: linha.id,
      titulo: linha.titulo,
      estado: linha.estado,
      prazo: linha.prazo,
      prioridade: linha.prioridade,
    }

    if (linha.prazo && linha.prazo < HOJE_ISO) {
      caixa.push({
        ...comum,
        grupo: 'vencida',
        rotulo: 'Venceu',
        ordem_grupo: 2,
        dias: dias(linha.prazo, HOJE_ISO),
      })
    } else if (linha.prazo && linha.prazo <= limiteJanela) {
      caixa.push({
        ...comum,
        grupo: 'vence_na_janela',
        rotulo: `Vence em ${janela} dias`,
        ordem_grupo: 3,
        dias: dias(HOJE_ISO, linha.prazo),
      })
    }

    if (linha.estado === 'aguardando' && linha.aguardando_desde) {
      const parado = dias(linha.aguardando_desde, HOJE_ISO)
      if (parado >= janela) {
        caixa.push({
          ...comum,
          grupo: 'aguardando_terceiro',
          rotulo: `Aguardando terceiro há mais de ${janela} dias`,
          ordem_grupo: 4,
          dias: parado,
        })
      }
    }

    if (linha.id === 'atividade-09' || linha.id === 'atividade-06') {
      caixa.push({ ...comum, grupo: 'entrou_hoje', rotulo: 'Caiu hoje', ordem_grupo: 1, dias: 0 })
    }
  }

  return caixa
}

function agendaDeExemplo(): LinhaAgenda[] {
  return [
    {
      tipo: 'encontro',
      tipo_rotulo: 'Encontro da turma',
      referencia_id: 'encontro-01',
      titulo: 'Encontro 7 · Gestão do ciclo',
      quando_em: emDias(2),
      hora_inicio: '09:00:00',
      hora_fim: '12:00:00',
      local: 'Sala de conselho, Vila Exemplo',
      link: null,
      status: 'previsto',
      turma_id: 'turma-01',
      turma_nome: 'Turma dedicada Horizonte Modelo',
      conta_id: null,
      conta_nome: null,
      dias_ate: 2,
    },
    {
      tipo: 'reuniao',
      tipo_rotulo: 'Reunião de conselho',
      referencia_id: 'pauta-01',
      titulo: 'Reunião mensal de conselho',
      quando_em: emDias(4),
      hora_inicio: '14:00:00',
      hora_fim: null,
      local: null,
      link: null,
      status: 'publicada',
      turma_id: null,
      turma_nome: null,
      conta_id: 'conta-01',
      conta_nome: 'Metalúrgica Aurora Fictícia',
      dias_ate: 4,
    },
    {
      tipo: 'compromisso',
      tipo_rotulo: 'Compromisso da agenda',
      referencia_id: 'atividade-02',
      titulo: 'Reunião de assinatura com a diretoria',
      quando_em: emDias(7),
      hora_inicio: '15:00:00',
      hora_fim: null,
      local: null,
      link: null,
      status: 'agendada',
      turma_id: null,
      turma_nome: null,
      conta_id: 'conta-01',
      conta_nome: 'Metalúrgica Aurora Fictícia',
      dias_ate: 7,
    },
    {
      tipo: 'compromisso',
      tipo_rotulo: 'Compromisso da agenda',
      referencia_id: 'atividade-08',
      titulo: 'Conferir a minuta do edital publicada no portal',
      quando_em: emDias(6),
      hora_inicio: '09:00:00',
      hora_fim: null,
      local: null,
      link: null,
      status: 'agendada',
      turma_id: null,
      turma_nome: null,
      conta_id: 'conta-08',
      conta_nome: 'Instituto Vila Exemplo',
      dias_ate: 6,
    },
  ]
}

// ======================================================= leitura do banco

type Embutido<T> = T | T[] | null

function primeiro<T>(valor: Embutido<T>): T | null {
  if (!valor) return null
  if (Array.isArray(valor)) return valor[0] ?? null
  return valor
}

function nomeDe(valor: Embutido<{ nome: string }>): string | null {
  return primeiro(valor)?.nome ?? null
}

function numeroOuNulo(valor: number | string | null | undefined): number | null {
  if (valor === null || valor === undefined || valor === '') return null
  const convertido = Number(valor)
  return Number.isNaN(convertido) ? null : convertido
}

const CAMPOS_CONTA =
  'id, nome, razao_social, cnpj, setor, porte, cidade, uf, site, tier, tier_sugerido, tier_confirmado_em, prioridade, power_of_x, eh_cliente, eh_prospecto, eh_fornecedor, eh_parceiro, gerente_contas_id, observacoes, criado_em, gerente:usuarios(nome)'

interface ContaCrua extends Omit<LinhaConta, 'gerente_contas_nome' | 'power_of_x' | 'prioridade'> {
  power_of_x: number | string | null
  prioridade: number | null
  gerente: Embutido<{ nome: string }>
}

function comoConta(linha: ContaCrua): LinhaConta {
  const prioridade = linha.prioridade
  return {
    ...linha,
    power_of_x: numeroOuNulo(linha.power_of_x) ?? 0,
    prioridade: prioridade === 1 || prioridade === 2 || prioridade === 3 ? prioridade : null,
    gerente_contas_nome: nomeDe(linha.gerente),
  }
}

async function lerContas(): Promise<LinhaConta[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data, error } = await cliente
    .from('contas')
    .select(CAMPOS_CONTA)
    .is('arquivado_em', null)
    .order('nome')
    .returns<ContaCrua[]>()

  if (error) throw new Error(error.message)
  return (data ?? []).map(comoConta)
}

/** A visão não carrega descrição nem leitura qualitativa. Estas vêm da tabela. */
interface ComplementoNegocio {
  id: string
  descricao: string | null
  probabilidade: LinhaNegocioForecast['probabilidade']
  desfecho: LinhaNegocioForecast['desfecho']
  proximo_passo_responsavel: string | null
  responsavel: Embutido<{ nome: string }>
}

async function lerComplementos(cliente: NonNullable<ReturnType<typeof obterCliente>>) {
  const { data, error } = await cliente
    .from('negocios')
    .select('id, descricao, probabilidade, desfecho, proximo_passo_responsavel, responsavel:usuarios(nome)')
    .is('arquivado_em', null)
    .returns<ComplementoNegocio[]>()

  if (error) throw new Error(error.message)

  const mapa = new Map<string, ComplementoNegocio>()
  for (const linha of data ?? []) mapa.set(linha.id, linha)
  return mapa
}

interface NegocioCru extends Omit<
  LinhaNegocioForecast,
  'fase' | 'probabilidade' | 'descricao' | 'desfecho' | 'proximo_passo_responsavel_nome' |
  'conselheiro_entrou_na_fase' | 'valor_total' | 'valor_recorrente_mes' | 'valor_considerado'
> {
  fase: number
  conselheiro_entrou_na_fase: number | null
  valor_total: number | string | null
  valor_recorrente_mes: number | string | null
  valor_considerado: number | string | null
}

function comoNegocio(
  linha: NegocioCru,
  complemento: ComplementoNegocio | undefined,
): LinhaNegocioForecast {
  return {
    ...linha,
    fase: comoFase(linha.fase),
    valor_total: numeroOuNulo(linha.valor_total),
    valor_recorrente_mes: numeroOuNulo(linha.valor_recorrente_mes),
    valor_considerado: numeroOuNulo(linha.valor_considerado),
    conselheiro_entrou_na_fase:
      linha.conselheiro_entrou_na_fase === null ? null : comoFase(linha.conselheiro_entrou_na_fase),
    proximo_passo_responsavel_nome: nomeDe(complemento?.responsavel ?? null),
    probabilidade: complemento?.probabilidade ?? null,
    descricao: complemento?.descricao ?? null,
    desfecho: complemento?.desfecho ?? null,
  }
}

async function lerNegocios(): Promise<PainelDeNegocios> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data, error } = await cliente
    .from('vw_negocios_forecast')
    .select('*')
    .order('fase')
    .returns<NegocioCru[]>()

  if (error) throw new Error(error.message)

  const complementos = await lerComplementos(cliente)

  const { data: pipeline, error: erroPipeline } = await cliente
    .from('vw_pipeline_higiene')
    .select('*')
    .returns<LinhaPipelineHigiene[]>()

  if (erroPipeline) throw new Error(erroPipeline.message)

  return {
    negocios: (data ?? []).map((linha) => comoNegocio(linha, complementos.get(linha.negocio_id))),
    pipeline: pipeline?.[0] ?? null,
  }
}

interface InteracaoCrua extends Omit<LinhaInteracao, 'contato_nome' | 'usuario_nome'> {
  contato: Embutido<{ nome: string }>
  usuario: Embutido<{ nome: string }>
}

function comoInteracao(linha: InteracaoCrua): LinhaInteracao {
  return {
    ...linha,
    contato_nome: nomeDe(linha.contato),
    usuario_nome: nomeDe(linha.usuario),
  }
}

const CAMPOS_INTERACAO =
  'id, conta_id, negocio_id, contato_id, usuario_id, canal, ocorrida_em, assunto, resumo, restrita, gerado_com_ia, contato:contatos(nome), usuario:usuarios(nome)'

async function lerFichaDaConta(contaId: string): Promise<FichaDaConta> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data: conta, error: erroConta } = await cliente
    .from('contas')
    .select(CAMPOS_CONTA)
    .eq('id', contaId)
    .is('arquivado_em', null)
    .returns<ContaCrua[]>()

  if (erroConta) throw new Error(erroConta.message)
  const primeiraConta = conta?.[0]
  if (!primeiraConta) throw new Error('Conta não encontrada, ou fora do alcance deste perfil.')

  const [contatos, negocios, contratos, interacoes, saude, alertas] = await Promise.all([
    cliente
      .from('contatos')
      .select('id, conta_id, nome, cargo, papel_decisao, email, telefone, linkedin, eh_principal, observacoes')
      .eq('conta_id', contaId)
      .is('arquivado_em', null)
      .order('eh_principal', { ascending: false })
      .returns<LinhaContato[]>(),
    cliente.from('vw_negocios_forecast').select('*').eq('conta_id', contaId).returns<NegocioCru[]>(),
    cliente
      .from('vw_contratos_em_curso')
      .select('*')
      .eq('conta_id', contaId)
      .returns<LinhaContratoEmCurso[]>(),
    cliente
      .from('interacoes')
      .select(CAMPOS_INTERACAO)
      .eq('conta_id', contaId)
      .is('arquivado_em', null)
      .order('ocorrida_em', { ascending: false })
      .limit(60)
      .returns<InteracaoCrua[]>(),
    cliente.from('vw_saude_da_conta').select('*').eq('conta_id', contaId).returns<LinhaSaudeDaConta[]>(),
    cliente.from('vw_alertas_abertos').select('*').eq('conta_id', contaId).returns<LinhaAlertaAberto[]>(),
  ])

  const falha =
    contatos.error ?? negocios.error ?? contratos.error ?? interacoes.error ?? saude.error ?? alertas.error
  if (falha) throw new Error(falha.message)

  const complementos = await lerComplementos(cliente)

  return {
    conta: comoConta(primeiraConta),
    contatos: contatos.data ?? [],
    negocios: (negocios.data ?? []).map((linha) =>
      comoNegocio(linha, complementos.get(linha.negocio_id)),
    ),
    contratos: contratos.data ?? [],
    interacoes: (interacoes.data ?? []).map(comoInteracao),
    saude: saude.data?.[0] ?? null,
    alertas: alertas.data ?? [],
  }
}

interface PapelCru extends Omit<LinhaPapelNegocio, 'entrou_na_fase' | 'usuario_nome' | 'parceiro_nome'> {
  entrou_na_fase: number
  usuario: Embutido<{ nome: string }>
  parceiro: Embutido<{ nome: string }>
}

async function lerFichaDoNegocio(negocioId: string): Promise<FichaDoNegocio> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data: negocio, error: erroNegocio } = await cliente
    .from('vw_negocios_forecast')
    .select('*')
    .eq('negocio_id', negocioId)
    .returns<NegocioCru[]>()

  if (erroNegocio) throw new Error(erroNegocio.message)
  const primeiroNegocio = negocio?.[0]
  if (!primeiroNegocio) throw new Error('Negócio não encontrado, ou fora do alcance deste perfil.')

  const [complemento, artefatos, papeis, interacoes, publica] = await Promise.all([
    cliente
      .from('negocios')
      .select('id, descricao, probabilidade, desfecho, proximo_passo_responsavel, responsavel:usuarios(nome)')
      .eq('id', negocioId)
      .returns<ComplementoNegocio[]>(),
    cliente
      .from('artefatos')
      .select('id, negocio_id, tipo, status, versao, titulo, arquivo_url, validado_em, gerado_com_ia, criado_em')
      .eq('negocio_id', negocioId)
      .is('arquivado_em', null)
      .order('criado_em')
      .returns<LinhaArtefato[]>(),
    cliente
      .from('papeis_negocio')
      .select('id, negocio_id, usuario_id, parceiro_id, papel, entrou_na_fase, principal, ativo, usuario:usuarios(nome), parceiro:parceiros(nome)')
      .eq('negocio_id', negocioId)
      .is('arquivado_em', null)
      .order('entrou_na_fase')
      .returns<PapelCru[]>(),
    cliente
      .from('interacoes')
      .select(CAMPOS_INTERACAO)
      .eq('negocio_id', negocioId)
      .is('arquivado_em', null)
      .order('ocorrida_em', { ascending: false })
      .limit(60)
      .returns<InteracaoCrua[]>(),
    cliente
      .from('negocios_rota_publica')
      .select('*')
      .eq('negocio_id', negocioId)
      .returns<LinhaRotaPublica[]>(),
  ])

  const falha =
    complemento.error ?? artefatos.error ?? papeis.error ?? interacoes.error ?? publica.error
  if (falha) throw new Error(falha.message)

  return {
    negocio: comoNegocio(primeiroNegocio, complemento.data?.[0]),
    artefatos: artefatos.data ?? [],
    papeis: (papeis.data ?? []).map((linha) => ({
      ...linha,
      entrou_na_fase: comoFase(linha.entrou_na_fase),
      usuario_nome: nomeDe(linha.usuario),
      parceiro_nome: nomeDe(linha.parceiro),
    })),
    interacoes: (interacoes.data ?? []).map(comoInteracao),
    rota_publica: publica.data?.[0] ?? null,
  }
}

interface AtividadeCrua extends Omit<
  LinhaAtividade,
  'contexto_codigo' | 'contexto_rotulo' | 'responsavel_nome' | 'conta_nome' | 'negocio_titulo' | 'recorrencia_nome' | 'prioridade'
> {
  prioridade: number | null
  contexto: Embutido<{ codigo: string; rotulo: string }>
  responsavel: Embutido<{ nome: string }>
  conta: Embutido<{ nome: string }>
  negocio: Embutido<{ titulo: string }>
  recorrencia: Embutido<{ nome: string }>
}

const CAMPOS_ATIVIDADE =
  'id, titulo, descricao, estado, contexto_id, energia, tempo_estimado_min, prazo, agendada_para, responsavel_id, delegado_para_id, delegado_para_externo, aguardando_desde, prioridade, ordem_kanban, conta_id, negocio_id, recorrencia_id, proxima_ocorrencia_id, concluida_em, contexto:contextos_gtd(codigo, rotulo), responsavel:usuarios(nome), conta:contas(nome), negocio:negocios(titulo), recorrencia:atividades_recorrencia(nome)'

function comoAtividade(linha: AtividadeCrua): LinhaAtividade {
  const contexto = primeiro(linha.contexto)
  const prioridade = linha.prioridade
  return {
    ...linha,
    prioridade: prioridade === 1 || prioridade === 2 || prioridade === 3 ? prioridade : null,
    contexto_codigo: contexto?.codigo ?? null,
    contexto_rotulo: contexto?.rotulo ?? null,
    responsavel_nome: nomeDe(linha.responsavel),
    conta_nome: nomeDe(linha.conta),
    negocio_titulo: primeiro(linha.negocio)?.titulo ?? null,
    recorrencia_nome: nomeDe(linha.recorrencia),
  }
}

async function lerQuadroDeAtividades(): Promise<QuadroDeAtividades> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const [atividades, colunas, contextos, caixa] = await Promise.all([
    cliente
      .from('atividades')
      .select(CAMPOS_ATIVIDADE)
      .is('arquivado_em', null)
      .order('ordem_kanban')
      .returns<AtividadeCrua[]>(),
    cliente
      .from('colunas_kanban')
      .select('id, nome, estado_gtd, ordem, cor, limite_wip')
      .eq('ativa', true)
      .is('arquivado_em', null)
      .order('ordem')
      .returns<ColunaDoQuadro[]>(),
    cliente
      .from('contextos_gtd')
      .select('id, codigo, rotulo, descricao, ordem')
      .eq('ativo', true)
      .is('arquivado_em', null)
      .order('ordem')
      .returns<ContextoGtd[]>(),
    cliente
      .from('caixa_de_entrada')
      .select('atividade_id, titulo, estado, prazo, prioridade, grupo, rotulo, ordem_grupo, dias')
      .order('ordem_grupo')
      .returns<LinhaCaixaDeEntrada[]>(),
  ])

  const falha = atividades.error ?? colunas.error ?? contextos.error ?? caixa.error
  if (falha) throw new Error(falha.message)

  return {
    atividades: (atividades.data ?? []).map(comoAtividade),
    colunas: colunas.data ?? [],
    contextos: contextos.data ?? [],
    caixa: caixa.data ?? [],
    janela_dias: JANELA_PADRAO,
  }
}

async function lerAgenda(inicio: string, fim: string): Promise<LinhaAgenda[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const [agenda, atividades] = await Promise.all([
    cliente.from('vw_agenda_da_semana').select('*').returns<LinhaAgenda[]>(),
    cliente
      .from('atividades')
      .select('id, titulo, prazo, agendada_para, estado, conta_id, conta:contas(nome)')
      .is('arquivado_em', null)
      .not('prazo', 'is', null)
      .gte('prazo', inicio)
      .lte('prazo', fim)
      .returns<
        Array<{
          id: string
          titulo: string
          prazo: string | null
          agendada_para: string | null
          estado: EstadoGtd
          conta_id: string | null
          conta: Embutido<{ nome: string }>
        }>
      >(),
  ])

  const falha = agenda.error ?? atividades.error
  if (falha) throw new Error(falha.message)

  const daSemana = agenda.data ?? []
  const jaTem = new Set(daSemana.map((linha) => linha.referencia_id))

  const comPrazo: LinhaAgenda[] = (atividades.data ?? [])
    .filter((linha) => !jaTem.has(linha.id) && linha.estado !== 'concluida' && linha.estado !== 'cancelada')
    .map((linha) => ({
      tipo: 'compromisso',
      tipo_rotulo: 'Atividade com prazo',
      referencia_id: linha.id,
      titulo: linha.titulo,
      quando_em: linha.prazo,
      hora_inicio: linha.agendada_para ? linha.agendada_para.slice(11, 19) : null,
      hora_fim: null,
      local: null,
      link: null,
      status: linha.estado,
      turma_id: null,
      turma_nome: null,
      conta_id: linha.conta_id,
      conta_nome: nomeDe(linha.conta),
      dias_ate: null,
    }))

  return [...daSemana, ...comPrazo]
}

// =========================================================== as consultas

/** A lista de contas, do banco ou do exemplo. */
export function useContas(): UseQueryResult<RespostaCrm<LinhaConta[]>, Error> {
  return useQuery<RespostaCrm<LinhaConta[]>, Error>({
    queryKey: ['crm', 'contas', fonte()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { dados: CONTAS_EXEMPLO, deExemplo: true }
      return { dados: await lerContas(), deExemplo: false }
    },
  })
}

/** A ficha inteira de uma conta, com as seis abas de uma vez só. */
export function useFichaDaConta(contaId: string | undefined): UseQueryResult<
  RespostaCrm<FichaDaConta>,
  Error
> {
  return useQuery<RespostaCrm<FichaDaConta>, Error>({
    queryKey: ['crm', 'conta', contaId ?? '', fonte()],
    enabled: Boolean(contaId),
    staleTime: 60_000,
    queryFn: async () => {
      const id = contaId ?? ''
      if (!temBanco()) {
        const conta = CONTAS_EXEMPLO.find((linha) => linha.id === id)
        if (!conta) throw new Error('Conta não encontrada no conjunto de exemplo.')
        return {
          dados: {
            conta,
            contatos: CONTATOS_EXEMPLO.filter((linha) => linha.conta_id === id),
            negocios: negociosDeExemplo().filter((linha) => linha.conta_id === id),
            contratos: CONTRATOS_EXEMPLO.filter((linha) => linha.conta_id === id),
            interacoes: INTERACOES_EXEMPLO.filter((linha) => linha.conta_id === id),
            saude: SAUDE_EXEMPLO.find((linha) => linha.conta_id === id) ?? null,
            alertas: ALERTAS_EXEMPLO.filter((linha) => linha.conta_id === id),
          },
          deExemplo: true,
        }
      }
      return { dados: await lerFichaDaConta(id), deExemplo: false }
    },
  })
}

/** A lista de negócios e as duas linhas do pipeline, na mesma consulta. */
export function useNegocios(): UseQueryResult<RespostaCrm<PainelDeNegocios>, Error> {
  return useQuery<RespostaCrm<PainelDeNegocios>, Error>({
    queryKey: ['crm', 'negocios', fonte()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        const negocios = negociosDeExemplo()
        return { dados: { negocios, pipeline: pipelineDeExemplo(negocios) }, deExemplo: true }
      }
      return { dados: await lerNegocios(), deExemplo: false }
    },
  })
}

/** A ficha do negócio, com artefatos, papéis, interações e rota pública. */
export function useFichaDoNegocio(negocioId: string | undefined): UseQueryResult<
  RespostaCrm<FichaDoNegocio>,
  Error
> {
  return useQuery<RespostaCrm<FichaDoNegocio>, Error>({
    queryKey: ['crm', 'negocio', negocioId ?? '', fonte()],
    enabled: Boolean(negocioId),
    staleTime: 60_000,
    queryFn: async () => {
      const id = negocioId ?? ''
      if (!temBanco()) {
        const negocio = negociosDeExemplo().find((linha) => linha.negocio_id === id)
        if (!negocio) throw new Error('Negócio não encontrado no conjunto de exemplo.')
        return {
          dados: {
            negocio,
            artefatos: artefatosDeExemplo(id),
            papeis: papeisDeExemplo(id),
            interacoes: INTERACOES_EXEMPLO.filter((linha) => linha.negocio_id === id),
            rota_publica: ROTAS_PUBLICAS_EXEMPLO.find((linha) => linha.negocio_id === id) ?? null,
          },
          deExemplo: true,
        }
      }
      return { dados: await lerFichaDoNegocio(id), deExemplo: false }
    },
  })
}

/** Atividades, colunas do quadro, contextos e caixa de entrada. */
export function useQuadroDeAtividades(): UseQueryResult<RespostaCrm<QuadroDeAtividades>, Error> {
  return useQuery<RespostaCrm<QuadroDeAtividades>, Error>({
    queryKey: ['crm', 'atividades', fonte()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        const atividades = atividadesDeExemplo()
        return {
          dados: {
            atividades,
            colunas: COLUNAS_EXEMPLO,
            contextos: CONTEXTOS_EXEMPLO,
            caixa: caixaDeExemplo(atividades, JANELA_PADRAO),
            janela_dias: JANELA_PADRAO,
          },
          deExemplo: true,
        }
      }
      return { dados: await lerQuadroDeAtividades(), deExemplo: false }
    },
  })
}

/** A agenda de um período, juntando encontro, reunião e compromisso. */
export function useAgenda(
  inicio: string,
  fim: string,
): UseQueryResult<RespostaCrm<LinhaAgenda[]>, Error> {
  return useQuery<RespostaCrm<LinhaAgenda[]>, Error>({
    queryKey: ['crm', 'agenda', inicio, fim, fonte()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        const daSemana = agendaDeExemplo()
        const jaTem = new Set(daSemana.map((linha) => linha.referencia_id))
        const comPrazo: LinhaAgenda[] = atividadesDeExemplo()
          .filter(
            (linha) =>
              linha.prazo !== null &&
              !jaTem.has(linha.id) &&
              linha.estado !== 'cancelada' &&
              linha.prazo >= inicio &&
              linha.prazo <= fim,
          )
          .map((linha) => ({
            tipo: 'compromisso',
            tipo_rotulo: 'Atividade com prazo',
            referencia_id: linha.id,
            titulo: linha.titulo,
            quando_em: linha.prazo,
            hora_inicio: linha.agendada_para ? linha.agendada_para.slice(11, 19) : null,
            hora_fim: null,
            local: null,
            link: null,
            status: linha.estado,
            turma_id: null,
            turma_nome: null,
            conta_id: linha.conta_id,
            conta_nome: linha.conta_nome,
            dias_ate: null,
          }))

        return { dados: [...daSemana, ...comPrazo], deExemplo: true }
      }
      return { dados: await lerAgenda(inicio, fim), deExemplo: false }
    },
  })
}

// ============================================================== escritas

/**
 * Atalho de escrita.
 *
 * O cliente vive preso ao esquema `valor` sem tipos gerados, então o corpo de
 * um `update` chega ao compilador como `never` e nenhuma gravação passa. Este
 * atalho devolve o construtor de consulta com a forma mínima que a escrita
 * usa. Não afrouxa regra nenhuma de negócio: quem decide se a linha pode ser
 * alterada continua sendo a política de linha do banco.
 */
interface EscritaSimples {
  update: (valores: Record<string, unknown>) => {
    eq: (coluna: string, valor: string) => PromiseLike<{ error: { message: string } | null }>
  }
}

function tabelaParaEscrita(nome: string): EscritaSimples {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')
  const abrir = cliente.from as unknown as (tabela: string) => EscritaSimples
  return abrir(nome)
}

export interface MudancaDeFase {
  negocio_id: Uuid
  fase: Fase
}

/**
 * Move o negócio de fase, que é o que o arrastar do quadro faz.
 * Com o banco ligado, grava. Sem banco, mexe só na cópia de tela, e a própria
 * tela avisa que a mudança não saiu do navegador.
 */
export function useMoverNegocioDeFase(): UseMutationResult<MudancaDeFase, Error, MudancaDeFase> {
  const fila = useQueryClient()

  return useMutation<MudancaDeFase, Error, MudancaDeFase>({
    mutationFn: async (mudanca) => {
      if (!temBanco()) return mudanca
      const { error } = await tabelaParaEscrita('negocios')
        .update({ fase: mudanca.fase, entrou_na_fase_em: HOJE_ISO })
        .eq('id', mudanca.negocio_id)
      if (error) throw new Error(error.message)
      return mudanca
    },
    onSuccess: (mudanca) => {
      const chave = ['crm', 'negocios', fonte()]
      fila.setQueryData<RespostaCrm<PainelDeNegocios>>(chave, (anterior) => {
        if (!anterior) return anterior
        const negocios = anterior.dados.negocios.map((linha) =>
          linha.negocio_id === mudanca.negocio_id
            ? { ...linha, fase: mudanca.fase, exige_higiene: mudanca.fase >= 1 && mudanca.fase <= 4 }
            : linha,
        )
        return { ...anterior, dados: { ...anterior.dados, negocios } }
      })
      if (temBanco()) void fila.invalidateQueries({ queryKey: ['crm'] })
    },
  })
}

/** Os campos de texto do negócio que a ficha deixa editar. */
export interface MudancaDeCampos {
  negocio_id: Uuid
  proximo_passo?: string | null
  proximo_passo_data?: string | null
  descricao?: string | null
}

/**
 * Grava os campos de texto da ficha do negócio.
 *
 * O botão assistido nunca chama esta função sozinho: ele só escreve no campo
 * quando a pessoa aceita a sugestão, e gravar é outro clique, sempre dela.
 */
export function useSalvarCamposDoNegocio(): UseMutationResult<MudancaDeCampos, Error, MudancaDeCampos> {
  const fila = useQueryClient()

  return useMutation<MudancaDeCampos, Error, MudancaDeCampos>({
    mutationFn: async (mudanca) => {
      if (!temBanco()) return mudanca

      const remendo: Record<string, unknown> = {}
      if (mudanca.proximo_passo !== undefined) remendo.proximo_passo = mudanca.proximo_passo
      if (mudanca.proximo_passo_data !== undefined) {
        remendo.proximo_passo_data = mudanca.proximo_passo_data
      }
      if (mudanca.descricao !== undefined) remendo.descricao = mudanca.descricao
      if (Object.keys(remendo).length === 0) return mudanca

      const { error } = await tabelaParaEscrita('negocios')
        .update(remendo)
        .eq('id', mudanca.negocio_id)
      if (error) throw new Error(error.message)
      return mudanca
    },
    onSuccess: (mudanca) => {
      const remendar = (linha: LinhaNegocioForecast): LinhaNegocioForecast => {
        const proximoPasso =
          mudanca.proximo_passo === undefined ? linha.proximo_passo : mudanca.proximo_passo
        const proximoPassoData =
          mudanca.proximo_passo_data === undefined
            ? linha.proximo_passo_data
            : mudanca.proximo_passo_data
        return {
          ...linha,
          proximo_passo: proximoPasso,
          proximo_passo_data: proximoPassoData,
          descricao: mudanca.descricao === undefined ? linha.descricao : mudanca.descricao,
          tem_proximo_passo: Boolean(
            proximoPasso && proximoPassoData && proximoPassoData >= HOJE_ISO,
          ),
        }
      }

      fila.setQueryData<RespostaCrm<FichaDoNegocio>>(
        ['crm', 'negocio', mudanca.negocio_id, fonte()],
        (anterior) =>
          anterior
            ? { ...anterior, dados: { ...anterior.dados, negocio: remendar(anterior.dados.negocio) } }
            : anterior,
      )

      fila.setQueryData<RespostaCrm<PainelDeNegocios>>(
        ['crm', 'negocios', fonte()],
        (anterior) =>
          anterior
            ? {
                ...anterior,
                dados: {
                  ...anterior.dados,
                  negocios: anterior.dados.negocios.map((linha) =>
                    linha.negocio_id === mudanca.negocio_id ? remendar(linha) : linha,
                  ),
                },
              }
            : anterior,
      )

      if (temBanco()) void fila.invalidateQueries({ queryKey: ['crm'] })
    },
  })
}

export interface MudancaDeEstado {
  atividade_id: Uuid
  estado: EstadoGtd
}

/** Move a atividade de coluna, ou seja, de estado do método GTD. */
export function useMoverAtividade(): UseMutationResult<MudancaDeEstado, Error, MudancaDeEstado> {
  const fila = useQueryClient()

  return useMutation<MudancaDeEstado, Error, MudancaDeEstado>({
    mutationFn: async (mudanca) => {
      if (!temBanco()) return mudanca
      const remendo: Record<string, unknown> = { estado: mudanca.estado }
      if (mudanca.estado === 'aguardando') remendo.aguardando_desde = HOJE_ISO
      if (mudanca.estado === 'concluida') remendo.concluida_em = new Date().toISOString()
      const { error } = await tabelaParaEscrita('atividades')
        .update(remendo)
        .eq('id', mudanca.atividade_id)
      if (error) throw new Error(error.message)
      return mudanca
    },
    onSuccess: (mudanca) => {
      const chave = ['crm', 'atividades', fonte()]
      fila.setQueryData<RespostaCrm<QuadroDeAtividades>>(chave, (anterior) => {
        if (!anterior) return anterior
        const atividades = anterior.dados.atividades.map((linha) =>
          linha.id === mudanca.atividade_id
            ? {
                ...linha,
                estado: mudanca.estado,
                concluida_em:
                  mudanca.estado === 'concluida' ? new Date().toISOString() : linha.concluida_em,
                aguardando_desde:
                  mudanca.estado === 'aguardando' ? HOJE_ISO : linha.aguardando_desde,
              }
            : linha,
        )
        return {
          ...anterior,
          dados: {
            ...anterior.dados,
            atividades,
            caixa: temBanco()
              ? anterior.dados.caixa
              : caixaDeExemplo(atividades, anterior.dados.janela_dias),
          },
        }
      })
      if (temBanco()) void fila.invalidateQueries({ queryKey: ['crm', 'atividades'] })
    },
  })
}

/** O que a conclusão devolve, para a tela saber se uma nova ocorrência nasceu. */
export interface ConclusaoDeAtividade {
  atividade_id: Uuid
  titulo: string
  /** Verdadeiro quando a atividade pertencia a uma série que se repete. */
  era_recorrente: boolean
  recorrencia_nome: string | null
}

/**
 * Conclui a atividade. Quando ela pertence a uma série, o gatilho do banco
 * cria a próxima ocorrência e aponta uma para a outra. A tela avisa disso.
 */
export function useConcluirAtividade(): UseMutationResult<ConclusaoDeAtividade, Error, LinhaAtividade> {
  const fila = useQueryClient()

  return useMutation<ConclusaoDeAtividade, Error, LinhaAtividade>({
    mutationFn: async (atividade) => {
      const resultado: ConclusaoDeAtividade = {
        atividade_id: atividade.id,
        titulo: atividade.titulo,
        era_recorrente: Boolean(atividade.recorrencia_id),
        recorrencia_nome: atividade.recorrencia_nome,
      }

      if (!temBanco()) return resultado

      const { error } = await tabelaParaEscrita('atividades')
        .update({ estado: 'concluida', concluida_em: new Date().toISOString() })
        .eq('id', atividade.id)
      if (error) throw new Error(error.message)
      return resultado
    },
    onSuccess: (resultado) => {
      const chave = ['crm', 'atividades', fonte()]
      fila.setQueryData<RespostaCrm<QuadroDeAtividades>>(chave, (anterior) => {
        if (!anterior) return anterior

        const agora = new Date().toISOString()
        const atividades = anterior.dados.atividades.map((linha) =>
          linha.id === resultado.atividade_id
            ? { ...linha, estado: 'concluida' as EstadoGtd, concluida_em: agora }
            : linha,
        )

        // Sem banco, a próxima ocorrência da série nasce aqui, para a tela
        // mostrar o que o gatilho do banco faria em produção.
        if (!temBanco() && resultado.era_recorrente) {
          const origem = anterior.dados.atividades.find((linha) => linha.id === resultado.atividade_id)
          if (origem) {
            atividades.push({
              ...origem,
              id: `${origem.id}-proxima`,
              estado: 'proxima_acao',
              concluida_em: null,
              prazo: origem.prazo ? emDias(30) : null,
              agendada_para: null,
              proxima_ocorrencia_id: null,
            })
          }
        }

        return {
          ...anterior,
          dados: {
            ...anterior.dados,
            atividades,
            caixa: temBanco()
              ? anterior.dados.caixa
              : caixaDeExemplo(atividades, anterior.dados.janela_dias),
          },
        }
      })
      if (temBanco()) void fila.invalidateQueries({ queryKey: ['crm', 'atividades'] })
    },
  })
}
