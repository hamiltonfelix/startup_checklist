import { useMemo, useState } from 'react'
import {
  Alarme,
  Botao,
  Cartao,
  Carregando,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Selecao,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { competenciaAtual, useHistoricoDeValor } from '@/dados/governanca'
import type { HistoricoDaConta, HistoricoValor } from '@/tipos/governanca'
import { data as formatarData, inteiro } from '@/tipos/rotulos'

/**
 * Histórico de Valor, por conta e por trimestre.
 *
 * O registro é obrigatório: em todo trimestre, para toda conta com programa
 * ativo, tem de existir uma linha com o que foi entregue, que resultado gerou e
 * qual a evidência. Esta tela mostra o trimestre em aberto primeiro, e cobra o
 * que falta antes de mostrar o que já está feito.
 */
export function HistoricoDeValor() {
  const consulta = useHistoricoDeValor()
  const [contaId, setContaId] = useState('')
  const competencia = competenciaAtual()

  const todas = useMemo(() => consulta.data?.dados ?? [], [consulta.data])

  const emTela = useMemo(
    () => (contaId ? todas.filter((linha) => linha.conta.id === contaId) : todas),
    [todas, contaId],
  )

  const devendo = todas.filter((linha) => linha.devidos.length > 0)
  const totalRegistros = todas.reduce((soma, linha) => soma + linha.registros.length, 0)

  return (
    <>
      <Migalhas itens={[{ rotulo: 'Governança' }, { rotulo: 'Histórico de Valor' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Governança · o que a casa entregou</p>
          <h1 className="pagina__titulo">Histórico de Valor</h1>
          <p className="pagina__lede">
            Registro obrigatório por trimestre, conta por conta: o que foi entregue, que resultado
            gerou e qual a evidência. É este histórico que sustenta a conversa de renovação.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao tom="contorno" onClick={() => void consulta.refetch()}>
            Atualizar
          </Botao>
        </div>
      </div>

      {consulta.data?.deExemplo ? (
        <Alarme tom="amarelo" titulo="Dados de exemplo" className="secao">
          {AVISO_SEM_BANCO}
        </Alarme>
      ) : null}

      {consulta.isError ? (
        <Alarme tom="vermelho" titulo="O Histórico de Valor não carregou">
          {consulta.error.message}
        </Alarme>
      ) : null}

      {consulta.isPending ? <Carregando texto="Reunindo o histórico" /> : null}

      <section className="secao" aria-labelledby="titulo-trimestre-aberto">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-trimestre-aberto">
            O trimestre em aberto · {competencia}
          </h2>
          <p className="secao__nota">
            {inteiro(totalRegistros)} registros no histórico ·{' '}
            {devendo.length === 0
              ? 'nenhuma conta devendo o trimestre corrente'
              : `${inteiro(devendo.length)} ${devendo.length === 1 ? 'conta deve' : 'contas devem'} o registro deste trimestre`}
            .
          </p>
        </div>

        {devendo.length > 0 ? (
          <Alarme
            tom="vermelho"
            titulo={`Falta registrar o Histórico de Valor de ${competencia}`}
            className="secao"
          >
            <ul className="lista-felix">
              {devendo.map((linha) =>
                linha.devidos.map((devido) => (
                  <li key={`${linha.conta.id}-${devido.programa_id}`}>
                    {linha.conta.nome} · {devido.programa_nome} · trimestre {devido.ano}-T
                    {devido.trimestre}
                  </li>
                )),
              )}
            </ul>
          </Alarme>
        ) : (
          <Alarme tom="verde" titulo="Trimestre em dia" className="secao">
            Toda conta com programa ativo já tem registro de Histórico de Valor no trimestre
            corrente.
          </Alarme>
        )}
      </section>

      <section className="secao" aria-labelledby="titulo-filtro-historico">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-filtro-historico">
            Filtro
          </h2>
          <p className="secao__nota">
            {inteiro(emTela.length)} de {inteiro(todas.length)} contas em tela.
          </p>
        </div>

        <div className="grade grade--2">
          <Selecao
            rotulo="Conta"
            vazio="Todas as contas"
            value={contaId}
            opcoes={todas.map((linha) => ({ valor: linha.conta.id, rotulo: linha.conta.nome }))}
            onChange={(evento) => setContaId(evento.target.value)}
          />
        </div>
      </section>

      {emTela.length === 0 && !consulta.isPending ? (
        <Cartao>
          <EstadoVazio
            titulo="Nenhuma conta com Histórico de Valor"
            texto="Assim que o primeiro trimestre for registrado, a conta aparece aqui com entrega, resultado e evidência."
          />
        </Cartao>
      ) : null}

      {emTela.map((linha) => (
        <BlocoDaConta key={linha.conta.id} linha={linha} competencia={competencia} />
      ))}
    </>
  )
}

// -------------------------------------------------------- uma conta

function BlocoDaConta({
  linha,
  competencia,
}: {
  linha: HistoricoDaConta
  competencia: string
}) {
  const registros = [...linha.registros].sort((a, b) => b.competencia.localeCompare(a.competencia))
  const trimestreAberto = registros.some((registro) => registro.competencia === competencia)

  const colunas: Array<ColunaTabela<HistoricoValor>> = [
    {
      chave: 'competencia',
      rotulo: 'Trimestre',
      largura: '9rem',
      conteudo: (registro) => (
        <>
          <strong className="numero">{registro.competencia}</strong>
          <br />
          <span className="texto-fraco">{formatarData(registro.data_referencia)}</span>
        </>
      ),
    },
    { chave: 'entregue', rotulo: 'O que foi entregue', conteudo: (registro) => registro.entregue },
    { chave: 'resultado', rotulo: 'Que resultado gerou', conteudo: (registro) => registro.resultado },
    {
      chave: 'evidencia',
      rotulo: 'Qual a evidência',
      conteudo: (registro) => (
        <>
          {registro.evidencia}
          <br />
          {registro.confirmado_em ? (
            <Etiqueta tom="verde" ponto>
              Confirmado pelo cliente em {formatarData(registro.confirmado_em)}
            </Etiqueta>
          ) : (
            <Etiqueta tom="amarela" ponto>
              Ainda sem confirmação do cliente
            </Etiqueta>
          )}
        </>
      ),
    },
  ]

  return (
    <section className="secao" aria-label={`Histórico de Valor de ${linha.conta.nome}`}>
      <div className="secao__topo">
        <h2 className="secao__titulo">{linha.conta.nome}</h2>
        <p className="secao__nota">
          {inteiro(registros.length)}{' '}
          {registros.length === 1 ? 'trimestre registrado' : 'trimestres registrados'} ·{' '}
          {trimestreAberto
            ? `trimestre ${competencia} já registrado`
            : `trimestre ${competencia} ainda em aberto`}
        </p>
      </div>

      {!trimestreAberto ? (
        <Alarme tom="amarelo" titulo={`O trimestre ${competencia} desta conta está em aberto`} className="secao">
          Falta escrever o que foi entregue no trimestre, que resultado isso gerou para a conta e
          qual a evidência do resultado. Sem as três coisas, o registro não vale.
        </Alarme>
      ) : null}

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={registros}
          chaveDaLinha={(registro) => registro.id}
          legenda={`Histórico de Valor de ${linha.conta.nome}, do trimestre mais recente para o mais antigo.`}
          vazioTitulo="Nenhum trimestre registrado para esta conta"
          vazioTexto="O registro é obrigatório por trimestre. Comece pelo trimestre em aberto."
        />
      </Cartao>
    </section>
  )
}
