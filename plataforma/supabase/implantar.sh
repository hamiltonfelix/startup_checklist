#!/usr/bin/env bash
# Implantação da Plataforma de Valor no Supabase.
#
# Uso:
#   export SUPABASE_TOKEN='sbp_...'          # token pessoal, nunca vai para o repositório
#   bash plataforma/supabase/implantar.sh listar          # mostra organizações e projetos
#   bash plataforma/supabase/implantar.sh criar "Nome"    # cria o projeto em São Paulo
#   bash plataforma/supabase/implantar.sh migrar <ref>    # aplica as migrações
#   bash plataforma/supabase/implantar.sh chaves <ref>    # devolve endereço e chave pública
#
# Este contêiner tem as portas de banco bloqueadas, então tudo passa pela API de
# gestão por HTTPS, que responde. Nenhuma credencial é escrita em arquivo.
set -uo pipefail

API="https://api.supabase.com/v1"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${SUPABASE_TOKEN:?defina SUPABASE_TOKEN antes de rodar}"

chamar() {
  local metodo="$1" caminho="$2" corpo="${3:-}"
  if [ -n "$corpo" ]; then
    curl -sS -X "$metodo" "$API$caminho" \
      -H "Authorization: Bearer $SUPABASE_TOKEN" \
      -H "Content-Type: application/json" -d "$corpo"
  else
    curl -sS -X "$metodo" "$API$caminho" -H "Authorization: Bearer $SUPABASE_TOKEN"
  fi
}

case "${1:-}" in

listar)
  echo "Organizações:"
  chamar GET /organizations | python3 -c "
import json,sys
for o in json.load(sys.stdin):
    print('  %-30s %s' % (o.get('name'), o.get('id')))"
  echo
  echo "Projetos:"
  chamar GET /projects | python3 -c "
import json,sys
d=json.load(sys.stdin)
if not d: print('  nenhum')
for p in d:
    print('  %-28s %-22s %-14s %s' % (p.get('name'), p.get('id'), p.get('region'), p.get('status')))"
  ;;

criar)
  NOME="${2:-Plataforma de Valor}"
  ORG=$(chamar GET /organizations | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['id'] if d else '')")
  [ -z "$ORG" ] && { echo "Nenhuma organização encontrada nesta conta."; exit 1; }
  SENHA="$(python3 -c "
import secrets, string
a = string.ascii_letters + string.digits
print(''.join(secrets.choice(a) for _ in range(40)))")"
  echo "Organização: $ORG"
  echo "Região: sa-east-1, São Paulo"
  echo
  echo "GUARDE ESTA SENHA DO BANCO AGORA. Ela não é mostrada de novo:"
  echo "    $SENHA"
  echo
  chamar POST /projects "$(python3 -c "
import json,sys
print(json.dumps({'name': sys.argv[1], 'organization_id': sys.argv[2],
                  'region': 'sa-east-1', 'db_pass': sys.argv[3], 'plan': 'free'}))" "$NOME" "$ORG" "$SENHA")"
  echo
  ;;

migrar)
  REF="${2:?informe a referência do projeto}"
  TOTAL=0; FALHOU=0
  for f in $(ls "$RAIZ"/migracoes/*.sql | sort); do
    NOME="$(basename "$f")"
    printf "%-42s" "$NOME"
    CORPO=$(python3 -c "
import json,sys
print(json.dumps({'query': open(sys.argv[1], encoding='utf-8').read()}))" "$f")
    RESP=$(chamar POST "/projects/$REF/database/query" "$CORPO")
    if echo "$RESP" | grep -qi '"message"\|"error"'; then
      echo "FALHOU"; echo "$RESP" | head -c 500; echo; FALHOU=1; break
    else
      echo "ok"; TOTAL=$((TOTAL+1))
    fi
  done
  echo
  echo "$TOTAL migrações aplicadas."
  [ "$FALHOU" = "1" ] && exit 1
  echo "Conferindo o que nasceu no banco:"
  chamar POST "/projects/$REF/database/query" '{"query":"select (select count(*) from pg_tables where schemaname=''valor'') as tabelas, (select count(*) from pg_views where schemaname=''valor'') as views, (select count(*) from pg_policies where schemaname=''valor'') as politicas"}'
  echo
  ;;

chaves)
  REF="${2:?informe a referência do projeto}"
  echo "Endereço: https://$REF.supabase.co"
  chamar GET "/projects/$REF/api-keys" | python3 -c "
import json,sys
for k in json.load(sys.stdin):
    nome = k.get('name')
    if nome == 'anon':
        print('Chave pública, pode ir para o ambiente da interface:')
        print('  ' + k.get('api_key',''))
    else:
        print('Chave %s: existe, e NAO sai daqui. Nunca no repositorio, nunca no navegador.' % nome)"
  ;;

*)
  sed -n '2,14p' "$0" | sed 's/^# //; s/^#//'
  ;;
esac
