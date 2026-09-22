/**
 * Dados da governança: atas, pautas, pendências, pesquisas e Histórico de Valor.
 *
 * Duas coisas moram aqui, na ordem em que a tela precisa delas:
 *
 * 1. Os dados de exemplo, que servem enquanto o banco não está ligado nesta
 *    máquina. Toda empresa e toda pessoa aqui é claramente fictícia, e nenhum
 *    valor é real, conforme a seção 11 do contrato técnico. Nenhuma avaliação
 *    de pessoa entra no exemplo: avaliação de gente é confidencial, quem decide
 *    quem vê é a política de linha, e inventar uma seria mentir sobre gente.
 *
 * 2. As consultas, com TanStack Query, no mesmo padrão de `dados/consultas.ts`:
 *    tenta o banco, cai no exemplo, e devolve `deExemplo` para a tela avisar.
 *    A interface nunca finge que exemplo é dado real.
 *
 * As regras de cálculo repetidas aqui, a pré-pauta e as faixas de NPS, são as
 * mesmas do banco. Quando o banco responde, o banco manda. O exemplo existe
 * para a tela rodar, e serve de conferência das regras.
 */

import { useQuery, type UseQueryResult } from '@tanstack/react-query'
import { obterCliente, temBanco } from '@/dados/cliente'
import type {
  AlertaCiclo,
  Ata,
  ConteudoAta,
  AtaNaLista,
  BancoPauta,
  ConsolidadoNps,
  ContaResumida,
  HistoricoDaConta,
  HistoricoDevido,
  HistoricoValor,
  ItemPautaNaTela,
  LinhaNpsPessoa,
  LinhaPrePauta,
  PainelNps,
  Pauta,
  PautaMontada,
  Pendencia,
  PendenciaNaLista,
  Pesquisa,
  PesquisaQuestao,
  SecaoModeloAta,
} from '@/tipos/governanca'
import { faixaDaNota, SECOES_EXTENSAO, SECOES_PADRAO } from '@/tipos/governanca'

/** O que toda consulta desta tela devolve. */
export interface RespostaGovernanca<T> {
  dados: T
  /** Verdadeiro quando o que está na tela veio do arquivo de exemplo. */
  deExemplo: boolean
}

/** A ficha completa de uma ata, com o modelo que vale para a conta. */
export interface FichaAta {
  ata: AtaNaLista
  /** As seções do modelo em vigor, na ordem. Sete, ou 16 com a extensão. */
  secoes: SecaoModeloAta[]
  usa_extensao: boolean
  /** As pendências que nasceram desta ata. */
  pendencias: PendenciaNaLista[]
}

// ------------------------------------------------------------- datas úteis

const HOJE = new Date()

/** Data ISO a tantos dias de hoje. Número negativo anda para trás. */
function emDias(dias: number): string {
  const d = new Date(HOJE)
  d.setDate(d.getDate() + dias)
  return d.toISOString().slice(0, 10)
}

/** Carimbo de tempo a tantas horas de agora. */
function emHoras(horas: number): string {
  const d = new Date(HOJE)
  d.setHours(d.getHours() + horas)
  return d.toISOString()
}

/** A data de hoje, no formato do banco. */
export function hojeISO(): string {
  return emDias(0)
}

/** O trimestre em aberto, no formato da coluna `competencia`: 2026-T3. */
export function competenciaAtual(): string {
  const ano = HOJE.getFullYear()
  const trimestre = Math.floor(HOJE.getMonth() / 3) + 1
  return `${ano}-T${trimestre}`
}

const INQUILINO = '00000000-0000-4000-8000-000000000001'

/** O bloco de carimbo que toda tabela de negócio carrega, seção 7 do contrato. */
const CARIMBO = {
  inquilino_id: INQUILINO,
  criado_em: `${emDias(-120)}T12:00:00.000Z`,
  criado_por: null,
  atualizado_em: null,
  atualizado_por: null,
  arquivado_em: null,
}

// ------------------------------------------------------------ as contas

export const CONTAS_EXEMPLO: ContaResumida[] = [
  { id: 'ct-01', nome: 'Metalúrgica Aurora Fictícia' },
  { id: 'ct-02', nome: 'Clínica Bem Viver Exemplo' },
  { id: 'ct-03', nome: 'Transportes Serra Modelo' },
]

const TURMAS_EXEMPLO: Record<string, string> = {
  'tu-01': 'Conselho Aurora · turma da manhã',
  'tu-02': 'Conselho compartilhado · turma da tarde',
  'tu-03': 'Conselho Serra · turma quinzenal',
}

function nomeDaConta(id: string | null): string {
  if (!id) return 'Conta sem nome'
  return CONTAS_EXEMPLO.find((conta) => conta.id === id)?.nome ?? 'Conta sem nome'
}

function nomeDaTurma(id: string | null): string | null {
  if (!id) return null
  return TURMAS_EXEMPLO[id] ?? null
}

// ---------------------------------------------------------------- as atas

/** O conteúdo de exemplo das sete seções, para a ata mais recente da Aurora. */
const CONTEUDO_AURORA_12 = {
  identificacao:
    'Conselho Aurora, turma da manhã. Ata número 12 do ciclo. Reunião realizada na sede da conta, '
    + 'com início às 9 horas e encerramento às 12 horas.',
  participantes:
    'Presentes: Conselheiro de Exemplo, Assessora de Exemplo, Sócia de Exemplo e Diretor de Exemplo.\n'
    + 'Ausência justificada: Sócio de Exemplo, em viagem de conta.',
  pauta:
    '1. Leitura das pendências em aberto do encontro anterior, 10 minutos.\n'
    + '2. Painel de indicadores do trimestre, 30 minutos.\n'
    + '3. Alçadas e processo de decisão, item deliberativo, 40 minutos.\n'
    + '4. Encerramento, combinados e data da próxima reunião, 10 minutos.',
  resumo_discussoes:
    'O painel do trimestre mostrou receita dentro do planejado e margem abaixo do combinado em duas '
    + 'linhas do portfólio. O conselho debateu se a queda vem de custo ou de preço, e concluiu que '
    + 'falta um corte por linha para responder. Na discussão de alçadas ficou claro que decisões de '
    + 'investimento vinham sendo tomadas sem critério escrito, o que atrasa e gera retrabalho.',
  deliberacoes:
    'D1. Aprovada a tabela de alçadas em três faixas, com o conselho decidindo acima da terceira. '
    + 'Dono: Diretor de Exemplo. Prazo: trinta dias.\n'
    + 'D2. Aprovado o corte de margem por linha de portfólio no painel do próximo encontro. '
    + 'Dono: Sócia de Exemplo. Prazo: até a próxima reunião.',
  proximos_passos:
    'P1. Escrever a tabela de alçadas e circular para leitura antes da próxima reunião.\n'
    + 'P2. Levantar o custo por linha com o financeiro e trazer o corte pronto.\n'
    + 'P3. Confirmar quem responde pelos dados de operação no painel.',
  proxima_reuniao:
    'Próxima reunião combinada para daqui a quinze dias, mesmo horário e mesmo local. '
    + 'A pré-pauta já nasce com as pendências em aberto desta ata, e será completada com os temas '
    + 'sugeridos do banco de pautas.',
}

const CONTEUDO_AURORA_11 = {
  identificacao: 'Conselho Aurora, turma da manhã. Ata número 11 do ciclo.',
  participantes: 'Presentes: Conselheiro de Exemplo, Assessora de Exemplo e os dois sócios.',
  pauta: '1. Pendências em aberto. 2. Indicadores. 3. Estrutura e funcionamento do conselho.',
  resumo_discussoes:
    'O conselho revisou a cadência de reuniões e concluiu que o intervalo atual dá tempo de '
    + 'acompanhar as decisões, desde que a ata saia em 24 horas.',
  deliberacoes: 'D1. Mantida a cadência quinzenal. Dono: Assessora de Exemplo. Prazo: imediato.',
  proximos_passos: 'P1. Publicar o calendário do semestre para os participantes.',
  proxima_reuniao: 'Próxima reunião em quinze dias, com o painel de indicadores revisado.',
}

const CONTEUDO_CLINICA_5 = {
  identificacao: 'Conselho compartilhado, turma da tarde. Ata número 5 do ciclo.',
  participantes: 'Presentes: Conselheiro de Exemplo, Assessora de Exemplo e a sócia responsável.',
  pauta: '1. Pendências. 2. Clientes e receita. 3. Pessoas e cultura.',
  resumo_discussoes:
    'A conta trouxe a carteira aberta por cliente e ficou evidente a concentração em três contratos. '
    + 'O conselho pediu o desenho de um plano de diluição dessa concentração.',
  deliberacoes: 'D1. Aprovado o plano de diluição de carteira. Dono: Sócia de Exemplo. Prazo: sessenta dias.',
  proximos_passos: 'P1. Trazer a carteira aberta por cliente e por margem no próximo encontro.',
  proxima_reuniao: 'Próxima reunião em trinta dias.',
}

const CONTEUDO_SERRA_8 = {
  identificacao: 'Conselho Serra, turma quinzenal. Ata número 8 do ciclo.',
  participantes: 'Presentes: Conselheiro de Exemplo, Assessora de Exemplo e os sócios da conta.',
  pauta: '1. Pessoas, liderança e sucessão. 2. Estrutura do time de operação.',
  resumo_discussoes:
    'A reunião tratou de pessoas do cliente, com nomes e avaliações de time. Por isso a ata nasce '
    + 'restrita e não é enviada. O registro fica na casa, para o líder tratar diretamente com a conta.',
  deliberacoes: 'Registro mantido na casa. Nada desta ata circula por envio.',
  proximos_passos: 'Conversa reservada entre o conselheiro e a sócia responsável.',
  proxima_reuniao: 'Próxima reunião em quinze dias, com pauta ordinária.',
}

export const ATAS_EXEMPLO: AtaNaLista[] = [
  {
    ...CARIMBO,
    id: 'ata-01',
    conta_id: 'ct-01',
    conta_nome: nomeDaConta('ct-01'),
    turma_id: 'tu-01',
    turma_nome: nomeDaTurma('tu-01'),
    pauta_id: 'pa-01',
    modelo_ata_id: 'mo-01',
    encontro_id: null,
    numero: 12,
    titulo: 'Reunião ordinária do conselho',
    data_reuniao: emDias(-3),
    conteudo: CONTEUDO_AURORA_12,
    status: 'aprovada',
    restrita: false,
    ata_anterior_aprovada: true,
    escrita_por: 'us-assessora',
    escrita_por_nome: 'Assessora de Exemplo',
    escrita_em: emHoras(-70),
    aprovada_por: 'us-conselheiro',
    aprovada_por_nome: 'Conselheiro de Exemplo',
    aprovada_em: emHoras(-40),
    enviada_em: null,
    prazo_envio: emHoras(-24),
    destinatarios: ['Sócia de Exemplo', 'Diretor de Exemplo'],
    arquivo_pdf_url: null,
    arquivo_docx_url: null,
    gerada_com_ia: false,
    proxima_data: emDias(12),
    pre_pauta: [],
    insight_conselho:
      'O conselho ganha tração quando a deliberação sai com dono e prazo no mesmo minuto em que é tomada.',
  },
  {
    ...CARIMBO,
    id: 'ata-02',
    conta_id: 'ct-01',
    conta_nome: nomeDaConta('ct-01'),
    turma_id: 'tu-01',
    turma_nome: nomeDaTurma('tu-01'),
    pauta_id: null,
    modelo_ata_id: 'mo-01',
    encontro_id: null,
    numero: 11,
    titulo: 'Reunião ordinária do conselho',
    data_reuniao: emDias(-18),
    conteudo: CONTEUDO_AURORA_11,
    status: 'enviada',
    restrita: false,
    ata_anterior_aprovada: true,
    escrita_por: 'us-assessora',
    escrita_por_nome: 'Assessora de Exemplo',
    escrita_em: emHoras(-430),
    aprovada_por: 'us-conselheiro',
    aprovada_por_nome: 'Conselheiro de Exemplo',
    aprovada_em: emHoras(-420),
    enviada_em: emHoras(-415),
    prazo_envio: emHoras(-408),
    destinatarios: ['Sócia de Exemplo', 'Diretor de Exemplo'],
    arquivo_pdf_url: null,
    arquivo_docx_url: null,
    gerada_com_ia: false,
    proxima_data: emDias(-3),
    pre_pauta: [],
    insight_conselho: null,
  },
  {
    ...CARIMBO,
    id: 'ata-03',
    conta_id: 'ct-02',
    conta_nome: nomeDaConta('ct-02'),
    turma_id: 'tu-02',
    turma_nome: nomeDaTurma('tu-02'),
    pauta_id: null,
    modelo_ata_id: 'mo-01',
    encontro_id: null,
    numero: 5,
    titulo: 'Reunião ordinária do conselho',
    data_reuniao: emDias(0),
    conteudo: CONTEUDO_CLINICA_5,
    status: 'em_aprovacao',
    restrita: false,
    ata_anterior_aprovada: true,
    escrita_por: 'us-assessora',
    escrita_por_nome: 'Assessora de Exemplo',
    escrita_em: emHoras(-4),
    aprovada_por: null,
    aprovada_por_nome: null,
    aprovada_em: null,
    enviada_em: null,
    prazo_envio: emHoras(20),
    destinatarios: ['Sócia de Exemplo'],
    arquivo_pdf_url: null,
    arquivo_docx_url: null,
    gerada_com_ia: true,
    proxima_data: emDias(30),
    pre_pauta: [],
    insight_conselho: null,
  },
  {
    ...CARIMBO,
    id: 'ata-04',
    conta_id: 'ct-03',
    conta_nome: nomeDaConta('ct-03'),
    turma_id: 'tu-03',
    turma_nome: nomeDaTurma('tu-03'),
    pauta_id: null,
    modelo_ata_id: 'mo-01',
    encontro_id: null,
    numero: 8,
    titulo: 'Reunião sobre pessoas do cliente',
    data_reuniao: emDias(-2),
    conteudo: CONTEUDO_SERRA_8,
    status: 'rascunho',
    restrita: true,
    ata_anterior_aprovada: true,
    escrita_por: 'us-assessora',
    escrita_por_nome: 'Assessora de Exemplo',
    escrita_em: emHoras(-44),
    aprovada_por: null,
    aprovada_por_nome: null,
    aprovada_em: null,
    enviada_em: null,
    prazo_envio: emHoras(-1),
    // Ata restrita não tem destinatário. A restrição de verificação do banco garante.
    destinatarios: [],
    arquivo_pdf_url: null,
    arquivo_docx_url: null,
    gerada_com_ia: false,
    proxima_data: emDias(13),
    pre_pauta: [],
    insight_conselho: null,
  },
]

// ------------------------------------------------------------ pendências

export const PENDENCIAS_EXEMPLO: PendenciaNaLista[] = [
  {
    ...CARIMBO,
    id: 'pe-01',
    conta_id: 'ct-01',
    conta_nome: nomeDaConta('ct-01'),
    turma_id: 'tu-01',
    turma_nome: nomeDaTurma('tu-01'),
    encontro_id: null,
    ata_id: 'ata-01',
    ata_numero: 12,
    ata_secao: 'deliberacoes',
    origem: 'deliberacao',
    descricao: 'Escrever a tabela de alçadas em três faixas e circular para leitura do conselho.',
    dono_usuario_id: null,
    dono_nome: 'Diretor de Exemplo',
    dono: 'Diretor de Exemplo',
    prazo: emDias(27),
    status: 'aberta',
    reaparece_na_pauta: true,
    concluida_em: null,
    evidencia: null,
  },
  {
    ...CARIMBO,
    id: 'pe-02',
    conta_id: 'ct-01',
    conta_nome: nomeDaConta('ct-01'),
    turma_id: 'tu-01',
    turma_nome: nomeDaTurma('tu-01'),
    encontro_id: null,
    ata_id: 'ata-02',
    ata_numero: 11,
    ata_secao: 'proximos_passos',
    origem: 'proximo_passo',
    descricao: 'Levantar o custo por linha de portfólio com o financeiro e trazer o corte de margem pronto.',
    dono_usuario_id: null,
    dono_nome: 'Sócia de Exemplo',
    dono: 'Sócia de Exemplo',
    // Prazo vencido. Entra na pré-pauta marcada como atrasada.
    prazo: emDias(-9),
    status: 'em_andamento',
    reaparece_na_pauta: true,
    concluida_em: null,
    evidencia: null,
  },
  {
    ...CARIMBO,
    id: 'pe-03',
    conta_id: 'ct-01',
    conta_nome: nomeDaConta('ct-01'),
    turma_id: 'tu-01',
    turma_nome: nomeDaTurma('tu-01'),
    encontro_id: null,
    ata_id: 'ata-02',
    ata_numero: 11,
    ata_secao: 'proximos_passos',
    origem: 'proximo_passo',
    descricao: 'Confirmar quem responde pelos dados de operação no painel de indicadores.',
    dono_usuario_id: 'us-assessora',
    dono_nome: null,
    dono: 'Assessora de Exemplo',
    // Sem prazo. A pré-pauta joga para o fim do bloco de pendências.
    prazo: null,
    status: 'aberta',
    reaparece_na_pauta: true,
    concluida_em: null,
    evidencia: null,
  },
  {
    ...CARIMBO,
    id: 'pe-04',
    conta_id: 'ct-02',
    conta_nome: nomeDaConta('ct-02'),
    turma_id: 'tu-02',
    turma_nome: nomeDaTurma('tu-02'),
    encontro_id: null,
    ata_id: 'ata-03',
    ata_numero: 5,
    ata_secao: 'deliberacoes',
    origem: 'deliberacao',
    descricao: 'Desenhar o plano de diluição da concentração de carteira em três contratos.',
    dono_usuario_id: null,
    dono_nome: 'Sócia de Exemplo',
    dono: 'Sócia de Exemplo',
    prazo: emDias(-2),
    status: 'aberta',
    reaparece_na_pauta: true,
    concluida_em: null,
    evidencia: null,
  },
  {
    ...CARIMBO,
    id: 'pe-05',
    conta_id: 'ct-01',
    conta_nome: nomeDaConta('ct-01'),
    turma_id: 'tu-01',
    turma_nome: nomeDaTurma('tu-01'),
    encontro_id: null,
    ata_id: 'ata-02',
    ata_numero: 11,
    ata_secao: 'proximos_passos',
    origem: 'tarefa_do_assessor',
    descricao: 'Publicar o calendário do semestre do conselho para os participantes da turma.',
    dono_usuario_id: 'us-assessora',
    dono_nome: null,
    dono: 'Assessora de Exemplo',
    prazo: emDias(-14),
    status: 'concluida',
    reaparece_na_pauta: true,
    concluida_em: emDias(-13),
    evidencia: 'Calendário publicado no portal da turma, com aviso registrado na plataforma.',
  },
  {
    ...CARIMBO,
    id: 'pe-06',
    conta_id: 'ct-03',
    conta_nome: nomeDaConta('ct-03'),
    turma_id: 'tu-03',
    turma_nome: nomeDaTurma('tu-03'),
    encontro_id: null,
    ata_id: null,
    ata_numero: null,
    ata_secao: null,
    origem: 'tarefa_do_conselheiro',
    descricao: 'Revisar o mapa de riscos da operação antes do encontro de outubro.',
    dono_usuario_id: 'us-conselheiro',
    dono_nome: null,
    dono: 'Conselheiro de Exemplo',
    prazo: emDias(16),
    status: 'aberta',
    reaparece_na_pauta: true,
    concluida_em: null,
    evidencia: null,
  },
]

// -------------------------------------------------------- banco de pautas
// Os 15 temas de governança e as 6 famílias de gestão do método, como estão
// semeados em `valor.semear_banco_pautas`.

type LinhaBanco = [
  familia: 'governanca' | 'gestao',
  codigo: string,
  tema: string,
  descricao: string,
  perguntas: [string, string],
  tipo: 'deliberativo' | 'consultivo' | 'informativo',
  minutos: number,
  ordem: number,
]

const BANCO_CRU: LinhaBanco[] = [
  ['governanca', 'GOV01', 'Propósito, missão, visão e valores', 'O porquê da empresa e o que ela não abre mão.',
    ['O propósito está escrito e é o mesmo na boca de cada sócio?', 'Que decisão recente contrariou algum valor declarado?'], 'consultivo', 30, 1],
  ['governanca', 'GOV02', 'Acordo de sócios e regras da sociedade', 'Direitos, deveres, dedicação, remuneração e saída.',
    ['O acordo cobre entrada, saída e impasse?', 'Quem decide o que, e com que maioria?'], 'deliberativo', 45, 2],
  ['governanca', 'GOV03', 'Estrutura e funcionamento do conselho', 'Composição, cadência, pauta e prestação de contas do conselho.',
    ['O conselho é consultivo ou de administração?', 'A cadência atual dá tempo de acompanhar as decisões?'], 'deliberativo', 40, 3],
  ['governanca', 'GOV04', 'Alçadas e processo de decisão', 'Quem decide até que valor e a partir de quando sobe para o conselho.',
    ['Qual decisão hoje trava por falta de alçada clara?', 'O que já foi decidido fora da alçada e por quê?'], 'deliberativo', 40, 4],
  ['governanca', 'GOV05', 'Estratégia de longo prazo e sua revisão', 'Onde a empresa quer chegar e com que frequência revisa o caminho.',
    ['A estratégia de três anos cabe no caixa de doze meses?', 'O que mudou no mercado desde a última revisão?'], 'consultivo', 45, 5],
  ['governanca', 'GOV06', 'Modelo de negócio e a oferta de valor', 'Como a empresa cria, entrega e captura valor.',
    ['Para quem o valor entregue é óbvio, e para quem ainda não é?', 'Que parte do modelo depende de uma pessoa só?'], 'consultivo', 40, 6],
  ['governanca', 'GOV07', 'Indicadores, metas e prestação de contas', 'O painel do conselho e o ritmo de cobrança.',
    ['Quais são os cinco números que o conselho acompanha?', 'Quem responde por cada número, com nome e prazo?'], 'deliberativo', 40, 7],
  ['governanca', 'GOV08', 'Gestão financeira e estrutura de capital', 'Caixa, margem, endividamento e necessidade de aporte.',
    ['Quantos meses de caixa a empresa tem no cenário pessimista?', 'Que dívida vence nos próximos doze meses?'], 'deliberativo', 45, 8],
  ['governanca', 'GOV09', 'Riscos, controles e continuidade', 'O mapa de riscos e o plano de continuidade do negócio.',
    ['Qual risco derruba a operação em uma semana?', 'Que controle existe hoje e quem testa esse controle?'], 'deliberativo', 40, 9],
  ['governanca', 'GOV10', 'Conformidade legal, fiscal e regulatória', 'Obrigações, licenças, contratos e passivos.',
    ['Que obrigação está vencida ou perto de vencer?', 'Qual passivo não está provisionado?'], 'informativo', 30, 10],
  ['governanca', 'GOV11', 'Ética, conduta e canal de denúncia', 'O código de conduta e o caminho seguro para reportar desvio.',
    ['O canal de denúncia existe, funciona e é conhecido?', 'Que caso foi tratado no período e como terminou?'], 'consultivo', 30, 11],
  ['governanca', 'GOV12', 'Pessoas, liderança e sucessão', 'Time-chave, retenção, desenvolvimento e plano de sucessão.',
    ['Quem substitui cada posição crítica amanhã?', 'Que líder está pronto para o próximo degrau?'], 'consultivo', 45, 12],
  ['governanca', 'GOV13', 'Propriedade intelectual e ativos', 'Titularidade da marca, do software, das bases e dos contratos.',
    ['A propriedade intelectual está no nome da empresa?', 'Que ativo está registrado em nome de pessoa física?'], 'deliberativo', 30, 13],
  ['governanca', 'GOV14', 'Marca, comunicação e reputação', 'Como a empresa é vista e como responde quando é mal vista.',
    ['Que promessa a marca faz e a operação não cumpre?', 'Existe protocolo para crise de reputação?'], 'consultivo', 30, 14],
  ['governanca', 'GOV15', 'Crescimento, expansão e novos mercados', 'Onde crescer, com que capital e em que ordem.',
    ['Qual a próxima fronteira e por que agora?', 'O que precisa estar pronto antes de escalar?'], 'deliberativo', 45, 15],
  ['gestao', 'GES01', 'Estratégia e mercado', 'Família de gestão: posicionamento, concorrência e escolhas de onde competir.',
    ['Que escolha estratégica ainda não foi feita?', 'Quem é o concorrente que mais incomoda e por quê?'], 'consultivo', 40, 21],
  ['gestao', 'GES02', 'Processos e operação', 'Família de gestão: desenho, padronização e produtividade da operação.',
    ['Qual processo quebra quando o volume dobra?', 'O que é feito à mão e deveria ser sistema?'], 'deliberativo', 40, 22],
  ['gestao', 'GES03', 'Pessoas e cultura', 'Família de gestão: estrutura, papéis, avaliação e cultura.',
    ['A estrutura atual sustenta a meta do ano?', 'Que comportamento a cultura premia sem querer?'], 'consultivo', 40, 23],
  ['gestao', 'GES04', 'Finanças e resultado', 'Família de gestão: precificação, custo, margem e capital de giro.',
    ['Que produto ou cliente destrói margem?', 'O preço acompanhou o custo no último ano?'], 'deliberativo', 40, 24],
  ['gestao', 'GES05', 'Clientes e receita', 'Família de gestão: funil, carteira, retenção e expansão de receita.',
    ['Qual a receita recorrente em risco nos próximos noventa dias?', 'Que cliente cresce e ninguém percebeu?'], 'deliberativo', 40, 25],
  ['gestao', 'GES06', 'Inovação e tecnologia', 'Família de gestão: produto, dados, automação e adoção de tecnologia.',
    ['Que aposta de inovação está sem dono?', 'Onde a tecnologia hoje custa mais do que devolve?'], 'consultivo', 40, 26],
]

export const BANCO_PAUTAS_EXEMPLO: BancoPauta[] = BANCO_CRU.map((linha) => ({
  ...CARIMBO,
  id: `bp-${linha[1]}`,
  familia: linha[0],
  codigo: linha[1],
  tema: linha[2],
  descricao: linha[3],
  perguntas_orientadoras: [...linha[4]],
  materiais: [],
  tipo_sugerido: linha[5],
  tempo_sugerido_minutos: linha[6],
  ordem: linha[7],
  ativo: true,
}))

// ------------------------------------------------------------ pauta e pré-pauta

export const PAUTA_EXEMPLO: Pauta = {
  ...CARIMBO,
  id: 'pa-02',
  conta_id: 'ct-01',
  turma_id: 'tu-01',
  encontro_id: null,
  numero: 13,
  titulo: 'Reunião ordinária do conselho',
  data_reuniao: emDias(12),
  hora_inicio: '09:00',
  status: 'rascunho',
  observacao: 'Pauta em preparo. As pendências em aberto já entraram sozinhas.',
  publicada_em: null,
  enviada_em: null,
  gerada_com_ia: false,
}

/**
 * Repete a ordenação de `valor.montar_pre_pauta`: primeiro as pendências que
 * reaparecem, ordenadas por prazo com as sem prazo no fim, depois até cinco
 * temas do banco de pautas que a turma ainda não tratou.
 *
 * A pendência aberta reaparece aqui em toda reunião, até fechar. Essa é a regra
 * que mais importa da tela da pauta.
 */
export function montarPrePautaDeExemplo(
  turmaId: string,
  dataReferencia: string,
  jaTratados: string[] = [],
): LinhaPrePauta[] {
  const pendentes = PENDENCIAS_EXEMPLO.filter(
    (pendencia) =>
      pendencia.turma_id === turmaId
      && pendencia.arquivado_em === null
      && pendencia.reaparece_na_pauta
      && (pendencia.status === 'aberta' || pendencia.status === 'em_andamento'),
  ).sort((a, b) => {
    if (!a.prazo && !b.prazo) return 0
    if (!a.prazo) return 1
    if (!b.prazo) return -1
    return a.prazo.localeCompare(b.prazo)
  })

  const doBloco: LinhaPrePauta[] = pendentes.map((pendencia, indice) => ({
    ordem_item: indice + 1,
    bloco: 'pendencia',
    tema: 'Pendência em aberto',
    detalhe: pendencia.descricao,
    dono: pendencia.dono,
    prazo: pendencia.prazo,
    situacao: !pendencia.prazo
      ? 'sem prazo definido'
      : pendencia.prazo < dataReferencia
        ? 'atrasada'
        : 'no prazo',
    tempo_previsto_minutos: 10,
    tipo: 'deliberativo',
    pendencia_id: pendencia.id,
    banco_pauta_id: null,
  }))

  const sugeridos: LinhaPrePauta[] = BANCO_PAUTAS_EXEMPLO.filter(
    (tema) => tema.ativo && !jaTratados.includes(tema.id),
  )
    .slice(0, 5)
    .map((tema, indice) => ({
      ordem_item: doBloco.length + indice + 1,
      bloco: 'tema_sugerido',
      tema: tema.tema,
      detalhe: tema.descricao,
      dono: null,
      prazo: null,
      situacao: 'sugestão do banco de pautas',
      tempo_previsto_minutos: tema.tempo_sugerido_minutos,
      tipo: tema.tipo_sugerido,
      pendencia_id: null,
      banco_pauta_id: tema.id,
    }))

  return [...doBloco, ...sugeridos]
}

/** Os itens já escritos na pauta de exemplo, com os automáticos de pendência. */
function itensDaPautaDeExemplo(): ItemPautaNaTela[] {
  const automaticos: ItemPautaNaTela[] = PENDENCIAS_EXEMPLO.filter(
    (pendencia) =>
      pendencia.turma_id === PAUTA_EXEMPLO.turma_id
      && pendencia.reaparece_na_pauta
      && (pendencia.status === 'aberta' || pendencia.status === 'em_andamento'),
  ).map((pendencia, indice) => ({
    ...CARIMBO,
    id: `pi-auto-${pendencia.id}`,
    pauta_id: PAUTA_EXEMPLO.id,
    ordem: indice + 1,
    tema: 'Pendência em aberto',
    detalhe: pendencia.descricao,
    tipo: 'deliberativo',
    tempo_previsto_minutos: 10,
    responsavel_usuario_id: pendencia.dono_usuario_id,
    responsavel_nome: pendencia.dono_nome,
    responsavel: pendencia.dono,
    origem: 'pendencia_aberta',
    pendencia_id: pendencia.id,
    banco_pauta_id: null,
    automatico: true,
    tratado: false,
  }))

  const escritos: ItemPautaNaTela[] = [
    {
      ...CARIMBO,
      id: 'pi-01',
      pauta_id: PAUTA_EXEMPLO.id,
      ordem: automaticos.length + 1,
      tema: 'Painel de indicadores do trimestre',
      detalhe: 'Receita, margem por linha de portfólio e caixa projetado para noventa dias.',
      tipo: 'informativo',
      tempo_previsto_minutos: 30,
      responsavel_usuario_id: null,
      responsavel_nome: 'Sócia de Exemplo',
      responsavel: 'Sócia de Exemplo',
      origem: 'ritual_semanal',
      pendencia_id: null,
      banco_pauta_id: null,
      automatico: false,
      tratado: false,
    },
    {
      ...CARIMBO,
      id: 'pi-02',
      pauta_id: PAUTA_EXEMPLO.id,
      ordem: automaticos.length + 2,
      tema: 'Indicadores, metas e prestação de contas',
      detalhe: 'O painel do conselho e o ritmo de cobrança.',
      tipo: 'deliberativo',
      tempo_previsto_minutos: 40,
      responsavel_usuario_id: 'us-conselheiro',
      responsavel_nome: null,
      responsavel: 'Conselheiro de Exemplo',
      origem: 'banco_de_pautas',
      pendencia_id: null,
      banco_pauta_id: 'bp-GOV07',
      automatico: false,
      tratado: false,
    },
  ]

  return [...automaticos, ...escritos]
}

// ------------------------------------------------------------------- NPS

/** O instrumento da casa, como está semeado em `valor.semear_questoes_nps`. */
const QUESTOES_CRU: Array<[number, PesquisaQuestao['bloco'], PesquisaQuestao['tipo'], string, boolean, number | null, number | null, boolean]> = [
  [1, 'recomendacao', 'nota_0_10', 'Em uma escala de 0 a 10, o quanto você recomendaria a Felix Empresarial a um colega ou parceiro?', true, null, null, true],
  [2, 'recomendacao', 'texto_livre', 'Qual o principal motivo da sua nota?', true, null, null, false],
  [3, 'qualidade', 'escala', 'Como você avalia a qualidade técnica do que foi entregue?', true, 1, 5, false],
  [4, 'atendimento', 'escala', 'Como você avalia o atendimento e a disponibilidade da equipe?', true, 1, 5, false],
  [5, 'relacionamento_comercial', 'escala', 'Como você avalia a clareza e a postura no relacionamento comercial?', true, 1, 5, false],
  [6, 'entrega', 'escala', 'Como você avalia o cumprimento de prazos e combinados na entrega?', true, 1, 5, false],
  [7, 'valor_percebido', 'escala', 'O quanto o resultado entregue justifica o investimento feito?', true, 1, 5, false],
  [8, 'lealdade', 'escala', 'Qual a sua intenção de continuar com a Felix Empresarial no próximo ciclo?', true, 1, 5, false],
  [9, 'inovacao', 'escala', 'O quanto a Felix Empresarial traz ideias novas e provocações úteis para o seu negócio?', true, 1, 5, false],
  [10, 'inovacao', 'texto_livre', 'O que faríamos de diferente para merecer uma nota mais alta?', false, null, null, false],
]

export const QUESTOES_EXEMPLO: PesquisaQuestao[] = QUESTOES_CRU.map((linha) => ({
  ...CARIMBO,
  id: `qu-${linha[0]}`,
  pesquisa_id: 'pq-01',
  ordem: linha[0],
  bloco: linha[1],
  tipo: linha[2],
  enunciado: linha[3],
  ajuda: null,
  obrigatoria: linha[4],
  escala_minimo: linha[5],
  escala_maximo: linha[6],
  opcoes: [],
  eh_pergunta_classica: linha[7],
}))

const PESQUISA_EXEMPLO: Pesquisa = {
  ...CARIMBO,
  id: 'pq-01',
  conta_id: 'ct-01',
  turma_id: 'tu-01',
  programa_id: null,
  tipo: 'nps_trimestral',
  titulo: 'NPS do trimestre',
  periodo: competenciaAtual(),
  periodo_inicio: emDias(-80),
  periodo_fim: emDias(10),
  publico_alvo: 'Sócios e diretoria da conta',
  status: 'aberta',
  abertura_em: `${emDias(-20)}T09:00:00.000Z`,
  anonima: false,
  observacao: null,
}

/**
 * A última nota de cada pessoa, com a data e a motivação escrita. Nunca a média.
 * A decisão é da casa e está escrita na tela, porque as pessoas perguntam.
 */
const NPS_PESSOAS_EXEMPLO: LinhaNpsPessoa[] = [
  {
    conta_id: 'ct-01',
    respondente_chave: 'ct-01-p1',
    respondente: 'Sócia de Exemplo',
    anonima: false,
    nota: 10,
    data_da_nota: emDias(-12),
    faixa: 'promotor',
    motivacao: 'O conselho trouxe ritmo de decisão. Saímos das reuniões com dono e prazo em tudo.',
    periodo: competenciaAtual(),
  },
  {
    conta_id: 'ct-01',
    respondente_chave: 'ct-01-p2',
    respondente: 'Diretor de Exemplo',
    anonima: false,
    nota: 9,
    data_da_nota: emDias(-11),
    faixa: 'promotor',
    motivacao: 'O painel de indicadores ficou muito melhor. Ainda quero ver o corte de margem por linha.',
    periodo: competenciaAtual(),
  },
  {
    conta_id: 'ct-01',
    respondente_chave: 'ct-01-p3',
    respondente: 'Gerente de Exemplo',
    anonima: false,
    nota: 8,
    data_da_nota: emDias(-10),
    faixa: 'neutro',
    motivacao: 'Gosto das reuniões, mas a ata às vezes demora a chegar.',
    periodo: competenciaAtual(),
  },
  {
    conta_id: 'ct-01',
    respondente_chave: 'ct-01-p4',
    respondente: 'anônimo',
    anonima: true,
    nota: 6,
    data_da_nota: emDias(-9),
    faixa: 'detrator',
    motivacao: 'Sinto que discutimos muito e executamos pouco entre uma reunião e outra.',
    periodo: competenciaAtual(),
  },
  {
    conta_id: 'ct-01',
    respondente_chave: 'ct-01-p5',
    respondente: 'Sócio de Exemplo',
    anonima: false,
    nota: 9,
    data_da_nota: emDias(-8),
    faixa: 'promotor',
    motivacao: 'A pendência que não fecha volta na pauta. Isso mudou o jogo aqui dentro.',
    periodo: competenciaAtual(),
  },
]

/** O consolidado sai das últimas notas, como na visão do banco. */
export function consolidarNps(pessoas: LinhaNpsPessoa[], contaId: string): ConsolidadoNps {
  const promotores = pessoas.filter((p) => p.faixa === 'promotor').length
  const neutros = pessoas.filter((p) => p.faixa === 'neutro').length
  const detratores = pessoas.filter((p) => p.faixa === 'detrator').length
  const respondentes = pessoas.length
  const datas = pessoas.map((p) => p.data_da_nota).sort()

  return {
    conta_id: contaId,
    respondentes,
    promotores,
    neutros,
    detratores,
    nps: respondentes
      ? Math.round(((promotores - detratores) / respondentes) * 1000) / 10
      : 0,
    ultima_resposta: datas.length > 0 ? (datas[datas.length - 1] ?? null) : null,
  }
}

const CICLOS_EXEMPLO: AlertaCiclo[] = [
  {
    id: 'ci-01',
    conta_id: 'ct-01',
    tipo: 'nps_trimestral',
    periodicidade_meses: 3,
    ultima_aplicacao: emDias(-80),
    proxima_aplicacao: emDias(10),
    dias_para_o_ciclo: 10,
    situacao: 'a vencer',
  },
  {
    id: 'ci-02',
    conta_id: 'ct-01',
    tipo: 'nota_conselheiro_semestral',
    periodicidade_meses: 6,
    ultima_aplicacao: emDias(-200),
    proxima_aplicacao: emDias(-18),
    dias_para_o_ciclo: -18,
    situacao: 'vencido',
  },
  {
    id: 'ci-03',
    conta_id: 'ct-02',
    tipo: 'nps_trimestral',
    periodicidade_meses: 3,
    ultima_aplicacao: emDias(-30),
    proxima_aplicacao: emDias(60),
    dias_para_o_ciclo: 60,
    situacao: 'em dia',
  },
  {
    id: 'ci-04',
    conta_id: 'ct-02',
    tipo: 'nota_conselheiro_semestral',
    periodicidade_meses: 6,
    ultima_aplicacao: null,
    proxima_aplicacao: emDias(4),
    dias_para_o_ciclo: 4,
    situacao: 'a vencer',
  },
  {
    id: 'ci-05',
    conta_id: 'ct-03',
    tipo: 'nps_trimestral',
    periodicidade_meses: 3,
    ultima_aplicacao: emDias(-95),
    proxima_aplicacao: emDias(-5),
    dias_para_o_ciclo: -5,
    situacao: 'vencido',
  },
]

// -------------------------------------------------- Histórico de Valor

const PROGRAMA_EXEMPLO = {
  id: 'pr-01',
  codigo: 'CONS-12',
  nome: 'Conselho dedicado · ciclo de doze meses',
}

function trimestreAnterior(passos: number): { ano: number; trimestre: number } {
  const base = HOJE.getFullYear() * 4 + Math.floor(HOJE.getMonth() / 3)
  const alvo = base - passos
  return { ano: Math.floor(alvo / 4), trimestre: (alvo % 4) + 1 }
}

function registro(
  id: string,
  contaId: string,
  passos: number,
  entregue: string,
  resultado: string,
  evidencia: string,
  confirmado: boolean,
): HistoricoValor {
  const { ano, trimestre } = trimestreAnterior(passos)
  return {
    ...CARIMBO,
    id,
    conta_id: contaId,
    programa_id: PROGRAMA_EXEMPLO.id,
    turma_id: 'tu-01',
    encontro_id: null,
    entregavel_id: null,
    contrato_id: null,
    ano,
    trimestre,
    competencia: `${ano}-T${trimestre}`,
    data_referencia: emDias(-90 * passos),
    entregue,
    resultado,
    evidencia,
    valor_numero: null,
    valor_unidade: null,
    arquivo_url: null,
    registrado_por: 'us-conselheiro',
    confirmado_por_contato_id: confirmado ? 'co-01' : null,
    confirmado_em: confirmado ? emDias(-90 * passos + 10) : null,
    observacao_interna: null,
  }
}

const HISTORICO_EXEMPLO: HistoricoValor[] = [
  registro(
    'hv-01',
    'ct-01',
    2,
    'Desenho do ciclo de gestão e implantação do painel de indicadores do conselho.',
    'A diretoria passou a fechar o mês com o painel pronto no terceiro dia útil, contra o décimo quinto de antes.',
    'Painel publicado, com as atas 6 a 8 registrando a leitura mês a mês.',
    true,
  ),
  registro(
    'hv-02',
    'ct-01',
    1,
    'Revisão do acordo de sócios e desenho da tabela de alçadas em três faixas.',
    'Decisões de investimento passaram a sair na própria reunião, sem consulta extra entre encontros.',
    'Ata 11, deliberação D1, com a tabela anexada ao registro da turma.',
    true,
  ),
  registro(
    'hv-03',
    'ct-02',
    1,
    'Mapa de carteira por cliente e por margem, com o plano de diluição de concentração.',
    'A conta identificou três contratos que respondiam por mais da metade da receita.',
    'Ata 4, com o mapa de carteira anexado.',
    false,
  ),
]

const DEVIDOS_EXEMPLO: HistoricoDevido[] = [
  {
    programa_id: PROGRAMA_EXEMPLO.id,
    programa_codigo: PROGRAMA_EXEMPLO.codigo,
    programa_nome: PROGRAMA_EXEMPLO.nome,
    conta_id: 'ct-01',
    ano: HOJE.getFullYear(),
    trimestre: Math.floor(HOJE.getMonth() / 3) + 1,
  },
  {
    programa_id: PROGRAMA_EXEMPLO.id,
    programa_codigo: PROGRAMA_EXEMPLO.codigo,
    programa_nome: PROGRAMA_EXEMPLO.nome,
    conta_id: 'ct-02',
    ano: HOJE.getFullYear(),
    trimestre: Math.floor(HOJE.getMonth() / 3) + 1,
  },
  {
    programa_id: PROGRAMA_EXEMPLO.id,
    programa_codigo: PROGRAMA_EXEMPLO.codigo,
    programa_nome: PROGRAMA_EXEMPLO.nome,
    conta_id: 'ct-03',
    ano: HOJE.getFullYear(),
    trimestre: Math.floor(HOJE.getMonth() / 3) + 1,
  },
]

// ============================================================== consultas
// O padrão é o de `dados/consultas.ts`: tenta o banco, cai no exemplo, e diz
// na tela que está em exemplo.

/**
 * Chamada de função do banco.
 *
 * O cliente da casa nasce sem o tipo gerado do esquema, então `rpc` chega sem
 * assinatura útil. A conversão fica presa aqui, num lugar só, em vez de se
 * espalhar por consulta. Quem chama continua tipado.
 */
async function chamarFuncao<T>(nome: string, argumentos: Record<string, unknown>): Promise<T[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const executar = cliente.rpc as unknown as (
    funcao: string,
    parametros: Record<string, unknown>,
  ) => PromiseLike<{ data: T[] | null; error: { message: string } | null }>

  const { data, error } = await executar(nome, argumentos)
  if (error) throw new Error(error.message)
  return data ?? []
}

/** Linha crua de `valor.atas`, com o nome da conta embutido. */
interface LinhaAtaCrua {
  id: string
  conta_id: string
  turma_id: string | null
  numero: number
  titulo: string | null
  data_reuniao: string
  conteudo: Record<string, string> | null
  status: Ata['status']
  restrita: boolean
  escrita_em: string | null
  aprovada_em: string | null
  enviada_em: string | null
  prazo_envio: string
  destinatarios: string[] | null
  proxima_data: string | null
  contas: { nome: string } | { nome: string }[] | null
}

function primeiroNome(contas: LinhaAtaCrua['contas']): string {
  if (!contas) return 'Conta sem nome'
  if (Array.isArray(contas)) return contas[0]?.nome ?? 'Conta sem nome'
  return contas.nome
}

function comoAtaDaLista(linha: LinhaAtaCrua): AtaNaLista {
  return {
    ...CARIMBO,
    id: linha.id,
    conta_id: linha.conta_id,
    conta_nome: primeiroNome(linha.contas),
    turma_id: linha.turma_id,
    turma_nome: null,
    pauta_id: null,
    modelo_ata_id: null,
    encontro_id: null,
    numero: linha.numero,
    titulo: linha.titulo,
    data_reuniao: linha.data_reuniao,
    conteudo: linha.conteudo ?? {},
    status: linha.status,
    restrita: linha.restrita,
    ata_anterior_aprovada: false,
    escrita_por: null,
    escrita_por_nome: null,
    escrita_em: linha.escrita_em,
    aprovada_por: null,
    aprovada_por_nome: null,
    aprovada_em: linha.aprovada_em,
    enviada_em: linha.enviada_em,
    prazo_envio: linha.prazo_envio,
    destinatarios: linha.destinatarios ?? [],
    arquivo_pdf_url: null,
    arquivo_docx_url: null,
    gerada_com_ia: false,
    proxima_data: linha.proxima_data,
    pre_pauta: [],
    insight_conselho: null,
  }
}

const COLUNAS_ATA =
  'id, conta_id, turma_id, numero, titulo, data_reuniao, conteudo, status, restrita, '
  + 'escrita_em, aprovada_em, enviada_em, prazo_envio, destinatarios, proxima_data, contas(nome)'

async function lerAtas(): Promise<AtaNaLista[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data, error } = await cliente
    .from('atas')
    .select(COLUNAS_ATA)
    .is('arquivado_em', null)
    .order('data_reuniao', { ascending: false })
    .returns<LinhaAtaCrua[]>()

  if (error) throw new Error(error.message)
  return (data ?? []).map(comoAtaDaLista)
}

/** A lista de atas, do banco ou do exemplo. */
export function useAtas(): UseQueryResult<RespostaGovernanca<AtaNaLista[]>, Error> {
  return useQuery<RespostaGovernanca<AtaNaLista[]>, Error>({
    queryKey: ['governanca', 'atas', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { dados: ATAS_EXEMPLO, deExemplo: true }
      return { dados: await lerAtas(), deExemplo: false }
    },
  })
}

/** Linha crua de `valor.pendencias`, com conta e ata embutidas. */
interface LinhaPendenciaCrua {
  id: string
  conta_id: string
  turma_id: string | null
  ata_id: string | null
  ata_secao: string | null
  origem: Pendencia['origem']
  descricao: string
  dono_usuario_id: string | null
  dono_nome: string | null
  prazo: string | null
  status: Pendencia['status']
  reaparece_na_pauta: boolean
  concluida_em: string | null
  evidencia: string | null
  contas: { nome: string } | { nome: string }[] | null
  atas: { numero: number } | { numero: number }[] | null
  usuarios: { nome: string } | { nome: string }[] | null
}

function nomeEmbutido(valor: { nome: string } | { nome: string }[] | null): string | null {
  if (!valor) return null
  if (Array.isArray(valor)) return valor[0]?.nome ?? null
  return valor.nome
}

function numeroEmbutido(valor: { numero: number } | { numero: number }[] | null): number | null {
  if (!valor) return null
  if (Array.isArray(valor)) return valor[0]?.numero ?? null
  return valor.numero
}

async function lerPendencias(): Promise<PendenciaNaLista[]> {
  const cliente = obterCliente()
  if (!cliente) throw new Error('Banco não configurado.')

  const { data, error } = await cliente
    .from('pendencias')
    .select(
      'id, conta_id, turma_id, ata_id, ata_secao, origem, descricao, dono_usuario_id, dono_nome, '
      + 'prazo, status, reaparece_na_pauta, concluida_em, evidencia, contas(nome), atas(numero), usuarios(nome)',
    )
    .is('arquivado_em', null)
    .order('prazo', { ascending: true, nullsFirst: false })
    .returns<LinhaPendenciaCrua[]>()

  if (error) throw new Error(error.message)

  return (data ?? []).map((linha) => ({
    ...CARIMBO,
    id: linha.id,
    conta_id: linha.conta_id,
    conta_nome: nomeEmbutido(linha.contas) ?? 'Conta sem nome',
    turma_id: linha.turma_id,
    turma_nome: null,
    encontro_id: null,
    ata_id: linha.ata_id,
    ata_numero: numeroEmbutido(linha.atas),
    ata_secao: linha.ata_secao,
    origem: linha.origem,
    descricao: linha.descricao,
    dono_usuario_id: linha.dono_usuario_id,
    dono_nome: linha.dono_nome,
    dono: nomeEmbutido(linha.usuarios) ?? linha.dono_nome ?? 'Sem dono registrado',
    prazo: linha.prazo,
    status: linha.status,
    reaparece_na_pauta: linha.reaparece_na_pauta,
    concluida_em: linha.concluida_em,
    evidencia: linha.evidencia,
  }))
}

/** As pendências, do banco ou do exemplo. Nenhuma some: fecha com evidência. */
export function usePendencias(): UseQueryResult<RespostaGovernanca<PendenciaNaLista[]>, Error> {
  return useQuery<RespostaGovernanca<PendenciaNaLista[]>, Error>({
    queryKey: ['governanca', 'pendencias', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) return { dados: PENDENCIAS_EXEMPLO, deExemplo: true }
      return { dados: await lerPendencias(), deExemplo: false }
    },
  })
}

/** A ficha de uma ata, com o modelo que vale para a conta. */
export function useAta(id: string | undefined): UseQueryResult<RespostaGovernanca<FichaAta | null>, Error> {
  const atas = useAtas()
  const pendencias = usePendencias()

  const lista = atas.data?.dados ?? []
  const escolhida = id ? lista.find((ata) => ata.id === id) : lista[0]
  const deExemplo = (atas.data?.deExemplo ?? false) || (pendencias.data?.deExemplo ?? false)

  return useQuery<RespostaGovernanca<FichaAta | null>, Error>({
    queryKey: ['governanca', 'ata', id ?? 'primeira', escolhida?.id ?? 'nenhuma', deExemplo],
    enabled: atas.isSuccess && pendencias.isSuccess,
    staleTime: 60_000,
    queryFn: async () => {
      if (!escolhida) return { dados: null, deExemplo }

      // A extensão de 16 blocos é ligada por cliente em modelos_ata_por_conta.
      // Sem linha lá, a conta usa o padrão de sete seções.
      let usaExtensao = false
      if (temBanco()) {
        const cliente = obterCliente()
        if (cliente) {
          const { data } = await cliente
            .from('modelos_ata_por_conta')
            .select('usa_extensao')
            .eq('conta_id', escolhida.conta_id)
            .is('arquivado_em', null)
            .limit(1)
            .returns<Array<{ usa_extensao: boolean }>>()
          usaExtensao = data?.[0]?.usa_extensao ?? false
        }
      }

      return {
        dados: {
          ata: escolhida,
          secoes: usaExtensao ? SECOES_EXTENSAO : SECOES_PADRAO,
          usa_extensao: usaExtensao,
          pendencias: (pendencias.data?.dados ?? []).filter(
            (pendencia) => pendencia.ata_id === escolhida.id,
          ),
        },
        deExemplo,
      }
    },
  })
}

/** Linha crua de `valor.pautas`, com itens embutidos. */
interface LinhaPautaCrua {
  id: string
  conta_id: string
  turma_id: string | null
  numero: number | null
  titulo: string
  data_reuniao: string
  hora_inicio: string | null
  status: Pauta['status']
  observacao: string | null
  contas: { nome: string } | { nome: string }[] | null
}

/**
 * A pauta com a pré-pauta ao lado.
 *
 * A pré-pauta vem de `valor.montar_pre_pauta(turma_id, data_referencia)`, que é
 * quem decide a ordem: pendência aberta primeiro, com dono e prazo, marcada como
 * atrasada quando o prazo passou, e só então os temas sugeridos do banco.
 */
export function usePauta(id: string | undefined): UseQueryResult<RespostaGovernanca<PautaMontada | null>, Error> {
  return useQuery<RespostaGovernanca<PautaMontada | null>, Error>({
    queryKey: ['governanca', 'pauta', id ?? 'proxima', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        const montada: PautaMontada = {
          pauta: PAUTA_EXEMPLO,
          conta_nome: nomeDaConta(PAUTA_EXEMPLO.conta_id),
          turma_nome: nomeDaTurma(PAUTA_EXEMPLO.turma_id),
          itens: itensDaPautaDeExemplo(),
          pre_pauta: montarPrePautaDeExemplo(
            PAUTA_EXEMPLO.turma_id ?? 'tu-01',
            hojeISO(),
            ['bp-GOV07'],
          ),
          banco: BANCO_PAUTAS_EXEMPLO,
        }
        return { dados: montada, deExemplo: true }
      }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      let consulta = cliente
        .from('pautas')
        .select(
          'id, conta_id, turma_id, numero, titulo, data_reuniao, hora_inicio, status, observacao, contas(nome)',
        )
        .is('arquivado_em', null)
      consulta = id ? consulta.eq('id', id) : consulta.order('data_reuniao', { ascending: false })

      const { data: pautas, error } = await consulta.limit(1).returns<LinhaPautaCrua[]>()
      if (error) throw new Error(error.message)

      const crua = pautas?.[0]
      if (!crua) return { dados: null, deExemplo: false }

      const { data: itens, error: erroItens } = await cliente
        .from('pautas_itens')
        .select(
          'id, pauta_id, ordem, tema, detalhe, tipo, tempo_previsto_minutos, responsavel_usuario_id, '
          + 'responsavel_nome, origem, pendencia_id, banco_pauta_id, automatico, tratado',
        )
        .eq('pauta_id', crua.id)
        .is('arquivado_em', null)
        .order('ordem', { ascending: true })
        .returns<Array<Omit<ItemPautaNaTela, keyof typeof CARIMBO | 'responsavel'>>>()

      if (erroItens) throw new Error(erroItens.message)

      const { data: banco, error: erroBanco } = await cliente
        .from('banco_pautas')
        .select(
          'id, familia, codigo, tema, descricao, perguntas_orientadoras, materiais, tipo_sugerido, '
          + 'tempo_sugerido_minutos, ordem, ativo',
        )
        .is('arquivado_em', null)
        .eq('ativo', true)
        .order('familia', { ascending: true })
        .order('ordem', { ascending: true })
        .returns<Array<Omit<BancoPauta, keyof typeof CARIMBO>>>()

      if (erroBanco) throw new Error(erroBanco.message)

      let prePauta: LinhaPrePauta[] = []
      if (crua.turma_id) {
        prePauta = await chamarFuncao<LinhaPrePauta>('montar_pre_pauta', {
          turma_id: crua.turma_id,
          data_referencia: crua.data_reuniao,
        })
      }

      const montada: PautaMontada = {
        pauta: { ...CARIMBO, ...crua, encontro_id: null, publicada_em: null, enviada_em: null, gerada_com_ia: false },
        conta_nome: nomeEmbutido(crua.contas) ?? 'Conta sem nome',
        turma_nome: null,
        itens: (itens ?? []).map((item) => ({
          ...CARIMBO,
          ...item,
          responsavel: item.responsavel_nome,
        })),
        pre_pauta: prePauta,
        banco: (banco ?? []).map((tema) => ({ ...CARIMBO, ...tema })),
      }

      return { dados: montada, deExemplo: false }
    },
  })
}

/** O painel de NPS de uma conta, com o ciclo e o que o banco liberou de avaliação. */
export function usePainelNps(contaId: string): UseQueryResult<RespostaGovernanca<PainelNps | null>, Error> {
  return useQuery<RespostaGovernanca<PainelNps | null>, Error>({
    queryKey: ['governanca', 'nps', contaId, temBanco()],
    // Sem conta escolhida não há painel a montar.
    enabled: contaId.length > 0,
    staleTime: 60_000,
    queryFn: async () => {
      const conta = CONTAS_EXEMPLO.find((linha) => linha.id === contaId)

      if (!temBanco()) {
        const pessoas = NPS_PESSOAS_EXEMPLO.filter((linha) => linha.conta_id === contaId)
        const painel: PainelNps = {
          conta: conta ?? { id: contaId, nome: 'Conta sem nome' },
          pesquisa: contaId === 'ct-01' ? PESQUISA_EXEMPLO : null,
          questoes: QUESTOES_EXEMPLO,
          pessoas,
          consolidado: consolidarNps(pessoas, contaId),
          ciclos: CICLOS_EXEMPLO.filter((ciclo) => ciclo.conta_id === contaId),
          // Avaliação de pessoa não entra em dado de exemplo. Quem decide quem
          // vê é a política de linha, e inventar uma seria mentir sobre gente.
          avaliacoes: [],
        }
        return { dados: painel, deExemplo: true }
      }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      const { data: pessoas, error } = await cliente
        .from('nps_por_conta')
        .select(
          'conta_id, respondente_chave, respondente, anonima, nota, data_da_nota, faixa, motivacao, periodo',
        )
        .eq('conta_id', contaId)
        .order('data_da_nota', { ascending: false })
        .returns<LinhaNpsPessoa[]>()

      if (error) throw new Error(error.message)
      const lista = pessoas ?? []

      const { data: ciclos } = await cliente
        .from('alertas_ciclo_avaliacao')
        .select(
          'id, conta_id, tipo, periodicidade_meses, ultima_aplicacao, proxima_aplicacao, dias_para_o_ciclo, situacao',
        )
        .eq('conta_id', contaId)
        .returns<AlertaCiclo[]>()

      const { data: pesquisas } = await cliente
        .from('pesquisas')
        .select(
          'id, conta_id, turma_id, programa_id, tipo, titulo, periodo, periodo_inicio, periodo_fim, '
          + 'publico_alvo, status, abertura_em, anonima, observacao',
        )
        .eq('conta_id', contaId)
        .is('arquivado_em', null)
        .order('periodo_fim', { ascending: false })
        .limit(1)
        .returns<Array<Omit<Pesquisa, keyof typeof CARIMBO>>>()

      const pesquisa = pesquisas?.[0] ? { ...CARIMBO, ...pesquisas[0] } : null

      let questoes: PesquisaQuestao[] = []
      if (pesquisa) {
        const { data: linhas } = await cliente
          .from('pesquisas_questoes')
          .select(
            'id, pesquisa_id, ordem, bloco, tipo, enunciado, ajuda, obrigatoria, escala_minimo, '
            + 'escala_maximo, opcoes, eh_pergunta_classica',
          )
          .eq('pesquisa_id', pesquisa.id)
          .is('arquivado_em', null)
          .order('ordem', { ascending: true })
          .returns<Array<Omit<PesquisaQuestao, keyof typeof CARIMBO>>>()
        questoes = (linhas ?? []).map((questao) => ({ ...CARIMBO, ...questao }))
      }

      // Avaliação de pessoa é confidencial. A tela não filtra por perfil: pede,
      // e o banco entrega o que aquela sessão pode ver. Vazio é resposta válida.
      const { data: avaliacoes } = await cliente
        .from('avaliacoes_conselheiro')
        .select(
          'id, conta_id, conselheiro_usuario_id, periodo, periodo_inicio, periodo_fim, nota, '
          + 'pontos_fortes, criticas_construtivas, liberada_para_avaliado, liberada_em, devolutiva_do_lider',
        )
        .eq('conta_id', contaId)
        .is('arquivado_em', null)
        .order('periodo_fim', { ascending: false })
        .returns<Array<Partial<PainelNps['avaliacoes'][number]>>>()

      const painel: PainelNps = {
        conta: conta ?? { id: contaId, nome: 'Conta sem nome' },
        pesquisa,
        questoes,
        pessoas: lista,
        consolidado: consolidarNps(lista, contaId),
        ciclos: ciclos ?? [],
        avaliacoes: (avaliacoes ?? []).map((linha) => ({
          ...CARIMBO,
          id: linha.id ?? '',
          conta_id: contaId,
          conselheiro_usuario_id: linha.conselheiro_usuario_id ?? '',
          pesquisa_id: null,
          periodo: linha.periodo ?? '',
          periodo_inicio: linha.periodo_inicio ?? '',
          periodo_fim: linha.periodo_fim ?? '',
          nota: linha.nota ?? 0,
          pontos_fortes: linha.pontos_fortes ?? null,
          criticas_construtivas: linha.criticas_construtivas ?? null,
          comentario_livre: null,
          respondida_em: linha.respondida_em ?? '',
          liberada_para_avaliado: linha.liberada_para_avaliado ?? false,
          liberada_em: linha.liberada_em ?? null,
          devolutiva_do_lider: linha.devolutiva_do_lider ?? null,
        })),
      }

      return { dados: painel, deExemplo: false }
    },
  })
}

/** O Histórico de Valor por conta e por trimestre, com o que falta registrar. */
export function useHistoricoDeValor(): UseQueryResult<RespostaGovernanca<HistoricoDaConta[]>, Error> {
  return useQuery<RespostaGovernanca<HistoricoDaConta[]>, Error>({
    queryKey: ['governanca', 'historico-de-valor', temBanco()],
    staleTime: 60_000,
    queryFn: async () => {
      if (!temBanco()) {
        const dados: HistoricoDaConta[] = CONTAS_EXEMPLO.map((conta) => ({
          conta,
          registros: HISTORICO_EXEMPLO.filter((linha) => linha.conta_id === conta.id),
          devidos: DEVIDOS_EXEMPLO.filter((linha) => linha.conta_id === conta.id),
        }))
        return { dados, deExemplo: true }
      }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      const { data: registros, error } = await cliente
        .from('historico_valor')
        .select(
          'id, conta_id, programa_id, turma_id, ano, trimestre, competencia, data_referencia, '
          + 'entregue, resultado, evidencia, valor_numero, valor_unidade, arquivo_url, confirmado_em, contas(nome)',
        )
        .is('arquivado_em', null)
        .order('ano', { ascending: false })
        .order('trimestre', { ascending: false })
        .returns<Array<Partial<HistoricoValor> & { contas: { nome: string } | { nome: string }[] | null }>>()

      if (error) throw new Error(error.message)

      const { data: devidos } = await cliente
        .from('vw_historico_valor_devido')
        .select('programa_id, programa_codigo, programa_nome, conta_id, ano, trimestre')
        .returns<HistoricoDevido[]>()

      const porConta = new Map<string, HistoricoDaConta>()

      for (const linha of registros ?? []) {
        const contaId = linha.conta_id ?? ''
        const atual = porConta.get(contaId) ?? {
          conta: { id: contaId, nome: nomeEmbutido(linha.contas) ?? 'Conta sem nome' },
          registros: [],
          devidos: [],
        }
        atual.registros.push({
          ...CARIMBO,
          id: linha.id ?? '',
          conta_id: contaId,
          programa_id: linha.programa_id ?? '',
          turma_id: linha.turma_id ?? null,
          encontro_id: null,
          entregavel_id: null,
          contrato_id: null,
          ano: linha.ano ?? 0,
          trimestre: linha.trimestre ?? 0,
          competencia: linha.competencia ?? '',
          data_referencia: linha.data_referencia ?? '',
          entregue: linha.entregue ?? '',
          resultado: linha.resultado ?? '',
          evidencia: linha.evidencia ?? '',
          valor_numero: linha.valor_numero ?? null,
          valor_unidade: linha.valor_unidade ?? null,
          arquivo_url: linha.arquivo_url ?? null,
          registrado_por: null,
          confirmado_por_contato_id: null,
          confirmado_em: linha.confirmado_em ?? null,
          observacao_interna: null,
        })
        porConta.set(contaId, atual)
      }

      for (const devido of devidos ?? []) {
        const atual = porConta.get(devido.conta_id) ?? {
          conta: { id: devido.conta_id, nome: 'Conta sem nome' },
          registros: [],
          devidos: [],
        }
        atual.devidos.push(devido)
        porConta.set(devido.conta_id, atual)
      }

      return { dados: [...porConta.values()], deExemplo: false }
    },
  })
}

/**
 * Grava o conteúdo das seções da ata.
 *
 * Devolve `banco` quando a linha foi atualizada, e `somente_tela` quando não há
 * banco ligado nesta máquina. A tela diz qual dos dois aconteceu, porque
 * prometer gravação que não houve é pior do que não gravar.
 *
 * A conversão de tipo existe porque o cliente da casa nasce sem o tipo gerado
 * do esquema. Ela fica presa aqui, e não se espalha pelas telas.
 */
export async function guardarConteudoDaAta(
  id: string,
  conteudo: ConteudoAta,
): Promise<'banco' | 'somente_tela'> {
  if (!temBanco()) return 'somente_tela'

  const cliente = obterCliente()
  if (!cliente) return 'somente_tela'

  const tabela = cliente.from('atas') as unknown as {
    update: (valores: Record<string, unknown>) => {
      eq: (coluna: string, valor: string) => PromiseLike<{ error: { message: string } | null }>
    }
  }

  const { error } = await tabela.update({ conteudo }).eq('id', id)
  if (error) throw new Error(error.message)
  return 'banco'
}

/**
 * Fecha uma pendência com evidência.
 *
 * Uma pendência nunca some: ela sai da pré-pauta quando alguém escreve o que
 * comprova a conclusão. Sem evidência, a função recusa antes de tocar no banco.
 */
export async function fecharPendencia(
  id: string,
  evidencia: string,
): Promise<'banco' | 'somente_tela'> {
  const texto = evidencia.trim()
  if (!texto) throw new Error('Pendência fecha com evidência. Escreva o que comprova a conclusão.')

  if (!temBanco()) return 'somente_tela'

  const cliente = obterCliente()
  if (!cliente) return 'somente_tela'

  const tabela = cliente.from('pendencias') as unknown as {
    update: (valores: Record<string, unknown>) => {
      eq: (coluna: string, valor: string) => PromiseLike<{ error: { message: string } | null }>
    }
  }

  const { error } = await tabela
    .update({ status: 'concluida', concluida_em: hojeISO(), evidencia: texto })
    .eq('id', id)
  if (error) throw new Error(error.message)
  return 'banco'
}

/** As contas que a governança acompanha, para os filtros das telas. */
export function useContasDaGovernanca(): UseQueryResult<RespostaGovernanca<ContaResumida[]>, Error> {
  return useQuery<RespostaGovernanca<ContaResumida[]>, Error>({
    queryKey: ['governanca', 'contas', temBanco()],
    staleTime: 300_000,
    queryFn: async () => {
      if (!temBanco()) return { dados: CONTAS_EXEMPLO, deExemplo: true }

      const cliente = obterCliente()
      if (!cliente) throw new Error('Banco não configurado.')

      const { data, error } = await cliente
        .from('contas')
        .select('id, nome')
        .is('arquivado_em', null)
        .order('nome', { ascending: true })
        .returns<ContaResumida[]>()

      if (error) throw new Error(error.message)
      return { dados: data ?? [], deExemplo: false }
    },
  })
}

/** A faixa de NPS calculada na interface, para conferir com a do banco. */
export { faixaDaNota }
