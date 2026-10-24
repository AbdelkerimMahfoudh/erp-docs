#!/usr/bin/env bash
# TSX-MR production — READ-ONLY reconciliation before any change (docs/103 §2).
#
#   scp -q reconcile-readonly.sh tsxmr-app-01:/tmp/ && \
#   ssh -q -t tsxmr-app-01 "umask 077; bash /tmp/reconcile-readonly.sh > /tmp/erp-reconcile.txt 2>&1; rm -f /tmp/reconcile-readonly.sh"
#   scp -q tsxmr-app-01:/tmp/erp-reconcile.txt . ; ssh -q tsxmr-app-01 "rm -f /tmp/erp-reconcile.txt"
#
# Changes nothing. Prints no secret, password hash, token, setup code, address, name, phone or email: counts, states,
# commits and file names only. Sudo is asked once (on the terminal, never captured) for the journal.
set -u
umask 077
cd /srv/erp-production/erp-backend || { echo "FATAL: no /srv/erp-production/erp-backend"; exit 1; }
S=""; docker ps >/dev/null 2>&1 || S="sudo"
kv() { grep -E "^$1=" deploy/production/stack.env 2>/dev/null | head -1 | cut -d= -f2- | tr -d "'\""; }
BACKUP_DIR=$(kv BACKUP_DIR); WEB_DIR=$(kv WEB_DIR); API_ENV=$(kv API_ENV_FILE)
set -a; . "$BACKUP_DIR/current-images.env" 2>/dev/null; set +a
C() { $S docker compose -p erp-production --env-file deploy/production/stack.env -f deploy/docker-compose.production.yml "$@"; }
SQL() { C exec -T db sh -c 'MYSQL_PWD="$(cat /secrets/mysql_root.pw)" mysql -uroot -N -B phonestore'; }
h() { echo; echo "=== $* ==="; }

h "1 API image and commit"
git log -1 --format='checkout %h %s'; echo "dirty files: $(git status --short | wc -l)"
echo "current: ${API_IMAGE:-unknown}"; echo "tools:   ${TOOLS_IMAGE:-unknown}"
C ps --format 'table {{.Service}}\t{{.Status}}\t{{.Image}}'
h "2 migrations"
curl -s https://api.tsxmr.com/api/health/ready; echo
h "3 test-site releases"
for s in app console; do echo "$s current -> $($S readlink "$WEB_DIR/$s/current" 2>/dev/null || echo none); releases: $($S ls "$WEB_DIR/$s/releases" 2>/dev/null | tr '\n' ' ')"; done
echo "enabled: $($S ls "$WEB_DIR/enabled" 2>/dev/null | tr '\n' ' ')"
echo "-- deployments.log (last 8)"; $S tail -8 "$BACKUP_DIR/deployments.log"
h "4-8 accounts, businesses, access (counts and states only)"
SQL <<'EOF'
SELECT 'platform_admins', COUNT(*), 'mfa_enrolled', COALESCE(SUM(mfa_enabled_at IS NOT NULL),0), 'active', COALESCE(SUM(is_active),0) FROM platform_admins;
SELECT 'platform_admin_live_sessions', COUNT(*) FROM platform_admin_sessions WHERE revoked_at IS NULL AND expires_at > NOW();
SELECT 'companies', COUNT(*), 'test', COALESCE(SUM(is_test=1),0), 'customer', COALESCE(SUM(is_test=0),0) FROM companies;
SELECT 'users', COUNT(*), 'active', COALESCE(SUM(is_active=1 AND deleted_at IS NULL),0) FROM users;
SELECT 'branches_stores', COUNT(*) FROM branches;
SELECT 'per_business', IF(c.is_test=1,'test','customer'), (SELECT COUNT(*) FROM users u WHERE u.company_id=c.id AND u.deleted_at IS NULL), (SELECT COUNT(*) FROM branches b WHERE b.company_id=c.id),
       'sub', s.status, 'complimentary', s.is_complimentary, 'grant_active', (s.is_complimentary=1 AND (s.complimentary_until IS NULL OR s.complimentary_until > NOW())),
       'paid_period_end_set', s.current_period_end IS NOT NULL,
       'setup_code_redeemed', (SELECT COUNT(*) FROM owner_invitations i WHERE i.company_id=c.id AND i.accepted_at IS NOT NULL),
       'setup_code_unspent_live', (SELECT COUNT(*) FROM owner_invitations i WHERE i.company_id=c.id AND i.accepted_at IS NULL AND i.revoked_at IS NULL AND i.expires_at > NOW()),
       'subscription_payments', (SELECT COUNT(*) FROM subscription_payments p WHERE p.company_id=c.id)
  FROM companies c LEFT JOIN subscriptions s ON s.company_id=c.id ORDER BY c.created_at;
SELECT 'sales', COUNT(*) FROM sales;
SELECT 'staff_invitations', COUNT(*) FROM staff_invitations;
SELECT 'whatsapp_messages', status, COUNT(*) FROM whatsapp_messages GROUP BY status;
SELECT 'email_messages', status, COUNT(*) FROM email_messages GROUP BY status;
SELECT 'subscription_notices', COUNT(*), 'accepted', COALESCE(SUM(accepted_at IS NOT NULL),0) FROM subscription_notices;
SELECT 'audit_last8', action, created_at FROM platform_audit_events ORDER BY created_at DESC LIMIT 8;
EOF
h "9 channels, activation, registration"
$S grep -E '^(CUSTOMER_ACTIVATION|EMAIL_CHANNEL|WHATSAPP_CHANNEL|WHATSAPP_LIVE_SENDS|CORS_ORIGINS|PORTAL_ORIGIN|NODE_ENV)=' "$API_ENV"
printf 'public sign-up (POST auth/register, empty body): HTTP '; curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -d '{}' https://api.tsxmr.com/api/v1/auth/register
h "10 backups and rollback point"
$S ls -l "$BACKUP_DIR" | grep -E '\.age$' | awk '{print $5, $9}'
echo "rollback image: the previous= field of the last deploy line above"
h "11 leftovers"
echo "/dev/shm erp/age files: $(ls /dev/shm 2>/dev/null | grep -c -i -E 'erp|age')"
echo "/tmp erp files: $(ls /tmp 2>/dev/null | grep -i -E 'erp|setup|admin|reconcile' | tr '\n' ' ')"
echo "home: $(ls -A ~ | tr '\n' ' ')"
h "12 edge: 401 headers without the password, certificates"
for u in https://erp-test.tsxmr.com/ https://dukan-test.tsxmr.com/admin https://tsxmr.com/admin; do
  printf '%s  ' "$u"; curl -s -o /dev/null -D - "$u" | grep -i -E '^(HTTP/|x-robots-tag|www-authenticate)' | tr -d '\r' | tr '\n' ' '; echo
done
for n in api.tsxmr.com erp-test.tsxmr.com dukan-test.tsxmr.com; do printf '%s  ' "$n"; echo | timeout 10 openssl s_client -connect "$n:443" -servername "$n" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null; done
h "13 logins since 2026-10-21 (addresses masked; needs sudo)"
mask() { sed -E 's/([0-9]{1,3}\.[0-9]{1,3})\.[0-9]{1,3}\.[0-9]{1,3}/\1.x.x/g'; }
sudo journalctl -u ssh --since 2026-10-21 --no-pager 2>/dev/null | grep -E 'Accepted' | awk '{print "   " $1,$2,$3,$6,$7,$8,$9,$11}' | mask | tail -20
echo "failed/invalid ssh attempts: $(sudo journalctl -u ssh --since 2026-10-21 --no-pager 2>/dev/null | grep -c -E 'Failed|Invalid user')"
echo; echo "RECONCILIATION DONE $(date -u +%FT%TZ)"
