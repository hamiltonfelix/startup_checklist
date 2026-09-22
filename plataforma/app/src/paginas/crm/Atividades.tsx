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
} from '@/componentes/indice'
import { useConcluirAtividade, useMoverAtividade, useQuadroDeAtividades } from '@/dados/crm'
import { AvisoDeFonte } from '@/paginas/crm/Negocios'
import {
  EXPLICACAO_GRUPO_CAIXA,
  ORDEM_ESTADO_GTD,
  ROTULO_ENERGIA,
  ROTULO_ESTADO_GTD,
  ROTULO_PRIORIDADE,
  tempoEstimado,
  textoOuAusente,
  type ColunaDoQuadro,
  type EnergiaAtividade,
  type EstadoGtd,
  type GrupoCaixaDeEntrada,
  type LinhaAtividade,
  type LinhaCaixaDeEntrada,
  type QuadroDeAtividades,
} from '@/tipos/crm'
import { data, inteiro } from '@/tipos/rotulos'

type Visao = 'quadro' | 'gtd'

/** Os quatro montes da caixa de entrada, na ordem que o banco entrega. */
const MONTES: GrupoCaixaDeEntrada[] = [
  'entrou_hoje',
  'vencida',
  'vence_na_janela',
  'aguardando_terceiro',
]

/**
 * A mesma tabela de atividades em duas visões, do jeito que o banco entrega.
 *
 * O quadro desenha as colunas configuráveis de `valor.colunas_kanban`, e cada
 * coluna aponta para um estado do método GTD. A lista do método mostra os
 * estados e os quatro montes de `valor.caixa_de_entrada`. Nenhuma das duas
 * duplica dado: é a mesma tabela lida de dois jeitos.
 */
export function Atividades() {
  const consulta = useQuadroDeAtividades()
  const mover = useMoverAtividade()
  const concluir = useConcluirAtividade()

  const [visao, setVisao] = useState<Visao>('quadro')
  const [contexto, setContexto] = useState('')
  const [energia, setEnergia] = useState('')
  const [avisoAberto, setAvisoAberto] = useState(true)

  const quadro: QuadroDeAtividades | null = consulta.data?.dados ?? null

  const atividades = useMemo(() => {
    const lista = quadro?.atividades ?? []
    return lista.filter((linha) => {
      if (contexto !== '' && linha.contexto_id !== contexto) return false
      if (energia !== '' && linha.energia !== energia) return false
      return true
    })
  }, [quadro, contexto, energia])

  const nasceuAProxima = concluir.isSuccess && concluir.data.era_recorrente && avisoAberto

  return (
    <>
      <Migalhas itens={[{ rotulo: 'CRM de Valor', para: '/painel' }, { rotulo: 'Atividades' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">CRM de Valor</p>
          <h1 className="pagina__titulo">Atividades</h1>
          <p className="pagina__lede">
            Próximos passos com data e dono. Quadro e método GTD leem a mesma tabela.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      <AvisoDeFonte deExemplo={consulta.data?.deExemplo} />

      {nasceuAProxima ? (
        <Alarme
          tom="verde"
          titulo="A próxima ocorrência já nasceu"
          className="secao"
          aoFechar={() => setAvisoAberto(false)}
        >
          A atividade {concluir.data.titulo} pertence à série{' '}
          {textoOuAusente(concluir.data.recorrencia_nome, 'de repetição')}. Ao concluir, a próxima
          ocorrência foi criada e já aparece na lista, com o mesmo roteiro.
        </Alarme>
      ) : null}

      {mover.isError ? (
        <Alarme tom="vermelho" titulo="A atividade não mudou de coluna" className="secao">
          {mover.error.message}
        </Alarme>
      ) : null}

      {concluir.isError ? (
        <Alarme tom="vermelho" titulo="A conclusão não foi gravada" className="secao">
          {concluir.error.message}
        </Alarme>
      ) : null}

      {consulta.isPending ? <Carregando texto="Carregando as atividades" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="As atividades não carregaram">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {quadro ? (
        <>
          <Cartao titulo="Filtros" className="secao">
            <div className="grade grade--3">
              <Selecao
                rotulo="Contexto"
                vazio="Todos os contextos"
                value={contexto}
                onChange={(evento) => setContexto(evento.target.value)}
                opcoes={quadro.contextos.map((linha) => ({
                  valor: linha.id,
                  rotulo: `${linha.codigo} · ${linha.rotulo}`,
                }))}
              />
              <Selecao
                rotulo="Energia"
                vazio="Toda energia"
                value={energia}
                onChange={(evento) => setEnergia(evento.target.value)}
                opcoes={(['alta', 'media', 'baixa'] as EnergiaAtividade[]).map((nivel) => ({
                  valor: nivel,
                  rotulo: ROTULO_ENERGIA[nivel],
                }))}
              />
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: 'var(--esp-2)' }}>
                <Botao
                  tom={visao === 'quadro' ? 'principal' : 'contorno'}
                  aria-pressed={visao === 'quadro'}
                  onClick={() => setVisao('quadro')}
                >
                  Quadro
                </Botao>
                <Botao
                  tom={visao === 'gtd' ? 'principal' : 'contorno'}
                  aria-pressed={visao === 'gtd'}
                  onClick={() => setVisao('gtd')}
                >
                  Método GTD
                </Botao>
              </div>
            </div>
          </Cartao>

          {visao === 'quadro' ? (
            <Quadro
              colunas={quadro.colunas}
              atividades={atividades}
              deExemplo={consulta.data?.deExemplo ?? false}
              aoMover={(atividade_id, estado) => {
                setAvisoAberto(true)
                mover.mutate({ atividade_id, estado })
              }}
              aoConcluir={(atividade) => {
                setAvisoAberto(true)
                concluir.mutate(atividade)
              }}
            />
          ) : (
            <MetodoGtd
              atividades={atividades}
              caixa={quadro.caixa}
              janela={quadro.janela_dias}
              aoMover={(atividade_id, estado) => {
                setAvisoAberto(true)
                mover.mutate({ atividade_id, estado })
              }}
              aoConcluir={(atividade) => {
                setAvisoAberto(true)
                concluir.mutate(atividade)
              }}
            />
          )}
        </>
      ) : null}
    </>
  )
}

// --------------------------------------------------------------- o quadro

const ESTILO_COLUNA: CSSProperties = {
  minWidth: '264px',
  maxWidth: '264px',
  display: 'flex',
  flexDirection: 'column',
  gap: 'var(--esp-2)',
  background: 'var(--cor-fundo-recuado)',
  border: '1px solid var(--cor-linha)',
  borderRadius: 'var(--raio-g)',
  padding: 'var(--esp-3)',
}

function Quadro({
  colunas,
  atividades,
  deExemplo,
  aoMover,
  aoConcluir,
}: {
  colunas: ColunaDoQuadro[]
  atividades: LinhaAtividade[]
  deExemplo: boolean
  aoMover: (atividadeId: string, estado: EstadoGtd) => void
  aoConcluir: (atividade: LinhaAtividade) => void
}) {
  const [arrastando, setArrastando] = useState<string | null>(null)
  const [alvo, setAlvo] = useState<string | null>(null)

  if (colunas.length === 0) {
    return (
      <Cartao>
        <EstadoVazio
          titulo="Nenhuma coluna configurada"
          texto="O quadro é configuração da casa, em valor.colunas_kanban. Enquanto não houver coluna ativa, use a visão do método GTD."
        />
      </Cartao>
    )
  }

  function soltar(evento: DragEvent<HTMLDivElement>, coluna: ColunaDoQuadro) {
    evento.preventDefault()
    const identificador = evento.dataTransfer.getData('text/plain') || arrastando
    setArrastando(null)
    setAlvo(null)
    if (!identificador) return
    const atividade = atividades.find((linha) => linha.id === identificador)
    if (!atividade || atividade.estado === coluna.estado_gtd) return
    aoMover(identificador, coluna.estado_gtd)
  }

  return (
    <section className="secao" aria-labelledby="titulo-quadro-atividades">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-quadro-atividades">
          Quadro por coluna configurável
        </h2>
        <p className="secao__nota">
          Cada coluna aponta para um estado do método GTD, então o quadro e a lista nunca divergem.
          {deExemplo ? ' Sem banco ligado, arrastar muda apenas a cópia que está na tela.' : ''}
        </p>
      </div>

      <div style={{ display: 'flex', gap: 'var(--esp-3)', overflowX: 'auto', paddingBottom: 'var(--esp-4)' }}>
        {colunas.map((coluna) => {
          const daColuna = atividades.filter((linha) => linha.estado === coluna.estado_gtd)
          const estourouWip = coluna.limite_wip !== null && daColuna.length > coluna.limite_wip

          return (
            <div
              key={coluna.id}
              style={{
                ...ESTILO_COLUNA,
                borderColor: alvo === coluna.id ? 'var(--cor-marca)' : 'var(--cor-linha)',
                background: alvo === coluna.id ? 'var(--cor-marca-suave)' : 'var(--cor-fundo-recuado)',
              }}
              onDragOver={(evento) => {
                evento.preventDefault()
                setAlvo(coluna.id)
              }}
              onDragLeave={() => setAlvo((atual) => (atual === coluna.id ? null : atual))}
              onDrop={(evento) => soltar(evento, coluna)}
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
                  {coluna.nome}
                </p>
                <p style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
                  {inteiro(daColuna.length)}{' '}
                  {daColuna.length === 1 ? 'atividade' : 'atividades'}
                  {coluna.limite_wip !== null ? ` · limite ${inteiro(coluna.limite_wip)}` : ''}
                </p>
                {estourouWip ? (
                  <Etiqueta tom="vermelha" ponto>
                    Limite de trabalho em andamento estourado
                  </Etiqueta>
                ) : null}
              </header>

              {daColuna.length === 0 ? (
                <p
                  style={{
                    fontSize: 'var(--texto-pp)',
                    color: 'var(--cor-texto-tenue)',
                    padding: 'var(--esp-4) 0',
                    textAlign: 'center',
                  }}
                >
                  Nenhuma atividade nesta coluna
                </p>
              ) : null}

              {daColuna.map((atividade) => (
                <FichaDeAtividade
                  key={atividade.id}
                  atividade={atividade}
                  arrastavel
                  arrastando={arrastando === atividade.id}
                  aoComecar={() => setArrastando(atividade.id)}
                  aoTerminar={() => {
                    setArrastando(null)
                    setAlvo(null)
                  }}
                  aoMover={aoMover}
                  aoConcluir={aoConcluir}
                />
              ))}
            </div>
          )
        })}
      </div>
    </section>
  )
}

// ----------------------------------------------------------- o método GTD

function MetodoGtd({
  atividades,
  caixa,
  janela,
  aoMover,
  aoConcluir,
}: {
  atividades: LinhaAtividade[]
  caixa: LinhaCaixaDeEntrada[]
  janela: number
  aoMover: (atividadeId: string, estado: EstadoGtd) => void
  aoConcluir: (atividade: LinhaAtividade) => void
}) {
  const porId = new Map(atividades.map((linha) => [linha.id, linha]))

  const rotuloDoMonte: Record<GrupoCaixaDeEntrada, string> = {
    entrou_hoje: 'Caiu hoje',
    vencida: 'Venceu',
    vence_na_janela: `Vence em ${janela} dias`,
    aguardando_terceiro: `Aguardando terceiro há mais de ${janela} dias`,
  }

  return (
    <>
      <section className="secao" aria-labelledby="titulo-caixa">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-caixa">
            A caixa de entrada
          </h2>
          <p className="secao__nota">
            Os quatro montes de valor.caixa_de_entrada. A janela vem da configuração da casa, não do
            código: hoje ela está em {inteiro(janela)} dias.
          </p>
        </div>

        <div className="grade grade--4">
          {MONTES.map((monte) => {
            const doMonte = caixa.filter(
              (linha) => linha.grupo === monte && porId.has(linha.atividade_id),
            )

            return (
              <Cartao
                key={monte}
                tom={monte === 'vencida' ? 'realce' : 'simples'}
                titulo={rotuloDoMonte[monte]}
                legenda={`${inteiro(doMonte.length)} ${doMonte.length === 1 ? 'atividade' : 'atividades'}`}
              >
                <p style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)', marginBottom: 'var(--esp-3)' }}>
                  {EXPLICACAO_GRUPO_CAIXA[monte]}
                </p>

                {doMonte.length === 0 ? (
                  <p style={{ fontSize: 'var(--texto-p)', color: 'var(--cor-texto-tenue)' }}>
                    Nada neste monte agora.
                  </p>
                ) : (
                  <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 'var(--esp-2)' }}>
                    {doMonte.map((linha) => {
                      const atividade = porId.get(linha.atividade_id)
                      return (
                        <li key={`${monte}-${linha.atividade_id}`}>
                          <strong style={{ fontSize: 'var(--texto-p)' }}>{linha.titulo}</strong>
                          <br />
                          <span style={{ fontSize: 'var(--texto-micro)', color: 'var(--cor-texto-fraco)' }}>
                            {ROTULO_ESTADO_GTD[linha.estado]} · {data(linha.prazo)}
                            {linha.dias === null
                              ? ''
                              : monte === 'vencida'
                                ? ` · atrasada há ${inteiro(linha.dias)} dias`
                                : monte === 'aguardando_terceiro'
                                  ? ` · parada há ${inteiro(linha.dias)} dias`
                                  : ` · em ${inteiro(linha.dias)} dias`}
                            {atividade?.contexto_codigo ? ` · ${atividade.contexto_codigo}` : ''}
                          </span>
                        </li>
                      )
                    })}
                  </ul>
                )}
              </Cartao>
            )
          })}
        </div>
      </section>

      <section className="secao" aria-labelledby="titulo-estados">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-estados">
            Por estado do método
          </h2>
          <p className="secao__nota">
            Contexto, energia e tempo estimado ficam visíveis em toda ficha, porque é com eles que
            se escolhe o que fazer agora.
          </p>
        </div>

        {ORDEM_ESTADO_GTD.map((estado) => {
          const doEstado = atividades.filter((linha) => linha.estado === estado)
          if (doEstado.length === 0 && (estado === 'cancelada' || estado === 'algum_dia')) return null

          return (
            <Cartao
              key={estado}
              className="secao"
              titulo={ROTULO_ESTADO_GTD[estado]}
              legenda={`${inteiro(doEstado.length)} ${doEstado.length === 1 ? 'atividade' : 'atividades'}`}
            >
              {doEstado.length === 0 ? (
                <p style={{ fontSize: 'var(--texto-p)', color: 'var(--cor-texto-tenue)' }}>
                  Nenhuma atividade neste estado.
                </p>
              ) : (
                <div className="grade grade--3">
                  {doEstado.map((atividade) => (
                    <FichaDeAtividade
                      key={atividade.id}
                      atividade={atividade}
                      arrastavel={false}
                      arrastando={false}
                      aoComecar={() => undefined}
                      aoTerminar={() => undefined}
                      aoMover={aoMover}
                      aoConcluir={aoConcluir}
                    />
                  ))}
                </div>
              )}
            </Cartao>
          )
        })}
      </section>
    </>
  )
}

// -------------------------------------------------------- ficha de cartão

const ESTILO_FICHA: CSSProperties = {
  background: 'var(--cor-superficie)',
  border: '1px solid var(--cor-linha)',
  borderRadius: 'var(--raio-m)',
  boxShadow: 'var(--sombra-p)',
  padding: 'var(--esp-3)',
  display: 'flex',
  flexDirection: 'column',
  gap: 'var(--esp-2)',
}

const TOM_ENERGIA: Record<EnergiaAtividade, 'vermelha' | 'amarela' | 'verde'> = {
  alta: 'vermelha',
  media: 'amarela',
  baixa: 'verde',
}

function FichaDeAtividade({
  atividade,
  arrastavel,
  arrastando,
  aoComecar,
  aoTerminar,
  aoMover,
  aoConcluir,
}: {
  atividade: LinhaAtividade
  arrastavel: boolean
  arrastando: boolean
  aoComecar: () => void
  aoTerminar: () => void
  aoMover: (atividadeId: string, estado: EstadoGtd) => void
  aoConcluir: (atividade: LinhaAtividade) => void
}) {
  const atrasada =
    atividade.prazo !== null &&
    atividade.estado !== 'concluida' &&
    atividade.estado !== 'cancelada' &&
    atividade.prazo < new Date().toISOString().slice(0, 10)

  return (
    <article
      style={{
        ...ESTILO_FICHA,
        opacity: arrastando ? 0.5 : 1,
        cursor: arrastavel ? 'grab' : 'default',
        borderColor: atrasada ? 'var(--cor-vermelho-linha)' : 'var(--cor-linha)',
      }}
      draggable={arrastavel}
      onDragStart={
        arrastavel
          ? (evento) => {
              evento.dataTransfer.setData('text/plain', atividade.id)
              evento.dataTransfer.effectAllowed = 'move'
              aoComecar()
            }
          : undefined
      }
      onDragEnd={arrastavel ? aoTerminar : undefined}
    >
      <strong style={{ fontSize: 'var(--texto-base)' }}>{atividade.titulo}</strong>

      {atividade.negocio_id ? (
        <Link to={`/negocios/${atividade.negocio_id}`} style={{ fontSize: 'var(--texto-pp)' }}>
          {textoOuAusente(atividade.negocio_titulo, 'negócio vinculado')}
        </Link>
      ) : atividade.conta_id ? (
        <Link to={`/contas/${atividade.conta_id}`} style={{ fontSize: 'var(--texto-pp)' }}>
          {textoOuAusente(atividade.conta_nome, 'conta vinculada')}
        </Link>
      ) : (
        <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
          Trabalho da casa, sem vínculo com conta ou negócio
        </span>
      )}

      <div style={{ display: 'flex', gap: 'var(--esp-1)', flexWrap: 'wrap' }}>
        {atividade.contexto_codigo ? (
          <Etiqueta tom="marca">{atividade.contexto_codigo}</Etiqueta>
        ) : (
          <Etiqueta tom="neutra">sem contexto</Etiqueta>
        )}
        {atividade.energia ? (
          <Etiqueta tom={TOM_ENERGIA[atividade.energia]}>{ROTULO_ENERGIA[atividade.energia]}</Etiqueta>
        ) : (
          <Etiqueta tom="neutra">sem energia definida</Etiqueta>
        )}
        <Etiqueta tom="neutra">{tempoEstimado(atividade.tempo_estimado_min)}</Etiqueta>
        {atividade.prioridade ? (
          <Etiqueta tom={atividade.prioridade === 1 ? 'realce' : 'neutra'}>
            {ROTULO_PRIORIDADE[atividade.prioridade]}
          </Etiqueta>
        ) : null}
        {atividade.recorrencia_id ? <Etiqueta tom="realce">Série que se repete</Etiqueta> : null}
      </div>

      <span style={{ fontSize: 'var(--texto-pp)', color: atrasada ? 'var(--cor-vermelho)' : 'var(--cor-texto-fraco)' }}>
        Prazo {data(atividade.prazo)}
        {atrasada ? ' · atrasada' : ''} · {textoOuAusente(atividade.responsavel_nome, 'sem dono')}
      </span>

      {atividade.estado === 'aguardando' ? (
        <span style={{ fontSize: 'var(--texto-micro)', color: 'var(--cor-texto-fraco)' }}>
          Na mão de{' '}
          {textoOuAusente(atividade.delegado_para_externo, 'terceiro não informado')} desde{' '}
          {data(atividade.aguardando_desde)}
        </span>
      ) : null}

      <label style={{ fontSize: 'var(--texto-micro)' }}>
        <span className="apenas-leitor">Mover {atividade.titulo} para outro estado</span>
        <select
          className="selecao__controle"
          style={{ width: '100%', fontSize: 'var(--texto-pp)' }}
          value={atividade.estado}
          aria-label={`Mover ${atividade.titulo} para outro estado`}
          onChange={(evento) => {
            const escolhido = evento.target.value as EstadoGtd
            if (escolhido !== atividade.estado) aoMover(atividade.id, escolhido)
          }}
        >
          {ORDEM_ESTADO_GTD.map((estado) => (
            <option key={estado} value={estado}>
              Mover para {ROTULO_ESTADO_GTD[estado]}
            </option>
          ))}
        </select>
      </label>

      {atividade.estado !== 'concluida' && atividade.estado !== 'cancelada' ? (
        <Botao tom="contorno" tamanho="p" largo onClick={() => aoConcluir(atividade)}>
          Concluir
        </Botao>
      ) : atividade.concluida_em ? (
        <span style={{ fontSize: 'var(--texto-micro)', color: 'var(--cor-verde)' }}>
          Concluída em {data(atividade.concluida_em)}
        </span>
      ) : null}
    </article>
  )
}
