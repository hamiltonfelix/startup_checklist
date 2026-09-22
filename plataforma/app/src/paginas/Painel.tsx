import { useState } from 'react'
import {
  Alarme,
  Botao,
  Carregando,
  Cartao,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { usePainelPipeline } from '@/dados/consultas'
import { useSessao } from '@/sessao/contexto'
import type {
  ForecastCategoria,
  InvarianteHigiene,
  LinhaFase,
  LinhaForecast,
  NegocioEmRisco,
  ResumoPipeline,
} from '@/tipos/dominio'
import {
  CRITERIO_FORECAST,
  data,
  dinheiro,
  inteiro,
  periodo,
  proporcao,
  ROTULO_CRITICIDADE,
  ROTULO_FASE,
  ROTULO_FORECAST,
  ROTULO_INVARIANTE,
} from '@/tipos/rotulos'

/**
 * Painel do pipeline.
 *
 * Mostra, sempre lado a lado, o pipeline declarado e o pipeline auditado; o
 * forecast nas quatro categorias que saem do artefato validado com o cliente;
 * e as quatro invariantes de higiene, cada uma com o próprio placar.
 *
 * Nenhum número desta tela vem de percentual de probabilidade. O forecast sai
 * do artefato, conforme a seção 5 do contrato técnico.
 */
export function Painel() {
  const { sessao } = useSessao()
  const consulta = usePainelPipeline()
  const [avisoAberto, setAvisoAberto] = useState(true)

  return (
    <>
      <Migalhas itens={[{ rotulo: 'CRM de Valor', para: '/painel' }, { rotulo: 'Painel' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Gestão Contínua · {sessao.inquilino_nome}</p>
          <h1 className="pagina__titulo">Painel do pipeline</h1>
          <p className="pagina__lede">
            O que está declarado, o que sobrevive à higiene e o que o artefato validado com o
            cliente sustenta. As duas linhas aparecem juntas, sempre.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Botao tom="principal">Registrar interação</Botao>
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

      {consulta.isPending ? <Carregando texto="Montando o painel" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="O painel não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <DuasLinhas resumo={consulta.data.painel.resumo} />
          <Forecast linhas={consulta.data.painel.forecast} />
          <Invariantes invariantes={consulta.data.painel.invariantes} />
          <PorFase fases={consulta.data.painel.fases} />
          <ForaDaHigiene negocios={consulta.data.painel.negocios_em_risco} />
        </>
      ) : null}
    </>
  )
}

// ----------------------------------------- pipeline declarado e auditado

function DuasLinhas({ resumo }: { resumo: ResumoPipeline }) {
  const proporcaoAuditada = resumo.declarado
    ? Math.round((resumo.auditado / resumo.declarado) * 100)
    : 0

  return (
    <section className="secao" aria-labelledby="titulo-duas-linhas">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-duas-linhas">
          As duas linhas
        </h2>
        <p className="secao__nota">
          Fases 1 a 4 · {periodo(resumo.periodo_inicio, resumo.periodo_fim)}
        </p>
      </div>

      <div className="pipeline-duplo">
        <article className="cartao cartao--marca linha-pipeline">
          <p className="linha-pipeline__rotulo">Pipeline declarado</p>
          <p className="linha-pipeline__valor">
            {dinheiro(resumo.declarado)}
            <span className="linha-pipeline__unidade">
              em {inteiro(resumo.negocios_declarados)} negócios
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
            {dinheiro(resumo.auditado)}
            <span className="linha-pipeline__unidade">
              em {inteiro(resumo.negocios_auditados)} negócios
            </span>
          </p>
          <p className="linha-pipeline__detalhe">
            A soma do que passa nas quatro invariantes de higiene. É este número que se leva para a
            reunião.
          </p>
          <div
            className="linha-pipeline__barra"
            role="img"
            aria-label={`O pipeline auditado é ${proporcaoAuditada} por cento do declarado.`}
          >
            <div
              className="linha-pipeline__preenchimento"
              style={{ width: `${proporcaoAuditada}%` }}
            />
          </div>
          <p className="linha-pipeline__legenda">
            {proporcaoAuditada} por cento do declarado sobrevive à higiene
          </p>
        </article>
      </div>
    </section>
  )
}

// ---------------------------------------------------- forecast por artefato

const TOM_FORECAST: Record<ForecastCategoria, string> = {
  compromisso: 'forecast__caixa--compromisso',
  possivel: 'forecast__caixa--possivel',
  aberto: 'forecast__caixa--aberto',
  fora: 'forecast__caixa--fora',
}

function Forecast({ linhas }: { linhas: LinhaForecast[] }) {
  return (
    <section className="secao" aria-labelledby="titulo-forecast">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-forecast">
          Forecast por artefato
        </h2>
        <p className="secao__nota">
          A categoria sai do artefato validado com o cliente. Nenhuma tela desta plataforma
          transforma leitura qualitativa em previsão de receita.
        </p>
      </div>

      <div className="forecast">
        {linhas.map((linha) => (
          <article key={linha.categoria} className={`forecast__caixa ${TOM_FORECAST[linha.categoria]}`}>
            <h3 className="forecast__nome">{ROTULO_FORECAST[linha.categoria]}</h3>
            <p className="forecast__valor">{dinheiro(linha.valor)}</p>
            <p className="forecast__quantos">
              {inteiro(linha.quantos)} {linha.quantos === 1 ? 'negócio' : 'negócios'}
            </p>
            <p className="forecast__criterio">{CRITERIO_FORECAST[linha.categoria]}</p>
          </article>
        ))}
      </div>
    </section>
  )
}

// ------------------------------------------------ as quatro invariantes

function tomDaInvariante(cumprem: number, avaliados: number): 'verde' | 'amarelo' | 'vermelho' {
  const taxa = proporcao(cumprem, avaliados)
  if (taxa >= 90) return 'verde'
  if (taxa >= 70) return 'amarelo'
  return 'vermelho'
}

function Invariantes({ invariantes }: { invariantes: InvarianteHigiene[] }) {
  return (
    <section className="secao" aria-labelledby="titulo-invariantes">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-invariantes">
          As quatro invariantes de higiene
        </h2>
        <p className="secao__nota">
          Todo negócio ativo nas fases 1 a 4 precisa cumprir as quatro. Quem falha em uma já sai do
          pipeline auditado.
        </p>
      </div>

      <div className="grade grade--4">
        {invariantes.map((invariante, indice) => {
          const tom = tomDaInvariante(invariante.cumprem, invariante.avaliados)
          const taxa = proporcao(invariante.cumprem, invariante.avaliados)

          return (
            <article key={invariante.chave} className={`invariante invariante--${tom}`}>
              <div className="invariante__topo">
                <span className="invariante__numero" aria-hidden="true">
                  {indice + 1}
                </span>
                <h3 className="invariante__nome">{ROTULO_INVARIANTE[invariante.chave]}</h3>
              </div>

              <div className="invariante__placar">
                <span className="invariante__cumprem">{inteiro(invariante.cumprem)}</span>
                <span className="invariante__de">
                  de {inteiro(invariante.avaliados)} cumprem · {taxa} por cento
                </span>
              </div>

              <div
                className="invariante__barra"
                role="img"
                aria-label={`${invariante.cumprem} de ${invariante.avaliados} negócios cumprem: ${taxa} por cento.`}
              >
                <div className="invariante__preenchimento" style={{ width: `${taxa}%` }} />
              </div>

              <p className="invariante__pendencia">
                {invariante.cumprem === invariante.avaliados
                  ? invariante.explicacao
                  : invariante.pendencia}
              </p>
            </article>
          )
        })}
      </div>
    </section>
  )
}

// ------------------------------------------------------------- por fase

function PorFase({ fases }: { fases: LinhaFase[] }) {
  const maior = Math.max(1, ...fases.map((linha) => linha.declarado))

  return (
    <section className="secao" aria-labelledby="titulo-fases">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-fases">
          As duas linhas, fase a fase
        </h2>
        <p className="secao__nota">
          A barra clara é o declarado. A barra cheia é o que passou na higiene.
        </p>
      </div>

      <Cartao>
        <div className="fases">
          {fases.map((linha) => (
            <div className="fase" key={linha.fase}>
              <span className="fase__numero" aria-hidden="true">
                {linha.fase}
              </span>
              <span className="fase__nome">{ROTULO_FASE[linha.fase]}</span>
              <span
                className="fase__trilho"
                role="img"
                aria-label={`Fase ${linha.fase}, ${ROTULO_FASE[linha.fase]}: declarado ${dinheiro(linha.declarado)}, auditado ${dinheiro(linha.auditado)}.`}
              >
                <span
                  className="fase__declarado"
                  style={{ width: `${(linha.declarado / maior) * 100}%` }}
                />
                <span
                  className="fase__auditado"
                  style={{ width: `${(linha.auditado / maior) * 100}%` }}
                />
              </span>
              <span className="fase__valores">
                <b>{dinheiro(linha.auditado)}</b> de {dinheiro(linha.declarado)} ·{' '}
                {inteiro(linha.quantos)}
              </span>
            </div>
          ))}
        </div>
      </Cartao>
    </section>
  )
}

// ------------------------------------------------- o que saiu do auditado

function ForaDaHigiene({ negocios }: { negocios: NegocioEmRisco[] }) {
  const colunas: Array<ColunaTabela<NegocioEmRisco>> = [
    {
      chave: 'conta',
      rotulo: 'Conta',
      conteudo: (linha) => (
        <>
          <strong>{linha.conta_nome}</strong>
          <br />
          <span className="texto-fraco">{linha.titulo}</span>
        </>
      ),
    },
    {
      chave: 'fase',
      rotulo: 'Fase',
      conteudo: (linha) => (
        <Etiqueta tom="marca">
          {linha.fase} · {ROTULO_FASE[linha.fase]}
        </Etiqueta>
      ),
    },
    {
      chave: 'falhas',
      rotulo: 'O que falta',
      conteudo: (linha) => (
        <ul className="lista-felix">
          {linha.falhas.map((falha) => (
            <li key={falha}>{ROTULO_INVARIANTE[falha]}</li>
          ))}
        </ul>
      ),
    },
    {
      chave: 'decisao',
      rotulo: 'Data da decisão do cliente',
      conteudo: (linha) => data(linha.data_decisao_cliente),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta tom={linha.criticidade === 'vermelho' ? 'vermelha' : 'amarela'} ponto>
          {ROTULO_CRITICIDADE[linha.criticidade]}
        </Etiqueta>
      ),
    },
    {
      chave: 'valor',
      rotulo: 'Valor declarado',
      alinhamento: 'numero',
      conteudo: (linha) => dinheiro(linha.valor_total),
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-fora">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-fora">
          Fora do pipeline auditado
        </h2>
        <p className="secao__nota">
          Cada linha aqui é trabalho a fazer, não número a esconder.
        </p>
      </div>

      <Cartao semRespiro>
        {negocios.length === 0 ? (
          <EstadoVazio
            titulo="Pipeline inteiro auditado"
            texto="Todos os negócios ativos cumprem as quatro invariantes de higiene."
            marca="&#10003;"
          />
        ) : (
          <Tabela
            colunas={colunas}
            linhas={negocios}
            chaveDaLinha={(linha) => linha.id}
            legenda="Negócios ativos que deixaram de cumprir pelo menos uma invariante de higiene."
          />
        )}
      </Cartao>
    </section>
  )
}
