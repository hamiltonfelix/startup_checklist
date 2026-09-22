/**
 * Implementação de mentira do `ServicoIA`.
 *
 * Devolve texto fixo por campo, depois de uma espera curta, só para que os
 * três estados do botão assistido apareçam de verdade na tela: parado,
 * pensando e com sugestão pronta.
 *
 * Nada aqui chama rede, e nenhuma chave de API existe neste repositório.
 * Quando a chave chegar, escreva outra classe que cumpra a mesma interface e
 * troque o serviço no `ProvedorIA`. Nenhum componente precisa mudar.
 */

import {
  ErroIA,
  type CampoAssistido,
  type SolicitacaoIA,
  type ServicoIA,
  type SugestaoIA,
} from '@/ia/ServicoIA'

const TEXTO_FIXO: Record<CampoAssistido, string> = {
  proximo_passo:
    'Marcar a reunião de validação do Plano de Trabalho com o patrocinador da conta, '
    + 'com pauta enviada dois dias antes e uma pergunta de decisão por bloco. '
    + 'Confirmar na conversa a data em que o cliente pretende decidir.',
  descricao_negocio:
    'Conta busca organizar a rotina de gestão e sustentar o crescimento do último ano. '
    + 'A dor declarada é a falta de ritual de acompanhamento, com decisões sem dono e sem prazo. '
    + 'O negócio cobre diagnóstico, desenho do ciclo de gestão e acompanhamento por doze meses.',
  hipotese_de_valor:
    'Se a conta passar a operar com ciclo de gestão registrado, com dono e prazo em toda decisão, '
    + 'ela reduz retrabalho de diretoria e encurta o tempo entre a decisão e a execução. '
    + 'A evidência a buscar na Exploração Profunda é o tempo médio entre reunião e ação concluída.',
  resumo_interacao:
    'Reunião de alinhamento com a diretoria. Confirmado o escopo do diagnóstico e o calendário '
    + 'dos primeiros encontros. Ficou pendente a indicação de quem responde pelos dados de operação. '
    + 'Próximo passo combinado na própria reunião, com data registrada.',
  pauta_encontro:
    'Abertura e leitura das pendências do encontro anterior. Painel de indicadores do período. '
    + 'Tema central do encontro, com caso preparado por um dos participantes. '
    + 'Deliberações, com dono e prazo. Encerramento com os combinados e a data do próximo encontro.',
  texto_livre:
    'Texto de exemplo gerado pelo serviço de mentira. Serve para provar o fluxo do botão '
    + 'assistido, com aceitar, editar e descartar. Nenhuma chave de API existe neste repositório.',
}

class ServicoIADeMentira implements ServicoIA {
  readonly nome = 'Assistente de Valor · serviço de exemplo'
  readonly disponivel = true

  /** Espera artificial, para o estado pensando durar o suficiente para ser visto. */
  private readonly espera: number

  constructor(espera = 900) {
    this.espera = espera
  }

  sugerir(solicitacao: SolicitacaoIA, sinal?: AbortSignal): Promise<SugestaoIA> {
    return new Promise<SugestaoIA>((resolver, rejeitar) => {
      if (sinal?.aborted) {
        rejeitar(new ErroIA('Sugestão cancelada antes de começar.'))
        return
      }

      const relogio = setTimeout(() => {
        sinal?.removeEventListener('abort', cancelar)

        const base = TEXTO_FIXO[solicitacao.campo] ?? TEXTO_FIXO.texto_livre
        const instrucao = solicitacao.instrucao?.trim()

        resolver({
          texto: instrucao ? `${base}\n\nAjuste solicitado: ${instrucao}` : base,
          origem: this.nome,
          gerado_em: new Date().toISOString(),
          aviso: 'Sugestão de exemplo. Nenhum serviço externo foi chamado.',
        })
      }, this.espera)

      const cancelar = () => {
        clearTimeout(relogio)
        rejeitar(new ErroIA('Sugestão cancelada.'))
      }

      sinal?.addEventListener('abort', cancelar, { once: true })
    })
  }
}

/** A instância usada enquanto a chave da API não existe. */
export const servicoIADeMentira: ServicoIA = new ServicoIADeMentira()
