import { useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  Abas,
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
  type Aba,
  type ColunaTabela,
} from '@/componentes/indice'
import { useFichaDaConta } from '@/dados/crm'
import { AvisoDeFonte, EtiquetaFase, EtiquetaForecast, EtiquetaHigiene } from '@/paginas/crm/Negocios'
import {
  dinheiroOuAusente,
  origemDoTier,
  ROTULO_ORIGEM_TIER,
  ROTULO_PRIORIDADE,
  ROTULO_SITUACAO_CONTRATO,
  situacaoDaConta,
  textoOuAusente,
  type FichaDaConta,
  type LinhaAlertaAberto,
  type LinhaConta,
  type LinhaContato,
  type LinhaContratoEmCurso,
  type LinhaInteracao,
  type LinhaNegocioForecast,
  type LinhaSaudeDaConta,
} from '@/tipos/crm'
import {
  data,
  dataPorExtenso,
  inteiro,
  ROTULO_ARTEFATO,
  ROTULO_CANAL,
  ROTULO_NIVEL,
  ROTULO_TIER,
} from '@/tipos/rotulos'

/**
 * A ficha da conta, em seis abas.
 *
 * Resumo, Pessoas, Negócios, Contratos, Interações e Saúde. A aba Saúde lê
 * `valor.vw_saude_da_conta` inteira. Nenhum dado é escondido por perfil nesta
 * tela: quem decide o que cada um enxerga é a política de linha do banco. O
 * que não veio aparece como não informado, nunca como zero.
 */
export function Conta() {
  const { id } = useParams<{ id: string }>()
  const consulta = useFichaDaConta(id)
  const [aba, setAba] = useState('resumo')

  const ficha = consulta.data?.dados

  return (
    <>
      <Migalhas
        itens={[
          { rotulo: 'CRM de Valor', para: '/painel' },
          { rotulo: 'Contas', para: '/contas' },
          { rotulo: ficha?.conta.nome ?? 'Conta' },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Ficha da conta</p>
          <h1 className="pagina__titulo">{ficha?.conta.nome ?? 'Conta'}</h1>
          {ficha ? (
            <p className="pagina__lede">
              {textoOuAusente(ficha.conta.setor, 'sem setor')} ·{' '}
              {textoOuAusente(
                [ficha.conta.cidade, ficha.conta.uf].filter(Boolean).join(' · '),
                'sem cidade informada',
              )}{' '}
              · {situacaoDaConta(ficha.conta)}
            </p>
          ) : null}
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      <AvisoDeFonte deExemplo={consulta.data?.deExemplo} />

      {consulta.isPending ? <Carregando texto="Carregando a ficha da conta" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A ficha não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {ficha ? (
        <Abas
          rotulo="Seções da ficha da conta"
          ativa={aba}
          aoTrocar={setAba}
          abas={montarAbas(ficha)}
        />
      ) : null}
    </>
  )
}

function montarAbas(ficha: FichaDaConta): Aba[] {
  const conta = ficha.conta

  return [
    { chave: 'resumo', rotulo: 'Resumo', conteudo: <AbaResumo conta={conta} /> },
    {
      chave: 'pessoas',
      rotulo: 'Pessoas',
      contagem: ficha.contatos.length,
      conteudo: <AbaPessoas contatos={ficha.contatos} />,
    },
    {
      chave: 'negocios',
      rotulo: 'Negócios',
      contagem: ficha.negocios.length,
      conteudo: <AbaNegocios negocios={ficha.negocios} />,
    },
    {
      chave: 'contratos',
      rotulo: 'Contratos',
      contagem: ficha.contratos.length,
      conteudo: <AbaContratos contratos={ficha.contratos} />,
    },
    {
      chave: 'interacoes',
      rotulo: 'Interações',
      contagem: ficha.interacoes.length,
      conteudo: <AbaInteracoes conta={conta} interacoes={ficha.interacoes} />,
    },
    {
      chave: 'saude',
      rotulo: 'Saúde',
      conteudo: <AbaSaude saude={ficha.saude} alertas={ficha.alertas} />,
    },
  ]
}

// ------------------------------------------------------------- linha seca

function Dado({ rotulo, children }: { rotulo: string; children: ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--esp-1)' }}>
      <span
        style={{
          fontSize: 'var(--texto-micro)',
          textTransform: 'uppercase',
          letterSpacing: 'var(--espaco-letra-rotulo)',
          color: 'var(--cor-texto-fraco)',
        }}
      >
        {rotulo}
      </span>
      <span style={{ fontSize: 'var(--texto-base)' }}>{children}</span>
    </div>
  )
}

/** Número grande com legenda, do jeito que o painel da casa mostra placar. */
function Placar({ rotulo, valor, nota }: { rotulo: string; valor: string; nota?: string }) {
  return (
    <article
      style={{
        border: '1px solid var(--cor-linha)',
        borderRadius: 'var(--raio-g)',
        padding: 'var(--esp-4)',
        background: 'var(--cor-superficie)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--esp-1)',
      }}
    >
      <span
        style={{
          fontSize: 'var(--texto-micro)',
          textTransform: 'uppercase',
          letterSpacing: 'var(--espaco-letra-rotulo)',
          color: 'var(--cor-texto-fraco)',
        }}
      >
        {rotulo}
      </span>
      <span style={{ fontFamily: 'var(--fonte-numero)', fontSize: 'var(--texto-2xg)' }}>{valor}</span>
      {nota ? (
        <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>{nota}</span>
      ) : null}
    </article>
  )
}

// --------------------------------------------------------------- resumo

function AbaResumo({ conta }: { conta: LinhaConta }) {
  const [resumo, setResumo] = useState(conta.observacoes ?? '')
  const origem = origemDoTier(conta)
  const emUso = conta.tier ?? conta.tier_sugerido

  return (
    <>
      <Cartao titulo="Dados da conta" className="secao">
        <div className="grade grade--3">
          <Dado rotulo="Razão social">{textoOuAusente(conta.razao_social)}</Dado>
          <Dado rotulo="CNPJ">{textoOuAusente(conta.cnpj)}</Dado>
          <Dado rotulo="Setor">{textoOuAusente(conta.setor, 'sem setor')}</Dado>
          <Dado rotulo="Porte">{textoOuAusente(conta.porte)}</Dado>
          <Dado rotulo="Cidade e estado">
            {textoOuAusente(
              [conta.cidade, conta.uf].filter(Boolean).join(' · '),
              'sem cidade informada',
            )}
          </Dado>
          <Dado rotulo="Sítio">{textoOuAusente(conta.site)}</Dado>
          <Dado rotulo="Tier">
            {emUso ? (
              <>
                <Etiqueta tom={origem === 'confirmado' ? 'marca' : 'neutra'}>
                  {ROTULO_TIER[emUso]}
                </Etiqueta>{' '}
                <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
                  {ROTULO_ORIGEM_TIER[origem]}
                  {origem === 'confirmado' && conta.tier_confirmado_em
                    ? ` em ${data(conta.tier_confirmado_em)}`
                    : ''}
                </span>
              </>
            ) : (
              'sem tier definido'
            )}
          </Dado>
          <Dado rotulo="Prioridade">
            {conta.prioridade ? ROTULO_PRIORIDADE[conta.prioridade] : 'sem prioridade'}
          </Dado>
          <Dado rotulo="Power of X">
            {inteiro(conta.power_of_x)}{' '}
            {conta.power_of_x === 1 ? 'linha do portfólio' : 'linhas do portfólio'}
          </Dado>
          <Dado rotulo="Gerente de Contas">
            {textoOuAusente(conta.gerente_contas_nome, 'sem responsável')}
          </Dado>
          <Dado rotulo="Situação">{situacaoDaConta(conta)}</Dado>
          <Dado rotulo="Na base desde">{data(conta.criado_em)}</Dado>
        </div>
      </Cartao>

      <Cartao
        titulo="Resumo da conta"
        legenda="O texto que abre a conversa sobre esta conta. Nada entra no campo sem você mandar."
      >
        <CampoTexto
          multiplas_linhas
          rotulo="Resumo"
          rows={5}
          maxLength={1200}
          contador
          valorAtual={resumo}
          value={resumo}
          onChange={(evento) => setResumo(evento.target.value)}
          auxilio="O assistente propõe um texto. Você aceita, edita ou descarta."
          acessorio={
            <BotaoIA
              campo="texto_livre"
              textoAtual={resumo}
              aoAceitar={setResumo}
              contexto={{
                conta: conta.nome,
                setor: conta.setor,
                cidade: conta.cidade,
                power_of_x: conta.power_of_x,
              }}
            />
          }
        />
      </Cartao>
    </>
  )
}

// --------------------------------------------------------------- pessoas

function AbaPessoas({ contatos }: { contatos: LinhaContato[] }) {
  if (contatos.length === 0) {
    return (
      <Cartao>
        <EstadoVazio
          titulo="Nenhuma pessoa registrada"
          texto="Ainda não há contato cadastrado nesta conta, ou este perfil não alcança a lista."
        />
      </Cartao>
    )
  }

  return (
    <section className="secao" aria-labelledby="titulo-pessoas">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-pessoas">
          Pessoas da conta
        </h2>
        <p className="secao__nota">
          Cada pessoa com o cargo e o papel que ocupa na decisão. Endereço eletrônico e telefone são
          colunas confidenciais: quando não vêm do banco, aparecem como não informados.
        </p>
      </div>

      <div className="grade grade--2">
        {contatos.map((contato) => (
          <Cartao
            key={contato.id}
            titulo={contato.nome}
            legenda={textoOuAusente(contato.cargo, 'sem cargo informado')}
            acoes={contato.eh_principal ? <Etiqueta tom="marca">Contato principal</Etiqueta> : null}
          >
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--esp-3)' }}>
              <Dado rotulo="Papel na decisão">
                <Etiqueta tom="realce">
                  {textoOuAusente(contato.papel_decisao, 'papel não informado')}
                </Etiqueta>
              </Dado>
              <Dado rotulo="Endereço eletrônico">{textoOuAusente(contato.email)}</Dado>
              <Dado rotulo="Telefone">{textoOuAusente(contato.telefone)}</Dado>
              {contato.observacoes ? (
                <Dado rotulo="Observações">{contato.observacoes}</Dado>
              ) : null}
            </div>
          </Cartao>
        ))}
      </div>
    </section>
  )
}

// -------------------------------------------------------------- negócios

function AbaNegocios({ negocios }: { negocios: LinhaNegocioForecast[] }) {
  const colunas: Array<ColunaTabela<LinhaNegocioForecast>> = [
    {
      chave: 'titulo',
      rotulo: 'Negócio',
      conteudo: (linha) => (
        <Link to={`/negocios/${linha.negocio_id}`} style={{ fontWeight: 'var(--peso-forte)' }}>
          {linha.titulo}
        </Link>
      ),
    },
    { chave: 'fase', rotulo: 'Fase', conteudo: (linha) => <EtiquetaFase fase={linha.fase} /> },
    {
      chave: 'categoria',
      rotulo: 'Categoria de forecast',
      conteudo: (linha) => (
        <EtiquetaForecast
          categoria={linha.categoria}
          artefato={linha.artefato_que_sustenta ? ROTULO_ARTEFATO[linha.artefato_que_sustenta] : null}
        />
      ),
    },
    {
      chave: 'higiene',
      rotulo: 'Higiene',
      conteudo: (linha) => <EtiquetaHigiene negocio={linha} />,
    },
    {
      chave: 'decisao',
      rotulo: 'Data da decisão do cliente',
      conteudo: (linha) => data(linha.data_decisao_cliente),
    },
    {
      chave: 'valor',
      rotulo: 'Valor',
      alinhamento: 'numero',
      conteudo: (linha) => dinheiroOuAusente(linha.valor_total ?? linha.valor_considerado),
    },
  ]

  return (
    <Cartao semRespiro>
      <Tabela
        colunas={colunas}
        linhas={negocios}
        chaveDaLinha={(linha) => linha.negocio_id}
        legenda="Negócios desta conta, com fase, categoria de forecast e sinal de higiene."
        vazioTitulo="Nenhum negócio nesta conta"
        vazioTexto="Não há negócio registrado, ou este perfil não alcança a lista."
      />
    </Cartao>
  )
}

// ------------------------------------------------------------- contratos

const TOM_VENCIMENTO: Record<string, 'verde' | 'amarela' | 'vermelha' | 'neutra'> = {
  verde: 'verde',
  amarelo: 'amarela',
  vermelho: 'vermelha',
  vencido: 'vermelha',
  sem_vigencia_fim: 'neutra',
}

function AbaContratos({ contratos }: { contratos: LinhaContratoEmCurso[] }) {
  const colunas: Array<ColunaTabela<LinhaContratoEmCurso>> = [
    {
      chave: 'numero',
      rotulo: 'Contrato de Valor',
      conteudo: (linha) => (
        <>
          <strong>{linha.numero}</strong>
          <br />
          <span className="texto-fraco">{textoOuAusente(linha.titulo, 'sem título')}</span>
        </>
      ),
    },
    {
      chave: 'oferta',
      rotulo: 'Oferta',
      conteudo: (linha) => textoOuAusente(linha.oferta_nome, 'sem oferta vinculada'),
    },
    {
      chave: 'nivel',
      rotulo: 'Nível',
      conteudo: (linha) => ROTULO_NIVEL[linha.nivel],
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta tom={linha.situacao === 'vigente' ? 'verde' : 'neutra'} ponto>
          {ROTULO_SITUACAO_CONTRATO[linha.situacao]}
        </Etiqueta>
      ),
    },
    {
      chave: 'vigencia',
      rotulo: 'Vigência',
      conteudo: (linha) =>
        linha.vigencia_fim
          ? `${data(linha.vigencia_inicio)} a ${data(linha.vigencia_fim)}`
          : `a partir de ${data(linha.vigencia_inicio)}`,
    },
    {
      chave: 'sinal',
      rotulo: 'Renovação',
      conteudo: (linha) => (
        <>
          <Etiqueta tom={TOM_VENCIMENTO[linha.sinal_de_vencimento] ?? 'neutra'} ponto>
            {linha.dias_para_vencer === null
              ? 'sem data de encerramento'
              : `${inteiro(linha.dias_para_vencer)} dias para vencer`}
          </Etiqueta>
          {linha.tem_negocio_de_renovacao && linha.negocio_renovacao_id ? (
            <>
              <br />
              <Link to={`/negocios/${linha.negocio_renovacao_id}`} className="texto-fraco">
                já existe negócio de renovação
              </Link>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'valor',
      rotulo: 'Valor mensal',
      alinhamento: 'numero',
      conteudo: (linha) => dinheiroOuAusente(linha.valor_mensal),
    },
  ]

  return (
    <Cartao semRespiro>
      <Tabela
        colunas={colunas}
        linhas={contratos}
        chaveDaLinha={(linha) => linha.contrato_id}
        legenda="Contratos de Valor em curso nesta conta, com vigência e sinal de renovação."
        vazioTitulo="Nenhum Contrato de Valor em curso"
        vazioTexto="Não há contrato vigente, pausado ou aguardando assinatura para esta conta."
      />
    </Cartao>
  )
}

// ------------------------------------------------------------ interações

function AbaInteracoes({ conta, interacoes }: { conta: LinhaConta; interacoes: LinhaInteracao[] }) {
  const [assunto, setAssunto] = useState('')
  const [resumo, setResumo] = useState('')

  return (
    <>
      <Cartao
        titulo="Rascunho de interação"
        legenda="O rascunho fica só nesta tela enquanto a gravação de interação não entra. Nada é enviado."
        className="secao"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--esp-4)' }}>
          <Campo
            rotulo="Assunto"
            value={assunto}
            maxLength={160}
            onChange={(evento) => setAssunto(evento.target.value)}
          />
          <CampoTexto
            multiplas_linhas
            rotulo="Resumo da interação"
            rows={4}
            maxLength={1200}
            contador
            valorAtual={resumo}
            value={resumo}
            onChange={(evento) => setResumo(evento.target.value)}
            auxilio="O assistente propõe um texto a partir do que já está escrito. Você aceita, edita ou descarta."
            acessorio={
              <BotaoIA
                campo="resumo_interacao"
                textoAtual={resumo}
                aoAceitar={setResumo}
                contexto={{ conta: conta.nome, assunto: assunto || null }}
              />
            }
          />
        </div>
      </Cartao>

      <section className="secao" aria-labelledby="titulo-historico-conta">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-historico-conta">
            Histórico de interações
          </h2>
          <p className="secao__nota">
            {inteiro(interacoes.length)}{' '}
            {interacoes.length === 1 ? 'conversa registrada' : 'conversas registradas'}. Conversa
            marcada como restrita só aparece para quem o banco deixa ver.
          </p>
        </div>

        <Cartao>
          <ListaDeInteracoes interacoes={interacoes} />
        </Cartao>
      </section>
    </>
  )
}

/** A linha do tempo de interações. Serve à ficha da conta e à do negócio. */
export function ListaDeInteracoes({ interacoes }: { interacoes: LinhaInteracao[] }) {
  if (interacoes.length === 0) {
    return (
      <EstadoVazio
        titulo="Nenhuma conversa registrada"
        texto="Assim que uma interação for registrada, ela aparece aqui, da mais recente para a mais antiga."
      />
    )
  }

  return (
    <ol style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 'var(--esp-4)' }}>
      {interacoes.map((interacao) => (
        <li
          key={interacao.id}
          style={{
            borderLeft: '3px solid var(--cor-marca)',
            paddingLeft: 'var(--esp-4)',
            display: 'flex',
            flexDirection: 'column',
            gap: 'var(--esp-1)',
          }}
        >
          <div style={{ display: 'flex', gap: 'var(--esp-2)', alignItems: 'center', flexWrap: 'wrap' }}>
            <Etiqueta tom="neutra">{ROTULO_CANAL[interacao.canal]}</Etiqueta>
            <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
              {dataPorExtenso(interacao.ocorrida_em)}
            </span>
            {interacao.restrita ? <Etiqueta tom="vermelha">Restrita</Etiqueta> : null}
            {interacao.gerado_com_ia ? <Etiqueta tom="realce">Escrita com apoio de IA</Etiqueta> : null}
          </div>

          <strong style={{ fontSize: 'var(--texto-m)' }}>{interacao.assunto}</strong>

          {interacao.resumo ? (
            <p style={{ color: 'var(--cor-texto-suave)' }}>{interacao.resumo}</p>
          ) : (
            <p className="texto-fraco">sem resumo registrado</p>
          )}

          <p style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
            {textoOuAusente(interacao.usuario_nome, 'autoria não informada')} ·{' '}
            {textoOuAusente(interacao.contato_nome, 'sem contato vinculado')}
          </p>
        </li>
      ))}
    </ol>
  )
}

// ----------------------------------------------------------------- saúde

function AbaSaude({
  saude,
  alertas,
}: {
  saude: LinhaSaudeDaConta | null
  alertas: LinhaAlertaAberto[]
}) {
  if (!saude) {
    return (
      <Cartao>
        <EstadoVazio
          titulo="A leitura de saúde não veio"
          texto="O banco não devolveu vw_saude_da_conta para esta conta neste perfil. A tela não inventa número no lugar dela."
        />
      </Cartao>
    )
  }

  return (
    <>
      <section className="secao" aria-labelledby="titulo-saude">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-saude">
            Saúde da conta
          </h2>
          <p className="secao__nota">Leitura de vw_saude_da_conta, uma linha por conta.</p>
        </div>

        <div className="grade grade--3">
          <Placar
            rotulo="Tier"
            valor={saude.tier_rotulo}
            nota={
              saude.tier_confirmado_em
                ? `Confirmado por gente em ${data(saude.tier_confirmado_em)}`
                : 'Sugerido pelo sistema, ainda sem confirmação'
            }
          />
          <Placar
            rotulo="Power of X"
            valor={inteiro(saude.power_of_x)}
            nota={
              saude.power_of_x === 1
                ? 'linha do portfólio já comprada'
                : 'linhas do portfólio já compradas'
            }
          />
          <Placar
            rotulo="NPS mais recente"
            valor={saude.nps === null ? 'sem resposta' : inteiro(saude.nps)}
            nota={
              saude.nps === null
                ? 'nenhuma resposta de pesquisa chegou para esta conta'
                : `${inteiro(saude.nps_respondentes)} respondentes · última resposta em ${data(saude.nps_ultima_resposta)}`
            }
          />
          <Placar
            rotulo="Contratos vivos"
            valor={inteiro(saude.contratos_vigentes)}
            nota={`${dinheiroOuAusente(saude.valor_mensal_vigente)} por mês · próximo vencimento em ${data(saude.proximo_vencimento_de_contrato)}`}
          />
          <Placar
            rotulo="Último contato"
            valor={saude.ultimo_contato_em === null ? 'sem registro' : data(saude.ultimo_contato_em)}
            nota={
              saude.dias_sem_contato === null
                ? 'nenhuma interação registrada nesta conta'
                : `${inteiro(saude.dias_sem_contato)} dias sem conversa registrada`
            }
          />
          <Placar
            rotulo="Alertas abertos"
            valor={inteiro(saude.alertas_abertos)}
            nota={`${inteiro(saude.alertas_vermelhos)} em vermelho · reconhecer não é resolver`}
          />
        </div>
      </section>

      <section className="secao" aria-labelledby="titulo-saude-extra">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-saude-extra">
            O que está aberto
          </h2>
          <p className="secao__nota">
            Pipeline da conta, turmas em andamento, pendências vencidas e a lista de alertas.
          </p>
        </div>

        <Cartao className="secao">
          <div className="grade grade--4">
            <Dado rotulo="Negócios ativos">{inteiro(saude.negocios_ativos)}</Dado>
            <Dado rotulo="Pipeline da conta">{dinheiroOuAusente(saude.pipeline_da_conta)}</Dado>
            <Dado rotulo="Turmas em andamento">{inteiro(saude.turmas_ativas)}</Dado>
            <Dado rotulo="Pendências vencidas">{inteiro(saude.pendencias_vencidas)}</Dado>
          </div>
        </Cartao>

        <Cartao titulo="Alertas abertos">
          {alertas.length === 0 ? (
            <EstadoVazio
              titulo="Nenhum alerta aberto"
              texto="Nada nesta conta pede ação hoje."
              marca="&#10003;"
            />
          ) : (
            <ul className="lista-felix">
              {alertas.map((alerta) => (
                <li key={alerta.alerta_id}>
                  <Etiqueta
                    tom={
                      alerta.criticidade === 'vermelho'
                        ? 'vermelha'
                        : alerta.criticidade === 'amarelo'
                          ? 'amarela'
                          : 'verde'
                    }
                    ponto
                  >
                    {alerta.criticidade_rotulo}
                  </Etiqueta>{' '}
                  {alerta.mensagem}
                  <br />
                  <span style={{ fontSize: 'var(--texto-pp)', color: 'var(--cor-texto-fraco)' }}>
                    {textoOuAusente(alerta.regra_nome, 'regra não informada')} ·{' '}
                    {alerta.dias_aberto === null
                      ? 'sem tempo apurado'
                      : `aberto há ${inteiro(alerta.dias_aberto)} dias`}{' '}
                    · quem age: {textoOuAusente(alerta.quem_age_nome, 'não informado')}
                  </span>
                  {alerta.negocio_id ? (
                    <>
                      {' '}
                      <Link to={`/negocios/${alerta.negocio_id}`}>abrir o negócio</Link>
                    </>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
        </Cartao>
      </section>
    </>
  )
}
