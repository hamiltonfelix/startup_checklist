#!/usr/bin/env bash
# Portão de qualidade da Plataforma de Valor.
# Roda sobre tudo que a fábrica produziu. Reprova sem dó.
# Uso: bash plataforma/testes/portao-qualidade.sh
set -uo pipefail

# Nada do que a varredura textual olha inclui dependencia de terceiro,
# resultado de compilacao ou historico do controle de versao.
EXCLUI=(--exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git --exclude-dir=.vite --exclude-dir=coverage)

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRACOES="$RAIZ/supabase/migracoes"
APP="$RAIZ/app"
BANCO="portao_$(date +%s)"
FALHAS=0

titulo() { printf "\n\033[1m%s\033[0m\n" "$1"; }
ok()     { printf "  \033[32mpassou\033[0m  %s\n" "$1"; }
falha()  { printf "  \033[31mREPROVOU\033[0m %s\n" "$1"; FALHAS=$((FALHAS+1)); }

# --------------------------------------------------------------- 1 editorial
titulo "1 · Regras editoriais"

ACHADOS=$(grep -rlP "${EXCLUI[@]}" '\x{2014}|\x{2013}' "$RAIZ" --include='*.sql' --include='*.ts' --include='*.tsx' --include='*.css' --include='*.md' --include='*.html' 2>/dev/null || true)
if [ -z "$ACHADOS" ]; then ok "nenhum travessão nem meia-risca"
else falha "travessão encontrado em:"; echo "$ACHADOS" | sed 's/^/           /'; fi

ACHADOS=$(grep -rn "${EXCLUI[@]}" 'Félix' "$RAIZ" --include='*.sql' --include='*.ts' --include='*.tsx' --include='*.css' --include='*.md' 2>/dev/null || true)
if [ -z "$ACHADOS" ]; then ok "Felix sempre sem acento"
else falha "Felix com acento em:"; echo "$ACHADOS" | head -10 | sed 's/^/           /'; fi

# --------------------------------------------------------------- 2 vocabulário
titulo "2 · Vocabulário do método na interface"

PROIBIDAS=("Oportunidade" "Oportunidades" "Vendedor" "Proposta" "Fechamento" "Data de fechamento")
for p in "${PROIBIDAS[@]}"; do
  # Procura só no que vira texto de tela. Comentário de SQL pode citar a palavra proibida
  # justamente para explicar que ela não deve ser usada.
  ACHADOS=$(grep -rn "${EXCLUI[@]}" "$p" "$APP/src" --include='*.tsx' --include='*.ts' 2>/dev/null | grep -v 'nunca\|Nunca\|jamais\|Jamais\|proibid' || true)
  if [ -z "$ACHADOS" ]; then ok "não usa a palavra $p"
  else falha "palavra proibida $p em:"; echo "$ACHADOS" | head -5 | sed 's/^/           /'; fi
done

# --------------------------------------------------------------- 3 segredos
titulo "3 · Nenhum segredo no repositório"

PADROES='sk-ant-|eyJhbGciOi|SUPABASE_SERVICE_ROLE|BEGIN [A-Z ]*PRIVATE KEY|postgres://[^ ]*:[^ @]*@'
ACHADOS=$(grep -rnE "${EXCLUI[@]}" "$PADROES" "$RAIZ" --include='*.sql' --include='*.ts' --include='*.tsx' --include='*.md' --include='*.json' --include='*.env*' 2>/dev/null | grep -v 'exemplo\|CONTRATO-TECNICO\|portao-qualidade' || true)
if [ -z "$ACHADOS" ]; then ok "nenhuma chave, token ou senha aparente"
else falha "possível segredo em:"; echo "$ACHADOS" | head -5 | sed 's/^/           /'; fi

ACHADOS=$(grep -rniE "${EXCLUI[@]}" '\(?\+?55 ?\(?[0-9]{2}\)? ?9[0-9]{4}[- ]?[0-9]{4}' "$RAIZ" --include='*.sql' --include='*.ts' --include='*.tsx' 2>/dev/null || true)
if [ -z "$ACHADOS" ]; then ok "nenhum telefone de verdade"
else falha "telefone aparente em:"; echo "$ACHADOS" | head -5 | sed 's/^/           /'; fi

# --------------------------------------------------------------- 4 migrações
titulo "4 · As migrações aplicam em ordem, num banco limpo"

sudo -u postgres dropdb --if-exists "$BANCO" 2>/dev/null
sudo -u postgres createdb "$BANCO" 2>/dev/null
APLICOU=0
for f in $(ls "$MIGRACOES"/*.sql 2>/dev/null | sort); do
  SAIDA=$(sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d "$BANCO" -f "$f" 2>&1)
  if [ $? -eq 0 ]; then APLICOU=$((APLICOU+1))
  else falha "$(basename "$f") não aplicou:"; echo "$SAIDA" | head -6 | sed 's/^/           /'; break; fi
done
[ "$APLICOU" -gt 0 ] && ok "$APLICOU migrações aplicadas em sequência"

# --------------------------------------------------------------- 5 padrão de tabela
titulo "5 · Toda tabela obedece ao padrão"

SEM_RLS=$(sudo -u postgres psql -tAc "
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'valor' and c.relkind = 'r' and not c.relrowsecurity
  order by 1" "$BANCO" 2>/dev/null)
if [ -z "$SEM_RLS" ]; then ok "todas as tabelas com segurança de linha habilitada"
else falha "tabela sem RLS:"; echo "$SEM_RLS" | sed 's/^/           /'; fi

SEM_POLITICA=$(sudo -u postgres psql -tAc "
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'valor' and c.relkind = 'r' and c.relrowsecurity
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
  order by 1" "$BANCO" 2>/dev/null)
if [ -z "$SEM_POLITICA" ]; then ok "todas as tabelas com pelo menos uma política"
else falha "tabela com RLS e sem política:"; echo "$SEM_POLITICA" | sed 's/^/           /'; fi

SEM_INQUILINO=$(sudo -u postgres psql -tAc "
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'valor' and c.relkind = 'r'
    and c.relname not in ('inquilinos','auditoria')
    and not exists (select 1 from pg_attribute a
                    where a.attrelid = c.oid and a.attname = 'inquilino_id' and a.attnum > 0)
  order by 1" "$BANCO" 2>/dev/null)
if [ -z "$SEM_INQUILINO" ]; then ok "todas as tabelas carregam o inquilino"
else falha "tabela sem inquilino_id:"; echo "$SEM_INQUILINO" | sed 's/^/           /'; fi

DINHEIRO_ERRADO=$(sudo -u postgres psql -tAc "
  select c.relname || '.' || a.attname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid and a.attnum > 0
  join pg_type t on t.oid = a.atttypid
  where n.nspname = 'valor' and c.relkind = 'r'
    and t.typname in ('float4','float8')
    and (a.attname like '%valor%' or a.attname like '%preco%' or a.attname like '%custo%'
         or a.attname like '%margem%' or a.attname like '%percentual%')
  order by 1" "$BANCO" 2>/dev/null)
if [ -z "$DINHEIRO_ERRADO" ]; then ok "nenhum dinheiro guardado como ponto flutuante"
else falha "dinheiro em float:"; echo "$DINHEIRO_ERRADO" | sed 's/^/           /'; fi

# --------------------------------------------------------------- 6 inventário
titulo "6 · Inventário"
T=$(sudo -u postgres psql -tAc "select count(*) from pg_tables where schemaname='valor'" "$BANCO" 2>/dev/null)
V=$(sudo -u postgres psql -tAc "select count(*) from pg_views where schemaname='valor'" "$BANCO" 2>/dev/null)
P=$(sudo -u postgres psql -tAc "select count(*) from pg_policies where schemaname='valor'" "$BANCO" 2>/dev/null)
F=$(sudo -u postgres psql -tAc "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='valor'" "$BANCO" 2>/dev/null)
C=$(sudo -u postgres psql -tAc "select count(*) from pg_description d join pg_class c on c.oid=d.objoid join pg_namespace n on n.oid=c.relnamespace where n.nspname='valor' and d.description like 'CONFIDENCIAL%'" "$BANCO" 2>/dev/null)
printf "  tabelas %s · views %s · políticas %s · funções %s · colunas confidenciais marcadas %s\n" "$T" "$V" "$P" "$F" "$C"

sudo -u postgres dropdb --if-exists "$BANCO" 2>/dev/null

# --------------------------------------------------------------- 7 segurança
titulo "7 · Segurança de linha provada com papel sem privilégio"
if bash "$RAIZ/testes/prova-de-seguranca.sh" >/tmp/prova_seg.txt 2>&1; then
  ok "$(grep -c 'passou' /tmp/prova_seg.txt) provas de segurança passaram"
else
  falha "a prova de segurança reprovou:"; grep -i 'REPROVOU' /tmp/prova_seg.txt | head -6 | sed 's/^/           /'
fi

# --------------------------------------------------------------- veredito
titulo "Veredito"
if [ "$FALHAS" -eq 0 ]; then printf "  \033[32mAPROVADO\033[0m · nenhuma falha\n\n"; exit 0
else printf "  \033[31mREPROVADO\033[0m · %s falha(s)\n\n" "$FALHAS"; exit 1; fi
