# Requisitos para construir · CRM, PRM e BRM de Valor

Versão 1.1 · 22/09/2026. O que eu preciso de Hamilton Felix para entregar a plataforma funcionando para os colaboradores da Felix, para os parceiros externos e para os conselheiros, com o gerenciamento dos conselhos.

> **Respondido em 22/09/2026.** Os blocos B, C, D e E estão fechados. As respostas e as premissas que eu completei a partir dos materiais da casa estão em `CATALOGO-E-REGRAS.md`, que passa a ser a fonte de verdade desses três blocos.
>
> | Bloco | Situação |
> |---|---|
> | **B, pessoas** | fechado. Só `hamiltonfelix@gmail.com` como administrador master no lançamento. Os demais entram por uma tela de gestão de usuários dentro da plataforma, que por isso sobe na Entrega 1 |
> | **C, regras** | fechado. Vendedor interno 10% e parceiro 10%, os dois sobre o valor menos 15% de imposto médio. O resto foi deduzido dos materiais e está marcado como premissa |
> | **D, catálogo** | fechado. Sete programas de Valor e sete serviços fora dos programas, com estrutura oficial e níveis de contrato |
> | **E, conselho** | fechado. Ata de sete seções, pendências que reaparecem, banco de pautas dos 15 temas, NPS trimestral, nota do conselheiro semestral |
> | **A, acessos** | **é o único que continua aberto**, e só trava a publicação. Detalhe no fim deste documento |

Como responder: por número, uma linha cada. Onde houver opção, basta a letra. Onde eu já tiver proposto um padrão, "ok" confirma.

Legenda de urgência:

| Marca | O que significa |
|---|---|
| **BLOQUEIA** | sem isso não existe sistema no ar |
| **PILOTO** | sem isso o sistema sobe mas ninguém usa de verdade |
| **DEPOIS** | posso começar com um padrão e trocar sem refazer nada |

---

## Bloco A · Acessos e contas

Cinco itens destravam a publicação. Nenhum deles eu consigo criar sozinho, porque envolvem cartão, CAPTCHA ou a sua identidade.

| Nº | O que preciso | Urgência | Como me entregar |
|---|---|---|---|
| A1 | Projeto no **Supabase**, região São Paulo, no plano gratuito para começar | BLOQUEIA | crie a conta e me passe a URL do projeto, a chave pública e a chave de serviço. A chave de serviço nunca entra no repositório |
| A2 | Chave da **API da Anthropic** para os botões de IA, com teto de gasto | BLOQUEIA para a Entrega 5 | console da Anthropic, chave nova só para este projeto |
| A3 | Acesso ao **DNS da Locaweb** para criar o subdomínio | BLOQUEIA para publicar | o painel tem CAPTCHA e regra de senha, então você entra e cria o registro. Eu mando o valor exato |
| A4 | **Repositório privado** no GitHub, sugestão de nome `valor-plataforma` | BLOQUEIA | criar e me dar acesso de escrita |
| A5 | Projeto no **Google Cloud** com OAuth para Calendar, Drive e Gmail | PILOTO | eu digo os escopos exatos; você cria e aprova a tela de consentimento |
| A6 | **Envio de e-mail** para convites, NPS, alertas e atas | PILOTO | opções: (a) Resend, (b) Postmark, (c) SMTP da Locaweb com a caixa @felixempresarial.com.br, que ainda está pendente de criação |
| A7 | **Assinatura eletrônica** | DEPOIS | opções: (a) ZapSign, que você já usa, (b) DocuSign, (c) nenhuma por enquanto, contrato assinado fora e anexado |
| A8 | **WhatsApp** | DEPOIS | opções: (a) só link direto para o número comercial, sem integração, (b) API oficial da Meta, que exige aprovação e custo por conversa |

---

## Bloco B · Quem vai usar

Preciso da lista real de pessoas. Sem ela não consigo testar permissão, e permissão é o coração deste sistema.

| Nº | O que preciso |
|---|---|
| B1 | **Lista de colaboradores** que vão entrar: nome, e-mail e perfil. Os perfis disponíveis são administrador, líder ou sócio, financeiro, gerente de contas, conselheiro, assessor executivo, leitura |
| B2 | **Quem é o administrador geral** além de você, se houver |
| B3 | **A conta de emergência**: sugiro um e-mail dedicado, com a senha e os códigos de recuperação impressos para o envelope. Confirme o endereço a usar |
| B4 | **Conselheiros** que vão entrar no piloto: nome, e-mail e se cada um é interno da casa ou associado com contrato próprio |
| B5 | **Parceiros** para o piloto do PRM: sugiro começar com dois ou três dos mais ativos. Nome, e-mail e as contas que já são atribuídas a cada um |
| B6 | **Assessor executivo**: quem é, e se vê todas as contas ou só as atribuídas. Padrão proposto: só as atribuídas |

---

## Bloco C · Regras de negócio que só você sabe

São as regras que viram cálculo no sistema. Cada uma tem a minha proposta de padrão, para você confirmar ou corrigir.

### Comissão de parceiro

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| C1 | A comissão incide sobre o valor bruto da parcela ou sobre o líquido depois de impostos? | sobre o bruto da parcela |
| C2 | Apura no faturamento ou no recebimento? | no recebimento |
| C3 | Por quanto tempo o parceiro recebe: pela vida do contrato, pelos primeiros 12 meses, pelos primeiros 24? | pela vida do contrato |
| C4 | Na renovação, continua a mesma comissão? | sim, se o parceiro seguir ativo |
| C5 | Percentual padrão por tipo de oferta, e se há faixa diferente para conselho, consultoria e treinamento | um percentual único por oferta, cadastrado no catálogo |
| C6 | Quanto tempo um registro de oportunidade aprovado garante a atribuição da conta ao parceiro | 12 meses a partir da aprovação |
| C7 | Quem aprova o registro e em quantos dias | você aprova, em 5 dias úteis |

### Remuneração do conselheiro

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| C8 | O conselheiro associado é remunerado por valor fixo mensal, por percentual do contrato ou por reunião realizada? | percentual do contrato, cadastrado por conselheiro |
| C9 | Essa remuneração fica registrada no sistema e entra no cálculo de margem? | sim, e é campo confidencial |
| C10 | O conselheiro enxerga o valor do contrato da conta que ele atende? | sim, da conta dele; não vê margem nem comissão de terceiros |

### Dinheiro e margem

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| C11 | Percentual de imposto padrão a aplicar sobre a nota | um percentual único por inquilino, editável por contrato |
| C12 | Como calcular margem: valor do contrato menos impostos, menos comissão de parceiro, menos remuneração do conselheiro? | exatamente isso |
| C13 | Quem enxerga margem | só você, líder e financeiro |

### Funil e metas

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| C14 | **Meta do período**, anual e trimestral, da casa e por pessoa. Sem meta não existe cobertura de pipeline | meta anual da casa, dividida por quatro, até você informar por pessoa |
| C15 | Critério de **Tier 1, 2 e 3** para uma conta: porte, potencial de receita, aderência ao método, relação estratégica? | potencial de receita anual combinado com aderência ao portfólio |
| C16 | Em quantos dias um lead sem contato vira alerta | 3 dias |
| C17 | Limite de dias parado que acende o alarme, enquanto não houver mediana histórica | 30 dias |
| C18 | Quem aprova proposta acima de determinado valor, e se há alçada de desconto | sem alçada na versão 1, tudo passa por você |

---

## Bloco D · O catálogo do portfólio

O catálogo é o que aparece na hora de escolher a oferta do negócio, e é o que dispara a criação de turma no BRM.

| Nº | O que preciso |
|---|---|
| D1 | **A lista fechada do que a casa vende hoje.** A minha leitura do site e das planilhas encontrou: Conselho de Valor dedicado, Conselho de Valor compartilhado, Negócios de Valor, Liderança de Valor, Gestão de Valor, Mentoria de Valor, Executivo de Valor, consultoria pontual, consultoria recorrente, treinamento pontual, treinamento recorrente, C-level as a service, NEXT C-LEVEL e modelo por resultado ou equity. Confirme o que está vivo, o que saiu e o que falta |
| D2 | Para cada oferta: **duração padrão, cadência e número de encontros** |
| D3 | Para cada oferta: **gera turma no BRM ou não** |
| D4 | Para cada oferta: **quais entregáveis** o cliente recebe |
| D5 | Quais ofertas aceitam os níveis **N2, participação nos resultados**, e **N3, equity** |
| D6 | Se o preço de referência entra no sistema. Se entrar, é campo confidencial e nunca sai em documento público |

---

## Bloco E · Conselhos e entrega, o BRM

É a parte que hoje vive fora de qualquer sistema e é a segunda entrega.

### Rito e ata

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| E1 | Confirmar o **padrão de ata de sete seções** como oficial da casa | confirmado, com a estrutura de 16 blocos como extensão opcional |
| E2 | Quem escreve, quem aprova e em quantas horas a ata sai depois da reunião | assessor escreve, conselheiro aprova, sai em 24 horas |
| E3 | A ata vai para o cliente por e-mail pelo sistema ou só fica na pasta do Drive? | as duas coisas, com registro de envio |
| E4 | As pendências reaparecem na pré-pauta seguinte até fechar | sim, é a regra |
| E5 | Reunião que trata de avaliação de pessoas do cliente fica marcada como restrita, fora da ata enviada | sim |

### Pautas

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| E6 | Usar como banco inicial os **15 temas de governança** e as **6 famílias de gestão** do método | sim |
| E7 | Existe um **cronograma temático anual** padrão para conselho, com a ordem dos temas? | se existir, me mande; senão, monto a partir dos temas |
| E8 | A pauta é enviada antecipadamente pelo sistema ao grupo do cliente? | o sistema gera e você envia; envio automático só na segunda versão |

### Turmas e programas

| Nº | O que preciso |
|---|---|
| E9 | **As turmas rodando hoje**, de conselho compartilhado e de qualquer programa: nome, início, cadência, participantes e em que encontro estão |
| E10 | **Os conselhos dedicados ativos**, com cadência e horário. A planilha tem, mas preciso da confirmação do que está vivo |
| E11 | Para as turmas de Negócios de Valor: confirmar os **12 encontros**, os entregáveis por participante e se a certificação contra evidência entra na versão 1 |
| E12 | O **resumo semanal** em Highlights, Lowlights, Metas e Prioridades entra como ritual das turmas de conselho? |

### Avaliação

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| E13 | O **questionário de NPS** exato: os blocos e a escala. Você já tem modelos de NPS de cliente, eNPS e NPS de revenda no Drive | uso os seus modelos, com a pergunta clássica mais os blocos de qualidade, atendimento, relacionamento, entrega, valor percebido, lealdade e inovação |
| E14 | Periodicidade por tipo de cliente | trimestral |
| E15 | A **nota de 0 a 10 do conselheiro**, que você pede aos sócios: com que frequência e quem responde | semestral, respondida pelos sócios do cliente |
| E16 | O que conta como registro no **Histórico de Valor**: entregável, decisão tomada, resultado medido? | qualquer um dos três, com evidência e, quando houver, um número |

---

## Bloco F · Parceiros, o PRM

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| F1 | O parceiro registra a oportunidade e espera aprovação, ou já cria o negócio direto? | registra e espera aprovação |
| F2 | O que acontece quando o parceiro registra uma conta que já está no pipeline de outro? | o sistema avisa, você decide, e a decisão fica registrada com o motivo |
| F3 | O parceiro vê o estágio real do negócio ou uma versão simplificada? | versão simplificada: registrado, em análise, aprovado, em andamento, fechado, encerrado |
| F4 | O parceiro vê a data de vencimento do contrato que ele trouxe? | sim, e o alerta de renovação |
| F5 | O parceiro vê a própria comissão prevista antes de o contrato fechar? | sim, como previsão, marcada como estimativa |
| F6 | Quais **materiais** ficam disponíveis ao parceiro na biblioteca | o institucional, os fliers dos programas e o material de treinamento de parceiro |
| F7 | O **treinamento de parceiro** entra no sistema com registro de conclusão? | sim, na Entrega 4 |

---

## Bloco G · Dados e migração

| Nº | O que preciso |
|---|---|
| G1 | Confirmar que as duas planilhas do Drive são as fontes oficiais, e qual vale quando divergem. A minha leitura é que a de prioridades tem o funil e a de contratos tem o dinheiro |
| G2 | **Autorização para ler** as pastas do Drive, as anotações do Gemini e o cofre, para pré-preencher contas e reuniões |
| G3 | O que fazer com as contas do pipeline que já são clientes. O levantamento achou pastas de prospect que já fecharam |
| G4 | A **base de leads da mentoria** e a **base fria do Distrito Federal** entram como segmento na Base de Leads ou ficam de fora? |
| G5 | Confirmar o congelamento das planilhas na data da migração, passando a operar só no sistema |
| G6 | Quem faz a conferência da importação ao meu lado, linha a linha, nas contas ativas |

---

## Bloco H · Confidencialidade

| Nº | Pergunta | Padrão proposto |
|---|---|---|
| H1 | Confirmar a lista de campos confidenciais: margem, comissão, impostos, líquido, remuneração de conselheiro, condições de equity, preço de referência, notas internas, avaliação de pessoas | confirmado |
| H2 | O gerente de contas interno vê margem? | não, liberável por perfil |
| H3 | O assessor executivo vê valor de contrato? | não |
| H4 | Quem é o **encarregado de dados** para a LGPD | você, até indicação em contrário |
| H5 | Entra **termo de consentimento** no primeiro contato com um lead? | campo de consentimento no contato, preenchido por quem registra |

---

## Bloco I · Identidade e conteúdo

| Nº | O que preciso |
|---|---|
| I1 | Os **arquivos de logo** em alta: lockup bordô horizontal e vertical, lockup branco, ícone. Eu já tenho o horizontal bordô |
| I2 | A decisão entre as linhas **ORIGEM** e **MERIDIANO** do Brand Kit 2.0 |
| I3 | O **nome que aparece na tela** e na aba do navegador. Proposta: "CRM de Valor", com "Felix Empresarial" no rodapé |
| I4 | Os **templates em DOCX** de proposta e de contrato que você usa hoje, para virarem template do sistema |
| I5 | Os **textos padrão** de e-mail: convite para reunião, envio de ata, pesquisa de NPS, lembrete de pendência. Se não houver, eu escrevo e você aprova |

---

## O que eu faço sem depender de nada

Para deixar claro o que não está esperando você:

- Todo o banco de dados, com as tabelas, as relações e a política de acesso por perfil.
- A interface inteira: funil, kanban, contas, contatos, negócios, atividades, painéis, construtor de consultas.
- Os cálculos de pipeline auditado, cobertura, concentração e forecast por artefato.
- O design system na identidade da casa e o PWA para celular.
- O leitor das planilhas, com a prévia e a fila "a confirmar", rodando com dados de exemplo.
- A estrutura do BRM, com programa, turma, encontro, participante e entregável.
- O gerador de ata no padrão de sete seções, em PDF e DOCX.
- O pacote de configuração exportável do white label, com o teste que reprova se houver dado da casa.
- Toda a suíte de testes de permissão, com um usuário de cada perfil.

Ou seja: posso começar hoje e chegar longe. Os itens do Bloco A me travam só na hora de publicar e de ligar a IA. Os Blocos B a I definem se o sistema nasce com a cara da Felix ou com um padrão genérico que depois vai ter que ser corrigido a mão.

---

## Ordem sugerida para você responder

1. **Bloco A**, os itens A1, A3 e A4. Com eles eu publico.
2. **Bloco B**, a lista de pessoas. Com ela eu testo permissão de verdade.
3. **Bloco D**, o catálogo. É o que estrutura o funil e as turmas.
4. **Bloco C**, as regras de dinheiro. Sem elas o painel do dono mostra número errado.
5. **Bloco E**, o conselho. É a segunda entrega e a que mais muda o seu dia.
6. O resto pode vir durante a construção.

Se preferir, transformo este documento num formulário web preenchível, no padrão das ferramentas da casa, que você responde no celular e exporta em PDF.
