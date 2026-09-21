# Prompt mestre · versão 1.0

Para colar numa sessão nova do Claude Code, com o repositório privado do projeto aberto. As decisões de Hamilton Felix de 21/09/2026 já estão embutidas.

---

```
Você vai construir a plataforma CRM de Valor, PRM de Valor e BRM de Valor da
Felix Empresarial, de forma autônoma e completa.

PAPEL
Você é o arquiteto, o desenvolvedor e o responsável pela qualidade. Trabalha em
paralelo sempre que houver itens independentes: lança um subagente por item e
nunca executa em sequência o que pode correr junto. Antes de cada entrega
grande, apresenta o plano, espera o aval e só então executa. Mantém um
STATUS.md na raiz com o que está feito, o que está em curso e o que depende de
decisão.

CONTEXTO A LER ANTES DE ESCREVER A PRIMEIRA LINHA DE CÓDIGO
1. crm-gestao-continua/ENTENDIMENTO-E-PROMPT-MESTRE.md, inteiro. É a fonte de
   verdade do desenho.
2. crm-gestao-continua/ESQUEMA-DE-DADOS.md, inteiro. É a fonte de verdade do
   modelo de dados e da política de acesso.
3. No Google Drive: as planilhas "FELIX - PRIORIDADES - 2026" e "CONTRATOS E
   PIPELINE - FELIX", na pasta FELIX - EMPRESARIAL/EMPRESAS. Só a estrutura
   entra em código; os valores entram no banco privado.
4. No cofre Obsidian espelhado no Drive, as notas: Negócios de Valor, Conselho
   de Valor, Memória Executiva de Conselho, Identidade visual FELIX, Como
   trabalhar com o Hamilton, Padrões editoriais dos documentos, Pipeline
   comercial no Drive, Carteira de clientes, Contratos modelo de conselho,
   Análise de Oportunidade, Avaliação do Meu Papel, Dossiê de Inteligência,
   Ferramentas FELIX, Skills FELIX, Hospedagem Locaweb e Mapa do Google Drive.
5. A ficha b16-cadencia-pipeline-forecast-ia.md e a Ferramenta 20
   20-painel-de-pipeline.html do Negócios de Valor 2.00. A ferramenta 20 é o
   motor de higiene e forecast que você vai reimplementar sobre dados vivos.
6. Uma ata de conselho no padrão de setembro de 2026, com as sete seções.
7. O site felixempresarial.com.br: metodo, negocios-de-valor, conselho-de-valor
   e solucoes.

O QUE ESTÁ SENDO CONSTRUÍDO
Uma plataforma, um banco, um login, três produtos:
- CRM de Valor: o funil comercial sobre as oito etapas do método.
- PRM de Valor: o parceiro registra oportunidade, acompanha aprovação, prazos e
  a própria comissão.
- BRM de Valor (Board Relationship Management): tudo o que a casa entrega
  depois da assinatura, em Programa, Turma, Encontro, Participante e
  Entregável, mais reuniões de conselho, atas, deliberações, pendências,
  transcrições, NPS e Histórico de Valor.
Gestão Contínua não é nome de produto: é a etapa transversal do método, o motor
de registro, higiene, cobertura e forecast que atravessa os três.

REGRAS INEGOCIÁVEIS
- Português do Brasil com acentuação correta em tudo: interface, textos de
  ajuda, mensagens de erro, documentação e commits. Nunca travessão nem
  meia-risca. Separador de rótulo é o ponto médio. Intervalo de datas com "a".
- Identidade Felix: vinho #5E1E3A em logo e títulos, vinho profundo #490B2C em
  fundos, dourado #EFB810 só como elemento gráfico em fundo claro e #C2900A
  como texto sobre branco, tinta #1D1D1B, cinza #707070; alarmes verde #2E7D4F,
  amarelo #C58A00, vermelho #B3261E. Oswald em títulos, Montserrat no corpo.
  Logo sempre por arquivo de lockup, nunca digitado. Texto justificado só em
  PDF e DOCX, nunca em tela.
- Vocabulário do método na interface: negócio, Gerente de Contas, Plano de
  Trabalho, Contrato de Valor, Confirmação de Compromisso, data da decisão do
  cliente. Nunca "oportunidade", "vendedor", "proposta" como nome de fase,
  "fechamento" nem "data de fechamento".
- As oito etapas são canônicas e nesta ordem: 1 Seleção Estratégica,
  2 Exploração Profunda, 3 Conexão de Valor, 4 Confirmação de Compromisso,
  5 Execução de Excelência, 6 Cultivo de Valor, 7 Parceria de Crescimento,
  8 Gestão Contínua. O funil do CRM é 0 Base de Leads, as fases 1 a 7 e
  8 Arquivo.
- Estágio só avança quando o artefato da fase existe e foi validado com o
  cliente. Os campos obrigatórios por fase estão na seção 4.1 do documento.
- O conselheiro entra na Conexão de Valor e conduz a relação até a Parceria de
  Crescimento. Papel é por negócio e por etapa, registrado em papeis_negocio,
  com data de entrada. A passagem de bastão da etapa 2 para a 3 é um evento
  registrado.
- Forecast por artefato: Compromisso, Possível, Aberto, Fora do número. Nunca
  ponderação por percentual como número oficial.
- Confidencialidade no banco, não na tela: política de acesso por linha e por
  coluna, campos confidenciais marcados no esquema, perfis da seção 6. O
  parceiro nunca vê margem, comissão de terceiros, valores internos ou atas.
- Nada se apaga: tudo se arquiva. Trilha de auditoria imutável. Exportação
  semanal automática para o Drive. Backups diários.
- Conta de administrador e conta de emergência criadas no primeiro dia, com
  múltiplo fator e códigos de recuperação impressos para envelope físico.
  Qualquer login da conta de emergência dispara alerta.
- A IA sugere e preenche em rascunho; o humano confirma. Nada é enviado ao
  cliente sem revisão. Chave de API só em função de servidor. Teto mensal de 50
  dólares, com corte automático e aviso.
- Multi-inquilino desde o primeiro commit. A Felix é o inquilino 1. Marca,
  catálogo, campos, listas, regras e módulos são configuração, não código. O
  exportador e o importador de pacote de configuração entram na Entrega 1, com
  o teste que reprova o pacote se ele contiver qualquer dado de conta, pessoa,
  contrato, valor, ata ou transcrição.
- Nunca inventar nome de pessoa, cliente ou valor. O que não estiver na fonte
  entra na fila "a confirmar".
- Nenhum valor confidencial em repositório, log, captura de tela ou documento
  público.

ARQUITETURA
- Backend: Supabase, projeto na região São Paulo. PostgreSQL com RLS, Auth com
  múltiplo fator, Storage privado com URLs assinadas, Edge Functions para IA e
  integrações, pg_cron para alertas e para a exportação semanal.
- Front-end: React, TypeScript, Vite, PWA instalável, roteamento por perfil,
  tokens de design Felix, componentes acessíveis, gráficos com paleta única.
- IA: Claude via API da Anthropic, chamado só por Edge Function, com registro
  de custo por chamada em execucoes_ia.
- Publicação: valor.felixempresarial.com.br, com /parceiros para o PRM e
  /conselho para o BRM. DNS na Locaweb, que não hospeda a aplicação.
- Repositório privado, com integração contínua que roda: testes de RLS com um
  usuário de cada perfil, testes das regras de fase, verificação de travessão e
  de acentuação, teste do pacote de configuração e build.

ENTREGAS, NESTA ORDEM
1. NÚCLEO DO CRM DE VALOR. Inquilino, autenticação com múltiplo fator e conta
   de emergência, perfis, contas, contatos, negócios, papéis por negócio, funil
   de 0 a 8 com campos obrigatórios, artefatos, kanban, atividades GTD, painel
   comercial com os quatro invariantes, cobertura e forecast por artefato,
   importação das duas planilhas, identidade Felix, exportador de configuração.
   Aceite: Hamilton Felix opera o pipeline real por uma semana sem abrir a
   planilha.
2. BRM DE VALOR. Programa, Turma, Encontro, Participante, Entregável; reuniões
   de conselho, banco de pautas, atas no padrão de sete seções, deliberações,
   pendências que reaparecem na pré-pauta, transcrições lidas do Drive, NPS,
   Histórico de Valor, painel do conselheiro e painel de turmas.
   Aceite: uma reunião real de conselho e um encontro real de turma registrados
   de ponta a ponta, com ata gerada em PDF e DOCX.
3. CARTEIRA E DINHEIRO. Contratos nos três níveis, parcelas e calendário de
   faturamento, comissões, alertas de vencimento e renovação, Parceria de
   Crescimento automática, Arquivo, painel do dono e financeiro, exportação e
   impressão.
   Aceite: o financeiro fecha um mês dentro do sistema.
4. PRM DE VALOR. Perfil de parceiro, registro e aprovação de oportunidade com
   checagem de conflito, score de oportunidade, comissão visível ao dono,
   materiais e treinamentos.
   Aceite: um parceiro real registra e acompanha uma oportunidade.
5. IA. Os botões da seção 7 do documento, dossiê de reunião, busca semântica,
   higiene automática, resumo de segunda-feira.
   Aceite: cada botão testado com uma conta real, com custo medido.
6. WHITE LABEL E INTEGRAÇÕES. Pacote de configuração exportável e importável,
   marca por inquilino, campos e listas configuráveis, Calendar, Drive, Gmail,
   assinatura eletrônica, exportação para o cofre.
   Aceite: um segundo inquilino criado por importação de pacote, sem nenhum
   dado da Felix.

Ao terminar cada entrega: rodar os testes, publicar em homologação, gerar um
roteiro de validação em português para Hamilton Felix testar em dez minutos no
celular, atualizar o STATUS.md e parar para o aval.

MIGRAÇÃO
Ordem da seção 12 do documento, com assistente de importação, prévia
obrigatória e fila "a confirmar". Mapeamento de fases da seção 4.1. Congelar as
planilhas na data da migração e passar a operar só no sistema.

DECISÕES JÁ TOMADAS
Nome: CRM de Valor, PRM de Valor e BRM de Valor.
Backend: Supabase em São Paulo; Locaweb só DNS.
Domínio: valor.felixempresarial.com.br, com /parceiros e /conselho.
Fases 0 e 8: Base de Leads e Arquivo.
Forecast oficial: por artefato; alta, média e baixa ficam como campo
informativo.
Margem: o comercial interno não vê, liberável por perfil.
Comissão: percentual sobre o valor da parcela, apurado no recebimento, pelo
prazo do contrato.
Aprovação de oportunidade de parceiro: Hamilton Felix aprova, prazo de 5 dias
úteis.
Conselheiro associado: perfil interno da casa, com contrato próprio e
remuneração registrada. O parceiro indicador continua no PRM.
Turmas: participante é contato ligado à conta dele; contrato por participante
na turma compartilhada e por turma na dedicada.
Assessor executivo: vê só as contas atribuídas; o conselheiro aprova a ata
antes do envio.
Portal do cliente: segunda versão.
White label: a Felix hospeda e cobra assinatura; a marca na tela é do cliente,
com a assinatura "Powered by Negócios de Valor · Felix Empresarial".
NPS: trimestral, instrumento da casa, link por e-mail e WhatsApp.
Ata: padrão de sete seções como oficial, governança grade de 16 blocos como
extensão.
Transcrições: leitura automática das pastas Meet Recordings e Google Meet do
Drive, com fila de triagem para o que não tem cliente no título.
Rota pública: sim, toggle por negócio, na versão 1.
Idioma: português, com inglês preparado para white label.
Celular: PWA responsivo instalável.
Linha do logo: ORIGEM.

O QUE FAZER SOZINHO E O QUE PERGUNTAR
Faça sozinho tudo que é técnico e reversível. Pergunte antes de: gastar
dinheiro, publicar em domínio público, enviar qualquer mensagem a cliente ou
parceiro, apagar ou sobrescrever dado importado, mudar nome de etapa ou de
campo do método.

FORMA DE REPORTAR
A cada parada: o que foi feito, o que foi verificado e como, o que ficou
pendente e o que precisa de decisão. Direto, em português, sem travessão.
```

---

## Como usar

1. Criar o repositório privado `valor-plataforma` no GitHub.
2. Copiar para ele os três arquivos deste projeto: o documento mestre, o esquema de dados e este prompt.
3. Criar o projeto no Supabase, região São Paulo, e guardar as credenciais fora do repositório.
4. Abrir a sessão nova, colar o bloco acima e acompanhar a Entrega 1.

## O que muda se uma decisão mudar

As decisões estão concentradas na seção 14 do documento mestre e no bloco "DECISÕES JÁ TOMADAS" deste prompt. Trocar qualquer uma é editar os dois lugares, sem refazer o desenho. As únicas que mexem na arquitetura são o backend, o multi-inquilino e a confidencialidade no banco.
