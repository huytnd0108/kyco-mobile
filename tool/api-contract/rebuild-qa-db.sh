#!/usr/bin/env bash
# Rebuild the mobile-QA database from the CURRENT backend schema (worktree
# kyco-wt/mobile-qa) — used after schema-changing merges (e.g. the provider→tasker
# rename). Lab-only: refuses any DB not named kyco_wapi_mobileqa.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
# ids of the admin-money fixtures (scripts/seed-qa-money-fixtures.ts), read by admin-money.mjs / ws7-retest2.mjs
FIXTURES_JSON=${QA_MONEY_FIXTURES:-$HERE/.qa-money-fixtures.json}
WT=${WT:-/home/bi/w/AppDroid1-ori/kyco-wt/mobile-qa}
DB=kyco_wapi_mobileqa; ROLE=kyco_mqa
psql_su() { docker exec -i appdroid-pg psql -U postgres -v ON_ERROR_STOP=1 "$@"; }
psql_su -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='$DB'" >/dev/null
psql_su -c "DROP DATABASE IF EXISTS $DB" -c "CREATE DATABASE $DB OWNER $ROLE" \
        -c "ALTER ROLE $ROLE IN DATABASE $DB SET search_path TO kycore, public" -c "ALTER ROLE $ROLE CONNECTION LIMIT 30"
cd "$WT"; set -a; . ./.env.local; set +a
# supported fresh-DB order (ea3de91): bootstrap → migrate → seed
npm run -s db:bootstrap
npm run -s db:migrate
npm run -s db:seed
timeout 300 npx tsx scripts/seed-btaskee-catalog.ts >/dev/null
npx tsx scripts/create-admin.ts admin@qa.local Admin12345qa 'QA Admin' >/dev/null
npx tsx scripts/create-admin.ts tasker@qa.local 'TaskerQa12345!' QATasker >/dev/null
psql_su -d $DB <<'SQL'
update kycore.users set role='tasker', phone='+84901110001', phone_verified_at=now() where email='tasker@qa.local';
update kycore.users set phone='+84901110002', phone_verified_at=now() where email='demo@demo.local';
update kycore.taskers set user_account_id=(select id from kycore.users where email='tasker@qa.local'), is_verified=true, is_banned=false, suspended_until=null where id=(select min(id) from kycore.taskers);
insert into kycore.site_settings(key,value,updated_at) values ('feature.api_mobile_v1_enabled','true',now()) on conflict (key) do update set value='true';
select u.email,u.role,t.id as tasker_id from kycore.users u left join kycore.taskers t on t.user_account_id=u.id order by u.id;
SQL
# admin-money fixtures (4998929, lab-only + idempotent): QA customer/tasker, paid payments,
# damage claims, disputes, payout, wallet balances. Default clearing 1,000,000 for the harnesses;
# re-run with --clearing=0 for the MQA-49 repro. Prints ids as JSON → $FIXTURES_JSON.
npx tsx scripts/seed-qa-money-fixtures.ts > "$FIXTURES_JSON.tmp"
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$FIXTURES_JSON.tmp" && mv "$FIXTURES_JSON.tmp" "$FIXTURES_JSON"
echo "money fixtures → $FIXTURES_JSON"; cat "$FIXTURES_JSON"
