# Gestão Contínua · CRM e PRM da Felix Empresarial

Documento de preparação. Nada foi construído ainda. Ele registra o que foi entendido do pedido, o que foi encontrado no segundo cérebro, a arquitetura recomendada, o desenho do produto fase a fase, as decisões que dependem de Hamilton Felix e o rascunho do prompt mestre que vai disparar a construção.

Versão 0.1 · 18/09/2026 · Preparado para aprovação e iteração.

Regra deste documento: nenhum valor de contrato, comissão, telefone, e-mail ou avaliação de pessoa entra aqui. O repositório onde ele vive é público. Tudo que é confidencial fica no Google Drive e nas planilhas de origem, e será carregado no CRM em ambiente privado.

---

## 1. O que eu entendi do pedido

Hamilton Felix quer um CRM completo, 100% na nuvem, construído de forma autônoma, que seja a materialização da etapa 8 da metodologia Negócios de Valor. O nome da etapa vira o nome do sistema: **Gestão Contínua**.

O que ele precisa, em uma lista fechada:

1. **As fases do CRM são as sete etapas sequenciais do método**, mais uma fase antes (os leads, antes da Seleção Estratégica) e uma fase depois (o arquivo, depois da Renovação de Valor: contratos concluídos, vencidos, cancelados e negócios perdidos). A Gestão Contínua não é fase: é o sistema inteiro.
2. **Contas com muitas pessoas**, cada uma com cargo, papel e situação. Uma conta gera muitos negócios, em paralelo.
3. **IA em cada fase**, como um botão ao lado do campo, que sugere e preenche. O usuário escolhe manual ou assistido.
4. **Dois mundos no mesmo login: CRM e PRM.** O parceiro entra, vê as oportunidades dele, o que foi aprovado, o que vence, o financeiro dele. Nunca vê margem, comissão de vendedor interno ou qualquer informação confidencial da Felix.
5. **Portfólio da Felix como catálogo**: Conselho de Valor (dedicado, compartilhado, recorrente), Negócios de Valor, Liderança de Valor, Gestão de Valor, Mentoria de Valor, e os demais formatos que a casa vende.
6. **Prazos e alertas em tudo**: validade de proposta, data de decisão, follow-up, vencimento e renovação de contrato, NPS periódico.
7. **Kanban tradicional mais atividades**: reuniões, calls, tarefas, com uma visão GTD (Getting Things Done) para não perder nada.
8. **Um grande painel, o "campo de Marte"**: visão do dono, do vendedor, do parceiro, dos alertas, das atividades pendentes, do pipeline e forecast, dos contratos em andamento.
9. **Origem e qualificação do lead**: origem, evento, tier 1, 2 e 3, probabilidade alta, média e baixa, com ou sem parceiro, com ou sem vendedor, interno ou externo, histórico de atividades, convite para eventos, campanhas.
10. **Contrato como entidade de verdade**: assinado ou não, modalidade, com ou sem equity, com ou sem participação no resultado, comissionamento, vínculo entre um cliente que também é fornecedor ou parceiro (Hamilton no conselho de uma empresa pode gerar negócios por ela).
11. **Duas visões de trabalho**: o que é da Felix e os projetos que a Felix executa para os clientes.
12. **Hospedagem**: hoje a Felix usa Locaweb. Ele precisa saber se dá para ficar lá, se precisa de contrato de banco de dados ou de outra plataforma. A única regra inegociável: não perder dados.
13. **Padrão de escrita, campos obrigatórios, automações e campos altamente customizáveis.**
14. **Consultas flexíveis nos painéis, impressão e exportação em PDF.**
15. **Edição amigável, melhores práticas atuais de CRM e o que há de mais inovador em IA aplicada a CRM.**
16. **Módulo de Conselho**: pautas pré-prontas a partir dos temas do método, registro das atas no padrão novo criado pelo Leandro, registro de pendências, transcrições das reuniões (automáticas ou lidas de uma pasta), NPS periódico com última nota e motivações por pessoa, alerta bimestral ou trimestral de avaliação da conta.
17. **Identidade visual da Felix**, com visualizações muito bem cuidadas.
18. **White label**: estruturar para a Felix hoje, com toda a complexidade da casa, e poder levar para um cliente depois.
19. **Permissionamento** por administrador geral, líder de área, comercial, gerente de conta e parceiro externo, com os cuidados de confidencialidade.
20. **Login e senha bem protegidos, com um usuário de administração e um de emergência**, guardado fisicamente em envelope.
21. **Propostas e contratos**: campos para contratos, disparo ou guarda de propostas a partir do negócio, registro do que foi negociado.
22. **A planilha atual não pode ser perdida**: os dados de pipeline e forecast que ele gerencia hoje entram, com liberdade para renomear e corrigir.

O pedido explícito desta rodada: **não executar**. Devolver entendimento, sugestões e perguntas, para ele aprovar e ajustar.

---

## 2. O que encontrei no segundo cérebro

Fontes lidas nesta rodada, todas no Google Drive, no Notion e no site institucional. O cofre Obsidian está espelhado no Drive e foi a fonte principal.

### 2.1 A metodologia, em forma final

Site felixempresarial.com.br e notas do cofre confirmam o cânone: oito etapas, sete sequenciais e uma transversal, cada uma com um artefato.

| Nº | Etapa | Artefato | Critério de saída sugerido pelo próprio método |
|---|---|---|---|
| 1 | Seleção Estratégica | Plano de Conta | conta escolhida, hipótese escrita, primeira reunião marcada |
| 2 | Exploração Profunda | Plano de Negócio | dores, objetivos e critérios de sucesso validados pelo cliente por escrito |
| 3 | Conexão de Valor | Plano de Trabalho | plano co-construído com o cliente, sem preço, com um número que veio dele |
| 4 | Confirmação de Compromisso | Contrato de Valor | contrato negociado com plano mútuo editado pelo cliente, depois assinado |
| 5 | Execução de Excelência | Entrega do Valor | kick-off interno e externo realizados, papéis e prazos definidos |
| 6 | Cultivo de Valor | Monitoria do Valor | reuniões periódicas com indicadores, crises tratadas, valor percebido registrado |
| 7 | Parceria de Crescimento | Renovação do Valor | proposta de crescimento ou renovação antecipada |
| 8 | Gestão Contínua (transversal) | Gestão no CRM e IA | o sistema que registra e audita as sete anteriores |

Vocabulário próprio do método, que o CRM precisa adotar na interface: oportunidade vira **negócio**, vender vira **realizar negócios de valor**, proposta vira **Plano de Trabalho**, pedido vira **Contrato de Valor**, vendedor vira **Gerente de Contas**, fechamento vira **Confirmação de Compromisso**, data de fechamento vira **data da decisão do cliente**.

Três papéis do método: Gerente de Contas, Pré-vendas e Gerente de Projetos. Uma conta gera muitos negócios: o Plano de Conta é da conta, o ciclo 2 a 7 roda por negócio.

O Plano de Conta já tem template de 8 blocos (Resumo Executivo, Resumo do Contrato Atual, Customer Success, Organograma Executivo, Relacionamento da Conta, Histórico da Conta, Notícias Relevantes, Hipótese para a Exploração Profunda). Esse template vira o formulário da fase 1.

### 2.2 A etapa 8 já tem teoria escrita pela casa

A ficha b16 do Negócios de Valor 2.00 ("Gestão contínua: pipeline, forecast, cadência e IA em vendas") e a Ferramenta 20 (Painel de Pipeline, já construída em HTML) definem o que o CRM tem de fazer nativamente:

- **Quatro invariantes de higiene**: todo estágio tem critério de saída verificável pelo cliente; todo negócio tem próximo passo com data e nome do lado do cliente; idade no estágio acima de duas vezes a mediana é alarme; data de decisão no passado é dívida, não pipeline.
- **Pipeline declarado e pipeline auditado**: o auditado tira quem está sem próximo passo ou com data vencida. A diferença é o número que abre a reunião.
- **Cobertura calculada, não regra de bolso**: cobertura necessária igual a 1 dividido pela taxa de vitória real, com o "sem decisão" no denominador. Alerta de concentração quando os dois maiores negócios passam de metade do pipeline.
- **Forecast por artefato, não por percentual**: Compromisso (Contrato de Valor em negociação com plano mútuo editado pelo cliente), Possível (Plano de Trabalho co-construído), Aberto (Plano de Negócio validado por escrito), Fora do número (nenhum artefato validado). Um negócio de um milhão não vale meio milhão: vale um milhão ou zero.
- **Dupla cadência**: revisão de pipeline olha negócios; revisão trimestral olha contas. Quatro rituais com uma unidade e uma pergunta cada: 1:1 semanal, pipeline review semanal ou quinzenal, deal review por gatilho, QBR trimestral.
- **Rota pública** (Lei 14.133): estágios com nome de fase administrativa (plano de contratações anual, ETP, edital, julgamento, homologação, contrato), desfechos próprios (suspenso, impugnado, deserto, fracassado) e forecast ancorado em cronograma público. Um CRM só com ganho e perdido mente sobre venda pública.
- **Régua de IA por etapa**: a IA tem evidência nas etapas 1 e 2 (prospecção, qualificação, descoberta) e na higiene do dado da etapa 8. Da etapa 3 em diante é assistente, não decisor. Tecnologia como colega de time, não como ferramenta: automatizar vira delegar e revisar.

### 2.3 O que a casa já construiu e que o CRM absorve

| Peça existente | Onde | O que vira no CRM |
|---|---|---|
| Painel de Pipeline (Ferramenta 20) | Negócios de Valor 2.00 | o motor de higiene, cobertura e forecast por artefato, agora sobre dados vivos |
| Análise de Oportunidade · Parceiros de Valor | ferramenta web de 03/09/2026 | o score de oportunidade do PRM (Momento 30, Acesso 20, Clareza 20, Sinais 15, Prontidão 15) e a recomendação de porta de entrada por programa |
| Avaliação do Meu Papel | ferramenta web de 04/09/2026 | opcional: autoavaliação dos três papéis dentro do módulo de equipe |
| Dossiê de Inteligência | app de 19/06/2026 | o briefing de conta gerado por IA antes de reunião, em 22 seções, sob protocolo OSINT ético e LGPD |
| Memória Executiva de Conselho e skills felix-ata | notas do cofre | a estrutura da ata e o gerador de PDF e DOCX |
| Ata de reunião de conselho no padrão de 04/09/2026 | Drive, pasta do cliente | o padrão de sete seções adotado pelo Leandro (ver 9.2) |
| Modelos de contrato de conselho | seis modelos de 08/06/2026 | os três níveis de contrato: N1 honorário, N2 honorário mais participação nos resultados, N3 honorário, participação e equity |
| Modelos de NPS, eNPS e NPS de revenda | material de um cliente de conselho, 2025 | o instrumento de avaliação periódica (pergunta clássica mais blocos de qualidade, atendimento, relacionamento, entrega, valor percebido, lealdade e inovação) |
| CRM do Sprint de Valor | Supabase mais Netlify, no ar em subdomínio próprio | a prova de que a arquitetura funciona no domínio da Felix: login por e-mail e senha, multiusuário, DNS na Locaweb |
| CRM de leads da mentoria | app local, 1.539 leads | base de leads a importar como segmento próprio |
| Template de resumo semanal (Highlights, Lowlights, Metas, Prioridades) | turma do Conselho de Valor | o ritual semanal de conta no módulo de conselho |
| 15 temas de governança e 6 famílias de gestão | metodo.html e Fundamentos do Conselho de Valor | o banco de pautas pré-prontas |

### 2.4 Os dados que existem hoje e que não podem ser perdidos

Duas planilhas na pasta EMPRESAS do Drive, mais a estrutura de pastas.

**FELIX - PRIORIDADES - 2026** (modificada em 09/09/2026): a planilha do funil de verdade. Blocos que importam:

- Contratos recorrentes: 27 linhas com empresa, executivo, serviço, periodicidade, contrato, início, fim, dia de cobrança, valor mensal, impostos, comissão, parceiro, líquido e observação. Vocabulário: serviço (conselho exclusivo, conselho de valor, CLT), periodicidade (semanal, quinzenal, diário), contrato (pendente, assinado, pausa).
- Pipeline: 127 linhas com empresa, prioridade (1 a 3), UF, cargo, nome, sobrenome, celular, estágio, serviço, valor mensal, meses, valor total, e-mail, parceiro e anotações. Funil de dez estágios numerados: 0 perdido, 1 lead, 1 retomar, 2 qualificação, 3 mostrar valor, 4 POC, 5 proposta técnica, 6 proposta comercial, 7 negociação, 8 contrato, 9 ganho. Serviços: conselho recorrente, consultoria pontual, modelo resultado, NEXT C-LEVEL, C-level as a service, mentoria recorrente e pontual, consultoria recorrente, treinamento pontual e recorrente, equity. Cargos: CEO e sócio, CSO, sócio, RH, outro.
- Cadastro de parceiros: 25 linhas com nome, UF, serviços, contato, LinkedIn, autorização para aparecer no site, contrato e anotações.
- Oportunidades trazidas por parceiro: parceiro, sócio, portfólio, cliente, executivo, contato, status, próximos passos, data estimada, projeto estimado, percentual de comissão, comissão estimada, comissão do parceiro, comissão líquida.
- Contratos pontuais: 13 linhas, 11 encerradas.
- Checklist de qualificação em cinco perguntas: Necessidade, Interesse, Competência, Horizonte, Originalidade.
- Blocos que não são do CRM e ficam fora: domínios, ideias, frases, missão, cursos, contatos de igreja e afins.

**CONTRATOS E PIPELINE - FELIX** (modificada em 17/09/2026): a planilha do contrato e do dinheiro.

- Carteira de contratos: 43 linhas com empresa, executivo, celular, e-mail, parceiro, serviço, contrato, multa, status, horas, valor, início, término, meses, data de faturamento, status de cobrança e observações. Vocabulário: contrato (assinado, pendente, cancelado), status comercial (ativo, prospectar, proposta, cancelado, recovery, contrato, follow-up, futuro), serviço (conselho, gestão de canais, consultoria de RH, diretor comercial, mentoria de CTO, canais ou relações com investidores, mentoria).
- Comissionamento por parceiro: parceiro, contato do parceiro, cliente, contato do cliente, oportunidade, valor do negócio, percentual, comissão e data.
- Calendários de faturamento e recebimento por cliente e por mês, de dezembro de 2023 a 2026, com impostos, comissão e líquido.
- Agenda semanal de reuniões recorrentes.

**Estrutura de pastas no Drive**: 18 contratos ativos, 71 pastas de prospect em pipeline, 24 contratos antigos, 4 empreendimentos próprios. Os clientes recentes seguem o padrão CLIENTE (contrato e plano de trabalho), REUNIÕES (uma pasta por data) e HISTÓRICO DE VALOR (a prova de valor entregue, hoje vazia em cinco clientes). Esse padrão vira a estrutura de documentos por conta no CRM.

**Reuniões gravadas**: 290 arquivos em Meet Recordings e mais 24 em Google Meet, com 95 documentos de anotações do Gemini. Padrão de nome: título do evento, data e hora, "Anotações do Gemini". É a fonte de transcrição que o CRM pode ler.

**O cofre**: 28 páginas de cliente, 92 notas de reunião, 58 fichas de pessoa. Serve para pré-preencher as contas com histórico.

### 2.5 Identidade visual e padrão de escrita

- Paleta medida em 17/09/2026: vinho do logo e dos títulos `#5E1E3A`, vinho profundo de fundo `#490B2C`, dourado `#EFB810`, dourado claro `#F9DB5C`, tinta `#1D1D1B`, cinza `#707070`. Regra de contraste: em fundo claro o dourado é elemento gráfico, não texto; para texto sobre branco, dourado profundo `#C2900A`. Cores de alarme já usadas nas ferramentas: verde `#2E7D4F`, amarelo `#C58A00`, vermelho `#B3261E`.
- Fontes: Oswald para títulos, condensada e em caixa alta; Montserrat para o corpo.
- Logo: nunca digitar o nome como texto, sempre o arquivo de lockup. Bordô em fundo claro, branco em fundo escuro. O símbolo é bússola mais relógio.
- Escrita: português do Brasil com acentuação correta, nunca travessão nem meia-risca, ponto médio "·" como separador em rótulos, intervalos escritos com "a". Texto justificado vale para documentos impressos, nunca para telas.
- Duas linhas de logo no Brand Kit 2.0 (ORIGEM e MERIDIANO) ainda sem escolha. O CRM precisa da decisão antes do design final.

### 2.6 Hospedagem: o que existe

- Conta corporativa na Locaweb, plano Hospedagem I por domínio, contratado em 08/2023. É hospedagem compartilhada: PHP 8, FTP, deploy por arrastar pasta para `public_html`, `.htaccess`, SSL. Inclui bancos MySQL e PostgreSQL pequenos, segundo o material público da Locaweb, mas não roda Node.js, funções serverless, autenticação gerenciada, armazenamento de arquivos com controle de acesso, nem agendador confiável.
- O DNS de felixempresarial.com.br está na Locaweb. Já existe o precedente do CRM do Sprint: subdomínio apontado por CNAME para a Netlify, banco e login no Supabase, SSL válido. Funcionou.
- Certificado do domínio principal vence em 31/12/2026.

---

## 3. Arquitetura recomendada

### 3.1 A resposta sobre a Locaweb

Não é preciso contratar nada novo na Locaweb, e também não recomendo construir o CRM dentro dela. A hospedagem compartilhada serve para site estático e páginas PHP simples. Um CRM com login, perfis, dados confidenciais, arquivos, IA e alertas agendados precisa de banco relacional com segurança por linha, autenticação com MFA, armazenamento privado e funções de servidor. Fazer isso em PHP sobre a Locaweb é possível, mas seria construir do zero o que uma plataforma já entrega pronta, com mais risco e mais custo de manutenção.

**Recomendação: Supabase como backend, front-end estático publicado no domínio da Felix.** É a mesma arquitetura do CRM do Sprint, que já está no ar.

| Camada | Escolha | Por quê |
|---|---|---|
| Banco, autenticação, armazenamento, funções | Supabase (PostgreSQL gerenciado), região São Paulo | segurança por linha (RLS) nativa, MFA, backups diários no plano Pro, funções serverless para IA e integrações, agendador (pg_cron), dados no Brasil |
| Front-end | aplicação web estática (React, TypeScript, Vite), instalável como PWA no celular | roda em qualquer hospedagem, inclusive no `public_html` da Locaweb ou na Netlify, sem servidor próprio |
| IA | API da Anthropic (Claude), chamada só por funções de servidor, nunca do navegador | a chave fica no servidor, o custo é controlado, cada chamada é registrada |
| Domínio | `crm.felixempresarial.com.br` para o CRM, com a entrada `/parceiros` para o PRM | um login, duas experiências; o DNS continua na Locaweb |
| Código | repositório privado novo no GitHub | o repositório atual é público e não pode receber schema, seeds ou nada da carteira |
| Documentos e anexos | Supabase Storage com URLs assinadas, mais link para a pasta do cliente no Drive | o Drive continua sendo o acervo; o CRM guarda o que precisa e aponta para o resto |

**Custo estimado** (a confirmar com os preços vigentes no dia da contratação):

| Item | Plano | Custo mensal | Quando |
|---|---|---|---|
| Supabase | Free | 0 | construção e piloto. Limite: 500 MB de banco, projeto pausa após 7 dias sem uso, sem backup |
| Supabase | Pro | 25 dólares | ao entrar em produção. 8 GB de banco, 100 GB de arquivos, backups diários guardados por 7 dias, nunca pausa |
| API Anthropic | por uso | estimativa de 20 a 100 dólares conforme o volume de transcrições e dossiês | desde o piloto |
| Netlify ou Vercel | Free | 0 | só se a publicação não for no `public_html` da Locaweb |
| Locaweb | já contratado | sem mudança | DNS e, se quiser, publicação estática |

"Não perder dados" fica garantido por quatro camadas: backups diários da plataforma, exportação semanal automática para uma pasta do Drive (CSV e JSON), arquivamento em vez de exclusão em toda entidade (nada se apaga, tudo se arquiva) e trilha de auditoria imutável de quem alterou o quê.

### 3.2 Um login, duas experiências

Recomendo **uma única aplicação** com perfis, e não dois sistemas. O parceiro entra por `crm.felixempresarial.com.br/parceiros` (ou pelo mesmo endereço), e o perfil dele decide o que aparece: menu, campos, painéis e relatórios. Dois sistemas separados duplicariam dados, e o problema declarado é justamente não perder nem desencontrar dados.

A separação de confidencialidade não fica na tela: fica no banco, por política de acesso por linha e por coluna. O parceiro não vê margem porque a consulta dele não retorna margem, e não porque a tela esconde.

### 3.3 White label desde o primeiro dia

O sistema nasce multi-inquilino (multi-tenant): a Felix é o primeiro inquilino. Cada inquilino tem marca (logo, cores, fontes, nome do produto), catálogo de portfólio, campos customizados, listas de valores, regras de alerta, templates de documentos e módulos ligados ou desligados (Conselho, PRM, rota pública). Os nomes das oito etapas são configuráveis por inquilino, mas a edição Felix mantém o cânone.

Nome do produto sugerido: **Gestão Contínua**. Subtítulo: CRM e PRM do Negócio de Valor. Para outro cliente, o nome e a marca trocam por configuração.

---

## 4. O desenho do produto: fases

### 4.1 O funil, fase a fase

| Fase | Nome na tela | O que entra | Campos obrigatórios para avançar |
|---|---|---|---|
| 0 | Base de Leads | toda origem: evento, indicação, base fria, formulário do site, rede, campanha. Sub-status: novo, em nutrição, retomar, descartado | empresa ou pessoa, origem, quem trouxe (interno ou parceiro), segmento provável |
| 1 | Seleção Estratégica | a conta escolhida, com Plano de Conta iniciado | CNPJ ou site, segmento, UF, dono da conta, tier (1, 2 ou 3), prioridade (1 a 3), hipótese de valor, ao menos um contato decisor ou porta de entrada |
| 2 | Exploração Profunda | o negócio nasce aqui, dentro da conta | Plano de Negócio com dores, objetivos e critérios de sucesso; evidência de validação pelo cliente (e-mail, ata ou anotação de reunião); próximo passo com data e nome do lado do cliente |
| 3 | Conexão de Valor | Plano de Trabalho co-construído, POC ou demonstração quando houver | oferta do portfólio, modalidade, valor estimado, um número que veio do cliente, data da reunião de valor realizada |
| 4 | Confirmação de Compromisso | proposta comercial, negociação, minuta, assinatura | Plano de Trabalho validado, valor mensal e meses (ou valor fechado), validade da proposta, data prevista da decisão do cliente, objeções registradas, nível de contrato (N1, N2, N3) |
| 5 | Execução de Excelência | contrato assinado, kick-off interno e externo | arquivo do contrato assinado, datas de início e fim, dia de faturamento, periodicidade e horário da cadência, responsáveis, pasta do cliente criada |
| 6 | Cultivo de Valor | a carteira ativa: reuniões, indicadores, NPS, crises, Histórico de Valor | cadência em dia, NPS agendado, ao menos um registro no Histórico de Valor a cada trimestre |
| 7 | Parceria de Crescimento | renovação, upsell, cross-sell; entra automaticamente a X dias do fim do contrato | proposta de crescimento ou de renovação, resultado (renovado, expandido, encerrado) |
| 8 | Arquivo | concluídos, vencidos, cancelados, perdidos, sem decisão, suspensos (rota pública) | motivo com vocabulário fechado, concorrente quando houver, lição aprendida, data |

O que sai do funil pode voltar: um arquivado vira lead de novo (retomar) com o histórico preservado.

### 4.2 Como o funil de hoje entra no novo

| Estágio atual na planilha | Fase nova | Sub-status sugerido |
|---|---|---|
| 1 - LEAD | 0 Base de Leads | novo |
| 1 - RETOMAR | 0 Base de Leads | retomar |
| 2 - QUALIFICAÇÃO | 1 Seleção Estratégica ou 2 Exploração Profunda | decide-se por conta: se há Plano de Conta, vai para 2 |
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
| Contratos pontuais encerrados e contratos antigos | 8 Arquivo | concluído |

A importação mostra esse mapeamento linha a linha antes de gravar, e tudo que não bater fica numa fila "a confirmar" para Hamilton decidir.

### 4.3 Duas camadas: conta e negócio

- **Conta** vive enquanto a conta existir. Tem Plano de Conta, contatos, contratos, histórico, tier, dono, parceiro que indicou, aniversário de contrato, e pode ser ao mesmo tempo cliente, parceiro, fornecedor, canal ou empreendimento próprio (campos de relação múltipla).
- **Negócio** roda o ciclo 2 a 7, um por oferta, vários em paralelo na mesma conta. Tem etapa, artefatos, valor, forecast, próximo passo, prazos e o contrato que nasce dele.
- **Contrato** é entidade própria, ligada ao negócio e à conta: é o que está em Cultivo de Valor e o que dispara Parceria de Crescimento.

### 4.4 Rota pública

Toggle por negócio: "cliente é Administração Pública". Ao ligar, as fases 1 a 4 ganham sub-status com nome de fase administrativa (plano de contratações anual, ETP, edital, julgamento, homologação, contrato), o campo de data de decisão passa a ser derivado do cronograma público, e o arquivo ganha os desfechos suspenso, impugnado, deserto e fracassado. Campo para o identificador no PNCP.

---

## 5. Modelo de dados

Entidades principais e os campos que não podem faltar. Tudo é extensível por campos customizados (texto, número, data, lista, múltipla escolha, moeda, percentual, arquivo, pessoa, conta), com marcação de obrigatório por fase e de confidencial.

| Entidade | Campos essenciais | Confidenciais (nunca no PRM) |
|---|---|---|
| Inquilino (tenant) | nome, marca, domínio, módulos, catálogo, regras | |
| Usuário e perfil | nome, e-mail, perfil, MFA, contas atribuídas, parceiro vinculado | |
| Conta | razão social, nome fantasia, CNPJ, site, LinkedIn, UF, cidade, segmento, faixa de faturamento, faixa de funcionários, tipo de relação (cliente, prospect, parceiro, fornecedor, canal, empreendimento), tier, prioridade, dono, parceiro indicador, origem, Plano de Conta (8 blocos), Power of X (linhas do portfólio compradas), aniversário do contrato, pasta no Drive, tags | notas internas, avaliação de risco |
| Contato (pessoa) | nome, sobrenome, cargo, papel na conta (decisor, patrocinador, influenciador, usuário, financeiro, jurídico, assessor), e-mail, celular, LinkedIn, quem conecta a ele, aniversário, situação (ativo, saiu da empresa), consentimento LGPD, perfil comportamental (opcional) | avaliações qualitativas |
| Negócio | título, conta, oferta do portfólio, modalidade (recorrente ou pontual), fase e sub-status, valor mensal, meses, valor total, origem, quem vende (interno ou parceiro), tier e probabilidade manual (alta, média, baixa), forecast por artefato (calculado), próximo passo, data do próximo passo, nome do lado do cliente, data prevista da decisão, validade da proposta, última interação, dias parado, rota pública, motivo de perda | margem, comissão interna, custo de entrega |
| Artefato | tipo (Plano de Conta, Plano de Negócio, Plano de Trabalho, Contrato de Valor, Entrega, Monitoria, Renovação), status (não existe, existe não validado, validado com o cliente), evidência, arquivo, versão | |
| Proposta | negócio, versão, valor, condições, validade, enviada em, aceita ou recusada em, arquivo, template usado | |
| Contrato | conta, negócio, tipo de serviço, nível (N1, N2, N3), status (minuta, pendente, assinado, em pausa, encerrado, cancelado, vencido), início, fim, meses, renovação automática, aviso prévio, multa, valor mensal, reajuste (IPCA), dia de faturamento, periodicidade e horário das reuniões, horas por semana, assinatura eletrônica (id), arquivo, alerta de renovação, periodicidade de NPS | impostos, comissão e parceiro, líquido, base e percentual de participação, condições de equity (phantom shares, cliff, good e bad leaver) |
| Parcela (faturamento e recebimento) | contrato, competência, vencimento, valor, nota fiscal, status (a faturar, faturado, pago, atrasado), pago em | comissão a pagar na parcela |
| Comissão | parceiro, negócio, contrato, parcela, percentual, valor, status (prevista, apurada, paga), data | percentual e valor são visíveis ao parceiro dono; nunca a outro parceiro |
| Parceiro (PRM) | pessoa ou empresa, tipo (indicador, canal, consultor associado, conselheiro do banco), UF, serviços que vende, contrato de parceria, autorizou aparecer no site, treinamentos concluídos, materiais liberados | |
| Atividade (GTD) | tipo (reunião, call, e-mail, WhatsApp, tarefa, visita, evento, follow-up), assunto, conta, negócio, contato, responsável, data e hora, duração, status (inbox, próxima ação, agendada, aguardando, algum dia ou talvez, concluída, cancelada), resultado, próxima ação gerada, link do Calendar ou Meet, delegado a | |
| Reunião de conselho | conta, contrato, data, participantes (presentes, ausentes, convidados), pauta (itens com tema, tipo deliberativo ou informativo ou consultivo, responsável), resumo das discussões, deliberações, próximos passos, próxima reunião e pré-pauta, transcrição, gravação, ata gerada (PDF e DOCX), aprovação da ata anterior | conteúdo sobre pessoas do cliente fica marcado como restrito |
| Pendência (deliberação) | origem (reunião), descrição, responsável (pessoa do cliente ou da Felix), prazo, status (em andamento, concluída, atrasada, cancelada), reaparece na próxima pauta até fechar | |
| Avaliação (NPS) | conta, contrato, período, respondente, nota 0 a 10, motivações, blocos (qualidade, atendimento, relacionamento, entrega, valor percebido, lealdade, inovação), nota do conselheiro, status (agendada, enviada, respondida), tendência | |
| Histórico de Valor | conta, data, entregável, valor gerado (descrição e número quando houver), evidência, arquivo | |
| Evento e campanha | nome, data, tipo, convidados (contas e contatos), status por convidado (convidado, confirmado, presente), leads gerados | |
| Documento | vinculado a conta, negócio, contrato ou reunião; tipo; versão; arquivo ou link do Drive | |
| Transcrição | fonte (anotações do Gemini, upload, gravação), texto, reunião, processamento (resumo, decisões, pendências, sinais de risco e de oportunidade) | texto bruto é restrito |
| Auditoria | quem, o quê, antes e depois, quando; imutável | |

---

## 6. Perfis e permissões

| Perfil | Quem | Vê | Não vê |
|---|---|---|---|
| Administrador geral | Hamilton | tudo, inclusive configuração, segurança e faturamento | |
| Administrador de emergência | conta reserva, credencial em envelope lacrado, MFA de recuperação impressa | tudo | só é usada se a principal falhar; qualquer uso gera alerta por e-mail |
| Líder de área ou sócio | direção | tudo do inquilino, exceto segurança | configuração de segurança |
| Financeiro | quem cuida do faturamento | contratos, parcelas, comissões, calendários, relatórios financeiros | pipeline e conselho, salvo se atribuído |
| Comercial (Gerente de Contas ou de Negócios) | quem vende | suas contas e negócios, atividades, forecast do seu funil, comissão própria | margem (configurável), comissão de terceiros, financeiro consolidado |
| Gerente de conta ou conselheiro (entrega) | quem atende a carteira | contas atribuídas, módulo de conselho, atas, pendências, NPS, Histórico de Valor | valores de contrato (configurável) |
| Assessor executivo | quem opera a agenda e as atas | agenda, atas, pendências, transcrições das contas atribuídas | financeiro |
| Parceiro externo (PRM) | quem indica ou revende | só as contas e negócios que ele trouxe: status, aprovação, próximos passos, vencimento, sua comissão prevista e paga, materiais públicos, seu treinamento, seu score de oportunidade | margem, comissão de qualquer outra pessoa, valores internos, atas de conselho, outros parceiros, financeiro da Felix |
| Cliente (fase 2, portal) | sócio do cliente de conselho | atas aprovadas, pendências dele, pesquisa de NPS, Histórico de Valor da conta | tudo o mais |
| Leitura | contador, auditor | relatórios definidos | edição |

Campos marcados como confidenciais ficam fora das consultas dos perfis sem direito, por política no banco. Toda exportação e impressão respeita o mesmo filtro.

---

## 7. IA em cada fase

Princípios: a IA sugere e preenche em rascunho, o humano confirma; todo texto gerado fica marcado como rascunho até a confirmação; nada é enviado ao cliente ou publicado sem revisão; cada chamada é registrada com custo; dados sensíveis não saem do banco sem necessidade.

| Fase | Botão de IA | O que faz | Base de evidência |
|---|---|---|---|
| 0 Leads | Enriquecer | a partir de CNPJ, site e LinkedIn colado: razão social, porte, CNAE, segmento, notícias recentes, sinais de momento; deduplica contra a base | forte (prospecção e qualificação) |
| 0 Leads | Pontuar | score de oportunidade com o motor da Análise de Oportunidade e recomendação de porta de entrada por programa | forte |
| 1 Seleção Estratégica | Rascunhar Plano de Conta | preenche os 8 blocos com o que se sabe e marca lacunas; gera três hipóteses de valor e a frase de abertura | forte |
| 1 | Dossiê de reunião | briefing executivo de 22 seções antes da primeira reunião, sob protocolo OSINT ético e LGPD | forte |
| 2 Exploração Profunda | Preparar perguntas | roteiro de perguntas da descoberta, no espírito do "O Psicanalista": não aceitar a queixa manifesta como necessidade | assistente |
| 2 | Transcrição vira Plano de Negócio | lê a anotação do Gemini ou a transcrição e monta dores, objetivos, critérios de sucesso, riscos e concorrência; aponta o que ainda precisa ser validado por escrito | forte na extração, humano valida |
| 3 Conexão de Valor | Rascunhar Plano de Trabalho | converte o Plano de Negócio em plano: objetivos do cliente, abordagem, benefícios, casos, próximos passos, sem preço | assistente |
| 4 Confirmação de Compromisso | Gerar proposta e minuta | monta a proposta e a minuta do Contrato de Valor a partir dos templates N1, N2 e N3 com as variáveis do negócio; lista objeções prováveis e respostas | assistente |
| 5 Execução de Excelência | Kick-off | gera a pauta e a ata do kick-off interno e externo; cria as atividades e a pasta do cliente | assistente |
| 6 Cultivo de Valor | Ata e pendências | transforma a transcrição na ata do padrão da casa, extrai decisões, responsáveis, prazos e o Insight do Conselho; sugere a pré-pauta seguinte | forte na extração |
| 6 | Ler o NPS | agrupa as motivações em temas, sinaliza risco de perda e valor percebido | assistente |
| 6 | Sugerir pauta | propõe pautas a partir dos 15 temas de governança, das pendências abertas e do cronograma temático anual | assistente |
| 7 Parceria de Crescimento | Proposta de crescimento | resume o Histórico de Valor e propõe renovação, upsell ou cross-sell com o argumento pronto | assistente |
| 8 Gestão Contínua | Higiene | lista o que saiu do pipeline auditado, sugere próximo passo para cada negócio parado, calcula cobertura e concentração, escreve "a leitura em uma frase para levar ao gestor" | forte (higiene do dado) |
| Transversal | Perguntar à carteira | busca semântica sobre contas, reuniões, atas e transcrições: "o que ficou pendente com este cliente?" | assistente |
| Transversal | Qualidade do dado | deduplica contatos, normaliza cargos e nomes, sinaliza campos obrigatórios vazios | forte |

O que a IA **não** faz: não decide probabilidade de negócio (isso é o artefato), não muda etapa sozinha, não envia mensagem ao cliente, não altera valores de contrato.

---

## 8. Painéis e consultas

Um painel principal por perfil e um construtor de consultas.

| Painel | Para quem | O que mostra |
|---|---|---|
| Mesa do Dono | Hamilton | receita recorrente ativa, contratos por status e por vencimento, pipeline auditado por fase, forecast por artefato, cobertura necessária contra real, NPS médio e tendência, alertas do dia, atividades vencidas da equipe, agenda da semana |
| Comercial | quem vende | kanban por fase, forecast por artefato, os quatro invariantes, cobertura e concentração, próximos passos vencidos, negócios parados, leads sem dono, taxa de conversão por transição |
| Carteira e Conselho | quem atende | reuniões da semana por cliente, pendências por cliente e por responsável, atas a enviar, NPS a aplicar, Histórico de Valor por conta, aniversários de contrato |
| Financeiro | financeiro | faturamento previsto e realizado por mês, parcelas a faturar e atrasadas, comissões apuradas e pagas, contratos a reajustar |
| Parceiro | PRM | seus leads e negócios por fase, o que está aprovado, o que espera aprovação, vencimentos, sua comissão prevista e paga, seu score de oportunidades, materiais e treinamentos |
| Eventos e campanhas | marketing e comercial | convidados por evento, presença, leads gerados por origem |
| Construtor de consultas | todos, no seu recorte | filtros por qualquer campo, agrupamento, colunas escolhidas, gráficos, visões salvas e compartilhadas, exportação em CSV e PDF, impressão em A4 com identidade |

Os gráficos seguem a identidade Felix e uma paleta de dados única, legível em tela e em impressão.

---

## 9. Módulo de Conselho

### 9.1 O que ele cobre

Agenda das reuniões por contrato (semanal, quinzenal, mensal presencial), pauta antecipada provocada no grupo do cliente, registro em ata, arquivamento na pasta compartilhada, revisão periódica das decisões, acompanhamento semanal dos compromissos e cronograma temático anual. Foi exatamente a prática aprovada com um cliente em 04/09/2026.

### 9.2 O padrão de ata adotado

A ata gerada pelo CRM segue as sete seções do padrão em uso desde setembro de 2026:

1. Identificação: data, horário, local ou formato.
2. Participantes: presentes, ausentes, convidados.
3. Pauta do dia: itens numerados com uma linha de contexto cada.
4. Resumo das discussões: um bloco por item, com os destaques em marcadores.
5. Deliberações: tabela com decisão, responsável, prazo e status.
6. Próximos passos: cada um com responsável e prazo.
7. Próxima reunião: data prevista e pré-pauta, seguida do encerramento.

A estrutura "governança grade" de 16 blocos das skills felix-ata (quórum, aprovação da ata anterior, acompanhamento das deliberações anteriores com status colorido, indicadores, riscos com severidade, Insight do Conselho, votação e conflitos de interesse, assinaturas) fica disponível como extensão opcional por cliente. Saída em PDF e DOCX com o sistema visual da Memória Executiva.

### 9.3 Pautas pré-prontas

Banco de pautas com os 15 temas de governança (saúde econômica e financeira, estratégia empresarial, modelo de negócio, gestão de riscos, cultura organizacional, mercado de atuação, relevância competitiva, estágio do negócio, propósito, valores e visão, competências de liderança, sucessão em cargos críticos, sustentabilidade, transformação digital e inovação, arquitetura da governança, relação com stakeholders) e as seis famílias de gestão (estratégia e governança, vendas e marketing, pessoas e cultura, gestão e financeiro, operações e logística, portfólio e inovação), cada uma com perguntas orientadoras e materiais de apoio. O cronograma temático anual de um cliente vira modelo reaproveitável.

### 9.4 Pendências que não morrem

Toda deliberação com responsável e prazo reaparece na pré-pauta seguinte até ser fechada. Atraso gera alerta ao responsável interno e aparece no painel de carteira. O ritual "esgotar a ata anterior antes de abrir assunto novo" fica embutido.

### 9.5 Transcrições

Três caminhos, escolhidos por decisão:

- Leitura automática das pastas Meet Recordings e Google Meet do Drive, identificando o cliente pelo título do evento e anexando as anotações do Gemini à reunião certa; o que não tiver cliente no título vai para uma fila de triagem.
- Upload manual da transcrição ou da gravação.
- Transcrição própria a partir do áudio (fase posterior).

O texto bruto fica restrito; as notas processadas seguem a regra do cofre: nada sobre pessoas do cliente sai do bruto.

### 9.6 NPS e avaliação da conta

Periodicidade por contrato (bimestral ou trimestral), instrumento com a pergunta clássica mais os blocos da casa, resposta por pessoa, nota do conselheiro (a avaliação de 0 a 10 que Hamilton já pede aos sócios), última nota e tendência na página da conta, alerta quando a avaliação vence e quando a nota cai.

### 9.7 Histórico de Valor

A pasta HISTÓRICO DE VALOR, hoje vazia em cinco clientes, vira registro obrigatório de Cultivo de Valor: o que foi entregue, com que resultado, com que evidência. É o insumo da Renovação.

---

## 10. Documentos, propostas e contratos

- Templates com variáveis: Plano de Conta, Plano de Negócio, Plano de Trabalho, proposta comercial, Contrato de Valor nos três níveis, kick-off, ata, pesquisa de NPS, proposta de crescimento.
- Geração em PDF e DOCX com identidade Felix (corpo justificado nos documentos, nunca em tela), versão numerada, guarda no negócio e no contrato, envio por e-mail a partir do sistema com registro da data.
- Assinatura eletrônica por integração (ZapSign ou DocuSign) com retorno do status para o contrato.
- Estrutura de pastas automática por conta, espelhando o padrão CLIENTE, REUNIÕES e HISTÓRICO DE VALOR, com link para a pasta do Drive.

---

## 11. Automações e alertas

| Gatilho | Ação |
|---|---|
| validade da proposta a 7 e a 1 dia | alerta ao dono e ao gerente |
| data prevista da decisão do cliente vencida | negócio sai do pipeline auditado e entra na lista de higiene |
| próximo passo vencido ou ausente | negócio marcado, alerta ao dono |
| negócio parado acima de duas vezes a mediana da fase (padrão inicial: 30 dias) | alarme de idade |
| contrato a 90, 60 e 30 dias do fim | negócio de renovação criado em Parceria de Crescimento |
| fim de contrato sem renovação | contrato vence e vai ao Arquivo com motivo |
| NPS vencido | pesquisa gerada e enviada, lembrete ao responsável |
| ata não gerada 24 horas depois da reunião | alerta ao assessor |
| pendência de conselho atrasada | alerta ao responsável interno e destaque na pré-pauta |
| lead sem dono há mais de 3 dias | alerta ao líder |
| oportunidade de parceiro aguardando aprovação há mais de X dias | alerta ao aprovador, visível ao parceiro |
| reunião criada no Google Calendar com conta identificada | atividade criada no CRM |
| anotação do Gemini nova no Drive | transcrição anexada à reunião ou enviada à triagem |
| toda segunda de manhã | resumo da semana por e-mail para cada perfil (o "brief" da carteira) |
| uso da conta de emergência | alerta imediato ao administrador |

Integrações previstas, em ordem de valor: Google Calendar e Meet, Google Drive, Gmail, assinatura eletrônica, WhatsApp (link direto no piloto, API oficial depois), ClickUp (opcional, um sentido: ação do CRM vira card), exportação para o cofre Obsidian (notas de cliente e de reunião no schema do cofre, sem valores).

---

## 12. Segurança e continuidade

- Autenticação com e-mail e senha forte, MFA obrigatório para administradores e financeiro, expiração de sessão, bloqueio por tentativas.
- Conta de emergência: criada no primeiro dia, credenciais impressas e guardadas em envelope físico com os códigos de recuperação de MFA; qualquer login dela dispara alerta.
- Política de acesso por linha e por coluna no banco, testada automaticamente a cada versão.
- Trilha de auditoria imutável; arquivamento em vez de exclusão; exportação semanal para o Drive; backups diários da plataforma; restauração ensaiada uma vez por trimestre.
- LGPD: campo de consentimento por contato, minimização (não se guarda o que não se usa), pedido de exclusão atendido por anonimização, dados hospedados no Brasil.
- Chaves de API só em funções de servidor; segredos fora do repositório.

---

## 13. Migração dos dados de hoje

Ordem de entrada, com assistente de importação que mostra a prévia e uma fila "a confirmar":

1. Catálogo de portfólio e listas de valores (origens, segmentos, motivos de arquivo, cargos, papéis).
2. Parceiros (25 linhas do cadastro).
3. Contas e contatos a partir das duas planilhas, com deduplicação por CNPJ e por nome.
4. Contratos recorrentes e pontuais, com parcelas geradas a partir do calendário de faturamento.
5. Pipeline (127 linhas) com o mapeamento de fases da seção 4.2.
6. Oportunidades trazidas por parceiro e comissões apuradas.
7. Pastas do Drive vinculadas às contas (18 ativas, 71 em pipeline, 24 antigas, 4 empreendimentos).
8. Histórico do cofre: páginas de cliente viram o resumo da conta; notas de reunião viram reuniões; fichas de pessoa viram contatos.
9. Anotações do Gemini das reuniões dos últimos doze meses anexadas às contas.
10. Base de leads da mentoria (1.539) e a base fria do Sprint como segmentos separados de Base de Leads, com a limpeza que já foi diagnosticada (duplicados, telefones ausentes).

Nada é gravado sem prévia. Valores que divergem entre as duas planilhas ficam marcados e a decisão é de Hamilton.

---

## 14. Decisões que dependem de Hamilton Felix

Para cada uma, a recomendação e o padrão que será adotado se não houver resposta.

| Nº | Decisão | Recomendação | Padrão se não responder |
|---|---|---|---|
| 1 | Nome do produto | "Gestão Contínua", subtítulo "CRM e PRM do Negócio de Valor" | Gestão Contínua |
| 2 | Backend e hospedagem | Supabase (região São Paulo) mais front-end estático; Locaweb só DNS e, se quiser, publicação estática | Supabase Free no piloto, Pro na produção |
| 3 | Domínio | `crm.felixempresarial.com.br` com `/parceiros` para o PRM, um login só | igual |
| 4 | Repositório | criar repositório privado novo; este é público e não recebe código do CRM | criar `gestao-continua` privado |
| 5 | Nomes das fases 0 e 8 | "Base de Leads" e "Arquivo" | igual |
| 6 | Mapeamento do funil atual | tabela da seção 4.2 | igual, com fila a confirmar |
| 7 | Forecast oficial | por artefato (Compromisso, Possível, Aberto, Fora do número); manter probabilidade manual (alta, média, baixa) como campo informativo | igual |
| 8 | O que o parceiro vê | tabela da seção 6 | igual |
| 9 | O comercial interno vê margem? | não, por padrão; liberar por perfil | não vê |
| 10 | Catálogo do portfólio e modalidades | lista da seção 2 e serviços das planilhas; preços configurados no app, nunca no repositório | importar do que existe |
| 11 | Regras de comissão | percentual sobre o bruto ou sobre o líquido, por parcela ou no fechamento, por quanto tempo, quem aprova | percentual sobre valor da parcela, apurado no recebimento |
| 12 | Aprovação de oportunidade de parceiro | quem aprova, prazo, o que "aprovada" significa (registrada com atribuição e comissão) | Hamilton aprova, prazo de 5 dias úteis |
| 13 | NPS | periodicidade padrão, instrumento, canal | trimestral, instrumento da casa, link por e-mail e WhatsApp |
| 14 | Ata | padrão de sete seções como oficial, 16 blocos como extensão | igual |
| 15 | Transcrições | leitura automática das pastas do Drive com fila de triagem | igual |
| 16 | Ordem das integrações | Calendar e Meet, Drive, Gmail, assinatura eletrônica, WhatsApp, ClickUp, Obsidian | igual |
| 17 | Usuários e perfis no lançamento | lista de pessoas e papéis | administrador, emergência, financeiro, assessor, comercial |
| 18 | Guarda da conta de emergência | envelope físico com códigos de recuperação | igual |
| 19 | Escopo da migração | tudo da seção 13 | tudo |
| 20 | Idiomas | português, com inglês preparado para white label | português |
| 21 | Celular | PWA responsivo instalável | igual |
| 22 | IA | Claude via API da Anthropic, teto mensal de gasto, o que pode ser enviado | teto inicial de 50 dólares por mês |
| 23 | Rota pública na versão 1 | sim, como toggle por negócio | sim |
| 24 | Portal do cliente | fase 2 | fase 2 |
| 25 | Linha do logo (ORIGEM ou MERIDIANO) | decidir antes do design final | ORIGEM |
| 26 | Regra sobre a planilha depois do CRM | congelar as planilhas na data da migração e passar a operar só no CRM | congelar |

---

## 15. Entregas propostas

| Entrega | Conteúdo | Critério de aceite |
|---|---|---|
| 1. Núcleo | tenant, autenticação com MFA e conta de emergência, perfis, contas, contatos, negócios, funil de 0 a 8 com campos obrigatórios, artefatos, kanban, atividades GTD, painel comercial com os quatro invariantes, cobertura e forecast por artefato, importação das duas planilhas, identidade Felix | Hamilton opera o pipeline real sem abrir a planilha por uma semana |
| 2. Carteira e dinheiro | contratos nos três níveis, parcelas e calendário de faturamento, comissões, alertas de vencimento e renovação, Parceria de Crescimento automática, Arquivo, painel do dono e financeiro, exportação e impressão | financeiro fecha um mês no CRM |
| 3. Conselho | reuniões, pautas pré-prontas, atas no padrão, pendências, transcrições do Drive, NPS, Histórico de Valor, painel de carteira | uma reunião real de conselho registrada de ponta a ponta com ata gerada |
| 4. PRM | perfil de parceiro, oportunidades com aprovação, score de oportunidade, comissão visível, materiais e treinamentos | um parceiro real registra e acompanha uma oportunidade |
| 5. IA | os botões da seção 7, dossiê de reunião, busca semântica, higiene automática, brief de segunda-feira | cada botão testado com uma conta real, com custo medido |
| 6. White label e integrações | marca por inquilino, campos e listas configuráveis, Calendar, Drive, Gmail, assinatura eletrônica, exportação para o cofre | um segundo inquilino de demonstração criado por configuração |

---

## 16. Prompt mestre · rascunho v0.1

O texto abaixo é o que será colado numa sessão nova para construir o sistema, depois das decisões da seção 14. As chaves entre colchetes são preenchidas com as respostas.

```
Você vai construir o "Gestão Contínua", CRM e PRM da Felix Empresarial, de forma
autônoma e completa, seguindo este documento de preparação como fonte de verdade:
crm-gestao-continua/ENTENDIMENTO-E-PROMPT-MESTRE.md.

PAPEL
Você é o arquiteto, o desenvolvedor e o responsável pela qualidade. Trabalha em
paralelo sempre que houver itens independentes. Antes de cada entrega grande,
apresenta o plano, espera o aval e só então executa. Registra decisões e
pendências num STATUS.md na raiz do projeto.

CONTEXTO A LER ANTES DE ESCREVER CÓDIGO
1. Este documento de preparação, inteiro.
2. No Google Drive de Hamilton Felix: a planilha "FELIX - PRIORIDADES - 2026" e
   a planilha "CONTRATOS E PIPELINE - FELIX", na pasta FELIX - EMPRESARIAL/EMPRESAS.
   Só a estrutura entra em código; os valores entram no banco privado.
3. No cofre Obsidian espelhado no Drive: as notas "Negócios de Valor",
   "Conselho de Valor", "Memória Executiva de Conselho", "Identidade visual FELIX",
   "Como trabalhar com o Hamilton", "Padrões editoriais dos documentos",
   "Pipeline comercial no Drive", "Carteira de clientes", "Contratos modelo de
   conselho", "Prospecção DF", "Hospedagem Locaweb", "Análise de Oportunidade",
   "Dossiê de Inteligência" e "Mapa do Google Drive".
4. A ficha "b16-cadencia-pipeline-forecast-ia.md" e a Ferramenta 20
   "20-painel-de-pipeline.html" do Negócios de Valor 2.00.
5. Uma ata de reunião de conselho no padrão de setembro de 2026 (sete seções).
6. O site felixempresarial.com.br: páginas metodo, negocios-de-valor e
   conselho-de-valor.
7. As páginas do Notion "Felix Empresarial / PROGRAMAS / NEGÓCIOS DE VALOR",
   fases 0 a 7.

REGRAS INEGOCIÁVEIS
- Português do Brasil com acentuação correta em tudo: interface, código de
  interface, documentação, mensagens. Nunca travessão nem meia-risca. Separador
  de rótulo é o ponto médio. Intervalos escritos com "a".
- Identidade Felix: vinho #5E1E3A para logo e títulos, vinho profundo #490B2C
  para fundos, dourado #EFB810 só como elemento gráfico em fundo claro e
  #C2900A como texto sobre branco, tinta #1D1D1B, cinza #707070; Oswald em
  títulos, Montserrat no corpo; logo sempre por arquivo, nunca digitado.
  Texto justificado só em PDF e DOCX, nunca em tela.
- Vocabulário do método na interface: negócio, Gerente de Contas, Plano de
  Trabalho, Contrato de Valor, Confirmação de Compromisso, data da decisão do
  cliente. Nunca "oportunidade", "vendedor", "proposta" como nome de fase,
  "fechamento" ou "data de fechamento".
- As oito etapas são canônicas: 1 Seleção Estratégica, 2 Exploração Profunda,
  3 Conexão de Valor, 4 Confirmação de Compromisso, 5 Execução de Excelência,
  6 Cultivo de Valor, 7 Parceria de Crescimento, 8 Gestão Contínua. O funil do
  CRM é 0 [NOME DA FASE 0] mais as fases 1 a 7 mais 8 [NOME DA FASE 8].
- Estágio só avança quando o artefato da fase existe e foi validado com o
  cliente. Os campos obrigatórios por fase estão na seção 4.1.
- Forecast por artefato: Compromisso, Possível, Aberto, Fora do número. Nunca
  ponderação por percentual como número oficial.
- Confidencialidade no banco, não na tela: política de acesso por linha e por
  coluna, campos confidenciais listados na seção 5, perfis da seção 6. O
  parceiro nunca vê margem, comissão de terceiros, valores internos ou atas.
- Nada se apaga: tudo se arquiva. Trilha de auditoria imutável. Exportação
  semanal automática para o Drive. Backups diários.
- Conta de administrador e conta de emergência criadas no primeiro dia, com MFA
  e códigos de recuperação impressos para o envelope.
- A IA sugere e preenche em rascunho; o humano confirma. Nada é enviado ao
  cliente sem revisão. Chave de API só em função de servidor. Teto mensal de
  [TETO EM DÓLARES].
- Multi-inquilino desde o primeiro commit: a Felix é o inquilino 1. Marca,
  catálogo, campos, listas, regras e módulos são configuração.
- Nunca inventar nome de pessoa, cliente ou valor. O que não estiver na fonte
  entra na fila "a confirmar".
- Nenhum valor confidencial em repositório, log, captura de tela ou documento
  público.

ARQUITETURA
- Backend: Supabase, projeto na região São Paulo, PostgreSQL com RLS, Auth com
  MFA, Storage privado com URLs assinadas, Edge Functions para IA e
  integrações, pg_cron para alertas e para a exportação semanal.
- Front-end: React, TypeScript, Vite, PWA instalável, roteamento por perfil,
  tokens de design Felix, componentes acessíveis, gráficos com paleta única.
- IA: Claude via API da Anthropic, chamado só por Edge Function, com registro
  de custo por chamada e por inquilino.
- Publicação: [DOMÍNIO], com DNS na Locaweb. Front-end publicado em [LOCAWEB
  public_html OU NETLIFY].
- Repositório: [REPOSITÓRIO PRIVADO], com CI que roda testes de RLS, testes de
  regras de fase, verificação de travessão e de acentuação, e build.

ENTREGAS, NESTA ORDEM
1. Núcleo. 2. Carteira e dinheiro. 3. Conselho. 4. PRM. 5. IA. 6. White label e
integrações. O conteúdo e o critério de aceite de cada uma estão na seção 15.
Ao terminar cada entrega: rodar os testes, publicar em ambiente de homologação,
gerar um roteiro de validação em português para Hamilton testar em dez minutos
no celular, atualizar o STATUS.md e parar para o aval.

MIGRAÇÃO
Seguir a ordem da seção 13 com assistente de importação, prévia obrigatória e
fila "a confirmar". Mapeamento de fases da seção 4.2. Congelar as planilhas na
data da migração.

DECISÕES JÁ TOMADAS
[COLAR AQUI A TABELA DA SEÇÃO 14 COM AS RESPOSTAS]

O QUE FAZER SOZINHO E O QUE PERGUNTAR
Faça sozinho tudo que é técnico e reversível. Pergunte antes de: gastar
dinheiro, publicar em domínio público, enviar qualquer mensagem a cliente ou
parceiro, apagar ou sobrescrever dado importado, mudar nome de etapa ou de
campo do método.

FORMA DE REPORTAR
A cada parada: o que foi feito, o que foi verificado e como, o que ficou
pendente, o que precisa de decisão. Sem rodeios, sem travessão, em português.
```

---

## 17. Próximo passo

Hamilton Felix responde a tabela da seção 14 (bastam os números e a resposta em uma linha). Com as respostas, o prompt mestre sai da versão 0.1 para a 1.0 e a construção começa pela Entrega 1.
