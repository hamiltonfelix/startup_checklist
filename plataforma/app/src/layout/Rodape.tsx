import { useSessao } from '@/sessao/contexto'

/** Rodapé discreto, no padrão dos relatórios impressos da casa. */
export function Rodape() {
  const { sessao } = useSessao()
  const ano = new Date().getFullYear()

  return (
    <footer className="rodape">
      <span>
        {sessao.inquilino_nome} · Plataforma de Valor · Uso interno · {ano}
      </span>
      <span className="rodape__assinatura">CRM · PRM · BRM de Valor</span>
    </footer>
  )
}
