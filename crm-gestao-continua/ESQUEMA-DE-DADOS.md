# Esquema de dados · CRM, PRM e BRM de Valor

Versão 1.0 · 21/09/2026. Acompanha o `ENTENDIMENTO-E-PROMPT-MESTRE.md`.

Convenções: toda tabela tem `id`, `tenant_id`, `criado_em`, `criado_por`, `atualizado_em`, `atualizado_por` e `arquivado_em` (nulo quando ativo). Nada se apaga. Nomes de tabela em português, no plural, sem acento, para evitar problema de codificação em SQL. Toda tabela tem política de acesso por linha ligada ao `tenant_id` e ao perfil.

Marcação de confidencialidade: **C** significa coluna confidencial, invisível para o perfil de parceiro e para quem não tiver a permissão explícita.

---

## 1. Base e configuração

### inquilinos
Quem usa a plataforma. A Felix é o inquilino 1.

| Campo | Tipo | Nota |
|---|---|---|
| nome, nome_curto | texto | |
| dominio | texto | subdomínio ou domínio próprio |
| marca | json | logo claro, logo escuro, ícone, cores, fontes, nome do produto na tela |
| modulos | json | crm, prm, brm, rota_publica, portal_cliente |
| locale, fuso | texto | padrão pt-BR e America/Sao_Paulo |
| plano, status | texto | |

### usuarios
Espelha a autenticação. Um usuário pertence a um inquilino.

| Campo | Tipo | Nota |
|---|---|---|
| nome, email | texto | |
| perfil | enum | admin, admin_emergencia, lider, financeiro, gerente_contas, conselheiro, assessor, parceiro, participante, cliente, leitura |
| parceiro_id | fk | preenchido quando perfil é parceiro |
| contato_id | fk | preenchido quando perfil é participante ou cliente |
| mfa_ativo, ultimo_acesso, ativo | bool, timestamp, bool | |

### campos_customizados
Permite campo novo em qualquer entidade sem mexer no código.

| Campo | Tipo | Nota |
|---|---|---|
| entidade | enum | conta, contato, negocio, contrato, turma, participante e demais |
| chave, rotulo, ajuda | texto | |
| tipo | enum | texto, texto_longo, numero, moeda, percentual, data, booleano, lista, lista_multipla, arquivo, usuario, conta, contato, url |
| opcoes | json | quando tipo é lista |
| obrigatorio_em_fase | array | fases em que passa a ser obrigatório |
| confidencial | bool | entra na política de coluna |
| ordem, secao, ativo | int, texto, bool | |

### listas_valores
Vocabulário controlado: origens, segmentos, cargos, papéis, motivos de arquivo, tipos de atividade, modalidades.

| Campo | Tipo |
|---|---|
| lista, valor, rotulo, ordem, ativo, cor | texto, texto, texto, int, bool, texto |

### auditoria
Imutável. Sem update nem delete, por política.

| Campo | Tipo |
|---|---|
| usuario_id, entidade, entidade_id, acao, antes, depois, ip, em | fk, texto, uuid, enum, json, json, inet, timestamp |

---

## 2. Comercial

### contas
Uma conta vive enquanto a conta existir.

| Campo | Tipo | Nota |
|---|---|---|
| razao_social, nome_fantasia, cnpj | texto | cnpj único por inquilino quando preenchido |
| site, linkedin, uf, cidade | texto | |
| segmento, faixa_faturamento, faixa_funcionarios | texto | de lista de valores |
| tipos_relacao | array | cliente, prospect, parceiro, fornecedor, canal, empreendimento. Uma conta pode ser mais de um |
| tier | enum | 1, 2, 3 |
| prioridade | enum | 1, 2, 3 |
| dono_id | fk usuarios | Gerente de Contas responsável |
| parceiro_id | fk parceiros | quem indicou, quando houver |
| origem, campanha_id, evento_id | texto, fk, fk | |
| plano_conta | json | os 8 blocos do template |
| plano_conta_status | enum | nao_existe, existe_nao_validado, validado |
| power_of_x | int | linhas do portfólio já compradas |
| aniversario_contrato | data | |
| pasta_drive_url | texto | |
| resumo, tags | texto, array | |
| notas_internas **C** | texto | |

### contatos
Pessoas. Uma conta tem muitas.

| Campo | Tipo | Nota |
|---|---|---|
| conta_id | fk | |
| nome, sobrenome, cargo | texto | |
| email, celular, linkedin **C** | texto | dado pessoal, acesso restrito |
| papeis | array | decisor, patrocinador, influenciador, usuario, financeiro, juridico, assessor, socio |
| quem_conecta_id | fk contatos | quem abre a porta para essa pessoa |
| situacao | enum | ativo, saiu_empresa, sem_contato |
| consentimento_lgpd, consentimento_em | bool, data | |
| perfil_comportamental | texto | opcional |
| aniversario | data | |
| avaliacao_qualitativa **C** | texto | |

### negocios
O ciclo 2 a 7 roda por negócio. Vários em paralelo na mesma conta.

| Campo | Tipo | Nota |
|---|---|---|
| conta_id | fk | |
| titulo | texto | |
| oferta_id | fk portfolio | |
| modalidade | enum | recorrente, pontual |
| fase | enum | 0 a 8 |
| sub_status | texto | de lista de valores, depende da fase |
| valor_mensal, meses, valor_total | numérico | |
| margem_estimada **C** | numérico | |
| origem, quem_vende | texto, enum | interno, parceiro |
| parceiro_id | fk | |
| tier, probabilidade_manual | enum | alta, media, baixa, informativo |
| forecast_categoria | enum calculado | compromisso, possivel, aberto, fora |
| proximo_passo, proximo_passo_contato_id, proximo_passo_data | texto, fk, data | |
| data_decisao_cliente | data | nunca chamada de data de fechamento |
| validade_proposta | data | |
| ultima_interacao | data | |
| dias_parado | int calculado | |
| rota_publica | bool | |
| pncp_id, fase_administrativa | texto, enum | quando rota pública |
| motivo_arquivo, concorrente, licao_aprendida | texto | quando fase 8 |

### papeis_negocio
O que faz a jornada do conselheiro funcionar.

| Campo | Tipo | Nota |
|---|---|---|
| negocio_id, usuario_id | fk | |
| papel | enum | gerente_contas, conselheiro, pre_vendas, gerente_projetos, assessor, parceiro |
| entrou_em, saiu_em | data | a entrada do conselheiro na etapa 3 fica registrada aqui |
| principal | bool | |

### artefatos
O critério de saída de cada etapa.

| Campo | Tipo | Nota |
|---|---|---|
| negocio_id ou conta_id | fk | Plano de Conta é da conta; os demais são do negócio |
| tipo | enum | plano_conta, plano_negocio, plano_trabalho, contrato_valor, entrega_valor, monitoria_valor, renovacao_valor |
| status | enum | nao_existe, existe_nao_validado, validado_com_cliente |
| evidencia | texto | e-mail, ata, número que veio do cliente |
| arquivo_url, versao, validado_em, validado_por | texto, int, data, fk | |

### propostas

| Campo | Tipo |
|---|---|
| negocio_id, versao, valor **C**, condicoes **C**, validade, enviada_em, respondida_em, resultado, arquivo_url, template_id | fk, int, numérico, texto, data, data, data, enum, texto, fk |

### eventos e campanhas

| Campo | Tipo |
|---|---|
| nome, tipo, data, local, responsavel_id, status | texto, enum, data, texto, fk, enum |

### convidados
Liga evento a conta e contato, com status convidado, confirmado, presente e lead gerado.

---

## 3. Portfólio, contratos e dinheiro

### portfolio
O catálogo do inquilino.

| Campo | Tipo | Nota |
|---|---|---|
| nome, codigo | texto | Conselho de Valor, Negócios de Valor e demais |
| tipo | enum | conselho, programa, mentoria, consultoria, treinamento, palestra |
| modalidade | array | dedicado, compartilhado, recorrente, pontual |
| gera_turma | bool | se sim, ao assinar cria turma no BRM |
| jornada_padrao | json | número de encontros, cadência, entregáveis esperados |
| preco_referencia **C** | numérico | |

### contratos

| Campo | Tipo | Nota |
|---|---|---|
| conta_id, negocio_id | fk | |
| oferta_id | fk portfolio | |
| nivel | enum | n1_honorario, n2_participacao, n3_equity |
| status | enum | minuta, pendente, assinado, pausa, encerrado, cancelado, vencido |
| inicio, fim, meses | data, data, int | |
| renovacao_automatica, aviso_previo_dias | bool, int | |
| multa **C**, valor_mensal **C**, reajuste_indice, dia_faturamento | texto, numérico, texto, int | |
| periodicidade_reuniao, horario_reuniao, horas_semana | enum, hora, numérico | |
| impostos_percentual **C**, comissao_percentual **C**, parceiro_id, liquido **C** | numérico, numérico, fk, numérico | |
| participacao_base **C**, participacao_percentual **C** | texto, numérico | quando N2 |
| equity_tipo **C**, cliff_meses **C**, condicoes_saida **C** | texto, int, texto | quando N3 |
| assinatura_provedor, assinatura_id, assinado_em, arquivo_url | texto, texto, data, texto | |
| nps_periodicidade | enum | bimestral, trimestral, semestral |

### parcelas

| Campo | Tipo |
|---|---|
| contrato_id, competencia, vencimento, valor **C**, nota_fiscal **C**, status, pago_em, observacao | fk, texto, data, numérico, texto, enum, data, texto |

### comissoes
Serve ao vendedor interno e ao parceiro, com a mesma regra.

| Campo | Tipo | Nota |
|---|---|---|
| beneficiario_tipo | enum | vendedor_interno, parceiro, conselheiro |
| usuario_id, parceiro_id | fk | um dos dois, conforme o tipo |
| negocio_id, contrato_id, parcela_id | fk | |
| valor_bruto **C** | numérico | o valor da parcela |
| imposto_percentual, imposto_valor **C** | numérico | padrão de 15%, editável por contrato |
| base_calculo **C** | numérico | valor bruto menos imposto |
| percentual | numérico | padrão de 10% para vendedor e para parceiro |
| valor **C** | numérico | base vezes percentual |
| percentual_efetivo_sobre_bruto | numérico calculado | 8,5% no padrão, para o relatório do dono bater com o do vendedor |
| status | enum | prevista, apurada, paga |
| data, observacao | data, texto | |

Regra de visibilidade: cada um vê só a própria linha. O financeiro e o administrador veem todas. Quando há vendedor e parceiro no mesmo negócio, nascem duas linhas, cada uma com 10% sobre a mesma base.

### percentuais_padrao
Onde a regra vive, para trocar sem mexer em código.

| Campo | Tipo | Nota |
|---|---|---|
| escopo | enum | inquilino, oferta, contrato, pessoa |
| escopo_id | uuid | nulo quando o escopo é o inquilino |
| imposto_percentual | numérico | 15 por padrão |
| comissao_vendedor_percentual | numérico | 10 por padrão |
| comissao_parceiro_percentual | numérico | 10 por padrão |
| vigencia_inicio, vigencia_fim | data | o histórico fica, nada é sobrescrito |

O cálculo procura o percentual na ordem pessoa, contrato, oferta, inquilino, e usa o primeiro que encontrar vigente.

---

## 4. PRM

### parceiros

| Campo | Tipo | Nota |
|---|---|---|
| nome, tipo | texto, enum | indicador, canal, consultor_associado, conselheiro_banco |
| conta_id | fk | quando o parceiro é uma empresa cadastrada |
| uf, servicos, autoriza_site | texto, array, bool | |
| contrato_parceria_url, vigencia_inicio, vigencia_fim | texto, data, data | |
| treinamentos_concluidos | array | |
| status | enum | ativo, inativo, prospect |

### registros_oportunidade
O que o parceiro submete antes de virar negócio.

| Campo | Tipo | Nota |
|---|---|---|
| parceiro_id | fk | |
| empresa, cnpj, contato_nome, contato_cargo | texto | |
| descricao, oferta_id | texto, fk | |
| score | json | resultado da Análise de Oportunidade: momento, acesso, clareza, sinais, prontidão, faixa, porta de entrada |
| status | enum | submetido, em_analise, aprovado, recusado, duplicado |
| conflito_com_negocio_id | fk | quando a checagem encontra a conta na base |
| aprovador_id, decidido_em, motivo_recusa | fk, timestamp, texto | |
| negocio_id | fk | criado quando aprovado |
| validade_atribuicao | data | por quanto tempo a indicação garante comissão |

### materiais e treinamentos
Biblioteca por perfil, com controle de publicação e registro de quem baixou e concluiu.

---

## 5. BRM · a entrega

### programas
Instância de execução de uma oferta do portfólio para um contrato.

| Campo | Tipo | Nota |
|---|---|---|
| contrato_id, oferta_id | fk | |
| nome, tipo | texto, enum | conselho_dedicado, conselho_compartilhado, programa_dedicado, programa_compartilhado, mentoria |
| responsavel_id | fk usuarios | o conselheiro ou facilitador |
| status | enum | planejado, ativo, concluido, suspenso |

### turmas

| Campo | Tipo | Nota |
|---|---|---|
| programa_id | fk | |
| nome, codigo | texto | por exemplo CV01 |
| inicio, fim, cadencia, horario, formato | data, data, enum, hora, enum | online, presencial, hibrido |
| vagas, facilitador_id, coordenador_id | int, fk, fk | |
| status | enum | |

Uma turma dedicada tem participantes de uma conta. Uma turma compartilhada tem participantes de contas diferentes, e cada participante pode ter contrato próprio.

### encontros

| Campo | Tipo | Nota |
|---|---|---|
| turma_id | fk | |
| numero, titulo, data, hora_inicio, hora_fim, formato, local | int, texto, data, hora, hora, enum, texto | |
| pauta | json | itens com tema, tipo (deliberativo, informativo, consultivo) e responsável |
| status | enum | agendado, realizado, cancelado, remarcado |
| gravacao_url, transcricao_id | texto, fk | |
| ata_id | fk | quando é reunião de conselho |
| material_urls | array | |

### participantes

| Campo | Tipo | Nota |
|---|---|---|
| turma_id, contato_id, conta_id | fk | |
| papel | enum | membro, socio, convidado, observador |
| contrato_id | fk | quando o contrato é por participante |
| entrou_em, saiu_em, status | data, data, enum | |
| indice_inicial, indice_final | json | INV ou IEV em T0 e T90 |
| certificado_em, certificado_url | data, texto | |

### presencas
Encontro por participante, com status presente, ausente, justificado.

### entregaveis

| Campo | Tipo | Nota |
|---|---|---|
| turma_id, encontro_id, participante_id | fk | |
| tipo | texto | Plano de Conta, Plano de Negócio, resumo semanal, plano de ação |
| titulo, descricao, arquivo_url, versao | texto | |
| prazo, entregue_em | data | |
| status | enum | pendente, entregue, em_revisao, aprovado, devolvido |
| avaliacao | json | rubrica: artefatos, movimento da conta, banca |
| devolutiva, avaliador_id | texto, fk | |

### reunioes_conselho
Especialização de encontro para o conselho, com o padrão de sete seções.

| Campo | Tipo | Nota |
|---|---|---|
| encontro_id, conta_id, contrato_id | fk | |
| presentes, ausentes, convidados | array | |
| ata_anterior_aprovada | bool | |
| resumo_discussoes | json | um bloco por item de pauta, com destaques |
| proxima_data, pre_pauta | data, json | |
| ata_status | enum | rascunho, em_aprovacao, aprovada, enviada |
| ata_pdf_url, ata_docx_url | texto | |
| insight_conselho | texto | a reflexão própria do conselheiro |
| restrito | bool | quando a reunião trata de pessoas do cliente |

### deliberacoes

| Campo | Tipo | Nota |
|---|---|---|
| reuniao_id, conta_id | fk | |
| decisao, responsavel_nome, responsavel_id | texto, texto, fk | o responsável pode ser pessoa do cliente |
| prazo, status | data, enum | em_andamento, concluida, atrasada, cancelada |
| reaparece_na_pauta | bool | padrão verdadeiro até fechar |
| fechada_em, evidencia | data, texto | |

### pendencias
Itens que não nasceram de deliberação: tarefas do conselheiro, do assessor ou do cliente, com a mesma régua de dono, prazo e status.

### avaliacoes
NPS, eNPS e a nota do conselheiro.

| Campo | Tipo | Nota |
|---|---|---|
| conta_id, contrato_id, programa_id | fk | |
| tipo | enum | nps_cliente, enps, nps_revenda, nota_conselheiro |
| periodo, enviada_em, respondida_em | texto, data, data | |
| respondente_contato_id | fk | |
| nota | int | 0 a 10 |
| motivacoes | texto | |
| blocos | json | qualidade, atendimento, relacionamento, entrega, valor percebido, lealdade, inovação |
| temas_ia | array | agrupamento gerado pela IA, confirmado por humano |
| status | enum | agendada, enviada, respondida, expirada |

### historico_valor
O registro do que foi entregue e o que gerou.

| Campo | Tipo |
|---|---|
| conta_id, contrato_id, data, entregavel, valor_descricao, valor_numero, evidencia, arquivo_url, registrado_por | fk, fk, data, texto, texto, numérico, texto, texto, fk |

### transcricoes

| Campo | Tipo | Nota |
|---|---|---|
| origem | enum | gemini_drive, upload, gravacao |
| arquivo_origem, drive_id, titulo_original, data_reuniao | texto, texto, texto, data | |
| conta_id, encontro_id | fk | nulo quando está na fila de triagem |
| texto **C** | texto | bruto, acesso restrito |
| processamento | json | resumo, decisões, pendências, riscos, oportunidades |
| status | enum | triagem, vinculada, processada, descartada |

### pautas_banco
O banco de pautas pré-prontas.

| Campo | Tipo | Nota |
|---|---|---|
| familia | enum | governanca, gestao, tendencias |
| tema | texto | os 15 temas de governança e as 6 famílias de gestão |
| perguntas_orientadoras | array | |
| materiais | array | |
| usado_em | array de fk | rastreia em que reuniões já entrou |

---

## 6. Transversal

### atividades (GTD)

| Campo | Tipo | Nota |
|---|---|---|
| tipo | enum | reuniao, call, email, whatsapp, tarefa, visita, evento, follow_up |
| assunto, descricao | texto | |
| conta_id, negocio_id, contato_id, contrato_id, turma_id | fk | qualquer combinação |
| responsavel_id, delegado_para_id | fk | |
| data, hora, duracao | data, hora, int | |
| status | enum | inbox, proxima_acao, agendada, aguardando, algum_dia, concluida, cancelada |
| resultado, proxima_acao_id | texto, fk | |
| calendar_event_id, meet_url | texto | |

### documentos

| Campo | Tipo |
|---|---|
| entidade, entidade_id, tipo, titulo, versao, arquivo_url, drive_url, gerado_por_template_id, confidencial | texto, uuid, texto, texto, int, texto, texto, fk, bool |

### templates
Modelos de documento com variáveis, por inquilino, versionados.

### alertas

| Campo | Tipo |
|---|---|
| regra, entidade, entidade_id, destinatario_id, severidade, mensagem, disparado_em, lido_em, resolvido_em | texto, texto, uuid, fk, enum, texto, timestamp, timestamp, timestamp |

### execucoes_ia
Registro de custo e rastreabilidade.

| Campo | Tipo |
|---|---|
| usuario_id, funcao, entidade, entidade_id, modelo, tokens_entrada, tokens_saida, custo, duracao_ms, status, resultado_aceito | fk, texto, texto, uuid, texto, int, int, numérico, int, enum, bool |

### pacotes_configuracao
O que torna o white label possível.

| Campo | Tipo | Nota |
|---|---|---|
| nome, versao, descricao | texto | |
| conteudo | json | etapas, campos, listas, templates, pautas, automações, painéis, perfis, textos |
| gerado_de_tenant_id, gerado_em, gerado_por | fk, timestamp, fk | |
| importado_em_tenant_id, importado_em | fk, timestamp | |

O gerador do pacote tem um teste obrigatório: o JSON não pode conter nenhum identificador de conta, contato, contrato, valor, comissão, ata, transcrição ou pessoa. O teste roda na integração contínua e falha a publicação se encontrar qualquer um.

---

## 7. Cálculos que o banco entrega prontos

| Cálculo | Regra |
|---|---|
| pipeline_declarado | soma do valor dos negócios abertos nas fases 1 a 4 |
| pipeline_auditado | idem, excluindo os sem próximo passo com data futura e os com data de decisão vencida |
| forecast_categoria | compromisso se o artefato Contrato de Valor está validado; possível se Plano de Trabalho validado; aberto se Plano de Negócio validado; fora nos demais |
| taxa_vitoria | três denominadores: competitividade, capacidade de decidir (com o sem decisão) e qualidade da entrada |
| cobertura_necessaria | 1 dividido pela taxa de vitória com sem decisão |
| cobertura_real | pipeline auditado dividido pela meta do período |
| concentracao | soma dos dois maiores negócios dividida pelo pipeline declarado; alerta acima de 50% |
| dias_parado | dias desde a última interação; alarme acima de duas vezes a mediana da fase, com piso inicial de 30 dias |
| receita_recorrente | soma do valor mensal dos contratos ativos |
| nps | promotores menos detratores, por conta e consolidado, com tendência |

---

## 8. Política de acesso, em resumo

1. Toda consulta é filtrada por `tenant_id` do usuário autenticado.
2. Perfil parceiro só enxerga linhas em que `parceiro_id` é o dele, e nunca colunas marcadas com **C**.
3. Perfil conselheiro enxerga contas em que tem linha em `papeis_negocio` ou é responsável de programa, e o BRM completo dessas contas.
4. Perfil gerente de contas enxerga contas em que é dono e negócios em que tem papel.
5. Perfil assessor enxerga as contas atribuídas, no módulo BRM e na agenda.
6. Perfil participante enxerga a própria linha em `participantes`, seus entregáveis e o material da turma.
7. Perfil financeiro enxerga contratos, parcelas e comissões de todo o inquilino.
8. Admin e líder enxergam tudo do inquilino.
9. Toda exportação e impressão passa pela mesma política.
10. Cada regra tem teste automatizado que roda a cada versão, com um usuário de cada perfil.
