/**
 * Contrato do serviço de IA da plataforma.
 *
 * A regra de ouro está na interface, não na implementação: o serviço só
 * devolve uma sugestão de texto. Quem escreve no campo é a pessoa, apertando
 * aceitar. Nenhum caminho deste arquivo grava nada em formulário.
 *
 * A chave da API ainda não existe, então a implementação em uso é a de
 * mentira, em `src/ia/servico-de-mentira.ts`. Quando a chave chegar, basta
 * trocar a implementação registrada no provedor. Nenhum componente muda.
 */

/** Os campos que hoje têm botão assistido ao lado. */
export type CampoAssistido =
  | 'proximo_passo'
  | 'descricao_negocio'
  | 'hipotese_de_valor'
  | 'resumo_interacao'
  | 'pauta_encontro'
  | 'texto_livre'

export interface PedidoIA {
  /** Qual campo está pedindo ajuda. */
  campo: CampoAssistido
  /** O que já está escrito, para a sugestão partir dali em vez do zero. */
  texto_atual?: string
  /**
   * Contexto público do registro em tela: nome da conta, fase, título do
   * negócio. Nunca mande dado confidencial daqui: margem, comissão, avaliação
   * de pessoa e ata restrita ficam de fora, conforme a seção 9 do contrato.
   */
  contexto?: Record<string, string | number | null>
  /** Instrução extra digitada por quem pediu. */
  instrucao?: string
}

export interface SugestaoIA {
  /** O texto proposto. Fica na caixa até alguém aceitar. */
  texto: string
  /** Quem produziu a sugestão, para aparecer no rodapé da caixa. */
  origem: string
  /** Momento da geração, em ISO 8601. */
  gerado_em: string
  /** Aviso opcional exibido junto da sugestão. */
  aviso?: string
}

export interface ServicoIA {
  /** Nome curto, mostrado na caixa de sugestão. */
  readonly nome: string
  /** Falso quando falta chave ou o serviço está fora do ar. */
  readonly disponivel: boolean
  /**
   * Pede uma sugestão. Pode ser cancelado pelo sinal, para o caso de a pessoa
   * fechar a caixa ou trocar de tela enquanto o serviço ainda pensa.
   */
  sugerir(pedido: PedidoIA, sinal?: AbortSignal): Promise<SugestaoIA>
}

/** Erro previsto do serviço, já com texto pronto para a tela. */
export class ErroIA extends Error {
  constructor(mensagem: string) {
    super(mensagem)
    this.name = 'ErroIA'
  }
}
