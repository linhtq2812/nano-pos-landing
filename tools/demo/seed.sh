#!/usr/bin/env bash
# Demo shop "Tạp hoá Hoa Mai" for landing screenshots. LOCAL Supabase only.
# Usage: bash tools/demo/seed.sh   (run from anywhere; nano-pos-db must be ../nano-pos-db)
# Re-running is safe: fixed ids, on conflict do nothing; orders are only added once.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
db_repo="${NANO_POS_DB:-$here/../../../nano-pos-db}"
status="$(cd "$db_repo" && supabase status -o json 2>/dev/null)"
api="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["API_URL"])' <<<"$status")"
key="$(python3 -c 'import json,sys;print(json.load(sys.stdin)["SERVICE_ROLE_KEY"])' <<<"$status")"
if [ "$api" != "http://127.0.0.1:54321" ]; then
  echo "refusing: API_URL is '$api', expected local http://127.0.0.1:54321" >&2; exit 1
fi
email="${DEMO_EMAIL:-demo-owner@nanopos.local}"
password="${DEMO_PASSWORD:-demo-landing-2026}"

# Create the owner through the Auth admin API (idempotent: 422 = already exists).
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$api/auth/v1/admin/users" \
  -H "apikey: $key" -H "Authorization: Bearer $key" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$email\",\"password\":\"$password\",\"email_confirm\":true}" | grep -qE '^(200|201|422)$' \
  || { echo "could not create $email" >&2; exit 1; }

if [ "${DEMO_RESET:-0}" = 1 ]; then
  # Superuser delete of the demo shop's orders only; report triggers mark the rollups dirty.
  docker exec -i supabase_db_nano-pos-db psql -q -U postgres -v ON_ERROR_STOP=1 -c \
    "delete from public.sale_orders where shop_id = 'd0000000-0000-4000-8000-000000000002'"
fi
docker exec -i supabase_db_nano-pos-db psql -q -U postgres -v ON_ERROR_STOP=1 -v email="$email" < "$here/seed.sql"
echo "demo ready: $email / $password"
