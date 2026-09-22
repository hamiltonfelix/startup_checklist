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
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useParceiros } from '@/dados/prm'
import { data, dinheiro, inteiro } from '@/tipos/rotulos'
import {
  CRITERIO_STATUS_PARCEIRO,
  ROTULO_STATUS_PARCEIRO,
  ROTULO_TIPO_PARCEIRO,
  type ParceiroNaLista,
  type ParceiroStatus,
} from '@/tipos/prm'

/**
 * Lista de parceiros do PRM de Valor.
 *
 * Três leituras numa tela só: em que ponto do credenciamento cada parceiro
 * está, quem responde por ele dentro da casa, e o que ele trouxe. Este último
 * é o que importa na reunião de canal: quantas indicações registrou, quantas
 * viraram negócio, quanto isso gerou e quanto ele recebeu.
 *
 * Coluna que o banco não entregou aparece como sem valor. Quem recorta é a
 * política de linha, conforme as seções 8 e 9 do contrato técnico. Esta tela
 * não tem, e não pode ter, condição de perfil.
 */

const TOM_DO_STATUS: Record<ParceiroStatus, 'neutra' | 'marca' | 'verde' | 'amarela' | 'vermelha'> =
  {
    prospecto: 'neutra',
    em_credenciamento: 'amarela',
    ativo: 'verde',
    suspenso: 'vermelha',
    encerrado: 'neutra',
  }

export function Parceiros() {
  const navegar = useNavigate()
  const consulta = useParceiros()
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [situacao, setSituacao] = useState('')
  const [busca, setBusca] = useState('')

  const parceiros = useMemo(() => consulta.data?.parceiros ?? [], [consulta.data])

  const visiveis = useMemo(() => {
    const termo = busca.trim().toLowerCase()
    return parceiros.filter((linha) => {
      if (situacao && linha.status !== situacao) return false
      if (!termo) return true
      const alvo = `${linha.nome} ${linha.cidade ?? ''} ${linha.responsavel_interno_nome ?? ''}`
      return alvo.toLowerCase().includes(termo)
    })
  }, [parceiros, situacao, busca])

  const placar = useMemo(() => {
    const credenciados = parceiros.filter((linha) => linha.status === 'ativo').length
    const emCredenciamento = parceiros.filter(
      (linha) => linha.status === 'em_credenciamento' || linha.status === 'prospecto',
    ).length
    const emAberto = parceiros.reduce((total, linha) => total + linha.indicacoes_em_aberto, 0)
    const gerado = parceiros.reduce((total, linha) => total + (linha.valor_gerado ?? 0), 0)
    return { credenciados, emCredenciamento, emAberto, gerado }
  }, [parceiros])

  const colunas: Array<ColunaTabela<ParceiroNaLista>> = [
    {
      chave: 'parceiro',
      rotulo: 'Parceiro',
      ordenavel: false,
      conteudo: (linha) => (
        <>
          <strong>{linha.nome}</strong>
          <br />
          <span className="texto-fraco">
            {ROTULO_TIPO_PARCEIRO[linha.tipo]}
            {linha.cidade ? ` · ${linha.cidade}` : ''}
            {linha.uf ? ` · ${linha.uf}` : ''}
          </span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Credenciamento',
      conteudo: (linha) => (
        <>
          <Etiqueta tom={TOM_DO_STATUS[linha.status]} ponto>
            {ROTULO_STATUS_PARCEIRO[linha.status]}
          </Etiqueta>
          <br />
          <span className="texto-fraco">
            {linha.credenciado_em
              ? `Desde ${data(linha.credenciado_em)}`
              : 'Ainda sem data de credenciamento'}
          </span>
        </>
      ),
    },
    {
      chave: 'responsavel',
      rotulo: 'Responsável interno',
      conteudo: (linha) =>
        linha.responsavel_interno_nome ?? (
          <span className="texto-fraco">Sem responsável definido</span>
        ),
    },
    {
      chave: 'indicacoes',
      rotulo: 'O que trouxe',
      alinhamento: 'numero',
      conteudo: (linha) => (
        <>
          <span className="numero">{inteiro(linha.indicacoes)}</span>{' '}
          {linha.indicacoes === 1 ? 'indicação' : 'indicações'}
          <br />
          <span className="texto-fraco">
            {inteiro(linha.indicacoes_convertidas)} em negócio · {inteiro(linha.indicacoes_em_aberto)}{' '}
            esperando decisão
          </span>
        </>
      ),
    },
    {
      chave: 'gerado',
      rotulo: 'Valor gerado',
      alinhamento: 'numero',
      conteudo: (linha) => dinheiro(linha.valor_gerado),
    },
    {
      chave: 'comissao',
      rotulo: 'Comissão dele',
      alinhamento: 'numero',
      conteudo: (linha) => dinheiro(linha.comissao_total),
    },
    {
      chave: 'protecao',
      rotulo: 'Proteção',
      alinhamento: 'numero',
      conteudo: (linha) => `${inteiro(linha.prazo_protecao_dias)} dias`,
    },
    {
      chave: 'acoes',
      rotulo: 'Ficha',
      alinhamento: 'acoes',
      conteudo: (linha) => (
        <Botao
          tom="contorno"
          tamanho="p"
          onClick={(evento) => {
            evento.stopPropagation()
            navegar(`/parceiros/${linha.id}`)
          }}
        >
          Abrir
        </Botao>
      ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'PRM de Valor' }, { rotulo: 'Parceiros' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">PRM de Valor</p>
          <h1 className="pagina__titulo">Parceiros</h1>
          <p className="pagina__lede">
            O canal de indicação da casa: em que ponto do credenciamento cada um está, quem responde
            por ele por dentro, e o que ele já trouxe.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Botao tom="principal">Cadastrar parceiro</Botao>
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

      {consulta.isPending ? <Carregando texto="Carregando os parceiros" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A lista não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <section className="secao" aria-labelledby="titulo-placar-parceiros">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-placar-parceiros">
                O canal em quatro números
              </h2>
              <p className="secao__nota">
                Coluna que o banco não entregou aparece como sem valor. Quem recorta é a política de
                linha, nunca esta tela.
              </p>
            </div>

            <div className="grade grade--4">
              <article className="cartao cartao--marca linha-pipeline">
                <p className="linha-pipeline__rotulo">Credenciados e ativos</p>
                <p className="linha-pipeline__valor">{inteiro(placar.credenciados)}</p>
                <p className="linha-pipeline__detalhe">
                  Podem indicar e receber comissão pela vida do contrato.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Em credenciamento</p>
                <p className="linha-pipeline__valor">{inteiro(placar.emCredenciamento)}</p>
                <p className="linha-pipeline__detalhe">
                  Ainda não podem indicar. Falta documentação, treinamento ou a data de
                  credenciamento.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Indicações esperando decisão</p>
                <p className="linha-pipeline__valor">{inteiro(placar.emAberto)}</p>
                <p className="linha-pipeline__detalhe">
                  A casa ainda não aceitou nem recusou. O prazo de proteção só começa no aceite.
                </p>
              </article>

              <article className="cartao cartao--realce linha-pipeline linha-pipeline--auditado">
                <p className="linha-pipeline__rotulo">Valor gerado pelo canal</p>
                <p className="linha-pipeline__valor">{dinheiro(placar.gerado)}</p>
                <p className="linha-pipeline__detalhe">
                  Soma dos negócios nascidos de indicação aceita.
                </p>
              </article>
            </div>
          </section>

          <section className="secao" aria-labelledby="titulo-lista-parceiros">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-lista-parceiros">
                Todos os parceiros
              </h2>
              <p className="secao__nota">
                {inteiro(visiveis.length)} de {inteiro(parceiros.length)} na lista.
              </p>
            </div>

            <Cartao>
              <div className="grade grade--3">
                <Selecao
                  rotulo="Situação de credenciamento"
                  vazio="Todas as situações"
                  value={situacao}
                  onChange={(evento) => setSituacao(evento.target.value)}
                  opcoes={(Object.keys(ROTULO_STATUS_PARCEIRO) as ParceiroStatus[]).map(
                    (chave) => ({ valor: chave, rotulo: ROTULO_STATUS_PARCEIRO[chave] }),
                  )}
                  auxilio={
                    situacao
                      ? CRITERIO_STATUS_PARCEIRO[situacao as ParceiroStatus]
                      : 'Escolha uma situação para ver o que ela significa.'
                  }
                />
                <Campo
                  rotulo="Buscar"
                  placeholder="Nome, cidade ou responsável interno"
                  value={busca}
                  onChange={(evento) => setBusca(evento.target.value)}
                  auxilio="A busca acontece na lista que o banco já entregou."
                />
              </div>
            </Cartao>

            <Cartao semRespiro className="secao">
              <Tabela
                colunas={colunas}
                linhas={visiveis}
                chaveDaLinha={(linha) => linha.id}
                legenda="Parceiros do canal, com a situação de credenciamento, o responsável interno e o que cada um trouxe."
                aoEscolherLinha={(linha) => navegar(`/parceiros/${linha.id}`)}
                vazioTitulo="Nenhum parceiro nesta faixa"
                vazioTexto="Troque a situação ou limpe a busca para ver o canal inteiro."
                vazioAcoes={
                  <Botao
                    tom="contorno"
                    onClick={() => {
                      setSituacao('')
                      setBusca('')
                    }}
                  >
                    Limpar filtros
                  </Botao>
                }
              />
            </Cartao>
          </section>
        </>
      ) : null}
    </>
  )
}
