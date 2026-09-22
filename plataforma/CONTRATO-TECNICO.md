# Contrato técnico · Plataforma de Valor

Versão 1.0 · 22/09/2026. Este documento é lei para todo agente que escreve código nesta pasta. Quem desrespeita qualquer regra abaixo tem a entrega rejeitada pela auditoria.

## 1. O que estamos construindo

Três produtos sobre um único banco, multi-inquilino desde o primeiro commit:

- **CRM de Valor**: o funil comercial nas nove fases do método Negócios de Valor.
- **PRM de Valor**: o portal do parceiro que indica negócios, com visibilidade restrita.
- **BRM de Valor**: a entrega do conselheiro, com programas, turmas, encontros, atas e entregáveis.

Leia antes de escrever qualquer linha:

1. `crm-gestao-continua/ENTENDIMENTO-E-PROMPT-MESTRE.md` · o desenho completo
2. `crm-gestao-continua/ESQUEMA-DE-DADOS.md` · entidades, campos e confidencialidade
3. `crm-gestao-continua/CATALOGO-E-REGRAS.md` · catálogo do portfólio, comissão, conselho
4. `crm-gestao-continua/REQUISITOS-PARA-CONSTRUIR.md` · decisões já fechadas

## 2. Regras editoriais, sem exceção

| Regra | Detalhe |
|---|---|
| Idioma | Português do Brasil, com acentuação correta, em tudo: comentários, textos de tela, mensagens de erro, nomes de coluna em rótulo |
| Travessão | **Proibido** o travessão e a meia-risca em qualquer arquivo. Use vírgula, ponto, dois-pontos, ou reescreva |
| Separador | Ponto médio `·` quando precisar separar elementos numa linha |
| Período | Intervalo de datas escrito com a palavra `a`, nunca com traço |
| Nome | Escreva `Felix`, sempre sem acento |
| Identificadores | `snake_case` sem acento e sem cedilha: `data_decisao_cliente`, `negocios`, `papeis_negocio` |
| Rótulos de tela | Com acento correto: `Negócio`, `Gerente de Contas`, `Próximo passo` |

## 3. Vocabulário obrigatório na interface

| Use | Nunca use |
|---|---|
| Negócio | Oportunidade |
| Gerente de Contas | Vendedor |
| Plano de Trabalho | Proposta |
| Contrato de Valor | Pedido |
| Confirmação de Compromisso | Fechamento |
| Data da decisão do cliente | Data de fechamento |
| Fase | Estágio, etapa do CRM |

## 4. As nove fases do funil

| Número | Fase | Artefato que a comprova |
|---|---|---|
| 0 | Lead | nenhum |
| 1 | Seleção Estratégica | Plano de Conta |
| 2 | Exploração Profunda | Plano de Negócio |
| 3 | Conexão de Valor | Plano de Trabalho |
| 4 | Confirmação de Compromisso | Contrato de Valor |
| 5 | Execução de Excelência | Entrega do Valor |
| 6 | Cultivo de Valor | Monitoria do Valor |
| 7 | Parceria de Crescimento | Renovação do Valor |
| 9 | Arquivo | concluído, vencido, cancelado, perdido |

A fase 8, Gestão Contínua, é a plataforma inteira. Não é uma fase do funil.

O conselheiro entra na fase 3 e segue até o fim. Isso vive na tabela `papeis_negocio`, com a coluna `entrou_na_fase`.

## 5. Forecast por artefato, nunca por probabilidade

| Categoria | Condição |
|---|---|
| `compromisso` | existe Contrato de Valor validado com o cliente |
| `possivel` | existe Plano de Trabalho validado com o cliente |
| `aberto` | existe Plano de Negócio validado com o cliente |
| `fora` | nenhum artefato validado |

Nenhuma tela mostra percentual de probabilidade como previsão de receita.

## 6. As quatro invariantes de higiene

Todo negócio ativo nas fases 1 a 4 precisa ter:

1. Próximo passo com data definida
2. Data da decisão do cliente no futuro
3. Interação nos últimos 30 dias
4. Artefato da fase atual registrado

Pipeline declarado é a soma de tudo. Pipeline auditado é a soma do que passa nas invariantes. As duas linhas aparecem lado a lado em todo painel.

## 7. Padrão de tabela

Toda tabela de negócio carrega, sem exceção:

```sql
id            uuid primary key default gen_random_uuid(),
inquilino_id  uuid not null references valor.inquilinos(id) on delete restrict,
criado_em     timestamptz not null default now(),
criado_por    uuid,
atualizado_em timestamptz,
atualizado_por uuid,
arquivado_em  timestamptz
```

Regras:

- **Nada é apagado.** Arquivar é preencher `arquivado_em`. Não existe `DELETE` no código de aplicação.
- Toda tabela tem `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` e pelo menos uma política.
- Toda coluna confidencial recebe `COMMENT ON COLUMN ... IS 'CONFIDENCIAL: quem pode ver'`.
- Dinheiro é `numeric(14,2)`. Percentual é `numeric(6,4)`. Nunca `float`.
- Data com hora é `timestamptz`. Data pura é `date`.

## 8. Contexto de sessão

O banco decide o que cada um vê. A interface nunca esconde nada que o banco tenha entregado.

| Parâmetro | Uso |
|---|---|
| `app.inquilino_id` | o inquilino da sessão |
| `app.usuario_id` | o usuário autenticado |
| `app.perfil` | `admin_master`, `lider`, `comercial`, `gerente_contas`, `conselheiro`, `parceiro`, `financeiro`, `assessor` |
| `app.parceiro_id` | preenchido apenas quando o perfil é `parceiro` |

Em produção no Supabase, esses valores vêm do JWT. Localmente vêm de `set_config`. As políticas leem sempre por `current_setting('app.x', true)`, então o mesmo SQL roda nos dois lugares.

## 9. O que o parceiro jamais vê

Margem, comissão de terceiros, custo de conselheiro, avaliação de pessoas, ata marcada como restrita, negócio de outro parceiro, e qualquer conta em que ele não tenha papel. Isso é garantido por política de linha e por máscara de coluna, nunca por `if` na interface.

## 10. Identidade visual

| Elemento | Valor |
|---|---|
| Vinho | `#5E1E3A` |
| Vinho profundo | `#490B2C` |
| Dourado | `#EFB810` |
| Dourado claro | `#F9DB5C` |
| Dourado sobre branco | `#C2900A` |
| Tinta | `#1D1D1B` |
| Cinza | `#707070` |
| Alarme verde | `#2E7D4F` |
| Alarme amarelo | `#C58A00` |
| Alarme vermelho | `#B3261E` |
| Título | Oswald |
| Texto | Montserrat |

Texto justificado somente em PDF. Nunca na tela.

## 11. Segredo nenhum no repositório

Nenhuma chave, senha, token, telefone, e-mail de cliente, valor de contrato ou avaliação de pessoa entra nestes arquivos. Semente de dados usa apenas nomes fictícios e valores redondos inventados. O repositório é público.

## 12. Propriedade de arquivos

Cada agente escreve somente os arquivos da sua lista. Nenhum agente edita arquivo de outro. Quem precisar de mudança em arquivo alheio escreve o pedido no seu relatório final, e o orquestrador resolve.

## 13. Como entregar

Ao terminar, o agente devolve: arquivos criados, o comando exato que prova que funciona, a saída real desse comando, e o que ficou pendente. Sem "deve funcionar". Se não rodou, diga que não rodou.
