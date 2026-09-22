import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Alarme,
  Botao,
  Campo,
  CampoTexto,
  Carregando,
  Cartao,
  Etiqueta,
  Migalhas,
  Modal,
  Selecao,
  Tabela,
  type ColunaTabela,
  type TomEtiqueta,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO, temBanco } from '@/dados/cliente'
import { useIndicacoes } from '@/dados/prm'
import { data, dinheiro, inteiro, ROTULO_FASE } from '@/tipos/rotulos'
import {
  DIAS_ALARME_PROTECAO,
  ROTULO_SITUACAO_PROTECAO,
  ROTULO_STATUS_INDICACAO,
  situacaoDaProtecao,
  type IndicacaoNaTela,
  type IndicacaoStatus,
  type SituacaoProtecao,
} from '@/tipos/prm'

/**
 * Indicações do canal.
 *
 * A indicação é o que o parceiro registra antes de virar negócio. A casa
 * analisa, aceita ou recusa, e a decisão fica gravada com o motivo.
 *
 * O número que manda nesta tela é o prazo de proteção. Ele nasce no aceite,
 * dura o que o parceiro tinha contratado no momento do registro, e o padrão da
 * casa é de 90 dias. Enquanto corre, a conta está reservada àquele parceiro.
 * Quando vence sem negócio, a reserva cai. Por isso a tela mostra quanto falta
 * em toda linha, e acende alarme quando está perto do fim.
 */

const TOM_DO_STATUS: Record<IndicacaoStatus, TomEtiqueta> = {
  registrada: 'neutra',
  em_analise: 'marca',
  aceita: 'verde',
  recusada: 'vermelha',
  duplicada: 'neutra',
  convertida: 'realce',
  expirada: 'amarela',
}

const TOM_DA_PROTECAO: Record<SituacaoProtecao, TomEtiqueta> = {
  sem_protecao: 'neutra',
  em_dia: 'verde',
  perto_de_vencer: 'amarela',
  vencida: 'vermelha',
}

/** As situações que ainda esperam a decisão da casa. */
const ESPERANDO: IndicacaoStatus[] = ['registrada', 'em_analise']

export function Indicacoes() {
  const consulta = useIndicacoes()
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [filtroStatus, setFiltroStatus] = useState('')
  const [busca, setBusca] = useState('')
  const [emDecisao, setEmDecisao] = useState<IndicacaoNaTela | null>(null)

  const indicacoes = useMemo(() => consulta.data?.indicacoes ?? [], [consulta.data])

  const visiveis = useMemo(() => {
    const termo = busca.trim().toLowerCase()
    return indicacoes.filter((linha) => {
      if (filtroStatus && linha.status !== filtroStatus) return false
      if (!termo) return true
      return `${linha.conta} ${linha.parceiro_nome} ${linha.contato_nome}`
        .toLowerCase()
        .includes(termo)
    })
  }, [indicacoes, filtroStatus, busca])

  const pertoDeVencer = useMemo(
    () =>
      indicacoes
        .filter(
          (linha) => situacaoDaProtecao(linha.dias_para_expirar_protecao, linha.status) === 'perto_de_vencer',
        )
        .sort(
          (a, b) => (a.dias_para_expirar_protecao ?? 0) - (b.dias_para_expirar_protecao ?? 0),
        ),
    [indicacoes],
  )

  const placar = useMemo(() => {
    const esperando = indicacoes.filter((linha) => ESPERANDO.includes(linha.status)).length
    const protegidas = indicacoes.filter(
      (linha) => situacaoDaProtecao(linha.dias_para_expirar_protecao, linha.status) === 'em_dia',
    ).length
    const convertidas = indicacoes.filter((linha) => linha.status === 'convertida').length
    return { esperando, protegidas, convertidas }
  }, [indicacoes])

  const colunas: Array<ColunaTabela<IndicacaoNaTela>> = [
    {
      chave: 'conta',
      rotulo: 'Conta indicada',
      conteudo: (linha) => (
        <>
          <strong>{linha.conta}</strong>
          <br />
          <span className="texto-fraco">
            {linha.contato_nome}
            {linha.contato_cargo ? ` · ${linha.contato_cargo}` : ''}
          </span>
        </>
      ),
    },
    {
      chave: 'parceiro',
      rotulo: 'Parceiro',
      conteudo: (linha) => (
        <>
          <Link to={`/parceiros/${linha.parceiro_id}`}>{linha.parceiro_nome || 'Parceiro'}</Link>
          <br />
          <span className="texto-fraco">Registrada em {data(linha.registrada_em)}</span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <>
          <Etiqueta tom={TOM_DO_STATUS[linha.status]} ponto>
            {ROTULO_STATUS_INDICACAO[linha.status]}
          </Etiqueta>
          {linha.motivo_recusa ? (
            <>
              <br />
              <span className="texto-fraco">{linha.motivo_recusa}</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'protecao',
      rotulo: 'Prazo de proteção',
      conteudo: (linha) => <Protecao indicacao={linha} />,
    },
    {
      chave: 'negocio',
      rotulo: 'Negócio gerado',
      conteudo: (linha) =>
        linha.negocio_id ? (
          <>
            <strong>{linha.negocio_titulo ?? 'Negócio aberto'}</strong>
            <br />
            <span className="texto-fraco">
              {linha.negocio_fase === null
                ? 'Fase não informada'
                : `Fase ${linha.negocio_fase} · ${ROTULO_FASE[linha.negocio_fase]}`}
              {linha.negocio_valor === null ? '' : ` · ${dinheiro(linha.negocio_valor)}`}
            </span>
          </>
        ) : (
          <span className="texto-fraco">Ainda sem negócio</span>
        ),
    },
    {
      chave: 'acoes',
      rotulo: 'Aceite',
      alinhamento: 'acoes',
      conteudo: (linha) =>
        ESPERANDO.includes(linha.status) ? (
          <Botao tom="principal" tamanho="p" onClick={() => setEmDecisao(linha)}>
            Analisar
          </Botao>
        ) : (
          <Botao tom="discreto" tamanho="p" onClick={() => setEmDecisao(linha)}>
            Ver decisão
          </Botao>
        ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'PRM de Valor' }, { rotulo: 'Indicações' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">PRM de Valor</p>
          <h1 className="pagina__titulo">Indicações</h1>
          <p className="pagina__lede">
            O que o parceiro registra antes de virar negócio. A casa analisa, decide com motivo, e o
            prazo de proteção começa a correr no aceite.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Botao tom="principal">Registrar indicação</Botao>
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

      {consulta.isPending ? <Carregando texto="Carregando as indicações" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A lista não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          {pertoDeVencer.length > 0 ? (
            <Alarme
              tom="vermelho"
              titulo={`Proteção perto de vencer em ${inteiro(pertoDeVencer.length)} ${pertoDeVencer.length === 1 ? 'indicação' : 'indicações'}`}
              className="secao"
            >
              <p>
                Faltam {DIAS_ALARME_PROTECAO} dias ou menos para a reserva cair. Sem negócio aberto
                até lá, a conta deixa de estar reservada ao parceiro.
              </p>
              <ul className="lista-felix">
                {pertoDeVencer.map((linha) => (
                  <li key={linha.id}>
                    <strong>{linha.conta}</strong>, de {linha.parceiro_nome}:{' '}
                    {inteiro(linha.dias_para_expirar_protecao ?? 0)}{' '}
                    {linha.dias_para_expirar_protecao === 1 ? 'dia' : 'dias'}, até{' '}
                    {data(linha.protecao_expira_em)}.
                  </li>
                ))}
              </ul>
            </Alarme>
          ) : null}

          <section className="secao" aria-labelledby="titulo-placar-indicacoes">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-placar-indicacoes">
                O canal em três números
              </h2>
              <p className="secao__nota">
                O prazo padrão da casa é de 90 dias, e cada indicação guarda o prazo que valia
                quando foi registrada.
              </p>
            </div>

            <div className="grade grade--3">
              <article className="cartao cartao--marca linha-pipeline">
                <p className="linha-pipeline__rotulo">Esperando decisão</p>
                <p className="linha-pipeline__valor">{inteiro(placar.esperando)}</p>
                <p className="linha-pipeline__detalhe">
                  Registradas ou em análise. Enquanto a casa não decide, o prazo de proteção nem
                  começou.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Com proteção em dia</p>
                <p className="linha-pipeline__valor">{inteiro(placar.protegidas)}</p>
                <p className="linha-pipeline__detalhe">
                  Aceitas, com mais de {DIAS_ALARME_PROTECAO} dias de reserva pela frente.
                </p>
              </article>

              <article className="cartao cartao--realce linha-pipeline linha-pipeline--auditado">
                <p className="linha-pipeline__rotulo">Convertidas em negócio</p>
                <p className="linha-pipeline__valor">{inteiro(placar.convertidas)}</p>
                <p className="linha-pipeline__detalhe">
                  A indicação virou negócio no funil, e o parceiro entra como papel dele.
                </p>
              </article>
            </div>
          </section>

          <FluxoDeAceite />

          <section className="secao" aria-labelledby="titulo-lista-indicacoes">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-lista-indicacoes">
                Todas as indicações
              </h2>
              <p className="secao__nota">
                {inteiro(visiveis.length)} de {inteiro(indicacoes.length)} na lista.
              </p>
            </div>

            <Cartao>
              <div className="grade grade--3">
                <Selecao
                  rotulo="Situação"
                  vazio="Todas as situações"
                  value={filtroStatus}
                  onChange={(evento) => setFiltroStatus(evento.target.value)}
                  opcoes={(Object.keys(ROTULO_STATUS_INDICACAO) as IndicacaoStatus[]).map(
                    (chave) => ({ valor: chave, rotulo: ROTULO_STATUS_INDICACAO[chave] }),
                  )}
                />
                <Campo
                  rotulo="Buscar"
                  placeholder="Conta indicada, parceiro ou contato"
                  value={busca}
                  onChange={(evento) => setBusca(evento.target.value)}
                />
              </div>
            </Cartao>

            <Cartao semRespiro className="secao">
              <Tabela
                colunas={colunas}
                linhas={visiveis}
                chaveDaLinha={(linha) => linha.id}
                legenda="Indicações do canal, com a situação, o prazo de proteção e o negócio gerado."
                vazioTitulo="Nenhuma indicação nesta faixa"
                vazioTexto="Troque a situação ou limpe a busca para ver o canal inteiro."
                vazioAcoes={
                  <Botao
                    tom="contorno"
                    onClick={() => {
                      setFiltroStatus('')
                      setBusca('')
                    }}
                  >
                    Limpar filtros
                  </Botao>
                }
              />
            </Cartao>
          </section>

          <JanelaDeDecisao indicacao={emDecisao} aoFechar={() => setEmDecisao(null)} />
        </>
      ) : null}
    </>
  )
}

// ------------------------------------------------------- o prazo em tela

/** Quanto falta da proteção, com barra, dias e alarme quando aperta. */
export function Protecao({ indicacao }: { indicacao: IndicacaoNaTela }) {
  const situacao = situacaoDaProtecao(indicacao.dias_para_expirar_protecao, indicacao.status)
  const dias = indicacao.dias_para_expirar_protecao

  if (situacao === 'sem_protecao') {
    return (
      <>
        <Etiqueta tom="neutra">{ROTULO_SITUACAO_PROTECAO.sem_protecao}</Etiqueta>
        <br />
        <span className="texto-fraco">
          O prazo de {inteiro(indicacao.prazo_protecao_dias)} dias começa no aceite da casa.
        </span>
      </>
    )
  }

  const total = Math.max(1, indicacao.prazo_protecao_dias)
  const restante = Math.max(0, Math.min(total, dias ?? 0))
  const fracao = Math.round((restante / total) * 100)

  return (
    <>
      <Etiqueta tom={TOM_DA_PROTECAO[situacao]} ponto>
        {ROTULO_SITUACAO_PROTECAO[situacao]}
      </Etiqueta>
      <div
        className="linha-pipeline__barra"
        role="img"
        aria-label={
          situacao === 'vencida'
            ? `Proteção vencida em ${data(indicacao.protecao_expira_em)}.`
            : `Faltam ${restante} de ${total} dias de proteção.`
        }
      >
        <div className="linha-pipeline__preenchimento" style={{ width: `${fracao}%` }} />
      </div>
      <span className="texto-fraco">
        {situacao === 'vencida'
          ? `Venceu em ${data(indicacao.protecao_expira_em)}`
          : `Faltam ${inteiro(restante)} de ${inteiro(total)} dias · até ${data(indicacao.protecao_expira_em)}`}
      </span>
    </>
  )
}

// ------------------------------------------------------- o fluxo de aceite

function FluxoDeAceite() {
  const passos = [
    {
      titulo: '1 · O parceiro registra',
      texto:
        'A indicação nasce com a conta, o contato e o contexto: por que esta conta, o que ele enxergou e que porta de entrada sugere.',
    },
    {
      titulo: '2 · A casa analisa',
      texto:
        'O responsável interno confere se a conta já é atendida, se há negócio em curso e se o momento faz sentido.',
    },
    {
      titulo: '3 · A casa decide',
      texto:
        'Aceita, recusa com motivo escrito, ou marca como duplicada. A recusa sem motivo não é aceita pelo banco.',
    },
    {
      titulo: '4 · A proteção corre',
      texto:
        'No aceite, o prazo começa. Enquanto corre, a conta está reservada ao parceiro. Vencido sem negócio, a reserva cai e a indicação fica como proteção vencida.',
    },
    {
      titulo: '5 · Vira negócio',
      texto:
        'Aberto o negócio, a indicação passa a convertida e o parceiro entra como papel dele, o que sustenta a comissão pela vida do contrato.',
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-fluxo">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-fluxo">
          O fluxo de aceite
        </h2>
        <p className="secao__nota">
          Cinco passos, nesta ordem. Nenhum deles é pulado, e cada decisão fica gravada.
        </p>
      </div>

      <Cartao>
        <ol className="lista-felix">
          {passos.map((passo) => (
            <li key={passo.titulo}>
              <strong>{passo.titulo}</strong>
              <br />
              <span className="texto-fraco">{passo.texto}</span>
            </li>
          ))}
        </ol>
      </Cartao>
    </section>
  )
}

// ------------------------------------------------- a janela de decisão

function JanelaDeDecisao({
  indicacao,
  aoFechar,
}: {
  indicacao: IndicacaoNaTela | null
  aoFechar: () => void
}) {
  const [motivo, setMotivo] = useState('')

  if (!indicacao) return null

  const decidida = !ESPERANDO.includes(indicacao.status)

  return (
    <Modal
      aberto
      aoFechar={aoFechar}
      titulo={indicacao.conta}
      legenda={`Indicação de ${indicacao.parceiro_nome} · registrada em ${data(indicacao.registrada_em)}`}
      tamanho="g"
      fechaNoFundo={false}
      rodape={
        decidida ? (
          <Botao tom="contorno" onClick={aoFechar}>
            Fechar
          </Botao>
        ) : (
          <>
            <Botao tom="discreto" onClick={aoFechar}>
              Voltar
            </Botao>
            <Botao tom="perigo" disabled={!temBanco() || motivo.trim().length === 0}>
              Recusar com este motivo
            </Botao>
            <Botao tom="principal" disabled={!temBanco()}>
              Aceitar e iniciar a proteção
            </Botao>
          </>
        )
      }
    >
      {!temBanco() && !decidida ? (
        <Alarme tom="amarelo" titulo="Decisão não gravada nesta máquina">
          O banco ainda não está ligado aqui, então aceitar e recusar ficam desligados. A janela
          mostra exatamente o que será gravado quando a conexão existir.
        </Alarme>
      ) : null}

      <p>
        <strong>Contato:</strong> {indicacao.contato_nome}
        {indicacao.contato_cargo ? ` · ${indicacao.contato_cargo}` : ''}
      </p>

      <p>
        <strong>Contexto que o parceiro escreveu:</strong>
        <br />
        {indicacao.contexto}
      </p>

      {indicacao.necessidade_percebida ? (
        <p>
          <strong>Necessidade percebida:</strong>
          <br />
          {indicacao.necessidade_percebida}
        </p>
      ) : null}

      {indicacao.oferta_nome ? (
        <p>
          <strong>Porta de entrada sugerida:</strong> {indicacao.oferta_nome}
        </p>
      ) : null}

      <p className="texto-fraco">
        Aceitar inicia o prazo de proteção de {inteiro(indicacao.prazo_protecao_dias)} dias, contados
        a partir de hoje. Enquanto ele correr, a conta fica reservada a este parceiro.
      </p>

      {decidida ? (
        <Cartao tom="plano" titulo="Decisão registrada">
          <p>
            <Etiqueta tom={TOM_DO_STATUS[indicacao.status]} ponto>
              {ROTULO_STATUS_INDICACAO[indicacao.status]}
            </Etiqueta>
          </p>
          {indicacao.analisado_por_nome ? (
            <p className="texto-fraco">Analisada por {indicacao.analisado_por_nome}.</p>
          ) : null}
          {indicacao.motivo_recusa ? <p>{indicacao.motivo_recusa}</p> : null}
          <Protecao indicacao={indicacao} />
        </Cartao>
      ) : (
        <CampoTexto
          multiplas_linhas
          rotulo="Motivo, obrigatório para recusar"
          rows={3}
          maxLength={400}
          contador
          valorAtual={motivo}
          value={motivo}
          onChange={(evento) => setMotivo(evento.target.value)}
          auxilio="O banco recusa a recusa sem motivo. Escreva o que o parceiro precisa entender."
        />
      )}
    </Modal>
  )
}
