# Decisões de arquitetura

Versão 1.0 · 22/09/2026. Registro das decisões que o orquestrador tomou quando dois construtores modelaram a mesma ideia de formas diferentes, ou quando um deles devolveu a escolha. Cada decisão traz o motivo, porque daqui a seis meses ninguém lembra.

---

## 1. A pauta tem uma dona só: a tabela

**O conflito.** A migração 0008, do BRM, guarda a pauta do encontro como `jsonb` dentro de `valor.encontros`. A migração 0009, da governança, modela pauta como tabela própria, com itens ordenados, origem, responsável e tempo previsto.

**A decisão.** `valor.pautas` é a fonte da verdade. O campo `jsonb` em `valor.encontros` passa a ser cache de leitura, preenchido a partir da tabela, e nunca editado direto.

**O motivo.** É da tabela que sai a regra que mais importa no rito do conselho: a pendência aberta reaparece na pré-pauta até fechar. Isso exige item com dono, prazo e origem, que `jsonb` solto não garante. Onde não há conselho, um workshop de dois dias, por exemplo, o `jsonb` basta e continua servindo.

---

## 2. O vínculo entre encontro e ata aponta numa direção só

**O conflito.** `valor.atas` tem `encontro_id`. `valor.encontros` não tem `ata_id`.

**A decisão.** Fica como está. O vínculo é `atas.encontro_id`, e ninguém acrescenta a coluna inversa.

**O motivo.** Duas colunas apontando uma para a outra são duas verdades que discordam no primeiro dia de uso. Navegar do encontro para a ata é uma consulta, não uma coluna. E um encontro pode ter ata nenhuma, uma ata, ou uma ata refeita, o que a coluna única não comporta.

---

## 3. A ata é numerada por turma, não por conta

**A decisão.** O índice único de numeração passa a ser por `(inquilino_id, turma_id, numero)`.

**O motivo.** No conselho compartilhado, uma turma reúne empresários de contas diferentes, e a reunião é uma só. Numerar por conta produziria a mesma reunião com números distintos para cada participante. No conselho dedicado, conta e turma andam juntas, então nada muda na prática.

---

## 4. O que espera confirmação de Hamilton Felix

Três listas não estão escritas em nenhum arquivo do repositório. O construtor as compôs a partir do vocabulário da casa, e deixou tudo em função de semeadura idempotente, trocável numa tela e não em código. **Nada disso bloqueia a construção.** Trocar é rodar a função de novo com a lista certa.

| Lista | De onde veio | O que confirmar |
|---|---|---|
| Os 15 temas de governança e as 6 famílias de gestão | vocabulário do Lean Governance Canvas do cofre, mais os 6 módulos do Gestão de Valor | a lista canônica do método |
| Os 16 blocos da extensão de ata | o que o esquema de dados descreve para reunião de conselho, mais o ritual semanal | o padrão da skill de ata da casa |
| O enunciado das 10 questões de NPS | a pergunta clássica mais os sete blocos exigidos | os modelos de NPS que estão no Drive |

As **sete seções oficiais da ata** não estão nesta lista: essas estão exatas, conforme o padrão em uso desde setembro de 2026.
