import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Alarme,
  Botao,
  BotaoIA,
  CampoTexto,
  Cartao,
  Etiqueta,
  Migalhas,
  Modal,
  Selecao,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { fecharPendencia, hojeISO, usePendencias } from '@/dados/governanca'
import type { PendenciaNaLista, PendenciaStatus } from '@/tipos/governanca'
import {
  ROTULO_PENDENCIA_ORIGEM,
  ROTULO_PENDENCIA_STATUS,
  situacaoDaPendencia,
} from '@/tipos/governanca'
import { data as formatarData, inteiro } from '@/tipos/rotulos'

/**
 * Pendências do conselho.
 *
 * Uma pendência nunca some. Ela nasce de uma deliberação ou de um próximo
 * passo da ata, reaparece na pré-pauta de toda reunião seguinte, e sai da fila
 * quando alguém escreve a evidência que comprova a conclusão. Cancelar também
 * é registro, não sumiço.
 */
export function Pendencias() {
  const consulta = usePendencias()
  const [conta, setConta] = useState('')
  const [turma, setTurma] = useState('')
  const [dono, setDono] = useState('')
  const [atraso, setAtraso] = useState('')
  const [emFoco, setEmFoco] = useState<PendenciaNaLista | null>(null)

  const todas = useMemo(() => consulta.data?.dados ?? [], [consulta.data])
  const hoje = hojeISO()

  const opcoes = useMemo(() => {
    const contas = new Map<string, string>()
    const turmas = new Map<string, string>()
    const donos = new Set<string>()

    for (const pendencia of todas) {
      contas.set(pendencia.conta_id, pendencia.conta_nome)
      if (pendencia.turma_id) {
        turmas.set(pendencia.turma_id, pendencia.turma_nome ?? pendencia.turma_id)
      }
      donos.add(pendencia.dono)
    }

    return {
      contas: [...contas.entries()].map(([valor, rotulo]) => ({ valor, rotulo })),
      turmas: [...turmas.entries()].map(([valor, rotulo]) => ({ valor, rotulo })),
      donos: [...donos].sort().map((nome) => ({ valor: nome, rotulo: nome })),
    }
  }, [todas])

  const lista = useMemo(
    () =>
      todas.filter((pendencia) => {
        if (conta && pendencia.conta_id !== conta) return false
        if (turma && pendencia.turma_id !== turma) return false
        if (dono && pendencia.dono !== dono) return false
        if (atraso === 'atrasadas') {
          const emAberto = pendencia.status === 'aberta' || pendencia.status === 'em_andamento'
          if (!emAberto || situacaoDaPendencia(pendencia.prazo, hoje) !== 'atrasada') return false
        }
        if (atraso === 'abertas' && pendencia.status !== 'aberta' && pendencia.status !== 'em_andamento') {
          return false
        }
        if (atraso === 'concluidas' && pendencia.status !== 'concluida') return false
        return true
      }),
    [todas, conta, turma, dono, atraso, hoje],
  )

  const emAberto = todas.filter(
    (pendencia) => pendencia.status === 'aberta' || pendencia.status === 'em_andamento',
  )
  const atrasadas = emAberto.filter(
    (pendencia) => situacaoDaPendencia(pendencia.prazo, hoje) === 'atrasada',
  )
  const semPrazo = emAberto.filter((pendencia) => !pendencia.prazo)

  const colunas: Array<ColunaTabela<PendenciaNaLista>> = [
    {
      chave: 'descricao',
      rotulo: 'Pendência',
      conteudo: (linha) => (
        <>
          <strong>{linha.descricao}</strong>
          <br />
          <span className="texto-fraco">
            {linha.conta_nome} · {linha.turma_nome ?? 'Turma não informada'}
          </span>
        </>
      ),
    },
    { chave: 'dono', rotulo: 'Dono', conteudo: (linha) => linha.dono },
    {
      chave: 'prazo',
      rotulo: 'Prazo',
      conteudo: (linha) => {
        const situacao = situacaoDaPendencia(linha.prazo, hoje)
        const emFila = linha.status === 'aberta' || linha.status === 'em_andamento'
        return (
          <>
            {formatarData(linha.prazo)}
            <br />
            {emFila ? (
              <Etiqueta
                tom={situacao === 'atrasada' ? 'vermelha' : situacao === 'no prazo' ? 'verde' : 'amarela'}
                ponto
              >
                {situacao === 'atrasada'
                  ? 'Atrasada'
                  : situacao === 'no prazo'
                    ? 'No prazo'
                    : 'Sem prazo definido'}
              </Etiqueta>
            ) : (
              <span className="texto-fraco">Fora da fila de cobrança</span>
            )}
          </>
        )
      },
    },
    {
      chave: 'origem',
      rotulo: 'Origem na ata',
      conteudo: (linha) => (
        <>
          {ROTULO_PENDENCIA_ORIGEM[linha.origem]}
          <br />
          {linha.ata_id ? (
            <Link className="migalhas__elo" to={`/atas/${linha.ata_id}`}>
              Ata {linha.ata_numero ?? 'sem número'}
              {linha.ata_secao ? ` · seção ${linha.ata_secao}` : ''}
            </Link>
          ) : (
            <span className="texto-fraco">Sem ata de origem registrada</span>
          )}
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <>
          <Etiqueta
            tom={
              linha.status === 'concluida'
                ? 'verde'
                : linha.status === 'cancelada'
                  ? 'neutra'
                  : 'amarela'
            }
            ponto
          >
            {ROTULO_PENDENCIA_STATUS[linha.status]}
          </Etiqueta>
          {linha.reaparece_na_pauta && (linha.status === 'aberta' || linha.status === 'em_andamento') ? (
            <>
              <br />
              <span className="texto-fraco">Reaparece na pré-pauta até fechar</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'evidencia',
      rotulo: 'Evidência de conclusão',
      conteudo: (linha) =>
        linha.evidencia ? (
          <>
            {linha.evidencia}
            <br />
            <span className="texto-fraco">Concluída em {formatarData(linha.concluida_em)}</span>
          </>
        ) : (
          <span className="texto-fraco">Ainda sem evidência</span>
        ),
    },
    {
      chave: 'acoes',
      rotulo: 'Ação',
      alinhamento: 'acoes',
      conteudo: (linha) =>
        linha.status === 'aberta' || linha.status === 'em_andamento' ? (
          <Botao tom="contorno" tamanho="p" onClick={() => setEmFoco(linha)}>
            Fechar com evidência
          </Botao>
        ) : (
          <span className="texto-fraco">Fechada</span>
        ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'Governança' }, { rotulo: 'Pendências' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Governança · o que reaparece até fechar</p>
          <h1 className="pagina__titulo">Pendências</h1>
          <p className="pagina__lede">
            Uma pendência nunca some da plataforma. Ela volta na pré-pauta de toda reunião, com dono
            e prazo, e só sai da fila quando alguém escreve a evidência que comprova a conclusão.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      {consulta.data?.deExemplo ? (
        <Alarme tom="amarelo" titulo="Dados de exemplo" className="secao">
          {AVISO_SEM_BANCO}
        </Alarme>
      ) : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A lista de pendências não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      <section className="secao" aria-labelledby="titulo-placar-pendencia">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-placar-pendencia">
            O placar da cobrança
          </h2>
          <p className="secao__nota">Data de referência do atraso: {formatarData(hoje)}.</p>
        </div>

        <div className="grade grade--3">
          <Cartao titulo="Em aberto" tom="marca">
            <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
              {inteiro(emAberto.length)}
            </p>
            <p className="texto-fraco">Abertas e em andamento, que voltam na pré-pauta.</p>
          </Cartao>
          <Cartao titulo="Atrasadas" tom={atrasadas.length > 0 ? 'realce' : 'simples'}>
            <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
              {inteiro(atrasadas.length)}
            </p>
            <p className="texto-fraco">Com prazo vencido diante da data de hoje.</p>
          </Cartao>
          <Cartao titulo="Sem prazo definido">
            <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
              {inteiro(semPrazo.length)}
            </p>
            <p className="texto-fraco">
              Pendência sem prazo cobra pouco. Combine a data na próxima reunião.
            </p>
          </Cartao>
        </div>
      </section>

      <section className="secao" aria-labelledby="titulo-filtros-pendencia">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-filtros-pendencia">
            Filtros
          </h2>
          <p className="secao__nota">
            {inteiro(lista.length)} de {inteiro(todas.length)} pendências em tela.
          </p>
        </div>

        <div className="grade grade--4">
          <Selecao
            rotulo="Turma"
            vazio="Todas as turmas"
            value={turma}
            opcoes={opcoes.turmas}
            onChange={(evento) => setTurma(evento.target.value)}
          />
          <Selecao
            rotulo="Conta"
            vazio="Todas as contas"
            value={conta}
            opcoes={opcoes.contas}
            onChange={(evento) => setConta(evento.target.value)}
          />
          <Selecao
            rotulo="Dono"
            vazio="Todos os donos"
            value={dono}
            opcoes={opcoes.donos}
            onChange={(evento) => setDono(evento.target.value)}
          />
          <Selecao
            rotulo="Situação"
            vazio="Todas as situações"
            value={atraso}
            opcoes={[
              { valor: 'atrasadas', rotulo: 'Somente as atrasadas' },
              { valor: 'abertas', rotulo: 'Somente as em aberto' },
              { valor: 'concluidas', rotulo: 'Somente as concluídas' },
            ]}
            onChange={(evento) => setAtraso(evento.target.value)}
          />
        </div>
      </section>

      <section className="secao" aria-labelledby="titulo-lista-pendencia">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-lista-pendencia">
            A lista inteira
          </h2>
          <p className="secao__nota">
            Descrição, dono, prazo, origem na ata, situação e evidência de conclusão.
          </p>
        </div>

        <Cartao semRespiro>
          <Tabela
            colunas={colunas}
            linhas={lista}
            chaveDaLinha={(linha) => linha.id}
            carregando={consulta.isPending}
            legenda="Pendências do conselho, com dono, prazo, origem na ata e evidência."
            vazioTitulo="Nenhuma pendência com estes filtros"
            vazioTexto="Troque a turma, a conta, o dono ou a situação para ver outras pendências."
          />
        </Cartao>
      </section>

      <JanelaDeConclusao
        pendencia={emFoco}
        aoFechar={() => setEmFoco(null)}
        aoConcluir={() => {
          setEmFoco(null)
          void consulta.refetch()
        }}
      />
    </>
  )
}

// ------------------------------------------------- concluir com evidência

function JanelaDeConclusao({
  pendencia,
  aoFechar,
  aoConcluir,
}: {
  pendencia: PendenciaNaLista | null
  aoFechar: () => void
  aoConcluir: () => void
}) {
  const [evidencia, setEvidencia] = useState('')
  const [gravando, setGravando] = useState(false)
  const [erro, setErro] = useState('')
  const [recado, setRecado] = useState('')

  async function concluir() {
    if (!pendencia) return
    setGravando(true)
    setErro('')
    setRecado('')
    try {
      const onde = await fecharPendencia(pendencia.id, evidencia)
      if (onde === 'banco') {
        setEvidencia('')
        aoConcluir()
        return
      }
      setRecado(
        'Sem banco ligado nesta máquina, a conclusão não é gravada. A evidência escrita aqui '
        + 'serve só de ensaio da tela.',
      )
    } catch (falha) {
      setErro(falha instanceof Error ? falha.message : 'Não foi possível fechar a pendência.')
    } finally {
      setGravando(false)
    }
  }

  const status: PendenciaStatus | null = pendencia?.status ?? null

  return (
    <Modal
      aberto={pendencia !== null}
      aoFechar={() => {
        setEvidencia('')
        setErro('')
        setRecado('')
        aoFechar()
      }}
      titulo="Fechar a pendência com evidência"
      legenda="Sem evidência escrita, a pendência continua voltando na pré-pauta."
      fechaNoFundo={false}
      rodape={
        <>
          <Botao
            tom="principal"
            carregando={gravando}
            disabled={evidencia.trim().length === 0}
            onClick={() => void concluir()}
          >
            Fechar com esta evidência
          </Botao>
          <Botao
            tom="contorno"
            onClick={() => {
              setEvidencia('')
              setErro('')
              setRecado('')
              aoFechar()
            }}
          >
            Voltar
          </Botao>
        </>
      }
    >
      {pendencia ? (
        <>
          <p>
            <strong>{pendencia.descricao}</strong>
          </p>
          <p className="texto-fraco" style={{ marginTop: 'var(--esp-2)' }}>
            {pendencia.conta_nome} · dono {pendencia.dono} · prazo {formatarData(pendencia.prazo)} ·{' '}
            {status ? ROTULO_PENDENCIA_STATUS[status] : 'Sem situação'}
          </p>

          {erro ? (
            <Alarme tom="vermelho" titulo="Não deu para fechar" className="secao">
              {erro}
            </Alarme>
          ) : null}

          {recado ? (
            <Alarme tom="amarelo" titulo="Nada foi gravado" className="secao">
              {recado}
            </Alarme>
          ) : null}

          <div className="secao">
            <CampoTexto
              multiplas_linhas
              rotulo="Evidência de conclusão"
              obrigatorio
              rows={5}
              value={evidencia}
              valorAtual={evidencia}
              onChange={(evento) => setEvidencia(evento.target.value)}
              auxilio="O que comprova que isto foi feito: documento, registro, decisão em ata, número entregue."
              acessorio={
                <BotaoIA
                  campo="texto_livre"
                  rotulo="Sugerir redação"
                  textoAtual={evidencia}
                  contexto={{ pendencia: pendencia.descricao, dono: pendencia.dono }}
                  aoAceitar={(texto) => setEvidencia(texto)}
                />
              }
            />
          </div>
        </>
      ) : null}
    </Modal>
  )
}
