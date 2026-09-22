import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Alarme,
  Botao,
  Campo,
  Carregando,
  Cartao,
  Etiqueta,
  Migalhas,
  Selecao,
  Tabela,
  type ColunaTabela,
  type SentidoOrdem,
  type TomEtiqueta,
} from '@/componentes/indice'
import { useEncontros } from '@/dados/brm'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useSessao } from '@/sessao/contexto'
import {
  ROTULO_FORMATO,
  ROTULO_STATUS_ENCONTRO,
  type BrmStatusEncontro,
  type EncontroNaLista,
} from '@/tipos/brm'
import { data, inteiro } from '@/tipos/rotulos'

/**
 * Encontros do BRM de Valor.
 *
 * A sequência é numerada e a numeração é sagrada: o encontro 2 remarcado
 * continua sendo o encontro 2, com a tentativa registrada e a primeira
 * marcação preservada. Isso é regra da migração 0008, e a tela mostra assim
 * porque é assim que o banco guarda.
 */

const TOM_DA_SITUACAO: Record<BrmStatusEncontro, TomEtiqueta> = {
  previsto: 'marca',
  realizado: 'verde',
  remarcado: 'amarela',
  cancelado: 'vermelha',
}

type ChaveDeOrdem = 'sequencia' | 'tema' | 'data_prevista' | 'data_realizada' | 'situacao'

export function Encontros() {
  const { sessao } = useSessao()
  const navegar = useNavigate()
  const consulta = useEncontros()

  const [avisoAberto, setAvisoAberto] = useState(true)
  const [busca, setBusca] = useState('')
  const [turma, setTurma] = useState('')
  const [situacao, setSituacao] = useState('')
  const [formato, setFormato] = useState('')
  const [ordem, setOrdem] = useState<ChaveDeOrdem>('data_prevista')
  const [sentido, setSentido] = useState<SentidoOrdem>('decrescente')

  const todos = useMemo(() => consulta.data?.encontros ?? [], [consulta.data])

  const turmas = useMemo(
    () => Array.from(new Set(todos.map((encontro) => encontro.turma_codigo))).sort(),
    [todos],
  )

  const filtrados = useMemo(() => {
    const procurado = busca.trim().toLowerCase()

    const lista = todos.filter((encontro) => {
      if (turma && encontro.turma_codigo !== turma) return false
      if (situacao && encontro.status !== situacao) return false
      if (formato && encontro.formato !== formato) return false
      if (!procurado) return true
      return (
        encontro.tema.toLowerCase().includes(procurado) ||
        encontro.turma_codigo.toLowerCase().includes(procurado) ||
        encontro.programa_nome.toLowerCase().includes(procurado) ||
        encontro.conselheiro_nome.toLowerCase().includes(procurado)
      )
    })

    const peso = (encontro: EncontroNaLista): string => {
      switch (ordem) {
        case 'sequencia':
          return `${encontro.turma_codigo}-${String(encontro.numero).padStart(4, '0')}-${encontro.tentativa}`
        case 'tema':
          return encontro.tema.toLowerCase()
        case 'data_realizada':
          return encontro.data_realizada ?? ''
        case 'situacao':
          return encontro.status
        default:
          return `${encontro.data_prevista}-${String(encontro.numero).padStart(4, '0')}`
      }
    }

    return [...lista].sort((a, b) => {
      const comparacao = peso(a).localeCompare(peso(b))
      return sentido === 'crescente' ? comparacao : -comparacao
    })
  }, [todos, busca, turma, situacao, formato, ordem, sentido])

  const remarcados = filtrados.filter((encontro) => encontro.status === 'remarcado').length

  function ordenar(chave: string) {
    const escolhida = chave as ChaveDeOrdem
    if (escolhida === ordem) {
      setSentido((atual) => (atual === 'crescente' ? 'decrescente' : 'crescente'))
      return
    }
    setOrdem(escolhida)
    setSentido('crescente')
  }

  const colunas: Array<ColunaTabela<EncontroNaLista>> = [
    {
      chave: 'sequencia',
      rotulo: 'Encontro',
      alinhamento: 'numero',
      ordenavel: true,
      conteudo: (linha) => (
        <>
          <span className="numero">{linha.numero}</span>
          <br />
          <span className="texto-fraco">
            {linha.tentativa > 1 ? `tentativa ${linha.tentativa}` : 'primeira marcação'}
          </span>
        </>
      ),
    },
    {
      chave: 'turma',
      rotulo: 'Turma',
      conteudo: (linha) => (
        <>
          <strong>{linha.turma_codigo}</strong>
          <br />
          <span className="texto-fraco">{linha.programa_nome}</span>
        </>
      ),
    },
    {
      chave: 'tema',
      rotulo: 'Tema',
      ordenavel: true,
      conteudo: (linha) => (
        <>
          <strong>{linha.tema}</strong>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--esp-1)', marginTop: 'var(--esp-1)' }}>
            {linha.restrito ? <Etiqueta tom="vermelha">Restrito</Etiqueta> : null}
            {linha.eh_pauta_prioritaria ? <Etiqueta tom="realce">Pauta prioritária</Etiqueta> : null}
            {linha.eh_encontro_de_gestao ? <Etiqueta tom="neutra">Encontro de gestão</Etiqueta> : null}
            {linha.eh_hotseat ? <Etiqueta tom="marca">Hotseat</Etiqueta> : null}
          </div>
        </>
      ),
    },
    {
      chave: 'data_prevista',
      rotulo: 'Data prevista',
      ordenavel: true,
      conteudo: (linha) => (
        <>
          {data(linha.data_prevista)}
          {linha.data_prevista_original && linha.data_prevista_original !== linha.data_prevista ? (
            <>
              <br />
              <span className="texto-fraco">
                primeira marcação em {data(linha.data_prevista_original)}
              </span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'data_realizada',
      rotulo: 'Data realizada',
      ordenavel: true,
      conteudo: (linha) =>
        linha.data_realizada ? (
          data(linha.data_realizada)
        ) : (
          <span className="texto-fraco">ainda não</span>
        ),
    },
    {
      chave: 'formato',
      rotulo: 'Formato',
      conteudo: (linha) => (
        <>
          {ROTULO_FORMATO[linha.formato]}
          {linha.eh_presencial_do_mes ? (
            <>
              <br />
              <span className="texto-fraco">presencial do mês</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      ordenavel: true,
      conteudo: (linha) => (
        <Etiqueta tom={TOM_DA_SITUACAO[linha.status]} ponto>
          {ROTULO_STATUS_ENCONTRO[linha.status]}
        </Etiqueta>
      ),
    },
    {
      chave: 'conduziu',
      rotulo: 'Quem conduziu',
      conteudo: (linha) => (
        <>
          {linha.conselheiro_nome}
          <br />
          <span className="texto-fraco">apoio de {linha.assessor_nome}</span>
        </>
      ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'BRM de Valor' }, { rotulo: 'Encontros' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">BRM de Valor · {sessao.inquilino_nome}</p>
          <h1 className="pagina__titulo">Encontros</h1>
          <p className="pagina__lede">
            A sequência oficial de cada turma, com tema, data prevista e realizada, formato,
            situação e quem conduziu. Escolha uma linha para abrir a ficha do encontro.
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

      {consulta.isPending ? <Carregando texto="Carregando os encontros" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="Os encontros não carregaram">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <section className="secao" aria-labelledby="titulo-lista-encontros">
          <div className="secao__topo">
            <h2 className="secao__titulo" id="titulo-lista-encontros">
              A sequência dos encontros
            </h2>
            <p className="secao__nota">
              {inteiro(filtrados.length)} de {inteiro(todos.length)} encontros com os filtros
              atuais.
            </p>
          </div>

          <Alarme tom="informacao" titulo="A remarcação não perde a numeração" className="secao">
            O encontro 2 remarcado continua sendo o encontro 2. O que muda é a tentativa, e a data
            da primeira marcação fica registrada ao lado da nova.{' '}
            {remarcados > 0
              ? `Há ${inteiro(remarcados)} ${remarcados === 1 ? 'encontro remarcado' : 'encontros remarcados'} nesta lista.`
              : 'Nenhum encontro remarcado nesta lista.'}
          </Alarme>

          <Cartao className="secao">
            <div className="grade grade--4">
              <Campo
                rotulo="Buscar"
                placeholder="Tema, turma, programa ou quem conduziu"
                value={busca}
                onChange={(evento) => setBusca(evento.target.value)}
              />
              <Selecao
                rotulo="Turma"
                vazio="Todas as turmas"
                value={turma}
                onChange={(evento) => setTurma(evento.target.value)}
                opcoes={turmas.map((codigo) => ({ valor: codigo, rotulo: codigo }))}
              />
              <Selecao
                rotulo="Situação"
                vazio="Todas as situações"
                value={situacao}
                onChange={(evento) => setSituacao(evento.target.value)}
                opcoes={Object.entries(ROTULO_STATUS_ENCONTRO).map(([valor, rotulo]) => ({
                  valor,
                  rotulo,
                }))}
              />
              <Selecao
                rotulo="Formato"
                vazio="Todos os formatos"
                value={formato}
                onChange={(evento) => setFormato(evento.target.value)}
                opcoes={Object.entries(ROTULO_FORMATO).map(([valor, rotulo]) => ({
                  valor,
                  rotulo,
                }))}
              />
            </div>
          </Cartao>

          <Cartao semRespiro>
            <Tabela
              colunas={colunas}
              linhas={filtrados}
              chaveDaLinha={(linha) => linha.id}
              legenda="Encontros com número da sequência oficial, tentativa, tema, datas, formato, situação e condução."
              ordenadaPor={ordem}
              sentido={sentido}
              aoOrdenar={ordenar}
              aoEscolherLinha={(linha) => navegar(`/encontros/${linha.id}`)}
              vazioTitulo="Nenhum encontro com estes filtros"
              vazioTexto="Afrouxe a busca, a turma, a situação ou o formato para ver mais."
            />
          </Cartao>
        </section>
      ) : null}
    </>
  )
}
