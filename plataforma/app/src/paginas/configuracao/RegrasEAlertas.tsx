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
  type TomEtiqueta,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO, temBanco } from '@/dados/cliente'
import { useRegrasEPrazos } from '@/dados/configuracao'
import type { Criticidade } from '@/tipos/dominio'
import { dinheiro, inteiro, ROTULO_CRITICIDADE, ROTULO_PAPEL } from '@/tipos/rotulos'
import {
  metaEmBranco,
  ROTULO_CANAL_ALERTA,
  ROTULO_ESCOPO_META,
  ROTULO_PERFIL_PLATAFORMA,
  ROTULO_PERIODO_META,
  SEM_META_SEM_COBERTURA,
  type MetaConfigurada,
  type PrazoConfiguravel,
  type RegraNaTela,
} from '@/tipos/configuracao'

/**
 * Regras e alertas.
 *
 * Duas coisas na mesma tela, porque uma não vive sem a outra: o catálogo de
 * regras que a casa decidiu, e os prazos que essas regras leem.
 *
 * Nenhum prazo desta tela é constante de código. Todos moram em
 * `valor.configuracoes`, chave por chave, e trocar o número é trocar a linha
 * do banco. Por isso a chave aparece em toda linha: quem administra precisa
 * saber onde o número mora.
 *
 * As metas do período nascem vazias de propósito. Onde a meta estiver em
 * branco, a tela diz, com todas as letras, que o painel mostra a cobertura de
 * pipeline como indisponível, e não um número errado.
 */

const TOM_DA_CRITICIDADE: Record<Criticidade, TomEtiqueta> = {
  verde: 'verde',
  amarelo: 'amarela',
  vermelho: 'vermelha',
}

export function RegrasEAlertas() {
  const consulta = useRegrasEPrazos()
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [regraEmEdicao, setRegraEmEdicao] = useState<RegraNaTela | null>(null)
  const [prazoEmEdicao, setPrazoEmEdicao] = useState<PrazoConfiguravel | null>(null)
  const [metaEmEdicao, setMetaEmEdicao] = useState<MetaConfigurada | null>(null)

  const regras = useMemo(() => consulta.data?.regras ?? [], [consulta.data])
  const prazos = useMemo(() => consulta.data?.prazos ?? [], [consulta.data])
  const metas = useMemo(() => consulta.data?.metas ?? [], [consulta.data])

  const metasVazias = useMemo(() => metas.filter(metaEmBranco), [metas])

  return (
    <>
      <Migalhas itens={[{ rotulo: 'Configuração' }, { rotulo: 'Regras e Alertas' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Configuração</p>
          <h1 className="pagina__titulo">Regras e Alertas</h1>
          <p className="pagina__lede">
            As regras que a casa decidiu, e os prazos que elas leem. Todo prazo aqui vem da
            configuração do inquilino, nunca do código.
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

      {consulta.isPending ? <Carregando texto="Carregando as regras" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="As regras não carregaram">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          {metasVazias.length > 0 ? (
            <Alarme
              tom="amarelo"
              titulo={`${inteiro(metasVazias.length)} ${metasVazias.length === 1 ? 'meta ainda está em branco' : 'metas ainda estão em branco'}`}
              className="secao"
            >
              <p>{SEM_META_SEM_COBERTURA}</p>
              <p>
                Isso é decisão da casa, e não falha: um número inventado seria pior que a ausência
                dele. Informe a meta quando quiser ver cobertura.
              </p>
              <ul className="lista-felix">
                {metasVazias.map((meta) => (
                  <li key={meta.chave}>
                    {meta.rotulo} · chave <code>{meta.chave}</code>
                  </li>
                ))}
              </ul>
            </Alarme>
          ) : null}

          <ListaDeRegras regras={regras} aoEditar={setRegraEmEdicao} />
          <ListaDePrazos prazos={prazos} aoEditar={setPrazoEmEdicao} />
          <ListaDeMetas metas={metas} aoEditar={setMetaEmEdicao} />

          <JanelaDaRegra regra={regraEmEdicao} aoFechar={() => setRegraEmEdicao(null)} />
          <JanelaDoPrazo prazo={prazoEmEdicao} aoFechar={() => setPrazoEmEdicao(null)} />
          <JanelaDaMeta meta={metaEmEdicao} aoFechar={() => setMetaEmEdicao(null)} />
        </>
      ) : null}
    </>
  )
}

// -------------------------------------------------------------- as regras

function ListaDeRegras({
  regras,
  aoEditar,
}: {
  regras: RegraNaTela[]
  aoEditar: (regra: RegraNaTela) => void
}) {
  const colunas: Array<ColunaTabela<RegraNaTela>> = [
    {
      chave: 'regra',
      rotulo: 'Regra',
      conteudo: (regra) => (
        <>
          <strong>{regra.nome}</strong>
          <br />
          <span className="texto-fraco">{regra.descricao ?? 'Sem descrição registrada.'}</span>
        </>
      ),
    },
    {
      chave: 'criticidade',
      rotulo: 'Criticidade',
      conteudo: (regra) => (
        <Etiqueta tom={TOM_DA_CRITICIDADE[regra.criticidade]} ponto>
          {ROTULO_CRITICIDADE[regra.criticidade]}
        </Etiqueta>
      ),
    },
    {
      chave: 'entidade',
      rotulo: 'Entidade alvo',
      conteudo: (regra) => (
        <>
          <code>{regra.entidade_alvo}</code>
          <br />
          <span className="texto-fraco">A tabela que a regra varre.</span>
        </>
      ),
    },
    {
      chave: 'destinatario',
      rotulo: 'Quem recebe',
      conteudo: (regra) => (
        <>
          {regra.destinatario_perfil ? (
            <>Perfil {ROTULO_PERFIL_PLATAFORMA[regra.destinatario_perfil]}</>
          ) : regra.destinatario_papel ? (
            <>Papel {ROTULO_PAPEL[regra.destinatario_papel]} no negócio</>
          ) : (
            <span className="texto-fraco">Fica no painel da casa</span>
          )}
          <br />
          <span className="texto-fraco">Por {ROTULO_CANAL_ALERTA[regra.canal]}</span>
        </>
      ),
    },
    {
      chave: 'prazos',
      rotulo: 'Prazos que lê',
      conteudo: (regra) =>
        regra.prazos_que_usa.length === 0 ? (
          <span className="texto-fraco">Nenhum prazo configurável</span>
        ) : (
          <ul className="lista-felix">
            {regra.prazos_que_usa.map((chave) => (
              <li key={chave}>
                <code>{chave}</code>
              </li>
            ))}
          </ul>
        ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (regra) => (
        <>
          <Etiqueta tom={regra.ativa ? 'verde' : 'neutra'} ponto>
            {regra.ativa ? 'Ativa' : 'Desligada'}
          </Etiqueta>
          <br />
          <span className="texto-fraco">
            {regra.alertas_abertos > 0
              ? `${inteiro(regra.alertas_abertos)} ${regra.alertas_abertos === 1 ? 'alerta aberto' : 'alertas abertos'}`
              : 'Nenhum alerta aberto'}
          </span>
        </>
      ),
    },
    {
      chave: 'acoes',
      rotulo: 'Editar',
      alinhamento: 'acoes',
      conteudo: (regra) => (
        <Botao tom="contorno" tamanho="p" onClick={() => aoEditar(regra)}>
          Abrir
        </Botao>
      ),
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-regras">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-regras">
          Regras de alerta
        </h2>
        <p className="secao__nota">
          {inteiro(regras.length)} {regras.length === 1 ? 'regra' : 'regras'} no catálogo. O prazo
          que cada uma lê está logo abaixo, com a chave do banco onde o número mora.
        </p>
      </div>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={regras}
          chaveDaLinha={(regra) => regra.id}
          legenda="Regras de alerta, com criticidade, entidade alvo, destinatário, prazos lidos e situação."
          aoEscolherLinha={(regra) => aoEditar(regra)}
          vazioTitulo="Nenhuma regra"
          vazioTexto="O inquilino ainda não recebeu a semente das regras, ou a política de linha não entregou nenhuma."
        />
      </Cartao>
    </section>
  )
}

// ------------------------------------------------------------- os prazos

/** Lê o número da configuração do jeito que a casa escreve cada unidade. */
export function valorDoPrazo(prazo: PrazoConfiguravel): string {
  if (prazo.valor === null) return 'em branco'

  switch (prazo.unidade) {
    case 'dias':
      return `${inteiro(prazo.valor)} ${prazo.valor === 1 ? 'dia' : 'dias'}`
    case 'horas':
      return `${inteiro(prazo.valor)} ${prazo.valor === 1 ? 'hora' : 'horas'}`
    case 'fracao':
      return `${inteiro(Math.round(prazo.valor * 100))} por cento`
    case 'fator':
      return `${inteiro(prazo.valor)} ${prazo.valor === 1 ? 'vez a mediana' : 'vezes a mediana'}`
    case 'quantidade':
      return `${inteiro(prazo.valor)} ${prazo.valor === 1 ? 'registro' : 'registros'}`
    case 'dinheiro':
      return dinheiro(prazo.valor)
    default:
      return inteiro(prazo.valor)
  }
}

function ListaDePrazos({
  prazos,
  aoEditar,
}: {
  prazos: PrazoConfiguravel[]
  aoEditar: (prazo: PrazoConfiguravel) => void
}) {
  const colunas: Array<ColunaTabela<PrazoConfiguravel>> = [
    {
      chave: 'prazo',
      rotulo: 'Prazo',
      conteudo: (prazo) => (
        <>
          <strong>{prazo.rotulo}</strong>
          <br />
          <span className="texto-fraco">{prazo.explicacao}</span>
        </>
      ),
    },
    {
      chave: 'valor',
      rotulo: 'Valor em uso',
      alinhamento: 'numero',
      conteudo: (prazo) =>
        prazo.valor === null ? (
          <Etiqueta tom="amarela" ponto>
            Em branco
          </Etiqueta>
        ) : (
          <span className="numero">{valorDoPrazo(prazo)}</span>
        ),
    },
    {
      chave: 'chave',
      rotulo: 'Chave no banco',
      conteudo: (prazo) => (
        <>
          <code>{prazo.chave}</code>
          <br />
          <span className="texto-fraco">Grupo {prazo.grupo}</span>
        </>
      ),
    },
    {
      chave: 'regra',
      rotulo: 'Regra que usa',
      conteudo: (prazo) =>
        prazo.regra ? <code>{prazo.regra}</code> : <span className="texto-fraco">Nenhuma regra</span>,
    },
    {
      chave: 'editavel',
      rotulo: 'Quem edita',
      conteudo: (prazo) => ROTULO_PERFIL_PLATAFORMA[prazo.editavel_por],
    },
    {
      chave: 'acoes',
      rotulo: 'Editar',
      alinhamento: 'acoes',
      conteudo: (prazo) => (
        <Botao tom="contorno" tamanho="p" onClick={() => aoEditar(prazo)}>
          Trocar
        </Botao>
      ),
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-prazos">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-prazos">
          Prazos configuráveis
        </h2>
        <p className="secao__nota">
          Lead sem dono, negócio parado, Plano de Trabalho vencendo, contrato vencendo, ata não
          enviada, concentração de pipeline e proteção de indicação. Todos lidos de
          <code> valor.configuracoes</code>, nenhum escrito no código.
        </p>
      </div>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={prazos}
          chaveDaLinha={(prazo) => prazo.chave}
          legenda="Prazos configuráveis do inquilino, com o valor em uso, a chave no banco e a regra que os lê."
          vazioTitulo="Nenhum prazo configurado"
          vazioTexto="O inquilino ainda não recebeu a semente da configuração."
        />
      </Cartao>
    </section>
  )
}

// -------------------------------------------------------------- as metas

function ListaDeMetas({
  metas,
  aoEditar,
}: {
  metas: MetaConfigurada[]
  aoEditar: (meta: MetaConfigurada) => void
}) {
  return (
    <section className="secao" aria-labelledby="titulo-metas">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-metas">
          Metas do período
        </h2>
        <p className="secao__nota">
          Anual e trimestral, da casa e por pessoa. Elas nascem vazias de propósito.
        </p>
      </div>

      <div className="grade grade--2">
        {metas.map((meta) => {
          const vazia = metaEmBranco(meta)

          return (
            <Cartao
              key={meta.chave}
              tom={vazia ? 'plano' : 'marca'}
              titulo={meta.rotulo}
              legenda={`${ROTULO_PERIODO_META[meta.periodo]} · ${ROTULO_ESCOPO_META[meta.escopo]} · chave ${meta.chave}`}
              acoes={
                <Botao tom="contorno" tamanho="p" onClick={() => aoEditar(meta)}>
                  {vazia ? 'Informar meta' : 'Trocar meta'}
                </Botao>
              }
            >
              {vazia ? (
                <>
                  <p>
                    <Etiqueta tom="amarela" ponto>
                      Meta em branco
                    </Etiqueta>
                  </p>
                  <p>{SEM_META_SEM_COBERTURA}</p>
                </>
              ) : (
                <>
                  <p className="linha-pipeline__valor">
                    {meta.escopo === 'casa'
                      ? dinheiro(meta.valor)
                      : `${inteiro(meta.pessoas_com_meta)} ${meta.pessoas_com_meta === 1 ? 'pessoa com meta' : 'pessoas com meta'}`}
                  </p>
                  <p className="texto-fraco">
                    Com a meta informada, o painel passa a calcular a cobertura de pipeline do
                    período.
                  </p>
                </>
              )}

              <p className="texto-fraco">
                Editável por {ROTULO_PERFIL_PLATAFORMA[meta.editavel_por]}.
              </p>
            </Cartao>
          )
        })}
      </div>
    </section>
  )
}

// ------------------------------------------------------ a janela da regra

function JanelaDaRegra({
  regra,
  aoFechar,
}: {
  regra: RegraNaTela | null
  aoFechar: () => void
}) {
  const [carregada, setCarregada] = useState<string | null>(null)
  const [nome, setNome] = useState('')
  const [mensagem, setMensagem] = useState('')
  const [criticidade, setCriticidade] = useState<Criticidade>('amarelo')
  const [ativa, setAtiva] = useState(true)

  if (!regra) return null

  if (carregada !== regra.id) {
    setCarregada(regra.id)
    setNome(regra.nome)
    setMensagem(regra.mensagem ?? '')
    setCriticidade(regra.criticidade)
    setAtiva(regra.ativa)
  }

  return (
    <Modal
      aberto
      aoFechar={aoFechar}
      titulo={regra.nome}
      legenda={`Código ${regra.codigo} · entidade alvo ${regra.entidade_alvo}`}
      tamanho="g"
      fechaNoFundo={false}
      rodape={
        <>
          <Botao tom="discreto" onClick={aoFechar}>
            Cancelar
          </Botao>
          <Botao tom="principal" disabled={!temBanco()}>
            Salvar regra
          </Botao>
        </>
      }
    >
      {!temBanco() ? (
        <Alarme tom="amarelo" titulo="Edição não gravada nesta máquina">
          O banco ainda não está ligado aqui, então salvar fica desligado.
        </Alarme>
      ) : null}

      {!regra.configuravel ? (
        <Alarme tom="informacao" titulo="Regra estrutural">
          A condição desta regra não é editável em tela. Ela vem do contrato técnico, e mudar a
          condição mudaria o significado do pipeline auditado. O texto e o destinatário continuam
          editáveis.
        </Alarme>
      ) : null}

      <Campo rotulo="Nome da regra" value={nome} onChange={(evento) => setNome(evento.target.value)} />

      <CampoTexto
        multiplas_linhas
        rotulo="Mensagem que chega a quem recebe"
        rows={4}
        maxLength={400}
        contador
        valorAtual={mensagem}
        value={mensagem}
        onChange={(evento) => setMensagem(evento.target.value)}
        auxilio="Curta, direta, e dizendo o que fazer. É o que a pessoa lê no painel ou na mensagem."
        acessorio={
          <BotaoIA
            campo="texto_livre"
            textoAtual={mensagem}
            contexto={{
              regra: regra.nome,
              entidade_alvo: regra.entidade_alvo,
              criticidade: ROTULO_CRITICIDADE[criticidade],
            }}
            aoAceitar={setMensagem}
            rotulo="Sugerir mensagem"
          />
        }
      />

      <Selecao
        rotulo="Criticidade"
        value={criticidade}
        onChange={(evento) => setCriticidade(evento.target.value as Criticidade)}
        opcoes={(['verde', 'amarelo', 'vermelho'] as Criticidade[]).map((chave) => ({
          valor: chave,
          rotulo: ROTULO_CRITICIDADE[chave],
        }))}
        auxilio="Vermelho é anunciado na hora por leitor de tela. Use com parcimônia."
      />

      <label className="campo__rotulo">
        <input
          type="checkbox"
          checked={ativa}
          onChange={(evento) => setAtiva(evento.target.checked)}
        />{' '}
        Regra ativa
      </label>
      <p className="campo__auxilio">
        Desligar para de gerar alertas novos. Os alertas já abertos continuam onde estão, até
        alguém resolver.
      </p>

      {regra.prazos_que_usa.length > 0 ? (
        <Cartao tom="plano" titulo="Prazos que esta regra lê">
          <ul className="lista-felix">
            {regra.prazos_que_usa.map((chave) => (
              <li key={chave}>
                <code>{chave}</code>
              </li>
            ))}
          </ul>
          <p className="texto-fraco">
            Para mudar o número, troque a chave na seção de prazos configuráveis. O número não vive
            nesta janela, e não vive no código.
          </p>
        </Cartao>
      ) : null}
    </Modal>
  )
}

// ------------------------------------------------------ a janela do prazo

function JanelaDoPrazo({
  prazo,
  aoFechar,
}: {
  prazo: PrazoConfiguravel | null
  aoFechar: () => void
}) {
  const [carregado, setCarregado] = useState<string | null>(null)
  const [texto, setTexto] = useState('')

  if (!prazo) return null

  if (carregado !== prazo.chave) {
    setCarregado(prazo.chave)
    setTexto(prazo.valor === null ? '' : String(prazo.valor))
  }

  const lido = texto.trim() === '' ? null : Number(texto.replace(',', '.'))
  const invalido = lido === null || Number.isNaN(lido) || lido < 0

  return (
    <Modal
      aberto
      aoFechar={aoFechar}
      titulo={prazo.rotulo}
      legenda={`Chave ${prazo.chave} · grupo ${prazo.grupo}`}
      rodape={
        <>
          <Botao tom="discreto" onClick={aoFechar}>
            Cancelar
          </Botao>
          <Botao tom="principal" disabled={!temBanco() || invalido}>
            Gravar na configuração
          </Botao>
        </>
      }
    >
      {!temBanco() ? (
        <Alarme tom="amarelo" titulo="Troca não gravada nesta máquina">
          O banco ainda não está ligado aqui, então gravar fica desligado.
        </Alarme>
      ) : null}

      <p>{prazo.explicacao}</p>

      <Campo
        rotulo="Valor"
        inputMode="decimal"
        value={texto}
        onChange={(evento) => setTexto(evento.target.value)}
        erro={texto.trim() !== '' && invalido ? 'Informe um número igual ou maior que zero.' : undefined}
        auxilio={
          prazo.unidade === 'fracao'
            ? 'Fração entre 0 e 1. O valor 0,5 significa metade do pipeline declarado.'
            : `Unidade: ${prazo.unidade}. Valor em uso hoje: ${valorDoPrazo(prazo)}.`
        }
      />

      <p className="texto-fraco">
        Este número mora em <code>valor.configuracoes</code>, e é lido pela regra a cada rodada de
        avaliação. Trocar aqui vale para a próxima rodada, e não recalcula alerta já aberto.
      </p>
    </Modal>
  )
}

// ------------------------------------------------------- a janela da meta

function JanelaDaMeta({
  meta,
  aoFechar,
}: {
  meta: MetaConfigurada | null
  aoFechar: () => void
}) {
  const [carregada, setCarregada] = useState<string | null>(null)
  const [texto, setTexto] = useState('')

  if (!meta) return null

  if (carregada !== meta.chave) {
    setCarregada(meta.chave)
    setTexto(meta.valor === null ? '' : String(meta.valor))
  }

  const lido = texto.trim() === '' ? null : Number(texto.replace(/\./g, '').replace(',', '.'))
  const invalido = lido === null || Number.isNaN(lido) || lido <= 0

  return (
    <Modal
      aberto
      aoFechar={aoFechar}
      titulo={meta.rotulo}
      legenda={`${ROTULO_PERIODO_META[meta.periodo]} · ${ROTULO_ESCOPO_META[meta.escopo]} · chave ${meta.chave}`}
      rodape={
        <>
          <Botao tom="discreto" onClick={aoFechar}>
            Cancelar
          </Botao>
          <Botao tom="principal" disabled={!temBanco() || invalido}>
            Gravar meta
          </Botao>
        </>
      }
    >
      {!temBanco() ? (
        <Alarme tom="amarelo" titulo="Meta não gravada nesta máquina">
          O banco ainda não está ligado aqui, então gravar fica desligado.
        </Alarme>
      ) : null}

      {metaEmBranco(meta) ? (
        <Alarme tom="amarelo" titulo="Esta meta está em branco">
          {SEM_META_SEM_COBERTURA}
        </Alarme>
      ) : null}

      {meta.escopo === 'por_pessoa' ? (
        <p>
          A meta por pessoa é uma linha por usuário. Esta janela informa a meta do período para
          quem for escolhido na tela de Usuários. Hoje há {inteiro(meta.pessoas_com_meta)}{' '}
          {meta.pessoas_com_meta === 1 ? 'pessoa com meta' : 'pessoas com meta'}.
        </p>
      ) : null}

      <Campo
        rotulo="Meta do período, em reais"
        inputMode="decimal"
        value={texto}
        onChange={(evento) => setTexto(evento.target.value)}
        erro={texto.trim() !== '' && invalido ? 'Informe um valor maior que zero.' : undefined}
        auxilio="Deixar em branco é uma escolha válida. Sem meta, o painel mostra a cobertura como indisponível."
      />

      <p className="texto-fraco">
        A cobertura de pipeline é o pipeline auditado dividido pela meta do período. Sem o segundo
        número, não existe divisão possível, e a plataforma prefere dizer indisponível a exibir
        qualquer coisa.
      </p>
    </Modal>
  )
}
