import { Fragment, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import {
  Abas,
  Alarme,
  Botao,
  Carregando,
  Cartao,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Selecao,
  Tabela,
  type Aba,
  type ColunaTabela,
  type TomEtiqueta,
} from '@/componentes/indice'
import { useTurma, type FichaDaTurma } from '@/dados/brm'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import {
  EXPLICACAO_MODALIDADE,
  ROTULO_CADENCIA,
  ROTULO_FORMATO,
  ROTULO_MODALIDADE_TURMA,
  ROTULO_PAPEL_PARTICIPANTE,
  ROTULO_STATUS_ENCONTRO,
  ROTULO_STATUS_ENTREGAVEL,
  ROTULO_STATUS_PARTICIPANTE,
  ROTULO_STATUS_TURMA,
  ROTULO_TIPO_ENTREGAVEL,
  ROTULO_VISIBILIDADE,
  competencia,
  presencaEmPorCento,
  type BrmStatusEncontro,
  type BrmStatusEntregavel,
  type DiaDoCalendario,
  type EncontroNaLista,
  type EntregavelNaLista,
  type ParticipanteNaFicha,
  type RegistroHistoricoNaFicha,
  type TurmaConta,
} from '@/tipos/brm'
import { data, dataPorExtenso, inteiro, periodo } from '@/tipos/rotulos'

/**
 * Ficha da turma.
 *
 * Cinco abas: Participantes, Calendário, Encontros, Entregáveis e Histórico de
 * Valor. Duas coisas esta tela precisa deixar óbvias, e por isso elas têm
 * destaque próprio: a turma compartilhada reúne contas diferentes, então a
 * conta de cada participante aparece na lista; e o calendário do conselho tem
 * recesso, então o salto de meados de dezembro a meados de janeiro é marcado
 * na cara, para não parecer erro de registro.
 */

const TOM_DO_ENCONTRO: Record<BrmStatusEncontro, TomEtiqueta> = {
  previsto: 'marca',
  realizado: 'verde',
  remarcado: 'amarela',
  cancelado: 'vermelha',
}

const TOM_DO_ENTREGAVEL: Record<BrmStatusEntregavel, TomEtiqueta> = {
  rascunho: 'neutra',
  entregue: 'marca',
  aprovado: 'verde',
}

export function Turma() {
  const { turmaId } = useParams<{ turmaId: string }>()
  const consulta = useTurma(turmaId)
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [aba, setAba] = useState('participantes')

  const ficha = consulta.data?.ficha ?? null

  const abas: Aba[] = ficha
    ? [
        {
          chave: 'participantes',
          rotulo: 'Participantes',
          contagem: ficha.participantes.length,
          conteudo: <AbaParticipantes ficha={ficha} />,
        },
        {
          chave: 'calendario',
          rotulo: 'Calendário',
          contagem: ficha.calendario.length,
          conteudo: <AbaCalendario ficha={ficha} />,
        },
        {
          chave: 'encontros',
          rotulo: 'Encontros',
          contagem: ficha.encontros.length,
          conteudo: <AbaEncontros ficha={ficha} />,
        },
        {
          chave: 'entregaveis',
          rotulo: 'Entregáveis',
          contagem: ficha.entregaveis.length,
          conteudo: <AbaEntregaveis ficha={ficha} />,
        },
        {
          chave: 'historico',
          rotulo: 'Histórico de Valor',
          contagem: ficha.historico.length,
          conteudo: <AbaHistorico ficha={ficha} />,
        },
      ]
    : []

  return (
    <>
      <Migalhas
        itens={[
          { rotulo: 'BRM de Valor' },
          { rotulo: 'Turmas', para: '/turmas' },
          { rotulo: ficha?.turma.codigo ?? 'Turma' },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">
            {ficha ? `${ficha.turma.programa_nome} · ${ficha.turma.programa_codigo}` : 'Turma'}
          </p>
          <h1 className="pagina__titulo">{ficha?.turma.codigo ?? 'Ficha da turma'}</h1>
          {ficha ? (
            <p className="pagina__lede">
              {ficha.turma.nome ?? ficha.turma.programa_nome} ·{' '}
              {EXPLICACAO_MODALIDADE[ficha.turma.modalidade]}
            </p>
          ) : null}
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Link className="botao botao--contorno" to="/turmas">
            Voltar às turmas
          </Link>
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

      {consulta.isPending ? <Carregando texto="Abrindo a ficha da turma" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A ficha não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data && !ficha && !consulta.isPending ? (
        <Cartao>
          <EstadoVazio
            titulo="Turma não encontrada"
            texto="Nenhuma turma viva responde por este endereço. Ou ela foi arquivada, ou a política de linha não entregou esta turma para quem está na sessão."
            acoes={
              <Link className="botao botao--principal" to="/turmas">
                Ir para a lista de turmas
              </Link>
            }
          />
        </Cartao>
      ) : null}

      {ficha ? (
        <>
          <ResumoDaTurma ficha={ficha} />
          <section className="secao" aria-labelledby="titulo-abas-turma">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-abas-turma">
                A turma por dentro
              </h2>
              <p className="secao__nota">
                Quem senta na turma, que datas ela tem, o que já aconteceu, o que foi produzido e o
                valor registrado por trimestre.
              </p>
            </div>
            <Abas abas={abas} ativa={aba} aoTrocar={setAba} rotulo="Seções da ficha da turma" />
          </section>
        </>
      ) : null}
    </>
  )
}

// ------------------------------------------------------- resumo do topo

function ResumoDaTurma({ ficha }: { ficha: FichaDaTurma }) {
  const turma = ficha.turma
  const previstos = turma.encontros_previstos ?? ficha.encontros.length
  const proximo = ficha.encontros
    .filter((encontro) => encontro.status === 'previsto')
    .sort((a, b) => a.data_prevista.localeCompare(b.data_prevista))[0]

  return (
    <section className="secao" aria-labelledby="titulo-resumo-turma">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-resumo-turma">
          A turma de relance
        </h2>
        <p className="secao__nota">
          {ROTULO_CADENCIA[turma.cadencia]} · {ROTULO_FORMATO[turma.formato]} ·{' '}
          {turma.horario_inicio && turma.horario_fim
            ? `das ${turma.horario_inicio} às ${turma.horario_fim}`
            : 'horário a definir'}{' '}
          · condução de {turma.facilitador_nome}
        </p>
      </div>

      <div className="grade grade--4">
        <Cartao tom="marca">
          <p className="kicker">Situação</p>
          <p style={{ marginTop: 'var(--esp-2)' }}>
            <Etiqueta
              tom={turma.status === 'em_andamento' ? 'verde' : 'marca'}
              ponto
            >
              {ROTULO_STATUS_TURMA[turma.status]}
            </Etiqueta>
          </p>
          <p className="texto-fraco" style={{ marginTop: 'var(--esp-2)' }}>
            {turma.data_inicio && turma.data_fim
              ? periodo(turma.data_inicio, turma.data_fim)
              : 'período a definir'}
          </p>
        </Cartao>

        <Cartao>
          <p className="kicker">Cadeiras ocupadas</p>
          <p className="numero" style={{ fontSize: 'var(--texto-2xg)', marginTop: 'var(--esp-2)' }}>
            {inteiro(turma.cadeiras_ocupadas)}
          </p>
          <p className="texto-fraco">
            de {turma.cadeiras_minimas} a {turma.cadeiras_maximas} cadeiras contratáveis
          </p>
        </Cartao>

        <Cartao>
          <p className="kicker">Encontros</p>
          <p className="numero" style={{ fontSize: 'var(--texto-2xg)', marginTop: 'var(--esp-2)' }}>
            {inteiro(turma.encontros_realizados)}
          </p>
          <p className="texto-fraco">
            realizados de {inteiro(previstos)} previstos ·{' '}
            {proximo ? `próximo em ${data(proximo.data_prevista)}` : 'nenhum encontro previsto'}
          </p>
        </Cartao>

        <Cartao tom={turma.modalidade === 'compartilhada' ? 'realce' : 'plano'}>
          <p className="kicker">Modalidade</p>
          <p style={{ marginTop: 'var(--esp-2)' }}>
            <Etiqueta tom={turma.modalidade === 'compartilhada' ? 'realce' : 'marca'}>
              {ROTULO_MODALIDADE_TURMA[turma.modalidade]}
            </Etiqueta>
          </p>
          <p className="texto-fraco" style={{ marginTop: 'var(--esp-2)' }}>
            {inteiro(turma.contas.length)}{' '}
            {turma.contas.length === 1 ? 'conta na turma' : 'contas diferentes na mesma turma'}
          </p>
        </Cartao>
      </div>
    </section>
  )
}

// ------------------------------------------------------------ participantes

function AbaParticipantes({ ficha }: { ficha: FichaDaTurma }) {
  const compartilhada = ficha.turma.modalidade === 'compartilhada'

  const colunasDeConta: Array<ColunaTabela<TurmaConta>> = [
    {
      chave: 'conta',
      rotulo: 'Conta',
      conteudo: (linha) => (
        <>
          <strong>{linha.conta_nome}</strong>
          {linha.eh_anfitria ? (
            <>
              {' '}
              <Etiqueta tom="realce">Anfitriã</Etiqueta>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'contratadas',
      rotulo: 'Cadeiras contratadas',
      alinhamento: 'numero',
      conteudo: (linha) => <span className="numero">{inteiro(linha.cadeiras_contratadas)}</span>,
    },
    {
      chave: 'ocupadas',
      rotulo: 'Cadeiras ocupadas',
      alinhamento: 'numero',
      conteudo: (linha) => (
        <span className="numero">
          {inteiro(
            ficha.participantes.filter(
              (pessoa) => pessoa.conta_id === linha.conta_id && pessoa.status !== 'desligado',
            ).length,
          )}
        </span>
      ),
    },
    {
      chave: 'entrada',
      rotulo: 'Entrou em',
      conteudo: (linha) => data(linha.entrou_em),
    },
  ]

  const colunas: Array<ColunaTabela<ParticipanteNaFicha>> = [
    {
      chave: 'cadeira',
      rotulo: 'Cadeira',
      alinhamento: 'numero',
      conteudo: (linha) => (
        <span className="numero">{linha.cadeira === null ? 'sem cadeira' : linha.cadeira}</span>
      ),
    },
    {
      chave: 'pessoa',
      rotulo: 'Participante',
      conteudo: (linha) => <strong>{linha.nome_exibido}</strong>,
    },
    {
      chave: 'conta',
      rotulo: 'Conta',
      conteudo: (linha) => <Etiqueta tom="marca">{linha.conta_nome}</Etiqueta>,
    },
    {
      chave: 'papel',
      rotulo: 'Papel',
      conteudo: (linha) => ROTULO_PAPEL_PARTICIPANTE[linha.papel],
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta tom={linha.status === 'ativo' ? 'verde' : 'neutra'} ponto>
          {ROTULO_STATUS_PARTICIPANTE[linha.status]}
        </Etiqueta>
      ),
    },
    {
      chave: 'presenca',
      rotulo: 'Presença',
      alinhamento: 'numero',
      conteudo: (linha) => (
        <>
          <span className="numero">
            {inteiro(linha.encontros_presentes)} de {inteiro(linha.encontros_convocados)}
          </span>
          <br />
          <span className="texto-fraco">{presencaEmPorCento(linha.presenca_percentual)}</span>
        </>
      ),
    },
    {
      chave: 'entrada',
      rotulo: 'Entrou em',
      conteudo: (linha) => data(linha.entrou_em),
    },
  ]

  return (
    <>
      {compartilhada ? (
        <Alarme tom="informacao" titulo="Esta turma é compartilhada" className="secao">
          A turma reúne contas diferentes, de mercados distintos. A coluna Conta diz de quem é cada
          cadeira, porque num conselho compartilhado quem senta ao lado não é sócio do vizinho.
        </Alarme>
      ) : null}

      <Cartao
        titulo="Contas na turma"
        legenda="Quantas cadeiras cada conta contratou e quantas de fato ocupou."
        semRespiro
        className="secao"
      >
        <Tabela
          colunas={colunasDeConta}
          linhas={ficha.turma.contas}
          chaveDaLinha={(linha) => linha.id}
          legenda="Contas presentes na turma, com cadeiras contratadas e ocupadas."
          vazioTitulo="Nenhuma conta registrada"
          vazioTexto="A turma ainda não tem conta ligada a ela."
        />
      </Cartao>

      <Cartao titulo="Quem senta na turma" semRespiro>
        <Tabela
          colunas={colunas}
          linhas={ficha.participantes}
          chaveDaLinha={(linha) => linha.id}
          legenda="Participantes da turma, cada um com a conta de origem, o papel, a situação e a presença acumulada."
          vazioTitulo="Nenhum participante na turma"
          vazioTexto="As cadeiras ainda não foram preenchidas."
        />
      </Cartao>
    </>
  )
}

// ----------------------------------------------------------------- calendário

function AbaCalendario({ ficha }: { ficha: FichaDaTurma }) {
  const turma = ficha.turma
  const temRecesso = Boolean(turma.recesso_inicio && turma.recesso_fim)
  const saltos = ficha.calendario.filter((dia) => dia.saltoDeRecesso).length

  if (ficha.calendario.length === 0) {
    return (
      <Cartao>
        <EstadoVazio
          titulo="Calendário base ainda não montado"
          texto="A turma ainda não tem datas previstas. O calendário nasce da data de início, da cadência e do recesso."
        />
      </Cartao>
    )
  }

  return (
    <>
      {temRecesso ? (
        <Alarme tom="informacao" titulo="Este calendário tem recesso" className="secao">
          O conselho para de meados de dezembro a meados de janeiro. As datas saltam esse período,
          e o salto aparece marcado na lista abaixo {saltos > 0 ? '' : 'sempre que acontecer '}
          para ninguém confundir recesso com falha de registro.
        </Alarme>
      ) : null}

      <Cartao
        titulo="Calendário base da turma"
        legenda={`${inteiro(ficha.calendario.length)} datas · cadência ${ROTULO_CADENCIA[turma.cadencia].toLowerCase()}${
          temRecesso && turma.recesso_inicio && turma.recesso_fim
            ? ` · recesso de ${data(turma.recesso_inicio)} a ${data(turma.recesso_fim)}`
            : ''
        }`}
      >
        <ol style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 'var(--esp-2)' }}>
          {ficha.calendario.map((dia) => (
            <Fragment key={dia.data}>
              {dia.saltoDeRecesso ? <FaixaDeRecesso salto={dia.saltoDeRecesso} /> : null}
              <LinhaDoCalendario dia={dia} />
            </Fragment>
          ))}
        </ol>
      </Cartao>
    </>
  )
}

function FaixaDeRecesso({ salto }: { salto: NonNullable<DiaDoCalendario['saltoDeRecesso']> }) {
  return (
    <li
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        alignItems: 'center',
        gap: 'var(--esp-3)',
        padding: 'var(--esp-3) var(--esp-4)',
        borderRadius: 'var(--raio-m)',
        border: '1px dashed var(--cor-amarelo-linha)',
        background: 'var(--cor-amarelo-fundo)',
      }}
    >
      <Etiqueta tom="amarela" ponto>
        Recesso
      </Etiqueta>
      <span>
        De {data(salto.inicio)} a {data(salto.fim)} · {inteiro(salto.semanas)}{' '}
        {salto.semanas === 1 ? 'semana' : 'semanas'} sem encontro. O salto no calendário é o recesso
        do conselho, não é falha de registro.
      </span>
    </li>
  )
}

function LinhaDoCalendario({ dia }: { dia: DiaDoCalendario }) {
  return (
    <li
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        alignItems: 'baseline',
        gap: 'var(--esp-3)',
        padding: 'var(--esp-2) var(--esp-3)',
        borderBottom: '1px solid var(--cor-linha)',
      }}
    >
      <span className="numero" style={{ minWidth: '2.5rem', color: 'var(--cor-texto-fraco)' }}>
        {dia.numero}
      </span>
      <span style={{ minWidth: '14rem' }}>{dataPorExtenso(dia.data)}</span>
      {dia.status ? (
        <Etiqueta tom={TOM_DO_ENCONTRO[dia.status]}>{ROTULO_STATUS_ENCONTRO[dia.status]}</Etiqueta>
      ) : (
        <Etiqueta tom="neutra">Data do calendário</Etiqueta>
      )}
      <span className="texto-fraco">
        {dia.tema ?? 'Tema ainda não definido para esta data'}
      </span>
      {dia.encontro_id ? (
        <Link className="botao botao--discreto botao--pp" to={`/encontros/${dia.encontro_id}`}>
          Abrir encontro
        </Link>
      ) : null}
    </li>
  )
}

// ------------------------------------------------------------------ encontros

function AbaEncontros({ ficha }: { ficha: FichaDaTurma }) {
  const navegar = useNavigate()

  const ordenados = useMemo(
    () =>
      [...ficha.encontros].sort((a, b) =>
        a.numero === b.numero ? a.tentativa - b.tentativa : a.numero - b.numero,
      ),
    [ficha.encontros],
  )

  const remarcados = ordenados.filter((encontro) => encontro.status === 'remarcado').length

  const colunas: Array<ColunaTabela<EncontroNaLista>> = [
    {
      chave: 'numero',
      rotulo: 'Encontro',
      alinhamento: 'numero',
      conteudo: (linha) => (
        <>
          <span className="numero">{linha.numero}</span>
          {linha.tentativa > 1 ? (
            <>
              <br />
              <span className="texto-fraco">tentativa {linha.tentativa}</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'tema',
      rotulo: 'Tema',
      conteudo: (linha) => (
        <>
          <strong>{linha.tema}</strong>
          {linha.restrito ? (
            <>
              {' '}
              <Etiqueta tom="vermelha">Restrito</Etiqueta>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'prevista',
      rotulo: 'Data prevista',
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
      chave: 'realizada',
      rotulo: 'Data realizada',
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
      conteudo: (linha) => (
        <Etiqueta tom={TOM_DO_ENCONTRO[linha.status]} ponto>
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
      {remarcados > 0 ? (
        <Alarme tom="informacao" titulo="Remarcação não perde a numeração" className="secao">
          Esta turma tem {inteiro(remarcados)}{' '}
          {remarcados === 1 ? 'encontro remarcado' : 'encontros remarcados'}. O encontro 2 remarcado
          continua sendo o encontro 2: o que muda é a tentativa, e a primeira marcação fica
          registrada com a data que tinha. É regra do banco, não detalhe de tela.
        </Alarme>
      ) : null}

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={ordenados}
          chaveDaLinha={(linha) => linha.id}
          legenda="Encontros da turma na sequência oficial, com tentativa, datas, formato, situação e condução."
          aoEscolherLinha={(linha) => navegar(`/encontros/${linha.id}`)}
          vazioTitulo="Nenhum encontro registrado"
          vazioTexto="A turma ainda não tem encontro na sequência oficial."
        />
      </Cartao>
    </>
  )
}

// ---------------------------------------------------------------- entregáveis

function AbaEntregaveis({ ficha }: { ficha: FichaDaTurma }) {
  const [visibilidade, setVisibilidade] = useState('')

  const filtrados = ficha.entregaveis.filter((item) => {
    if (visibilidade === 'sim') return item.visivel_ao_cliente
    if (visibilidade === 'nao') return !item.visivel_ao_cliente
    return true
  })

  const colunas: Array<ColunaTabela<EntregavelNaLista>> = [
    {
      chave: 'tipo',
      rotulo: 'Tipo',
      conteudo: (linha) => ROTULO_TIPO_ENTREGAVEL[linha.tipo],
    },
    {
      chave: 'titulo',
      rotulo: 'Título',
      conteudo: (linha) => <strong>{linha.titulo}</strong>,
    },
    {
      chave: 'encontro',
      rotulo: 'Encontro',
      alinhamento: 'numero',
      conteudo: (linha) =>
        linha.encontro_numero === null ? (
          <span className="texto-fraco">sem encontro</span>
        ) : (
          <span className="numero">{linha.encontro_numero}</span>
        ),
    },
    {
      chave: 'data',
      rotulo: 'Data',
      conteudo: (linha) =>
        linha.data_entrega ? (
          data(linha.data_entrega)
        ) : (
          <span className="texto-fraco">
            {linha.prazo ? `prazo em ${data(linha.prazo)}` : 'sem data'}
          </span>
        ),
    },
    {
      chave: 'autoria',
      rotulo: 'Quem produziu',
      conteudo: (linha) => linha.produzido_por_exibido,
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta tom={TOM_DO_ENTREGAVEL[linha.status]} ponto>
          {ROTULO_STATUS_ENTREGAVEL[linha.status]}
        </Etiqueta>
      ),
    },
    {
      chave: 'visibilidade',
      rotulo: 'Visível ao cliente',
      conteudo: (linha) => (
        <Etiqueta tom={linha.visivel_ao_cliente ? 'verde' : 'neutra'} ponto>
          {linha.visivel_ao_cliente ? 'Sim' : 'Não'}
        </Etiqueta>
      ),
    },
  ]

  return (
    <>
      <Cartao className="secao">
        <div className="grade grade--3">
          <Selecao
            rotulo="Visível ao cliente"
            vazio="Tudo, visível e interno"
            value={visibilidade}
            onChange={(evento) => setVisibilidade(evento.target.value)}
            auxilio="Esta marca decide o que o participante enxerga no portal dele."
            opcoes={[
              { valor: 'sim', rotulo: ROTULO_VISIBILIDADE.sim },
              { valor: 'nao', rotulo: ROTULO_VISIBILIDADE.nao },
            ]}
          />
        </div>
      </Cartao>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={filtrados}
          chaveDaLinha={(linha) => linha.id}
          legenda="Entregáveis da turma, com tipo, autoria, situação e visibilidade ao cliente."
          vazioTitulo="Nenhum entregável com este filtro"
          vazioTexto="Troque o filtro de visibilidade para ver os demais."
        />
      </Cartao>
    </>
  )
}

// --------------------------------------------------------- Histórico de Valor

function AbaHistorico({ ficha }: { ficha: FichaDaTurma }) {
  const agora = new Date()
  const anoAtual = ficha.devido[0]?.ano ?? agora.getFullYear()
  const trimestreAtual = ficha.devido[0]?.trimestre ?? Math.floor(agora.getMonth() / 3) + 1
  const emAberto = competencia(anoAtual, trimestreAtual)

  const doTrimestre = ficha.historico.filter(
    (registro) => registro.ano === anoAtual && registro.trimestre === trimestreAtual,
  )

  const colunas: Array<ColunaTabela<RegistroHistoricoNaFicha>> = [
    {
      chave: 'competencia',
      rotulo: 'Trimestre',
      conteudo: (linha) => (
        <>
          <span className="numero">{linha.competencia}</span>
          <br />
          <span className="texto-fraco">{data(linha.data_referencia)}</span>
        </>
      ),
    },
    {
      chave: 'conta',
      rotulo: 'Conta',
      conteudo: (linha) => <Etiqueta tom="marca">{linha.conta_nome}</Etiqueta>,
    },
    {
      chave: 'entregue',
      rotulo: 'O que foi entregue',
      conteudo: (linha) => linha.entregue,
    },
    {
      chave: 'resultado',
      rotulo: 'Que resultado gerou',
      conteudo: (linha) => linha.resultado,
    },
    {
      chave: 'evidencia',
      rotulo: 'Qual a evidência',
      conteudo: (linha) => linha.evidencia,
    },
    {
      chave: 'confirmacao',
      rotulo: 'Confirmado pelo cliente',
      conteudo: (linha) =>
        linha.confirmado_em ? (
          <Etiqueta tom="verde" ponto>
            {data(linha.confirmado_em)}
          </Etiqueta>
        ) : (
          <Etiqueta tom="amarela" ponto>
            ainda não
          </Etiqueta>
        ),
    },
  ]

  return (
    <>
      {ficha.devido.length > 0 ? (
        <Alarme tom="amarelo" titulo={`Trimestre em aberto · ${emAberto}`} className="secao">
          <p>
            O registro do Histórico de Valor é obrigatório por trimestre: o que foi entregue, que
            resultado gerou e qual a evidência. Faltam {inteiro(ficha.devido.length)}{' '}
            {ficha.devido.length === 1 ? 'conta' : 'contas'} neste trimestre.
          </p>
          <ul className="lista-felix" style={{ marginTop: 'var(--esp-2)' }}>
            {ficha.devido.map((linha) => (
              <li key={`${linha.programa_id}-${linha.conta_id}`}>
                {linha.conta_nome} · {linha.programa_nome}
              </li>
            ))}
          </ul>
        </Alarme>
      ) : (
        <Alarme tom="verde" titulo={`Trimestre em dia · ${emAberto}`} className="secao">
          Toda conta deste programa já tem registro de Histórico de Valor no trimestre corrente, com{' '}
          {inteiro(doTrimestre.length)}{' '}
          {doTrimestre.length === 1 ? 'registro lançado' : 'registros lançados'}.
        </Alarme>
      )}

      <Cartao
        titulo="Histórico de Valor do programa"
        legenda="O que foi entregue, que resultado gerou e qual a evidência, trimestre a trimestre. É o insumo da renovação."
        semRespiro
      >
        <Tabela
          colunas={colunas}
          linhas={ficha.historico}
          chaveDaLinha={(linha) => linha.id}
          legenda="Registros de Histórico de Valor por trimestre e por conta."
          vazioTitulo="Nenhum registro de Histórico de Valor"
          vazioTexto="Sem registro trimestral, a renovação chega sem prova do que a casa entregou."
        />
      </Cartao>
    </>
  )
}
