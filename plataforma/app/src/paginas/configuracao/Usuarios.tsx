import { useMemo, useState } from 'react'
import {
  Abas,
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
  type Aba,
  type ColunaTabela,
  type TomEtiqueta,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO, temBanco } from '@/dados/cliente'
import { useUsuarios } from '@/dados/configuracao'
import { inteiro } from '@/tipos/rotulos'
import {
  ALCANCE,
  AVISO_CONTA_DE_EMERGENCIA,
  dataHora,
  diasAte,
  PERFIS,
  ROTULO_PERFIL_PLATAFORMA,
  ROTULO_SITUACAO_CONVITE,
  situacaoDoConvite,
  type ConviteNaTela,
  type PerfilPlataforma,
  type SituacaoConvite,
  type UsuarioNaTela,
} from '@/tipos/configuracao'

/**
 * Gestão de usuários.
 *
 * Sem esta tela ninguém entra na plataforma, e por isso ela entra na primeira
 * entrega, não depois. Ela cobre convidar por endereço de correio, escolher
 * perfil, atribuir contas, ativar e desativar, forçar múltiplo fator, ver o
 * último acesso, revogar sessão e reenviar convite.
 *
 * A aba do alcance dos perfis existe por um motivo prático: quem convida
 * precisa entender o que está entregando. O texto é descrição do que as
 * políticas de linha do banco já fazem, e não uma segunda regra de acesso.
 * Se os dois discordarem, quem está errado é o texto.
 */

const TOM_DA_SITUACAO: Record<SituacaoConvite, TomEtiqueta> = {
  aguardando: 'amarela',
  aceito: 'verde',
  vencido: 'vermelha',
}

export function Usuarios() {
  const consulta = useUsuarios()
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [aba, setAba] = useState('pessoas')
  const [convidando, setConvidando] = useState(false)
  const [atribuindo, setAtribuindo] = useState<UsuarioNaTela | null>(null)

  const usuarios = useMemo(() => consulta.data?.usuarios ?? [], [consulta.data])
  const convites = useMemo(() => consulta.data?.convites ?? [], [consulta.data])

  const contasConhecidas = useMemo(() => {
    const vistas = new Set<string>()
    for (const pessoa of usuarios) for (const conta of pessoa.contas) vistas.add(conta)
    return [...vistas].sort((a, b) => a.localeCompare(b, 'pt-BR'))
  }, [usuarios])

  const placar = useMemo(() => {
    const ativos = usuarios.filter((pessoa) => pessoa.ativo && pessoa.auth_id !== null).length
    const semMfa = usuarios.filter((pessoa) => !pessoa.mfa_obrigatorio).length
    const nuncaEntraram = usuarios.filter((pessoa) => pessoa.ultimo_acesso === null).length
    const aguardando = convites.filter(
      (convite) => situacaoDoConvite(convite) === 'aguardando',
    ).length
    return { ativos, semMfa, nuncaEntraram, aguardando }
  }, [usuarios, convites])

  const abas: Aba[] = [
    {
      chave: 'pessoas',
      rotulo: 'Pessoas',
      contagem: usuarios.length,
      conteudo: <ListaDePessoas usuarios={usuarios} aoAtribuirContas={setAtribuindo} />,
    },
    {
      chave: 'convites',
      rotulo: 'Convites',
      contagem: convites.length,
      conteudo: <ListaDeConvites convites={convites} />,
    },
    {
      chave: 'perfis',
      rotulo: 'O que cada perfil alcança',
      contagem: PERFIS.length,
      conteudo: <Perfis />,
    },
  ]

  return (
    <>
      <Migalhas itens={[{ rotulo: 'Configuração' }, { rotulo: 'Usuários' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Configuração</p>
          <h1 className="pagina__titulo">Usuários</h1>
          <p className="pagina__lede">
            É por aqui que alguém entra na plataforma. Convide por endereço de correio, escolha o
            perfil, atribua contas, e confira quem entrou e quando.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Botao tom="principal" onClick={() => setConvidando(true)}>
            Convidar pessoa
          </Botao>
        </div>
      </div>

      <AvisoDaContaDeEmergencia />

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

      {consulta.isPending ? <Carregando texto="Carregando as pessoas" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A lista não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data ? (
        <>
          <section className="secao" aria-labelledby="titulo-placar-usuarios">
            <div className="secao__topo">
              <h2 className="secao__titulo" id="titulo-placar-usuarios">
                Quem entra hoje
              </h2>
              <p className="secao__nota">
                Múltiplo fator desligado é dívida de segurança, não preferência.
              </p>
            </div>

            <div className="grade grade--4">
              <article className="cartao cartao--marca linha-pipeline">
                <p className="linha-pipeline__rotulo">Com acesso ativo</p>
                <p className="linha-pipeline__valor">{inteiro(placar.ativos)}</p>
                <p className="linha-pipeline__detalhe">
                  Pessoas que já aceitaram o convite e estão ativas.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Convites aguardando</p>
                <p className="linha-pipeline__valor">{inteiro(placar.aguardando)}</p>
                <p className="linha-pipeline__detalhe">
                  Enviados e ainda dentro do prazo. Vencido, é só reenviar.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Sem múltiplo fator</p>
                <p className="linha-pipeline__valor">{inteiro(placar.semMfa)}</p>
                <p className="linha-pipeline__detalhe">
                  Ligue o múltiplo fator em cada uma delas. A conta de emergência já nasce com ele.
                </p>
              </article>

              <article className="cartao linha-pipeline">
                <p className="linha-pipeline__rotulo">Nunca entraram</p>
                <p className="linha-pipeline__valor">{inteiro(placar.nuncaEntraram)}</p>
                <p className="linha-pipeline__detalhe">
                  Sem nenhum acesso registrado até agora. Vale conferir se o convite chegou.
                </p>
              </article>
            </div>
          </section>

          <section className="secao">
            <Abas abas={abas} ativa={aba} aoTrocar={setAba} rotulo="Seções da tela de usuários" />
          </section>

          <JanelaDeConvite
            aberta={convidando}
            aoFechar={() => setConvidando(false)}
            contas={contasConhecidas}
          />

          <JanelaDeContas
            usuario={atribuindo}
            contas={contasConhecidas}
            aoFechar={() => setAtribuindo(null)}
          />
        </>
      ) : null}
    </>
  )
}

// -------------------------------------------- o aviso da conta de emergência

/** Permanente de propósito. Não tem botão de fechar, e não vai ter. */
function AvisoDaContaDeEmergencia() {
  return (
    <Alarme tom="informacao" titulo="Conta de emergência" className="secao">
      <ul className="lista-felix">
        {AVISO_CONTA_DE_EMERGENCIA.map((linha) => (
          <li key={linha}>{linha}</li>
        ))}
      </ul>
    </Alarme>
  )
}

// ---------------------------------------------------------- lista de pessoas

function ListaDePessoas({
  usuarios,
  aoAtribuirContas,
}: {
  usuarios: UsuarioNaTela[]
  aoAtribuirContas: (usuario: UsuarioNaTela) => void
}) {
  const [filtroPerfil, setFiltroPerfil] = useState('')
  const [busca, setBusca] = useState('')

  const visiveis = useMemo(() => {
    const termo = busca.trim().toLowerCase()
    return usuarios.filter((pessoa) => {
      if (filtroPerfil && pessoa.perfil !== filtroPerfil) return false
      if (!termo) return true
      return `${pessoa.nome} ${pessoa.email ?? ''}`.toLowerCase().includes(termo)
    })
  }, [usuarios, filtroPerfil, busca])

  const colunas: Array<ColunaTabela<UsuarioNaTela>> = [
    {
      chave: 'pessoa',
      rotulo: 'Pessoa',
      conteudo: (pessoa) => (
        <>
          <strong>{pessoa.nome}</strong>
          <br />
          <span className="texto-fraco">{pessoa.email ?? 'endereço não entregue pelo banco'}</span>
          {pessoa.parceiro_nome ? (
            <>
              <br />
              <span className="texto-fraco">Parceiro: {pessoa.parceiro_nome}</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'perfil',
      rotulo: 'Perfil',
      conteudo: (pessoa) => (
        <>
          <Etiqueta tom={pessoa.perfil === 'emergencia' ? 'realce' : 'marca'}>
            {ROTULO_PERFIL_PLATAFORMA[pessoa.perfil]}
          </Etiqueta>
          <br />
          <span className="texto-fraco">{ALCANCE[pessoa.perfil].resumo}</span>
        </>
      ),
    },
    {
      chave: 'contas',
      rotulo: 'Contas atribuídas',
      alinhamento: 'numero',
      conteudo: (pessoa) => (
        <>
          <span className="numero">{inteiro(pessoa.contas_atribuidas)}</span>
          <br />
          <Botao tom="discreto" tamanho="p" onClick={() => aoAtribuirContas(pessoa)}>
            Atribuir contas
          </Botao>
        </>
      ),
    },
    {
      chave: 'mfa',
      rotulo: 'Múltiplo fator',
      conteudo: (pessoa) => (
        <>
          <Etiqueta tom={pessoa.mfa_obrigatorio ? 'verde' : 'amarela'} ponto>
            {pessoa.mfa_obrigatorio ? 'Obrigatório' : 'Desligado'}
          </Etiqueta>
          {!pessoa.mfa_obrigatorio ? (
            <>
              <br />
              <Botao tom="discreto" tamanho="p" disabled={!temBanco()}>
                Forçar múltiplo fator
              </Botao>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'acesso',
      rotulo: 'Último acesso',
      conteudo: (pessoa) => (
        <>
          {dataHora(pessoa.ultimo_acesso)}
          <br />
          <span className="texto-fraco">
            {pessoa.auth_id === null ? 'Convite ainda não aceito' : 'Identidade ligada'}
          </span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (pessoa) => (
        <Etiqueta tom={pessoa.ativo ? 'verde' : 'vermelha'} ponto>
          {pessoa.ativo ? 'Ativa' : 'Desativada'}
        </Etiqueta>
      ),
    },
    {
      chave: 'acoes',
      rotulo: 'Ações',
      alinhamento: 'acoes',
      conteudo: (pessoa) => (
        <>
          <Botao tom={pessoa.ativo ? 'contorno' : 'principal'} tamanho="p" disabled={!temBanco()}>
            {pessoa.ativo ? 'Desativar' : 'Ativar'}
          </Botao>{' '}
          <Botao tom="perigo" tamanho="p" disabled={!temBanco() || pessoa.auth_id === null}>
            Revogar sessão
          </Botao>
        </>
      ),
    },
  ]

  return (
    <>
      <Cartao>
        <div className="grade grade--3">
          <Selecao
            rotulo="Perfil"
            vazio="Todos os perfis"
            value={filtroPerfil}
            onChange={(evento) => setFiltroPerfil(evento.target.value)}
            opcoes={PERFIS.map((perfil) => ({
              valor: perfil,
              rotulo: ROTULO_PERFIL_PLATAFORMA[perfil],
            }))}
            auxilio={
              filtroPerfil
                ? ALCANCE[filtroPerfil as PerfilPlataforma].resumo
                : 'Escolha um perfil para ler, aqui mesmo, o que ele alcança.'
            }
          />
          <Campo
            rotulo="Buscar"
            placeholder="Nome ou endereço de correio"
            value={busca}
            onChange={(evento) => setBusca(evento.target.value)}
          />
        </div>
      </Cartao>

      {!temBanco() ? (
        <Alarme tom="amarelo" titulo="Ações desligadas nesta máquina" className="secao">
          Ativar, desativar, forçar múltiplo fator e revogar sessão gravam no banco. Enquanto ele
          não estiver ligado aqui, os botões ficam visíveis e desabilitados, para a tela não mentir
          sobre o que aconteceu.
        </Alarme>
      ) : null}

      <Cartao semRespiro className="secao">
        <Tabela
          colunas={colunas}
          linhas={visiveis}
          chaveDaLinha={(pessoa) => pessoa.id}
          legenda="Pessoas com acesso à plataforma, com perfil, contas atribuídas, múltiplo fator e último acesso."
          vazioTitulo="Ninguém nesta faixa"
          vazioTexto="Troque o perfil ou limpe a busca para ver todo mundo."
          vazioAcoes={
            <Botao
              tom="contorno"
              onClick={() => {
                setFiltroPerfil('')
                setBusca('')
              }}
            >
              Limpar filtros
            </Botao>
          }
        />
      </Cartao>
    </>
  )
}

// --------------------------------------------------------- lista de convites

function ListaDeConvites({ convites }: { convites: ConviteNaTela[] }) {
  const colunas: Array<ColunaTabela<ConviteNaTela>> = [
    {
      chave: 'pessoa',
      rotulo: 'Convidada',
      conteudo: (convite) => (
        <>
          <strong>{convite.nome}</strong>
          <br />
          <span className="texto-fraco">{convite.email ?? 'endereço não entregue pelo banco'}</span>
        </>
      ),
    },
    {
      chave: 'perfil',
      rotulo: 'Perfil oferecido',
      conteudo: (convite) => (
        <>
          <Etiqueta tom="marca">{ROTULO_PERFIL_PLATAFORMA[convite.perfil]}</Etiqueta>
          <br />
          <span className="texto-fraco">{ALCANCE[convite.perfil].resumo}</span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (convite) => {
        const situacao = situacaoDoConvite(convite)
        const dias = diasAte(convite.expira_em)
        return (
          <>
            <Etiqueta tom={TOM_DA_SITUACAO[situacao]} ponto>
              {ROTULO_SITUACAO_CONVITE[situacao]}
            </Etiqueta>
            <br />
            <span className="texto-fraco">
              {situacao === 'aceito'
                ? `Aceito em ${dataHora(convite.aceito_em)}`
                : situacao === 'vencido'
                  ? `Venceu em ${dataHora(convite.expira_em)}`
                  : `Vence em ${inteiro(dias ?? 0)} ${dias === 1 ? 'dia' : 'dias'}`}
            </span>
          </>
        )
      },
    },
    {
      chave: 'reenvios',
      rotulo: 'Reenvios',
      alinhamento: 'numero',
      conteudo: (convite) => (
        <>
          <span className="numero">{inteiro(convite.reenvios)}</span>
          <br />
          <span className="texto-fraco">
            {convite.reenviado_em ? `Último em ${dataHora(convite.reenviado_em)}` : 'Nunca reenviado'}
          </span>
        </>
      ),
    },
    {
      chave: 'acoes',
      rotulo: 'Ações',
      alinhamento: 'acoes',
      conteudo: (convite) =>
        convite.aceito_em ? (
          <span className="texto-fraco">Nada a fazer</span>
        ) : (
          <Botao tom="contorno" tamanho="p" disabled={!temBanco()}>
            Reenviar convite
          </Botao>
        ),
    },
  ]

  return (
    <Cartao
      semRespiro
      titulo="Convites enviados"
      legenda="O convite guarda só o resumo do token. O token puro vive apenas na mensagem enviada."
    >
      <Tabela
        colunas={colunas}
        linhas={convites}
        chaveDaLinha={(convite) => convite.id}
        legenda="Convites enviados, com o perfil oferecido, a situação e quantas vezes foram reenviados."
        vazioTitulo="Nenhum convite"
        vazioTexto="Ninguém foi convidado ainda, ou todos os convites já viraram acesso."
      />
    </Cartao>
  )
}

// ------------------------------------------------- o alcance de cada perfil

function Perfis() {
  const daCasa = PERFIS.filter((perfil) => ALCANCE[perfil].origem === 'casa')
  const deFora = PERFIS.filter((perfil) => ALCANCE[perfil].origem === 'fora')

  return (
    <>
      <Alarme tom="informacao" titulo="Isto é descrição, não é a regra">
        O que cada perfil alcança é decidido pela política de linha e pela máscara de coluna no
        banco. O texto abaixo descreve o que elas fazem, para quem convida entender o que está
        entregando. Nenhuma tela desta plataforma esconde dado que o banco já entregou.
      </Alarme>

      <section className="secao" aria-labelledby="titulo-perfis-casa">
        <div className="secao__topo">
          <h3 className="secao__titulo" id="titulo-perfis-casa">
            Perfis da casa
          </h3>
          <p className="secao__nota">
            Gente de dentro. Enxerga a lista de colegas, com nome e perfil.
          </p>
        </div>

        <div className="grade grade--2">
          {daCasa.map((perfil) => (
            <FichaDoPerfil key={perfil} perfil={perfil} />
          ))}
        </div>
      </section>

      <section className="secao" aria-labelledby="titulo-perfis-fora">
        <div className="secao__topo">
          <h3 className="secao__titulo" id="titulo-perfis-fora">
            Perfis de fora
          </h3>
          <p className="secao__nota">
            Gente que não é da casa. Não conhece o time por dentro, e o alcance é curto de propósito.
          </p>
        </div>

        <div className="grade grade--2">
          {deFora.map((perfil) => (
            <FichaDoPerfil key={perfil} perfil={perfil} />
          ))}
        </div>
      </section>
    </>
  )
}

function FichaDoPerfil({ perfil }: { perfil: PerfilPlataforma }) {
  const ficha = ALCANCE[perfil]

  return (
    <Cartao
      tom={perfil === 'emergencia' ? 'realce' : 'simples'}
      titulo={ROTULO_PERFIL_PLATAFORMA[perfil]}
      legenda={ficha.resumo}
    >
      <p className="kicker">Alcança</p>
      <ul className="lista-felix">
        {ficha.alcanca.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>

      <p className="kicker">Não alcança</p>
      <ul className="lista-felix">
        {ficha.nao_alcanca.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </Cartao>
  )
}

// ----------------------------------------------------- a janela do convite

function JanelaDeConvite({
  aberta,
  aoFechar,
  contas,
}: {
  aberta: boolean
  aoFechar: () => void
  contas: string[]
}) {
  const [nome, setNome] = useState('')
  const [endereco, setEndereco] = useState('')
  const [perfil, setPerfil] = useState<PerfilPlataforma>('gerente_contas')
  const [texto, setTexto] = useState('')
  const [escolhidas, setEscolhidas] = useState<string[]>([])
  const [exigirMfa, setExigirMfa] = useState(true)

  if (!aberta) return null

  const ficha = ALCANCE[perfil]
  const enderecoValido = /.+@.+\..+/.test(endereco.trim())
  const podeEnviar = temBanco() && nome.trim().length > 1 && enderecoValido

  function alternarConta(conta: string) {
    setEscolhidas((anterior) =>
      anterior.includes(conta)
        ? anterior.filter((item) => item !== conta)
        : [...anterior, conta],
    )
  }

  return (
    <Modal
      aberto
      aoFechar={aoFechar}
      titulo="Convidar pessoa"
      legenda="O convite vai por endereço de correio e vence em sete dias. Depois disso, basta reenviar."
      tamanho="g"
      fechaNoFundo={false}
      rodape={
        <>
          <Botao tom="discreto" onClick={aoFechar}>
            Cancelar
          </Botao>
          <Botao tom="principal" disabled={!podeEnviar}>
            Enviar convite
          </Botao>
        </>
      }
    >
      {!temBanco() ? (
        <Alarme tom="amarelo" titulo="Convite não enviado nesta máquina">
          O banco ainda não está ligado aqui, então o envio fica desligado. A janela mostra
          exatamente o que será gravado quando a conexão existir.
        </Alarme>
      ) : null}

      <Campo
        rotulo="Nome de quem entra"
        obrigatorio
        value={nome}
        onChange={(evento) => setNome(evento.target.value)}
        auxilio="É este nome que aparece na lista de pessoas e na trilha de auditoria."
      />

      <Campo
        rotulo="Endereço de correio"
        type="email"
        obrigatorio
        value={endereco}
        onChange={(evento) => setEndereco(evento.target.value)}
        erro={
          endereco.trim().length > 0 && !enderecoValido
            ? 'Este endereço não parece completo. Confira antes de enviar.'
            : undefined
        }
        auxilio="Para onde o convite vai. Um endereço por pessoa, e nunca uma caixa compartilhada."
      />

      <Selecao
        rotulo="Perfil"
        obrigatorio
        value={perfil}
        onChange={(evento) => setPerfil(evento.target.value as PerfilPlataforma)}
        opcoes={PERFIS.map((chave) => ({
          valor: chave,
          rotulo: ROTULO_PERFIL_PLATAFORMA[chave],
        }))}
        auxilio={ficha.resumo}
      />

      <Cartao tom="plano" titulo={`O que ${ROTULO_PERFIL_PLATAFORMA[perfil]} alcança`}>
        <ul className="lista-felix">
          {ficha.alcanca.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
        <p className="kicker">Não alcança</p>
        <ul className="lista-felix">
          {ficha.nao_alcanca.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      </Cartao>

      {perfil === 'emergencia' ? (
        <Alarme tom="vermelho" titulo="Convite de conta de emergência">
          Esta conta não é para o dia a dia. Confirme que o múltiplo fator ficará obrigatório e que
          os códigos de recuperação serão impressos e guardados em envelope lacrado.
        </Alarme>
      ) : null}

      <CampoTexto
        multiplas_linhas
        rotulo="Texto do convite"
        rows={4}
        maxLength={600}
        contador
        valorAtual={texto}
        value={texto}
        onChange={(evento) => setTexto(evento.target.value)}
        auxilio="Uma linha explicando por que esta pessoa está sendo chamada. Vai junto com o convite."
        acessorio={
          <BotaoIA
            campo="texto_livre"
            textoAtual={texto}
            contexto={{
              perfil_oferecido: ROTULO_PERFIL_PLATAFORMA[perfil],
              resumo_do_perfil: ficha.resumo,
            }}
            aoAceitar={setTexto}
            rotulo="Sugerir texto"
          />
        }
      />

      <Cartao
        tom="plano"
        titulo="Contas atribuídas"
        legenda="Marque as contas que esta pessoa passa a ter papel. Dá para mudar depois, na ficha dela."
      >
        {contas.length === 0 ? (
          <p className="texto-fraco">
            Nenhuma conta conhecida nesta tela. A lista completa vive na tela de Contas.
          </p>
        ) : (
          <div className="grade grade--2">
            {contas.map((conta) => (
              <label key={conta} className="campo__rotulo">
                <input
                  type="checkbox"
                  checked={escolhidas.includes(conta)}
                  onChange={() => alternarConta(conta)}
                />{' '}
                {conta}
              </label>
            ))}
          </div>
        )}
        <p className="texto-fraco">
          {inteiro(escolhidas.length)} {escolhidas.length === 1 ? 'conta marcada' : 'contas marcadas'}.
        </p>
      </Cartao>

      <label className="campo__rotulo">
        <input
          type="checkbox"
          checked={exigirMfa}
          onChange={(evento) => setExigirMfa(evento.target.checked)}
        />{' '}
        Exigir múltiplo fator desta pessoa
      </label>
      <p className="campo__auxilio">
        Recomendado para todo mundo, e obrigatório para administrador, líder, financeiro e conta de
        emergência.
      </p>
    </Modal>
  )
}

// -------------------------------------------------- a janela de atribuição

function JanelaDeContas({
  usuario,
  contas,
  aoFechar,
}: {
  usuario: UsuarioNaTela | null
  contas: string[]
  aoFechar: () => void
}) {
  const [escolhidas, setEscolhidas] = useState<string[]>([])
  const [carregado, setCarregado] = useState<string | null>(null)

  if (!usuario) return null

  // Primeira abertura desta pessoa: parte do que ela já tem.
  if (carregado !== usuario.id) {
    setCarregado(usuario.id)
    setEscolhidas(usuario.contas)
  }

  function alternar(conta: string) {
    setEscolhidas((anterior) =>
      anterior.includes(conta) ? anterior.filter((item) => item !== conta) : [...anterior, conta],
    )
  }

  return (
    <Modal
      aberto
      aoFechar={aoFechar}
      titulo={`Contas de ${usuario.nome}`}
      legenda="A pessoa alcança a conta em que tem papel registrado. É o papel que manda, não o perfil."
      rodape={
        <>
          <Botao tom="discreto" onClick={aoFechar}>
            Cancelar
          </Botao>
          <Botao tom="principal" disabled={!temBanco()}>
            Salvar atribuição
          </Botao>
        </>
      }
    >
      {!temBanco() ? (
        <Alarme tom="amarelo" titulo="Atribuição não gravada nesta máquina">
          O banco ainda não está ligado aqui, então salvar fica desligado.
        </Alarme>
      ) : null}

      {contas.length === 0 ? (
        <p className="texto-fraco">
          Nenhuma conta conhecida nesta tela. A lista completa vive na tela de Contas.
        </p>
      ) : (
        <div className="grade grade--2">
          {contas.map((conta) => (
            <label key={conta} className="campo__rotulo">
              <input
                type="checkbox"
                checked={escolhidas.includes(conta)}
                onChange={() => alternar(conta)}
              />{' '}
              {conta}
            </label>
          ))}
        </div>
      )}

      <p className="texto-fraco">
        {inteiro(escolhidas.length)} de {inteiro(contas.length)} marcadas.
      </p>
    </Modal>
  )
}
