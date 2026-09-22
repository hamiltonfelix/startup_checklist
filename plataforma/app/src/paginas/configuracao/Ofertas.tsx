import { useMemo, useState } from 'react'
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
} from '@/componentes/indice'
import { AVISO_SEM_BANCO, temBanco } from '@/dados/cliente'
import { useOfertas } from '@/dados/configuracao'
import type { ModalidadeOferta, NivelContrato } from '@/tipos/dominio'
import { inteiro, ROTULO_MODALIDADE, ROTULO_NIVEL } from '@/tipos/rotulos'
import { EXPLICACAO_NIVEL, type OfertaNaTela } from '@/tipos/configuracao'

/**
 * Catálogo do portfólio.
 *
 * Cada linha traz o que a casa vende: código, nome, família, modalidade,
 * níveis de contrato aceitos, se gera turma, para quem é e como é a estrutura.
 *
 * A regra que esta tela existe para deixar clara: oferta inativa continua no
 * catálogo. Ela não some, porque o histórico de quem já comprou depende dela.
 * O que a inativação faz é tirá-la da lista de sugestões ao montar negócio
 * novo. Duas coisas diferentes, e a tela diz isso em toda linha inativa.
 */

const MODALIDADES: ModalidadeOferta[] = ['pontual', 'recorrente', 'pontual_com_sustentacao']
const NIVEIS: NivelContrato[] = ['n1', 'n2', 'n3']

export function Ofertas() {
  const consulta = useOfertas()
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [filtroFamilia, setFiltroFamilia] = useState('')
  const [filtroSituacao, setFiltroSituacao] = useState('')
  const [busca, setBusca] = useState('')
  const [emEdicao, setEmEdicao] = useState<OfertaNaTela | null>(null)

  const ofertas = useMemo(() => consulta.data?.ofertas ?? [], [consulta.data])

  const familias = useMemo(() => {
    const vistas = new Set(ofertas.map((oferta) => oferta.familia))
    return [...vistas].sort((a, b) => a.localeCompare(b, 'pt-BR'))
  }, [ofertas])

  const visiveis = useMemo(() => {
    const termo = busca.trim().toLowerCase()
    return ofertas.filter((oferta) => {
      if (filtroFamilia && oferta.familia !== filtroFamilia) return false
      if (filtroSituacao === 'ativa' && !oferta.ativa) return false
      if (filtroSituacao === 'inativa' && oferta.ativa) return false
      if (filtroSituacao === 'sugerida' && !oferta.sugerida) return false
      if (!termo) return true
      return `${oferta.nome} ${oferta.codigo} ${oferta.publico_alvo ?? ''}`
        .toLowerCase()
        .includes(termo)
    })
  }, [ofertas, filtroFamilia, filtroSituacao, busca])

  const placar = useMemo(() => {
    const ativas = ofertas.filter((oferta) => oferta.ativa).length
    const sugeridas = ofertas.filter((oferta) => oferta.ativa && oferta.sugerida).length
    const inativas = ofertas.filter((oferta) => !oferta.ativa).length
    const inativasComHistorico = ofertas.filter(
      (oferta) => !oferta.ativa && oferta.negocios_no_historico > 0,
    ).length
    return { ativas, sugeridas, inativas, inativasComHistorico }
  }, [ofertas])

  const colunas: Array<ColunaTabela<OfertaNaTela>> = [
    {
      chave: 'oferta',
      rotulo: 'Oferta',
      conteudo: (oferta) => (
        <>
          <strong>{oferta.nome}</strong>
          <br />
          <span className="texto-fraco">
            {oferta.codigo} · {oferta.familia}
          </span>
        </>
      ),
    },
    {
      chave: 'modalidade',
      rotulo: 'Modalidade',
      conteudo: (oferta) => (
        <>
          <Etiqueta tom="marca">{ROTULO_MODALIDADE[oferta.modalidade]}</Etiqueta>
          <br />
          <span className="texto-fraco">
            {oferta.gera_turma ? 'Gera turma' : 'Não gera turma'}
          </span>
        </>
      ),
    },
    {
      chave: 'niveis',
      rotulo: 'Níveis aceitos',
      conteudo: (oferta) => (
        <>
          {oferta.niveis_aceitos.map((nivel) => (
            <Etiqueta key={nivel} tom="neutra">
              {ROTULO_NIVEL[nivel]}
            </Etiqueta>
          ))}
        </>
      ),
    },
    {
      chave: 'publico',
      rotulo: 'Público',
      conteudo: (oferta) => oferta.publico_alvo ?? <span className="texto-fraco">a confirmar</span>,
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (oferta) => <SituacaoDaOferta oferta={oferta} />,
    },
    {
      chave: 'acoes',
      rotulo: 'Editar',
      alinhamento: 'acoes',
      conteudo: (oferta) => (
        <Botao
          tom="contorno"
          tamanho="p"
          onClick={(evento) => {
            evento.stopPropagation()
            setEmEdicao(oferta)
          }}
        >
          Abrir
        </Botao>
      ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'Configuração' }, { rotulo: 'Ofertas' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Configuração</p>
          <h1 className="pagina__titulo">Ofertas</h1>
          <p className="pagina__lede">
            O catálogo do portfólio: o que a casa vende, em que modalidade, com que níveis de
            contrato, para quem, e se aquilo forma turma.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Botao tom="principal" disabled={!temBanco()}>
            Nova oferta
          </Botao>
        </div>
      </div>

      <Alarme tom="informacao" titulo="Oferta inativa não some do catálogo" className="secao">
        <p>
          Inativar uma oferta faz uma coisa só: ela deixa de aparecer como sugestão ao montar
          negócio novo. Ela continua no catálogo, continua ligada a todo negócio e a todo contrato
          que já a usaram, e continua aparecendo no histórico da conta. Nada é apagado nesta
          plataforma.
        </p>
      </Alarme>

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

      {consulta.isPending ? <Carregando texto="Carregando o catálogo" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="O catálogo não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <section className="secao" aria-labelledby="titulo-placar-ofertas">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-placar-ofertas">
                O catálogo em quatro números
              </h2>
            </div>

            <div className="grade grade--4">
              <article className="cartao cartao--marca linha-pipeline">
                <p className="linha-pipeline__rotulo">Ativas</p>
                <p className="linha-pipeline__valor">{inteiro(placar.ativas)}</p>
                <p className="linha-pipeline__detalhe">
                  Podem ser escolhidas em negócio novo e em contrato novo.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Sugeridas</p>
                <p className="linha-pipeline__valor">{inteiro(placar.sugeridas)}</p>
                <p className="linha-pipeline__detalhe">
                  Aparecem antes das demais na hora de montar o negócio.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Inativas</p>
                <p className="linha-pipeline__valor">{inteiro(placar.inativas)}</p>
                <p className="linha-pipeline__detalhe">
                  Fora da sugestão, dentro do catálogo. Nenhuma delas foi apagada.
                </p>
              </article>

              <article className="cartao cartao--realce linha-pipeline linha-pipeline--auditado">
                <p className="linha-pipeline__rotulo">Inativas com histórico</p>
                <p className="linha-pipeline__valor">{inteiro(placar.inativasComHistorico)}</p>
                <p className="linha-pipeline__detalhe">
                  Já foram vendidas. É exatamente por elas que oferta inativa nunca é removida.
                </p>
              </article>
            </div>
          </section>

          <section className="secao" aria-labelledby="titulo-lista-ofertas">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-lista-ofertas">
                Todas as ofertas
              </h2>
              <p className="secao__nota">
                {inteiro(visiveis.length)} de {inteiro(ofertas.length)} no catálogo.
              </p>
            </div>

            <Cartao>
              <div className="grade grade--3">
                <Selecao
                  rotulo="Família"
                  vazio="Todas as famílias"
                  value={filtroFamilia}
                  onChange={(evento) => setFiltroFamilia(evento.target.value)}
                  opcoes={familias.map((familia) => ({ valor: familia, rotulo: familia }))}
                />
                <Selecao
                  rotulo="Situação"
                  vazio="Ativas e inativas"
                  value={filtroSituacao}
                  onChange={(evento) => setFiltroSituacao(evento.target.value)}
                  opcoes={[
                    { valor: 'ativa', rotulo: 'Somente ativas' },
                    { valor: 'sugerida', rotulo: 'Somente sugeridas' },
                    { valor: 'inativa', rotulo: 'Somente inativas' },
                  ]}
                />
                <Campo
                  rotulo="Buscar"
                  placeholder="Nome, código ou público"
                  value={busca}
                  onChange={(evento) => setBusca(evento.target.value)}
                />
              </div>
            </Cartao>

            <Cartao semRespiro className="secao">
              <Tabela
                colunas={colunas}
                linhas={visiveis}
                chaveDaLinha={(oferta) => oferta.id}
                legenda="Catálogo do portfólio, com modalidade, níveis aceitos, público e situação."
                aoEscolherLinha={(oferta) => setEmEdicao(oferta)}
                vazioTitulo="Nenhuma oferta nesta faixa"
                vazioTexto="Troque a família ou a situação para ver o catálogo inteiro."
                vazioAcoes={
                  <Botao
                    tom="contorno"
                    onClick={() => {
                      setFiltroFamilia('')
                      setFiltroSituacao('')
                      setBusca('')
                    }}
                  >
                    Limpar filtros
                  </Botao>
                }
              />
            </Cartao>
          </section>

          <NiveisDeContrato />

          <JanelaDaOferta oferta={emEdicao} aoFechar={() => setEmEdicao(null)} />
        </>
      ) : null}
    </>
  )
}

// ---------------------------------------------------- situação em tela

function SituacaoDaOferta({ oferta }: { oferta: OfertaNaTela }) {
  if (!oferta.ativa) {
    return (
      <>
        <Etiqueta tom="amarela" ponto>
          Inativa
        </Etiqueta>
        <br />
        <span className="texto-fraco">
          Continua no catálogo para o histórico. Não aparece como sugestão.
          {oferta.negocios_no_historico > 0
            ? ` ${inteiro(oferta.negocios_no_historico)} ${oferta.negocios_no_historico === 1 ? 'negócio' : 'negócios'} já a usaram.`
            : ''}
        </span>
      </>
    )
  }

  return (
    <>
      <Etiqueta tom="verde" ponto>
        Ativa
      </Etiqueta>
      {oferta.sugerida ? (
        <>
          {' '}
          <Etiqueta tom="realce">Sugerida</Etiqueta>
        </>
      ) : null}
      <br />
      <span className="texto-fraco">
        {oferta.sugerida
          ? 'Aparece entre as primeiras ao montar negócio.'
          : 'Disponível, mas fora da lista de sugestões.'}
      </span>
    </>
  )
}

// -------------------------------------------------- os níveis de contrato

function NiveisDeContrato() {
  return (
    <section className="secao" aria-labelledby="titulo-niveis">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-niveis">
          Os três níveis de contrato
        </h2>
        <p className="secao__nota">
          Cada oferta declara quais níveis aceita. O nível escolhido no contrato precisa estar entre
          eles.
        </p>
      </div>

      <div className="grade grade--3">
        {NIVEIS.map((nivel) => (
          <Cartao key={nivel} titulo={ROTULO_NIVEL[nivel]}>
            <p>{EXPLICACAO_NIVEL[nivel]}</p>
          </Cartao>
        ))}
      </div>
    </section>
  )
}

// ------------------------------------------------------ a janela de edição

function JanelaDaOferta({
  oferta,
  aoFechar,
}: {
  oferta: OfertaNaTela | null
  aoFechar: () => void
}) {
  const [carregada, setCarregada] = useState<string | null>(null)
  const [nome, setNome] = useState('')
  const [familia, setFamilia] = useState('')
  const [modalidade, setModalidade] = useState<ModalidadeOferta>('pontual')
  const [niveis, setNiveis] = useState<NivelContrato[]>([])
  const [geraTurma, setGeraTurma] = useState(false)
  const [publico, setPublico] = useState('')
  const [estrutura, setEstrutura] = useState('')
  const [ativa, setAtiva] = useState(true)
  const [sugerida, setSugerida] = useState(true)

  if (!oferta) return null

  // Primeira abertura desta oferta: o formulário parte do que está gravado.
  if (carregada !== oferta.id) {
    setCarregada(oferta.id)
    setNome(oferta.nome)
    setFamilia(oferta.familia)
    setModalidade(oferta.modalidade)
    setNiveis(oferta.niveis_aceitos)
    setGeraTurma(oferta.gera_turma)
    setPublico(oferta.publico_alvo ?? '')
    setEstrutura(oferta.estrutura ?? '')
    setAtiva(oferta.ativa)
    setSugerida(oferta.sugerida)
  }

  function alternarNivel(nivel: NivelContrato) {
    setNiveis((anterior) =>
      anterior.includes(nivel) ? anterior.filter((item) => item !== nivel) : [...anterior, nivel],
    )
  }

  return (
    <Modal
      aberto
      aoFechar={aoFechar}
      titulo={oferta.nome}
      legenda={`Código ${oferta.codigo}. O código não muda, porque é por ele que o histórico se liga à oferta.`}
      tamanho="g"
      fechaNoFundo={false}
      rodape={
        <>
          <Botao tom="discreto" onClick={aoFechar}>
            Cancelar
          </Botao>
          <Botao tom="principal" disabled={!temBanco()}>
            Salvar oferta
          </Botao>
        </>
      }
    >
      {!temBanco() ? (
        <Alarme tom="amarelo" titulo="Edição não gravada nesta máquina">
          O banco ainda não está ligado aqui, então salvar fica desligado. A janela mostra
          exatamente o que será gravado quando a conexão existir.
        </Alarme>
      ) : null}

      <Campo
        rotulo="Nome da oferta"
        obrigatorio
        value={nome}
        onChange={(evento) => setNome(evento.target.value)}
      />

      <Campo
        rotulo="Família"
        obrigatorio
        value={familia}
        onChange={(evento) => setFamilia(evento.target.value)}
        auxilio="Programas de Valor, Serviços, ou a família que a casa criar."
      />

      <Selecao
        rotulo="Modalidade"
        obrigatorio
        value={modalidade}
        onChange={(evento) => setModalidade(evento.target.value as ModalidadeOferta)}
        opcoes={MODALIDADES.map((chave) => ({ valor: chave, rotulo: ROTULO_MODALIDADE[chave] }))}
      />

      <Cartao tom="plano" titulo="Níveis de contrato aceitos">
        {NIVEIS.map((nivel) => (
          <div key={nivel}>
            <label className="campo__rotulo">
              <input
                type="checkbox"
                checked={niveis.includes(nivel)}
                onChange={() => alternarNivel(nivel)}
              />{' '}
              {ROTULO_NIVEL[nivel]}
            </label>
            <p className="campo__auxilio">{EXPLICACAO_NIVEL[nivel]}</p>
          </div>
        ))}
        {niveis.length === 0 ? (
          <p className="campo__erro" role="alert">
            <span aria-hidden="true">!</span>A oferta precisa aceitar pelo menos um nível.
          </p>
        ) : null}
      </Cartao>

      <Campo
        rotulo="Público"
        value={publico}
        onChange={(evento) => setPublico(evento.target.value)}
        auxilio="Para quem esta oferta é. Uma frase, com o cargo ou o tipo de time."
      />

      <CampoTexto
        multiplas_linhas
        rotulo="Estrutura da oferta"
        rows={5}
        maxLength={800}
        contador
        valorAtual={estrutura}
        value={estrutura}
        onChange={(evento) => setEstrutura(evento.target.value)}
        auxilio="Como a entrega acontece: quantos encontros, com que ritmo, por quanto tempo."
        acessorio={
          <BotaoIA
            campo="texto_livre"
            textoAtual={estrutura}
            contexto={{
              oferta: nome,
              familia,
              modalidade: ROTULO_MODALIDADE[modalidade],
              publico_alvo: publico || null,
            }}
            aoAceitar={setEstrutura}
            rotulo="Sugerir descrição"
          />
        }
      />

      <label className="campo__rotulo">
        <input
          type="checkbox"
          checked={geraTurma}
          onChange={(evento) => setGeraTurma(evento.target.checked)}
        />{' '}
        Esta oferta gera turma
      </label>
      <p className="campo__auxilio">
        Ligado, o contrato desta oferta abre turma no BRM de Valor, com calendário e participantes.
      </p>

      <label className="campo__rotulo">
        <input
          type="checkbox"
          checked={ativa}
          onChange={(evento) => {
            setAtiva(evento.target.checked)
            // Inativa nunca é sugerida. As duas chaves andam juntas.
            if (!evento.target.checked) setSugerida(false)
          }}
        />{' '}
        Oferta ativa
      </label>
      <p className="campo__auxilio">
        Desligar não apaga nada. A oferta sai da sugestão e continua no catálogo, ligada a todo
        negócio e contrato que já a usaram.
      </p>

      <label className="campo__rotulo">
        <input
          type="checkbox"
          checked={sugerida}
          disabled={!ativa}
          onChange={(evento) => setSugerida(evento.target.checked)}
        />{' '}
        Aparece como sugestão
      </label>
      <p className="campo__auxilio">
        {ativa
          ? 'Ligado, esta oferta aparece entre as primeiras ao montar negócio.'
          : 'Oferta inativa não pode ser sugerida. Reative antes de marcar esta caixa.'}
      </p>

      {oferta.negocios_no_historico > 0 ? (
        <Alarme tom="informacao" titulo="Esta oferta tem histórico">
          {inteiro(oferta.negocios_no_historico)}{' '}
          {oferta.negocios_no_historico === 1 ? 'negócio já usou' : 'negócios já usaram'} esta
          oferta. Inativar é seguro: nenhum deles perde a ligação.
        </Alarme>
      ) : null}
    </Modal>
  )
}
