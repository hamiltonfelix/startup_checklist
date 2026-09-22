import { useEffect, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  Alarme,
  Botao,
  BotaoIA,
  Campo,
  CampoTexto,
  Carregando,
  Cartao,
  EstadoVazio,
  Etiqueta,
  Migalhas,
} from '@/componentes/indice'
import { useFichaDoNegocio, useSalvarCamposDoNegocio } from '@/dados/crm'
import { AvisoDeFonte, EtiquetaForecast, EtiquetaHigiene } from '@/paginas/crm/Negocios'
import { ListaDeInteracoes } from '@/paginas/crm/Conta'
import {
  artefatoExigidoNaFase,
  AVISO_FORECAST,
  AVISO_PROBABILIDADE,
  dinheiroOuAusente,
  invariantesDoNegocio,
  textoOuAusente,
  TRILHA_DE_ARTEFATOS,
  type LinhaArtefato,
  type LinhaNegocioForecast,
  type LinhaPapelNegocio,
  type LinhaRotaPublica,
} from '@/tipos/crm'
import type { TipoArtefato } from '@/tipos/dominio'
import {
  data,
  dinheiro,
  inteiro,
  ROTULO_ARTEFATO,
  ROTULO_DESFECHO,
  ROTULO_FASE,
  ROTULO_INVARIANTE,
  ROTULO_NIVEL,
  ROTULO_ORIGEM,
  ROTULO_PAPEL,
  ROTULO_PROBABILIDADE,
  ROTULO_ROTA,
  ROTULO_STATUS_ARTEFATO,
} from '@/tipos/rotulos'

/**
 * A ficha do negócio, o coração do CRM de Valor.
 *
 * Traz, na ordem em que o método pede: o cabeçalho com a categoria de forecast
 * e o artefato que a sustenta; o próximo passo em destaque, porque é a primeira
 * invariante de higiene; as quatro invariantes com o que falta em cada uma que
 * estiver quebrada; a trilha dos sete artefatos do método; quem faz o quê e a
 * partir de que fase entrou; o histórico de interações; e, quando a rota é
 * pública, o bloco da Lei 14.133.
 */
export function Negocio() {
  const { id } = useParams<{ id: string }>()
  const consulta = useFichaDoNegocio(id)
  const salvar = useSalvarCamposDoNegocio()

  const ficha = consulta.data?.dados

  return (
    <>
      <Migalhas
        itens={[
          { rotulo: 'CRM de Valor', para: '/painel' },
          { rotulo: 'Negócios', para: '/negocios' },
          { rotulo: ficha?.negocio.titulo ?? 'Negócio' },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Ficha do negócio</p>
          <h1 className="pagina__titulo">{ficha?.negocio.titulo ?? 'Negócio'}</h1>
          {ficha ? (
            <p className="pagina__lede">
              <Link to={`/contas/${ficha.negocio.conta_id}`}>{ficha.negocio.conta_nome}</Link> ·{' '}
              {ROTULO_ROTA[ficha.negocio.rota]} · origem {ROTULO_ORIGEM[ficha.negocio.origem]}
            </p>
          ) : null}
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      <AvisoDeFonte deExemplo={consulta.data?.deExemplo} />

      {consulta.isPending ? <Carregando texto="Carregando a ficha do negócio" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A ficha não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {salvar.isError ? (
        <Alarme tom="vermelho" titulo="A gravação não passou" className="secao">
          {salvar.error.message}
        </Alarme>
      ) : null}

      {ficha ? (
        <>
          <Cabecalho negocio={ficha.negocio} />

          <ProximoPasso
            negocio={ficha.negocio}
            deExemplo={consulta.data?.deExemplo ?? false}
            salvando={salvar.isPending}
            aoSalvar={(passo, quando) =>
              salvar.mutate({
                negocio_id: ficha.negocio.negocio_id,
                proximo_passo: passo,
                proximo_passo_data: quando,
              })
            }
          />

          <Invariantes negocio={ficha.negocio} />

          <Trilha negocio={ficha.negocio} artefatos={ficha.artefatos} />

          <QuemFazOQue papeis={ficha.papeis} />

          <Descricao
            negocio={ficha.negocio}
            deExemplo={consulta.data?.deExemplo ?? false}
            salvando={salvar.isPending}
            aoSalvar={(texto) =>
              salvar.mutate({ negocio_id: ficha.negocio.negocio_id, descricao: texto })
            }
          />

          {ficha.negocio.rota === 'publica' ? (
            <RotaPublica publica={ficha.rota_publica} />
          ) : null}

          <section className="secao" aria-labelledby="titulo-interacoes-negocio">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-interacoes-negocio">
                Histórico de interações
              </h2>
              <p className="secao__nota">
                {inteiro(ficha.interacoes.length)}{' '}
                {ficha.interacoes.length === 1 ? 'conversa registrada' : 'conversas registradas'}{' '}
                neste negócio, da mais recente para a mais antiga.
              </p>
            </div>
            <Cartao>
              <ListaDeInteracoes interacoes={ficha.interacoes} />
            </Cartao>
          </section>
        </>
      ) : null}
    </>
  )
}

// ------------------------------------------------------------- cabeçalho

function Ficha({ rotulo, children }: { rotulo: string; children: ReactNode }) {
  return (
    <article
      style={{
        border: '1px solid var(--cor-linha)',
        borderRadius: 'var(--raio-g)',
        background: 'var(--cor-superficie)',
        padding: 'var(--esp-4)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--esp-2)',
      }}
    >
      <span
        style={{
          fontSize: 'var(--texto-micro)',
          textTransform: 'uppercase',
          letterSpacing: 'var(--espaco-letra-rotulo)',
          color: 'var(--cor-texto-fraco)',
        }}
      >
        {rotulo}
      </span>
      <div style={{ fontSize: 'var(--texto-m)' }}>{children}</div>
    </article>
  )
}

function Cabecalho({ negocio }: { negocio: LinhaNegocioForecast }) {
  return (
    <section className="secao" aria-labelledby="titulo-cabecalho-negocio">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-cabecalho-negocio">
          O negócio de relance
        </h2>
        <p className="secao__nota">{AVISO_FORECAST}</p>
      </div>

      <div className="grade grade--3">
        <Ficha rotulo="Conta">
          <Link to={`/contas/${negocio.conta_id}`} style={{ fontWeight: 'var(--peso-forte)' }}>
            {negocio.conta_nome}
          </Link>
          <br />
          <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
            {textoOuAusente(negocio.oferta_nome, 'sem oferta vinculada')} ·{' '}
            {ROTULO_NIVEL[negocio.nivel_contrato]}
          </span>
        </Ficha>

        <Ficha rotulo="Fase">
          <span style={{ fontFamily: 'var(--fonte-titulo)', fontSize: 'var(--texto-g)' }}>
            {negocio.fase} · {ROTULO_FASE[negocio.fase]}
          </span>
          <br />
          <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
            nesta fase desde {data(negocio.entrou_na_fase_em)}
            {negocio.dias_parado === null
              ? ''
              : ` · ${inteiro(negocio.dias_parado)} dias sem conversa`}
          </span>
          {negocio.desfecho ? (
            <>
              <br />
              <Etiqueta tom="neutra">Desfecho: {ROTULO_DESFECHO[negocio.desfecho]}</Etiqueta>
            </>
          ) : null}
        </Ficha>

        <Ficha rotulo="Valor">
          <span style={{ fontFamily: 'var(--fonte-numero)', fontSize: 'var(--texto-xg)' }}>
            {dinheiroOuAusente(negocio.valor_total ?? negocio.valor_considerado)}
          </span>
          <br />
          <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
            {negocio.valor_recorrente_mes === null
              ? 'sem parcela recorrente informada'
              : `${dinheiro(negocio.valor_recorrente_mes)} por mês · ${inteiro(negocio.meses_recorrencia)} meses`}
          </span>
        </Ficha>

        <Ficha rotulo="Data da decisão do cliente">
          <span style={{ fontFamily: 'var(--fonte-numero)', fontSize: 'var(--texto-xg)' }}>
            {data(negocio.data_decisao_cliente)}
          </span>
          <br />
          <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
            {negocio.dias_ate_decisao === null
              ? 'sem data combinada com o cliente'
              : negocio.dias_ate_decisao >= 0
                ? `faltam ${inteiro(negocio.dias_ate_decisao)} dias`
                : `passou há ${inteiro(Math.abs(negocio.dias_ate_decisao))} dias`}
          </span>
        </Ficha>

        <Ficha rotulo="Categoria de forecast">
          <EtiquetaForecast
            categoria={negocio.categoria}
            artefato={
              negocio.artefato_que_sustenta ? ROTULO_ARTEFATO[negocio.artefato_que_sustenta] : null
            }
          />
          <br />
          <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
            {negocio.artefato_que_sustenta
              ? `${ROTULO_ARTEFATO[negocio.artefato_que_sustenta]} validado com o cliente em ${data(negocio.artefato_validado_em)}`
              : 'nenhum artefato validado com o cliente sustenta este negócio hoje'}
          </span>
        </Ficha>

        <Ficha rotulo="Leitura do time">
          {negocio.probabilidade ? (
            <Etiqueta tom="neutra">{ROTULO_PROBABILIDADE[negocio.probabilidade]}</Etiqueta>
          ) : (
            <span className="texto-fraco">sem leitura registrada</span>
          )}
          <br />
          <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
            {AVISO_PROBABILIDADE}
          </span>
        </Ficha>
      </div>
    </section>
  )
}

// ---------------------------------------------------------- próximo passo

function ProximoPasso({
  negocio,
  deExemplo,
  salvando,
  aoSalvar,
}: {
  negocio: LinhaNegocioForecast
  deExemplo: boolean
  salvando: boolean
  aoSalvar: (passo: string | null, quando: string | null) => void
}) {
  const [passo, setPasso] = useState(negocio.proximo_passo ?? '')
  const [quando, setQuando] = useState(negocio.proximo_passo_data ?? '')

  useEffect(() => {
    setPasso(negocio.proximo_passo ?? '')
    setQuando(negocio.proximo_passo_data ?? '')
  }, [negocio.proximo_passo, negocio.proximo_passo_data])

  const mudou = passo !== (negocio.proximo_passo ?? '') || quando !== (negocio.proximo_passo_data ?? '')

  return (
    <section className="secao" aria-labelledby="titulo-proximo-passo">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-proximo-passo">
          Próximo passo
        </h2>
        <p className="secao__nota">
          A primeira das quatro invariantes de higiene. Sem próximo passo com data, o negócio para e
          ninguém percebe.
        </p>
      </div>

      <Cartao
        tom={negocio.tem_proximo_passo ? 'realce' : 'marca'}
        acoes={
          <Etiqueta tom={negocio.tem_proximo_passo ? 'verde' : 'vermelha'} ponto>
            {negocio.tem_proximo_passo ? 'Invariante cumprida' : 'Invariante quebrada'}
          </Etiqueta>
        }
        titulo={textoOuAusente(negocio.proximo_passo, 'Nenhum próximo passo escrito')}
        legenda={`${data(negocio.proximo_passo_data)} · responsável: ${textoOuAusente(
          negocio.proximo_passo_responsavel_nome,
          'não informado',
        )}`}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--esp-4)' }}>
          <CampoTexto
            multiplas_linhas
            rotulo="Qual é o próximo passo"
            rows={3}
            maxLength={500}
            contador
            valorAtual={passo}
            value={passo}
            onChange={(evento) => setPasso(evento.target.value)}
            auxilio="O assistente propõe um passo a partir da fase e do que já está escrito. Nada entra no campo sem você mandar."
            acessorio={
              <BotaoIA
                campo="proximo_passo"
                textoAtual={passo}
                aoAceitar={setPasso}
                contexto={{
                  conta: negocio.conta_nome,
                  negocio: negocio.titulo,
                  fase: `${negocio.fase} · ${ROTULO_FASE[negocio.fase]}`,
                  categoria_de_forecast: negocio.categoria,
                }}
              />
            }
          />

          <div className="grade grade--2">
            <Campo
              rotulo="Data do próximo passo"
              type="date"
              value={quando}
              onChange={(evento) => setQuando(evento.target.value)}
            />
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 'var(--esp-2)' }}>
              <Botao
                tom="principal"
                carregando={salvando}
                disabled={!mudou}
                onClick={() => aoSalvar(passo.trim() || null, quando || null)}
              >
                Gravar próximo passo
              </Botao>
              {mudou ? (
                <Botao
                  tom="discreto"
                  onClick={() => {
                    setPasso(negocio.proximo_passo ?? '')
                    setQuando(negocio.proximo_passo_data ?? '')
                  }}
                >
                  Desfazer
                </Botao>
              ) : null}
            </div>
          </div>

          {deExemplo ? (
            <p className="secao__nota">
              Sem banco ligado, gravar muda apenas a cópia que está na tela.
            </p>
          ) : null}
        </div>
      </Cartao>
    </section>
  )
}

// ------------------------------------------------- as quatro invariantes

function Invariantes({ negocio }: { negocio: LinhaNegocioForecast }) {
  const leitura = invariantesDoNegocio(negocio)

  return (
    <section className="secao" aria-labelledby="titulo-invariantes-negocio">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-invariantes-negocio">
          As quatro invariantes de higiene
        </h2>
        <div style={{ display: 'flex', gap: 'var(--esp-2)', alignItems: 'center' }}>
          <EtiquetaHigiene negocio={negocio} />
        </div>
      </div>

      {!negocio.exige_higiene ? (
        <Alarme tom="informacao" className="secao">
          A higiene é exigida nas fases 1 a 4. Este negócio está na fase {negocio.fase},{' '}
          {ROTULO_FASE[negocio.fase]}, então as quatro leituras abaixo servem de acompanhamento, não
          de corte do pipeline auditado.
        </Alarme>
      ) : null}

      <div className="grade grade--4">
        {leitura.map((invariante, indice) => (
          <article
            key={invariante.chave}
            className={`invariante invariante--${invariante.cumpre ? 'verde' : 'vermelho'}`}
          >
            <div className="invariante__topo">
              <span className="invariante__numero" aria-hidden="true">
                {indice + 1}
              </span>
              <h3 className="invariante__nome">{ROTULO_INVARIANTE[invariante.chave]}</h3>
            </div>

            <div className="invariante__placar">
              <Etiqueta tom={invariante.cumpre ? 'verde' : 'vermelha'} ponto>
                {invariante.cumpre ? 'Cumprida' : 'Quebrada'}
              </Etiqueta>
            </div>

            <p className="invariante__pendencia">
              {invariante.cumpre ? 'Nada a fazer nesta invariante.' : invariante.pendencia}
            </p>
          </article>
        ))}
      </div>
    </section>
  )
}

// ----------------------------------------------- a trilha dos artefatos

function Trilha({
  negocio,
  artefatos,
}: {
  negocio: LinhaNegocioForecast
  artefatos: LinhaArtefato[]
}) {
  const daFase = artefatoExigidoNaFase(negocio.fase)

  /** O artefato mais recente de cada tipo, que é o que vale na tela. */
  function maisRecente(tipo: TipoArtefato): LinhaArtefato | null {
    const doTipo = artefatos.filter((linha) => linha.tipo === tipo)
    if (doTipo.length === 0) return null
    return doTipo.reduce((maior, atual) => (atual.versao >= maior.versao ? atual : maior))
  }

  return (
    <section className="secao" aria-labelledby="titulo-trilha">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-trilha">
          A trilha dos sete artefatos
        </h2>
        <p className="secao__nota">
          Só artefato validado com o cliente conta para o forecast. Rascunho e pronto por dentro não
          mudam a categoria deste negócio.
        </p>
      </div>

      <Cartao semRespiro>
        <ol style={{ listStyle: 'none', margin: 0 }}>
          {TRILHA_DE_ARTEFATOS.map((tipo, indice) => {
            const artefato = maisRecente(tipo)
            const validado = artefato?.status === 'validado_com_cliente'
            const eODaFase = daFase === tipo
            const sustenta = negocio.artefato_que_sustenta === tipo

            return (
              <li
                key={tipo}
                style={{
                  display: 'flex',
                  gap: 'var(--esp-4)',
                  alignItems: 'flex-start',
                  padding: 'var(--esp-4)',
                  borderBottom:
                    indice === TRILHA_DE_ARTEFATOS.length - 1
                      ? 'none'
                      : '1px solid var(--cor-linha)',
                  background: eODaFase ? 'var(--cor-marca-suave)' : 'transparent',
                }}
              >
                <span
                  aria-hidden="true"
                  style={{
                    flex: '0 0 auto',
                    width: '2rem',
                    height: '2rem',
                    borderRadius: 'var(--raio-pilula)',
                    display: 'grid',
                    placeItems: 'center',
                    fontFamily: 'var(--fonte-numero)',
                    background: validado
                      ? 'var(--cor-verde-fundo)'
                      : artefato
                        ? 'var(--cor-amarelo-fundo)'
                        : 'var(--cor-fundo-recuado)',
                    color: validado
                      ? 'var(--cor-verde)'
                      : artefato
                        ? 'var(--cor-amarelo)'
                        : 'var(--cor-texto-tenue)',
                    border: `1px solid ${
                      validado
                        ? 'var(--cor-verde-linha)'
                        : artefato
                          ? 'var(--cor-amarelo-linha)'
                          : 'var(--cor-linha)'
                    }`,
                  }}
                >
                  {indice + 1}
                </span>

                <div style={{ flex: '1 1 auto', display: 'flex', flexDirection: 'column', gap: 'var(--esp-1)' }}>
                  <div style={{ display: 'flex', gap: 'var(--esp-2)', flexWrap: 'wrap', alignItems: 'center' }}>
                    <strong style={{ fontSize: 'var(--texto-m)' }}>{ROTULO_ARTEFATO[tipo]}</strong>
                    {eODaFase ? <Etiqueta tom="marca">Artefato desta fase</Etiqueta> : null}
                    {sustenta ? (
                      <Etiqueta tom="verde" ponto>
                        Sustenta a categoria de forecast
                      </Etiqueta>
                    ) : null}
                  </div>

                  {artefato ? (
                    <>
                      <span style={{ fontSize: 'var(--texto-p)' }}>
                        Versão {inteiro(artefato.versao)} ·{' '}
                        <Etiqueta tom={validado ? 'verde' : 'amarela'}>
                          {ROTULO_STATUS_ARTEFATO[artefato.status]}
                        </Etiqueta>
                      </span>
                      <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
                        {validado
                          ? `Validado com o cliente em ${data(artefato.validado_em)}. Conta para o forecast.`
                          : 'Ainda não validado com o cliente. Não conta para o forecast.'}
                        {artefato.gerado_com_ia ? ' · escrito com apoio de IA' : ''}
                      </span>
                    </>
                  ) : (
                    <span style={{ fontSize: 'var(--texto-p)', color: 'var(--cor-texto-fraco)' }}>
                      Ainda não registrado neste negócio.
                      {eODaFase
                        ? ' É o artefato que comprova a fase atual, e a invariante de higiene cobra ele.'
                        : ''}
                    </span>
                  )}
                </div>
              </li>
            )
          })}
        </ol>
      </Cartao>
    </section>
  )
}

// ----------------------------------------------------- quem faz o quê

function QuemFazOQue({ papeis }: { papeis: LinhaPapelNegocio[] }) {
  const ativos = papeis.filter((papel) => papel.ativo)

  return (
    <section className="secao" aria-labelledby="titulo-papeis">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-papeis">
          Quem faz o quê
        </h2>
        <p className="secao__nota">
          Leitura de papeis_negocio, com a fase a partir da qual cada um entrou. O conselheiro entra
          na Conexão de Valor, a fase 3, e segue até o fim.
        </p>
      </div>

      <Cartao>
        {ativos.length === 0 ? (
          <EstadoVazio
            titulo="Nenhum papel registrado"
            texto="Este negócio ainda não tem papel atribuído, ou este perfil não alcança a lista."
          />
        ) : (
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 'var(--esp-3)' }}>
            {ativos.map((papel) => (
              <li
                key={papel.id}
                style={{
                  display: 'flex',
                  gap: 'var(--esp-4)',
                  alignItems: 'center',
                  flexWrap: 'wrap',
                  borderLeft: '3px solid var(--cor-realce)',
                  paddingLeft: 'var(--esp-4)',
                }}
              >
                <span style={{ minWidth: '12rem' }}>
                  <strong>{ROTULO_PAPEL[papel.papel]}</strong>
                  {papel.principal ? (
                    <>
                      {' '}
                      <Etiqueta tom="marca">principal</Etiqueta>
                    </>
                  ) : null}
                </span>

                <span style={{ minWidth: '14rem' }}>
                  {textoOuAusente(papel.usuario_nome ?? papel.parceiro_nome, 'sem nome informado')}
                </span>

                <Etiqueta tom="neutra">
                  entrou na fase {papel.entrou_na_fase} · {ROTULO_FASE[papel.entrou_na_fase]}
                </Etiqueta>

                {papel.papel === 'conselheiro' ? (
                  <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-realce-legivel)' }}>
                    entrada do conselheiro conforme o método
                  </span>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </Cartao>
    </section>
  )
}

// ------------------------------------------------------------- descrição

function Descricao({
  negocio,
  deExemplo,
  salvando,
  aoSalvar,
}: {
  negocio: LinhaNegocioForecast
  deExemplo: boolean
  salvando: boolean
  aoSalvar: (texto: string | null) => void
}) {
  const [texto, setTexto] = useState(negocio.descricao ?? '')

  useEffect(() => {
    setTexto(negocio.descricao ?? '')
  }, [negocio.descricao])

  const mudou = texto !== (negocio.descricao ?? '')

  return (
    <section className="secao" aria-labelledby="titulo-descricao">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-descricao">
          Descrição do negócio
        </h2>
        <p className="secao__nota">
          O que a casa entendeu deste negócio, em texto corrido, para quem chega depois.
        </p>
      </div>

      <Cartao>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--esp-4)' }}>
          <CampoTexto
            multiplas_linhas
            rotulo="Descrição"
            rows={5}
            maxLength={2000}
            contador
            valorAtual={texto}
            value={texto}
            onChange={(evento) => setTexto(evento.target.value)}
            auxilio="Nada entra no campo sem você mandar. O assistente só propõe."
            acessorio={
              <BotaoIA
                campo="descricao_negocio"
                textoAtual={texto}
                aoAceitar={setTexto}
                contexto={{
                  conta: negocio.conta_nome,
                  negocio: negocio.titulo,
                  oferta: negocio.oferta_nome,
                  fase: `${negocio.fase} · ${ROTULO_FASE[negocio.fase]}`,
                }}
              />
            }
          />

          <div style={{ display: 'flex', gap: 'var(--esp-2)' }}>
            <Botao
              tom="principal"
              carregando={salvando}
              disabled={!mudou}
              onClick={() => aoSalvar(texto.trim() || null)}
            >
              Gravar descrição
            </Botao>
            {mudou ? (
              <Botao tom="discreto" onClick={() => setTexto(negocio.descricao ?? '')}>
                Desfazer
              </Botao>
            ) : null}
          </div>

          {deExemplo ? (
            <p className="secao__nota">
              Sem banco ligado, gravar muda apenas a cópia que está na tela.
            </p>
          ) : null}
        </div>
      </Cartao>
    </section>
  )
}

// ----------------------------------------------------------- rota pública

function RotaPublica({ publica }: { publica: LinhaRotaPublica | null }) {
  return (
    <section className="secao" aria-labelledby="titulo-rota-publica">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-rota-publica">
          Rota pública · Lei 14.133
        </h2>
        <p className="secao__nota">
          Este negócio corre pela via da contratação pública. O que manda é o processo, com prazo e
          sessão marcados em portal oficial.
        </p>
      </div>

      {publica === null ? (
        <Alarme tom="amarelo" titulo="Bloco da rota pública ainda em branco">
          O negócio está marcado como rota pública, mas o complemento com identificador do PNCP,
          órgão, modalidade, fase administrativa e data da sessão ainda não foi registrado.
        </Alarme>
      ) : (
        <Cartao tom="marca">
          <div className="grade grade--3">
            <Ficha rotulo="Identificador do PNCP">
              {textoOuAusente(publica.identificador_pncp, 'ainda sem identificador')}
            </Ficha>
            <Ficha rotulo="Órgão">{textoOuAusente(publica.orgao)}</Ficha>
            <Ficha rotulo="Modalidade">{textoOuAusente(publica.modalidade)}</Ficha>
            <Ficha rotulo="Fase administrativa">
              {textoOuAusente(publica.fase_administrativa)}
            </Ficha>
            <Ficha rotulo="Data da sessão">{data(publica.data_sessao)}</Ficha>
            <Ficha rotulo="Publicação">{data(publica.data_publicacao)}</Ficha>
          </div>

          {publica.desfecho_publico ? (
            <p style={{ marginTop: 'var(--esp-4)' }}>
              <Etiqueta tom="neutra">Desfecho do processo: {publica.desfecho_publico}</Etiqueta>
            </p>
          ) : null}
        </Cartao>
      )}
    </section>
  )
}
