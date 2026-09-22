import { Navigate, Route, Routes } from 'react-router-dom'
import { Casca } from '@/layout/Casca'
import { todosOsItens } from '@/layout/menu'
import { EmConstrucao, NaoEncontrada } from '@/paginas/EmConstrucao'
import { Estilo } from '@/paginas/Estilo'
import { Painel } from '@/paginas/Painel'
import { Atividades, Calendario, Conta, Contas, Negocio, Negocios } from '@/paginas/crm/indice'
import { Comissoes, Indicacoes, Parceiro, Parceiros } from '@/paginas/prm/indice'
import { Encontro, Encontros, Entregaveis, Programas, Turma, Turmas } from '@/paginas/brm/indice'
import {
  Ata,
  Atas,
  HistoricoDeValor,
  Pauta,
  Pendencias,
  Pesquisas,
} from '@/paginas/governanca/indice'
import { Ofertas, RegrasEAlertas, Usuarios } from '@/paginas/configuracao/indice'

/**
 * As rotas da plataforma.
 *
 * As telas construídas entram uma a uma, agrupadas pelos três produtos. O que
 * ainda não existe nasce do próprio arquivo de menu, para que nenhuma entrada
 * de navegação leve a lugar nenhum, e para que acrescentar um item de menu não
 * exija lembrar de acrescentar uma rota à mão.
 *
 * A lista abaixo é a única fonte do que já está pronto. Quem construir uma tela
 * nova acrescenta o caminho aqui e a entrada some do laço de pendentes sozinha.
 */
const CONSTRUIDAS = [
  '/painel',
  '/contas',
  '/negocios',
  '/atividades',
  '/calendario',
  '/parceiros',
  '/indicacoes',
  '/comissoes',
  '/programas',
  '/turmas',
  '/encontros',
  '/atas',
  '/pautas',
  '/entregaveis',
  '/pendencias',
  '/pesquisas',
  '/historico-de-valor',
  '/configuracao/usuarios',
  '/configuracao/ofertas',
  '/configuracao/regras-e-alertas',
  '/configuracao/identidade',
]

export function App() {
  const jaConstruidas = new Set(CONSTRUIDAS)
  const pendentes = todosOsItens().filter((item) => !jaConstruidas.has(item.para))

  return (
    <Routes>
      <Route element={<Casca />}>
        <Route index element={<Navigate to="/painel" replace />} />
        <Route path="/painel" element={<Painel />} />

        {/* CRM de Valor */}
        <Route path="/contas" element={<Contas />} />
        <Route path="/contas/:id" element={<Conta />} />
        <Route path="/negocios" element={<Negocios />} />
        <Route path="/negocios/:id" element={<Negocio />} />
        <Route path="/atividades" element={<Atividades />} />
        <Route path="/calendario" element={<Calendario />} />

        {/* PRM de Valor */}
        <Route path="/parceiros" element={<Parceiros />} />
        <Route path="/parceiros/:id" element={<Parceiro />} />
        <Route path="/indicacoes" element={<Indicacoes />} />
        <Route path="/comissoes" element={<Comissoes />} />

        {/* BRM de Valor */}
        <Route path="/programas" element={<Programas />} />
        <Route path="/turmas" element={<Turmas />} />
        <Route path="/turmas/:turmaId" element={<Turma />} />
        <Route path="/encontros" element={<Encontros />} />
        <Route path="/encontros/:encontroId" element={<Encontro />} />
        <Route path="/entregaveis" element={<Entregaveis />} />

        {/* Governança */}
        <Route path="/atas" element={<Atas />} />
        <Route path="/atas/:id" element={<Ata />} />
        <Route path="/pautas" element={<Pauta />} />
        <Route path="/pautas/:id" element={<Pauta />} />
        <Route path="/pendencias" element={<Pendencias />} />
        <Route path="/pesquisas" element={<Pesquisas />} />
        <Route path="/historico-de-valor" element={<HistoricoDeValor />} />

        {/* Configuração */}
        <Route path="/configuracao/usuarios" element={<Usuarios />} />
        <Route path="/configuracao/ofertas" element={<Ofertas />} />
        <Route path="/configuracao/regras-e-alertas" element={<RegrasEAlertas />} />

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
