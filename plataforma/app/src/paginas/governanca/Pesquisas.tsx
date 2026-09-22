import { useEffect, useState } from 'react'
import {
  Alarme,
  Botao,
  Cartao,
  Carregando,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Selecao,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useContasDaGovernanca, usePainelNps } from '@/dados/governanca'
import type {
  AlertaCiclo,
  AvaliacaoConselheiro,
  LinhaNpsPessoa,
  PesquisaQuestao,
  QuestaoBloco,
} from '@/tipos/governanca'
import {
  CRITERIO_NPS_FAIXA,
  ROTULO_NPS_FAIXA,
  ROTULO_PESQUISA_STATUS,
  ROTULO_PESQUISA_TIPO,
  ROTULO_QUESTAO_BLOCO,
  ROTULO_QUESTAO_TIPO,
  ROTULO_SITUACAO_CICLO,
} from '@/tipos/governanca'
import { data as formatarData, dataPorExtenso, inteiro, periodo } from '@/tipos/rotulos'

/**
 * Pesquisas e NPS por conta.
 *
 * A decisão da casa, escrita na própria tela porque as pessoas perguntam: cada
 * pessoa entra com a última nota que deu, com a data e a motivação escrita.
 * A plataforma não mostra média de nota em lugar nenhum. O NPS sai da contagem
 * de promotores menos detratores sobre o total de respondentes.
 *
 * Avaliação de pessoa é confidencial e quem decide quem vê é a política de
 * linha no banco. Esta tela não esconde nada com condição de perfil: ela pede,
 * e mostra o que vier. Quando não vier nada, ela diz isso sem quebrar.
 */
export function Pesquisas() {
  const contas = useContasDaGovernanca()
  const [contaId, setContaId] = useState('')

  const lista = contas.data?.dados ?? []

  // A primeira conta da lista abre a tela, para nunca cair num painel vazio.
  useEffect(() => {
    if (!contaId && lista.length > 0) {
      setContaId(lista[0]?.id ?? '')
    }
  }, [contaId, lista])

  const consulta = usePainelNps(contaId)
  const painel = consulta.data?.dados ?? null

  return (
    <>
      <Migalhas itens={[{ rotulo: 'Governança' }, { rotulo: 'Pesquisas' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Governança · voz do cliente</p>
          <h1 className="pagina__titulo">Pesquisas e NPS</h1>
          <p className="pagina__lede">
            Cada pessoa aparece com a última nota que deu, a data e a motivação escrita. Esta
            plataforma não mostra média de nota, por decisão da casa: média esconde o detrator que
            precisa de uma conversa.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      {consulta.data?.deExemplo || contas.data?.deExemplo ? (
        <Alarme tom="amarelo" titulo="Dados de exemplo" className="secao">
          {AVISO_SEM_BANCO} Nenhuma avaliação de pessoa entra nos dados de exemplo.
        </Alarme>
      ) : null}

      {contas.isError ? (
        <Alarme tom="vermelho" titulo="A lista de contas não carregou">
          {contas.error.message}
        </Alarme>
      ) : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="O painel de NPS não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      <section className="secao" aria-labelledby="titulo-conta-nps">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-conta-nps">
            A conta
          </h2>
          <p className="secao__nota">O painel é por conta, nunca um número só para a casa inteira.</p>
        </div>

        <div className="grade grade--2">
          <Selecao
            rotulo="Conta"
            value={contaId}
            opcoes={lista.map((conta) => ({ valor: conta.id, rotulo: conta.nome }))}
            onChange={(evento) => setContaId(evento.target.value)}
          />
        </div>
      </section>

      {contas.isPending || (consulta.isPending && contaId.length > 0) ? (
        <Carregando texto="Montando o painel de NPS" />
      ) : null}

      {painel ? (
        <>
          <Placar painel={painel.consolidado} pessoas={painel.pessoas} />
          <Pessoas pessoas={painel.pessoas} />
          <Ciclos ciclos={painel.ciclos} />
          <Instrumento
            questoes={painel.questoes}
            titulo={painel.pesquisa?.titulo ?? null}
            situacao={
              painel.pesquisa
                ? `${ROTULO_PESQUISA_TIPO[painel.pesquisa.tipo]} · ${ROTULO_PESQUISA_STATUS[painel.pesquisa.status]} · ${periodo(
                    painel.pesquisa.periodo_inicio,
                    painel.pesquisa.periodo_fim,
                  )}`
                : null
            }
          />
          <Avaliacoes avaliacoes={painel.avaliacoes} />
        </>
      ) : null}
    </>
  )
}

// ------------------------------------------------------------------ placar

function Placar({
  painel,
  pessoas,
}: {
  painel: { respondentes: number; promotores: number; neutros: number; detratores: number; nps: number; ultima_resposta: string | null }
  pessoas: LinhaNpsPessoa[]
}) {
  const faixa = (quantos: number) =>
    painel.respondentes ? Math.round((quantos / painel.respondentes) * 100) : 0

  return (
    <section className="secao" aria-labelledby="titulo-placar-nps">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-placar-nps">
          O NPS da conta
        </h2>
        <p className="secao__nota">
          Promotores menos detratores, sobre o total de respondentes. Cada respondente entra com a
          última nota, nunca com a média das notas que já deu.
        </p>
      </div>

      <div className="grade grade--4">
        <Cartao titulo="NPS" tom="marca">
          <p className="numero" style={{ fontSize: 'var(--texto-3xg)' }}>
            {painel.respondentes === 0 ? 'sem nota' : painel.nps}
          </p>
          <p className="texto-fraco">
            {inteiro(painel.respondentes)}{' '}
            {painel.respondentes === 1 ? 'respondente' : 'respondentes'}
            {painel.ultima_resposta ? ` · última resposta em ${formatarData(painel.ultima_resposta)}` : ''}
          </p>
        </Cartao>

        <Cartao titulo="Promotores">
          <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
            {inteiro(painel.promotores)}
          </p>
          <p className="texto-fraco">
            {faixa(painel.promotores)} por cento · {CRITERIO_NPS_FAIXA.promotor}
          </p>
        </Cartao>

        <Cartao titulo="Neutros">
          <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
            {inteiro(painel.neutros)}
          </p>
          <p className="texto-fraco">
            {faixa(painel.neutros)} por cento · {CRITERIO_NPS_FAIXA.neutro}
          </p>
        </Cartao>

        <Cartao titulo="Detratores" tom={painel.detratores > 0 ? 'realce' : 'simples'}>
          <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
            {inteiro(painel.detratores)}
          </p>
          <p className="texto-fraco">
            {faixa(painel.detratores)} por cento · {CRITERIO_NPS_FAIXA.detrator}
          </p>
        </Cartao>
      </div>

      {pessoas.some((pessoa) => pessoa.faixa === 'detrator') ? (
        <Alarme tom="amarelo" titulo="Há detrator nesta conta" className="secao">
          Detrator não é número de painel, é conversa marcada. Leia a motivação escrita de cada um
          antes da próxima reunião de conselho.
        </Alarme>
      ) : null}
    </section>
  )
}

// ------------------------------------------- a última nota de cada pessoa

function Pessoas({ pessoas }: { pessoas: LinhaNpsPessoa[] }) {
  const colunas: Array<ColunaTabela<LinhaNpsPessoa>> = [
    {
      chave: 'respondente',
      rotulo: 'Pessoa',
      conteudo: (linha) => (
        <>
          <strong>{linha.respondente}</strong>
          {linha.anonima ? (
            <>
              <br />
              <span className="texto-fraco">Resposta anônima, identidade mascarada pelo banco</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'nota',
      rotulo: 'Última nota',
      alinhamento: 'numero',
      conteudo: (linha) => <span className="numero">{linha.nota}</span>,
    },
    {
      chave: 'faixa',
      rotulo: 'Faixa',
      conteudo: (linha) => (
        <Etiqueta
          tom={
            linha.faixa === 'promotor' ? 'verde' : linha.faixa === 'neutro' ? 'amarela' : 'vermelha'
          }
          ponto
        >
          {ROTULO_NPS_FAIXA[linha.faixa]}
        </Etiqueta>
      ),
    },
    {
      chave: 'data',
      rotulo: 'Data da nota',
      conteudo: (linha) => formatarData(linha.data_da_nota),
    },
    {
      chave: 'motivacao',
      rotulo: 'Motivação escrita',
      conteudo: (linha) =>
        linha.motivacao ?? <span className="texto-fraco">Sem motivação escrita nesta resposta</span>,
    },
    { chave: 'periodo', rotulo: 'Ciclo', conteudo: (linha) => linha.periodo },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-pessoas-nps">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-pessoas-nps">
          A última nota de cada pessoa
        </h2>
        <p className="secao__nota">
          Uma linha por pessoa, com a data e a motivação escrita. Nunca a média: a média some com a
          pessoa que precisa de conversa, e é exatamente essa pessoa que o conselho quer ver.
        </p>
      </div>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={pessoas}
          chaveDaLinha={(linha) => linha.respondente_chave}
          legenda="Última nota de cada pessoa, com data, faixa e motivação escrita."
          vazioTitulo="Nenhuma nota registrada para esta conta"
          vazioTexto="Quando a pesquisa do ciclo fechar, cada pessoa aparece aqui com a última nota que deu."
        />
      </Cartao>
    </section>
  )
}

// -------------------------------------------------------------- os ciclos

function Ciclos({ ciclos }: { ciclos: AlertaCiclo[] }) {
  const vencidos = ciclos.filter((ciclo) => ciclo.situacao === 'vencido')
  const aVencer = ciclos.filter((ciclo) => ciclo.situacao === 'a vencer')

  return (
    <section className="secao" aria-labelledby="titulo-ciclos">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-ciclos">
          O ciclo das pesquisas
        </h2>
        <p className="secao__nota">
          A pesquisa de NPS é trimestral. A nota do conselheiro é semestral, respondida pelos sócios
          do cliente.
        </p>
      </div>

      {vencidos.length > 0 ? (
        <Alarme
          tom="vermelho"
          titulo={`${vencidos.length} ${vencidos.length === 1 ? 'ciclo vencido' : 'ciclos vencidos'}`}
          className="secao"
        >
          <ul className="lista-felix">
            {vencidos.map((ciclo) => (
              <li key={ciclo.id}>
                {ROTULO_PESQUISA_TIPO[ciclo.tipo]} · devia ter sido aplicada em{' '}
                {dataPorExtenso(ciclo.proxima_aplicacao)} · {Math.abs(ciclo.dias_para_o_ciclo)} dias
                de atraso
              </li>
            ))}
          </ul>
        </Alarme>
      ) : null}

      {aVencer.length > 0 ? (
        <Alarme tom="amarelo" titulo="Ciclo vencendo" className="secao">
          <ul className="lista-felix">
            {aVencer.map((ciclo) => (
              <li key={ciclo.id}>
                {ROTULO_PESQUISA_TIPO[ciclo.tipo]} · próxima aplicação em{' '}
                {dataPorExtenso(ciclo.proxima_aplicacao)} · faltam {ciclo.dias_para_o_ciclo} dias
              </li>
            ))}
          </ul>
        </Alarme>
      ) : null}

      <div className="grade grade--2">
        {ciclos.length === 0 ? (
          <Cartao>
            <EstadoVazio
              titulo="Nenhum ciclo configurado para esta conta"
              texto="Sem ciclo configurado, a plataforma não tem quando cobrar a próxima pesquisa."
            />
          </Cartao>
        ) : (
          ciclos.map((ciclo) => (
            <Cartao
              key={ciclo.id}
              titulo={ROTULO_PESQUISA_TIPO[ciclo.tipo]}
              legenda={`A cada ${ciclo.periodicidade_meses} meses`}
              acoes={
                <Etiqueta
                  tom={
                    ciclo.situacao === 'vencido'
                      ? 'vermelha'
                      : ciclo.situacao === 'a vencer'
                        ? 'amarela'
                        : 'verde'
                  }
                  ponto
                >
                  {ROTULO_SITUACAO_CICLO[ciclo.situacao]}
                </Etiqueta>
              }
            >
              <p>
                Próxima aplicação em <strong>{dataPorExtenso(ciclo.proxima_aplicacao)}</strong>.
              </p>
              <p className="texto-fraco" style={{ marginTop: 'var(--esp-2)' }}>
                {ciclo.ultima_aplicacao
                  ? `Última aplicação em ${dataPorExtenso(ciclo.ultima_aplicacao)}.`
                  : 'Nenhuma aplicação registrada até agora.'}
              </p>
              <p className="texto-fraco">
                {ciclo.dias_para_o_ciclo >= 0
                  ? `Faltam ${ciclo.dias_para_o_ciclo} dias.`
                  : `Venceu há ${Math.abs(ciclo.dias_para_o_ciclo)} dias.`}
              </p>
            </Cartao>
          ))
        )}
      </div>
    </section>
  )
}

// ------------------------------------------------------- o instrumento

const ORDEM_DOS_BLOCOS: QuestaoBloco[] = [
  'recomendacao',
  'qualidade',
  'atendimento',
  'relacionamento_comercial',
  'entrega',
  'valor_percebido',
  'lealdade',
  'inovacao',
]

function Instrumento({
  questoes,
  titulo,
  situacao,
}: {
  questoes: PesquisaQuestao[]
  titulo: string | null
  situacao: string | null
}) {
  const classica = questoes.find((questao) => questao.eh_pergunta_classica)

  return (
    <section className="secao" aria-labelledby="titulo-instrumento">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-instrumento">
          O instrumento da casa
        </h2>
        <p className="secao__nota">
          A pergunta clássica de recomendação, mais os blocos de qualidade, atendimento,
          relacionamento comercial, entrega, valor percebido, lealdade e inovação.
        </p>
      </div>

      {titulo ? (
        <Cartao titulo={titulo} legenda={situacao ?? undefined} tom="marca">
          <p>
            {classica
              ? classica.enunciado
              : 'Esta pesquisa ainda não tem a pergunta clássica de recomendação registrada.'}
          </p>
          <p className="texto-fraco" style={{ marginTop: 'var(--esp-2)' }}>
            É a resposta desta pergunta que vira promotor, neutro ou detrator, e que calcula o NPS.
          </p>
        </Cartao>
      ) : (
        <Cartao>
          <EstadoVazio
            titulo="Nenhuma pesquisa registrada para esta conta"
            texto="Quando a campanha do ciclo nascer, o instrumento inteiro aparece aqui, bloco a bloco."
          />
        </Cartao>
      )}

      {questoes.length > 0 ? (
        <div className="grade grade--2 secao">
          {ORDEM_DOS_BLOCOS.filter((bloco) => questoes.some((questao) => questao.bloco === bloco)).map(
            (bloco) => (
              <Cartao key={bloco} titulo={ROTULO_QUESTAO_BLOCO[bloco]}>
                <ul className="lista-felix">
                  {questoes
                    .filter((questao) => questao.bloco === bloco)
                    .map((questao) => (
                      <li key={questao.id}>
                        {questao.enunciado}
                        <br />
                        <span className="texto-fraco">
                          {ROTULO_QUESTAO_TIPO[questao.tipo]}
                          {questao.escala_minimo !== null && questao.escala_maximo !== null
                            ? ` de ${questao.escala_minimo} a ${questao.escala_maximo}`
                            : ''}
                          {questao.obrigatoria ? ' · obrigatória' : ' · opcional'}
                          {questao.eh_pergunta_classica ? ' · calcula o NPS' : ''}
                        </span>
                      </li>
                    ))}
                </ul>
              </Cartao>
            ),
          )}
        </div>
      ) : null}
    </section>
  )
}

// ------------------------------------------- avaliação do conselheiro

function Avaliacoes({ avaliacoes }: { avaliacoes: AvaliacaoConselheiro[] }) {
  return (
    <section className="secao" aria-labelledby="titulo-avaliacoes">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-avaliacoes">
          Nota do conselheiro
        </h2>
        <p className="secao__nota">
          De 0 a 10, semestral, respondida pelos sócios do cliente, com as críticas construtivas
          registradas.
        </p>
      </div>

      <Alarme tom="informacao" titulo="Avaliação de pessoa é confidencial" className="secao">
        Quem pode ler cada linha desta seção é decidido pela política de linha no banco, nunca por
        esta tela. A interface pede o dado e mostra o que vier. Quando nada vier, é porque esta
        sessão não alcança, ou porque o líder ainda não liberou a devolutiva ao avaliado.
      </Alarme>

      {avaliacoes.length === 0 ? (
        <Cartao>
          <EstadoVazio
            titulo="Nenhuma avaliação chegou a esta sessão"
            texto="Isto não é erro da tela. Ou não existe avaliação registrada no período, ou o banco não liberou nenhuma linha para quem está olhando agora."
          />
        </Cartao>
      ) : (
        <div className="grade grade--2">
          {avaliacoes.map((avaliacao) => (
            <Cartao
              key={avaliacao.id}
              titulo={`Ciclo ${avaliacao.periodo}`}
              legenda={periodo(avaliacao.periodo_inicio, avaliacao.periodo_fim)}
              acoes={
                <Etiqueta tom={avaliacao.liberada_para_avaliado ? 'verde' : 'amarela'} ponto>
                  {avaliacao.liberada_para_avaliado
                    ? 'Liberada ao avaliado'
                    : 'Ainda não liberada ao avaliado'}
                </Etiqueta>
              }
            >
              <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
                {avaliacao.nota}
              </p>
              {avaliacao.pontos_fortes ? (
                <>
                  <p className="texto-fraco" style={{ marginTop: 'var(--esp-3)' }}>
                    Pontos fortes
                  </p>
                  <p>{avaliacao.pontos_fortes}</p>
                </>
              ) : null}
              {avaliacao.criticas_construtivas ? (
                <>
                  <p className="texto-fraco" style={{ marginTop: 'var(--esp-3)' }}>
                    Críticas construtivas
                  </p>
                  <p>{avaliacao.criticas_construtivas}</p>
                </>
              ) : null}
              {avaliacao.devolutiva_do_lider ? (
                <>
                  <p className="texto-fraco" style={{ marginTop: 'var(--esp-3)' }}>
                    Devolutiva do líder
                  </p>
                  <p>{avaliacao.devolutiva_do_lider}</p>
                </>
              ) : null}
              <p className="texto-fraco" style={{ marginTop: 'var(--esp-3)' }}>
                Quem avaliou nunca é revelado ao avaliado.
              </p>
            </Cartao>
          ))}
        </div>
      )}
    </section>
  )
}
