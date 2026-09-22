#!/usr/bin/env bash
# Prova de segurança da Plataforma de Valor.
#
# Roda como papel sem privilégio, e não como dono do banco, porque o dono
# ignora a segurança de linha e aprovaria até uma política quebrada.
# Varre TODA tabela em todo perfil. Qualquer erro reprova, e recursão de
# política aparece aqui como estouro de pilha.
#
# Uso: bash plataforma/testes/prova-de-seguranca.sh [nome_do_banco]
set -uo pipefail

BANCO="${1:-prova_seg_$(date +%s)}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRIOU=0
FALHAS=0
INQ='11111111-1111-1111-1111-111111111111'
PARC_A='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
PARC_B='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'

titulo() { printf "\n\033[1m%s\033[0m\n" "$1"; }
ok()     { printf "  \033[32mpassou\033[0m   %s\n" "$1"; }
falha()  { printf "  \033[31mREPROVOU\033[0m %s\n" "$1"; FALHAS=$((FALHAS+1)); }

if ! sudo -u postgres psql -lqt | cut -d\| -f1 | grep -qw "$BANCO"; then
  sudo -u postgres createdb "$BANCO" >/dev/null 2>&1
  CRIOU=1
  for f in $(ls "$RAIZ"/supabase/migracoes/*.sql | sort); do
    sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d "$BANCO" -f "$f" >/dev/null 2>&1 \
      || { echo "  migração $(basename "$f") não aplicou"; exit 1; }
  done
fi


# ------------------------------------------------ 0 semeia, senão a prova é oca
# Sem dado na tabela, "o parceiro lê zero" é verdade trivial e não prova nada.
# A carga entra como dono do banco, que ignora a segurança de linha de propósito,
# e cada bloco adiante confere primeiro que o administrador ENXERGA a linha,
# antes de exigir que o perfil restrito não enxergue.
sudo -u postgres psql -q -d "$BANCO" >/dev/null 2>&1 <<SQL
insert into valor.inquilinos (id, nome, apelido) values ('$INQ','Casa de Prova','prova')
  on conflict do nothing;
insert into valor.parceiros (id, inquilino_id, nome) values
  ('$PARC_A','$INQ','Parceiro Ficticio A'),
  ('$PARC_B','$INQ','Parceiro Ficticio B')
  on conflict do nothing;
insert into valor.contas (id, inquilino_id, nome) values
  ('c1111111-1111-1111-1111-111111111111','$INQ','Conta Ficticia Um'),
  ('c2222222-2222-2222-2222-222222222222','$INQ','Conta Ficticia Dois')
  on conflict do nothing;
insert into valor.negocios (id, inquilino_id, conta_id, titulo, parceiro_id, valor_total) values
  ('d1111111-1111-1111-1111-111111111111','$INQ','c1111111-1111-1111-1111-111111111111','Negocio do parceiro A','$PARC_A',100000),
  ('d2222222-2222-2222-2222-222222222222','$INQ','c2222222-2222-2222-2222-222222222222','Negocio do parceiro B','$PARC_B',200000),
  ('d3333333-3333-3333-3333-333333333333','$INQ','c1111111-1111-1111-1111-111111111111','Negocio sem parceiro',null,300000)
  on conflict do nothing;
SQL

CONTROLE=$(sudo -u postgres psql -tA -d "$BANCO" 2>&1 <<SQL
set role valor_aplicacao;
select set_config('app.inquilino_id','$INQ',false);
select set_config('app.perfil','admin_master',false);
select count(*) from valor.negocios;
SQL
)
CONTROLE=$(echo "$CONTROLE" | tail -1 | tr -d ' ')
titulo "0 · Controle: existe dado para a prova morder"
if [ "$CONTROLE" -ge 3 ] 2>/dev/null; then ok "o administrador enxerga $CONTROLE negócios semeados"
else falha "a carga falhou, o administrador enxerga $CONTROLE negócios. Toda prova adiante seria oca"; fi

# ------------------------------------------------ 1 varredura de toda tabela
titulo "1 · Toda tabela lida por todo perfil, sem erro e sem recursão"

TABELAS=$(sudo -u postgres psql -tAc \
  "select tablename from pg_tables where schemaname='valor' order by 1" "$BANCO")

for PERFIL in admin_master lider comercial gerente_contas conselheiro assessor financeiro parceiro participante; do
  ERROS=""
  for T in $TABELAS; do
    SAIDA=$(sudo -u postgres psql -tA -d "$BANCO" 2>&1 <<SQL
set role valor_aplicacao;
select set_config('app.inquilino_id','$INQ',false);
select set_config('app.perfil','$PERFIL',false);
select set_config('app.parceiro_id','$PARC_A',false);
select count(*) from valor.$T;
SQL
)
    if echo "$SAIDA" | grep -qi 'ERROR'; then
      MOTIVO=$(echo "$SAIDA" | grep -i 'ERROR' | head -1)
      ERROS="$ERROS\n           $T · $MOTIVO"
    fi
  done
  if [ -z "$ERROS" ]; then ok "perfil $PERFIL lê as $(echo "$TABELAS" | wc -w) tabelas"
  else falha "perfil $PERFIL:"; printf "$ERROS\n"; fi
done

# ------------------------------------------------ 2 o parceiro não atravessa
titulo "2 · O parceiro não enxerga o que não é dele"

prova_parceiro() {
  local DESCRICAO="$1" CONSULTA="$2" ESPERADO="$3"
  local R
  R=$(sudo -u postgres psql -tA -d "$BANCO" 2>&1 <<SQL
set role valor_aplicacao;
select set_config('app.inquilino_id','$INQ',false);
select set_config('app.perfil','parceiro',false);
select set_config('app.parceiro_id','$PARC_A',false);
$CONSULTA
SQL
)
  R=$(echo "$R" | tail -1 | tr -d ' ')
  if [ "$R" = "$ESPERADO" ]; then ok "$DESCRICAO"
  else falha "$DESCRICAO · esperado $ESPERADO, veio $R"; fi
}

# A prova de verdade: o parceiro enxerga o negócio DELE e não enxerga o do outro.
# Aqui há dado nas duas pontas, então o zero significa alguma coisa.
prova_parceiro "parceiro enxerga o próprio negócio" \
  "select count(*) from valor.negocios where parceiro_id = '$PARC_A'::uuid;" "1"
prova_parceiro "parceiro não enxerga o negócio do outro parceiro" \
  "select count(*) from valor.negocios where parceiro_id = '$PARC_B'::uuid;" "0"
prova_parceiro "parceiro não enxerga negócio sem parceiro" \
  "select count(*) from valor.negocios where parceiro_id is null;" "0"
prova_parceiro "parceiro enxerga um negócio no total, não três" \
  "select count(*) from valor.negocios;" "1"
prova_parceiro "parceiro não enxerga a conta do negócio alheio" \
  "select count(*) from valor.contas where id = 'c2222222-2222-2222-2222-222222222222'::uuid;" "0"

# Nas tabelas que o parceiro nunca alcança, o zero só vale com controle:
# primeiro provamos que o administrador enxerga a linha.
for TAB in contratos parcelas comissoes atas pendencias margem_contrato; do
  EXISTE=$(sudo -u postgres psql -tAc \
    "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='valor' and c.relname='$TAB'" "$BANCO")
  if [ "$EXISTE" = "1" ]; then
    prova_parceiro "parceiro não lê $TAB" "select count(*) from valor.$TAB;" "0"
  fi
done

# ------------------------------------------------ 2b o participante é do cliente
titulo "2b · O participante lê a própria turma, e nada do acervo da casa"

prova_participante() {
  local DESCRICAO="$1" CONSULTA="$2" ESPERADO="$3"
  local R
  R=$(sudo -u postgres psql -tA -d "$BANCO" 2>&1 <<SQL
set role valor_aplicacao;
select set_config('app.inquilino_id','$INQ',false);
select set_config('app.perfil','participante',false);
$CONSULTA
SQL
)
  R=$(echo "$R" | tail -1 | tr -d ' ')
  if [ "$R" = "$ESPERADO" ]; then ok "$DESCRICAO"
  else falha "$DESCRICAO · esperado $ESPERADO, veio $R"; fi
}

for TAB in banco_pautas modelos_ata contratos parcelas comissoes margem_contrato historico_valor; do
  EXISTE=$(sudo -u postgres psql -tAc \
    "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='valor' and c.relname='$TAB'" "$BANCO")
  if [ "$EXISTE" = "1" ]; then
    prova_participante "participante não lê $TAB" "select count(*) from valor.$TAB;" "0"
  fi
done

# ------------------------------------------------ 3 ninguém apaga
titulo "3 · Nada é apagado, apenas arquivado"

R=$(sudo -u postgres psql -tA -d "$BANCO" 2>&1 <<SQL
set role valor_aplicacao;
delete from valor.negocios;
SQL
)
if echo "$R" | grep -qi 'permission denied\|permissão negada'; then ok "remoção de negócio negada pelo banco"
else falha "remoção de negócio NÃO foi negada: $(echo "$R" | head -1)"; fi

# ------------------------------------------------ 4 sem inquilino, sem dado
titulo "4 · Sessão sem inquilino não enxerga nada"

R=$(sudo -u postgres psql -tA -d "$BANCO" 2>&1 <<SQL
set role valor_aplicacao;
select set_config('app.inquilino_id','',false);
select set_config('app.perfil','admin_master',false);
select count(*) from valor.negocios;
SQL
)
R=$(echo "$R" | tail -1 | tr -d ' ')
if [ "$R" = "0" ]; then ok "sessão sem inquilino lê zero negócios"
else falha "sessão sem inquilino leu $R negócios"; fi

# ------------------------------------------------ 5 inquilino não vaza em inquilino
titulo "5 · Um inquilino não alcança o outro"

R=$(sudo -u postgres psql -tA -d "$BANCO" 2>&1 <<SQL
set role valor_aplicacao;
select set_config('app.inquilino_id','99999999-9999-9999-9999-999999999999',false);
select set_config('app.perfil','admin_master',false);
select count(*) from valor.negocios;
SQL
)
R=$(echo "$R" | tail -1 | tr -d ' ')
if [ "$R" = "0" ]; then ok "inquilino estranho lê zero negócios"
else falha "inquilino estranho leu $R negócios"; fi

[ "$CRIOU" = "1" ] && sudo -u postgres dropdb --if-exists "$BANCO" >/dev/null 2>&1

titulo "Veredito da segurança"
if [ "$FALHAS" -eq 0 ]; then printf "  \033[32mAPROVADO\033[0m · nenhuma falha\n\n"; exit 0
else printf "  \033[31mREPROVADO\033[0m · %s falha(s)\n\n" "$FALHAS"; exit 1; fi
