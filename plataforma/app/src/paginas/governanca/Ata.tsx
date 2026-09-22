import { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  Alarme,
  Botao,
  BotaoIA,
  CampoTexto,
  Cartao,
  Carregando,
  EstadoVazio,
  Etiqueta,
  Migalhas,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { AVISO_SEM_BANCO } from '@/dados/cliente'
import { guardarConteudoDaAta, useAta } from '@/dados/governanca'
import type { CampoAssistido } from '@/ia/ServicoIA'
import type {
  AtaNaLista,
  ChaveBlocoExtensao,
  ConteudoAta,
  PendenciaNaLista,
  SecaoModeloAta,
} from '@/tipos/governanca'
import {
  ataAtrasada,
  horasDeAtraso,
  PASSOS_DO_FLUXO,
  passoDaAta,
  quemFalta,
  ROTULO_ATA_STATUS,
  ROTULO_PENDENCIA_STATUS,
} from '@/tipos/governanca'
import { data as formatarData, dataPorExtenso } from '@/tipos/rotulos'

/**
 * Ficha da ata.
 *
 * O padrão da casa desde setembro de 2026 tem sete seções, nesta ordem, e é
 * isso que a tela desenha. Quando a conta liga a extensão opcional, a mesma
 * tela desenha os 16 blocos, porque a ordem vem do modelo e não do código.
 *
 * Três regras do rito mandam nesta tela:
 *   · o fluxo é assessor escreve, conselheiro aprova, sistema envia, e a ata
 *     precisa sair em 24 horas depois da reunião;
 *   · ata restrita não é enviada, e isso aparece em faixa vermelha, escrito,
 *     nunca num ícone discreto;
 *   · a exportação em PDF justifica o texto. A tela, nunca.
 */
export function Ata() {
  const { id } = useParams()
  const consulta = useAta(id)
  const ficha = consulta.data?.dados ?? null

  const [rascunho, setRascunho] = useState<ConteudoAta>({})
  const [ataCarregada, setAtaCarregada] = useState<string | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [recado, setRecado] = useState<string>('')
  const [erro, setErro] = useState<string>('')

  // O rascunho parte do que veio do banco, e só é trocado quando a ata muda.
  // Recarregar a consulta não apaga o que a pessoa está escrevendo agora.
  useEffect(() => {
    const atual = ficha?.ata.id ?? null
    if (atual === ataCarregada) return
    setAtaCarregada(atual)
    setRascunho(ficha?.ata.conteudo ?? {})
    setRecado('')
    setErro('')
  }, [ficha, ataCarregada])

  const mudou = useMemo(() => {
    if (!ficha) return false
    const original = ficha.ata.conteudo
    const chaves = new Set([...Object.keys(original), ...Object.keys(rascunho)])
    for (const chave of chaves) {
      const antes = original[chave as ChaveBlocoExtensao] ?? ''
      const agora = rascunho[chave as ChaveBlocoExtensao] ?? ''
      if (antes !== agora) return true
    }
    return false
  }, [ficha, rascunho])

  if (consulta.isPending) {
    return <Carregando texto="Abrindo a ata" />
  }

  if (consulta.isError) {
    return (
      <Alarme tom="vermelho" titulo="A ata não carregou">
        {consulta.error.message}
      </Alarme>
    )
  }

  if (!ficha) {
    return (
      <>
        <Migalhas itens={[{ rotulo: 'BRM de Valor' }, { rotulo: 'Atas', para: '/atas' }, { rotulo: 'Ata' }]} />
        <Cartao>
          <EstadoVazio
            titulo="Ata não encontrada"
            texto="O endereço aponta para uma ata que não existe, ou que esta sessão não alcança."
            acoes={
              <Link className="botao botao--contorno" to="/atas">
                Voltar para a lista de atas
              </Link>
            }
          />
        </Cartao>
      </>
    )
  }

  const { ata, secoes, usa_extensao: usaExtensao, pendencias } = ficha

  async function guardar() {
    if (!ficha) return
    setGuardando(true)
    setRecado('')
    setErro('')
    try {
      const onde = await guardarConteudoDaAta(ficha.ata.id, rascunho)
      setRecado(
        onde === 'banco'
          ? 'Conteúdo guardado no banco.'
          : 'Sem banco ligado nesta máquina, a alteração fica só nesta tela e some ao recarregar.',
      )
      if (onde === 'banco') void consulta.refetch()
    } catch (falha) {
      setErro(falha instanceof Error ? falha.message : 'Não foi possível guardar o conteúdo.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <>
      <Migalhas
        itens={[
          { rotulo: 'BRM de Valor' },
          { rotulo: 'Atas', para: '/atas' },
          { rotulo: `Ata ${ata.numero}` },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">
            {ata.conta_nome} · {ata.turma_nome ?? 'Turma não informada'}
          </p>
          <h1 className="pagina__titulo">
            Ata {ata.numero} · reunião de {formatarData(ata.data_reuniao)}
          </h1>
          <p className="pagina__lede">
            {ata.titulo ?? 'Reunião ordinária do conselho'} ·{' '}
            {usaExtensao
              ? 'esta conta usa a extensão opcional de 16 blocos'
              : 'padrão de sete seções, em uso desde setembro de 2026'}
            .
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao
            tom="contorno"
            disabled={ata.restrita}
            title={
              ata.restrita
                ? 'Ata restrita não circula em PDF. A reunião tratou de pessoas do cliente.'
                : 'Gera o PDF da ata, com o texto justificado como manda o padrão da casa.'
            }
            onClick={() => setErro(exportarEmPdf(ata, secoes, rascunho) ?? '')}
          >
            Exportar em PDF
          </Botao>
          <Botao tom="principal" carregando={guardando} disabled={!mudou} onClick={() => void guardar()}>
            Guardar as seções
          </Botao>
        </div>
      </div>

      {consulta.data?.deExemplo ? (
        <Alarme tom="amarelo" titulo="Dados de exemplo" className="secao">
          {AVISO_SEM_BANCO}
        </Alarme>
      ) : null}

      {ata.restrita ? (
        <Alarme tom="vermelho" titulo="Ata restrita: esta ata NÃO é enviada ao cliente" className="secao">
          <p>
            A reunião tratou de pessoas do cliente. Por isso a ata nasce restrita, e ata restrita
            não sai da casa: não entra na fila de envio, não tem destinatário, não vai para o
            portal do parceiro e não é exportada para circular.
          </p>
          <p>
            O registro existe para o líder tratar diretamente com a conta. Se algo desta ata
            precisa chegar ao cliente, escreva uma ata ordinária, sem o conteúdo sobre pessoas.
          </p>
        </Alarme>
      ) : null}

      {ataAtrasada(ata) ? (
        <Alarme
          tom="vermelho"
          titulo={`Passou das 24 horas: ${horasDeAtraso(ata.prazo_envio)} horas de atraso`}
          className="secao"
        >
          O rito manda a ata sair em até 24 horas depois da reunião. {quemFalta(ata)}
        </Alarme>
      ) : null}

      <Fluxo ata={ata} />

      <section className="secao" aria-labelledby="titulo-secoes">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-secoes">
            {usaExtensao ? 'Os 16 blocos da extensão' : 'As sete seções do padrão'}
          </h2>
          <p className="secao__nota">
            Na ordem do modelo em vigor. O botão do assistente propõe texto e espera: nada entra no
            campo sem você mandar, e a ata é documento que vai para o cliente.
          </p>
        </div>

        {recado ? (
          <Alarme tom="verde" titulo="Alteração registrada" aoFechar={() => setRecado('')}>
            {recado}
          </Alarme>
        ) : null}

        {erro ? (
          <Alarme tom="vermelho" titulo="Atenção" aoFechar={() => setErro('')}>
            {erro}
          </Alarme>
        ) : null}

        <div style={{ display: 'grid', gap: 'var(--esp-4)' }}>
          {secoes.map((secao) => (
            <Cartao
              key={secao.chave}
              titulo={`${secao.ordem}. ${secao.rotulo}`}
              legenda={secao.apoio}
              acoes={
                secao.obrigatoria ? (
                  <Etiqueta tom="marca">Obrigatória</Etiqueta>
                ) : (
                  <Etiqueta tom="neutra">Opcional</Etiqueta>
                )
              }
            >
              <CampoTexto
                multiplas_linhas
                rotulo={secao.rotulo}
                rows={secao.chave === 'identificacao' ? 3 : 6}
                value={rascunho[secao.chave] ?? ''}
                valorAtual={rascunho[secao.chave] ?? ''}
                onChange={(evento) =>
                  setRascunho((anterior) => ({ ...anterior, [secao.chave]: evento.target.value }))
                }
                acessorio={
                  <BotaoIA
                    campo={campoAssistidoDaSecao(secao.chave)}
                    rotulo="Sugerir texto"
                    textoAtual={rascunho[secao.chave] ?? ''}
                    contexto={{
                      secao: secao.rotulo,
                      conta: ata.conta_nome,
                      data_reuniao: ata.data_reuniao,
                      numero_da_ata: ata.numero,
                    }}
                    aoAceitar={(texto) =>
                      setRascunho((anterior) => ({ ...anterior, [secao.chave]: texto }))
                    }
                  />
                }
              />
            </Cartao>
          ))}
        </div>
      </section>

      <PendenciasDaAta pendencias={pendencias} />

      <PrePautaDaAta ata={ata} />
    </>
  )
}

// ------------------------------------------------------------------ fluxo

function Fluxo({ ata }: { ata: AtaNaLista }) {
  const passo = passoDaAta(ata.status)

  return (
    <section className="secao" aria-labelledby="titulo-fluxo">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-fluxo">
          O fluxo da ata
        </h2>
        <p className="secao__nota">
          O assessor escreve, o conselheiro aprova, o sistema envia. O prazo é de 24 horas depois da
          reunião.
        </p>
      </div>

      <div className="grade grade--3">
        {PASSOS_DO_FLUXO.map((etapa, indice) => {
          const cumprido = passo > indice
          const atual = passo === indice
          const tom = cumprido ? 'verde' : atual ? 'realce' : 'neutra'

          return (
            <Cartao
              key={etapa.chave}
              tom={atual ? 'realce' : 'simples'}
              titulo={`${indice + 1}. ${etapa.rotulo}`}
              legenda={etapa.quem}
            >
              <Etiqueta tom={tom} ponto>
                {cumprido ? 'Cumprido' : atual ? 'Passo atual' : 'Ainda não'}
              </Etiqueta>
              <p className="texto-fraco" style={{ marginTop: 'var(--esp-3)' }}>
                {indice === 0
                  ? ata.escrita_em
                    ? `Escrita por ${ata.escrita_por_nome ?? 'assessor não identificado'} em ${dataPorExtenso(ata.escrita_em)}.`
                    : 'Ainda sem registro de escrita.'
                  : null}
                {indice === 1
                  ? ata.aprovada_em
                    ? `Aprovada por ${ata.aprovada_por_nome ?? 'conselheiro não identificado'} em ${dataPorExtenso(ata.aprovada_em)}.`
                    : 'Ainda sem aprovação do conselheiro.'
                  : null}
                {indice === 2
                  ? ata.restrita
                    ? 'Ata restrita não é enviada. Este passo não acontece.'
                    : ata.enviada_em
                      ? `Enviada em ${dataPorExtenso(ata.enviada_em)}.`
                      : `Prazo de envio até ${dataPorExtenso(ata.prazo_envio)}.`
                  : null}
              </p>
            </Cartao>
          )
        })}
      </div>

      <Cartao className="secao" titulo="Onde a ata está agora" tom="plano">
        <p>
          <Etiqueta tom={ata.status === 'enviada' ? 'verde' : 'marca'} ponto>
            {ROTULO_ATA_STATUS[ata.status]}
          </Etiqueta>
        </p>
        <p style={{ marginTop: 'var(--esp-3)' }}>{quemFalta(ata)}</p>
        <p className="texto-fraco" style={{ marginTop: 'var(--esp-2)' }}>
          {ata.restrita
            ? 'Sem destinatário, porque ata restrita não é enviada.'
            : ata.destinatarios.length > 0
              ? `Destinatários registrados: ${ata.destinatarios.join(', ')}.`
              : 'Nenhum destinatário registrado ainda.'}
        </p>
      </Cartao>
    </section>
  )
}

// ------------------------------------------------- pendências desta ata

function PendenciasDaAta({ pendencias }: { pendencias: PendenciaNaLista[] }) {
  const colunas: Array<ColunaTabela<PendenciaNaLista>> = [
    { chave: 'descricao', rotulo: 'Pendência', conteudo: (linha) => linha.descricao },
    { chave: 'dono', rotulo: 'Dono', conteudo: (linha) => linha.dono },
    { chave: 'prazo', rotulo: 'Prazo', conteudo: (linha) => formatarData(linha.prazo) },
    {
      chave: 'situacao',
      rotulo: 'Situação',
      conteudo: (linha) => (
        <Etiqueta
          tom={
            linha.status === 'concluida' ? 'verde' : linha.status === 'cancelada' ? 'neutra' : 'amarela'
          }
          ponto
        >
          {ROTULO_PENDENCIA_STATUS[linha.status]}
        </Etiqueta>
      ),
    },
  ]

  return (
    <section className="secao" aria-labelledby="titulo-pendencias-ata">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-pendencias-ata">
          O que esta ata deixou em aberto
        </h2>
        <p className="secao__nota">
          Cada linha daqui reaparece na pré-pauta da reunião seguinte, até fechar com evidência.
        </p>
      </div>

      <Cartao semRespiro>
        <Tabela
          colunas={colunas}
          linhas={pendencias}
          chaveDaLinha={(linha) => linha.id}
          legenda="Pendências nascidas desta ata, com dono, prazo e situação."
          vazioTitulo="Nenhuma pendência nasceu desta ata"
          vazioTexto="As deliberações e os próximos passos desta reunião não geraram pendência registrada."
        />
      </Cartao>
    </section>
  )
}

// ---------------------------------------------- pré-pauta da próxima reunião

function PrePautaDaAta({ ata }: { ata: AtaNaLista }) {
  return (
    <section className="secao" aria-labelledby="titulo-pre-pauta-ata">
      <div className="secao__topo">
        <h2 className="secao__titulo" id="titulo-pre-pauta-ata">
          Próxima reunião com pré-pauta
        </h2>
        <p className="secao__nota">
          A pré-pauta nasce das pendências em aberto. A tela da pauta mostra a lista inteira, já
          ordenada pelo banco.
        </p>
      </div>

      <Cartao>
        <p>
          {ata.proxima_data
            ? `Próxima reunião combinada para ${dataPorExtenso(ata.proxima_data)}.`
            : 'Data da próxima reunião ainda não combinada nesta ata.'}
        </p>
        {ata.pre_pauta.length > 0 ? (
          <ul className="lista-felix" style={{ marginTop: 'var(--esp-4)' }}>
            {ata.pre_pauta.map((linha) => (
              <li key={`${linha.bloco}-${linha.ordem_item}`}>
                {linha.tema}
                {linha.detalhe ? ` · ${linha.detalhe}` : ''}
                {linha.dono ? ` · dono: ${linha.dono}` : ''}
                {linha.prazo ? ` · prazo: ${formatarData(linha.prazo)}` : ''} · {linha.situacao}
              </li>
            ))}
          </ul>
        ) : (
          <p className="texto-fraco" style={{ marginTop: 'var(--esp-3)' }}>
            A pré-pauta desta ata ainda não foi congelada no registro. Abra a tela da pauta para ver
            a pré-pauta viva, montada agora a partir das pendências em aberto.
          </p>
        )}
        <p style={{ marginTop: 'var(--esp-4)' }}>
          <Link className="botao botao--contorno botao--p" to="/pautas">
            Abrir a pauta da próxima reunião
          </Link>
        </p>
      </Cartao>
    </section>
  )
}

// ------------------------------------------------------- apoio da tela

/** Qual campo assistido combina com cada seção do modelo. */
function campoAssistidoDaSecao(chave: ChaveBlocoExtensao): CampoAssistido {
  switch (chave) {
    case 'pauta':
      return 'pauta_encontro'
    case 'resumo_discussoes':
      return 'resumo_interacao'
    case 'proximos_passos':
    case 'deliberacoes':
      return 'proximo_passo'
    default:
      return 'texto_livre'
  }
}

/**
 * Exporta a ata em PDF, pela impressão do navegador.
 *
 * A folha de estilo desta janela é a única da casa com `text-align: justify`,
 * porque o contrato técnico manda justificar somente em PDF, nunca na tela.
 * Nenhuma dependência nova entra por causa desta função.
 */
function exportarEmPdf(
  ata: AtaNaLista,
  secoes: SecaoModeloAta[],
  conteudo: ConteudoAta,
): string | null {
  if (ata.restrita) {
    return (
      'Ata restrita não é enviada nem circula em PDF. A reunião tratou de pessoas do cliente, '
      + 'e o registro fica na casa.'
    )
  }

  const janela = window.open('', '_blank', 'width=900,height=1200')
  if (!janela) {
    return 'O navegador bloqueou a janela de impressão. Libere janelas para este endereço e tente de novo.'
  }

  const escapar = (texto: string) =>
    texto
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

  const paragrafos = (texto: string) =>
    texto
      .split(/\n+/)
      .filter((linha) => linha.trim().length > 0)
      .map((linha) => `<p>${escapar(linha)}</p>`)
      .join('')

  const corpo = secoes
    .map((secao) => {
      const texto = conteudo[secao.chave] ?? ''
      if (!texto.trim() && !secao.obrigatoria) return ''
      return `<section><h2>${secao.ordem}. ${escapar(secao.rotulo)}</h2>${
        texto.trim() ? paragrafos(texto) : '<p class="vazio">Seção sem conteúdo registrado.</p>'
      }</section>`
    })
    .join('')

  const folha = `
    @page { size: A4; margin: 22mm 18mm; }
    body {
      font-family: Montserrat, system-ui, sans-serif;
      color: #1d1d1b;
      font-size: 11pt;
      line-height: 1.5;
    }
    h1, h2 { font-family: Oswald, 'Arial Narrow', sans-serif; color: #5e1e3a; }
    h1 { font-size: 18pt; letter-spacing: 0.02em; margin-bottom: 2mm; }
    h2 { font-size: 12pt; text-transform: uppercase; letter-spacing: 0.06em; margin: 8mm 0 2mm; }
    .cabeca { border-bottom: 2px solid #efb810; padding-bottom: 4mm; margin-bottom: 6mm; }
    .cabeca p { margin: 0; color: #707070; font-size: 9pt; }
    /* Justificado somente aqui, no PDF. A tela nunca justifica. */
    section p { text-align: justify; margin: 0 0 3mm; }
    .vazio { color: #707070; font-style: italic; text-align: left; }
    footer { margin-top: 10mm; border-top: 1px solid #e9dce3; padding-top: 3mm; color: #707070; font-size: 8pt; }
  `

  janela.document.write(
    `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">`
    + `<title>Ata ${ata.numero} · ${escapar(ata.conta_nome)}</title>`
    + `<style>${folha}</style></head><body>`
    + `<div class="cabeca"><h1>Ata ${ata.numero} · ${escapar(ata.conta_nome)}</h1>`
    + `<p>${escapar(ata.turma_nome ?? 'Turma não informada')} · reunião de ${formatarData(ata.data_reuniao)}</p></div>`
    + corpo
    + `<footer>Felix Empresarial · Plataforma de Valor · documento gerado a partir do registro da ata.</footer>`
    + `</body></html>`,
  )
  janela.document.close()
  janela.focus()
  janela.print()
  return null
}
