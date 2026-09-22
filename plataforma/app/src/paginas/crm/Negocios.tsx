import { useMemo, useState, type CSSProperties, type DragEvent } from 'react'
import { Link } from 'react-router-dom'
import {
  Alarme,
  Botao,
  Carregando,
  Cartao,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Selecao,
  Tabela,
  type ColunaTabela,
  type SentidoOrdem,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useMoverNegocioDeFase, useNegocios } from '@/dados/crm'
import {
  AVISO_FORECAST,
  dinheiroOuAusente,
  ORDEM_DAS_FASES,
  sinalDeHigiene,
  textoOuAusente,
  type LinhaNegocioForecast,
  type LinhaPipelineHigiene,
} from '@/tipos/crm'
import type { Criticidade, Fase, ForecastCategoria, RotaNegocio } from '@/tipos/dominio'
import {
  CRITERIO_FORECAST,
  data,
  dinheiro,
  inteiro,
  ROTULO_ARTEFATO,
  ROTULO_CRITICIDADE,
  ROTULO_FASE,
  ROTULO_FORECAST,
  ROTULO_ROTA,
} from '@/tipos/rotulos'

/* ==========================================================================
   Peças compartilhadas pelas telas do CRM.
   Moram aqui porque é a tela de negócios que define a linguagem visual de
   fase, forecast e higiene. As outras telas do CRM importam daqui, para que a
   mesma ideia tenha a mesma cara em todo lugar.
   ========================================================================== */

/** Faixa que diz, em voz alta, que a tela está rodando com dados de exemplo. */
export function AvisoDeFonte({ deExemplo }: { deExemplo: boolean | undefined }) {
  const [aberto, setAberto] = useState(true)
  if (!deExemplo || !aberto) return null

  return (
    <Alarme
      tom="amarelo"
      titulo="Dados de exemplo"
      aoFechar={() => setAberto(false)}
      className="secao"
    >
      {AVISO_SEM_BANCO}
    </Alarme>
  )
}

/** A fase do funil, sempre com o número e o nome juntos. */
export function EtiquetaFase({ fase }: { fase: Fase }) {
  return (
    <Etiqueta tom="marca">
      {fase} · {ROTULO_FASE[fase]}
    </Etiqueta>
  )
}

const TOM_FORECAST: Record<ForecastCategoria, 'verde' | 'realce' | 'marca' | 'neutra'> = {
  compromisso: 'verde',
  possivel: 'realce',
  aberto: 'marca',
  fora: 'neutra',
}

/** A categoria de forecast, que sai do artefato validado com o cliente. */
export function EtiquetaForecast({
  categoria,
  artefato,
}: {
  categoria: ForecastCategoria
  artefato?: string | null
}) {
  return (
    <span style={{ display: 'inline-flex', flexWrap: 'wrap', gap: 'var(--esp-2)', alignItems: 'center' }}>
      <Etiqueta tom={TOM_FORECAST[categoria]} title={CRITERIO_FORECAST[categoria]}>
        {ROTULO_FORECAST[categoria]}
      </Etiqueta>
      {artefato ? (
        <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
          sustentado por {artefato}
        </span>
      ) : null}
    </span>
  )
}

const TOM_HIGIENE: Record<Criticidade, 'verde' | 'amarela' | 'vermelha'> = {
  verde: 'verde',
  amarelo: 'amarela',
  vermelho: 'vermelha',
}

/** O sinal verde, amarelo ou vermelho de higiene do negócio. */
export function EtiquetaHigiene({ negocio }: { negocio: LinhaNegocioForecast }) {
  const sinal = sinalDeHigiene(negocio)

  if (sinal === null) {
    return (
      <Etiqueta tom="neutra" title="A higiene é exigida apenas nas fases 1 a 4.">
        Higiene não exigida nesta fase
      </Etiqueta>
    )
  }

  const quantas = negocio.quantas_invariantes_quebradas

  return (
    <Etiqueta tom={TOM_HIGIENE[sinal]} ponto>
      {sinal === 'verde'
        ? ROTULO_CRITICIDADE.verde
        : `${quantas} ${quantas === 1 ? 'invariante quebrada' : 'invariantes quebradas'}`}
    </Etiqueta>
  )
}

/* ==========================================================================
   Tela de negócios
   ========================================================================== */

type Visao = 'quadro' | 'tabela'

interface Filtros {
  fase: string
  categoria: string
  gerente: string
  parceiro: string
  rota: string
  busca: string
}

const FILTROS_VAZIOS: Filtros = {
  fase: '',
  categoria: '',
  gerente: '',
  parceiro: '',
  rota: '',
  busca: '',
}

/**
 * As duas visões do funil, sobre a mesma lista.
 *
 * O quadro desenha as nove fases do método na ordem do contrato técnico, com
 * arrastar entre colunas. A tabela mostra a mesma lista com coluna ordenável e
 * filtro. Acima das duas, sempre visíveis, o pipeline declarado e o pipeline
 * auditado lado a lado, como manda a seção 6 do contrato.
 */
export function Negocios() {
  const consulta = useNegocios()
  const mover = useMoverNegocioDeFase()
  const [visao, setVisao] = useState<Visao>('quadro')
  const [filtros, setFiltros] = useState<Filtros>(FILTROS_VAZIOS)
  const [ordem, setOrdem] = useState<{ chave: string; sentido: SentidoOrdem }>({
    chave: 'fase',
    sentido: 'crescente',
  })

  const negocios = useMemo(() => consulta.data?.dados.negocios ?? [], [consulta.data])

  const gerentes = useMemo(
    () => listaUnica(negocios.map((linha) => linha.gerente_contas_nome)),
    [negocios],
  )
  const parceiros = useMemo(
    () => listaUnica(negocios.map((linha) => linha.parceiro_nome)),
    [negocios],
  )

  const filtrados = useMemo(() => {
    const busca = filtros.busca.trim().toLowerCase()

    return negocios.filter((linha) => {
      if (filtros.fase !== '' && String(linha.fase) !== filtros.fase) return false
      if (filtros.categoria !== '' && linha.categoria !== filtros.categoria) return false
      if (filtros.gerente !== '' && (linha.gerente_contas_nome ?? '') !== filtros.gerente) return false
      if (filtros.parceiro !== '') {
        if (filtros.parceiro === 'sem_parceiro' && linha.parceiro_nome) return false
        if (filtros.parceiro !== 'sem_parceiro' && (linha.parceiro_nome ?? '') !== filtros.parceiro) {
          return false
        }
      }
      if (filtros.rota !== '' && linha.rota !== filtros.rota) return false
      if (busca) {
        const alvo = `${linha.titulo} ${linha.conta_nome} ${linha.oferta_nome ?? ''}`.toLowerCase()
        if (!alvo.includes(busca)) return false
      }
      return true
    })
  }, [negocios, filtros])

  const ordenados = useMemo(
    () => ordenarNegocios(filtrados, ordem.chave, ordem.sentido),
    [filtrados, ordem],
  )

  function trocarOrdem(chave: string) {
    setOrdem((anterior) =>
      anterior.chave === chave
        ? { chave, sentido: anterior.sentido === 'crescente' ? 'decrescente' : 'crescente' }
        : { chave, sentido: 'crescente' },
    )
  }

  return (
    <>
      <Migalhas itens={[{ rotulo: 'CRM de Valor', para: '/painel' }, { rotulo: 'Negócios' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">CRM de Valor</p>
          <h1 className="pagina__titulo">Negócios</h1>
          <p className="pagina__lede">
            O funil nas nove fases do método Negócios de Valor. Quadro e tabela leem a mesma lista.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      <AvisoDeFonte deExemplo={consulta.data?.deExemplo} />

      {consulta.isPending ? <Carregando texto="Carregando o funil" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="O funil não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {mover.isError ? (
        <Alarme tom="vermelho" titulo="A mudança de fase não foi gravada" className="secao">
          {mover.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <DuasLinhas pipeline={consulta.data.dados.pipeline} />

          <section className="secao" aria-labelledby="titulo-lista-negocios">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-lista-negocios">
                A mesma lista, em duas visões
              </h2>
              <div style={{ display: 'flex', gap: 'var(--esp-2)', alignItems: 'center' }}>
                <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
                  {inteiro(ordenados.length)} de {inteiro(negocios.length)} negócios
                </span>
                <div role="group" aria-label="Escolha da visão" style={{ display: 'flex', gap: 'var(--esp-1)' }}>
                  <Botao
                    tom={visao === 'quadro' ? 'principal' : 'contorno'}
                    tamanho="p"
                    aria-pressed={visao === 'quadro'}
                    onClick={() => setVisao('quadro')}
                  >
                    Quadro por fase
                  </Botao>
                  <Botao
                    tom={visao === 'tabela' ? 'principal' : 'contorno'}
                    tamanho="p"
                    aria-pressed={visao === 'tabela'}
                    onClick={() => setVisao('tabela')}
                  >
                    Tabela
                  </Botao>
                </div>
              </div>
            </div>

            <p className="secao__nota" style={{ marginBottom: 'var(--esp-4)' }}>
              {AVISO_FORECAST}
            </p>

            {visao === 'quadro' ? (
              <Quadro
                negocios={ordenados}
                deExemplo={consulta.data.deExemplo}
                aoMover={(negocio_id, fase) => mover.mutate({ negocio_id, fase })}
              />
            ) : (
              <>
                <Cartao titulo="Filtros" className="secao">
                  <div className="grade grade--3">
                    <Selecao
                      rotulo="Fase"
                      vazio="Todas as fases"
                      value={filtros.fase}
                      onChange={(evento) =>
                        setFiltros((anterior) => ({ ...anterior, fase: evento.target.value }))
                      }
                      opcoes={ORDEM_DAS_FASES.map((fase) => ({
                        valor: String(fase),
                        rotulo: `${fase} · ${ROTULO_FASE[fase]}`,
                      }))}
                    />
                    <Selecao
                      rotulo="Categoria de forecast"
                      vazio="Todas as categorias"
                      value={filtros.categoria}
                      onChange={(evento) =>
                        setFiltros((anterior) => ({ ...anterior, categoria: evento.target.value }))
                      }
                      opcoes={(['compromisso', 'possivel', 'aberto', 'fora'] as ForecastCategoria[]).map(
                        (categoria) => ({ valor: categoria, rotulo: ROTULO_FORECAST[categoria] }),
                      )}
                    />
                    <Selecao
                      rotulo="Gerente de Contas"
                      vazio="Todos"
                      value={filtros.gerente}
                      onChange={(evento) =>
                        setFiltros((anterior) => ({ ...anterior, gerente: evento.target.value }))
                      }
                      opcoes={gerentes.map((nome) => ({ valor: nome, rotulo: nome }))}
                    />
                    <Selecao
                      rotulo="Parceiro"
                      vazio="Todos"
                      value={filtros.parceiro}
                      onChange={(evento) =>
                        setFiltros((anterior) => ({ ...anterior, parceiro: evento.target.value }))
                      }
                      opcoes={[
                        { valor: 'sem_parceiro', rotulo: 'Sem parceiro' },
                        ...parceiros.map((nome) => ({ valor: nome, rotulo: nome })),
                      ]}
                    />
                    <Selecao
                      rotulo="Rota"
                      vazio="Privada e pública"
                      value={filtros.rota}
                      onChange={(evento) =>
                        setFiltros((anterior) => ({ ...anterior, rota: evento.target.value }))
                      }
                      opcoes={(['privada', 'publica'] as RotaNegocio[]).map((rota) => ({
                        valor: rota,
                        rotulo: ROTULO_ROTA[rota],
                      }))}
                    />
                    <div style={{ display: 'flex', alignItems: 'flex-end' }}>
                      <Botao tom="discreto" onClick={() => setFiltros(FILTROS_VAZIOS)} largo>
                        Limpar filtros
                      </Botao>
                    </div>
                  </div>
                </Cartao>

                <Cartao semRespiro>
                  <TabelaDeNegocios
                    negocios={ordenados}
                    ordenadaPor={ordem.chave}
                    sentido={ordem.sentido}
                    aoOrdenar={trocarOrdem}
                  />
                </Cartao>
              </>
            )}
          </section>
        </>
      ) : null}
    </>
  )
}

// ------------------------------------------ pipeline declarado e auditado

function DuasLinhas({ pipeline }: { pipeline: LinhaPipelineHigiene | null }) {
  return (
    <section className="secao" aria-labelledby="titulo-duas-linhas-negocios">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-duas-linhas-negocios">
          As duas linhas
        </h2>
        <p className="secao__nota">
          Fases 1 a 4 · leitura de vw_pipeline_higiene, sempre lado a lado.
        </p>
      </div>

      {pipeline === null ? (
        <Cartao>
          <EstadoVazio
            titulo="As duas linhas não vieram nesta sessão"
            texto="O banco não devolveu a leitura do pipeline para este perfil. A tela não inventa número no lugar dela."
          />
        </Cartao>
      ) : (
        <div className="pipeline-duplo">
          <article className="cartao cartao--marca linha-pipeline">
            <p className="linha-pipeline__rotulo">Pipeline declarado</p>
            <p className="linha-pipeline__valor">
              {dinheiroOuAusente(pipeline.pipeline_declarado)}
              <span className="linha-pipeline__unidade">
                em {inteiro(pipeline.negocios_declarados)} negócios
              </span>
            </p>
            <p className="linha-pipeline__detalhe">
              A soma de tudo que está ativo nas fases 1 a 4, sem nenhum filtro.
            </p>
            <div
              className="linha-pipeline__barra"
              role="img"
              aria-label="O pipeline declarado é a linha de referência, cem por cento."
            >
              <div className="linha-pipeline__preenchimento" style={{ width: '100%' }} />
            </div>
            <p className="linha-pipeline__legenda">Linha de referência</p>
          </article>

          <article className="cartao cartao--realce linha-pipeline linha-pipeline--auditado">
            <p className="linha-pipeline__rotulo">Pipeline auditado</p>
            <p className="linha-pipeline__valor">
              {dinheiroOuAusente(pipeline.pipeline_auditado)}
              <span className="linha-pipeline__unidade">
                em {inteiro(pipeline.negocios_auditados)} negócios
              </span>
            </p>
            <p className="linha-pipeline__detalhe">
              A soma do que passa nas quatro invariantes de higiene. É este número que se leva para a
              reunião.
            </p>
            <div
              className="linha-pipeline__barra"
              role="img"
              aria-label={`O pipeline auditado é ${pipeline.percentual_valor_auditado ?? 0} por cento do declarado.`}
            >
              <div
                className="linha-pipeline__preenchimento"
                style={{ width: `${Math.max(0, Math.min(100, pipeline.percentual_valor_auditado ?? 0))}%` }}
              />
            </div>
            <p className="linha-pipeline__legenda">
              {pipeline.percentual_valor_auditado === null
                ? 'Proporção não informada'
                : `${pipeline.percentual_valor_auditado} por cento do declarado sobrevive à higiene`}
              {' · '}
              {dinheiroOuAusente(pipeline.valor_travado)} travados em{' '}
              {inteiro(pipeline.negocios_travados)} negócios
            </p>
          </article>
        </div>
      )}
    </section>
  )
}

// ------------------------------------------------------------- o quadro

const ESTILO_COLUNA: CSSProperties = {
  minWidth: '272px',
  maxWidth: '272px',
  display: 'flex',
  flexDirection: 'column',
  gap: 'var(--esp-2)',
  background: 'var(--cor-fundo-recuado)',
  border: '1px solid var(--cor-linha)',
  borderRadius: 'var(--raio-g)',
  padding: 'var(--esp-3)',
}

const ESTILO_FICHA: CSSProperties = {
  background: 'var(--cor-superficie)',
  border: '1px solid var(--cor-linha)',
  borderRadius: 'var(--raio-m)',
  boxShadow: 'var(--sombra-p)',
  padding: 'var(--esp-3)',
  display: 'flex',
  flexDirection: 'column',
  gap: 'var(--esp-2)',
  cursor: 'grab',
}

function Quadro({
  negocios,
  deExemplo,
  aoMover,
}: {
  negocios: LinhaNegocioForecast[]
  deExemplo: boolean
  aoMover: (negocioId: string, fase: Fase) => void
}) {
  const [arrastando, setArrastando] = useState<string | null>(null)
  const [alvo, setAlvo] = useState<Fase | null>(null)

  function soltar(evento: DragEvent<HTMLDivElement>, fase: Fase) {
    evento.preventDefault()
    const identificador = evento.dataTransfer.getData('text/plain') || arrastando
    setArrastando(null)
    setAlvo(null)
    if (!identificador) return
    const negocio = negocios.find((linha) => linha.negocio_id === identificador)
    if (!negocio || negocio.fase === fase) return
    aoMover(identificador, fase)
  }

  return (
    <>
      {deExemplo ? (
        <p className="secao__nota" style={{ marginBottom: 'var(--esp-3)' }}>
          Sem banco ligado, arrastar muda apenas a cópia que está na tela. Nada é gravado.
        </p>
      ) : null}

      <div
        style={{ display: 'flex', gap: 'var(--esp-3)', overflowX: 'auto', paddingBottom: 'var(--esp-4)' }}
      >
        {ORDEM_DAS_FASES.map((fase) => {
          const daFase = negocios.filter((linha) => linha.fase === fase)
          const comValor = daFase.filter((linha) => linha.valor_considerado !== null)
          const soma = comValor.reduce((total, linha) => total + (linha.valor_considerado ?? 0), 0)
          const semValor = daFase.length - comValor.length

          return (
            <div
              key={fase}
              style={{
                ...ESTILO_COLUNA,
                borderColor: alvo === fase ? 'var(--cor-marca)' : 'var(--cor-linha)',
                background: alvo === fase ? 'var(--cor-marca-suave)' : 'var(--cor-fundo-recuado)',
              }}
              onDragOver={(evento) => {
                evento.preventDefault()
                setAlvo(fase)
              }}
              onDragLeave={() => setAlvo((atual) => (atual === fase ? null : atual))}
              onDrop={(evento) => soltar(evento, fase)}
            >
              <header style={{ borderBottom: '1px solid var(--cor-linha)', paddingBottom: 'var(--esp-2)' }}>
                <p
                  style={{
                    fontFamily: 'var(--fonte-titulo)',
                    fontSize: 'var(--texto-p)',
                    textTransform: 'uppercase',
                    letterSpacing: 'var(--espaco-letra-rotulo)',
                    color: 'var(--cor-marca)',
                  }}
                >
                  {fase} · {ROTULO_FASE[fase]}
                </p>
                <p style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
                  {inteiro(daFase.length)} {daFase.length === 1 ? 'negócio' : 'negócios'} ·{' '}
                  {comValor.length === 0 ? 'sem valor informado' : dinheiro(soma)}
                  {semValor > 0 && comValor.length > 0
                    ? ` · ${inteiro(semValor)} sem valor informado`
                    : ''}
                </p>
              </header>

              {daFase.length === 0 ? (
                <p
                  style={{
                    fontSize: 'var(--texto-pp)',
                    color: 'var(--cor-texto-tenue)',
                    padding: 'var(--esp-4) 0',
                    textAlign: 'center',
                  }}
                >
                  Nenhum negócio nesta fase
                </p>
              ) : null}

              {daFase.map((negocio) => (
                <FichaDeNegocio
                  key={negocio.negocio_id}
                  negocio={negocio}
                  arrastando={arrastando === negocio.negocio_id}
                  aoComecar={() => setArrastando(negocio.negocio_id)}
                  aoTerminar={() => {
                    setArrastando(null)
                    setAlvo(null)
                  }}
                  aoMover={aoMover}
                />
              ))}
            </div>
          )
        })}
      </div>
    </>
  )
}

function FichaDeNegocio({
  negocio,
  arrastando,
  aoComecar,
  aoTerminar,
  aoMover,
}: {
  negocio: LinhaNegocioForecast
  arrastando: boolean
  aoComecar: () => void
  aoTerminar: () => void
  aoMover: (negocioId: string, fase: Fase) => void
}) {
  return (
    <article
      style={{ ...ESTILO_FICHA, opacity: arrastando ? 0.5 : 1 }}
      draggable
      onDragStart={(evento) => {
        evento.dataTransfer.setData('text/plain', negocio.negocio_id)
        evento.dataTransfer.effectAllowed = 'move'
        aoComecar()
      }}
      onDragEnd={aoTerminar}
    >
      <Link
        to={`/negocios/${negocio.negocio_id}`}
        style={{ fontWeight: 'var(--peso-forte)', fontSize: 'var(--texto-base)' }}
      >
        {negocio.titulo}
      </Link>

      <Link
        to={`/contas/${negocio.conta_id}`}
        style={{ fontSize: 'var(--texto-p)', color: 'var(--cor-texto-fraco)' }}
      >
        {negocio.conta_nome}
      </Link>

      <p style={{ fontFamily: 'var(--fonte-numero)', fontSize: 'var(--texto-g)' }}>
        {dinheiroOuAusente(negocio.valor_total ?? negocio.valor_considerado)}
      </p>

      <EtiquetaForecast
        categoria={negocio.categoria}
        artefato={
          negocio.artefato_que_sustenta ? ROTULO_ARTEFATO[negocio.artefato_que_sustenta] : null
        }
      />

      <EtiquetaHigiene negocio={negocio} />

      <label style={{ fontSize: 'var(--texto-micro)', color: 'var(--cor-texto-fraco)' }}>
        <span className="apenas-leitor">Mover {negocio.titulo} para outra fase</span>
        <select
          className="selecao__controle"
          style={{ width: '100%', fontSize: 'var(--texto-pp)' }}
          value={String(negocio.fase)}
          aria-label={`Mover ${negocio.titulo} para outra fase`}
          onChange={(evento) => {
            const escolhida = Number(evento.target.value) as Fase
            if (escolhida !== negocio.fase) aoMover(negocio.negocio_id, escolhida)
          }}
        >
          {ORDEM_DAS_FASES.map((fase) => (
            <option key={fase} value={String(fase)}>
              Mover para {fase} · {ROTULO_FASE[fase]}
            </option>
          ))}
        </select>
      </label>
    </article>
  )
}

// ------------------------------------------------------------- a tabela

function TabelaDeNegocios({
  negocios,
  ordenadaPor,
  sentido,
  aoOrdenar,
}: {
  negocios: LinhaNegocioForecast[]
  ordenadaPor: string
  sentido: SentidoOrdem
  aoOrdenar: (chave: string) => void
}) {
  const colunas: Array<ColunaTabela<LinhaNegocioForecast>> = [
    {
      chave: 'titulo',
      rotulo: 'Negócio',
      ordenavel: true,
      conteudo: (linha) => (
        <>
          <Link to={`/negocios/${linha.negocio_id}`} style={{ fontWeight: 'var(--peso-forte)' }}>
            {linha.titulo}
          </Link>
          <br />
          <Link to={`/contas/${linha.conta_id}`} className="texto-fraco">
            {linha.conta_nome}
          </Link>
        </>
      ),
    },
    {
      chave: 'fase',
      rotulo: 'Fase',
      ordenavel: true,
      conteudo: (linha) => <EtiquetaFase fase={linha.fase} />,
    },
    {
      chave: 'categoria',
      rotulo: 'Categoria de forecast',
      ordenavel: true,
      conteudo: (linha) => (
        <EtiquetaForecast
          categoria={linha.categoria}
          artefato={linha.artefato_que_sustenta ? ROTULO_ARTEFATO[linha.artefato_que_sustenta] : null}
        />
      ),
    },
    {
      chave: 'higiene',
      rotulo: 'Higiene',
      ordenavel: true,
      conteudo: (linha) => <EtiquetaHigiene negocio={linha} />,
    },
    {
      chave: 'gerente',
      rotulo: 'Gerente de Contas',
      ordenavel: true,
      conteudo: (linha) => textoOuAusente(linha.gerente_contas_nome, 'sem papel atribuído'),
    },
    {
      chave: 'parceiro',
      rotulo: 'Parceiro',
      ordenavel: true,
      conteudo: (linha) => textoOuAusente(linha.parceiro_nome, 'sem parceiro'),
    },
    {
      chave: 'rota',
      rotulo: 'Rota',
      ordenavel: true,
      conteudo: (linha) => (
        <Etiqueta tom={linha.rota === 'publica' ? 'realce' : 'neutra'}>
          {ROTULO_ROTA[linha.rota]}
        </Etiqueta>
      ),
    },
    {
      chave: 'decisao',
      rotulo: 'Data da decisão do cliente',
      ordenavel: true,
      conteudo: (linha) => data(linha.data_decisao_cliente),
    },
    {
      chave: 'valor',
      rotulo: 'Valor',
      alinhamento: 'numero',
      ordenavel: true,
      conteudo: (linha) => dinheiroOuAusente(linha.valor_total ?? linha.valor_considerado),
    },
  ]

  return (
    <Tabela
      colunas={colunas}
      linhas={negocios}
      chaveDaLinha={(linha) => linha.negocio_id}
      legenda="Negócios do funil, com fase, categoria de forecast, sinal de higiene e rota."
      ordenadaPor={ordenadaPor}
      sentido={sentido}
      aoOrdenar={aoOrdenar}
      vazioTitulo="Nenhum negócio com estes filtros"
      vazioTexto="Afrouxe um filtro, ou limpe todos para ver o funil inteiro."
    />
  )
}

// ---------------------------------------------------------------- apoios

function listaUnica(valores: Array<string | null>): string[] {
  const conjunto = new Set<string>()
  for (const valor of valores) {
    const limpo = (valor ?? '').trim()
    if (limpo) conjunto.add(limpo)
  }
  return [...conjunto].sort((a, b) => a.localeCompare(b, 'pt-BR'))
}

const ORDEM_CATEGORIA: Record<ForecastCategoria, number> = {
  compromisso: 1,
  possivel: 2,
  aberto: 3,
  fora: 4,
}

function ordenarNegocios(
  negocios: LinhaNegocioForecast[],
  chave: string,
  sentido: SentidoOrdem,
): LinhaNegocioForecast[] {
  const peso = sentido === 'crescente' ? 1 : -1

  const valorDe = (linha: LinhaNegocioForecast): string | number => {
    switch (chave) {
      case 'titulo':
        return linha.titulo.toLowerCase()
      case 'fase':
        return linha.fase
      case 'categoria':
        return ORDEM_CATEGORIA[linha.categoria]
      case 'higiene':
        return linha.exige_higiene ? linha.quantas_invariantes_quebradas : -1
      case 'gerente':
        return (linha.gerente_contas_nome ?? '').toLowerCase()
      case 'parceiro':
        return (linha.parceiro_nome ?? '').toLowerCase()
      case 'rota':
        return linha.rota
      case 'decisao':
        return linha.data_decisao_cliente ?? ''
      case 'valor':
        return linha.valor_total ?? linha.valor_considerado ?? -1
      default:
        return linha.fase
    }
  }

  return [...negocios].sort((a, b) => {
    const esquerda = valorDe(a)
    const direita = valorDe(b)
    if (typeof esquerda === 'number' && typeof direita === 'number') {
      return (esquerda - direita) * peso
    }
    return String(esquerda).localeCompare(String(direita), 'pt-BR') * peso
  })
}
