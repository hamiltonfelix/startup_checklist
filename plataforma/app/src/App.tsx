import { Navigate, Route, Routes } from 'react-router-dom'
import { Casca } from '@/layout/Casca'
import { todosOsItens } from '@/layout/menu'
import { EmConstrucao, NaoEncontrada } from '@/paginas/EmConstrucao'
import { Estilo } from '@/paginas/Estilo'
import { Painel } from '@/paginas/Painel'

/**
 * As rotas da plataforma.
 *
 * As telas já construídas entram uma a uma. As demais nascem do próprio
 * arquivo de menu, para que nenhuma entrada de navegação leve a lugar nenhum,
 * e para que acrescentar um item de menu não exija lembrar de acrescentar uma
 * rota à mão.
 */
export function App() {
  const jaConstruidas = new Set(['/painel', '/configuracao/identidade'])

  const pendentes = todosOsItens().filter((item) => !jaConstruidas.has(item.para))

  return (
    <Routes>
      <Route element={<Casca />}>
        <Route index element={<Navigate to="/painel" replace />} />
        <Route path="/painel" element={<Painel />} />

        {/* A vitrine do sistema de design mora em dois endereços. */}
        <Route path="/configuracao/identidade" element={<Estilo />} />
        <Route path="/estilo" element={<Estilo />} />

        {pendentes.map((item) => (
          <Route
            key={item.chave}
            path={item.prefixo ? `${item.para}/*` : item.para}
            element={<EmConstrucao />}
          />
        ))}

        <Route path="/busca" element={<EmConstrucao />} />
        <Route path="*" element={<NaoEncontrada />} />
      </Route>
    </Routes>
  )
}
