import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Alarme,
  Botao,
  Cartao,
  Etiqueta,
  Migalhas,
  Selecao,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useAtas } from '@/dados/governanca'
import type { AtaNaLista, AtaStatus } from '@/tipos/governanca'
import {
  ataAtrasada,
  horasDeAtraso,
  quemFalta,
  ROTULO_ATA_STATUS,
} from '@/tipos/governanca'
import { data as formatarData } from '@/tipos/rotulos'

/**
 * Lista de atas do conselho.
 *
 * Três coisas aparecem antes de qualquer tabela, porque são o rito e não
 * detalhe: quantas atas estouraram as 24 horas, quantas estão restritas e não
 * saem da casa, e em que passo do fluxo cada uma parou.
 */
export function Atas() {
  const navegar = useNavigate()
  const consulta = useAtas()
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [conta, setConta] = useState('')
  const [status, setStatus] = useState('')
  const [somenteAtrasadas, setSomenteAtrasadas] = useState('')

  const todas = useMemo(() => consulta.data?.dados ?? [], [consulta.data])

  const contas = useMemo(() => {
    const vistas = new Map<string, string>()
    for (const ata of todas) vistas.set(ata.conta_id, ata.conta_nome)
    return [...vistas.entries()].map(([valor, rotulo]) => ({ valor, rotulo }))
  }, [todas])

  const lista = useMemo(
    () =>
      todas.filter((ata) => {
        if (conta && ata.conta_id !== conta) return false
        if (status && ata.status !== status) return false
        if (somenteAtrasadas === 'sim' && !ataAtrasada(ata)) return false
        return true
      }),
    [todas, conta, status, somenteAtrasadas],
  )

  const atrasadas = todas.filter((ata) => ataAtrasada(ata))
  const restritas = todas.filter((ata) => ata.restrita)

  const colunas: Array<ColunaTabela<AtaNaLista>> = [
    {
      chave: 'ata',
      rotulo: 'Ata',
      conteudo: (linha) => (
        <>
          <strong>
            Ata {linha.numero} · {linha.conta_nome}
          </strong>
          <br />
          <span className="texto-fraco">
            {linha.turma_nome ?? 'Turma não informada'} · reunião de {formatarData(linha.data_reuniao)}
          </span>
        </>
      ),
    },
    {
      chave: 'passo',
      rotulo: 'Passo do fluxo',
      conteudo: (linha) => (
        <>
          <Etiqueta tom={linha.status === 'enviada' ? 'verde' : 'marca'} ponto>
            {ROTULO_ATA_STATUS[linha.status]}
          </Etiqueta>
          <br />
          <span className="texto-fraco">{quemFalta(linha)}</span>
        </>
      ),
    },
    {
      chave: 'prazo',
      rotulo: 'Prazo de 24 horas',
      conteudo: (linha) => {
        if (linha.status === 'enviada') {
          return <span className="texto-fraco">Enviada em {formatarData(linha.enviada_em)}</span>
        }
        const horas = horasDeAtraso(linha.prazo_envio)
        if (horas > 0) {
          return (
            <Etiqueta tom="vermelha" ponto>
              {horas} horas de atraso
            </Etiqueta>
          )
        }
        return <span className="texto-fraco">Dentro do prazo, vence em {formatarData(linha.prazo_envio)}</span>
      },
    },
    {
      chave: 'restrita',
      rotulo: 'Restrição',
      conteudo: (linha) =>
        linha.restrita ? (
          <Etiqueta tom="vermelha" ponto>
            Restrita, não é enviada
          </Etiqueta>
        ) : (
          <span className="texto-fraco">Sai para o cliente</span>
        ),
    },
    {
      chave: 'acoes',
      rotulo: 'Ação',
      alinhamento: 'acoes',
      conteudo: (linha) => (
        <Botao tom="contorno" tamanho="p" onClick={() => navegar(`/atas/${linha.id}`)}>
          Abrir a ata
        </Botao>
      ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'BRM de Valor' }, { rotulo: 'Atas' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Conselho · rito da casa</p>
          <h1 className="pagina__titulo">Atas do conselho</h1>
          <p className="pagina__lede">
            O assessor escreve, o conselheiro aprova, o sistema envia. A ata precisa sair em 24
            horas depois da reunião. Ata restrita não é enviada, e isso está dito com todas as
            letras em cada linha desta lista.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      {consulta.data?.deExemplo && avisoAberto ? (
        <Alarme
          tom="amarelo"
          titulo="Dados de exemplo"
          aoFechar={() => setAvisoAberto(false)}
          className="secao"
        >
          {AVISO_SEM_BANCO}
        </Alarme>
      ) : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A lista de atas não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {atrasadas.length > 0 ? (
        <Alarme
          tom="vermelho"
          titulo={`${atrasadas.length} ${atrasadas.length === 1 ? 'ata passou' : 'atas passaram'} das 24 horas`}
          className="secao"
        >
          <ul className="lista-felix">
            {atrasadas.map((ata) => (
              <li key={ata.id}>
                Ata {ata.numero} · {ata.conta_nome} · {horasDeAtraso(ata.prazo_envio)} horas de
                atraso · {quemFalta(ata)}
              </li>
            ))}
          </ul>
        </Alarme>
      ) : null}

      {restritas.length > 0 ? (
        <Alarme
          tom="amarelo"
          titulo={`${restritas.length} ${restritas.length === 1 ? 'ata restrita' : 'atas restritas'} nesta lista`}
          className="secao"
        >
          Reunião que tratou de pessoas do cliente gera ata restrita. Ata restrita não é enviada ao
          cliente, não entra na fila de envio e não aparece para parceiro. O registro fica na casa,
          para o líder tratar diretamente com a conta.
        </Alarme>
      ) : null}

      <section className="secao" aria-labelledby="titulo-filtros-ata">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-filtros-ata">
            Filtros
          </h2>
          <p className="secao__nota">
            {lista.length} de {todas.length} atas em tela.
          </p>
        </div>

        <div className="grade grade--3">
          <Selecao
            rotulo="Conta"
            vazio="Todas as contas"
            value={conta}
            opcoes={contas}
            onChange={(evento) => setConta(evento.target.value)}
          />
          <Selecao
            rotulo="Passo do fluxo"
            vazio="Todos os passos"
            value={status}
            opcoes={(Object.keys(ROTULO_ATA_STATUS) as AtaStatus[]).map((chave) => ({
              valor: chave,
              rotulo: ROTULO_ATA_STATUS[chave],
            }))}
            onChange={(evento) => setStatus(evento.target.value)}
          />
          <Selecao
            rotulo="Prazo"
            vazio="Todas as atas"
            value={somenteAtrasadas}
            opcoes={[{ valor: 'sim', rotulo: 'Somente as que passaram de 24 horas' }]}
            onChange={(evento) => setSomenteAtrasadas(evento.target.value)}
          />
        </div>
      </section>

      <section className="secao" aria-labelledby="titulo-lista-ata">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-lista-ata">
            As atas, da mais recente para a mais antiga
          </h2>
          <p className="secao__nota">
            O passo do fluxo diz quem escreveu, quem aprovou e o que ainda falta.
          </p>
        </div>

        <Cartao semRespiro>
          <Tabela
            colunas={colunas}
            linhas={lista}
            chaveDaLinha={(linha) => linha.id}
            carregando={consulta.isPending}
            legenda="Atas do conselho, com o passo do fluxo, o prazo de 24 horas e a marca de restrita."
            vazioTitulo="Nenhuma ata com estes filtros"
            vazioTexto="Troque a conta, o passo do fluxo ou o prazo para ver outras atas."
            aoEscolherLinha={(linha) => navegar(`/atas/${linha.id}`)}
          />
        </Cartao>
      </section>
    </>
  )
}
