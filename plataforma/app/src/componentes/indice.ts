/**
 * Porta única dos componentes de base. Quem monta tela importa daqui,
 * e não de cada arquivo, para que trocar a implementação de um componente
 * não obrigue a mexer em toda a aplicação.
 */

export { Abas, type Aba, type PropsAbas } from '@/componentes/Abas'
export { Alarme, type PropsAlarme, type TomAlarme } from '@/componentes/Alarme'
export { Botao, type PropsBotao, type TamanhoBotao, type TomBotao } from '@/componentes/Botao'
export { BotaoIA, type EstadoIA, type PropsBotaoIA } from '@/componentes/BotaoIA'
export { Campo, CampoTexto, type PropsCampo, type PropsCampoTexto } from '@/componentes/Campo'
export { Carregando, Esqueleto, type PropsCarregando } from '@/componentes/Carregando'
export { Cartao, type PropsCartao, type TomCartao } from '@/componentes/Cartao'
export { EstadoVazio, type PropsEstadoVazio } from '@/componentes/EstadoVazio'
export { Etiqueta, type PropsEtiqueta, type TomEtiqueta } from '@/componentes/Etiqueta'
export { Migalhas, type Migalha, type PropsMigalhas } from '@/componentes/Migalhas'
export { Modal, type PropsModal, type TamanhoModal } from '@/componentes/Modal'
export { Paginacao, type PropsPaginacao } from '@/componentes/Paginacao'
export { Selecao, type OpcaoSelecao, type PropsSelecao } from '@/componentes/Selecao'
export {
  Tabela,
  type AlinhamentoColuna,
  type ColunaTabela,
  type PropsTabela,
  type SentidoOrdem,
} from '@/componentes/Tabela'
