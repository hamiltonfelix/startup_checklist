import { useEffect, useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { BarraLateral } from '@/layout/BarraLateral'
import { Cabecalho } from '@/layout/Cabecalho'
import { Rodape } from '@/layout/Rodape'

const CHAVE_RECOLHIDA = 'felix.lateral.recolhida'

/**
 * A casca da aplicação: barra lateral, cabeçalho, área de conteúdo e rodapé.
 *
 * No computador a lateral fica fixa e pode recolher para só ícones. Abaixo de
 * 1024px ela vira gaveta, com cortina por trás e fechamento pelo Escape.
 */
export function Casca() {
  const local = useLocation()
  const [gaveta, setGaveta] = useState(false)
  const [recolhida, setRecolhida] = useState(
    () => window.localStorage.getItem(CHAVE_RECOLHIDA) === 'sim',
  )

  // Trocar de tela fecha a gaveta e leva o foco para o topo do conteúdo.
  useEffect(() => {
    setGaveta(false)
  }, [local.pathname])

  useEffect(() => {
    window.localStorage.setItem(CHAVE_RECOLHIDA, recolhida ? 'sim' : 'nao')
  }, [recolhida])

  useEffect(() => {
    if (!gaveta) return
    const naTecla = (evento: KeyboardEvent) => {
      if (evento.key === 'Escape') setGaveta(false)
    }
    document.addEventListener('keydown', naTecla)
    return () => document.removeEventListener('keydown', naTecla)
  }, [gaveta])

  const classes = [
    'casca',
    recolhida ? 'casca--recolhida' : '',
    gaveta ? 'casca--gaveta-aberta' : '',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div className={classes}>
      <a className="pular-para-conteudo" href="#conteudo">
        Pular para o conteúdo
      </a>

      <BarraLateral aoNavegar={() => setGaveta(false)} recolhida={recolhida} />

      {gaveta ? (
        <button
          type="button"
          className="casca__cortina"
          aria-label="Fechar a navegação"
          onClick={() => setGaveta(false)}
        />
      ) : null}

      <Cabecalho
        aoAbrirGaveta={() => setGaveta(true)}
        aoRecolher={() => setRecolhida((anterior) => !anterior)}
        recolhida={recolhida}
      />

      <div className="corpo">
        <main className="conteudo" id="conteudo" tabIndex={-1}>
          <Outlet />
        </main>
        <Rodape />
      </div>
    </div>
  )
}
