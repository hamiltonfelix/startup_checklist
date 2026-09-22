import { useLocation } from 'react-router-dom'
import { Botao, Cartao, EstadoVazio, Migalhas } from '@/componentes/indice'
import { grupoDoItem, itemDoCaminho } from '@/layout/menu'

/**
 * Tela ainda não construída.
 *
 * A casca e a navegação já existem inteiras, então toda entrada de menu leva a
 * algum lugar. Quem constrói a tela de verdade troca esta pela dela, sem mexer
 * na navegação.
 */
export function EmConstrucao() {
  const local = useLocation()
  const item = itemDoCaminho(local.pathname)
  const grupo = item ? grupoDoItem(item.chave) : undefined
  const titulo = item?.rotulo ?? 'Tela'

  return (
    <>
      <Migalhas
        itens={[
          ...(grupo ? [{ rotulo: grupo.titulo }] : []),
          { rotulo: titulo },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          {grupo ? <p className="kicker">{grupo.titulo}</p> : null}
          <h1 className="pagina__titulo">{titulo}</h1>
          {item?.descricao ? <p className="pagina__lede">{item.descricao}</p> : null}
        </div>
      </div>

      <Cartao>
        <EstadoVazio
          titulo="Tela ainda por construir"
          texto="A casca, a navegação e o sistema de design já estão de pé. Esta tela entra na próxima entrega, com os dados vindos do banco."
          acoes={<Botao tom="contorno" onClick={() => window.history.back()}>Voltar</Botao>}
        />
      </Cartao>
    </>
  )
}

/** Caminho que não existe em lugar nenhum. */
export function NaoEncontrada() {
  return (
    <>
      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Erro 404</p>
          <h1 className="pagina__titulo">Caminho não encontrado</h1>
        </div>
      </div>

      <Cartao>
        <EstadoVazio
          titulo="Esta tela não existe"
          texto="Confira o endereço, ou volte ao painel do pipeline."
          acoes={
            <Botao tom="principal" onClick={() => window.location.assign('/painel')}>
              Ir para o painel
            </Botao>
          }
        />
      </Cartao>
    </>
  )
}
