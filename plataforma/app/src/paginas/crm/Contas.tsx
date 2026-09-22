import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import {
  Alarme,
  Botao,
  Campo,
  Carregando,
  Cartao,
  Etiqueta,
  Migalhas,
  Paginacao,
  Selecao,
  Tabela,
  type ColunaTabela,
  type SentidoOrdem,
} from '@/componentes/indice'
import { useContas } from '@/dados/crm'
import { AvisoDeFonte } from '@/paginas/crm/Negocios'
import {
  origemDoTier,
  ROTULO_ORIGEM_TIER,
  ROTULO_PRIORIDADE,
  situacaoDaConta,
  textoOuAusente,
  type LinhaConta,
} from '@/tipos/crm'
import type { TierConta } from '@/tipos/dominio'
import { data, inteiro, ROTULO_TIER } from '@/tipos/rotulos'

interface Filtros {
  busca: string
  tier: string
  prioridade: string
  setor: string
  situacao: string
}

const FILTROS_VAZIOS: Filtros = {
  busca: '',
  tier: '',
  prioridade: '',
  setor: '',
  situacao: '',
}

/**
 * A lista de contas.
 *
 * Busca, filtro por tier, prioridade, setor e situação de cliente ou prospecto.
 * A coluna de Power of X conta quantas linhas do portfólio a conta já comprou.
 * O tier aparece sempre com a marca de quem o definiu: o sistema sugere, gente
 * confirma, e as duas coisas são diferentes.
 */
export function Contas() {
  const consulta = useContas()
  const navegar = useNavigate()

  const [filtros, setFiltros] = useState<Filtros>(FILTROS_VAZIOS)
  const [ordem, setOrdem] = useState<{ chave: string; sentido: SentidoOrdem }>({
    chave: 'nome',
    sentido: 'crescente',
  })
  const [pagina, setPagina] = useState(1)
  const [porPagina, setPorPagina] = useState(25)

  const contas = useMemo(() => consulta.data?.dados ?? [], [consulta.data])

  const setores = useMemo(() => {
    const conjunto = new Set<string>()
    for (const conta of contas) {
      const setor = (conta.setor ?? '').trim()
      if (setor) conjunto.add(setor)
    }
    return [...conjunto].sort((a, b) => a.localeCompare(b, 'pt-BR'))
  }, [contas])

  const filtradas = useMemo(() => {
    const busca = filtros.busca.trim().toLowerCase()

    return contas.filter((conta) => {
      if (filtros.tier !== '') {
        const tierEmUso = conta.tier ?? conta.tier_sugerido
        if (filtros.tier === 'sem_tier') {
          if (tierEmUso) return false
        } else if (tierEmUso !== filtros.tier) {
          return false
        }
      }
      if (filtros.prioridade !== '' && String(conta.prioridade ?? '') !== filtros.prioridade) {
        return false
      }
      if (filtros.setor !== '' && (conta.setor ?? '') !== filtros.setor) return false
      if (filtros.situacao === 'cliente' && !conta.eh_cliente) return false
      if (filtros.situacao === 'prospecto' && !conta.eh_prospecto) return false
      if (busca) {
        const alvo = `${conta.nome} ${conta.razao_social ?? ''} ${conta.setor ?? ''} ${conta.cidade ?? ''}`
        if (!alvo.toLowerCase().includes(busca)) return false
      }
      return true
    })
  }, [contas, filtros])

  const ordenadas = useMemo(
    () => ordenarContas(filtradas, ordem.chave, ordem.sentido),
    [filtradas, ordem],
  )

  const daPagina = useMemo(
    () => ordenadas.slice((pagina - 1) * porPagina, pagina * porPagina),
    [ordenadas, pagina, porPagina],
  )

  function trocarFiltro(remendo: Partial<Filtros>) {
    setFiltros((anterior) => ({ ...anterior, ...remendo }))
    setPagina(1)
  }

  function trocarOrdem(chave: string) {
    setOrdem((anterior) =>
      anterior.chave === chave
        ? { chave, sentido: anterior.sentido === 'crescente' ? 'decrescente' : 'crescente' }
        : { chave, sentido: 'crescente' },
    )
  }

  const colunas: Array<ColunaTabela<LinhaConta>> = [
    {
      chave: 'nome',
      rotulo: 'Conta',
      ordenavel: true,
      conteudo: (conta) => (
        <>
          <Link to={`/contas/${conta.id}`} style={{ fontWeight: 'var(--peso-forte)' }}>
            {conta.nome}
          </Link>
          <br />
          <span className="texto-fraco">
            {textoOuAusente(
              [conta.cidade, conta.uf].filter(Boolean).join(' · '),
              'sem cidade informada',
            )}
          </span>
        </>
      ),
    },
    {
      chave: 'setor',
      rotulo: 'Setor',
      ordenavel: true,
      conteudo: (conta) => textoOuAusente(conta.setor, 'sem setor'),
    },
    {
      chave: 'tier',
      rotulo: 'Tier',
      ordenavel: true,
      conteudo: (conta) => <CelulaTier conta={conta} />,
    },
    {
      chave: 'prioridade',
      rotulo: 'Prioridade',
      ordenavel: true,
      conteudo: (conta) =>
        conta.prioridade ? (
          <Etiqueta tom={conta.prioridade === 1 ? 'realce' : 'neutra'}>
            {ROTULO_PRIORIDADE[conta.prioridade]}
          </Etiqueta>
        ) : (
          <span className="texto-fraco">sem prioridade</span>
        ),
    },
    {
      chave: 'power_of_x',
      rotulo: 'Power of X',
      alinhamento: 'numero',
      ordenavel: true,
      conteudo: (conta) => (
        <>
          <span className="numero" style={{ fontSize: 'var(--texto-g)' }}>
            {inteiro(conta.power_of_x)}
          </span>
          <br />
          <span style={{ fontSize: 'var(--texto-micro)', color: 'var(--cor-texto-fraco)' }}>
            {conta.power_of_x === 1 ? 'linha comprada' : 'linhas compradas'}
          </span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      ordenavel: true,
      conteudo: (conta) => (
        <Etiqueta tom={conta.eh_cliente ? 'verde' : 'neutra'} ponto>
          {situacaoDaConta(conta)}
        </Etiqueta>
      ),
    },
    {
      chave: 'gerente',
      rotulo: 'Gerente de Contas',
      ordenavel: true,
      conteudo: (conta) => textoOuAusente(conta.gerente_contas_nome, 'sem responsável'),
    },
    {
      chave: 'acoes',
      rotulo: 'Ações',
      alinhamento: 'acoes',
      conteudo: (conta) => (
        <Botao tom="contorno" tamanho="p" onClick={() => navegar(`/contas/${conta.id}`)}>
          Abrir ficha
        </Botao>
      ),
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'CRM de Valor', para: '/painel' }, { rotulo: 'Contas' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">CRM de Valor</p>
          <h1 className="pagina__titulo">Contas</h1>
          <p className="pagina__lede">
            As empresas com quem a casa fala. Power of X conta quantas linhas do portfólio cada uma
            já comprou.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      <AvisoDeFonte deExemplo={consulta.data?.deExemplo} />

      {consulta.isPending ? <Carregando texto="Carregando as contas" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A lista de contas não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <Cartao titulo="Filtros" className="secao">
            <div className="grade grade--3">
              <Campo
                rotulo="Buscar"
                placeholder="Nome, razão social, setor ou cidade"
                value={filtros.busca}
                onChange={(evento) => trocarFiltro({ busca: evento.target.value })}
              />
              <Selecao
                rotulo="Tier"
                vazio="Todos os tiers"
                value={filtros.tier}
                onChange={(evento) => trocarFiltro({ tier: evento.target.value })}
                opcoes={[
                  { valor: 't1', rotulo: ROTULO_TIER.t1 },
                  { valor: 't2', rotulo: ROTULO_TIER.t2 },
                  { valor: 't3', rotulo: ROTULO_TIER.t3 },
                  { valor: 'sem_tier', rotulo: 'Sem tier' },
                ]}
              />
              <Selecao
                rotulo="Prioridade"
                vazio="Todas as prioridades"
                value={filtros.prioridade}
                onChange={(evento) => trocarFiltro({ prioridade: evento.target.value })}
                opcoes={[
                  { valor: '1', rotulo: ROTULO_PRIORIDADE[1] },
                  { valor: '2', rotulo: ROTULO_PRIORIDADE[2] },
                  { valor: '3', rotulo: ROTULO_PRIORIDADE[3] },
                ]}
              />
              <Selecao
                rotulo="Setor"
                vazio="Todos os setores"
                value={filtros.setor}
                onChange={(evento) => trocarFiltro({ setor: evento.target.value })}
                opcoes={setores.map((setor) => ({ valor: setor, rotulo: setor }))}
              />
              <Selecao
                rotulo="Situação"
                vazio="Cliente e prospecto"
                value={filtros.situacao}
                onChange={(evento) => trocarFiltro({ situacao: evento.target.value })}
                opcoes={[
                  { valor: 'cliente', rotulo: 'Cliente' },
                  { valor: 'prospecto', rotulo: 'Prospecto' },
                ]}
              />
              <div style={{ display: 'flex', alignItems: 'flex-end' }}>
                <Botao
                  tom="discreto"
                  largo
                  onClick={() => {
                    setFiltros(FILTROS_VAZIOS)
                    setPagina(1)
                  }}
                >
                  Limpar filtros
                </Botao>
              </div>
            </div>
          </Cartao>

          <section className="secao" aria-labelledby="titulo-lista-contas">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-lista-contas">
                Lista de contas
              </h2>
              <p className="secao__nota">
                {inteiro(ordenadas.length)} de {inteiro(contas.length)} contas. O tier que veio do
                sistema é sugestão; o tier confirmado por gente carrega data de confirmação.
              </p>
            </div>

            <Cartao semRespiro>
              <Tabela
                colunas={colunas}
                linhas={daPagina}
                chaveDaLinha={(conta) => conta.id}
                legenda="Contas com tier, prioridade, Power of X e situação."
                ordenadaPor={ordem.chave}
                sentido={ordem.sentido}
                aoOrdenar={trocarOrdem}
                vazioTitulo="Nenhuma conta com estes filtros"
                vazioTexto="Afrouxe um filtro, ou limpe todos para ver a base inteira."
              />
            </Cartao>

            <Paginacao
              pagina={pagina}
              total={ordenadas.length}
              porPagina={porPagina}
              aoTrocarPagina={setPagina}
              aoTrocarTamanho={(tamanho) => {
                setPorPagina(tamanho)
                setPagina(1)
              }}
            />
          </section>
        </>
      ) : null}
    </>
  )
}

// ---------------------------------------------------------------- o tier

/**
 * O tier com a marca de origem.
 *
 * Sugerido pelo sistema e confirmado por gente são coisas diferentes, e a
 * tela nunca deixa as duas parecerem a mesma. Quando a casa confirmou um tier
 * diferente do sugerido, as duas leituras aparecem juntas.
 */
function CelulaTier({ conta }: { conta: LinhaConta }) {
  const origem = origemDoTier(conta)
  const emUso: TierConta | null = conta.tier ?? conta.tier_sugerido

  if (origem === 'ausente' || !emUso) {
    return <span className="texto-fraco">Sem tier definido</span>
  }

  const diverge = Boolean(conta.tier && conta.tier_sugerido && conta.tier !== conta.tier_sugerido)

  return (
    <>
      <Etiqueta tom={origem === 'confirmado' ? 'marca' : 'neutra'}>{ROTULO_TIER[emUso]}</Etiqueta>
      <br />
      <span style={{ fontSize: 'var(--texto-micro)', color: 'var(--cor-texto-fraco)' }}>
        {ROTULO_ORIGEM_TIER[origem]}
        {origem === 'confirmado' && conta.tier_confirmado_em
          ? ` · ${data(conta.tier_confirmado_em)}`
          : ''}
      </span>
      {diverge && conta.tier_sugerido ? (
        <>
          <br />
          <span style={{ fontSize: 'var(--texto-micro)', color: 'var(--cor-realce-legivel)' }}>
            o sistema sugere {ROTULO_TIER[conta.tier_sugerido]}
          </span>
        </>
      ) : null}
    </>
  )
}

// -------------------------------------------------------------- ordenação

const PESO_TIER: Record<TierConta, number> = { t1: 1, t2: 2, t3: 3 }

function ordenarContas(
  contas: LinhaConta[],
  chave: string,
  sentido: SentidoOrdem,
): LinhaConta[] {
  const peso = sentido === 'crescente' ? 1 : -1

  const valorDe = (conta: LinhaConta): string | number => {
    switch (chave) {
      case 'nome':
        return conta.nome.toLowerCase()
      case 'setor':
        return (conta.setor ?? '').toLowerCase()
      case 'tier': {
        const emUso = conta.tier ?? conta.tier_sugerido
        return emUso ? PESO_TIER[emUso] : 9
      }
      case 'prioridade':
        return conta.prioridade ?? 9
      case 'power_of_x':
        return conta.power_of_x
      case 'situacao':
        return situacaoDaConta(conta).toLowerCase()
      case 'gerente':
        return (conta.gerente_contas_nome ?? '').toLowerCase()
      default:
        return conta.nome.toLowerCase()
    }
  }

  return [...contas].sort((a, b) => {
    const esquerda = valorDe(a)
    const direita = valorDe(b)
    if (typeof esquerda === 'number' && typeof direita === 'number') {
      return (esquerda - direita) * peso
    }
    return String(esquerda).localeCompare(String(direita), 'pt-BR') * peso
  })
}
