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
  type TomEtiqueta,
} from '@/componentes/indice'
import { useTurmas } from '@/dados/brm'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useSessao } from '@/sessao/contexto'
import {
  ROTULO_CADENCIA,
  ROTULO_FORMATO,
  ROTULO_MODALIDADE_TURMA,
  ROTULO_STATUS_TURMA,
  type BrmStatusTurma,
  type TurmaNaLista,
} from '@/tipos/brm'
import { data, inteiro, periodo } from '@/tipos/rotulos'

/**
 * Turmas do BRM de Valor.
 *
 * A turma é o grupo que percorre o programa. A lista traz código, capacidade
 * de cadeiras, cadeiras ocupadas, período e situação, e diz de relance quando
 * a turma ainda está abaixo do piso ou já bateu no teto.
 */

const TOM_DA_SITUACAO: Record<BrmStatusTurma, TomEtiqueta> = {
  planejada: 'marca',
  em_andamento: 'verde',
  suspensa: 'amarela',
  concluida: 'neutra',
  cancelada: 'vermelha',
}

export function Turmas() {
  const { sessao } = useSessao()
  const navegar = useNavigate()
  const consulta = useTurmas()

  const [avisoAberto, setAvisoAberto] = useState(true)
  const [busca, setBusca] = useState('')
  const [modalidade, setModalidade] = useState('')
  const [situacao, setSituacao] = useState('')

  const todas = useMemo(() => consulta.data?.turmas ?? [], [consulta.data])

  const filtradas = useMemo(() => {
    const procurado = busca.trim().toLowerCase()
    return todas.filter((turma) => {
      if (modalidade && turma.modalidade !== modalidade) return false
      if (situacao && turma.status !== situacao) return false
      if (!procurado) return true
      return (
        turma.codigo.toLowerCase().includes(procurado) ||
        (turma.nome ?? '').toLowerCase().includes(procurado) ||
        turma.programa_nome.toLowerCase().includes(procurado) ||
        turma.contas.some((conta) => conta.conta_nome.toLowerCase().includes(procurado))
      )
    })
  }, [todas, busca, modalidade, situacao])

  const compartilhadas = filtradas.filter((turma) => turma.modalidade === 'compartilhada').length

  const colunas: Array<ColunaTabela<TurmaNaLista>> = [
    {
      chave: 'codigo',
      rotulo: 'Código',
      conteudo: (linha) => (
        <>
          <strong>{linha.codigo}</strong>
          <br />
          <span className="texto-fraco">{linha.nome ?? linha.programa_nome}</span>
        </>
      ),
    },
    {
      chave: 'programa',
      rotulo: 'Programa',
      conteudo: (linha) => (
        <>
          {linha.programa_nome}
          <br />
          <Etiqueta tom={linha.modalidade === 'compartilhada' ? 'realce' : 'marca'}>
            {ROTULO_MODALIDADE_TURMA[linha.modalidade]}
          </Etiqueta>
        </>
      ),
    },
    {
      chave: 'contas',
      rotulo: 'Contas na turma',
      conteudo: (linha) =>
        linha.contas.length === 0 ? (
          <span className="texto-fraco">nenhuma conta registrada</span>
        ) : (
          <>
            <span className="numero">{inteiro(linha.contas.length)}</span>{' '}
            <span className="texto-fraco">
              {linha.contas.length === 1 ? 'conta' : 'contas diferentes'}
            </span>
            <br />
            <span className="texto-fraco">
              {linha.contas.map((conta) => conta.conta_nome).join(' · ')}
            </span>
          </>
        ),
    },
    {
      chave: 'cadeiras',
      rotulo: 'Cadeiras',
      alinhamento: 'numero',
      conteudo: (linha) => <Cadeiras turma={linha} />,
    },
    {
      chave: 'periodo',
      rotulo: 'Período',
      conteudo: (linha) =>
        linha.data_inicio && linha.data_fim ? (
          periodo(linha.data_inicio, linha.data_fim)
        ) : linha.data_inicio ? (
          <>a partir de {data(linha.data_inicio)}</>
        ) : (
          <span className="texto-fraco">período a definir</span>
        ),
    },
    {
      chave: 'conducao',
      rotulo: 'Condução',
      conteudo: (linha) => (
        <>
          {linha.facilitador_nome}
          <br />
          <span className="texto-fraco">
            {ROTULO_CADENCIA[linha.cadencia]} · {ROTULO_FORMATO[linha.formato]}
          </span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta tom={TOM_DA_SITUACAO[linha.status]} ponto>
          {ROTULO_STATUS_TURMA[linha.status]}
        </Etiqueta>
      ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'BRM de Valor' }, { rotulo: 'Turmas' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">BRM de Valor · {sessao.inquilino_nome}</p>
          <h1 className="pagina__titulo">Turmas</h1>
          <p className="pagina__lede">
            A turma é o grupo que percorre o programa. Cada linha traz o código, o piso e o teto de
            cadeiras, quantas cadeiras estão de fato ocupadas, o período e a situação. Escolha uma
            linha para abrir a ficha.
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

      {consulta.isPending ? <Carregando texto="Carregando as turmas" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="As turmas não carregaram">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <section className="secao" aria-labelledby="titulo-lista-turmas">
          <div className="secao__topo">
            <h2 className="secao__titulo" id="titulo-lista-turmas">
              As turmas em curso e por começar
            </h2>
            <p className="secao__nota">
              {inteiro(filtradas.length)} de {inteiro(todas.length)} turmas ·{' '}
              {inteiro(compartilhadas)} compartilhadas, que reúnem contas diferentes na mesma sala.
            </p>
          </div>

          <Cartao className="secao">
            <div className="grade grade--3">
              <Campo
                rotulo="Buscar"
                placeholder="Código, turma, programa ou conta"
                value={busca}
                onChange={(evento) => setBusca(evento.target.value)}
              />
              <Selecao
                rotulo="Modalidade"
                vazio="Todas as modalidades"
                value={modalidade}
                onChange={(evento) => setModalidade(evento.target.value)}
                opcoes={[
                  { valor: 'dedicada', rotulo: ROTULO_MODALIDADE_TURMA.dedicada },
                  { valor: 'compartilhada', rotulo: ROTULO_MODALIDADE_TURMA.compartilhada },
                ]}
              />
              <Selecao
                rotulo="Situação"
                vazio="Todas as situações"
                value={situacao}
                onChange={(evento) => setSituacao(evento.target.value)}
                opcoes={Object.entries(ROTULO_STATUS_TURMA).map(([valor, rotulo]) => ({
                  valor,
                  rotulo,
                }))}
              />
            </div>
          </Cartao>

          <Cartao semRespiro>
            <Tabela
              colunas={colunas}
              linhas={filtradas}
              chaveDaLinha={(linha) => linha.id}
              legenda="Turmas com código, contas, cadeiras ocupadas sobre a capacidade, período e situação."
              aoEscolherLinha={(linha) => navegar(`/turmas/${linha.id}`)}
              vazioTitulo="Nenhuma turma com estes filtros"
              vazioTexto="Afrouxe a busca, a modalidade ou a situação para ver mais."
            />
          </Cartao>
        </section>
      ) : null}
    </>
  )
}

// ------------------------------------------------- cadeiras ocupadas na turma

/**
 * Cadeiras ocupadas contra a capacidade contratada. O piso vale no momento de
 * começar, o teto vale sempre, e as duas leituras aparecem juntas.
 */
function Cadeiras({ turma }: { turma: TurmaNaLista }) {
  const teto = Math.max(1, turma.cadeiras_maximas)
  const proporcao = Math.min(100, Math.round((turma.cadeiras_ocupadas / teto) * 100))
  const abaixoDoPiso = turma.cadeiras_ocupadas < turma.cadeiras_minimas
  const noTeto = turma.cadeiras_ocupadas >= turma.cadeiras_maximas

  return (
    <div style={{ display: 'grid', gap: 'var(--esp-1)', justifyItems: 'end' }}>
      <span>
        <span className="numero">{inteiro(turma.cadeiras_ocupadas)}</span>{' '}
        <span className="texto-fraco">
          ocupadas · de {turma.cadeiras_minimas} a {turma.cadeiras_maximas}
        </span>
      </span>

      <span
        role="img"
        aria-label={`${turma.cadeiras_ocupadas} cadeiras ocupadas de um teto de ${turma.cadeiras_maximas}.`}
        style={{
          display: 'block',
          width: '100%',
          minWidth: '96px',
          height: '6px',
          borderRadius: 'var(--raio-pilula)',
          background: 'var(--cor-linha)',
          overflow: 'hidden',
        }}
      >
        <span
          style={{
            display: 'block',
            height: '100%',
            width: `${proporcao}%`,
            background: abaixoDoPiso ? 'var(--cor-amarelo)' : 'var(--cor-marca)',
          }}
        />
      </span>

      {abaixoDoPiso ? (
        <Etiqueta tom="amarela">Abaixo do piso de cadeiras</Etiqueta>
      ) : noTeto ? (
        <Etiqueta tom="verde">Turma no teto de cadeiras</Etiqueta>
      ) : null}
    </div>
  )
}
