/**
 * Tipos do domínio da Plataforma de Valor.
 *
 * Espelho fiel das migrações do esquema `valor`:
 *   0001_tipos_e_funcoes.sql      · os enums comuns
 *   0002_inquilinos_e_usuarios.sql · inquilino, usuário, convite, configuração
 *   0003_nucleo_crm.sql            · oferta, conta, contato, negócio, papel,
 *                                    artefato e interação
 *
 * Os nomes são exatamente os do banco, em snake_case sem acento. Quem quiser
 * rótulo bonito de tela usa os dicionários em `src/tipos/rotulos.ts`.
 * Nenhum campo é renomeado aqui, para que o `select` do Supabase case sem
 * tradução no meio do caminho.
 */

// ---------------------------------------------------------------- apelidos

/** Chave primária uuid. */
export type Uuid = string
/** `timestamptz` serializado pelo PostgREST, no padrão ISO 8601. */
export type DataHora = string
/** `date` serializado pelo PostgREST, no padrão AAAA-MM-DD. */
export type Data = string
/** `numeric(14,2)`. Chega como texto ou número conforme a configuração. */
export type Dinheiro = number

// ------------------------------------------------------------------ enums
// Cada tipo abaixo repete, na mesma ordem, os valores do `create type` da 0001.

export type PerfilUsuario =
  | 'admin_master'
  | 'lider'
  | 'comercial'
  | 'gerente_contas'
  | 'conselheiro'
  | 'assessor'
  | 'financeiro'
  | 'parceiro'
  | 'participante'
  | 'emergencia'

export type PapelNegocio =
  | 'gerente_contas'
  | 'conselheiro'
  | 'pre_vendas'
  | 'gerente_projetos'
  | 'assessor'
  | 'parceiro'

export type TipoArtefato =
  | 'plano_conta'
  | 'plano_negocio'
  | 'plano_trabalho'
  | 'contrato_valor'
  | 'entrega_valor'
  | 'monitoria_valor'
  | 'renovacao_valor'

export type StatusArtefato = 'rascunho' | 'interno_pronto' | 'validado_com_cliente' | 'superado'

/** Sai do artefato validado com o cliente, nunca de percentual. */
export type ForecastCategoria = 'compromisso' | 'possivel' | 'aberto' | 'fora'

export type DesfechoNegocio = 'concluido' | 'vencido' | 'cancelado' | 'perdido'

export type TierConta = 't1' | 't2' | 't3'

/** Leitura qualitativa do time. Jamais vira previsão de receita em tela. */
export type Probabilidade = 'alta' | 'media' | 'baixa'

export type OrigemLead =
  | 'evento'
  | 'indicacao_parceiro'
  | 'indicacao_cliente'
  | 'prospeccao_ativa'
  | 'inbound'
  | 'rede_pessoal'
  | 'licitacao_publica'
  | 'base_instalada'
  | 'outro'

export type RotaNegocio = 'privada' | 'publica'

export type ModalidadeOferta = 'pontual' | 'recorrente' | 'pontual_com_sustentacao'

export type NivelContrato = 'n1' | 'n2' | 'n3'

export type Criticidade = 'verde' | 'amarelo' | 'vermelho'

export type CanalInteracao =
  | 'reuniao_presencial'
  | 'reuniao_online'
  | 'ligacao'
  | 'email'
  | 'whatsapp'
  | 'evento'
  | 'visita'
  | 'outro'

/** `check (fase between 0 and 9)`. A fase 8 não existe no funil. */
export type Fase = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 9

export type DesfechoPublico =
  | 'homologado'
  | 'suspenso'
  | 'impugnado'
  | 'deserto'
  | 'fracassado'
  | 'revogado'
  | 'anulado'

// ------------------------------------------------------ colunas de carimbo
// O bloco que toda tabela de negócio carrega, conforme a seção 7 do contrato.

export interface Carimbo {
  criado_em: DataHora
  criado_por: Uuid | null
  atualizado_em: DataHora | null
  atualizado_por: Uuid | null
  /** Nada é apagado. Arquivar é preencher esta coluna. */
  arquivado_em: DataHora | null
}

export interface DoInquilino {
  inquilino_id: Uuid
}

// ------------------------------------------------- 0002 · inquilino e gente

export interface Inquilino {
  id: Uuid
  nome: string
  apelido: string
  dominio: string | null
  ativo: boolean
  criado_em: DataHora
  atualizado_em: DataHora | null
  arquivado_em: DataHora | null
}

export interface Usuario extends DoInquilino, Carimbo {
  id: Uuid
  auth_id: Uuid | null
  email: string
  nome: string
  perfil: PerfilUsuario
  telefone: string | null
  ativo: boolean
  mfa_obrigatorio: boolean
  ultimo_acesso: DataHora | null
}

export interface Convite extends DoInquilino, Carimbo {
  id: Uuid
  email: string
  nome: string
  perfil: PerfilUsuario
  token_hash: string
  expira_em: DataHora
  aceito_em: DataHora | null
  usuario_id: Uuid | null
  reenviado_em: DataHora | null
  reenvios: number
}

export interface Configuracao extends DoInquilino, Carimbo {
  id: Uuid
  chave: string
  valor: unknown
  rotulo: string
  grupo: string
  editavel_por: PerfilUsuario
}

// ------------------------------------------------------- 0003 · núcleo CRM

export interface Oferta extends DoInquilino, Carimbo {
  id: Uuid
  codigo: string
  nome: string
  familia: string
  modalidade: ModalidadeOferta
  niveis_aceitos: NivelContrato[]
  gera_turma: boolean
  publico_alvo: string | null
  estrutura: string | null
  ativa: boolean
  sugerida: boolean
  ordem: number
}

export interface Conta extends DoInquilino, Carimbo {
  id: Uuid
  nome: string
  razao_social: string | null
  cnpj: string | null
  setor: string | null
  porte: string | null
  cidade: string | null
  uf: string | null
  site: string | null
  tier: TierConta | null
  tier_sugerido: TierConta | null
  tier_confirmado_em: DataHora | null
  prioridade: 1 | 2 | 3 | null
  /** Quantas linhas do portfólio esta conta já comprou. */
  power_of_x: number
  eh_cliente: boolean
  eh_prospecto: boolean
  eh_fornecedor: boolean
  eh_parceiro: boolean
  gerente_contas_id: Uuid | null
  observacoes: string | null
}

export interface Contato extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  nome: string
  cargo: string | null
  /** Decisor, influenciador, usuário, guardião, patrocinador. */
  papel_decisao: string | null
  /** CONFIDENCIAL: quem tem papel na conta. Pode voltar nulo por máscara. */
  email: string | null
  /** CONFIDENCIAL: quem tem papel na conta. Pode voltar nulo por máscara. */
  telefone: string | null
  linkedin: string | null
  eh_principal: boolean
  aniversario: Data | null
  observacoes: string | null
}

export interface Negocio extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  oferta_id: Uuid | null
  parceiro_id: Uuid | null
  titulo: string
  descricao: string | null
  fase: Fase
  rota: RotaNegocio
  origem: OrigemLead
  origem_detalhe: string | null
  /** CONFIDENCIAL: time interno e o parceiro dono do negócio. */
  valor_total: Dinheiro | null
  valor_recorrente_mes: Dinheiro | null
  meses_recorrencia: number | null
  nivel_contrato: NivelContrato
  /** Leitura qualitativa do time. Nunca vira previsão de receita em tela. */
  probabilidade: Probabilidade | null
  /** A data em que o cliente decide. O nome desta data é este, e nenhum outro. */
  data_decisao_cliente: Data | null
  proximo_passo: string | null
  proximo_passo_data: Data | null
  proximo_passo_responsavel: Uuid | null
  ultima_interacao: Data | null
  entrou_na_fase_em: Data
  desfecho: DesfechoNegocio | null
  motivo_desfecho: string | null
  data_desfecho: Data | null
  concorrente: string | null
}

export interface NegocioRotaPublica extends DoInquilino {
  negocio_id: Uuid
  identificador_pncp: string | null
  orgao: string | null
  modalidade: string | null
  fase_administrativa: string | null
  data_sessao: Data | null
  data_publicacao: Data | null
  desfecho_publico: DesfechoPublico | null
  criado_em: DataHora
  atualizado_em: DataHora | null
  atualizado_por: Uuid | null
}

export interface PapelNegocioRegistro extends DoInquilino, Carimbo {
  id: Uuid
  negocio_id: Uuid
  usuario_id: Uuid | null
  parceiro_id: Uuid | null
  papel: PapelNegocio
  /** O conselheiro entra na fase 3, Conexão de Valor, e segue até o fim. */
  entrou_na_fase: Fase
  principal: boolean
  ativo: boolean
}

export interface Artefato extends DoInquilino, Carimbo {
  id: Uuid
  negocio_id: Uuid
  tipo: TipoArtefato
  /** Só `validado_com_cliente` conta para o forecast. */
  status: StatusArtefato
  versao: number
  titulo: string | null
  conteudo: Record<string, unknown>
  arquivo_url: string | null
  validado_em: Data | null
  validado_por_contato: Uuid | null
  gerado_com_ia: boolean
}

export interface Interacao extends DoInquilino, Carimbo {
  id: Uuid
  conta_id: Uuid
  negocio_id: Uuid | null
  contato_id: Uuid | null
  usuario_id: Uuid | null
  canal: CanalInteracao
  ocorrida_em: DataHora
  assunto: string
  resumo: string | null
  transcricao_url: string | null
  /** Conversa sobre pessoas do cliente. Fica fora de qualquer visão de parceiro. */
  restrita: boolean
  gerado_com_ia: boolean
}

// --------------------------------------------------- leituras derivadas
// Não são tabelas. São o que o painel calcula, ou o que a visão do banco
// devolve pronta. Ficam aqui porque a interface conversa com elas.

/** As quatro invariantes de higiene, na ordem da seção 6 do contrato. */
export type ChaveInvariante =
  | 'proximo_passo_com_data'
  | 'data_decisao_no_futuro'
  | 'interacao_em_30_dias'
  | 'artefato_da_fase_registrado'

export interface InvarianteHigiene {
  chave: ChaveInvariante
  nome: string
  explicacao: string
  /** Negócios ativos nas fases 1 a 4 que cumprem a invariante. */
  cumprem: number
  /** Total de negócios ativos nas fases 1 a 4 avaliados. */
  avaliados: number
  /** O que fazer com quem não cumpre. */
  pendencia: string
}

export interface LinhaForecast {
  categoria: ForecastCategoria
  valor: Dinheiro
  quantos: number
}

export interface LinhaFase {
  fase: Fase
  declarado: Dinheiro
  auditado: Dinheiro
  quantos: number
}

export interface ResumoPipeline {
  /** Soma de tudo que está ativo nas fases 1 a 4. */
  declarado: Dinheiro
  /** Soma do que passa nas quatro invariantes. */
  auditado: Dinheiro
  negocios_declarados: number
  negocios_auditados: number
  periodo_inicio: Data
  periodo_fim: Data
}

/** O que o painel consome de uma vez só. */
export interface PainelPipeline {
  resumo: ResumoPipeline
  forecast: LinhaForecast[]
  invariantes: InvarianteHigiene[]
  fases: LinhaFase[]
  negocios_em_risco: NegocioEmRisco[]
}

export interface NegocioEmRisco {
  id: Uuid
  titulo: string
  conta_nome: string
  fase: Fase
  valor_total: Dinheiro | null
  data_decisao_cliente: Data | null
  proximo_passo: string | null
  proximo_passo_data: Data | null
  ultima_interacao: Data | null
  criticidade: Criticidade
  /** Quais invariantes este negócio deixou de cumprir. */
  falhas: ChaveInvariante[]
}

// ------------------------------------------------------ contexto de sessão
// Espelha `app.inquilino_id`, `app.usuario_id`, `app.perfil` e `app.parceiro_id`.
// A interface lê para montar o menu. Ela nunca esconde dado com isso: quem
// decide o que cada um enxerga é a política de linha no banco.

export interface ContextoSessao {
  inquilino_id: Uuid
  inquilino_nome: string
  usuario_id: Uuid
  usuario_nome: string
  perfil: PerfilUsuario
  parceiro_id: Uuid | null
}
