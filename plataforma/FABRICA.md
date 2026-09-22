# A fábrica · como esta plataforma é construída

Versão 1.0 · 22/09/2026. Hamilton Felix pediu uma fábrica de software, não um programador solitário. Este documento diz quem faz o quê, quem confere, e o que reprova uma entrega.

## O princípio

Ninguém aprova o próprio trabalho. Quem constrói não é quem audita. Toda entrega precisa de prova executada, com saída real colada no relatório. A frase "deve funcionar" reprova a entrega sozinha.

## Os papéis

### Orquestrador
Escreve a fundação, define o contrato técnico, distribui a propriedade dos arquivos, integra as entregas, opera o portão de qualidade e decide os conflitos. É o único que altera `0001`, `0002` e `0003`.

### Construtores
Cada um é dono exclusivo de um conjunto de arquivos. Nenhum construtor edita arquivo de outro. Quem precisa de mudança em arquivo alheio registra o pedido no relatório, e o orquestrador resolve. Isso elimina conflito de escrita concorrente sem serializar o trabalho.

| Papel | Domínio | Arquivos |
|---|---|---|
| Engenheiro de PRM e Financeiro | parceiro, contrato, parcela, comissão, margem | `0004`, `0005`, `0006` |
| Engenheiro de BRM | programa, turma, participante, encontro, entregável | `0007`, `0008` |
| Engenheiro de Governança | pauta, ata, pendência, pesquisa, NPS | `0009`, `0010` |
| Engenheiro de Operação | atividade GTD, alerta, automação, auditoria | `0011`, `0012`, `0013` |
| Engenheiro de Interface | sistema de design, casca, componentes, painel | `app/` |
| Engenheiro de Painéis | views de forecast, higiene e campo de Marte | `0014`, `0015` |
| Curador de Catálogo | semente do portfólio, temas de pauta, configuração | `0016` |

### Auditores
Entram depois dos construtores, e não escrevem código de produção.

| Papel | O que procura |
|---|---|
| Auditor de Segurança | tenta furar a segurança de linha, assumindo cada perfil, e prova que o parceiro não alcança margem, comissão de terceiro, ata restrita nem negócio alheio |
| Auditor de Método | confere se o vocabulário, as nove fases, o forecast por artefato e as quatro invariantes estão respeitados, e não substituídos por CRM genérico |
| Auditor Editorial | travessão, acentuação, `Felix` sem acento, texto justificado em tela, segredo no repositório |
| Testador | escreve o conjunto de testes que roda sozinho e prova cada regra de negócio com número na tela |

## O portão de qualidade

`bash plataforma/testes/portao-qualidade.sh` roda sobre tudo e reprova por:

1. Travessão ou meia-risca em qualquer arquivo
2. `Felix` escrito com acento
3. Palavra proibida no texto de tela
4. Chave, token, senha ou telefone aparente no repositório
5. Migração que não aplica num banco limpo, em ordem
6. Tabela sem segurança de linha habilitada
7. Tabela com segurança habilitada e sem nenhuma política
8. Tabela de negócio sem coluna de inquilino
9. Dinheiro guardado em ponto flutuante

O portão roda antes de todo commit. Reprovou, não commita.

## A esteira

```
fundação  ·  0001 tipos e funções de contexto
             0002 inquilino, usuários, convites, configuração
             0003 núcleo do CRM, com política de linha desde o nascimento
   ↓
onda 1    ·  quatro construtores de domínio, em paralelo, mais a interface
   ↓
onda 2    ·  views de painel e semente do catálogo, que dependem das tabelas
   ↓
auditoria ·  segurança, método, editorial, testes
   ↓
portão    ·  aprovado, commita. reprovado, volta ao construtor dono do arquivo
```

## Por que multi-inquilino desde a primeira linha

Porque a versão white label não é um projeto futuro, é uma entrega do programa Negócios de Valor. Toda tabela carrega o inquilino, toda política filtra por ele, e a configuração do inquilino vive em dado, não em código. Assim, levar a plataforma para outro cliente é criar uma linha em `valor.inquilinos` e carregar um pacote de configuração, não recompilar nada.

## O que nunca muda

- Nada é apagado. Arquivar é carimbar a data em `arquivado_em`.
- Confidencialidade é decidida no banco, por política de linha e de coluna. A interface nunca é a guardiã do segredo.
- Previsão de receita sai do artefato validado com o cliente, jamais de percentual de probabilidade.
- Pipeline declarado e pipeline auditado aparecem sempre lado a lado.
