import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Alarme,
  Botao,
  Carregando,
  Cartao,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Modal,
} from '@/componentes/indice'
import { useAgenda } from '@/dados/crm'
import { AvisoDeFonte } from '@/paginas/crm/Negocios'
import {
  chaveDoDia,
  hora,
  ROTULO_TIPO_AGENDA,
  textoOuAusente,
  type LinhaAgenda,
  type TipoItemAgenda,
} from '@/tipos/crm'
import { dataPorExtenso, inteiro, periodo } from '@/tipos/rotulos'

type Visao = 'mes' | 'semana'

const DIAS_DA_SEMANA = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado']
const DIAS_CURTOS = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']

const TOM_TIPO: Record<TipoItemAgenda, 'marca' | 'realce' | 'neutra'> = {
  encontro: 'marca',
  reuniao: 'realce',
  compromisso: 'neutra',
}

/**
 * O calendário da casa, em mês e em semana.
 *
 * Junta numa lista só o que `valor.vw_agenda_da_semana` entrega: atividade com
 * prazo, encontro de turma e compromisso da agenda. A visão de mês amplia a
 * janela com as atividades que têm prazo dentro do mês, para que o quadro do
 * mês não fique vazio fora dos sete dias da visão do banco.
 */
export function Calendario() {
  const [visao, setVisao] = useState<Visao>('mes')
  const [ancora, setAncora] = useState(() => new Date())
  const [aberto, setAberto] = useState<LinhaAgenda | null>(null)

  const grade = useMemo(() => montarGrade(ancora, visao), [ancora, visao])
  const consulta = useAgenda(grade.inicio, grade.fim)

  const porDia = useMemo(() => {
    const mapa = new Map<string, LinhaAgenda[]>()
    for (const item of consulta.data?.dados ?? []) {
      if (!item.quando_em) continue
      const chave = item.quando_em.slice(0, 10)
      const lista = mapa.get(chave)
      if (lista) lista.push(item)
      else mapa.set(chave, [item])
    }
    for (const lista of mapa.values()) {
      lista.sort((a, b) => (a.hora_inicio ?? '99').localeCompare(b.hora_inicio ?? '99'))
    }
    return mapa
  }, [consulta.data])

  const semData = useMemo(
    () => (consulta.data?.dados ?? []).filter((item) => !item.quando_em),
    [consulta.data],
  )

  function andar(passo: number) {
    setAncora((anterior) => {
      const proximo = new Date(anterior)
      if (visao === 'mes') proximo.setMonth(proximo.getMonth() + passo)
      else proximo.setDate(proximo.getDate() + passo * 7)
      return proximo
    })
  }

  return (
    <>
      <Migalhas itens={[{ rotulo: 'CRM de Valor', para: '/painel' }, { rotulo: 'Calendário' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">CRM de Valor</p>
          <h1 className="pagina__titulo">Calendário</h1>
          <p className="pagina__lede">
            Encontro de turma, reunião de conselho e compromisso da agenda, numa lista só.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao
            tom={visao === 'mes' ? 'principal' : 'contorno'}
            aria-pressed={visao === 'mes'}
            onClick={() => setVisao('mes')}
          >
            Mês
          </Botao>
          <Botao
            tom={visao === 'semana' ? 'principal' : 'contorno'}
            aria-pressed={visao === 'semana'}
            onClick={() => setVisao('semana')}
          >
            Semana
          </Botao>
        </div>
      </div>

      <AvisoDeFonte deExemplo={consulta.data?.deExemplo} />

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A agenda não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      <section className="secao" aria-labelledby="titulo-calendario">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-calendario">
            {grade.titulo}
          </h2>
          <div style={{ display: 'flex', gap: 'var(--esp-2)', alignItems: 'center' }}>
            <span className="secao__nota">{periodo(grade.inicio, grade.fim)}</span>
            <Botao tamanho="p" tom="contorno" onClick={() => andar(-1)}>
              Anterior
            </Botao>
            <Botao tamanho="p" tom="contorno" onClick={() => setAncora(new Date())}>
              Hoje
            </Botao>
            <Botao tamanho="p" tom="contorno" onClick={() => andar(1)}>
              Próximo
            </Botao>
          </div>
        </div>

        {consulta.isPending ? <Carregando texto="Carregando a agenda" /> : null}

        {consulta.data ? (
          visao === 'mes' ? (
            <QuadroDoMes
              dias={grade.dias}
              mesDeReferencia={ancora.getMonth()}
              porDia={porDia}
              aoAbrir={setAberto}
            />
          ) : (
            <QuadroDaSemana dias={grade.dias} porDia={porDia} aoAbrir={setAberto} />
          )
        ) : null}
      </section>

      {semData.length > 0 ? (
        <Cartao titulo="Sem data definida" className="secao">
          <ul className="lista-felix">
            {semData.map((item) => (
              <li key={`${item.tipo}-${item.referencia_id}`}>
                {item.titulo} · {item.tipo_rotulo}
              </li>
            ))}
          </ul>
        </Cartao>
      ) : null}

      <DetalheDoItem item={aberto} aoFechar={() => setAberto(null)} />
    </>
  )
}

// ------------------------------------------------------------- a grade

interface Grade {
  titulo: string
  inicio: string
  fim: string
  dias: Date[]
}

const MESES = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
]

function montarGrade(ancora: Date, visao: Visao): Grade {
  if (visao === 'semana') {
    const domingo = new Date(ancora)
    domingo.setDate(domingo.getDate() - domingo.getDay())
    const dias = Array.from({ length: 7 }, (_, indice) => {
      const dia = new Date(domingo)
      dia.setDate(dia.getDate() + indice)
      return dia
    })
    const ultimo = new Date(domingo)
    ultimo.setDate(ultimo.getDate() + 6)
    return {
      titulo: 'Semana',
      inicio: chaveDoDia(domingo),
      fim: chaveDoDia(ultimo),
      dias,
    }
  }

  const primeiroDoMes = new Date(ancora.getFullYear(), ancora.getMonth(), 1)
  const comeco = new Date(primeiroDoMes)
  comeco.setDate(comeco.getDate() - comeco.getDay())

  const dias = Array.from({ length: 42 }, (_, indice) => {
    const dia = new Date(comeco)
    dia.setDate(dia.getDate() + indice)
    return dia
  })

  const ultimo = new Date(comeco)
  ultimo.setDate(ultimo.getDate() + 41)

  return {
    titulo: `${MESES[ancora.getMonth()] ?? 'Mês'} de ${ancora.getFullYear()}`,
    inicio: chaveDoDia(comeco),
    fim: chaveDoDia(ultimo),
    dias,
  }
}

// ------------------------------------------------------------ visão de mês

function QuadroDoMes({
  dias,
  mesDeReferencia,
  porDia,
  aoAbrir,
}: {
  dias: Date[]
  mesDeReferencia: number
  porDia: Map<string, LinhaAgenda[]>
  aoAbrir: (item: LinhaAgenda) => void
}) {
  const hoje = chaveDoDia(new Date())

  return (
    <Cartao semRespiro>
      <div style={{ overflowX: 'auto' }}>
        <div style={{ minWidth: '760px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, minmax(0, 1fr))' }}>
            {DIAS_CURTOS.map((nome, indice) => (
              <div
                key={nome}
                style={{
                  padding: 'var(--esp-2)',
                  textAlign: 'center',
                  fontSize: 'var(--texto-micro)',
                  textTransform: 'uppercase',
                  letterSpacing: 'var(--espaco-letra-rotulo)',
                  color: 'var(--cor-texto-fraco)',
                  borderBottom: '1px solid var(--cor-linha)',
                }}
              >
                <abbr title={DIAS_DA_SEMANA[indice]} style={{ textDecoration: 'none' }}>
                  {nome}
                </abbr>
              </div>
            ))}
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, minmax(0, 1fr))' }}>
            {dias.map((dia) => {
              const chave = chaveDoDia(dia)
              const itens = porDia.get(chave) ?? []
              const doMes = dia.getMonth() === mesDeReferencia
              const eHoje = chave === hoje

              return (
                <div
                  key={chave}
                  style={{
                    minHeight: '112px',
                    padding: 'var(--esp-2)',
                    borderBottom: '1px solid var(--cor-linha)',
                    borderRight: '1px solid var(--cor-linha)',
                    background: eHoje
                      ? 'var(--cor-marca-suave)'
                      : doMes
                        ? 'var(--cor-superficie)'
                        : 'var(--cor-fundo-recuado)',
                    opacity: doMes ? 1 : 0.6,
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 'var(--esp-1)',
                  }}
                >
                  <span
                    style={{
                      fontFamily: 'var(--fonte-numero)',
                      fontSize: 'var(--texto-p)',
                      color: eHoje ? 'var(--cor-marca)' : 'var(--cor-texto-fraco)',
                    }}
                  >
                    {dia.getDate()}
                    {eHoje ? <span className="apenas-leitor"> · hoje</span> : null}
                  </span>

                  {itens.map((item) => (
                    <BotaoDoItem key={`${item.tipo}-${item.referencia_id}`} item={item} aoAbrir={aoAbrir} />
                  ))}
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </Cartao>
  )
}

// --------------------------------------------------------- visão de semana

function QuadroDaSemana({
  dias,
  porDia,
  aoAbrir,
}: {
  dias: Date[]
  porDia: Map<string, LinhaAgenda[]>
  aoAbrir: (item: LinhaAgenda) => void
}) {
  const hoje = chaveDoDia(new Date())

  return (
    <div style={{ display: 'flex', gap: 'var(--esp-3)', overflowX: 'auto', paddingBottom: 'var(--esp-4)' }}>
      {dias.map((dia) => {
        const chave = chaveDoDia(dia)
        const itens = porDia.get(chave) ?? []
        const eHoje = chave === hoje

        return (
          <div
            key={chave}
            style={{
              minWidth: '232px',
              flex: '1 1 232px',
              border: '1px solid var(--cor-linha)',
              borderRadius: 'var(--raio-g)',
              background: eHoje ? 'var(--cor-marca-suave)' : 'var(--cor-fundo-recuado)',
              padding: 'var(--esp-3)',
              display: 'flex',
              flexDirection: 'column',
              gap: 'var(--esp-2)',
            }}
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
                {DIAS_DA_SEMANA[dia.getDay()]}
                {eHoje ? ' · hoje' : ''}
              </p>
              <p style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
                {dataPorExtenso(chave)} · {inteiro(itens.length)}{' '}
                {itens.length === 1 ? 'item' : 'itens'}
              </p>
            </header>

            {itens.length === 0 ? (
              <p style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-tenue)', textAlign: 'center', padding: 'var(--esp-4) 0' }}>
                Dia livre
              </p>
            ) : (
              itens.map((item) => (
                <BotaoDoItem
                  key={`${item.tipo}-${item.referencia_id}`}
                  item={item}
                  aoAbrir={aoAbrir}
                  detalhado
                />
              ))
            )}
          </div>
        )
      })}
    </div>
  )
}

// ------------------------------------------------------------ item e ficha

function BotaoDoItem({
  item,
  aoAbrir,
  detalhado = false,
}: {
  item: LinhaAgenda
  aoAbrir: (item: LinhaAgenda) => void
  detalhado?: boolean
}) {
  return (
    <button
      type="button"
      onClick={() => aoAbrir(item)}
      style={{
        textAlign: 'left',
        width: '100%',
        border: '1px solid var(--cor-linha)',
        borderLeft: `3px solid ${
          item.tipo === 'encontro'
            ? 'var(--cor-marca)'
            : item.tipo === 'reuniao'
              ? 'var(--cor-realce-legivel)'
              : 'var(--cor-texto-fraco)'
        }`,
        borderRadius: 'var(--raio-p)',
        background: 'var(--cor-superficie)',
        color: 'var(--cor-texto)',
        padding: 'var(--esp-2)',
        fontSize: 'var(--texto-pp)',
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--esp-1)',
      }}
    >
      <span style={{ fontWeight: 'var(--peso-forte)' }}>
        {item.hora_inicio ? `${hora(item.hora_inicio)} · ` : ''}
        {item.titulo}
      </span>
      {detalhado ? (
        <span style={{ color: 'var(--cor-texto-fraco)', fontSize: 'var(--texto-micro)' }}>
          {item.tipo_rotulo}
          {item.conta_nome ? ` · ${item.conta_nome}` : ''}
          {item.turma_nome ? ` · ${item.turma_nome}` : ''}
        </span>
      ) : null}
    </button>
  )
}

function DetalheDoItem({ item, aoFechar }: { item: LinhaAgenda | null; aoFechar: () => void }) {
  return (
    <Modal
      aberto={item !== null}
      aoFechar={aoFechar}
      titulo={item?.titulo ?? 'Item da agenda'}
      legenda={item ? `${item.tipo_rotulo} · ${dataPorExtenso(item.quando_em)}` : undefined}
      rodape={
        <Botao tom="contorno" onClick={aoFechar}>
          Voltar ao calendário
        </Botao>
      }
    >
      {item === null ? (
        <EstadoVazio titulo="Nada escolhido" />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--esp-4)' }}>
          <div style={{ display: 'flex', gap: 'var(--esp-2)', flexWrap: 'wrap' }}>
            <Etiqueta tom={TOM_TIPO[item.tipo]}>{ROTULO_TIPO_AGENDA[item.tipo]}</Etiqueta>
            {item.status ? <Etiqueta tom="neutra">{item.status}</Etiqueta> : null}
          </div>

          <p>
            <strong>Quando</strong>
            <br />
            {dataPorExtenso(item.quando_em)}
            {item.hora_inicio
              ? ` · ${hora(item.hora_inicio)}${item.hora_fim ? ` a ${hora(item.hora_fim)}` : ''}`
              : ' · sem hora definida'}
          </p>

          <p>
            <strong>Onde</strong>
            <br />
            {textoOuAusente(item.local, 'local não informado')}
            {item.link ? (
              <>
                <br />
                <a href={item.link} target="_blank" rel="noreferrer">
                  abrir o endereço da reunião
                </a>
              </>
            ) : null}
          </p>

          <p>
            <strong>Vínculos</strong>
            <br />
            {item.conta_id ? (
              <Link to={`/contas/${item.conta_id}`}>
                {textoOuAusente(item.conta_nome, 'conta vinculada')}
              </Link>
            ) : (
              'sem conta vinculada'
            )}
            <br />
            {item.turma_id ? (
              <Link to={`/turmas/${item.turma_id}`}>
                {textoOuAusente(item.turma_nome, 'turma vinculada')}
              </Link>
            ) : (
              'sem turma vinculada'
            )}
          </p>

          <p>
            {item.tipo === 'encontro' ? (
              <Link to={`/encontros/${item.referencia_id}`}>Abrir o encontro</Link>
            ) : item.tipo === 'compromisso' ? (
              <Link to="/atividades">Abrir a lista de atividades</Link>
            ) : (
              <Link to="/encontros">Abrir a agenda de encontros</Link>
            )}
          </p>
        </div>
      )}
    </Modal>
  )
}
