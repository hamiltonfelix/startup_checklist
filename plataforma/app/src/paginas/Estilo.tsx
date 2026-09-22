import { useState } from 'react'
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
  Esqueleto,
  Etiqueta,
  Migalhas,
  Modal,
  Paginacao,
  Selecao,
  Tabela,
  type ColunaTabela,
} from '@/componentes/indice'
import { NEGOCIOS_EXEMPLO, categoriaForecast } from '@/dados/exemplo'
import { useTema } from '@/sessao/contexto'
import { data, dinheiro, ROTULO_FASE, ROTULO_FORECAST } from '@/tipos/rotulos'
import type { NegocioExemplo } from '@/dados/exemplo'

/**
 * Vitrine do sistema de design da Felix.
 *
 * Uma página só com todas as cores e todos os componentes de base, para servir
 * de referência e de teste visual. Trocar o tema no cabeçalho conferem os dois
 * temas de uma vez.
 */

interface Cor {
  nome: string
  valor: string
  uso: string
  claro?: boolean
}

const PALETA: Cor[] = [
  { nome: 'Vinho', valor: '#5E1E3A', uso: 'Marca, título, botão principal' },
  { nome: 'Vinho profundo', valor: '#490B2C', uso: 'Barra lateral, estado pressionado' },
  { nome: 'Dourado', valor: '#EFB810', uso: 'Realce, topo de cartão, foco', claro: true },
  { nome: 'Dourado claro', valor: '#F9DB5C', uso: 'Realce no tema escuro, seleção', claro: true },
  { nome: 'Dourado sobre branco', valor: '#C2900A', uso: 'Dourado legível em texto' },
  { nome: 'Tinta', valor: '#1D1D1B', uso: 'Texto corrente' },
  { nome: 'Cinza', valor: '#707070', uso: 'Texto de apoio e rótulo' },
  { nome: 'Alarme verde', valor: '#2E7D4F', uso: 'Em dia, validado, cumprido' },
  { nome: 'Alarme amarelo', valor: '#C58A00', uso: 'Atenção, prazo perto' },
  { nome: 'Alarme vermelho', valor: '#B3261E', uso: 'Fora do auditado, vencido' },
]

const ESCALA = [
  { ficha: '--texto-3xg · 40px', tamanho: 'var(--texto-3xg)', fonte: 'var(--fonte-titulo)' },
  { ficha: '--texto-2xg · 30px', tamanho: 'var(--texto-2xg)', fonte: 'var(--fonte-titulo)' },
  { ficha: '--texto-xg · 24px', tamanho: 'var(--texto-xg)', fonte: 'var(--fonte-titulo)' },
  { ficha: '--texto-g · 20px', tamanho: 'var(--texto-g)', fonte: 'var(--fonte-titulo)' },
  { ficha: '--texto-m · 17px', tamanho: 'var(--texto-m)', fonte: 'var(--fonte-texto)' },
  { ficha: '--texto-base · 15px', tamanho: 'var(--texto-base)', fonte: 'var(--fonte-texto)' },
  { ficha: '--texto-p · 13px', tamanho: 'var(--texto-p)', fonte: 'var(--fonte-texto)' },
  { ficha: '--texto-pp · 12px', tamanho: 'var(--texto-pp)', fonte: 'var(--fonte-texto)' },
  { ficha: '--texto-micro · 11px', tamanho: 'var(--texto-micro)', fonte: 'var(--fonte-texto)' },
]

const ESPACOS = ['--esp-1', '--esp-2', '--esp-3', '--esp-4', '--esp-5', '--esp-6', '--esp-7', '--esp-8']
const RAIOS = ['--raio-p', '--raio-m', '--raio-g', '--raio-xg', '--raio-pilula']
const SOMBRAS = ['--sombra-p', '--sombra-m', '--sombra-g', '--sombra-xg']

export function Estilo() {
  const { tema, definirTema } = useTema()
  const [modalAberto, setModalAberto] = useState(false)
  const [aba, setAba] = useState('componentes')
  const [pagina, setPagina] = useState(1)
  const [porPagina, setPorPagina] = useState(10)
  const [proximoPasso, setProximoPasso] = useState('')
  const [descricao, setDescricao] = useState('')
  const [comErro, setComErro] = useState('')

  const colunas: Array<ColunaTabela<NegocioExemplo>> = [
    { chave: 'conta', rotulo: 'Conta', conteudo: (linha) => linha.conta_nome, ordenavel: true },
    { chave: 'titulo', rotulo: 'Negócio', conteudo: (linha) => linha.titulo },
    {
      chave: 'fase',
      rotulo: 'Fase',
      conteudo: (linha) => <Etiqueta tom="marca">{ROTULO_FASE[linha.fase]}</Etiqueta>,
    },
    {
      chave: 'forecast',
      rotulo: 'Forecast',
      conteudo: (linha) => (
        <Etiqueta tom={categoriaForecast(linha) === 'compromisso' ? 'verde' : 'neutra'}>
          {ROTULO_FORECAST[categoriaForecast(linha)]}
        </Etiqueta>
      ),
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
      ordenavel: true,
      conteudo: (linha) => dinheiro(linha.valor_total),
    },
  ]

  return (
    <>
      <Migalhas
        itens={[
          { rotulo: 'Configuração', para: '/configuracao/identidade' },
          { rotulo: 'Identidade' },
        ]}
      />

      <div className="pagina__topo">
        <div className="pagina__titulos">
          <p className="kicker">Sistema de design · Felix Empresarial</p>
          <h1 className="pagina__titulo">Identidade da casa</h1>
          <p className="pagina__lede">
            Todas as cores e todos os componentes de base numa tela só. Serve de vitrine, de
            referência e de teste visual nos dois temas.
          </p>
        </div>
        <div className="pagina__acoes">
          <Botao
            tom={tema === 'claro' ? 'principal' : 'contorno'}
            tamanho="p"
            onClick={() => definirTema('claro')}
          >
            Tema claro
          </Botao>
          <Botao
            tom={tema === 'escuro' ? 'principal' : 'contorno'}
            tamanho="p"
            onClick={() => definirTema('escuro')}
          >
            Tema escuro
          </Botao>
          <Botao
            tom={tema === 'sistema' ? 'principal' : 'contorno'}
            tamanho="p"
            onClick={() => definirTema('sistema')}
          >
            Seguir o sistema
          </Botao>
        </div>
      </div>

      {/* ------------------------------------------------------------ cores */}
      <section className="secao" aria-labelledby="titulo-cores">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-cores">
            As dez cores da casa
          </h2>
          <p className="secao__nota">
            Nenhum componente inventa cor. Tudo sai das variáveis de `tokens.css`.
          </p>
        </div>

        <div className="paleta">
          {PALETA.map((cor) => (
            <article className="paleta__ficha" key={cor.nome}>
              <div className="paleta__amostra" style={{ background: cor.valor }} />
              <div className="paleta__dados">
                <p className="paleta__nome">{cor.nome}</p>
                <p className="paleta__valor">{cor.valor}</p>
                <p className="paleta__uso">{cor.uso}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      {/* ------------------------------------------------------- tipografia */}
      <section className="secao" aria-labelledby="titulo-tipografia">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-tipografia">
            Tipografia
          </h2>
          <p className="secao__nota">
            Oswald no título, em caixa alta e com espaçamento largo. Montserrat no texto. Texto
            nunca justificado na tela.
          </p>
        </div>

        <div className="vitrine__bloco escala-tipo">
          {ESCALA.map((linha) => (
            <div className="escala-tipo__linha" key={linha.ficha}>
              <span className="escala-tipo__ficha">{linha.ficha}</span>
              <span style={{ fontSize: linha.tamanho, fontFamily: linha.fonte }}>
                Negócios de Valor
              </span>
            </div>
          ))}
        </div>
      </section>

      {/* -------------------------------------------- espaço, raio e sombra */}
      <section className="secao" aria-labelledby="titulo-medidas">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-medidas">
            Espaçamento, raio e sombra
          </h2>
          <p className="secao__nota">Passo de quatro pixels. Tudo encaixa nesta régua.</p>
        </div>

        <div className="grade grade--3">
          <Cartao titulo="Espaçamento">
            <div className="vitrine__medidas">
              {ESPACOS.map((nome) => (
                <div className="vitrine__medida" key={nome}>
                  <span className="vitrine__medida-nome">{nome}</span>
                  <span className="vitrine__medida-barra" style={{ width: `var(${nome})` }} />
                </div>
              ))}
            </div>
          </Cartao>

          <Cartao titulo="Raio">
            <div className="vitrine__raios">
              {RAIOS.map((nome) => (
                <div className="vitrine__raio" key={nome} style={{ borderRadius: `var(${nome})` }}>
                  {nome.replace('--raio-', '')}
                </div>
              ))}
            </div>
          </Cartao>

          <Cartao titulo="Sombra">
            <div className="vitrine__sombras">
              {SOMBRAS.map((nome) => (
                <div className="vitrine__sombra" key={nome} style={{ boxShadow: `var(${nome})` }}>
                  {nome.replace('--sombra-', '')}
                </div>
              ))}
            </div>
          </Cartao>
        </div>
      </section>

      {/* -------------------------------------------------------- botões */}
      <section className="secao" aria-labelledby="titulo-botoes">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-botoes">
            Botões
          </h2>
          <p className="secao__nota">Cinco tons, quatro tamanhos, com foco visível no teclado.</p>
        </div>

        <div className="vitrine__bloco">
          <p className="vitrine__rotulo">Tons</p>
          <div className="vitrine__amostras">
            <Botao tom="principal">Principal</Botao>
            <Botao tom="realce">Realce</Botao>
            <Botao tom="contorno">Contorno</Botao>
            <Botao tom="discreto">Discreto</Botao>
            <Botao tom="perigo">Arquivar</Botao>
            <Botao tom="principal" disabled>
              Desligado
            </Botao>
            <Botao tom="principal" carregando>
              Salvando
            </Botao>
          </div>
        </div>

        <div className="vitrine__bloco">
          <p className="vitrine__rotulo">Tamanhos</p>
          <div className="vitrine__amostras">
            <Botao tom="principal" tamanho="pp">
              Muito pequeno
            </Botao>
            <Botao tom="principal" tamanho="p">
              Pequeno
            </Botao>
            <Botao tom="principal">Padrão</Botao>
            <Botao tom="principal" tamanho="g">
              Grande
            </Botao>
          </div>
        </div>
      </section>

      {/* ---------------------------------------------------- etiquetas */}
      <section className="secao" aria-labelledby="titulo-etiquetas">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-etiquetas">
            Etiquetas
          </h2>
          <p className="secao__nota">
            A cor nunca carrega sozinha o significado. O texto dentro sempre diz o que é.
          </p>
        </div>

        <div className="vitrine__bloco">
          <div className="vitrine__amostras">
            <Etiqueta tom="neutra">Rascunho</Etiqueta>
            <Etiqueta tom="marca">Conexão de Valor</Etiqueta>
            <Etiqueta tom="realce">Plano de Trabalho</Etiqueta>
            <Etiqueta tom="verde" ponto>
              Validado com o cliente
            </Etiqueta>
            <Etiqueta tom="amarela" ponto>
              Atenção
            </Etiqueta>
            <Etiqueta tom="vermelha" ponto>
              Fora do pipeline auditado
            </Etiqueta>
            <Etiqueta tom="solida">Contrato de Valor</Etiqueta>
          </div>
        </div>
      </section>

      {/* ------------------------------------------------------- alarmes */}
      <section className="secao" aria-labelledby="titulo-alarmes">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-alarmes">
            Alarmes
          </h2>
          <p className="secao__nota">
            O vermelho é anunciado na hora pelo leitor de tela. Os demais esperam a pessoa terminar.
          </p>
        </div>

        <div className="vitrine__pilha">
          <Alarme tom="informacao" titulo="Gestão Contínua">
            A fase 8 do método é a plataforma inteira, e não uma fase do funil.
          </Alarme>
          <Alarme tom="verde" titulo="Higiene em dia">
            Todos os negócios ativos cumprem as quatro invariantes.
          </Alarme>
          <Alarme
            tom="amarelo"
            titulo="Interação vencendo"
            acoes={<Botao tamanho="p" tom="contorno">Registrar conversa</Botao>}
          >
            Duas contas passam de trinta dias sem conversa registrada nesta semana.
          </Alarme>
          <Alarme tom="vermelho" titulo="Data da decisão do cliente no passado" aoFechar={() => undefined}>
            Um negócio saiu do pipeline auditado. Isso é dívida, não pipeline.
          </Alarme>
        </div>
      </section>

      {/* ------------------------------------------ campos e o botão de IA */}
      <section className="secao" aria-labelledby="titulo-campos">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-campos">
            Campos, seleção e o botão assistido
          </h2>
          <p className="secao__nota">
            O botão assistido tem três estados: parado, pensando e com sugestão pronta. Nada entra
            no campo sem a pessoa mandar.
          </p>
        </div>

        <Cartao titulo="Formulário de exemplo" legenda="Negócio na Conexão de Valor">
          <div className="vitrine__formulario">
            <Campo
              rotulo="Título do negócio"
              placeholder="Conselho dedicado, ciclo de doze meses"
              obrigatorio
              auxilio="Como este negócio aparece nas listas e no painel."
            />

            <Selecao
              rotulo="Fase"
              vazio="Escolha a fase"
              opcoes={[
                { valor: '1', rotulo: '1 · Seleção Estratégica' },
                { valor: '2', rotulo: '2 · Exploração Profunda' },
                { valor: '3', rotulo: '3 · Conexão de Valor' },
                { valor: '4', rotulo: '4 · Confirmação de Compromisso' },
              ]}
              auxilio="A saída de cada fase é comprovada por artefato."
            />

            <Campo
              rotulo="Data da decisão do cliente"
              type="date"
              auxilio="A data em que o cliente decide. Nunca se chama de outra coisa."
            />

            <Campo
              rotulo="Campo com erro"
              value={comErro}
              onChange={(evento) => setComErro(evento.target.value)}
              erro="Este campo precisa de um valor para o negócio avançar de fase."
            />

            <CampoTexto
              multiplas_linhas
              rotulo="Próximo passo"
              value={proximoPasso}
              onChange={(evento) => setProximoPasso(evento.target.value)}
              placeholder="O que acontece a seguir, com data e nome do lado do cliente"
              maxLength={400}
              contador
              valorAtual={proximoPasso}
              acessorio={
                <BotaoIA
                  campo="proximo_passo"
                  textoAtual={proximoPasso}
                  aoAceitar={setProximoPasso}
                  contexto={{ fase: 3, conta: 'Metalúrgica Aurora Fictícia' }}
                />
              }
            />

            <CampoTexto
              multiplas_linhas
              rotulo="Descrição do negócio"
              value={descricao}
              onChange={(evento) => setDescricao(evento.target.value)}
              placeholder="O que a conta busca e o que a casa entrega"
              acessorio={
                <BotaoIA
                  campo="descricao_negocio"
                  textoAtual={descricao}
                  aoAceitar={setDescricao}
                  rotulo="Sugerir"
                />
              }
            />
          </div>
        </Cartao>
      </section>

      {/* ------------------------------------------------- abas e tabela */}
      <section className="secao" aria-labelledby="titulo-abas">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-abas">
            Abas, tabela e paginação
          </h2>
          <p className="secao__nota">
            No telefone a tabela vira lista de fichas, e cada célula leva o próprio rótulo.
          </p>
        </div>

        <Cartao semRespiro>
          <div style={{ padding: 'var(--esp-5) var(--esp-5) 0' }}>
            <Abas
              rotulo="Vitrine de componentes"
              ativa={aba}
              aoTrocar={setAba}
              abas={[
                {
                  chave: 'componentes',
                  rotulo: 'Negócios',
                  contagem: NEGOCIOS_EXEMPLO.length,
                  conteudo: (
                    <Tabela
                      colunas={colunas}
                      linhas={NEGOCIOS_EXEMPLO}
                      chaveDaLinha={(linha) => linha.id}
                      legenda="Negócios de exemplo, com empresas fictícias e valores inventados."
                      ordenadaPor="valor"
                      sentido="decrescente"
                      aoOrdenar={() => undefined}
                    />
                  ),
                },
                {
                  chave: 'vazio',
                  rotulo: 'Estado vazio',
                  conteudo: (
                    <EstadoVazio
                      titulo="Nenhuma conta com este filtro"
                      texto="Ajuste o filtro, ou cadastre a primeira conta do período."
                      acoes={<Botao tom="principal">Nova conta</Botao>}
                    />
                  ),
                },
                {
                  chave: 'espera',
                  rotulo: 'Espera',
                  conteudo: (
                    <div className="vitrine__pilha">
                      <Carregando texto="Carregando negócios" />
                      <Carregando texto="Salvando" emLinha />
                      <Esqueleto linhas={5} />
                    </div>
                  ),
                },
                { chave: 'desligada', rotulo: 'Aba desligada', desabilitada: true, conteudo: null },
              ]}
            />
          </div>

          <Paginacao
            pagina={pagina}
            total={NEGOCIOS_EXEMPLO.length}
            porPagina={porPagina}
            aoTrocarPagina={setPagina}
            aoTrocarTamanho={(tamanho) => {
              setPorPagina(tamanho)
              setPagina(1)
            }}
          />
        </Cartao>
      </section>

      {/* ---------------------------------------------- cartões e janela */}
      <section className="secao" aria-labelledby="titulo-cartoes">
        <div className="secao__topo">
          <h2 className="secao__titulo" id="titulo-cartoes">
            Cartões, migalhas e janela
          </h2>
          <p className="secao__nota">
            A janela fecha com Escape, prende a tabulação e devolve o foco a quem a abriu.
          </p>
        </div>

        <div className="grade grade--3">
          <Cartao titulo="Cartão simples" legenda="Sem topo colorido">
            <p>O padrão da casa: fio fino, sombra discreta e respiro generoso.</p>
          </Cartao>

          <Cartao
            tom="marca"
            titulo="Cartão de marca"
            legenda="Topo em vinho"
            rodape="Atualizado agora"
          >
            <p>Use quando o cartão carrega o número principal da tela.</p>
          </Cartao>

          <Cartao
            tom="realce"
            titulo="Cartão de realce"
            legenda="Topo em dourado"
            acoes={<Botao tamanho="p" tom="contorno" onClick={() => setModalAberto(true)}>Abrir janela</Botao>}
          >
            <p>Use quando o cartão precisa chamar atenção sem virar alarme.</p>
          </Cartao>
        </div>

        <div className="vitrine__bloco" style={{ marginTop: 'var(--esp-4)' }}>
          <p className="vitrine__rotulo">Migalhas</p>
          <Migalhas
            itens={[
              { rotulo: 'CRM de Valor', para: '/painel' },
              { rotulo: 'Contas', para: '/contas' },
              { rotulo: 'Metalúrgica Aurora Fictícia' },
            ]}
          />
        </div>
      </section>

      <Modal
        aberto={modalAberto}
        aoFechar={() => setModalAberto(false)}
        titulo="Confirmar a mudança de fase"
        legenda="Conexão de Valor para Confirmação de Compromisso"
        rodape={
          <>
            <Botao tom="discreto" onClick={() => setModalAberto(false)}>
              Cancelar
            </Botao>
            <Botao tom="principal" onClick={() => setModalAberto(false)}>
              Confirmar
            </Botao>
          </>
        }
      >
        <p>
          A saída da Conexão de Valor exige o Plano de Trabalho validado com o cliente. Confirme que
          a validação está registrada antes de avançar.
        </p>
        <ul className="lista-felix" style={{ marginTop: 'var(--esp-4)' }}>
          <li>Plano de Trabalho registrado e validado.</li>
          <li>Próximo passo com data marcada.</li>
          <li>Data da decisão do cliente adiante de hoje.</li>
        </ul>
      </Modal>
    </>
  )
}
