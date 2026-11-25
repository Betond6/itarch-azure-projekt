#!/usr/bin/env bash
# Futtatás a vm-client gépen:
#   export DB_PASSWORD='...'   # a jelszót NE írjátok bele a fájlba
#   ./scripts/test.sh | tee teszt-eredmeny.log
APP=10.20.1.4
APP_USER=${APP_USER:-vmclient}

echo "== F1 SSH (vm-client -> vm-app) =="
ssh -o ConnectTimeout=5 "$APP_USER@$APP" 'hostname; docker ps --format "{{.Names}} {{.Status}}" 2>/dev/null || true'

echo "== F2 HTTP (Nginx kontener) =="
curl -s -o /dev/null -w 'HTTP %{http_code}\n' "http://$APP/"

echo "== F3 REST API =="
curl -s "http://$APP:8000/api/health"; echo
curl -s -X POST -H 'Content-Type: application/json' -d '{"name":"teszt"}' "http://$APP/api/items"; echo
curl -s "http://$APP/api/items" | jq .

echo "== F4 PostgreSQL =="
PGPASSWORD="$DB_PASSWORD" psql -h "$APP" -U projekt -d projektdb -c 'SELECT count(*) FROM items;'

echo "== F5 fajlatvitel (scp) =="
echo "teszt $(date)" > f.txt
scp -q f.txt "$APP_USER@$APP:~/"
sha256sum f.txt
ssh "$APP_USER@$APP" sha256sum f.txt

echo "== Negativ tesztek =="
nc -zvw3 "$APP" 6379 || echo "6379: nem elerheto (vart eredmeny)"
nmap -Pn -p 22,80,443,3306,5432,6379,8000 "$APP"
