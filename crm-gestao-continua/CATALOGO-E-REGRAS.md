# Catálogo e regras de negócio · CRM, PRM e BRM de Valor

Versão 1.0 · 22/09/2026. Fecha os blocos C, D e E do levantamento de requisitos, com o que Hamilton Felix respondeu e com o que eu deduzi dos materiais da casa.

Cada item traz a **origem**: `RESPOSTA` quando veio dele, `MATERIAL` quando saiu do site, das planilhas ou do cofre, e `PREMISSA` quando eu completei uma lacuna. Toda premissa é editável na tela de configuração, sem tocar em código.

---

## 1. Usuários

| Item | Decisão | Origem |
|---|---|---|
| Quem entra no lançamento | apenas `hamiltonfelix@gmail.com`, como administrador master | RESPOSTA |
| Como os demais entram | por uma tela de gestão de usuários dentro da plataforma, com convite por e-mail, definição de perfil e reenvio de convite | RESPOSTA |
| Conta de emergência | criada no primeiro dia, com múltiplo fator e códigos de recuperação impressos. Sugiro um endereço dedicado, a definir na hora de publicar | PREMISSA |
| Consequência de produto | a tela de usuários entra na Entrega 1, e não depois. Sem ela você não consegue trazer ninguém | RESPOSTA |

A tela de gestão de usuários tem: convidar por e-mail, escolher perfil, atribuir contas, ativar e desativar, forçar múltiplo fator, ver último acesso e revogar sessão.

---

## 2. Comissão e impostos

### A regra

| Item | Decisão | Origem |
|---|---|---|
| Percentual do vendedor interno | **10%** | RESPOSTA |
| Percentual do parceiro que indica | **10%** | RESPOSTA |
| Imposto médio a descontar antes | **15%** | RESPOSTA |
| Base de cálculo | o valor da parcela **menos os impostos**, e a comissão incide sobre esse líquido | RESPOSTA |
| Quando apura | no recebimento da parcela | PREMISSA |
| Por quanto tempo | pela vida do contrato, incluindo renovações, enquanto o vendedor ou o parceiro seguir ativo na conta | PREMISSA |
| Quando há vendedor **e** parceiro no mesmo negócio | os dois recebem, cada um 10% sobre a mesma base líquida | PREMISSA |
| Percentual de imposto | 15% é o padrão do inquilino, editável por contrato quando o regime for diferente | RESPOSTA mais PREMISSA |

### A conta, em ordem

```
1. valor da parcela                                    valor bruto
2. imposto                = valor bruto x 15%
3. base de comissão       = valor bruto menos imposto
4. comissão do vendedor   = base x 10%
5. comissão do parceiro   = base x 10%
6. custo do conselheiro   = conforme o contrato do conselheiro
7. margem                 = base menos comissões menos custo do conselheiro
```

Exemplo com uma parcela de dez mil: imposto de mil e quinhentos, base de oito mil e quinhentos, comissão de oitocentos e cinquenta para o vendedor e outros oitocentos e cinquenta para o parceiro, sobrando seis mil e oitocentos antes do custo do conselheiro.

Na prática, cada comissão de 10% equivale a 8,5% do bruto. O sistema guarda os dois números, para o relatório do vendedor e para o relatório do dono não divergirem.

### O que o sistema passa a ter

- **Comissão de vendedor interno** como entidade própria, espelhando a de parceiro. Não existia no esquema e entra agora.
- Percentual padrão por inquilino, sobreposto por oferta e, se preciso, por contrato ou por pessoa.
- Extrato por pessoa: previsto, apurado e pago, por competência, com o cálculo aberto linha a linha.
- O vendedor vê a própria comissão. Nunca a de outro. O parceiro, idem.

---

## 3. Margem

| Item | Decisão | Origem |
|---|---|---|
| Fórmula | valor bruto menos imposto menos comissões menos custo do conselheiro | PREMISSA derivada da regra de comissão |
| Quem vê | você, líder e financeiro | PREMISSA |
| Onde aparece | painel do dono, ficha do contrato e relatório de rentabilidade por conta, por oferta e por conselheiro | PREMISSA |

---

## 4. Remuneração do conselheiro

| Item | Decisão | Origem |
|---|---|---|
| Modelo | percentual do contrato, cadastrado por conselheiro e por contrato | PREMISSA |
| Alternativas suportadas | valor fixo mensal, valor por reunião realizada, ou percentual. O campo aceita os três, para não travar quando o modelo mudar | PREMISSA |
| Entra na margem | sim, como custo | PREMISSA |
| Confidencial | sim. O conselheiro vê a própria remuneração e o valor do contrato da conta dele, nunca a margem nem a comissão de terceiros | PREMISSA |

---

## 5. O catálogo do portfólio

Montado do site institucional, das duas planilhas e das notas do cofre. Os números são os oficiais da casa. Nenhum preço entra aqui.

### Programas de Valor

| Oferta | Público | Modalidade | Estrutura oficial | Gera turma |
|---|---|---|---|---|
| **Conselho de Valor dedicado** | donos e sócios de uma empresa | recorrente, anual | encontros semanais de conselho, encontro semanal de gestão, pauta prioritária mensal e um presencial por mês | sim, turma de um cliente |
| **Conselho de Valor compartilhado** | até 8 empresários de mercados diferentes | recorrente, anual | 48 reuniões no ano, hotseat por membro, resumo semanal, um presencial por mês | sim, turma multiempresa |
| **Negócios de Valor** | times comerciais B2B e B2G | pontual com sustentação | 12 encontros de 2h30 mais 8 semanas de sustentação; variante de 10 encontros; imersão de 3 dias; de 8 a 16 cadeiras; a unidade de venda é o time | sim, dedicada ou compartilhada |
| **Liderança de Valor** | sócios, C-level e líderes | pontual | workshop de 2 dias, 8 módulos, 1 plano de desenvolvimento por participante | sim |
| **Gestão de Valor** | sócios e principais executivos | recorrente, anual | 6 módulos, 48 temas, encontros semanais | sim |
| **Mentoria de Valor** | donos e CEOs | recorrente, anual, individual | encontro semanal, deep-dive mensal, plano em 4 estações | sim, turma de um |
| **Executivo de Valor** | ocupantes de cadeira do C-level | recorrente | Mesa do CEO: 12 etapas em 6 meses, encontros quinzenais de 2h, índice próprio em T0, T90 e T180 | sim |

### Serviços fora dos programas

| Oferta | Modalidade | Observação |
|---|---|---|
| Consultoria pontual | pontual | escopo fechado, com entregável definido |
| Consultoria recorrente | recorrente | mensalidade |
| Treinamento pontual e recorrente | pontual ou recorrente | workshop ou palestra contratada |
| C-level as a service | recorrente | executivo alocado por tempo determinado |
| Modelo por resultado | recorrente ou pontual | honorário menor mais participação nos resultados, nível N2 |
| Equity | recorrente | honorário mais participação societária, nível N3 |
| NEXT C-LEVEL | a confirmar | frente própria, catalogada para não se perder no funil |

### Níveis de contrato por oferta

| Nível | O que é | Quais ofertas aceitam |
|---|---|---|
| N1 | honorário | todas |
| N2 | honorário mais participação nos resultados | conselho dedicado, C-level as a service, modelo por resultado |
| N3 | honorário, participação e equity | conselho dedicado e modelo por equity, com a ressalva de validação de advogado e contador que já está registrada no cofre |

**Premissa a confirmar quando quiser:** o Sprint de Valor está fora do site por decisão de julho, então entra no catálogo como inativo, disponível mas não sugerido.

---

## 6. Funil, tier e alertas

| Item | Decisão | Origem |
|---|---|---|
| Critério de **Tier** | a matriz do próprio método, contrato atual contra potencial da conta: Tier 1 ouro, Tier 2 prata, Tier 3 bronze. O sistema calcula uma sugestão e você confirma | MATERIAL, do mapa de contas do Negócios de Valor |
| **Power of X** | número de linhas do portfólio que a conta já comprou, visível na ficha da conta e usado na sugestão de tier | MATERIAL |
| **Prioridade** | 1, 2 e 3, como na planilha de hoje | MATERIAL |
| Lead sem dono | alerta em 3 dias | PREMISSA |
| Negócio parado | alarme acima de 30 dias, até existir mediana histórica por fase, quando passa a ser duas vezes a mediana | MATERIAL, da ficha da etapa 8 |
| Proposta vencendo | avisos a 7 e a 1 dia | PREMISSA |
| Contrato vencendo | negócio de renovação criado a 90 dias, com avisos a 60 e a 30 | PREMISSA |
| **Meta do período** | campo na tela de configuração, anual e trimestral, da casa e por pessoa. Sem meta o painel mostra cobertura como indisponível, e não um número errado | PREMISSA |
| Alçada de aprovação | sem alçada na versão 1: tudo passa por você | PREMISSA |

---

## 7. Conselho e entrega

| Item | Decisão | Origem |
|---|---|---|
| Padrão de ata | as sete seções em uso desde setembro de 2026: identificação, participantes, pauta, resumo das discussões, deliberações, próximos passos, próxima reunião com pré-pauta | MATERIAL |
| Extensão opcional | a estrutura de 16 blocos das skills de ata, ligável por cliente | MATERIAL |
| Fluxo da ata | o assessor escreve, o conselheiro aprova, o sistema envia. Alerta se não sair em 24 horas | PREMISSA |
| Pendências | reaparecem na pré-pauta até fechar, com dono e prazo | MATERIAL |
| Reunião sobre pessoas do cliente | marcada como restrita, fora da ata enviada | MATERIAL, pela regra de confidencialidade do cofre |
| Banco de pautas | os 15 temas de governança e as 6 famílias de gestão do método, cada um com perguntas orientadoras | MATERIAL |
| Ritual semanal da turma | Highlights, Lowlights, Metas e Prioridades, com tópico, responsável e data | MATERIAL, do template do Conselho de Valor |
| NPS | trimestral, com a pergunta clássica mais os blocos de qualidade, atendimento, relacionamento comercial, entrega, valor percebido, lealdade e inovação | MATERIAL, dos modelos de NPS da casa |
| Nota do conselheiro | de 0 a 10, semestral, respondida pelos sócios do cliente, com as críticas construtivas registradas | MATERIAL |
| Histórico de Valor | registro obrigatório por trimestre: o que foi entregue, que resultado gerou e qual a evidência | MATERIAL |
| Calendário de turma | 48 reuniões no ano para conselho, com recesso de meados de dezembro a meados de janeiro | MATERIAL |

---

## 8. O que continua em aberto

Nada bloqueia a construção. Estes itens têm padrão adotado e podem ser trocados numa tela, não em código:

1. A meta do período, que você informa quando quiser ver cobertura de pipeline.
2. O modelo de remuneração de cada conselheiro, quando houver o primeiro associado.
3. O endereço da conta de emergência.
4. A escolha entre as linhas ORIGEM e MERIDIANO do logo.
5. A confirmação do NEXT C-LEVEL e do Sprint de Valor no catálogo.
