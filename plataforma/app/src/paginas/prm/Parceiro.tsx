import { useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  Abas,
  Alarme,
  Botao,
  Carregando,
  Cartao,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Tabela,
  type Aba,
  type ColunaTabela,
  type TomEtiqueta,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { useParceiro } from '@/dados/prm'
import { ExtratosDeComissao } from '@/paginas/prm/Comissoes'
import { Protecao } from '@/paginas/prm/Indicacoes'
import { dataHora } from '@/tipos/configuracao'
import { data, dinheiro, inteiro, ROTULO_FASE } from '@/tipos/rotulos'
import {
  CRITERIO_STATUS_PARCEIRO,
  montarExtratos,
  pontosPercentuais,
  ROTULO_STATUS_INDICACAO,
  ROTULO_STATUS_PARCEIRO,
  ROTULO_TIPO_PARCEIRO,
  ROTULO_TIPO_PESSOA,
  type IndicacaoNaTela,
  type ParceiroStatus,
  type UsuarioDoParceiro,
} from '@/tipos/prm'

/**
 * Ficha do parceiro.
 *
 * Cinco leituras, em abas: o cadastro, quem entra no portal em nome dele, as
 * indicações que registrou, os negócios que saíram dessas indicações e o
 * extrato de comissão dele.
 *
 * O extrato aqui é o mesmo componente da tela de Comissões, com a mesma régua
 * e a mesma abertura de cálculo, para não existirem duas contas diferentes
 * para o mesmo dinheiro.
 */

const TOM_DO_STATUS: Record<ParceiroStatus, TomEtiqueta> = {
  prospecto: 'neutra',
  em_credenciamento: 'amarela',
  ativo: 'verde',
  suspenso: 'vermelha',
  encerrado: 'neutra',
}

export function Parceiro() {
  const { id } = useParams<{ id: string }>()
  const consulta = useParceiro(id)
  const [avisoAberto, setAvisoAberto] = useState(true)
  const [aba, setAba] = useState('cadastro')

  const ficha = consulta.data?.parceiro ?? null
  const indicacoes = useMemo(() => consulta.data?.indicacoes ?? [], [consulta.data])
  const usuarios = useMemo(() => consulta.data?.usuarios ?? [], [consulta.data])
  const comissoes = useMemo(() => consulta.data?.comissoes ?? [], [consulta.data])
  const extratos = useMemo(() => montarExtratos(comissoes), [comissoes])

  const negocios = useMemo(
    () => indicacoes.filter((linha) => linha.negocio_id !== null),
    [indicacoes],
  )

  const nome = ficha?.nome ?? 'Parceiro'

  const abas: Aba[] = [
    {
      chave: 'cadastro',
      rotulo: 'Cadastro',
      conteudo: ficha ? <Cadastro parceiro={ficha} /> : null,
    },
    {
      chave: 'portal',
      rotulo: 'Usuários do portal',
      contagem: usuarios.length,
      conteudo: <UsuariosDoPortal usuarios={usuarios} />,
    },
    {
      chave: 'indicacoes',
      rotulo: 'Indicações',
      contagem: indicacoes.length,
      conteudo: <IndicacoesDoParceiro indicacoes={indicacoes} />,
    },
    {
      chave: 'negocios',
      rotulo: 'Negócios gerados',
      contagem: negocios.length,
      conteudo: <NegociosGerados indicacoes={negocios} />,
    },
    {
      chave: 'comissao',
      rotulo: 'Comissão dele',
      contagem: comissoes.length,
      conteudo: (
        <ExtratosDeComissao
          extratos={extratos}
          vazioTexto="Este parceiro ainda não tem linha de comissão. Ela nasce quando a parcela do contrato é apurada."
        />
      ),
    },
  ]

  return (
    <>
      <Migalhas
        itens={[
          { rotulo: 'PRM de Valor' },
          { rotulo: 'Parceiros', para: '/parceiros' },
          { rotulo: nome },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Ficha do parceiro</p>
          <h1 className="pagina__titulo">{nome}</h1>
          {ficha ? (
            <p className="pagina__lede">
              {ROTULO_TIPO_PARCEIRO[ficha.tipo]} · {ROTULO_TIPO_PESSOA[ficha.tipo_pessoa]}
              {ficha.cidade ? ` · ${ficha.cidade}` : ''}
              {ficha.uf ? ` · ${ficha.uf}` : ''}
            </p>
          ) : null}
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
          <Link className="botao botao--contorno" to="/parceiros">
            Voltar à lista
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

      {consulta.isPending ? <Carregando texto="Carregando a ficha" /> : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="A ficha não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.data && !ficha ? (
        <Cartao>
          <EstadoVazio
            titulo="Parceiro não encontrado"
            texto="Este identificador não existe, ou a política de linha do banco não entregou esta ficha para quem está olhando."
            acoes={
              <Link className="botao botao--principal" to="/parceiros">
                Ir para a lista de parceiros
              </Link>
            }
          />
        </Cartao>
      ) : null}

      {ficha ? (
        <>
          <ResumoDoParceiro
            status={ficha.status}
            credenciadoEm={ficha.credenciado_em}
            vigenciaFim={ficha.vigencia_fim}
            prazoProtecao={ficha.prazo_protecao_dias}
            indicacoes={indicacoes.length}
            convertidas={negocios.length}
          />

          <section className="secao">
            <Abas abas={abas} ativa={aba} aoTrocar={setAba} rotulo="Seções da ficha do parceiro" />
          </section>
        </>
      ) : null}
    </>
  )
}

// ------------------------------------------------------------ o resumo

function ResumoDoParceiro({
  status,
  credenciadoEm,
  vigenciaFim,
  prazoProtecao,
  indicacoes,
  convertidas,
}: {
  status: ParceiroStatus
  credenciadoEm: string | null
  vigenciaFim: string | null
  prazoProtecao: number
  indicacoes: number
  convertidas: number
}) {
  return (
    <section className="secao" aria-labelledby="titulo-resumo-parceiro">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-resumo-parceiro">
          Onde este parceiro está
        </h2>
        <p className="secao__nota">{CRITERIO_STATUS_PARCEIRO[status]}</p>
      </div>

      <div className="grade grade--4">
        <article className="cartao cartao--marca linha-pipeline">
          <p className="linha-pipeline__rotulo">Credenciamento</p>
          <p className="linha-pipeline__valor">
            <Etiqueta tom={TOM_DO_STATUS[status]} ponto>
              {ROTULO_STATUS_PARCEIRO[status]}
            </Etiqueta>
          </p>
          <p className="linha-pipeline__detalhe">
            {credenciadoEm ? `Credenciado em ${data(credenciadoEm)}.` : 'Sem data de credenciamento.'}
          </p>
        </article>

        <article className="cartao linha-pipeline">
          <p className="linha-pipeline__rotulo">Vigência do contrato de parceria</p>
          <p className="linha-pipeline__valor">{vigenciaFim ? data(vigenciaFim) : 'sem data'}</p>
          <p className="linha-pipeline__detalhe">
            Vigência vencida bloqueia indicação nova, mas não apaga o histórico.
          </p>
        </article>

        <article className="cartao linha-pipeline">
          <p className="linha-pipeline__rotulo">Prazo de proteção</p>
          <p className="linha-pipeline__valor">
            {inteiro(prazoProtecao)}
            <span className="linha-pipeline__unidade">dias</span>
          </p>
          <p className="linha-pipeline__detalhe">
            Cada indicação copia este prazo no momento do registro. O padrão da casa é de 90 dias.
          </p>
        </article>

        <article className="cartao cartao--realce linha-pipeline linha-pipeline--auditado">
          <p className="linha-pipeline__rotulo">O que trouxe</p>
          <p className="linha-pipeline__valor">
            {inteiro(indicacoes)}
            <span className="linha-pipeline__unidade">
              {indicacoes === 1 ? 'indicação' : 'indicações'}
            </span>
          </p>
          <p className="linha-pipeline__detalhe">
            {inteiro(convertidas)} {convertidas === 1 ? 'virou' : 'viraram'} negócio no funil.
          </p>
        </article>
      </div>
    </section>
  )
}

// ------------------------------------------------------------- cadastro

function Cadastro({ parceiro }: { parceiro: NonNullable<ReturnType<typeof useParceiro>['data']>['parceiro'] }) {
  if (!parceiro) return null

  const linhas: Array<{ rotulo: string; valor: string }> = [
    { rotulo: 'Nome', valor: parceiro.nome },
    { rotulo: 'Razão social', valor: parceiro.razao_social ?? 'não informada' },
    { rotulo: 'Tipo de pessoa', valor: ROTULO_TIPO_PESSOA[parceiro.tipo_pessoa] },
    { rotulo: 'Tipo de parceria', valor: ROTULO_TIPO_PARCEIRO[parceiro.tipo] },
    { rotulo: 'Documento', valor: parceiro.documento ?? 'não entregue pelo banco' },
    { rotulo: 'Correio comercial', valor: parceiro.email_comercial ?? 'não informado' },
    { rotulo: 'Telefone comercial', valor: parceiro.telefone_comercial ?? 'não entregue pelo banco' },
    { rotulo: 'Cidade', valor: parceiro.cidade ?? 'não informada' },
    { rotulo: 'Unidade da federação', valor: parceiro.uf ?? 'não informada' },
    { rotulo: 'Sítio', valor: parceiro.site ?? 'não informado' },
    {
      rotulo: 'Vigência',
      valor:
        parceiro.vigencia_inicio && parceiro.vigencia_fim
          ? `${data(parceiro.vigencia_inicio)} a ${data(parceiro.vigencia_fim)}`
          : 'sem vigência registrada',
    },
    {
      rotulo: 'Percentual negociado',
      valor:
        parceiro.comissao_percentual_negociado === null
          ? 'usa o padrão da casa'
          : pontosPercentuais(parceiro.comissao_percentual_negociado),
    },
    {
      rotulo: 'Divulgação no sítio da casa',
      valor: parceiro.autoriza_divulgacao_site ? 'autorizada' : 'não autorizada',
    },
  ]

  const colunas: Array<ColunaTabela<{ rotulo: string; valor: string }>> = [
    { chave: 'rotulo', rotulo: 'Campo', conteudo: (linha) => <strong>{linha.rotulo}</strong> },
    { chave: 'valor', rotulo: 'Conteúdo', conteudo: (linha) => linha.valor },
  ]

  return (
    <div className="grade grade--2">
      <Cartao semRespiro titulo="Cadastro" legenda="O que a casa registrou sobre este parceiro.">
        <Tabela
          colunas={colunas}
          linhas={linhas}
          chaveDaLinha={(linha) => linha.rotulo}
          legenda="Campos do cadastro do parceiro."
        />
      </Cartao>

      <div>
        <Cartao titulo="Serviços que ele presta">
          {parceiro.servicos.length === 0 ? (
            <p className="texto-fraco">Nenhum serviço registrado.</p>
          ) : (
            <ul className="lista-felix">
              {parceiro.servicos.map((servico) => (
                <li key={servico}>{servico}</li>
              ))}
            </ul>
          )}
        </Cartao>

        <Cartao className="secao" titulo="Treinamentos concluídos">
          {parceiro.treinamentos_concluidos.length === 0 ? (
            <p className="texto-fraco">
              Nenhum treinamento concluído. O credenciamento não fecha sem isso.
            </p>
          ) : (
            <ul className="lista-felix">
              {parceiro.treinamentos_concluidos.map((treinamento) => (
                <li key={treinamento}>{treinamento}</li>
              ))}
            </ul>
          )}
        </Cartao>

        <Cartao className="secao" titulo="Condições e observações">
          {parceiro.condicoes_comerciais ? (
            <p>{parceiro.condicoes_comerciais}</p>
          ) : (
            <p className="texto-fraco">
              Sem condição comercial própria registrada, ou coluna não entregue pelo banco.
            </p>
          )}
          {parceiro.observacoes ? <p>{parceiro.observacoes}</p> : null}
        </Cartao>
      </div>
    </div>
  )
}

// -------------------------------------------------------- portal do parceiro

function UsuariosDoPortal({ usuarios }: { usuarios: UsuarioDoParceiro[] }) {
  const colunas: Array<ColunaTabela<UsuarioDoParceiro>> = [
    {
      chave: 'pessoa',
      rotulo: 'Pessoa',
      conteudo: (linha) => (
        <>
          <strong>{linha.usuario_nome}</strong>
          {linha.principal ? (
            <>
              {' '}
              <Etiqueta tom="realce">Contato principal</Etiqueta>
            </>
          ) : null}
          <br />
          <span className="texto-fraco">
            {linha.usuario_email ?? 'endereço não entregue pelo banco'}
          </span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Acesso',
      conteudo: (linha) => (
        <Etiqueta tom={linha.ativo ? 'verde' : 'vermelha'} ponto>
          {linha.ativo ? 'Ativo' : 'Desativado'}
        </Etiqueta>
      ),
    },
    {
      chave: 'ultimo',
      rotulo: 'Último acesso ao portal',
      conteudo: (linha) => dataHora(linha.ultimo_acesso_portal),
    },
  ]

  return (
    <Cartao
      semRespiro
      titulo="Quem entra no portal por este parceiro"
      legenda="O vínculo exige usuário de perfil parceiro, e é ele que alimenta o parceiro da sessão."
    >
      <Tabela
        colunas={colunas}
        linhas={usuarios}
        chaveDaLinha={(linha) => linha.id}
        legenda="Pessoas com acesso ao portal em nome deste parceiro."
        vazioTitulo="Ninguém acessa o portal ainda"
        vazioTexto="Convide a pessoa na tela de Usuários, com o perfil parceiro, e depois ligue o vínculo aqui."
      />
    </Cartao>
  )
}

// -------------------------------------------------------- indicações dele

function IndicacoesDoParceiro({ indicacoes }: { indicacoes: IndicacaoNaTela[] }) {
  const colunas: Array<ColunaTabela<IndicacaoNaTela>> = [
    {
      chave: 'conta',
      rotulo: 'Conta indicada',
      conteudo: (linha) => (
        <>
          <strong>{linha.conta}</strong>
          <br />
          <span className="texto-fraco">Registrada em {data(linha.registrada_em)}</span>
        </>
      ),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <>
          <Etiqueta tom="neutra" ponto>
            {ROTULO_STATUS_INDICACAO[linha.status]}
          </Etiqueta>
          {linha.motivo_recusa ? (
            <>
              <br />
              <span className="texto-fraco">{linha.motivo_recusa}</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'protecao',
      rotulo: 'Prazo de proteção',
      conteudo: (linha) => <Protecao indicacao={linha} />,
    },
  ]

  return (
    <Cartao semRespiro titulo="Indicações registradas por este parceiro">
      <Tabela
        colunas={colunas}
        linhas={indicacoes}
        chaveDaLinha={(linha) => linha.id}
        legenda="Indicações deste parceiro, com a situação e o prazo de proteção."
        vazioTitulo="Nenhuma indicação"
        vazioTexto="Este parceiro ainda não registrou nada, ou a política de linha não entregou as indicações dele."
      />
    </Cartao>
  )
}

// ------------------------------------------------------- negócios gerados

function NegociosGerados({ indicacoes }: { indicacoes: IndicacaoNaTela[] }) {
  const colunas: Array<ColunaTabela<IndicacaoNaTela>> = [
    {
      chave: 'negocio',
      rotulo: 'Negócio',
      conteudo: (linha) => (
        <>
          <strong>{linha.negocio_titulo ?? 'Negócio aberto'}</strong>
          <br />
          <span className="texto-fraco">{linha.conta}</span>
        </>
      ),
    },
    {
      chave: 'fase',
      rotulo: 'Fase',
      conteudo: (linha) =>
        linha.negocio_fase === null ? (
          <span className="texto-fraco">Fase não informada</span>
        ) : (
          <Etiqueta tom="marca">
            {linha.negocio_fase} · {ROTULO_FASE[linha.negocio_fase]}
          </Etiqueta>
        ),
    },
    {
      chave: 'origem',
      rotulo: 'Indicação de origem',
      conteudo: (linha) => (
        <>
          Aceita em {data(linha.aceita_em)}
          <br />
          <span className="texto-fraco">
            Proteção de {inteiro(linha.prazo_protecao_dias)} dias no registro
          </span>
        </>
      ),
    },
    {
      chave: 'valor',
      rotulo: 'Valor do negócio',
      alinhamento: 'numero',
      conteudo: (linha) => dinheiro(linha.negocio_valor),
    },
  ]

  return (
    <Cartao
      semRespiro
      titulo="Negócios que saíram das indicações dele"
      legenda="Valor que o banco não entregar aparece como sem valor. Quem recorta é a política de linha."
    >
      <Tabela
        colunas={colunas}
        linhas={indicacoes}
        chaveDaLinha={(linha) => linha.id}
        legenda="Negócios abertos a partir de indicações deste parceiro."
        vazioTitulo="Nenhum negócio ainda"
        vazioTexto="Nenhuma indicação deste parceiro virou negócio no funil até aqui."
      />
    </Cartao>
  )
}
