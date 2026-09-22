import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Alarme,
  Botao,
  Campo,
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
import { useProgramas } from '@/dados/brm'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useSessao } from '@/sessao/contexto'
import {
  EXPLICACAO_MODALIDADE,
  ROTULO_CADENCIA,
  ROTULO_MODALIDADE_TURMA,
  ROTULO_STATUS_PROGRAMA,
  estruturaOficial,
  resumoDaEstrutura,
  type BrmModalidadeTurma,
  type BrmStatusPrograma,
  type ProgramaNaLista,
} from '@/tipos/brm'
import { inteiro, periodo } from '@/tipos/rotulos'

/**
 * Programas do BRM de Valor.
 *
 * O programa é a instância vendida de uma oferta do portfólio: uma oferta, um
 * ano, uma modalidade e um responsável. Cada programa da casa tem estrutura
 * própria, e esta tela mostra a do programa, lida das colunas de carga da
 * migração 0007, nunca adivinhada pelo nome.
 */

const TOM_DA_SITUACAO: Record<BrmStatusPrograma, TomEtiqueta> = {
  planejado: 'marca',
  ativo: 'verde',
  suspenso: 'amarela',
  concluido: 'neutra',
  cancelado: 'vermelha',
}

const TOM_DA_MODALIDADE: Record<BrmModalidadeTurma, TomEtiqueta> = {
  dedicada: 'marca',
  compartilhada: 'realce',
}

export function Programas() {
  const { sessao } = useSessao()
  const consulta = useProgramas()

  const [avisoAberto, setAvisoAberto] = useState(true)
  const [busca, setBusca] = useState('')
  const [modalidade, setModalidade] = useState('')
  const [situacao, setSituacao] = useState('')
  const [ano, setAno] = useState('')
  const [emFoco, setEmFoco] = useState<string | null>(null)

  const todos = useMemo(() => consulta.data?.programas ?? [], [consulta.data])

  const anos = useMemo(
    () => Array.from(new Set(todos.map((programa) => programa.ano))).sort((a, b) => b - a),
    [todos],
  )

  const filtrados = useMemo(() => {
    const procurado = busca.trim().toLowerCase()
    return todos.filter((programa) => {
      if (modalidade && programa.modalidade !== modalidade) return false
      if (situacao && programa.status !== situacao) return false
      if (ano && String(programa.ano) !== ano) return false
      if (!procurado) return true
      return (
        programa.nome.toLowerCase().includes(procurado) ||
        programa.codigo.toLowerCase().includes(procurado) ||
        programa.oferta_nome.toLowerCase().includes(procurado) ||
        (programa.conta_nome ?? '').toLowerCase().includes(procurado)
      )
    })
  }, [todos, busca, modalidade, situacao, ano])

  const emCartaz = emFoco
    ? filtrados.filter((programa) => programa.id === emFoco)
    : filtrados

  const colunas: Array<ColunaTabela<ProgramaNaLista>> = [
    {
      chave: 'programa',
      rotulo: 'Programa',
      conteudo: (linha) => (
        <>
          <strong>{linha.nome}</strong>
          <br />
          <span className="texto-fraco">
            {linha.codigo}
            {linha.conta_nome ? ` · ${linha.conta_nome}` : ''}
          </span>
        </>
      ),
    },
    {
      chave: 'oferta',
      rotulo: 'Oferta',
      conteudo: (linha) => linha.oferta_nome,
    },
    {
      chave: 'ano',
      rotulo: 'Ano',
      alinhamento: 'numero',
      conteudo: (linha) => <span className="numero">{linha.ano}</span>,
    },
    {
      chave: 'modalidade',
      rotulo: 'Modalidade',
      conteudo: (linha) => (
        <Etiqueta tom={TOM_DA_MODALIDADE[linha.modalidade]}>
          {ROTULO_MODALIDADE_TURMA[linha.modalidade]}
        </Etiqueta>
      ),
    },
    {
      chave: 'responsavel',
      rotulo: 'Conselheiro responsável',
      conteudo: (linha) => linha.responsavel_nome,
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta tom={TOM_DA_SITUACAO[linha.status]} ponto>
          {ROTULO_STATUS_PROGRAMA[linha.status]}
        </Etiqueta>
      ),
    },
    {
      chave: 'carga',
      rotulo: 'Carga oficial',
      conteudo: (linha) => <span className="texto-fraco">{resumoDaEstrutura(linha)}</span>,
    },
    {
      chave: 'turmas',
      rotulo: 'Turmas e cadeiras',
      alinhamento: 'numero',
      conteudo: (linha) => (
        <>
          <span className="numero">{inteiro(linha.turmas)}</span>
          <br />
          <span className="texto-fraco">{inteiro(linha.cadeiras_ocupadas)} cadeiras ocupadas</span>
        </>
      ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'BRM de Valor' }, { rotulo: 'Programas' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">BRM de Valor · {sessao.inquilino_nome}</p>
          <h1 className="pagina__titulo">Programas</h1>
          <p className="pagina__lede">
            O programa é a instância vendida de uma oferta do portfólio: uma oferta, um ano, uma
            modalidade e um conselheiro responsável. A estrutura oficial de cada um sai das colunas
            de carga do próprio programa, não do nome dele.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Link className="botao botao--principal" to="/turmas">
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

      {consulta.isPending ? <Carregando texto="Carregando os programas" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="Os programas não carregaram">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <section className="secao" aria-labelledby="titulo-lista-programas">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-lista-programas">
                Os programas da casa
              </h2>
              <p className="secao__nota">
                {inteiro(filtrados.length)} de {inteiro(todos.length)} programas com os filtros
                atuais. Escolha uma linha para ver só a estrutura daquele programa.
              </p>
            </div>

            <Cartao className="secao">
              <div className="grade grade--4">
                <Campo
                  rotulo="Buscar"
                  placeholder="Código, programa, oferta ou conta"
                  value={busca}
                  onChange={(evento) => setBusca(evento.target.value)}
                />
                <Selecao
                  rotulo="Modalidade"
                  vazio="Todas as modalidades"
                  value={modalidade}
                  onChange={(evento) => setModalidade(evento.target.value)}
                  opcoes={[
                    { valor: 'dedicada', rotulo: ROTULO_MODALIDADE_TURMA.dedicada },
                    { valor: 'compartilhada', rotulo: ROTULO_MODALIDADE_TURMA.compartilhada },
                  ]}
                />
                <Selecao
                  rotulo="Situação"
                  vazio="Todas as situações"
                  value={situacao}
                  onChange={(evento) => setSituacao(evento.target.value)}
                  opcoes={Object.entries(ROTULO_STATUS_PROGRAMA).map(([valor, rotulo]) => ({
                    valor,
                    rotulo,
                  }))}
                />
                <Selecao
                  rotulo="Ano"
                  vazio="Todos os anos"
                  value={ano}
                  onChange={(evento) => setAno(evento.target.value)}
                  opcoes={anos.map((numero) => ({ valor: String(numero), rotulo: String(numero) }))}
                />
              </div>
            </Cartao>

            <Cartao semRespiro>
              <Tabela
                colunas={colunas}
                linhas={filtrados}
                chaveDaLinha={(linha) => linha.id}
                legenda="Programas vendidos, com oferta, ano, modalidade, responsável, situação e carga oficial."
                aoEscolherLinha={(linha) =>
                  setEmFoco((atual) => (atual === linha.id ? null : linha.id))
                }
                linhaSelecionada={(linha) => linha.id === emFoco}
                vazioTitulo="Nenhum programa com estes filtros"
                vazioTexto="Afrouxe a busca, o ano ou a situação para ver mais."
              />
            </Cartao>
          </section>

          <section className="secao" aria-labelledby="titulo-estrutura">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-estrutura">
                Estrutura oficial, programa a programa
              </h2>
              <p className="secao__nota">
                Cada programa da casa tem a sua. O que aparece aqui é a carga gravada no programa,
                que é o que a casa vendeu e o que a entrega precisa cumprir.
              </p>
            </div>

            {emFoco ? (
              <p className="secao__nota" style={{ marginBottom: 'var(--esp-4)' }}>
                <Botao tom="discreto" tamanho="p" onClick={() => setEmFoco(null)}>
                  Ver a estrutura de todos os programas
                </Botao>
              </p>
            ) : null}

            {emCartaz.length === 0 ? (
              <Cartao>
                <EstadoVazio
                  titulo="Nenhum programa para mostrar"
                  texto="Nenhum programa passou pelos filtros atuais."
                />
              </Cartao>
            ) : (
              <div className="grade grade--2">
                {emCartaz.map((programa) => (
                  <FichaDaEstrutura key={programa.id} programa={programa} />
                ))}
              </div>
            )}
          </section>
        </>
      ) : null}
    </>
  )
}

// -------------------------------------------- a estrutura oficial do programa

function FichaDaEstrutura({ programa }: { programa: ProgramaNaLista }) {
  const itens = estruturaOficial(programa)

  return (
    <Cartao
      tom="plano"
      titulo={programa.nome}
      legenda={`${programa.codigo} · ${ROTULO_MODALIDADE_TURMA[programa.modalidade]} · ${programa.ano}`}
      acoes={
        <Etiqueta tom={TOM_DA_SITUACAO[programa.status]} ponto>
          {ROTULO_STATUS_PROGRAMA[programa.status]}
        </Etiqueta>
      }
      rodape={
        <span className="texto-fraco">
          {EXPLICACAO_MODALIDADE[programa.modalidade]} Cadência {' '}
          {ROTULO_CADENCIA[programa.cadencia].toLowerCase()} ·{' '}
          {programa.data_inicio && programa.data_fim
            ? periodo(programa.data_inicio, programa.data_fim)
            : 'período a definir'}
        </span>
      }
    >
      {itens.length === 0 ? (
        <p className="texto-fraco">
          A carga oficial deste programa ainda não foi registrada. Sem ela, a entrega não tem
          contra o que ser conferida.
        </p>
      ) : (
        <dl style={{ display: 'grid', gap: 'var(--esp-3)', margin: 0 }}>
          {itens.map((item) => (
            <div
              key={item.chave}
              style={{
                display: 'grid',
                gap: 'var(--esp-1)',
                paddingBottom: 'var(--esp-3)',
                borderBottom: '1px solid var(--cor-linha)',
              }}
            >
              <dt className="kicker">{item.rotulo}</dt>
              <dd style={{ margin: 0 }}>{item.valor}</dd>
            </div>
          ))}
        </dl>
      )}
    </Cartao>
  )
}
