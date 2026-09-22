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

---

## 5. O white label vaza calado pela cor, não pela palavra

**O achado.** O curador de catálogo descobriu que `valor.semear_gtd`, na migração 0011, pinta as colunas do quadro Kanban com a paleta da Felix escrita dentro do código: `#5E1E3A`, `#C2900A`, `#C58A00`, `#1D1D1B`, `#2E7D4F` e `#707070`.

**Por que isso é sério.** Num inquilino white label, isso é a identidade visual da Felix aparecendo no sistema de outra empresa. E vaza em silêncio, porque ninguém lê hexadecimal numa revisão de texto. A varredura de marca só pegou porque ela procura também pelas dez cores da casa, e não apenas por palavras.

**O contorno que existe hoje.** `valor.neutralizar_identidade` repinta as colunas logo depois da semeadura, então o resultado final está limpo e o teste prova isso.

**A correção de fundo, ainda pendente.** A coluna deve ler `identidade.cores` de `valor.configuracoes` em vez de trazer a cor escrita. Enquanto isso não acontecer, qualquer semeadura nova que esqueça de chamar a neutralização volta a vazar.

**A lição que fica para a fábrica.** Identidade visual não é decoração, é dado de inquilino. Nenhuma migração escreve cor, fonte ou nome de marca dentro do código. Tudo isso vive em configuração, e a varredura de marca precisa procurar por cor, e não só por palavra.

---

## 6. Meta em branco é indisponível, nunca zero

**A regra.** As quatro chaves de meta nascem vazias de propósito. Quem lê meta **não pode** usar função de leitura com valor padrão, porque ela devolveria o padrão e inventaria uma meta que ninguém definiu.

**O que fazer.** Ler a chave direto e tratar `jsonb_typeof(valor) = 'null'` como indisponível. O painel mostra cobertura como indisponível, e não um número errado.

**O motivo.** Um número errado numa tela de decisão é pior do que a ausência do número. Quem vê "indisponível" vai atrás. Quem vê um número falso decide em cima dele.

---

## 7. Meta tem duas formas de chave, e a mais precisa vence

**O conflito.** O curador de catálogo criou quatro chaves de meta na semente, sem o período escrito no nome, para a tela editar. O engenheiro de painéis criou uma forma com o período escrito na chave, mais precisa, para guardar histórico de meta por ano e por trimestre.

**A decisão.** As duas convivem. `valor.vw_cobertura` lê as duas e, quando existirem as duas para o mesmo período, **a chave com período escrito vence**, por ser a mais específica. Nenhuma das duas é lida com função de valor padrão, como manda a decisão 6.

**O motivo.** A tela precisa de uma chave estável para editar a meta corrente sem inventar nome. O histórico precisa de uma chave por período para a meta do ano passado não sumir quando a do ano novo for gravada. Escolher só uma perderia ou a facilidade da tela ou a memória do histórico.

---

## 8. O painel do parceiro não engana com agregado

**A decisão.** As visões que publicam número da casa, pipeline, higiene, cobertura, concentração, funil e saúde da conta, negam o perfil de parceiro em vez de filtrar por ele.

**O motivo.** Se elas apenas filtrassem, o parceiro receberia um agregado calculado só com os negócios dele, **apresentado como o número da casa**. Não seria vazamento, seria mentira. O portal do parceiro tem a visão própria dele, com a carteira dele e a comissão dele, e é a única que ele enxerga.

A mesma regra vale para a cobertura quando a amostra é pequena: com menos de cinco decisões, ou nenhum ganho, a visão devolve indisponível com o motivo escrito, em vez de publicar uma taxa de ganho tirada de duas ou três decisões.
