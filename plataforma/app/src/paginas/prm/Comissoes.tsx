import { useMemo, useState } from 'react'
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
  type TomEtiqueta,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useComissoes } from '@/dados/prm'
import { data, dinheiro, dinheiroExato, inteiro } from '@/tipos/rotulos'
import {
  abrirCalculo,
  competencia as rotuloCompetencia,
  CRITERIO_STATUS_COMISSAO,
  montarExtratos,
  pontosPercentuais,
  ROTULO_BENEFICIARIO,
  ROTULO_STATUS_COMISSAO,
  type ComissaoStatus,
  type ExtratoDeComissao,
  type LinhaComissao,
  type TotalDaCompetencia,
} from '@/tipos/prm'

/**
 * Extrato de comissão.
 *
 * Por pessoa, por competência, com o cálculo aberto linha a linha, porque foi
 * assim que a casa decidiu. Os dois percentuais aparecem sempre juntos: os 10
 * por cento sobre a base líquida e os 8,5 por cento efetivos sobre o bruto.
 * É o segundo número que faz o relatório de quem recebe bater com o de quem
 * paga.
 *
 * Aviso que vale para esta tela inteira: ela é vista pelo parceiro e pelo
 * Gerente de Contas, e cada um recebe do banco apenas a própria linha. Esta
 * tela não faz filtro de perfil nenhum, e não pode fazer. Se a linha veio,
 * ela aparece. Quem recorta é a política de linha, conforme as seções 8 e 9
 * do contrato técnico.
 */

const TOM_DO_STATUS: Record<ComissaoStatus, TomEtiqueta> = {
  prevista: 'neutra',
  apurada: 'amarela',
  paga: 'verde',
  cancelada: 'vermelha',
}

export function Comissoes() {
  const consulta = useComissoes()
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [filtroCompetencia, setFiltroCompetencia] = useState('')
  const [filtroSituacao, setFiltroSituacao] = useState('')

  const linhas = useMemo(() => consulta.data?.linhas ?? [], [consulta.data])

  const competencias = useMemo(() => {
    const vistas = new Set(linhas.map((linha) => linha.competencia))
    return [...vistas].sort((a, b) => b.localeCompare(a))
  }, [linhas])

  const extratos = useMemo(() => {
    const filtradas = linhas.filter((linha) => {
      if (filtroCompetencia && linha.competencia !== filtroCompetencia) return false
      if (filtroSituacao && linha.status !== filtroSituacao) return false
      return true
    })
    return montarExtratos(filtradas)
  }, [linhas, filtroCompetencia, filtroSituacao])

  return (
    <>
      <Migalhas itens={[{ rotulo: 'PRM de Valor' }, { rotulo: 'Comissões' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">PRM de Valor</p>
          <h1 className="pagina__titulo">Comissões</h1>
          <p className="pagina__lede">
            Extrato por pessoa e por competência, com o cálculo aberto linha a linha. Os dois
            percentuais ficam à vista, para o relatório de quem recebe e o de quem paga não
            divergirem.
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

      {consulta.isPending ? <Carregando texto="Montando o extrato" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="O extrato não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <ReguaDaCasa />

          <section className="secao" aria-labelledby="titulo-filtros-comissao">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-filtros-comissao">
                O que mostrar
              </h2>
              <p className="secao__nota">
                Estes dois filtros trabalham sobre o que o banco já entregou. Eles não escondem
                nada: quem recorta é a política de linha.
              </p>
            </div>

            <Cartao>
              <div className="grade grade--3">
                <Selecao
                  rotulo="Competência"
                  vazio="Todas as competências"
                  value={filtroCompetencia}
                  onChange={(evento) => setFiltroCompetencia(evento.target.value)}
                  opcoes={competencias.map((chave) => ({
                    valor: chave,
                    rotulo: rotuloCompetencia(chave),
                  }))}
                />
                <Selecao
                  rotulo="Situação"
                  vazio="Todas as situações"
                  value={filtroSituacao}
                  onChange={(evento) => setFiltroSituacao(evento.target.value)}
                  opcoes={(Object.keys(ROTULO_STATUS_COMISSAO) as ComissaoStatus[]).map(
                    (chave) => ({ valor: chave, rotulo: ROTULO_STATUS_COMISSAO[chave] }),
                  )}
                  auxilio={
                    filtroSituacao
                      ? CRITERIO_STATUS_COMISSAO[filtroSituacao as ComissaoStatus]
                      : 'Prevista, apurada ou paga. A cancelada nunca entra nos totais.'
                  }
                />
              </div>
            </Cartao>
          </section>

          <ExtratosDeComissao extratos={extratos} />
        </>
      ) : null}
    </>
  )
}

// --------------------------------------------------------- a régua da casa

/** A conta, na ordem exata em que a casa decidiu. Fica sempre à vista. */
export function ReguaDaCasa() {
  return (
    <section className="secao" aria-labelledby="titulo-regua">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-regua">
          A conta, em ordem
        </h2>
        <p className="secao__nota">
          O imposto sai primeiro. A comissão incide sobre o que sobra, nunca sobre o bruto.
        </p>
      </div>

      <div className="grade grade--2">
        <Cartao
          titulo="Os cinco passos"
          legenda="A mesma régua para o parceiro e para o Gerente de Contas."
        >
          <ol className="lista-felix">
            <li>Valor da parcela, que é o valor bruto.</li>
            <li>Imposto, igual ao bruto vezes o percentual de imposto da casa.</li>
            <li>Base de comissão, igual ao bruto menos o imposto.</li>
            <li>Comissão, igual à base vezes o percentual acordado.</li>
            <li>Percentual efetivo sobre o bruto, que é a mesma comissão lida sobre o bruto.</li>
          </ol>
        </Cartao>

        <Cartao
          tom="realce"
          titulo="Por que os dois percentuais"
          legenda="Um número só faria os relatórios discordarem."
        >
          <p>
            Com 15 por cento de imposto e 10 por cento sobre a base, a comissão equivale a 8,5 por
            cento do bruto. Quem recebe lê os 10 por cento, que foi o que combinou. Quem paga lê os
            8,5 por cento, que é o que sai do bruto. São o mesmo dinheiro, e por isso os dois
            aparecem em toda linha desta tela.
          </p>
          <p className="texto-fraco">
            Os percentuais vêm da configuração do inquilino, nunca do código. Quando um contrato
            tem regime diferente, a própria linha carrega o percentual que valeu.
          </p>
        </Cartao>
      </div>
    </section>
  )
}

// ------------------------------------------------------- extrato por pessoa

export interface PropsExtratos {
  extratos: ExtratoDeComissao[]
  /** Texto do estado vazio, para a ficha do parceiro trocar a frase. */
  vazioTexto?: string
}

/**
 * O extrato agrupado por pessoa e por competência.
 *
 * Reaproveitado pela ficha do parceiro, que mostra o extrato dele com a mesma
 * régua e a mesma abertura de cálculo.
 */
export function ExtratosDeComissao({ extratos, vazioTexto }: PropsExtratos) {
  const [fechadas, setFechadas] = useState<Set<string>>(new Set())

  const totalDeLinhas = extratos.reduce(
    (total, extrato) =>
      total + extrato.competencias.reduce((soma, grupo) => soma + grupo.linhas.length, 0),
    0,
  )

  function alternar(id: string) {
    setFechadas((anterior) => {
      const proximo = new Set(anterior)
      if (proximo.has(id)) proximo.delete(id)
      else proximo.add(id)
      return proximo
    })
  }

  function abrirTodas() {
    setFechadas(new Set())
  }

  function fecharTodas() {
    const todas = new Set<string>()
    for (const extrato of extratos) {
      for (const grupo of extrato.competencias) {
        for (const linha of grupo.linhas) todas.add(linha.id)
      }
    }
    setFechadas(todas)
  }

  if (extratos.length === 0) {
    return (
      <section className="secao" aria-labelledby="titulo-extratos">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-extratos">
            Extrato
          </h2>
        </div>
        <Cartao>
          <EstadoVazio
            titulo="Nenhuma linha de comissão"
            texto={
              vazioTexto ??
              'Não veio nenhuma linha do banco com os filtros atuais. A comissão nasce quando a parcela é apurada.'
            }
          />
        </Cartao>
      </section>
    )
  }

  return (
    <section className="secao" aria-labelledby="titulo-extratos">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-extratos">
          Extrato por pessoa
        </h2>
        <p className="secao__nota">
          {inteiro(extratos.length)} {extratos.length === 1 ? 'pessoa' : 'pessoas'} ·{' '}
          {inteiro(totalDeLinhas)} {totalDeLinhas === 1 ? 'linha' : 'linhas'}. O cálculo de cada
          linha nasce aberto.
        </p>
      </div>

      <div className="pagina__acoes secao">
        <Botao tom="contorno" tamanho="p" onClick={abrirTodas}>
          Abrir todos os cálculos
        </Botao>
        <Botao tom="discreto" tamanho="p" onClick={fecharTodas}>
          Fechar todos os cálculos
        </Botao>
      </div>

      {extratos.map((extrato) => (
        <Cartao
          key={`${extrato.beneficiario_tipo}-${extrato.beneficiario_id}`}
          className="secao"
          tom="marca"
          titulo={extrato.beneficiario_nome}
          legenda={`${ROTULO_BENEFICIARIO[extrato.beneficiario_tipo]} · ${inteiro(extrato.geral.quantas)} ${extrato.geral.quantas === 1 ? 'linha' : 'linhas'} no período mostrado`}
        >
          <TotaisDaCompetencia total={extrato.geral} legenda="Somando todas as competências" />

          {extrato.competencias.map((grupo) => (
            <section
              key={`${extrato.beneficiario_id}-${grupo.total.competencia}`}
              className="secao"
              aria-label={`Competência ${rotuloCompetencia(grupo.total.competencia)}`}
            >
              <div className="secao__topo">
                <h3 className="secao__titulo">{rotuloCompetencia(grupo.total.competencia)}</h3>
                <p className="secao__nota">
                  {inteiro(grupo.linhas.length)}{' '}
                  {grupo.linhas.length === 1 ? 'linha nesta competência' : 'linhas nesta competência'}
                </p>
              </div>

              <TotaisDaCompetencia total={grupo.total} legenda="Nesta competência" />

              {grupo.linhas.map((linha) => (
                <LinhaDoExtrato
                  key={linha.id}
                  linha={linha}
                  aberta={!fechadas.has(linha.id)}
                  aoAlternar={() => alternar(linha.id)}
                />
              ))}
            </section>
          ))}
        </Cartao>
      ))}
    </section>
  )
}

function TotaisDaCompetencia({
  total,
  legenda,
}: {
  total: TotalDaCompetencia
  legenda: string
}) {
  return (
    <div className="grade grade--4 secao">
      <article className="cartao linha-pipeline">
        <p className="linha-pipeline__rotulo">Prevista</p>
        <p className="linha-pipeline__valor">{dinheiro(total.prevista)}</p>
        <p className="linha-pipeline__detalhe">{legenda} · parcela ainda não recebida.</p>
      </article>
      <article className="cartao linha-pipeline">
        <p className="linha-pipeline__rotulo">Apurada</p>
        <p className="linha-pipeline__valor">{dinheiro(total.apurada)}</p>
        <p className="linha-pipeline__detalhe">{legenda} · recebida e aguardando pagamento.</p>
      </article>
      <article className="cartao linha-pipeline">
        <p className="linha-pipeline__rotulo">Paga</p>
        <p className="linha-pipeline__valor">{dinheiro(total.paga)}</p>
        <p className="linha-pipeline__detalhe">{legenda} · com data de pagamento registrada.</p>
      </article>
      <article className="cartao cartao--realce linha-pipeline linha-pipeline--auditado">
        <p className="linha-pipeline__rotulo">Total</p>
        <p className="linha-pipeline__valor">{dinheiro(total.total)}</p>
        <p className="linha-pipeline__detalhe">
          Sobre uma base de {dinheiro(total.base)}, vinda de {dinheiro(total.bruto)} de bruto. Linha
          cancelada não entra.
        </p>
      </article>
    </div>
  )
}

// ---------------------------------------------------- o cálculo aberto

interface PassoDoCalculo {
  chave: string
  passo: string
  conta: string
  valor: string
}

function LinhaDoExtrato({
  linha,
  aberta,
  aoAlternar,
}: {
  linha: LinhaComissao
  aberta: boolean
  aoAlternar: () => void
}) {
  const calculo = abrirCalculo(linha)

  const passos: PassoDoCalculo[] = [
    {
      chave: 'bruto',
      passo: 'Valor da parcela',
      conta: 'O valor bruto que o cliente pagou',
      valor: dinheiroExato(calculo.valor_bruto),
    },
    {
      chave: 'imposto',
      passo: 'Imposto',
      conta: `Bruto vezes ${pontosPercentuais(calculo.imposto_percentual)}`,
      valor: dinheiroExato(calculo.imposto_valor),
    },
    {
      chave: 'base',
      passo: 'Base de comissão',
      conta: 'Bruto menos imposto',
      valor: dinheiroExato(calculo.base_calculo),
    },
    {
      chave: 'comissao',
      passo: 'Comissão',
      conta:
        calculo.percentual_sobre_base === null
          ? 'Valor combinado, sem percentual sobre a base'
          : `Base vezes ${pontosPercentuais(calculo.percentual_sobre_base)}`,
      valor: dinheiroExato(calculo.valor),
    },
    {
      chave: 'efetivo',
      passo: 'Percentual efetivo sobre o bruto',
      conta: 'A mesma comissão lida sobre o bruto',
      valor: pontosPercentuais(calculo.percentual_efetivo_sobre_bruto),
    },
  ]

  const colunas: Array<ColunaTabela<PassoDoCalculo>> = [
    { chave: 'passo', rotulo: 'Passo', conteudo: (passo) => <strong>{passo.passo}</strong> },
    {
      chave: 'conta',
      rotulo: 'Como se calcula',
      conteudo: (passo) => <span className="texto-fraco">{passo.conta}</span>,
    },
    {
      chave: 'valor',
      rotulo: 'Resultado',
      alinhamento: 'numero',
      conteudo: (passo) => <span className="numero">{passo.valor}</span>,
    },
  ]

  return (
    <Cartao
      className="secao"
      titulo={linha.conta_nome || 'Conta sem nome'}
      legenda={[
        linha.negocio_titulo,
        linha.contrato_codigo,
        linha.parcela_numero === null ? null : `Parcela ${inteiro(linha.parcela_numero)}`,
      ]
        .filter(Boolean)
        .join(' · ')}
      acoes={
        <>
          <Etiqueta tom={TOM_DO_STATUS[linha.status]} ponto>
            {ROTULO_STATUS_COMISSAO[linha.status]}
          </Etiqueta>
          <Botao tom="contorno" tamanho="p" onClick={aoAlternar} aria-expanded={aberta}>
            {aberta ? 'Fechar o cálculo' : 'Abrir o cálculo'}
          </Botao>
        </>
      }
      rodape={
        <>
          <span>
            {pontosPercentuais(calculo.percentual_sobre_base)} sobre a base ·{' '}
            {pontosPercentuais(calculo.percentual_efetivo_sobre_bruto)} efetivos sobre o bruto
          </span>
          <span className="numero">{dinheiroExato(calculo.valor)}</span>
        </>
      }
    >
      {linha.pago_em ? (
        <p className="texto-fraco">Pagamento registrado em {data(linha.pago_em)}.</p>
      ) : null}

      {linha.observacao ? <p>{linha.observacao}</p> : null}

      {aberta ? (
        <Tabela
          colunas={colunas}
          linhas={passos}
          chaveDaLinha={(passo) => passo.chave}
          legenda={`Cálculo aberto da comissão de ${linha.beneficiario_nome} nesta parcela.`}
        />
      ) : (
        <p className="texto-fraco">
          O cálculo desta linha está fechado. Abra para conferir os cinco passos.
        </p>
      )}
    </Cartao>
  )
}
