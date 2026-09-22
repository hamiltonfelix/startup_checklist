import { useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  Abas,
  Alarme,
  Botao,
  BotaoIA,
  Campo,
  Cartao,
  Carregando,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { hojeISO, usePauta } from '@/dados/governanca'
import type {
  BancoPauta,
  ItemPautaNaTela,
  LinhaPrePauta,
  PautaFamilia,
} from '@/tipos/governanca'
import {
  ROTULO_PAUTA_FAMILIA,
  ROTULO_PAUTA_ORIGEM,
  ROTULO_PAUTA_STATUS,
  ROTULO_PAUTA_TIPO,
} from '@/tipos/governanca'
import { data as formatarData, inteiro } from '@/tipos/rotulos'

/**
 * Pauta e pré-pauta da reunião de conselho.
 *
 * A regra que manda nesta tela: pendência aberta reaparece na pré-pauta até
 * fechar, com dono e prazo, marcada como atrasada quando o prazo passou. Quem
 * decide essa ordem é `valor.montar_pre_pauta`, no banco. A tela mostra
 * primeiro as pendências, depois os temas sugeridos do banco de pautas.
 */
export function Pauta() {
  const { id } = useParams()
  const consulta = usePauta(id)
  const montada = consulta.data?.dados ?? null
  const [tema, setTema] = useState('')

  const tempoTotal = useMemo(
    () => (montada?.itens ?? []).reduce((soma, item) => soma + item.tempo_previsto_minutos, 0),
    [montada],
  )

  if (consulta.isPending) {
    return <Carregando texto="Montando a pauta" />
  }

  if (consulta.isError) {
    return (
      <Alarme tom="vermelho" titulo="A pauta não carregou">
        {consulta.error.message}
      </Alarme>
    )
  }

  if (!montada) {
    return (
      <>
        <Migalhas itens={[{ rotulo: 'Governança' }, { rotulo: 'Pauta' }]} />
        <Cartao>
          <EstadoVazio
            titulo="Nenhuma pauta encontrada"
            texto="Não existe pauta registrada para esta turma, ou esta sessão não alcança nenhuma."
            acoes={
              <Link className="botao botao--contorno" to="/atas">
                Ver as atas do conselho
              </Link>
            }
          />
        </Cartao>
      </>
    )
  }

  const { pauta, itens, pre_pauta: prePauta, banco } = montada
  const pendenciasDaPrePauta = prePauta.filter((linha) => linha.bloco === 'pendencia')
  const temasDaPrePauta = prePauta.filter((linha) => linha.bloco === 'tema_sugerido')
  const atrasadas = pendenciasDaPrePauta.filter((linha) => linha.situacao === 'atrasada')

  return (
    <>
      <Migalhas itens={[{ rotulo: 'Governança' }, { rotulo: 'Pauta' }]} />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">
            {montada.conta_nome} · {montada.turma_nome ?? 'Turma não informada'}
          </p>
          <h1 className="pagina__titulo">
            {pauta.titulo} · {formatarData(pauta.data_reuniao)}
          </h1>
          <p className="pagina__lede">
            Pendência aberta reaparece aqui em toda reunião, com dono e prazo, até fechar com
            evidência. Só depois delas entram os temas sugeridos do banco de pautas.
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

      {atrasadas.length > 0 ? (
        <Alarme
          tom="vermelho"
          titulo={`${atrasadas.length} ${atrasadas.length === 1 ? 'pendência atrasada' : 'pendências atrasadas'} na pré-pauta`}
          className="secao"
        >
          <ul className="lista-felix">
            {atrasadas.map((linha) => (
              <li key={`atrasada-${linha.ordem_item}`}>
                {linha.detalhe ?? linha.tema} · dono: {linha.dono ?? 'sem dono registrado'} · prazo{' '}
                {formatarData(linha.prazo)}
              </li>
            ))}
          </ul>
        </Alarme>
      ) : null}

      <section className="secao" aria-labelledby="titulo-cabeca-pauta">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-cabeca-pauta">
            A reunião
          </h2>
          <p className="secao__nota">
            Tempo previsto somado: {inteiro(tempoTotal)} minutos em {inteiro(itens.length)} itens.
          </p>
        </div>

        <div className="grade grade--3">
          <Cartao titulo="Data e hora" tom="marca">
            <p className="numero" style={{ fontSize: 'var(--texto-xg)' }}>
              {formatarData(pauta.data_reuniao)}
            </p>
            <p className="texto-fraco">{pauta.hora_inicio ?? 'Horário a confirmar'}</p>
          </Cartao>
          <Cartao titulo="Situação da pauta">
            <Etiqueta tom={pauta.status === 'publicada' ? 'verde' : 'marca'} ponto>
              {ROTULO_PAUTA_STATUS[pauta.status]}
            </Etiqueta>
            <p className="texto-fraco" style={{ marginTop: 'var(--esp-3)' }}>
              {pauta.numero ? `Reunião número ${pauta.numero} do ciclo.` : 'Reunião sem número.'}
            </p>
          </Cartao>
          <Cartao titulo="Pendências que voltam">
            <p className="numero" style={{ fontSize: 'var(--texto-2xg)' }}>
              {inteiro(pendenciasDaPrePauta.length)}
            </p>
            <p className="texto-fraco">
              {atrasadas.length > 0
                ? `${inteiro(atrasadas.length)} com prazo vencido.`
                : 'Nenhuma com prazo vencido.'}
            </p>
          </Cartao>
        </div>
      </section>

      <PrePauta pendencias={pendenciasDaPrePauta} temas={temasDaPrePauta} />

      <ItensDaPauta itens={itens} />

      <BancoDePautas banco={banco} tema={tema} definirTema={setTema} />
    </>
  )
}

// ---------------------------------------------------------------- pré-pauta

function PrePauta({
  pendencias,
  temas,
}: {
  pendencias: LinhaPrePauta[]
  temas: LinhaPrePauta[]
}) {
  const hoje = hojeISO()

  const colunasPendencia: Array<ColunaTabela<LinhaPrePauta>> = [
    {
      chave: 'ordem',
      rotulo: 'Ordem',
      alinhamento: 'numero',
      largura: '5rem',
      conteudo: (linha) => <span className="numero">{linha.ordem_item}</span>,
    },
    {
      chave: 'pendencia',
      rotulo: 'Pendência em aberto',
      conteudo: (linha) => linha.detalhe ?? linha.tema,
    },
    { chave: 'dono', rotulo: 'Dono', conteudo: (linha) => linha.dono ?? 'Sem dono registrado' },
    {
      chave: 'prazo',
      rotulo: 'Prazo',
      conteudo: (linha) => formatarData(linha.prazo),
    },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta
          tom={
            linha.situacao === 'atrasada'
              ? 'vermelha'
              : linha.situacao === 'no prazo'
                ? 'verde'
                : 'amarela'
          }
          ponto
        >
          {linha.situacao === 'atrasada'
            ? 'Atrasada'
            : linha.situacao === 'no prazo'
              ? 'No prazo'
              : 'Sem prazo definido'}
        </Etiqueta>
      ),
    },
    {
      chave: 'tempo',
      rotulo: 'Tempo previsto',
      alinhamento: 'numero',
      conteudo: (linha) => `${linha.tempo_previsto_minutos} min`,
    },
  ]

  const colunasTema: Array<ColunaTabela<LinhaPrePauta>> = [
    { chave: 'tema', rotulo: 'Tema sugerido', conteudo: (linha) => <strong>{linha.tema}</strong> },
    { chave: 'detalhe', rotulo: 'Do que trata', conteudo: (linha) => linha.detalhe ?? 'Sem descrição' },
    {
      chave: 'tipo',
      rotulo: 'Tipo',
      conteudo: (linha) => (
        <Etiqueta tom={linha.tipo === 'deliberativo' ? 'marca' : 'neutra'}>
          {ROTULO_PAUTA_TIPO[linha.tipo]}
        </Etiqueta>
      ),
    },
    {
      chave: 'tempo',
      rotulo: 'Tempo sugerido',
      alinhamento: 'numero',
      conteudo: (linha) => `${linha.tempo_previsto_minutos} min`,
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-pre-pauta">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-pre-pauta">
          Pré-pauta
        </h2>
        <p className="secao__nota">
          Montada por `valor.montar_pre_pauta`, com a data de hoje, {formatarData(hoje)}, como
          referência de atraso. Primeiro as pendências, depois os temas sugeridos.
        </p>
      </div>

      <Cartao
        titulo="1. Pendências que reaparecem até fechar"
        legenda="Toda pendência aberta ou em andamento volta para a mesa, com dono e prazo."
        semRespiro
      >
        <Tabela
          colunas={colunasPendencia}
          linhas={pendencias}
          chaveDaLinha={(linha) => `pendencia-${linha.ordem_item}`}
          legenda="Pendências em aberto da turma, na ordem de prazo, com as sem prazo no fim."
          vazioTitulo="Nenhuma pendência em aberto"
          vazioTexto="A turma fechou tudo que ficou da reunião anterior, cada uma com evidência."
        />
      </Cartao>

      <Cartao
        className="secao"
        titulo="2. Temas sugeridos do banco de pautas"
        legenda="Os temas que esta turma ainda não tratou, na ordem do método."
        semRespiro
      >
        <Tabela
          colunas={colunasTema}
          linhas={temas}
          chaveDaLinha={(linha) => `tema-${linha.ordem_item}`}
          legenda="Temas do banco de pautas ainda não tratados por esta turma."
          vazioTitulo="Nenhum tema sugerido"
          vazioTexto="A turma já passou pelos temas do banco, ou o banco de pautas ainda não foi semeado."
        />
      </Cartao>
    </section>
  )
}

// ------------------------------------------------------------ itens da pauta

function ItensDaPauta({ itens }: { itens: ItemPautaNaTela[] }) {
  const colunas: Array<ColunaTabela<ItemPautaNaTela>> = [
    {
      chave: 'ordem',
      rotulo: 'Ordem',
      alinhamento: 'numero',
      largura: '5rem',
      conteudo: (linha) => <span className="numero">{linha.ordem}</span>,
    },
    {
      chave: 'tema',
      rotulo: 'Item',
      conteudo: (linha) => (
        <>
          <strong>{linha.tema}</strong>
          {linha.detalhe ? (
            <>
              <br />
              <span className="texto-fraco">{linha.detalhe}</span>
            </>
          ) : null}
        </>
      ),
    },
    {
      chave: 'tipo',
      rotulo: 'Tipo',
      conteudo: (linha) => (
        <Etiqueta tom={linha.tipo === 'deliberativo' ? 'marca' : 'neutra'}>
          {ROTULO_PAUTA_TIPO[linha.tipo]}
        </Etiqueta>
      ),
    },
    {
      chave: 'tempo',
      rotulo: 'Tempo previsto',
      alinhamento: 'numero',
      conteudo: (linha) => `${linha.tempo_previsto_minutos} min`,
    },
    {
      chave: 'responsavel',
      rotulo: 'Responsável',
      conteudo: (linha) => linha.responsavel ?? 'A definir na reunião',
    },
    {
      chave: 'origem',
      rotulo: 'Origem',
      conteudo: (linha) => (
        <>
          {ROTULO_PAUTA_ORIGEM[linha.origem]}
          {linha.automatico ? (
            <>
              <br />
              <Etiqueta tom="amarela">Entrou sozinho pela regra da pendência</Etiqueta>
            </>
          ) : null}
        </>
      ),
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-itens-pauta">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-itens-pauta">
          Os itens da pauta
        </h2>
        <p className="secao__nota">
          Ordenados, com tempo previsto, responsável, origem e o tipo deliberativo ou consultivo.
        </p>
      </div>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={itens}
          chaveDaLinha={(linha) => linha.id}
          legenda="Itens da pauta, na ordem em que serão tratados."
          vazioTitulo="Pauta ainda sem itens"
          vazioTexto="Assim que a pauta nascer, as pendências em aberto da turma entram sozinhas."
        />
      </Cartao>
    </section>
  )
}

// --------------------------------------------------------- banco de pautas

function BancoDePautas({
  banco,
  tema,
  definirTema,
}: {
  banco: BancoPauta[]
  tema: string
  definirTema: (texto: string) => void
}) {
  const familias: PautaFamilia[] = ['governanca', 'gestao', 'tendencias']
  const comItens = familias.filter((familia) => banco.some((linha) => linha.familia === familia))
  const [aba, setAba] = useState<string>(comItens[0] ?? 'governanca')

  return (
    <section className="secao" aria-labelledby="titulo-banco">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-banco">
          Banco de pautas
        </h2>
        <p className="secao__nota">
          Os temas de governança e as famílias de gestão do método, cada um com as perguntas que
          abrem a conversa.
        </p>
      </div>

      <Cartao
        titulo="Escrever um tema novo"
        legenda="O assistente propõe a partir do banco de temas. Nada entra no campo sem você mandar."
      >
        <Campo
          rotulo="Tema do item de pauta"
          placeholder="Por exemplo: alçadas e processo de decisão"
          value={tema}
          valorAtual={tema}
          onChange={(evento) => definirTema(evento.target.value)}
          auxilio="O tema escrito aqui entra na pauta como item, com tempo, responsável e tipo."
          acessorio={
            <BotaoIA
              campo="pauta_encontro"
              rotulo="Sugerir tema"
              textoAtual={tema}
              contexto={{
                banco_de_temas: banco
                  .slice(0, 8)
                  .map((linha) => linha.tema)
                  .join(' · '),
                temas_no_banco: banco.length,
              }}
              aoAceitar={(texto) => definirTema(texto)}
            />
          }
        />
      </Cartao>

      <div className="secao">
        <Abas
          rotulo="Famílias do banco de pautas"
          ativa={aba}
          aoTrocar={setAba}
          abas={comItens.map((familia) => {
            const temas = banco.filter((linha) => linha.familia === familia)
            return {
              chave: familia,
              rotulo: ROTULO_PAUTA_FAMILIA[familia],
              contagem: temas.length,
              conteudo: (
                <div className="grade grade--2">
                  {temas.map((linha) => (
                    <Cartao
                      key={linha.id}
                      titulo={linha.tema}
                      legenda={linha.descricao ?? undefined}
                      acoes={
                        <Etiqueta tom={linha.tipo_sugerido === 'deliberativo' ? 'marca' : 'neutra'}>
                          {ROTULO_PAUTA_TIPO[linha.tipo_sugerido]}
                        </Etiqueta>
                      }
                      rodape={
                        <span className="texto-fraco">
                          {linha.codigo} · tempo sugerido de {linha.tempo_sugerido_minutos} minutos
                        </span>
                      }
                    >
                      <p className="texto-fraco">Perguntas orientadoras</p>
                      <ul className="lista-felix" style={{ marginTop: 'var(--esp-2)' }}>
                        {linha.perguntas_orientadoras.map((pergunta, indice) => (
                          <li key={`${linha.id}-${indice}`}>{pergunta}</li>
                        ))}
                      </ul>
                      <Botao
                        tom="contorno"
                        tamanho="p"
                        className="secao"
                        onClick={() => definirTema(linha.tema)}
                      >
                        Usar este tema
                      </Botao>
                    </Cartao>
                  ))}
                </div>
              ),
            }
          })}
        />
      </div>
    </section>
  )
}
