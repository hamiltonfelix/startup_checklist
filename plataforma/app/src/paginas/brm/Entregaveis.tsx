import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Alarme,
  Botao,
  BotaoIA,
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
import { useEntregaveis } from '@/dados/brm'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useSessao } from '@/sessao/contexto'
import {
  ROTULO_STATUS_ENTREGAVEL,
  ROTULO_TIPO_ENTREGAVEL,
  ROTULO_VISIBILIDADE,
  type BrmStatusEntregavel,
  type EntregavelNaLista,
} from '@/tipos/brm'
import { data, inteiro } from '@/tipos/rotulos'

/**
 * Entregáveis do BRM de Valor.
 *
 * Tipo, título, data, quem produziu, situação e, com destaque próprio, a marca
 * de visível ao cliente. Essa marca decide o que o participante enxerga no
 * portal dele, então o filtro por visibilidade fica na frente, em botão, e não
 * escondido numa lista de opções qualquer.
 */

const TOM_DA_SITUACAO: Record<BrmStatusEntregavel, TomEtiqueta> = {
  rascunho: 'neutra',
  entregue: 'marca',
  aprovado: 'verde',
}

type Visibilidade = 'tudo' | 'sim' | 'nao'

const BOTOES_DE_VISIBILIDADE: Array<{ chave: Visibilidade; rotulo: string }> = [
  { chave: 'tudo', rotulo: 'Tudo' },
  { chave: 'sim', rotulo: ROTULO_VISIBILIDADE.sim },
  { chave: 'nao', rotulo: ROTULO_VISIBILIDADE.nao },
]

export function Entregaveis() {
  const { sessao } = useSessao()
  const consulta = useEntregaveis()

  const [avisoAberto, setAvisoAberto] = useState(true)
  const [busca, setBusca] = useState('')
  const [turma, setTurma] = useState('')
  const [tipo, setTipo] = useState('')
  const [situacao, setSituacao] = useState('')
  const [visibilidade, setVisibilidade] = useState<Visibilidade>('tudo')
  const [aberto, setAberto] = useState<EntregavelNaLista | null>(null)

  const todos = useMemo(() => consulta.data?.entregaveis ?? [], [consulta.data])

  const turmas = useMemo(
    () => Array.from(new Set(todos.map((item) => item.turma_codigo))).sort(),
    [todos],
  )

  const visiveis = todos.filter((item) => item.visivel_ao_cliente).length
  const internos = todos.length - visiveis

  const filtrados = useMemo(() => {
    const procurado = busca.trim().toLowerCase()
    return todos.filter((item) => {
      if (visibilidade === 'sim' && !item.visivel_ao_cliente) return false
      if (visibilidade === 'nao' && item.visivel_ao_cliente) return false
      if (turma && item.turma_codigo !== turma) return false
      if (tipo && item.tipo !== tipo) return false
      if (situacao && item.status !== situacao) return false
      if (!procurado) return true
      return (
        item.titulo.toLowerCase().includes(procurado) ||
        (item.descricao ?? '').toLowerCase().includes(procurado) ||
        item.produzido_por_exibido.toLowerCase().includes(procurado) ||
        (item.conta_nome ?? '').toLowerCase().includes(procurado)
      )
    })
  }, [todos, busca, turma, tipo, situacao, visibilidade])

  const colunas: Array<ColunaTabela<EntregavelNaLista>> = [
    {
      chave: 'tipo',
      rotulo: 'Tipo',
      conteudo: (linha) => (
        <>
          {ROTULO_TIPO_ENTREGAVEL[linha.tipo]}
          {linha.tipo_detalhe ? (
            <>
              <br />
              <span className="texto-fraco">{linha.tipo_detalhe}</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'titulo',
      rotulo: 'Título',
      conteudo: (linha) => (
        <>
          <strong>{linha.titulo}</strong>
          <br />
          <span className="texto-fraco">
            {linha.turma_codigo}
            {linha.encontro_numero === null ? '' : ` · encontro ${linha.encontro_numero}`}
            {linha.conta_nome ? ` · ${linha.conta_nome}` : ''}
          </span>
        </>
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
        <Etiqueta tom={TOM_DA_SITUACAO[linha.status]} ponto>
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
      <Migalhas itens={[{ rotulo: 'BRM de Valor' }, { rotulo: 'Entregáveis' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">BRM de Valor · {sessao.inquilino_nome}</p>
          <h1 className="pagina__titulo">Entregáveis</h1>
          <p className="pagina__lede">
            O que cada encontro produziu: ata, pré-pauta, resumo semanal, plano, diagnóstico e o que
            mais a turma gerar. Escolha uma linha para abrir a ficha e escrever a descrição.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Link className="botao botao--contorno" to="/turmas">
            Ver as turmas
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

      {consulta.isPending ? <Carregando texto="Carregando os entregáveis" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="Os entregáveis não carregaram">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <section className="secao" aria-labelledby="titulo-visibilidade">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-visibilidade">
                Visível ao cliente
              </h2>
              <p className="secao__nota">
                Esta marca decide o que o participante enxerga no portal dele. Sem ela marcada, o
                entregável fica dentro de casa.
              </p>
            </div>

            <Cartao tom="realce">
              <div
                role="group"
                aria-label="Filtro por visibilidade ao cliente"
                style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--esp-2)' }}
              >
                {BOTOES_DE_VISIBILIDADE.map((botao) => (
                  <Botao
                    key={botao.chave}
                    tom={visibilidade === botao.chave ? 'principal' : 'contorno'}
                    aria-pressed={visibilidade === botao.chave}
                    onClick={() => setVisibilidade(botao.chave)}
                  >
                    {botao.rotulo}
                    {botao.chave === 'sim' ? ` · ${inteiro(visiveis)}` : ''}
                    {botao.chave === 'nao' ? ` · ${inteiro(internos)}` : ''}
                    {botao.chave === 'tudo' ? ` · ${inteiro(todos.length)}` : ''}
                  </Botao>
                ))}
              </div>
            </Cartao>
          </section>

          <section className="secao" aria-labelledby="titulo-lista-entregaveis">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-lista-entregaveis">
                Os entregáveis da casa
              </h2>
              <p className="secao__nota">
                {inteiro(filtrados.length)} de {inteiro(todos.length)} entregáveis com os filtros
                atuais.
              </p>
            </div>

            <Cartao className="secao">
              <div className="grade grade--4">
                <Campo
                  rotulo="Buscar"
                  placeholder="Título, descrição, autoria ou conta"
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
                  rotulo="Tipo"
                  vazio="Todos os tipos"
                  value={tipo}
                  onChange={(evento) => setTipo(evento.target.value)}
                  opcoes={Object.entries(ROTULO_TIPO_ENTREGAVEL).map(([valor, rotulo]) => ({
                    valor,
                    rotulo,
                  }))}
                />
                <Selecao
                  rotulo="Situação"
                  vazio="Todas as situações"
                  value={situacao}
                  onChange={(evento) => setSituacao(evento.target.value)}
                  opcoes={Object.entries(ROTULO_STATUS_ENTREGAVEL).map(([valor, rotulo]) => ({
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
                legenda="Entregáveis com tipo, título, data, autoria, situação e visibilidade ao cliente."
                aoEscolherLinha={(linha) => setAberto(linha)}
                vazioTitulo="Nenhum entregável com estes filtros"
                vazioTexto="Troque a visibilidade, a turma, o tipo ou a situação para ver mais."
              />
            </Cartao>
          </section>
        </>
      ) : null}

      <FichaDoEntregavel entregavel={aberto} aoFechar={() => setAberto(null)} />
    </>
  )
}

// ------------------------------------------------------- ficha do entregável

/**
 * A ficha do entregável, com a descrição e o botão assistido ao lado.
 *
 * O contexto que vai para o assistente é público: tipo, título, turma e
 * encontro. Nota, devolutiva e rubrica são avaliação de pessoa e não passam
 * por aqui, conforme a seção 9 do contrato técnico.
 */
function FichaDoEntregavel({
  entregavel,
  aoFechar,
}: {
  entregavel: EntregavelNaLista | null
  aoFechar: () => void
}) {
  const [descricao, setDescricao] = useState('')

  useEffect(() => {
    setDescricao(entregavel?.descricao ?? '')
  }, [entregavel])

  if (!entregavel) return null

  return (
    <Modal
      aberto={Boolean(entregavel)}
      aoFechar={aoFechar}
      titulo={entregavel.titulo}
      legenda={`${ROTULO_TIPO_ENTREGAVEL[entregavel.tipo]} · ${entregavel.turma_codigo}${
        entregavel.encontro_numero === null ? '' : ` · encontro ${entregavel.encontro_numero}`
      }`}
      tamanho="g"
      fechaNoFundo={false}
      rodape={
        <Botao tom="contorno" onClick={aoFechar}>
          Fechar
        </Botao>
      }
    >
      <div style={{ display: 'grid', gap: 'var(--esp-5)' }}>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--esp-2)' }}>
          <Etiqueta tom={TOM_DA_SITUACAO[entregavel.status]} ponto>
            {ROTULO_STATUS_ENTREGAVEL[entregavel.status]}
          </Etiqueta>
          <Etiqueta tom={entregavel.visivel_ao_cliente ? 'verde' : 'neutra'} ponto>
            {entregavel.visivel_ao_cliente
              ? ROTULO_VISIBILIDADE.sim
              : ROTULO_VISIBILIDADE.nao}
          </Etiqueta>
          <Etiqueta tom="neutra">versão {entregavel.versao}</Etiqueta>
        </div>

        <dl style={{ display: 'grid', gap: 'var(--esp-3)', margin: 0 }}>
          <div>
            <dt className="kicker">Quem produziu</dt>
            <dd style={{ margin: 0 }}>{entregavel.produzido_por_exibido}</dd>
          </div>
          <div>
            <dt className="kicker">Data de entrega</dt>
            <dd style={{ margin: 0 }}>
              {entregavel.data_entrega
                ? data(entregavel.data_entrega)
                : entregavel.prazo
                  ? `ainda não entregue · prazo em ${data(entregavel.prazo)}`
                  : 'ainda não entregue'}
            </dd>
          </div>
          {entregavel.aprovado_em ? (
            <div>
              <dt className="kicker">Aprovado em</dt>
              <dd style={{ margin: 0 }}>{data(entregavel.aprovado_em)}</dd>
            </div>
          ) : null}
          {entregavel.conta_nome ? (
            <div>
              <dt className="kicker">Conta</dt>
              <dd style={{ margin: 0 }}>{entregavel.conta_nome}</dd>
            </div>
          ) : null}
        </dl>

        <CampoTexto
          multiplas_linhas
          rotulo="Descrição do entregável"
          rows={6}
          value={descricao}
          maxLength={1200}
          contador
          valorAtual={descricao}
          onChange={(evento) => setDescricao(evento.target.value)}
          auxilio="O assistente propõe texto e você decide. A gravação no banco entra quando a escrita for ligada nesta tela."
          acessorio={
            <BotaoIA
              campo="texto_livre"
              textoAtual={descricao}
              contexto={{
                tipo: ROTULO_TIPO_ENTREGAVEL[entregavel.tipo],
                titulo: entregavel.titulo,
                turma: entregavel.turma_codigo,
                encontro: entregavel.encontro_numero,
              }}
              aoAceitar={setDescricao}
              rotulo="Sugerir descrição"
            />
          }
        />

        {entregavel.arquivo_url ? (
          <p>
            <span className="kicker">Arquivo</span>
            <br />
            <a href={entregavel.arquivo_url} target="_blank" rel="noreferrer">
              Abrir o arquivo do entregável
            </a>
          </p>
        ) : null}
      </div>
    </Modal>
  )
}
