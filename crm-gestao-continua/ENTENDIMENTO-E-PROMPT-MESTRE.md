# CRM de Valor, PRM de Valor e BRM de Valor · Felix Empresarial

Documento mestre de preparação. Nada foi construído ainda. Ele registra o entendimento do pedido, o inventário das fontes, a arquitetura, o desenho do produto, o modelo de dados, as decisões e o plano de entrega.

Versão 2.0 · 21/09/2026 · Incorpora as três definições de 21/09: os nomes da família, a jornada do conselheiro a partir da Conexão de Valor e o white label como entregável do programa Negócios de Valor.

Peças deste projeto:

| Arquivo | O que é |
|---|---|
| `ENTENDIMENTO-E-PROMPT-MESTRE.md` | este documento, a fonte de verdade do desenho |
| `PROMPT-MESTRE.md` | o prompt versão 1.0, pronto para abrir a sessão de construção |
| `ESQUEMA-DE-DADOS.md` | entidades, campos, relações e política de acesso |
| `2026-09-21-ESTRATEGIA-CRM-PRM-BRM-DE-VALOR.pdf` | o relatório curto de duas páginas com o entendimento |

Regra deste repositório: nenhum valor de contrato, comissão, telefone, e-mail ou avaliação de pessoa entra aqui. Ele é público. Tudo que é confidencial fica no Google Drive e nas planilhas de origem, e será carregado no sistema em ambiente privado.

---

## 1. O que eu entendi do pedido

Hamilton Felix quer uma plataforma completa, na nuvem, construída de forma autônoma, que materialize a etapa 8 da metodologia Negócios de Valor. Ela tem três produtos sobre um único banco de dados.

### 1.1 As três definições de 21/09/2026

**Primeira, os nomes.** A família se chama **CRM de Valor**, **PRM de Valor** e **BRM de Valor**. Gestão Contínua deixa de ser nome de produto e volta a ser o que é no método: a etapa transversal, o motor de registro, higiene, cobertura e forecast que atravessa os três.

**Segunda, a jornada do conselheiro.** O conselheiro entra no ciclo na **Conexão de Valor** e vai até o fim. Ele mesmo faz a pré-venda consultiva: o diagnóstico com o empresário e o Plano de Trabalho co-construído. Depois conduz a entrega, a monitoria e a renovação. Disso nasce o **BRM de Valor**, Board Relationship Management, onde ficam as atas e os entregáveis que o assessor executivo produz hoje fora do sistema, e também tudo que é entregue nos demais programas: conselho compartilhado, Negócios de Valor em turmas dedicadas e compartilhadas, mentoria e os outros.

**Terceira, o foco e o horizonte.** O foco inicial é o uso da Felix Empresarial. Depois virá uma versão **white label**, com todo o aprendizado e sem os dados e o negócio da casa, entregue a uma empresa como parte da implantação do programa Negócios de Valor.

### 1.2 O que já estava pedido e continua valendo

1. As fases do CRM são as sete etapas sequenciais do método, com uma fase antes (os leads) e uma depois (o arquivo).
2. Contas com muitas pessoas, cada uma com cargo, papel e situação. Uma conta gera muitos negócios, em paralelo.
3. IA em cada fase, como um botão ao lado do campo, que sugere e preenche. O usuário escolhe manual ou assistido.
4. Portfólio da Felix como catálogo, com modalidades dedicada, compartilhada, recorrente e pontual.
5. Prazos e alertas em tudo: validade de proposta, data de decisão, follow-up, vencimento, renovação e NPS.
6. Kanban tradicional mais atividades, com uma visão GTD para não perder nada.
7. Um grande painel, com visões do dono, do vendedor, do conselheiro, do parceiro e do financeiro.
8. Origem e qualificação do lead, tier, probabilidade, com ou sem parceiro, campanhas e eventos.
9. Contrato como entidade de verdade: assinatura, modalidade, equity, participação no resultado, comissionamento, e o vínculo de um cliente que também é fornecedor ou parceiro.
10. Duas visões de trabalho: o que é da Felix e os projetos que a Felix executa para os clientes.
11. Hospedagem na nuvem, sem perder dados, com resposta clara sobre a Locaweb.
12. Padrão de escrita, campos obrigatórios, automações e campos altamente customizáveis.
13. Consultas flexíveis, impressão e exportação em PDF.
14. Edição amigável, melhores práticas atuais de CRM e o que há de mais inovador em IA aplicada.
15. Módulo de conselho com pautas pré-prontas, atas no padrão novo, pendências, transcrições e NPS periódico.
16. Identidade visual da Felix, com visualizações muito bem cuidadas.
17. Permissionamento por administrador, líder de área, comercial, gerente de conta e parceiro externo.
18. Login protegido, com um usuário de administração e um de emergência guardado em envelope físico.
19. Propostas e contratos gerados e guardados a partir do negócio.
20. A planilha atual não pode ser perdida.

---

## 2. O que encontrei no segundo cérebro

Fontes lidas: Google Drive, cofre Obsidian espelhado no Drive, Notion e o site institucional.

### 2.1 A metodologia, em forma final

| Nº | Etapa | Artefato | Critério de saída |
|---|---|---|---|
| 1 | Seleção Estratégica | Plano de Conta | conta escolhida, hipótese escrita, primeira reunião marcada |
| 2 | Exploração Profunda | Plano de Negócio | dores, objetivos e critérios de sucesso validados pelo cliente por escrito |
| 3 | Conexão de Valor | Plano de Trabalho | plano co-construído com o cliente, sem preço, com um número que veio dele |
| 4 | Confirmação de Compromisso | Contrato de Valor | contrato negociado com plano mútuo editado pelo cliente, depois assinado |
| 5 | Execução de Excelência | Entrega do Valor | kick-off interno e externo realizados, papéis e prazos definidos |
| 6 | Cultivo de Valor | Monitoria do Valor | reuniões periódicas com indicadores, crises tratadas, valor percebido registrado |
| 7 | Parceria de Crescimento | Renovação do Valor | proposta de crescimento ou renovação antecipada |
| 8 | Gestão Contínua (transversal) | Gestão no CRM e IA | o sistema que registra e audita as sete anteriores |

Vocabulário próprio, obrigatório na interface: oportunidade vira **negócio**, vender vira **realizar negócios de valor**, proposta vira **Plano de Trabalho**, pedido vira **Contrato de Valor**, vendedor vira **Gerente de Contas**, fechamento vira **Confirmação de Compromisso**, data de fechamento vira **data da decisão do cliente**.

Três papéis do método: Gerente de Contas (metodologia própria), Pré-vendas (adaptado do Gartner) e Gerente de Projetos (adaptado do PMBOK). Uma conta gera muitos negócios: o Plano de Conta é da conta, o ciclo 2 a 7 roda por negócio.

O Plano de Conta tem template de 8 blocos: Resumo Executivo, Resumo do Contrato Atual, Customer Success, Organograma Executivo, Relacionamento da Conta, Histórico da Conta, Notícias Relevantes e Hipótese para a Exploração Profunda. Esse template vira o formulário da fase 1.

### 2.2 A etapa 8 já tem teoria escrita pela casa

A ficha b16 do Negócios de Valor 2.00 e a Ferramenta 20 (Painel de Pipeline, já construída em HTML) definem o que o sistema faz nativamente:

- **Quatro invariantes de higiene**: todo estágio tem critério de saída verificável pelo cliente; todo negócio tem próximo passo com data e nome do lado do cliente; idade no estágio acima de duas vezes a mediana é alarme; data de decisão no passado é dívida, não pipeline.
- **Pipeline declarado e pipeline auditado**: o auditado tira quem está sem próximo passo ou com data vencida. A diferença abre a reunião.
- **Cobertura calculada**: cobertura necessária igual a 1 dividido pela taxa de vitória real, com o sem decisão no denominador. Alerta de concentração quando os dois maiores negócios passam de metade do pipeline.
- **Forecast por artefato**: Compromisso (Contrato de Valor em negociação com plano mútuo editado pelo cliente), Possível (Plano de Trabalho co-construído), Aberto (Plano de Negócio validado por escrito), Fora do número (nenhum artefato validado).
- **Dupla cadência**: revisão de pipeline olha negócios; revisão trimestral olha contas. Quatro rituais com uma unidade e uma pergunta cada.
- **Rota pública** (Lei 14.133): estágios com nome de fase administrativa, desfechos próprios (suspenso, impugnado, deserto, fracassado) e forecast ancorado em cronograma público.
- **Régua de IA por etapa**: evidência nas etapas 1 e 2 e na higiene do dado. Da etapa 3 em diante a IA é assistente, não decisor.

### 2.3 O que a casa já construiu e que a plataforma absorve

| Peça existente | O que vira |
|---|---|
| Painel de Pipeline (Ferramenta 20) | o motor de higiene, cobertura e forecast por artefato, agora sobre dados vivos |
| Análise de Oportunidade · Parceiros de Valor | o score de oportunidade do PRM e a recomendação de porta de entrada por programa |
| Avaliação do Meu Papel | a autoavaliação dos três papéis no módulo de equipe e nas turmas do BRM |
| Dossiê de Inteligência | o briefing de conta gerado por IA antes de reunião, em 22 seções, sob protocolo ético e LGPD |
| Memória Executiva de Conselho e skills felix-ata | a estrutura da ata e o gerador de PDF e DOCX |
| Ata no padrão de setembro de 2026 | o padrão de sete seções que o assessor executivo já usa |
| Modelos de contrato de conselho | os três níveis: N1 honorário, N2 com participação nos resultados, N3 com equity |
| Modelos de NPS, eNPS e NPS de revenda | o instrumento de avaliação periódica |
| CRM do Sprint de Valor | a prova de que a arquitetura funciona no domínio da casa |
| Template de resumo semanal | o ritual semanal de conta no BRM: Highlights, Lowlights, Metas e Prioridades |
| 15 temas de governança e 6 famílias de gestão | o banco de pautas pré-prontas |
| Cronogramas de 48 reuniões das turmas | o calendário padrão de turma no BRM |

### 2.4 Os dados que existem hoje e não podem ser perdidos

**FELIX - PRIORIDADES - 2026** (09/09/2026), a planilha do funil:

- Contratos recorrentes: 27 linhas com empresa, executivo, serviço, periodicidade, contrato, início, fim, dia de cobrança, valor mensal, impostos, comissão, parceiro, líquido e observação. Serviço: conselho exclusivo, conselho de valor, CLT. Periodicidade: semanal, quinzenal, diário. Contrato: pendente, assinado, pausa.
- Pipeline: 127 linhas com empresa, prioridade (1 a 3), UF, cargo, nome, celular, estágio, serviço, valor mensal, meses, valor total, e-mail, parceiro e anotações. Funil de dez estágios: 0 perdido, 1 lead, 1 retomar, 2 qualificação, 3 mostrar valor, 4 POC, 5 proposta técnica, 6 proposta comercial, 7 negociação, 8 contrato, 9 ganho. Serviços: conselho recorrente, consultoria pontual, modelo resultado, NEXT C-LEVEL, C-level as a service, mentoria recorrente e pontual, consultoria recorrente, treinamento pontual e recorrente, equity. Cargos: CEO e sócio, CSO, sócio, RH, outro.
- Cadastro de parceiros: 25 linhas, com autorização para aparecer no site.
- Oportunidades por parceiro, com estágio e campos de comissão.
- Contratos pontuais: 13 linhas, 11 encerradas.
- Checklist de qualificação em cinco perguntas: Necessidade, Interesse, Competência, Horizonte, Originalidade.

**CONTRATOS E PIPELINE - FELIX** (17/09/2026), a planilha do contrato e do dinheiro:

- Carteira: 43 linhas com empresa, executivo, contato, parceiro, serviço, contrato, multa, status, horas, valor, início, término, meses, data de faturamento e status de cobrança. Contrato: assinado, pendente, cancelado. Status comercial: ativo, prospectar, proposta, cancelado, recovery, contrato, follow-up, futuro.
- Comissionamento por parceiro, com percentual e data.
- Calendários de faturamento e recebimento por cliente e por mês, de dezembro de 2023 a 2026, com impostos, comissão e líquido.
- Agenda semanal de reuniões recorrentes.

**Estrutura de pastas no Drive**: 18 contratos ativos, 71 pastas de prospect, 24 contratos antigos, 4 empreendimentos próprios. O padrão dos clientes recentes é CLIENTE (contrato e plano de trabalho), REUNIÕES (uma pasta por data) e HISTÓRICO DE VALOR (hoje vazia em cinco clientes). Esse padrão vira a estrutura de documentos por conta.

**Reuniões gravadas**: 290 arquivos em Meet Recordings e 24 em Google Meet, com 95 documentos de anotações do Gemini. Padrão de nome: título do evento, data e hora, "Anotações do Gemini". É a fonte de transcrição que o BRM lê.

**O cofre**: 28 páginas de cliente, 92 notas de reunião, 58 fichas de pessoa, para pré-preencher as contas com histórico.

### 2.5 Identidade visual e padrão de escrita

- Paleta medida em 17/09/2026: vinho do logo e dos títulos `#5E1E3A`, vinho profundo de fundo `#490B2C`, dourado `#EFB810`, dourado claro `#F9DB5C`, tinta `#1D1D1B`, cinza `#707070`. Em fundo claro o dourado é elemento gráfico, não texto; para texto sobre branco, dourado profundo `#C2900A`. Alarmes: verde `#2E7D4F`, amarelo `#C58A00`, vermelho `#B3261E`.
- Fontes: Oswald para títulos, condensada e em caixa alta; Montserrat para o corpo.
- Logo: nunca digitar o nome como texto, sempre o arquivo de lockup. Bordô em fundo claro, branco em fundo escuro.
- Escrita: português do Brasil com acentuação correta, nunca travessão nem meia-risca, ponto médio como separador, intervalos com "a". Texto justificado em documentos impressos, nunca em tela.
- Duas linhas de logo no Brand Kit 2.0 (ORIGEM e MERIDIANO) ainda sem escolha.

### 2.6 Hospedagem: o que existe

Conta corporativa na Locaweb, plano Hospedagem I por domínio, contratado em 08/2023. É hospedagem compartilhada: PHP, FTP, deploy por pasta, `.htaccess`, SSL, bancos MySQL e PostgreSQL pequenos. Não roda Node.js, funções serverless, autenticação gerenciada, armazenamento com controle de acesso nem agendador confiável. O DNS do domínio está lá. Já existe o precedente do CRM do Sprint: subdomínio apontado para outra plataforma, banco e login no Supabase, SSL válido.

---

## 3. Arquitetura

### 3.1 A resposta sobre a Locaweb

Não é preciso contratar nada novo na Locaweb, e não se deve construir dentro dela. Hospedagem compartilhada serve para site estático e páginas simples. Uma plataforma com login, perfis, dados confidenciais, arquivos, IA e alertas agendados precisa de banco relacional com segurança por linha, autenticação com múltiplo fator, armazenamento privado e funções de servidor.

**Recomendação: Supabase como backend, front-end estático publicado no domínio da Felix.** É a mesma arquitetura do CRM do Sprint, que já está no ar.

| Camada | Escolha | Por quê |
|---|---|---|
| Banco, autenticação, armazenamento, funções | Supabase (PostgreSQL gerenciado), região São Paulo | segurança por linha nativa, múltiplo fator, funções serverless, agendador, dados no Brasil |
| Front-end | aplicação web estática (React, TypeScript, Vite), instalável como PWA | roda em qualquer hospedagem, inclusive no `public_html` da Locaweb |
| IA | API da Anthropic (Claude), chamada só por funções de servidor | a chave fica no servidor, o custo é controlado, cada chamada é registrada |
| Domínio | `valor.felixempresarial.com.br`, com `/parceiros` para o PRM e `/conselho` para o BRM | um login, três experiências; o DNS continua na Locaweb |
| Código | repositório privado novo no GitHub | o repositório atual é público e não pode receber schema, seeds nem nada da carteira |
| Documentos e anexos | Supabase Storage com URLs assinadas, mais link para a pasta do cliente no Drive | o Drive continua sendo o acervo; o sistema guarda o que precisa e aponta para o resto |

**Custo estimado**, a confirmar na contratação:

| Item | Plano | Custo mensal | Quando |
|---|---|---|---|
| Supabase | Free | 0 | construção e piloto. Limite de 500 MB, pausa após 7 dias sem uso, sem backup |
| Supabase | Pro | 25 dólares | produção. 8 GB de banco, 100 GB de arquivos, backups diários por 7 dias, nunca pausa |
| API Anthropic | por uso | 20 a 100 dólares conforme o volume de transcrições e dossiês | desde o piloto |
| Locaweb | já contratado | sem mudança | DNS e publicação estática |

Não perder dados fica garantido por quatro camadas: backups diários da plataforma, exportação semanal automática para uma pasta do Drive em CSV e JSON, arquivamento em vez de exclusão em toda entidade e trilha de auditoria imutável.

### 3.2 Um login, três experiências

Uma única aplicação com perfis, e não três sistemas. O perfil decide menu, campos, painéis e relatórios. A separação de confidencialidade fica no banco, por política de acesso por linha e por coluna: o parceiro não vê margem porque a consulta dele não retorna margem, e não porque a tela esconde.

### 3.3 White label desde o primeiro dia

O sistema nasce multi-inquilino. A Felix é o inquilino 1. Cada inquilino tem marca, catálogo de portfólio, campos customizados, listas de valores, regras de alerta, templates e módulos ligados ou desligados. Os nomes das oito etapas são configuráveis, mas a edição Felix mantém o cânone.

**O pacote de configuração exportável** é requisito de arquitetura, não um extra do fim: a qualquer momento é possível exportar tudo que é configuração (etapas, campos, listas, templates, pautas, automações, painéis, ferramentas, perfis) sem uma linha de dado, e importar esse pacote num inquilino novo. É isso que a Felix entrega ao cliente do programa Negócios de Valor.

---

## 4. Os três produtos

### 4.1 CRM de Valor

O funil, fase a fase:

| Fase | Nome na tela | Quem conduz | Campos obrigatórios para avançar |
|---|---|---|---|
| 0 | Base de Leads | Gerente de Contas ou Parceiro | empresa ou pessoa, origem, quem trouxe, segmento provável |
| 1 | Seleção Estratégica | Gerente de Contas | CNPJ ou site, segmento, UF, dono da conta, tier, prioridade, hipótese de valor, ao menos um contato decisor |
| 2 | Exploração Profunda | Gerente de Contas, conselheiro acompanha | Plano de Negócio com dores, objetivos e critérios de sucesso, evidência de validação pelo cliente, próximo passo com data e nome |
| 3 | Conexão de Valor | **Conselheiro**, como pré-venda consultiva | oferta do portfólio, modalidade, valor estimado, um número que veio do cliente, data da reunião de valor realizada |
| 4 | Confirmação de Compromisso | Gerente de Contas com o conselheiro | Plano de Trabalho validado, valor e meses, validade da proposta, data prevista da decisão, objeções, nível de contrato |
| 5 | Execução de Excelência | Conselheiro e assessor executivo | contrato assinado, datas, dia de faturamento, cadência, responsáveis, pasta criada, turma criada quando houver |
| 6 | Cultivo de Valor | Conselheiro e assessor executivo, no BRM | cadência em dia, NPS agendado, ao menos um registro no Histórico de Valor por trimestre |
| 7 | Parceria de Crescimento | Conselheiro com o Gerente de Contas | proposta de crescimento ou renovação, resultado |
| 8 | Arquivo | Sistema, com motivo declarado | motivo com vocabulário fechado, concorrente quando houver, lição aprendida, data |

O que sai do funil pode voltar: um arquivado vira lead de novo, com o histórico preservado.

**Papéis por negócio, não só dono de conta.** Cada negócio tem Gerente de Contas, Conselheiro, Assessor executivo e Parceiro, cada um com data de entrada. A passagem de bastão da etapa 2 para a 3 é um evento registrado, com Plano de Conta e Plano de Negócio entregues ao conselheiro.

**Como o funil de hoje entra no novo:**

| Estágio atual | Fase nova | Sub-status |
|---|---|---|
| 1 - LEAD | 0 Base de Leads | novo |
| 1 - RETOMAR | 0 Base de Leads | retomar |
| 2 - QUALIFICAÇÃO | 1 Seleção Estratégica ou 2 Exploração Profunda | se há Plano de Conta, vai para 2 |
| 3 - MOSTRAR VALOR | 3 Conexão de Valor | reunião de valor a realizar |
| 4 - POC | 3 Conexão de Valor | POC em curso |
| 5 - PROPOSTA TEC | 3 Conexão de Valor | Plano de Trabalho enviado |
| 6 - PROPOSTA COM | 4 Confirmação de Compromisso | proposta enviada |
| 7 - NEGOCIAÇÃO | 4 Confirmação de Compromisso | em negociação |
| 8 - CONTRATO | 4 Confirmação de Compromisso | minuta ou assinatura |
| 9 - GANHO | 5 Execução de Excelência | kick-off |
| 0 - PERDIDO | 8 Arquivo | perdido |
| Contratos recorrentes ativos | 6 Cultivo de Valor | por contrato |
| Contratos a menos de 90 dias do fim | 7 Parceria de Crescimento | renovação |
| Contratos pontuais encerrados e antigos | 8 Arquivo | concluído |

**Rota pública.** Toggle por negócio. Ao ligar, as fases 1 a 4 ganham sub-status com nome de fase administrativa (plano de contratações anual, ETP, edital, julgamento, homologação, contrato), a data de decisão passa a derivar do cronograma público e o arquivo ganha os desfechos suspenso, impugnado, deserto e fracassado, com campo para o identificador no PNCP.

### 4.2 PRM de Valor

O que o parceiro faz: registra a oportunidade, acompanha a aprovação, vê prazos e vencimentos, acompanha a própria comissão prevista e paga, usa o score de oportunidade para priorizar, baixa materiais liberados e faz o treinamento de parceiro.

O que ele nunca vê: margem, comissão de qualquer outra pessoa, valores internos da Felix, atas de conselho, outros parceiros, financeiro da casa e contas que não trouxe.

Fluxo de aprovação: o parceiro registra a conta e a oportunidade, o sistema checa conflito com a base (a conta já é cliente, já está no pipeline de outro, já foi registrada), o aprovador decide em prazo definido, e a aprovação passa a valer como atribuição de comissão pelo prazo do contrato.

O score de oportunidade vem da ferramenta Análise de Oportunidade: Momento 30, Acesso 20, Clareza 20, Sinais 15, Prontidão 15, com faixas Janela aberta, Em aquecimento, Cultivar e Observar, e recomendação de porta de entrada por programa.

### 4.3 BRM de Valor

É o produto da entrega. Cobre tudo que a casa faz depois da assinatura, em cinco entidades que se repetem para qualquer programa: **Programa, Turma, Encontro, Participante e Entregável**.

| Formato | Como se modela |
|---|---|
| Conselho dedicado | Programa "Conselho de Valor", uma turma por cliente, encontros na cadência do contrato, participantes são os sócios e executivos do cliente, entregáveis são atas, planos e diagnósticos |
| Conselho compartilhado | uma turma com até 8 empresários de contas diferentes, calendário de 48 reuniões, encontros com pauta comum e hotseat por membro, resumo semanal por participante |
| Negócios de Valor dedicado | uma turma por empresa, 12 encontros, participantes do time comercial do cliente, entregáveis por participante (Plano de Conta, Plano de Negócio e os demais), índice INV em T0 e T90, certificação contra evidência |
| Negócios de Valor compartilhado | uma turma com participantes de várias contas, o mesmo calendário, a mesma régua de certificação |
| Mentoria de Valor | turma de um participante, encontros semanais, plano em quatro estações |
| Liderança, Gestão e Executivo de Valor | turma por contrato, com a jornada própria de cada programa |

Além disso, o BRM cobre:

- **Reuniões de conselho** com pauta antecipada, ata no padrão de sete seções, deliberações com dono, prazo e status, pendências que reaparecem na pré-pauta até fechar, e aprovação da ata anterior.
- **Transcrições**, lidas automaticamente das pastas do Drive, anexadas à reunião certa, com fila de triagem para o que não tem cliente no título.
- **NPS periódico** por contrato, com nota por pessoa, motivações, blocos da casa, nota do conselheiro e tendência.
- **Histórico de Valor**, o registro obrigatório do que foi entregue, com que resultado e que evidência. É o insumo da Renovação.
- **Avaliação da conta** em ciclo bimestral ou trimestral, com alerta quando vence.
- **Banco de pautas** com os 15 temas de governança e as 6 famílias de gestão, cada um com perguntas orientadoras e material de apoio, mais o cronograma temático anual reaproveitável.

---

## 5. Modelo de dados

O detalhe campo a campo está em `ESQUEMA-DE-DADOS.md`. As entidades principais:

**Base**: Inquilino, Usuário, Perfil, Campo customizado, Lista de valores, Auditoria.

**Comercial**: Conta, Contato, Papel na conta, Negócio, Papel no negócio, Artefato, Proposta, Evento, Campanha.

**Contratual e financeiro**: Contrato, Parcela, Comissão, Nível de contrato.

**Parceria**: Parceiro, Registro de oportunidade, Aprovação, Material, Treinamento.

**Entrega (BRM)**: Programa, Turma, Encontro, Participante, Entregável, Reunião de conselho, Pauta, Deliberação, Pendência, Avaliação (NPS), Histórico de Valor, Transcrição.

**Transversal**: Atividade (GTD), Documento, Nota, Anexo, Alerta, Execução de IA.

Campos marcados como confidenciais ficam fora das consultas dos perfis sem direito, por política no banco. Toda exportação e impressão respeita o mesmo filtro.

---

## 6. Perfis e permissões

| Perfil | Vê | Não vê |
|---|---|---|
| Administrador geral | tudo, inclusive configuração, segurança e faturamento | |
| Administrador de emergência | tudo; credenciais em envelope lacrado; qualquer uso gera alerta | |
| Líder ou sócio | tudo do inquilino | configuração de segurança |
| Financeiro | contratos, parcelas, comissões, calendários, relatórios financeiros | pipeline e conselho, salvo se atribuído |
| Gerente de Contas | suas contas e negócios, atividades, forecast do seu funil, comissão própria | margem, comissão de terceiros, financeiro consolidado |
| **Conselheiro** | as contas em que é conselheiro, do momento em que entra no negócio; BRM completo dessas contas; agenda, pendências, entregáveis, NPS e renovações | valores de contrato de outras contas, financeiro consolidado, margem (configurável por perfil) |
| Assessor executivo | agenda, atas, pendências, transcrições e entregáveis das contas atribuídas | financeiro |
| Parceiro externo | só o que trouxe: status, aprovação, próximos passos, vencimento, sua comissão, materiais e treinamento | margem, comissão de terceiros, valores internos, atas, outros parceiros |
| Participante de turma | seu material, seus entregáveis, sua avaliação | tudo o mais |
| Cliente (portal, fase 2) | atas aprovadas, pendências dele, NPS, Histórico de Valor da conta | tudo o mais |
| Leitura | relatórios definidos | edição |

---

## 7. IA em cada fase

Princípios: a IA sugere e preenche em rascunho, o humano confirma; todo texto gerado fica marcado como rascunho; nada é enviado ao cliente sem revisão; cada chamada é registrada com custo; a chave vive só no servidor.

| Onde | Botão | O que faz |
|---|---|---|
| 0 Leads | Enriquecer | a partir de CNPJ, site e LinkedIn: razão social, porte, CNAE, segmento, notícias, sinais de momento; deduplica |
| 0 Leads | Pontuar | score de oportunidade e recomendação de porta de entrada por programa |
| 1 Seleção Estratégica | Rascunhar Plano de Conta | preenche os 8 blocos, marca lacunas, gera três hipóteses de valor e a frase de abertura |
| 1 | Dossiê de reunião | briefing executivo de 22 seções antes da primeira reunião |
| 2 Exploração Profunda | Preparar perguntas | roteiro da descoberta, no espírito de não aceitar a queixa manifesta como necessidade |
| 2 | Transcrição vira Plano de Negócio | extrai dores, objetivos, critérios de sucesso, riscos e concorrência, e aponta o que falta validar |
| 3 Conexão de Valor | Rascunhar Plano de Trabalho | converte o Plano de Negócio em plano, sem preço |
| 4 Confirmação de Compromisso | Gerar proposta e minuta | monta proposta e minuta a partir dos templates N1, N2 e N3; lista objeções prováveis e respostas |
| 5 Execução de Excelência | Kick-off | gera pauta e ata do kick-off, cria atividades, pasta e turma |
| 6 Cultivo de Valor | Ata e pendências | transforma a transcrição na ata do padrão da casa, extrai decisões, responsáveis, prazos e o insight do conselho, sugere a pré-pauta seguinte |
| 6 | Ler o NPS | agrupa motivações em temas, sinaliza risco de perda e valor percebido |
| 6 | Sugerir pauta | propõe pautas a partir dos 15 temas, das pendências abertas e do cronograma temático |
| 6 | Avaliar entregável de turma | dá devolutiva sobre o artefato do participante, contra a rubrica do programa |
| 7 Parceria de Crescimento | Proposta de crescimento | resume o Histórico de Valor e propõe renovação, upsell ou cross-sell |
| 8 Gestão Contínua | Higiene | lista o que saiu do pipeline auditado, sugere próximo passo para cada negócio parado, calcula cobertura e concentração, escreve a leitura em uma frase |
| Transversal | Perguntar à carteira | busca semântica sobre contas, reuniões, atas e transcrições |
| Transversal | Qualidade do dado | deduplica, normaliza cargos e nomes, sinaliza obrigatórios vazios |

A IA não decide probabilidade de negócio, não muda etapa sozinha, não envia mensagem ao cliente e não altera valores de contrato.

---

## 8. Painéis

| Painel | Para quem | O que mostra |
|---|---|---|
| Mesa do Dono | Hamilton | receita recorrente ativa, contratos por status e vencimento, pipeline auditado por fase, forecast por artefato, cobertura necessária contra real, NPS médio e tendência, alertas do dia, atividades vencidas, agenda da semana |
| Comercial | Gerente de Contas | kanban por fase, forecast por artefato, os quatro invariantes, cobertura e concentração, próximos passos vencidos, negócios parados, leads sem dono, conversão por transição |
| Conselheiro | quem atende | minhas contas, reuniões da semana, pendências por cliente e responsável, atas a enviar, NPS a aplicar, entregáveis devidos, Histórico de Valor, renovações a caminho |
| Turmas | quem facilita | turmas ativas, presença, entregáveis por participante, índice INV, certificações |
| Financeiro | financeiro | faturamento previsto e realizado por mês, parcelas a faturar e atrasadas, comissões apuradas e pagas, contratos a reajustar |
| Parceiro | PRM | seus leads e negócios por fase, aprovações, vencimentos, comissão prevista e paga, score das oportunidades, materiais e treinamentos |
| Eventos e campanhas | marketing e comercial | convidados por evento, presença, leads gerados por origem |
| Construtor de consultas | todos, no seu recorte | filtros por qualquer campo, agrupamento, colunas escolhidas, gráficos, visões salvas, exportação em CSV e PDF, impressão A4 com identidade |

---

## 9. Documentos, propostas e contratos

- Templates com variáveis: Plano de Conta, Plano de Negócio, Plano de Trabalho, proposta comercial, Contrato de Valor nos três níveis, kick-off, ata, pesquisa de NPS, proposta de crescimento, certificado de turma.
- Geração em PDF e DOCX com identidade Felix, corpo justificado nos documentos, versão numerada, guarda no negócio e no contrato, envio por e-mail com registro.
- Assinatura eletrônica por integração, com retorno do status para o contrato.
- Estrutura de pastas automática por conta, espelhando CLIENTE, REUNIÕES e HISTÓRICO DE VALOR, com link para o Drive.

---

## 10. Automações e alertas

| Gatilho | Ação |
|---|---|
| validade da proposta a 7 e a 1 dia | alerta ao dono e ao gerente |
| data prevista da decisão vencida | negócio sai do pipeline auditado e entra na higiene |
| próximo passo vencido ou ausente | negócio marcado, alerta ao dono |
| negócio parado acima de duas vezes a mediana da fase | alarme de idade |
| contrato a 90, 60 e 30 dias do fim | negócio de renovação criado em Parceria de Crescimento |
| fim de contrato sem renovação | contrato vence e vai ao Arquivo com motivo |
| NPS vencido | pesquisa gerada e enviada, lembrete ao responsável |
| ata não gerada 24 horas depois da reunião | alerta ao assessor e ao conselheiro |
| pendência de conselho atrasada | alerta ao responsável e destaque na pré-pauta |
| encontro de turma sem presença registrada | alerta ao facilitador |
| entregável de participante em atraso | alerta ao participante e ao facilitador |
| lead sem dono há mais de 3 dias | alerta ao líder |
| oportunidade de parceiro aguardando aprovação | alerta ao aprovador, visível ao parceiro |
| reunião criada no Calendar com conta identificada | atividade criada no sistema |
| anotação do Gemini nova no Drive | transcrição anexada à reunião ou enviada à triagem |
| toda segunda de manhã | resumo da semana por e-mail para cada perfil |
| uso da conta de emergência | alerta imediato ao administrador |

Integrações por ordem de valor: Google Calendar e Meet, Google Drive, Gmail, assinatura eletrônica, WhatsApp, ClickUp (um sentido), exportação para o cofre Obsidian.

---

## 11. Segurança e continuidade

- Autenticação com e-mail e senha forte, múltiplo fator obrigatório para administradores e financeiro, expiração de sessão, bloqueio por tentativas.
- Conta de emergência criada no primeiro dia, com credenciais e códigos de recuperação impressos para envelope físico; qualquer login dela dispara alerta.
- Política de acesso por linha e por coluna no banco, testada automaticamente a cada versão.
- Trilha de auditoria imutável, arquivamento em vez de exclusão, exportação semanal para o Drive, backups diários, restauração ensaiada por trimestre.
- LGPD: consentimento por contato, minimização, exclusão por anonimização, dados no Brasil.
- Chaves de API só em funções de servidor, segredos fora do repositório.

---

## 12. Migração

Ordem de entrada, com assistente que mostra a prévia e uma fila "a confirmar":

1. Catálogo de portfólio e listas de valores.
2. Parceiros.
3. Contas e contatos das duas planilhas, deduplicados por CNPJ e nome.
4. Contratos recorrentes e pontuais, com parcelas geradas do calendário de faturamento.
5. Pipeline, com o mapeamento de fases da seção 4.1.
6. Oportunidades por parceiro e comissões apuradas.
7. Pastas do Drive vinculadas às contas.
8. Histórico do cofre: páginas de cliente viram resumo da conta, notas de reunião viram reuniões, fichas de pessoa viram contatos.
9. Anotações do Gemini dos últimos doze meses anexadas às contas.
10. Turmas existentes do Conselho de Valor e do Negócios de Valor, com encontros e materiais.
11. Bases de leads da mentoria e a base fria, como segmentos separados.

Nada é gravado sem prévia. Valores que divergem entre as planilhas ficam marcados para decisão de Hamilton Felix. As planilhas são congeladas na data da migração.

---

## 13. White label

O que é entregue ao cliente do programa Negócios de Valor: um inquilino novo, com o **pacote de configuração** importado e nenhum dado da Felix.

O pacote contém: as oito etapas com nomes e critérios, os campos obrigatórios por fase, as listas de valores, os templates de documento, o banco de pautas, as automações, os painéis, as ferramentas, os perfis e as regras de acesso, os textos de ajuda e o material de onboarding.

O que nunca sai do inquilino da Felix: contas, contatos, negócios, contratos, valores, comissões, atas, transcrições, avaliações, Histórico de Valor e qualquer dado de pessoa.

Consequência prática: o exportador e o importador de configuração entram na primeira entrega, mesmo que só sejam usados mais tarde. Módulos ligados por inquilino: a Felix usa CRM, PRM e BRM; o cliente do programa recebe o CRM, o PRM se tiver canal e o BRM só se tiver conselho.

---

## 14. Decisões

Respondidas em 21/09/2026:

| Nº | Decisão | Resposta |
|---|---|---|
| 1 | Nome | CRM de Valor, PRM de Valor e BRM de Valor |
| 2 | Gestão Contínua | volta a ser a etapa transversal, não é nome de produto |
| 3 | Entrada do conselheiro | na Conexão de Valor, conduzindo até a Parceria de Crescimento |
| 4 | Registro da entrega | BRM de Valor, cobrindo conselho dedicado, compartilhado e todos os programas |
| 5 | Foco | Felix Empresarial primeiro, white label depois, como entregável do Negócios de Valor |

Assumidas como padrão, revisáveis a qualquer momento:

| Nº | Decisão | Padrão adotado |
|---|---|---|
| 6 | Backend | Supabase, região São Paulo; Locaweb só DNS |
| 7 | Domínio | `valor.felixempresarial.com.br`, com `/parceiros` e `/conselho` |
| 8 | Repositório | privado novo, chamado `valor-plataforma` |
| 9 | Fases 0 e 8 | Base de Leads e Arquivo |
| 10 | Forecast oficial | por artefato; probabilidade manual fica como campo informativo |
| 11 | Margem para o comercial interno | não vê, liberável por perfil |
| 12 | Comissão | percentual sobre o valor da parcela, apurado no recebimento, pelo prazo do contrato |
| 13 | Aprovação de oportunidade de parceiro | Hamilton Felix aprova, prazo de 5 dias úteis |
| 14 | Conselheiro associado | perfil interno da casa, com contrato próprio e remuneração registrada; o parceiro indicador continua no PRM |
| 15 | Turmas compartilhadas | participante é contato ligado à conta dele; o contrato é por participante na turma compartilhada e por turma na dedicada |
| 16 | Assessor executivo | vê só as contas atribuídas; o conselheiro aprova a ata antes do envio |
| 17 | Portal do cliente | segunda versão |
| 18 | White label na prática | a Felix hospeda e cobra assinatura; a marca na tela é do cliente, com assinatura "Powered by Negócios de Valor · Felix Empresarial" |
| 19 | NPS | trimestral, instrumento da casa, link por e-mail e WhatsApp |
| 20 | Ata | padrão de sete seções como oficial, governança grade de 16 blocos como extensão |
| 21 | Transcrições | leitura automática das pastas do Drive, com fila de triagem |
| 22 | Integrações | Calendar e Meet, Drive, Gmail, assinatura eletrônica, WhatsApp, ClickUp, Obsidian |
| 23 | Idiomas | português, com inglês preparado para white label |
| 24 | Celular | PWA responsivo instalável |
| 25 | IA | Claude via API da Anthropic, teto inicial de 50 dólares por mês |
| 26 | Rota pública | sim, como toggle por negócio, na versão 1 |
| 27 | Linha do logo | ORIGEM, até decisão em contrário |
| 28 | Planilhas | congeladas na data da migração |

---

## 15. Plano de entrega

| Nº | Entrega | Conteúdo | Critério de aceite |
|---|---|---|---|
| 1 | Núcleo do CRM de Valor | inquilino, autenticação com múltiplo fator e conta de emergência, perfis, contas, contatos, negócios, papéis por negócio, funil de 0 a 8 com campos obrigatórios, artefatos, kanban, atividades GTD, painel comercial com os quatro invariantes, cobertura e forecast por artefato, importação das duas planilhas, identidade Felix, exportador de configuração | Hamilton Felix opera o pipeline real por uma semana sem abrir a planilha |
| 2 | BRM de Valor | Programa, Turma, Encontro, Participante, Entregável; reuniões de conselho, pautas pré-prontas, atas no padrão de sete seções, deliberações, pendências, transcrições do Drive, NPS, Histórico de Valor, painel do conselheiro e painel de turmas | uma reunião real de conselho e um encontro real de turma registrados de ponta a ponta, com ata gerada |
| 3 | Carteira e dinheiro | contratos nos três níveis, parcelas e calendário de faturamento, comissões, alertas de vencimento e renovação, Parceria de Crescimento automática, Arquivo, painel do dono e financeiro, exportação e impressão | o financeiro fecha um mês dentro do sistema |
| 4 | PRM de Valor | perfil de parceiro, registro e aprovação de oportunidade, score, comissão visível, materiais e treinamentos | um parceiro real registra e acompanha uma oportunidade |
| 5 | IA | os botões da seção 7, dossiê de reunião, busca semântica, higiene automática, resumo de segunda-feira | cada botão testado com uma conta real, com custo medido |
| 6 | White label e integrações | pacote de configuração exportável e importável, marca por inquilino, campos e listas configuráveis, Calendar, Drive, Gmail, assinatura eletrônica, exportação para o cofre | um segundo inquilino criado por importação de pacote, sem nenhum dado da Felix |

---

## 16. Próximo passo

O prompt mestre está pronto em `PROMPT-MESTRE.md`, versão 1.0, com as decisões desta seção 14 já embutidas. Basta abrir uma sessão nova, colar o prompt e acompanhar a Entrega 1. Qualquer decisão da tabela de padrões pode ser trocada antes ou durante a construção, sem refazer o desenho.
