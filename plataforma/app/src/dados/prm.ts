/**
 * Dados do PRM de Valor: parceiros, indicações e comissão.
 *
 * Segue a mesma regra de `src/dados/consultas.ts`: quando o banco está ligado,
 * lê do banco. Quando não está, cai nos exemplos deste arquivo e diz isso na
 * tela. Nunca mistura os dois sem avisar, e nunca finge que exemplo é dado
 * real.
 *
 * Todo parceiro, toda conta e toda pessoa aqui são claramente fictícios, e
 * todo valor é redondo e inventado. Nenhum endereço de correio deste arquivo
 * existe: o domínio `exemplo.invalido` não é, e nunca será, um domínio de
 * verdade. Conforme a seção 11 do contrato técnico.
 *
 * Nenhuma função deste arquivo filtra por perfil. O recorte é do banco, pela
 * política de linha, conforme as seções 8 e 9 do contrato.
 */

import { useQuery, type UseQueryResult } from '@tanstack/react-query'
import { obterCliente, temBanco } from '@/dados/cliente'
import type { Fase, Uuid } from '@/tipos/dominio'
import {
  montarExtratos,
  type ExtratoDeComissao,
  type IndicacaoNaTela,
  type LinhaComissao,
  type Parceiro,
  type ParceiroNaLista,
  type UsuarioDoParceiro,
} from '@/tipos/prm'

// ------------------------------------------------------------- datas úteis

const HOJE = new Date()

/** Data ISO a tantos dias de hoje. Número negativo anda para trás. */
function emDias(dias: number): string {
  const d = new Date(HOJE)
  d.setDate(d.getDate() + dias)
  return d.toISOString().slice(0, 10)
}

/** Primeiro dia do mês, a tantos meses de hoje. É assim que a competência nasce. */
function competenciaEm(meses: number): string {
  const d = new Date(HOJE.getFullYear(), HOJE.getMonth() + meses, 1, 12)
  return d.toISOString().slice(0, 10)
}

/** Quantos dias faltam para a data. Negativo quando já passou. */
function diasPara(data: string | null): number | null {
  if (!data) return null
  const alvo = new Date(`${data.slice(0, 10)}T12:00:00`)
  if (Number.isNaN(alvo.getTime())) return null
  const umDia = 24 * 60 * 60 * 1000
  const hoje = new Date(`${HOJE.toISOString().slice(0, 10)}T12:00:00`)
  return Math.round((alvo.getTime() - hoje.getTime()) / umDia)
}

// ----------------------------------------------------- parceiros de exemplo

export const PARCEIROS_EXEMPLO: ParceiroNaLista[] = [
  {
    id: 'pex-01',
    nome: 'Consultoria Aurora Fictícia',
    tipo: 'indicador',
    tipo_pessoa: 'juridica',
    status: 'ativo',
    cidade: 'Cidade Modelo',
    uf: 'SP',
    credenciado_em: emDias(-420),
    vigencia_fim: emDias(310),
    prazo_protecao_dias: 90,
    responsavel_interno_nome: 'Pessoa de Exemplo',
    indicacoes: 4,
    indicacoes_convertidas: 1,
    indicacoes_em_aberto: 1,
    valor_gerado: 260000,
    comissao_total: 8500,
    ultima_indicacao_em: emDias(-12),
  },
  {
    id: 'pex-02',
    nome: 'Canal Meridiano Modelo',
    tipo: 'canal',
    tipo_pessoa: 'juridica',
    status: 'ativo',
    cidade: 'Vila Fictícia',
    uf: 'MG',
    credenciado_em: emDias(-190),
    vigencia_fim: emDias(540),
    prazo_protecao_dias: 90,
    responsavel_interno_nome: 'Pessoa de Exemplo',
    indicacoes: 2,
    indicacoes_convertidas: 0,
    indicacoes_em_aberto: 1,
    valor_gerado: 0,
    comissao_total: 0,
    ultima_indicacao_em: emDias(-5),
  },
  {
    id: 'pex-03',
    nome: 'Estúdio Bússola Exemplo',
    tipo: 'consultor_associado',
    tipo_pessoa: 'fisica',
    status: 'em_credenciamento',
    cidade: 'Bairro Inventado',
    uf: 'PR',
    credenciado_em: null,
    vigencia_fim: null,
    prazo_protecao_dias: 90,
    responsavel_interno_nome: 'Pessoa de Exemplo',
    indicacoes: 0,
    indicacoes_convertidas: 0,
    indicacoes_em_aberto: 0,
    valor_gerado: 0,
    comissao_total: 0,
    ultima_indicacao_em: null,
  },
  {
    id: 'pex-04',
    nome: 'Rede Farol Fictícia',
    tipo: 'indicador',
    tipo_pessoa: 'juridica',
    status: 'suspenso',
    cidade: 'Distrito Exemplo',
    uf: 'RS',
    credenciado_em: emDias(-700),
    vigencia_fim: emDias(-20),
    prazo_protecao_dias: 60,
    responsavel_interno_nome: null,
    indicacoes: 1,
    indicacoes_convertidas: 0,
    indicacoes_em_aberto: 0,
    valor_gerado: 0,
    comissao_total: 0,
    ultima_indicacao_em: emDias(-260),
  },
]

/** A ficha completa de cada parceiro de exemplo. */
export const FICHAS_EXEMPLO: Record<string, Parceiro> = {
  'pex-01': {
    id: 'pex-01',
    inquilino_id: 'inq-exemplo',
    conta_id: null,
    nome: 'Consultoria Aurora Fictícia',
    razao_social: 'Aurora Consultoria Fictícia Ltda',
    tipo_pessoa: 'juridica',
    documento: null,
    tipo: 'indicador',
    status: 'ativo',
    email_comercial: 'contato@aurora.exemplo.invalido',
    telefone_comercial: null,
    cidade: 'Cidade Modelo',
    uf: 'SP',
    site: 'aurora.exemplo.invalido',
    responsavel_interno_id: 'uex-02',
    credenciado_em: emDias(-420),
    vigencia_inicio: emDias(-420),
    vigencia_fim: emDias(310),
    contrato_parceria_url: null,
    comissao_percentual_negociado: null,
    prazo_protecao_dias: 90,
    condicoes_comerciais: null,
    servicos: ['Diagnóstico de gestão', 'Mapeamento de conta'],
    treinamentos_concluidos: ['Método Negócios de Valor', 'Credenciamento do canal'],
    autoriza_divulgacao_site: true,
    observacoes: 'Trouxe a primeira conta convertida do canal. Responde rápido.',
    criado_em: `${emDias(-430)}T09:00:00.000Z`,
    atualizado_em: `${emDias(-12)}T14:30:00.000Z`,
    arquivado_em: null,
  },
  'pex-02': {
    id: 'pex-02',
    inquilino_id: 'inq-exemplo',
    conta_id: null,
    nome: 'Canal Meridiano Modelo',
    razao_social: 'Meridiano Modelo Serviços Ltda',
    tipo_pessoa: 'juridica',
    documento: null,
    tipo: 'canal',
    status: 'ativo',
    email_comercial: 'parceria@meridiano.exemplo.invalido',
    telefone_comercial: null,
    cidade: 'Vila Fictícia',
    uf: 'MG',
    site: null,
    responsavel_interno_id: 'uex-02',
    credenciado_em: emDias(-190),
    vigencia_inicio: emDias(-190),
    vigencia_fim: emDias(540),
    contrato_parceria_url: null,
    comissao_percentual_negociado: null,
    prazo_protecao_dias: 90,
    condicoes_comerciais: null,
    servicos: ['Revenda de programas'],
    treinamentos_concluidos: ['Credenciamento do canal'],
    autoriza_divulgacao_site: false,
    observacoes: null,
    criado_em: `${emDias(-200)}T10:00:00.000Z`,
    atualizado_em: null,
    arquivado_em: null,
  },
  'pex-03': {
    id: 'pex-03',
    inquilino_id: 'inq-exemplo',
    conta_id: null,
    nome: 'Estúdio Bússola Exemplo',
    razao_social: null,
    tipo_pessoa: 'fisica',
    documento: null,
    tipo: 'consultor_associado',
    status: 'em_credenciamento',
    email_comercial: 'bussola@exemplo.invalido',
    telefone_comercial: null,
    cidade: 'Bairro Inventado',
    uf: 'PR',
    site: null,
    responsavel_interno_id: 'uex-02',
    credenciado_em: null,
    vigencia_inicio: null,
    vigencia_fim: null,
    contrato_parceria_url: null,
    comissao_percentual_negociado: null,
    prazo_protecao_dias: 90,
    condicoes_comerciais: null,
    servicos: [],
    treinamentos_concluidos: [],
    autoriza_divulgacao_site: false,
    observacoes: 'Falta concluir o treinamento do método antes de liberar o portal.',
    criado_em: `${emDias(-40)}T11:00:00.000Z`,
    atualizado_em: null,
    arquivado_em: null,
  },
  'pex-04': {
    id: 'pex-04',
    inquilino_id: 'inq-exemplo',
    conta_id: null,
    nome: 'Rede Farol Fictícia',
    razao_social: 'Farol Fictícia Participações Ltda',
    tipo_pessoa: 'juridica',
    documento: null,
    tipo: 'indicador',
    status: 'suspenso',
    email_comercial: 'farol@exemplo.invalido',
    telefone_comercial: null,
    cidade: 'Distrito Exemplo',
    uf: 'RS',
    site: null,
    responsavel_interno_id: null,
    credenciado_em: emDias(-700),
    vigencia_inicio: emDias(-700),
    vigencia_fim: emDias(-20),
    contrato_parceria_url: null,
    comissao_percentual_negociado: null,
    prazo_protecao_dias: 60,
    condicoes_comerciais: null,
    servicos: [],
    treinamentos_concluidos: ['Credenciamento do canal'],
    autoriza_divulgacao_site: false,
    observacoes: 'Vigência vencida. Renovar o contrato de parceria antes de reativar.',
    criado_em: `${emDias(-710)}T08:00:00.000Z`,
    atualizado_em: `${emDias(-20)}T16:00:00.000Z`,
    arquivado_em: null,
  },
}

export const USUARIOS_DO_PARCEIRO_EXEMPLO: UsuarioDoParceiro[] = [
  {
    id: 'pux-01',
    parceiro_id: 'pex-01',
    usuario_id: 'uex-20',
    usuario_nome: 'Parceiro de Exemplo',
    usuario_email: 'parceiro.exemplo@aurora.exemplo.invalido',
    principal: true,
    ativo: true,
    ultimo_acesso_portal: `${emDias(-2)}T09:15:00.000Z`,
  },
  {
    id: 'pux-02',
    parceiro_id: 'pex-01',
    usuario_id: 'uex-21',
    usuario_nome: 'Segunda Pessoa Fictícia',
    usuario_email: 'segunda.pessoa@aurora.exemplo.invalido',
    principal: false,
    ativo: true,
    ultimo_acesso_portal: `${emDias(-31)}T17:40:00.000Z`,
  },
  {
    id: 'pux-03',
    parceiro_id: 'pex-02',
    usuario_id: 'uex-22',
    usuario_nome: 'Contato Meridiano Fictício',
    usuario_email: 'contato@meridiano.exemplo.invalido',
    principal: true,
    ativo: true,
    ultimo_acesso_portal: null,
  },
  {
    id: 'pux-04',
    parceiro_id: 'pex-04',
    usuario_id: 'uex-23',
    usuario_nome: 'Contato Farol Fictício',
    usuario_email: 'contato@farol.exemplo.invalido',
    principal: true,
    ativo: false,
    ultimo_acesso_portal: `${emDias(-240)}T13:00:00.000Z`,
  },
]

// ---------------------------------------------------- indicações de exemplo

/** Monta a linha já com os dias que faltam para a proteção vencer. */
function indicacao(base: Omit<IndicacaoNaTela, 'dias_para_expirar_protecao'>): IndicacaoNaTela {
  return { ...base, dias_para_expirar_protecao: diasPara(base.protecao_expira_em) }
}

export const INDICACOES_EXEMPLO: IndicacaoNaTela[] = [
  indicacao({
    id: 'iex-01',
    parceiro_id: 'pex-01',
    parceiro_nome: 'Consultoria Aurora Fictícia',
    conta: 'Clínica Bem Viver Exemplo',
    contato_nome: 'Sócia Responsável Fictícia',
    contato_cargo: 'Sócia administradora',
    oferta_nome: 'Gestão de Valor',
    contexto:
      'A sócia comentou que o time de gestão cresceu sem ritual nenhum e que as decisões voltam toda semana para a mesa dela.',
    necessidade_percebida: 'Ritmo de gestão e clareza de prioridade entre as áreas.',
    status: 'convertida',
    registrada_em: emDias(-120),
    decidido_em: `${emDias(-112)}T10:00:00.000Z`,
    motivo_recusa: null,
    aceita_em: emDias(-112),
    prazo_protecao_dias: 90,
    protecao_expira_em: emDias(-22),
    negocio_id: 'ex-03',
    negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    negocio_fase: 3 as Fase,
    negocio_valor: 260000,
    analisado_por_nome: 'Pessoa de Exemplo',
  }),
  indicacao({
    id: 'iex-02',
    parceiro_id: 'pex-01',
    parceiro_nome: 'Consultoria Aurora Fictícia',
    conta: 'Metalúrgica Aurora Fictícia',
    contato_nome: 'Diretor Industrial Fictício',
    contato_cargo: 'Diretor industrial',
    oferta_nome: 'Conselho de Valor dedicado',
    contexto:
      'Empresa familiar na terceira geração, com dois sócios discordando do plano de sucessão e sem fórum para resolver.',
    necessidade_percebida: 'Fórum de decisão entre os sócios, com pauta e registro.',
    status: 'aceita',
    registrada_em: emDias(-86),
    decidido_em: `${emDias(-84)}T15:30:00.000Z`,
    motivo_recusa: null,
    aceita_em: emDias(-84),
    prazo_protecao_dias: 90,
    // Faltam poucos dias: é o caso que precisa acender o alarme na tela.
    protecao_expira_em: emDias(6),
    negocio_id: null,
    negocio_titulo: null,
    negocio_fase: null,
    negocio_valor: null,
    analisado_por_nome: 'Pessoa de Exemplo',
  }),
  indicacao({
    id: 'iex-03',
    parceiro_id: 'pex-01',
    parceiro_nome: 'Consultoria Aurora Fictícia',
    conta: 'Transportes Serra Modelo',
    contato_nome: 'Gerente Geral Fictício',
    contato_cargo: 'Gerente geral',
    oferta_nome: 'Negócios de Valor',
    contexto:
      'O time comercial dobrou de tamanho em um ano e nenhuma conta grande tem plano escrito.',
    necessidade_percebida: 'Método comercial e ritual de acompanhamento do funil.',
    status: 'aceita',
    registrada_em: emDias(-30),
    decidido_em: `${emDias(-28)}T09:00:00.000Z`,
    motivo_recusa: null,
    aceita_em: emDias(-28),
    prazo_protecao_dias: 90,
    protecao_expira_em: emDias(62),
    negocio_id: null,
    negocio_titulo: null,
    negocio_fase: null,
    negocio_valor: null,
    analisado_por_nome: 'Pessoa de Exemplo',
  }),
  indicacao({
    id: 'iex-04',
    parceiro_id: 'pex-01',
    parceiro_nome: 'Consultoria Aurora Fictícia',
    conta: 'Agro Vale Fictício',
    contato_nome: 'Sócio Fundador Fictício',
    contato_cargo: 'Sócio fundador',
    oferta_nome: null,
    contexto:
      'Conversa de corredor num evento do setor. O sócio pediu para ser procurado depois da safra.',
    necessidade_percebida: null,
    status: 'registrada',
    registrada_em: emDias(-12),
    decidido_em: null,
    motivo_recusa: null,
    aceita_em: null,
    prazo_protecao_dias: 90,
    protecao_expira_em: null,
    negocio_id: null,
    negocio_titulo: null,
    negocio_fase: null,
    negocio_valor: null,
    analisado_por_nome: null,
  }),
  indicacao({
    id: 'iex-05',
    parceiro_id: 'pex-02',
    parceiro_nome: 'Canal Meridiano Modelo',
    conta: 'Softworks Exemplo',
    contato_nome: 'Diretora de Pessoas Fictícia',
    contato_cargo: 'Diretora de pessoas',
    oferta_nome: 'Liderança de Valor',
    contexto:
      'Doze líderes novos promovidos no mesmo semestre, sem nenhum preparo formal para a cadeira.',
    necessidade_percebida: 'Formação de liderança com plano por participante.',
    status: 'em_analise',
    registrada_em: emDias(-5),
    decidido_em: null,
    motivo_recusa: null,
    aceita_em: null,
    prazo_protecao_dias: 90,
    protecao_expira_em: null,
    negocio_id: null,
    negocio_titulo: null,
    negocio_fase: null,
    negocio_valor: null,
    analisado_por_nome: 'Pessoa de Exemplo',
  }),
  indicacao({
    id: 'iex-06',
    parceiro_id: 'pex-02',
    parceiro_nome: 'Canal Meridiano Modelo',
    conta: 'Rede Sabor Fictícia',
    contato_nome: 'Comprador Fictício',
    contato_cargo: 'Comprador',
    oferta_nome: 'Consultoria pontual',
    contexto: 'Solicitação de orçamento avulso vinda de uma lista pública.',
    necessidade_percebida: null,
    status: 'recusada',
    registrada_em: emDias(-64),
    decidido_em: `${emDias(-60)}T11:20:00.000Z`,
    motivo_recusa:
      'A conta já estava em atendimento direto da casa havia quatro meses, com Plano de Conta registrado.',
    aceita_em: null,
    prazo_protecao_dias: 90,
    protecao_expira_em: null,
    negocio_id: null,
    negocio_titulo: null,
    negocio_fase: null,
    negocio_valor: null,
    analisado_por_nome: 'Pessoa de Exemplo',
  }),
  indicacao({
    id: 'iex-07',
    parceiro_id: 'pex-04',
    parceiro_nome: 'Rede Farol Fictícia',
    conta: 'Têxtil Canção Fictícia',
    contato_nome: 'Diretor Fictício',
    contato_cargo: 'Diretor',
    oferta_nome: 'Mentoria de Valor',
    contexto: 'Indicação antiga que ficou sem retorno do contato durante todo o prazo.',
    necessidade_percebida: null,
    status: 'expirada',
    registrada_em: emDias(-260),
    decidido_em: `${emDias(-255)}T09:00:00.000Z`,
    motivo_recusa: null,
    aceita_em: emDias(-255),
    prazo_protecao_dias: 60,
    protecao_expira_em: emDias(-195),
    negocio_id: null,
    negocio_titulo: null,
    negocio_fase: null,
    negocio_valor: null,
    analisado_por_nome: 'Pessoa de Exemplo',
  }),
]

// ---------------------------------------------------- comissões de exemplo

/**
 * Monta uma linha de comissão a partir do bruto e dos dois percentuais, na
 * ordem exata da regra da casa. O exemplo nunca fica incoerente consigo mesmo
 * porque nenhum número é digitado pronto: todos saem da conta.
 */
function comissaoDeExemplo(entrada: {
  id: string
  beneficiario_tipo: LinhaComissao['beneficiario_tipo']
  beneficiario_id: string
  beneficiario_nome: string
  conta_nome: string
  negocio_titulo: string
  contrato_codigo: string
  parcela_numero: number
  competencia: string
  status: LinhaComissao['status']
  pago_em: string | null
  valor_bruto: number
  imposto_percentual: number
  percentual: number
  observacao?: string
}): LinhaComissao {
  const impostoValor = (entrada.valor_bruto * entrada.imposto_percentual) / 100
  const base = entrada.valor_bruto - impostoValor
  const valor = (base * entrada.percentual) / 100

  return {
    id: entrada.id,
    beneficiario_tipo: entrada.beneficiario_tipo,
    beneficiario_id: entrada.beneficiario_id,
    beneficiario_nome: entrada.beneficiario_nome,
    conta_nome: entrada.conta_nome,
    negocio_titulo: entrada.negocio_titulo,
    contrato_codigo: entrada.contrato_codigo,
    parcela_numero: entrada.parcela_numero,
    competencia: entrada.competencia,
    status: entrada.status,
    pago_em: entrada.pago_em,
    valor_bruto: entrada.valor_bruto,
    imposto_percentual: entrada.imposto_percentual,
    imposto_valor: impostoValor,
    base_calculo: base,
    percentual: entrada.percentual,
    valor,
    percentual_efetivo_sobre_bruto: (valor * 100) / entrada.valor_bruto,
    observacao: entrada.observacao ?? null,
  }
}

const IMPOSTO_PADRAO = 15
const COMISSAO_PADRAO = 10

/**
 * O valor do enum `valor.comissao_beneficiario` que marca a pessoa da casa.
 *
 * Este identificador existe uma vez só neste arquivo, e é copiado do
 * `create type` da migração 0006 sem tradução, porque é ele que o banco devolve
 * na coluna `beneficiario_tipo`. Identificador de banco se escreve como o banco
 * escreve, em snake_case, conforme a seção 2 do contrato técnico. Em tela, este
 * mesmo registro se chama Gerente de Contas, e quem faz essa ponte é o
 * dicionário `ROTULO_BENEFICIARIO`, em `src/tipos/prm.ts`.
 */
const BENEFICIARIO_DA_CASA: LinhaComissao['beneficiario_tipo'] = 'vendedor_interno'

export const COMISSOES_EXEMPLO: LinhaComissao[] = [
  comissaoDeExemplo({
    id: 'cex-01',
    beneficiario_tipo: 'parceiro',
    beneficiario_id: 'pex-01',
    beneficiario_nome: 'Consultoria Aurora Fictícia',
    conta_nome: 'Clínica Bem Viver Exemplo',
    negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    contrato_codigo: 'CV-EXEMPLO-0031',
    parcela_numero: 1,
    competencia: competenciaEm(-2),
    status: 'paga',
    pago_em: competenciaEm(-1),
    valor_bruto: 20000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
  }),
  comissaoDeExemplo({
    id: 'cex-02',
    beneficiario_tipo: 'parceiro',
    beneficiario_id: 'pex-01',
    beneficiario_nome: 'Consultoria Aurora Fictícia',
    conta_nome: 'Clínica Bem Viver Exemplo',
    negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    contrato_codigo: 'CV-EXEMPLO-0031',
    parcela_numero: 2,
    competencia: competenciaEm(-1),
    status: 'apurada',
    pago_em: null,
    valor_bruto: 20000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
  }),
  comissaoDeExemplo({
    id: 'cex-03',
    beneficiario_tipo: 'parceiro',
    beneficiario_id: 'pex-01',
    beneficiario_nome: 'Consultoria Aurora Fictícia',
    conta_nome: 'Clínica Bem Viver Exemplo',
    negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    contrato_codigo: 'CV-EXEMPLO-0031',
    parcela_numero: 3,
    competencia: competenciaEm(0),
    status: 'prevista',
    pago_em: null,
    valor_bruto: 20000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
  }),
  comissaoDeExemplo({
    id: 'cex-04',
    beneficiario_tipo: 'parceiro',
    beneficiario_id: 'pex-01',
    beneficiario_nome: 'Consultoria Aurora Fictícia',
    conta_nome: 'Clínica Bem Viver Exemplo',
    negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    contrato_codigo: 'CV-EXEMPLO-0031',
    parcela_numero: 4,
    competencia: competenciaEm(1),
    status: 'prevista',
    pago_em: null,
    valor_bruto: 20000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
  }),
  // Mesma parcela, outra pessoa. A casa paga os dois sobre a mesma base.
  comissaoDeExemplo({
    id: 'cex-05',
    beneficiario_tipo: BENEFICIARIO_DA_CASA,
    beneficiario_id: 'uex-02',
    beneficiario_nome: 'Gerente de Contas de Exemplo',
    conta_nome: 'Clínica Bem Viver Exemplo',
    negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    contrato_codigo: 'CV-EXEMPLO-0031',
    parcela_numero: 1,
    competencia: competenciaEm(-2),
    status: 'paga',
    pago_em: competenciaEm(-1),
    valor_bruto: 20000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
    observacao: 'Negócio com parceiro e pessoa da casa. As duas linhas usam a mesma base líquida.',
  }),
  comissaoDeExemplo({
    id: 'cex-06',
    beneficiario_tipo: BENEFICIARIO_DA_CASA,
    beneficiario_id: 'uex-02',
    beneficiario_nome: 'Gerente de Contas de Exemplo',
    conta_nome: 'Clínica Bem Viver Exemplo',
    negocio_titulo: 'Gestão de Valor · implantação do ciclo',
    contrato_codigo: 'CV-EXEMPLO-0031',
    parcela_numero: 2,
    competencia: competenciaEm(-1),
    status: 'apurada',
    pago_em: null,
    valor_bruto: 20000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
  }),
  comissaoDeExemplo({
    id: 'cex-07',
    beneficiario_tipo: BENEFICIARIO_DA_CASA,
    beneficiario_id: 'uex-02',
    beneficiario_nome: 'Gerente de Contas de Exemplo',
    conta_nome: 'Metalúrgica Aurora Fictícia',
    negocio_titulo: 'Conselho dedicado · ciclo de doze meses',
    contrato_codigo: 'CV-EXEMPLO-0028',
    parcela_numero: 7,
    competencia: competenciaEm(-1),
    status: 'apurada',
    pago_em: null,
    valor_bruto: 40000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
  }),
  comissaoDeExemplo({
    id: 'cex-08',
    beneficiario_tipo: BENEFICIARIO_DA_CASA,
    beneficiario_id: 'uex-02',
    beneficiario_nome: 'Gerente de Contas de Exemplo',
    conta_nome: 'Metalúrgica Aurora Fictícia',
    negocio_titulo: 'Conselho dedicado · ciclo de doze meses',
    contrato_codigo: 'CV-EXEMPLO-0028',
    parcela_numero: 8,
    competencia: competenciaEm(0),
    status: 'prevista',
    pago_em: null,
    valor_bruto: 40000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
  }),
  comissaoDeExemplo({
    id: 'cex-09',
    beneficiario_tipo: BENEFICIARIO_DA_CASA,
    beneficiario_id: 'uex-02',
    beneficiario_nome: 'Gerente de Contas de Exemplo',
    conta_nome: 'Transportes Serra Modelo',
    negocio_titulo: 'Negócios de Valor · turma dedicada',
    contrato_codigo: 'CV-EXEMPLO-0030',
    parcela_numero: 2,
    competencia: competenciaEm(-1),
    status: 'cancelada',
    pago_em: null,
    valor_bruto: 16000,
    imposto_percentual: IMPOSTO_PADRAO,
    percentual: COMISSAO_PADRAO,
    observacao: 'Parcela renegociada com o cliente. A linha foi cancelada e outra nasceu no lugar.',
  }),
]

// ------------------------------------------------------ leitura do banco

interface LinhaParceiroBanco {
  id: string
  nome: string
  tipo: ParceiroNaLista['tipo']
  tipo_pessoa: ParceiroNaLista['tipo_pessoa']
  status: ParceiroNaLista['status']
  cidade: string | null
  uf: string | null
  credenciado_em: string | null
  vigencia_fim: string | null
  prazo_protecao_dias: number
  responsavel: { nome: string } | { nome: string }[] | null
}

function primeiroNome(valor: LinhaParceiroBanco['responsavel']): string | null {
  if (!valor) return null
  if (Array.isArray(valor)) return valor[0]?.nome ?? null
  return valor.nome
}

interface LinhaIndicacaoBanco {
  id: string
  parceiro_id: string
  conta_indicada_nome: string
  contato_nome: string
  contato_cargo: string | null
  contexto: string
  necessidade_percebida: string | null
  status: IndicacaoNaTela['status']
  criado_em: string
  decidido_em: string | null
  motivo_recusa: string | null
  aceita_em: string | null
  prazo_protecao_dias: number
  protecao_expira_em: string | null
  negocio_id: string | null
}

interface LinhaComissaoBanco {
  id: string
  beneficiario_tipo: LinhaComissao['beneficiario_tipo']
  beneficiario_id: string | null
  usuario_id: string | null
  parceiro_id: string | null
  competencia: string
  status: LinhaComissao['status']
  pago_em: string | null
  valor_bruto: number | string
  imposto_percentual: number | string
  imposto_valor: number | string
  base_calculo: number | string
  percentual: number | string | null
  valor: number | string
  percentual_efetivo_sobre_bruto: number | string | null
  observacao: string | null
}

function numero(valor: number | string | null | undefined): number {
  if (valor === null || valor === undefined) return 0
  const lido = typeof valor === 'number' ? valor : Number(valor)
  return Number.isNaN(lido) ? 0 : lido
}

function numeroOuNulo(valor: number | string | null | undefined): number | null {
  if (valor === null || valor === undefined) return null
  const lido = typeof valor === 'number' ? valor : Number(valor)
  return Number.isNaN(lido) ? null : lido
}

async function lerParceirosDoBanco(): Promise<ParceiroNaLista[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data, error } = await cliente
    .from('parceiros')
    .select(
      'id, nome, tipo, tipo_pessoa, status, cidade, uf, credenciado_em, vigencia_fim, prazo_protecao_dias, responsavel:usuarios!parceiros_responsavel_interno_id_fkey(nome)',
    )
    .is('arquivado_em', null)
    .order('nome')
    .returns<LinhaParceiroBanco[]>()

  if (error) throw new Error(error.message)

  const parceiros = data ?? []
  const identificadores = parceiros.map((linha) => linha.id)
  const indicacoes = identificadores.length > 0 ? await lerIndicacoesDoBanco(identificadores) : []

  return parceiros.map((linha) => {
    const minhas = indicacoes.filter((item) => item.parceiro_id === linha.id)
    const emAberto = minhas.filter(
      (item) => item.status === 'registrada' || item.status === 'em_analise',
    )
    const convertidas = minhas.filter((item) => item.status === 'convertida')
    const datas = minhas.map((item) => item.registrada_em).sort()

    return {
      id: linha.id,
      nome: linha.nome,
      tipo: linha.tipo,
      tipo_pessoa: linha.tipo_pessoa,
      status: linha.status,
      cidade: linha.cidade,
      uf: linha.uf,
      credenciado_em: linha.credenciado_em,
      vigencia_fim: linha.vigencia_fim,
      prazo_protecao_dias: linha.prazo_protecao_dias,
      responsavel_interno_nome: primeiroNome(linha.responsavel),
      indicacoes: minhas.length,
      indicacoes_convertidas: convertidas.length,
      indicacoes_em_aberto: emAberto.length,
      valor_gerado: convertidas.reduce((total, item) => total + (item.negocio_valor ?? 0), 0),
      comissao_total: null,
      ultima_indicacao_em: datas[datas.length - 1] ?? null,
    }
  })
}

async function lerIndicacoesDoBanco(parceiros?: string[]): Promise<IndicacaoNaTela[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  let consulta = cliente
    .from('indicacoes')
    .select(
      'id, parceiro_id, conta_indicada_nome, contato_nome, contato_cargo, contexto, necessidade_percebida, status, criado_em, decidido_em, motivo_recusa, aceita_em, prazo_protecao_dias, protecao_expira_em, negocio_id',
    )
    .is('arquivado_em', null)
    .order('criado_em', { ascending: false })

  if (parceiros && parceiros.length > 0) {
    consulta = consulta.in('parceiro_id', parceiros)
  }

  const { data, error } = await consulta.returns<LinhaIndicacaoBanco[]>()
  if (error) throw new Error(error.message)

  return (data ?? []).map((linha) =>
    indicacao({
      id: linha.id,
      parceiro_id: linha.parceiro_id,
      parceiro_nome: '',
      conta: linha.conta_indicada_nome,
      contato_nome: linha.contato_nome,
      contato_cargo: linha.contato_cargo,
      oferta_nome: null,
      contexto: linha.contexto,
      necessidade_percebida: linha.necessidade_percebida,
      status: linha.status,
      registrada_em: linha.criado_em.slice(0, 10),
      decidido_em: linha.decidido_em,
      motivo_recusa: linha.motivo_recusa,
      aceita_em: linha.aceita_em,
      prazo_protecao_dias: linha.prazo_protecao_dias,
      protecao_expira_em: linha.protecao_expira_em,
      negocio_id: linha.negocio_id,
      negocio_titulo: null,
      negocio_fase: null,
      negocio_valor: null,
      analisado_por_nome: null,
    }),
  )
}

async function lerComissoesDoBanco(): Promise<LinhaComissao[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data, error } = await cliente
    .from('comissoes')
    .select(
      'id, beneficiario_tipo, beneficiario_id, usuario_id, parceiro_id, competencia, status, pago_em, valor_bruto, imposto_percentual, imposto_valor, base_calculo, percentual, valor, percentual_efetivo_sobre_bruto, observacao',
    )
    .is('arquivado_em', null)
    .order('competencia', { ascending: false })
    .returns<LinhaComissaoBanco[]>()

  if (error) throw new Error(error.message)

  return (data ?? []).map((linha) => ({
    id: linha.id,
    beneficiario_tipo: linha.beneficiario_tipo,
    beneficiario_id: linha.beneficiario_id ?? linha.usuario_id ?? linha.parceiro_id ?? linha.id,
    beneficiario_nome: 'Beneficiário',
    conta_nome: '',
    negocio_titulo: null,
    contrato_codigo: null,
    parcela_numero: null,
    competencia: linha.competencia,
    status: linha.status,
    pago_em: linha.pago_em,
    valor_bruto: numero(linha.valor_bruto),
    imposto_percentual: numero(linha.imposto_percentual),
    imposto_valor: numero(linha.imposto_valor),
    base_calculo: numero(linha.base_calculo),
    percentual: numeroOuNulo(linha.percentual),
    valor: numero(linha.valor),
    percentual_efetivo_sobre_bruto: numeroOuNulo(linha.percentual_efetivo_sobre_bruto),
    observacao: linha.observacao,
  }))
}

// -------------------------------------------------------------- consultas

export interface RespostaParceiros {
  parceiros: ParceiroNaLista[]
  deExemplo: boolean
}

export function useParceiros(): UseQueryResult<RespostaParceiros, Error> {
  return useQuery<RespostaParceiros, Error>({
    queryKey: ['prm', 'parceiros', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { parceiros: PARCEIROS_EXEMPLO, deExemplo: true }
      return { parceiros: await lerParceirosDoBanco(), deExemplo: false }
    },
  })
}

export interface RespostaFichaDoParceiro {
  parceiro: Parceiro | null
  resumo: ParceiroNaLista | null
  usuarios: UsuarioDoParceiro[]
  indicacoes: IndicacaoNaTela[]
  comissoes: LinhaComissao[]
  deExemplo: boolean
}

export function useParceiro(id: Uuid | undefined): UseQueryResult<RespostaFichaDoParceiro, Error> {
  return useQuery<RespostaFichaDoParceiro, Error>({
    queryKey: ['prm', 'parceiro', id ?? 'sem-id', temBanco()],
    enabled: Boolean(id),
    staleTime: 60_000,
    queryFn: async () => {
      const chave = id ?? ''

      if (!temBanco()) {
        return {
          parceiro: FICHAS_EXEMPLO[chave] ?? null,
          resumo: PARCEIROS_EXEMPLO.find((linha) => linha.id === chave) ?? null,
          usuarios: USUARIOS_DO_PARCEIRO_EXEMPLO.filter((linha) => linha.parceiro_id === chave),
          indicacoes: INDICACOES_EXEMPLO.filter((linha) => linha.parceiro_id === chave),
          comissoes: COMISSOES_EXEMPLO.filter(
            (linha) => linha.beneficiario_tipo === 'parceiro' && linha.beneficiario_id === chave,
          ),
          deExemplo: true,
        }
      }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      const { data, error } = await cliente
        .from('parceiros')
        .select('*')
        .eq('id', chave)
        .is('arquivado_em', null)
        .maybeSingle<Parceiro>()

      if (error) throw new Error(error.message)

      const indicacoes = await lerIndicacoesDoBanco([chave])
      const comissoes = (await lerComissoesDoBanco()).filter(
        (linha) => linha.beneficiario_tipo === 'parceiro' && linha.beneficiario_id === chave,
      )

      return {
        parceiro: data ?? null,
        resumo: null,
        usuarios: [],
        indicacoes,
        comissoes,
        deExemplo: false,
      }
    },
  })
}

export interface RespostaIndicacoes {
  indicacoes: IndicacaoNaTela[]
  deExemplo: boolean
}

export function useIndicacoes(): UseQueryResult<RespostaIndicacoes, Error> {
  return useQuery<RespostaIndicacoes, Error>({
    queryKey: ['prm', 'indicacoes', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { indicacoes: INDICACOES_EXEMPLO, deExemplo: true }
      return { indicacoes: await lerIndicacoesDoBanco(), deExemplo: false }
    },
  })
}

export interface RespostaComissoes {
  linhas: LinhaComissao[]
  extratos: ExtratoDeComissao[]
  deExemplo: boolean
}

/**
 * O extrato de comissão.
 *
 * Esta consulta não filtra nada. Quem recebe o próprio recorte é o banco, pela
 * política de linha: o parceiro recebe a linha dele, o Gerente de Contas recebe
 * a dele, e o financeiro recebe todas. A tela mostra o que veio.
 */
export function useComissoes(): UseQueryResult<RespostaComissoes, Error> {
  return useQuery<RespostaComissoes, Error>({
    queryKey: ['prm', 'comissoes', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      const linhas = temBanco() ? await lerComissoesDoBanco() : COMISSOES_EXEMPLO
      return { linhas, extratos: montarExtratos(linhas), deExemplo: !temBanco() }
    },
  })
}
