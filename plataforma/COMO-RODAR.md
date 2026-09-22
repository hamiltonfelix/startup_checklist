# Como rodar a Plataforma de Valor na sua máquina

## Onde ela está

**Não está no seu disco.** Ela foi construída num contêiner na nuvem e vive no GitHub:

| | |
|---|---|
| Repositório | `https://github.com/hamiltonfelix/startup_checklist` |
| Ramo | `claude/crm-felix-prompt-structure-gh1zgs` |
| Pasta | `plataforma/` |
| Tamanho | 8,7 MB, sem as dependências |

## O que precisa estar instalado

**Node.js 18 ou mais novo.** Só isso. Baixe em `nodejs.org`, a versão LTS. Se já tiver, confira com `node --version`.

Não precisa de banco de dados, não precisa de conta em lugar nenhum. A plataforma sobe com dados de exemplo e avisa na tela que está em exemplo.

## Os comandos, em ordem

Abra o **Prompt de Comando**, o **PowerShell** ou o **Git Bash** e cole uma linha de cada vez:

```
git clone https://github.com/hamiltonfelix/startup_checklist.git
cd startup_checklist
git checkout claude/crm-felix-prompt-structure-gh1zgs
cd plataforma/app
npm install
npm run dev
```

O `npm install` demora um ou dois minutos na primeira vez. Depois, o `npm run dev` responde em segundos e mostra um endereço parecido com:

```
  ➜  Local:   http://localhost:5173/
```

Abra esse endereço no navegador. A plataforma inteira está lá.

## Para parar e voltar depois

Parar: `Ctrl` mais `C` na janela do comando.

Voltar, nas próximas vezes:

```
cd startup_checklist/plataforma/app
npm run dev
```

Não precisa repetir o `npm install`.

## Para pegar as novidades

Quando houver versão nova:

```
cd startup_checklist
git pull origin claude/crm-felix-prompt-structure-gh1zgs
cd plataforma/app
npm install
npm run dev
```

## O que dá para testar hoje

Tudo que é **leitura** funciona: as vinte e uma telas, a navegação por perfil, o quadro de negócios pelas nove fases, a trilha dos artefatos, o cálculo da comissão aberto passo a passo, o rito do conselho, o NPS.

No canto superior direito há um seletor **Ver como**. Troque o perfil e veja a navegação mudar. É o jeito rápido de conferir o que o parceiro enxerga e o que ele não enxerga.

O que ainda **não grava**: convidar usuário, aceitar indicação, salvar oferta e avançar o fluxo da ata. A interface está montada e o botão avisa que sem banco não grava. Isso entra quando o Supabase estiver ligado.

## Os outros comandos

| Comando | O que faz |
|---|---|
| `npm run dev` | sobe para desenvolver, com recarga automática |
| `npm run build` | compila a versão de produção na pasta `dist` |
| `npm run preview` | serve a versão compilada, para ver como fica publicada |
| `npm run tipos` | confere os tipos sem compilar |

## Se der errado

**`git` não é reconhecido como comando:** instale o Git em `git-scm.com`.

**`npm` não é reconhecido:** o Node.js não está instalado ou o terminal precisa ser fechado e aberto de novo.

**A porta 5173 está ocupada:** rode `npm run dev -- --port 5174` e use o endereço novo.

**A tela abre em branco:** confira o console do navegador com `F12`. O mais comum é a versão do Node ser antiga demais.
