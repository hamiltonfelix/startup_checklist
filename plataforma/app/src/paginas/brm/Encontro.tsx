import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  Alarme,
  Botao,
  BotaoIA,
  Campo,
  CampoTexto,
  Carregando,
  Cartao,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Tabela,
  type ColunaTabela,
  type TomEtiqueta,
} from '@/componentes/indice'
import { useEncontro, type FichaDoEncontro } from '@/dados/brm'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import {
  EXPLICACAO_ITEM_RITUAL,
  ROTULO_FORMATO,
  ROTULO_ITEM_RITUAL,
  ROTULO_PRESENCA,
  ROTULO_STATUS_ENCONTRO,
  ROTULO_STATUS_ENTREGAVEL,
  ROTULO_TIPO_ENTREGAVEL,
  numeroDoEncontro,
  type BrmSituacaoPresenca,
  type BrmStatusEncontro,
  type BrmStatusEntregavel,
  type BrmTipoItemRitual,
  type EntregavelNaLista,
  type ItemRitualNaFicha,
  type PresencaNaFicha,
} from '@/tipos/brm'
import { data, dataPorExtenso, inteiro } from '@/tipos/rotulos'

/**
 * Ficha do encontro.
 *
 * Traz a presença por participante, o ritual semanal nos quatro tipos, os
 * entregáveis que o encontro gerou e a gravação ou transcrição quando houver.
 *
 * Confidencialidade não é trabalho desta tela. O banco decide o que entrega:
 * encontro restrito e anotação sobre gente do cliente simplesmente não chegam
 * para quem não pode vê-los. Se chegou, aparece aqui, sem `if` de perfil.
 */

const TOM_DO_ENCONTRO: Record<BrmStatusEncontro, TomEtiqueta> = {
  previsto: 'marca',
  realizado: 'verde',
  remarcado: 'amarela',
  cancelado: 'vermelha',
}

const TOM_DA_PRESENCA: Record<BrmSituacaoPresenca, TomEtiqueta> = {
  presente: 'verde',
  ausente_justificado: 'amarela',
  ausente: 'vermelha',
}

const TOM_DO_ENTREGAVEL: Record<BrmStatusEntregavel, TomEtiqueta> = {
  rascunho: 'neutra',
  entregue: 'marca',
  aprovado: 'verde',
}

const TIPOS_DO_RITUAL: BrmTipoItemRitual[] = ['highlight', 'lowlight', 'meta', 'prioridade']

export function Encontro() {
  const { encontroId } = useParams<{ encontroId: string }>()
  const consulta = useEncontro(encontroId)
  const [avisoAberto, setAvisoAberto] = useState(true)

  const ficha = consulta.data?.ficha ?? null

  return (
    <>
      <Migalhas
        itens={[
          { rotulo: 'BRM de Valor' },
          { rotulo: 'Encontros', para: '/encontros' },
          ...(ficha
            ? [{ rotulo: ficha.turma.codigo, para: `/turmas/${ficha.turma.id}` }]
            : []),
          { rotulo: ficha ? `Encontro ${ficha.encontro.numero}` : 'Encontro' },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">
            {ficha
              ? `${ficha.turma.codigo} · ${ficha.turma.programa_nome}`
              : 'BRM de Valor · Encontro'}
          </p>
          <h1 className="pagina__titulo">
            {ficha
              ? `Encontro ${numeroDoEncontro(ficha.encontro.numero, ficha.encontro.tentativa)}`
              : 'Ficha do encontro'}
          </h1>
          {ficha ? <p className="pagina__lede">{ficha.encontro.tema}</p> : null}
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          {ficha ? (
            <Link className="botao botao--contorno" to={`/turmas/${ficha.turma.id}`}>
              Voltar à turma
            </Link>
          ) : null}
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

      {consulta.isPending ? <Carregando texto="Abrindo a ficha do encontro" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A ficha não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data && !ficha && !consulta.isPending ? (
        <Cartao>
          <EstadoVazio
            titulo="Encontro não encontrado"
            texto="Nenhum encontro vivo responde por este endereço. Ou ele foi arquivado, ou a política de linha não entregou este encontro para quem está na sessão."
            acoes={
              <Link className="botao botao--principal" to="/encontros">
                Ir para a lista de encontros
              </Link>
            }
          />
        </Cartao>
      ) : null}

      {ficha ? (
        <>
          {ficha.encontro.restrito ? (
            <Alarme tom="amarelo" titulo="Encontro restrito" className="secao">
              Este encontro trata de pessoas do cliente e fica fora da ata enviada. Quem não pode
              vê-lo não recebe esta linha do banco, então esta tela não precisa esconder nada: ela
              mostra o que chegou.
            </Alarme>
          ) : null}

          <Cabecalho ficha={ficha} />
          <Numeracao ficha={ficha} />
          <TemaEResumo ficha={ficha} />
          <Presenca ficha={ficha} />
          <Ritual ficha={ficha} />
          <Entregaveis ficha={ficha} />
          <Registro ficha={ficha} />
        </>
      ) : null}
    </>
  )
}

// ------------------------------------------------------------------ cabeçalho

function Cabecalho({ ficha }: { ficha: FichaDoEncontro }) {
  const encontro = ficha.encontro

  return (
    <section className="secao" aria-labelledby="titulo-encontro-resumo">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-encontro-resumo">
          O encontro de relance
        </h2>
        <p className="secao__nota">
          Turma {ficha.turma.codigo} · {ficha.turma.programa_nome}
        </p>
      </div>

      <div className="grade grade--4">
        <Cartao tom="marca">
          <p className="kicker">Situação</p>
          <p style={{ marginTop: 'var(--esp-2)' }}>
            <Etiqueta tom={TOM_DO_ENCONTRO[encontro.status]} ponto>
              {ROTULO_STATUS_ENCONTRO[encontro.status]}
            </Etiqueta>
          </p>
          <p className="texto-fraco" style={{ marginTop: 'var(--esp-2)' }}>
            Encontro {numeroDoEncontro(encontro.numero, encontro.tentativa)} da sequência oficial
          </p>
        </Cartao>

        <Cartao>
          <p className="kicker">Data prevista</p>
          <p style={{ marginTop: 'var(--esp-2)' }}>{dataPorExtenso(encontro.data_prevista)}</p>
          <p className="texto-fraco">
            {encontro.hora_prevista_inicio && encontro.hora_prevista_fim
              ? `das ${encontro.hora_prevista_inicio} às ${encontro.hora_prevista_fim}`
              : 'horário a definir'}
          </p>
        </Cartao>

        <Cartao>
          <p className="kicker">Data realizada</p>
          <p style={{ marginTop: 'var(--esp-2)' }}>
            {encontro.data_realizada ? dataPorExtenso(encontro.data_realizada) : 'ainda não'}
          </p>
          <p className="texto-fraco">
            {ROTULO_FORMATO[encontro.formato]}
            {encontro.local ? ` · ${encontro.local}` : ''}
          </p>
        </Cartao>

        <Cartao>
          <p className="kicker">Quem conduziu</p>
          <p style={{ marginTop: 'var(--esp-2)' }}>{encontro.conselheiro_nome}</p>
          <p className="texto-fraco">apoio de {encontro.assessor_nome}</p>
        </Cartao>
      </div>

      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: 'var(--esp-2)',
          marginTop: 'var(--esp-4)',
        }}
      >
        {encontro.eh_presencial_do_mes ? <Etiqueta tom="realce">Presencial do mês</Etiqueta> : null}
        {encontro.eh_pauta_prioritaria ? (
          <Etiqueta tom="realce">Pauta prioritária do mês</Etiqueta>
        ) : null}
        {encontro.eh_encontro_de_gestao ? (
          <Etiqueta tom="neutra">Encontro semanal de gestão</Etiqueta>
        ) : null}
        {encontro.eh_hotseat ? <Etiqueta tom="marca">Hotseat do membro</Etiqueta> : null}
        {encontro.restrito ? <Etiqueta tom="vermelha">Restrito</Etiqueta> : null}
      </div>
    </section>
  )
}

// ---------------------------------------------- numeração e tentativas

function Numeracao({ ficha }: { ficha: FichaDoEncontro }) {
  const encontro = ficha.encontro
  const houveRemarcacao = ficha.tentativas.length > 0 || encontro.tentativa > 1

  if (!houveRemarcacao) return null

  return (
    <section className="secao" aria-labelledby="titulo-numeracao">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-numeracao">
          Numeração e tentativas
        </h2>
        <p className="secao__nota">
          A remarcação não perde a numeração original. Este continua sendo o encontro{' '}
          {encontro.numero} da turma, na tentativa {encontro.tentativa}.
        </p>
      </div>

      <Cartao>
        <ol style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 'var(--esp-3)' }}>
          {[...ficha.tentativas, encontro]
            .sort((a, b) => a.tentativa - b.tentativa)
            .map((linha) => (
              <li
                key={linha.id}
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  alignItems: 'baseline',
                  gap: 'var(--esp-3)',
                  paddingBottom: 'var(--esp-3)',
                  borderBottom: '1px solid var(--cor-linha)',
                }}
              >
                <span className="kicker" style={{ minWidth: '7rem' }}>
                  Tentativa {linha.tentativa}
                </span>
                <Etiqueta tom={TOM_DO_ENCONTRO[linha.status]} ponto>
                  {ROTULO_STATUS_ENCONTRO[linha.status]}
                </Etiqueta>
                <span>marcada para {data(linha.data_prevista)}</span>
                {linha.data_realizada ? (
                  <span className="texto-fraco">realizada em {data(linha.data_realizada)}</span>
                ) : null}
                {linha.motivo_remarcacao ? (
                  <span className="texto-fraco">{linha.motivo_remarcacao}</span>
                ) : null}
                {linha.id === encontro.id ? (
                  <Etiqueta tom="solida">Você está aqui</Etiqueta>
                ) : (
                  <Link className="botao botao--discreto botao--pp" to={`/encontros/${linha.id}`}>
                    Abrir
                  </Link>
                )}
              </li>
            ))}
        </ol>
      </Cartao>
    </section>
  )
}

// ------------------------------------------------------- tema e resumo com IA

/**
 * O tema e o resumo, com o botão assistido ao lado de cada um.
 *
 * Nada entra no campo sem a pessoa mandar: quem escreve é ela, apertando
 * aceitar na caixa do assistente. O contexto que vai para o serviço é público:
 * turma, número, data e tema. A transcrição é confidencial e não trafega por
 * aqui, mesmo quando existe.
 */
function TemaEResumo({ ficha }: { ficha: FichaDoEncontro }) {
  const encontro = ficha.encontro
  const [tema, setTema] = useState(encontro.tema)
  const [resumo, setResumo] = useState('')

  // Trocar de encontro sem sair da tela precisa recarregar o campo.
  useEffect(() => {
    setTema(encontro.tema)
    setResumo('')
  }, [encontro.id, encontro.tema])

  const contexto = {
    turma: ficha.turma.codigo,
    programa: ficha.turma.programa_nome,
    encontro: encontro.numero,
    data_prevista: encontro.data_prevista,
    tem_transcricao: encontro.transcricao_url || encontro.transcricao_texto ? 'sim' : 'nao',
  }

  return (
    <section className="secao" aria-labelledby="titulo-tema">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-tema">
          Tema e resumo
        </h2>
        <p className="secao__nota">
          O assistente propõe texto, e só isso. Nada entra no campo sem você aceitar. A gravação
          destes dois campos no banco entra quando a escrita for ligada nesta tela.
        </p>
      </div>

      <Cartao>
        <div style={{ display: 'grid', gap: 'var(--esp-5)' }}>
          <Campo
            rotulo="Tema do encontro"
            value={tema}
            maxLength={160}
            contador
            valorAtual={tema}
            onChange={(evento) => setTema(evento.target.value)}
            auxilio="O tema da pauta, como ele entra na ata e na agenda da turma."
            acessorio={
              <BotaoIA
                campo="pauta_encontro"
                textoAtual={tema}
                contexto={contexto}
                aoAceitar={setTema}
                rotulo="Sugerir tema"
              />
            }
          />

          <CampoTexto
            multiplas_linhas
            rotulo="Resumo do encontro"
            rows={5}
            value={resumo}
            maxLength={1200}
            contador
            valorAtual={resumo}
            onChange={(evento) => setResumo(evento.target.value)}
            auxilio={
              encontro.transcricao_url || encontro.transcricao_texto
                ? 'Este encontro tem transcrição registrada. O assistente parte dela, que fica no servidor e não trafega por esta tela.'
                : 'Este encontro ainda não tem transcrição registrada. O assistente parte do que já estiver escrito aqui.'
            }
            acessorio={
              <BotaoIA
                campo="resumo_interacao"
                textoAtual={resumo}
                contexto={contexto}
                aoAceitar={setResumo}
                rotulo="Sugerir resumo"
              />
            }
          />
        </div>
      </Cartao>
    </section>
  )
}

// -------------------------------------------------------------------- presença

function Presenca({ ficha }: { ficha: FichaDoEncontro }) {
  const presentes = ficha.presencas.filter((linha) => linha.situacao === 'presente').length
  const convocados = ficha.presencas.length

  const colunas: Array<ColunaTabela<PresencaNaFicha>> = [
    {
      chave: 'cadeira',
      rotulo: 'Cadeira',
      alinhamento: 'numero',
      conteudo: (linha) => (
        <span className="numero">{linha.cadeira === null ? 'sem cadeira' : linha.cadeira}</span>
      ),
    },
    {
      chave: 'pessoa',
      rotulo: 'Participante',
      conteudo: (linha) => <strong>{linha.participante_nome}</strong>,
    },
    {
      chave: 'conta',
      rotulo: 'Conta',
      conteudo: (linha) => <Etiqueta tom="marca">{linha.conta_nome}</Etiqueta>,
    },
    {
      chave: 'situacao',
      rotulo: 'Presença',
      conteudo: (linha) => (
        <Etiqueta tom={TOM_DA_PRESENCA[linha.situacao]} ponto>
          {ROTULO_PRESENCA[linha.situacao]}
        </Etiqueta>
      ),
    },
    {
      chave: 'minutos',
      rotulo: 'Minutos',
      alinhamento: 'numero',
      conteudo: (linha) =>
        linha.minutos_presentes === null ? (
          <span className="texto-fraco">sem registro</span>
        ) : (
          <span className="numero">{inteiro(linha.minutos_presentes)}</span>
        ),
    },
    {
      chave: 'justificativa',
      rotulo: 'Justificativa',
      conteudo: (linha) =>
        linha.justificativa ? (
          linha.justificativa
        ) : (
          <span className="texto-fraco">sem justificativa</span>
        ),
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-presenca">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-presenca">
          Presença por participante
        </h2>
        <p className="secao__nota">
          {convocados === 0
            ? 'Nenhuma presença registrada neste encontro.'
            : `${inteiro(presentes)} de ${inteiro(convocados)} convocados estiveram presentes.`}
        </p>
      </div>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={ficha.presencas}
          chaveDaLinha={(linha) => linha.id}
          legenda="Presença de cada participante no encontro, com a conta de origem."
          vazioTitulo="Presença ainda não registrada"
          vazioTexto="O encontro ainda não teve a chamada lançada."
        />
      </Cartao>
    </section>
  )
}

// -------------------------------------------------------------- ritual semanal

function Ritual({ ficha }: { ficha: FichaDoEncontro }) {
  return (
    <section className="secao" aria-labelledby="titulo-ritual">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-ritual">
          Ritual semanal
        </h2>
        <p className="secao__nota">
          Highlights, Lowlights, Metas e Prioridades. Todo item tem tópico, responsável e data, como
          manda o template do Conselho de Valor.
        </p>
      </div>

      {ficha.ritual.length === 0 ? (
        <Cartao>
          <EstadoVazio
            titulo="Ritual ainda não lançado"
            texto="Este encontro não tem item de ritual registrado. Sem Highlights, Lowlights, Metas e Prioridades, a semana seguinte começa sem dono e sem data."
          />
        </Cartao>
      ) : (
        <div className="grade grade--2">
          {TIPOS_DO_RITUAL.map((tipo) => (
            <BlocoDoRitual
              key={tipo}
              tipo={tipo}
              itens={ficha.ritual.filter((item) => item.tipo === tipo)}
            />
          ))}
        </div>
      )}
    </section>
  )
}

function BlocoDoRitual({
  tipo,
  itens,
}: {
  tipo: BrmTipoItemRitual
  itens: ItemRitualNaFicha[]
}) {
  return (
    <Cartao
      tom={tipo === 'lowlight' ? 'plano' : 'simples'}
      titulo={ROTULO_ITEM_RITUAL[tipo]}
      legenda={EXPLICACAO_ITEM_RITUAL[tipo]}
      acoes={<Etiqueta tom="neutra">{inteiro(itens.length)}</Etiqueta>}
    >
      {itens.length === 0 ? (
        <p className="texto-fraco">Nenhum item deste tipo neste encontro.</p>
      ) : (
        <ul className="lista-felix" style={{ margin: 0, padding: 0, listStyle: 'none' }}>
          {itens.map((item) => (
            <li key={item.id}>
              <strong>{item.topico}</strong>
              <br />
              <span className="texto-fraco">
                {item.responsavel_exibido} · data {data(item.data_alvo)}
                {item.concluido_em ? ` · concluído em ${data(item.concluido_em)}` : ''}
              </span>
              {item.evidencia ? (
                <>
                  <br />
                  <span className="texto-fraco">Evidência: {item.evidencia}</span>
                </>
              ) : null}
            </li>
          ))}
        </ul>
      )}
    </Cartao>
  )
}

// ---------------------------------------------------- entregáveis do encontro

function Entregaveis({ ficha }: { ficha: FichaDoEncontro }) {
  const colunas: Array<ColunaTabela<EntregavelNaLista>> = [
    {
      chave: 'tipo',
      rotulo: 'Tipo',
      conteudo: (linha) => ROTULO_TIPO_ENTREGAVEL[linha.tipo],
    },
    {
      chave: 'titulo',
      rotulo: 'Título',
      conteudo: (linha) => <strong>{linha.titulo}</strong>,
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
        <Etiqueta tom={TOM_DO_ENTREGAVEL[linha.status]} ponto>
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
    <section className="secao" aria-labelledby="titulo-entregaveis-encontro">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-entregaveis-encontro">
          Entregáveis do encontro
        </h2>
        <p className="secao__nota">
          O que este encontro produziu, com a marca que decide o que o participante enxerga no
          portal dele.
        </p>
      </div>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={ficha.entregaveis}
          chaveDaLinha={(linha) => linha.id}
          legenda="Entregáveis gerados neste encontro."
          vazioTitulo="Nenhum entregável neste encontro"
          vazioTexto="Nem a ata saiu ainda. O fluxo é o assessor escrever, o conselheiro aprovar e o sistema enviar."
          vazioAcoes={
            <Link className="botao botao--contorno" to="/entregaveis">
              Ver todos os entregáveis
            </Link>
          }
        />
      </Cartao>
    </section>
  )
}

// ------------------------------------------------------ gravação e transcrição

function Registro({ ficha }: { ficha: FichaDoEncontro }) {
  const encontro = ficha.encontro
  const temAlgo = Boolean(
    encontro.gravacao_url || encontro.transcricao_url || encontro.transcricao_texto,
  )

  return (
    <section className="secao" aria-labelledby="titulo-registro">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-registro">
          Gravação e transcrição
        </h2>
        <p className="secao__nota">
          Material bruto da reunião. Chega apenas para quem a política de linha permite, e por isso
          esta tela mostra o que chegou sem conferir perfil.
        </p>
      </div>

      <Cartao>
        {!temAlgo ? (
          <EstadoVazio
            titulo="Sem gravação e sem transcrição"
            texto="Este encontro não tem gravação nem transcrição registradas, ou elas não foram entregues para quem está na sessão."
          />
        ) : (
          <div style={{ display: 'grid', gap: 'var(--esp-4)' }}>
            {encontro.gravacao_url ? (
              <p>
                <span className="kicker">Gravação</span>
                <br />
                <a href={encontro.gravacao_url} target="_blank" rel="noreferrer">
                  Abrir a gravação do encontro {encontro.numero}
                </a>
              </p>
            ) : null}

            {encontro.transcricao_url ? (
              <p>
                <span className="kicker">Transcrição</span>
                <br />
                <a href={encontro.transcricao_url} target="_blank" rel="noreferrer">
                  Abrir a transcrição do encontro {encontro.numero}
                </a>
              </p>
            ) : null}

            {encontro.transcricao_texto ? (
              <div>
                <span className="kicker">Trecho da transcrição</span>
                <p style={{ marginTop: 'var(--esp-2)' }}>{encontro.transcricao_texto}</p>
              </div>
            ) : null}

            {encontro.observacoes_restritas ? (
              <Alarme tom="amarelo" titulo="Anotação restrita">
                {encontro.observacoes_restritas}
              </Alarme>
            ) : null}
          </div>
        )}
      </Cartao>
    </section>
  )
}
