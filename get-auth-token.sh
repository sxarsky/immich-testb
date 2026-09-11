#!/usr/bin/env bash
# Get an Immich bearer access token for eval use.
#
# Mirrors pellepedro-testbot/immich-testb's deployment-testbot/get-token.sh
# (the proven recipe for this fork): admin sign-up (idempotent — a second
# call 400s once the admin exists, which is expected and ignored) followed
# by login, printing the accessToken to stdout.
#
# Credentials are fixed eval-only defaults, overridable via env vars. The same
# pair is handed to browser tests through the scenario's uiCredentials, so
# SKYRAMP_UI_USERNAME/SKYRAMP_UI_PASSWORD override them when set.
#
# The script also marks onboarding complete. Without that, web/src/routes/auth/
# login/+page.svelte sends the admin to /auth/onboarding instead of /photos, and
# every browser test lands on the onboarding wizard. Two flags gate it: the
# server-wide one (POST /api/system-metadata/admin-onboarding) and the per-user
# one (PUT /api/users/me/onboarding).
#
# Usage: SKYRAMP_TEST_TOKEN=$(bash get-auth-token.sh)
set -euo pipefail

IMMICH_HOST="${IMMICH_HOST:-http://localhost:2285}"
ADMIN_EMAIL="${SKYRAMP_UI_USERNAME:-${IMMICH_ADMIN_EMAIL:-admin@immich.test}}"
ADMIN_PASSWORD="${SKYRAMP_UI_PASSWORD:-${IMMICH_ADMIN_PASSWORD:-EvalPass123!}}"
ADMIN_NAME="Immich Admin"

# First run creates the admin; subsequent runs 400 ("already initialized" or
# similar) which is expected once the account exists — ignored either way.
curl -sf -m 10 -X POST "${IMMICH_HOST}/api/auth/admin-sign-up" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\",\"name\":\"${ADMIN_NAME}\"}" \
  >/dev/null 2>&1 || true

LOGIN_RESPONSE_BODY=$(mktemp)
trap 'rm -f "${LOGIN_RESPONSE_BODY}"' EXIT

LOGIN_STATUS=$(
  curl -sS -m 10 -o "${LOGIN_RESPONSE_BODY}" -w '%{http_code}' -X POST "${IMMICH_HOST}/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}"
) || { echo "ERROR: network failure contacting ${IMMICH_HOST}/api/auth/login" >&2; exit 1; }

if [[ "${LOGIN_STATUS}" != "201" && "${LOGIN_STATUS}" != "200" ]]; then
  echo "ERROR: Immich login failed (HTTP ${LOGIN_STATUS})" >&2
  cat "${LOGIN_RESPONSE_BODY}" >&2
  exit 1
fi

ACCESS_TOKEN=$(python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])" < "${LOGIN_RESPONSE_BODY}")

if [[ -z "${ACCESS_TOKEN}" || "${ACCESS_TOKEN}" == "None" ]]; then
  echo "ERROR: could not extract accessToken from Immich login response" >&2
  cat "${LOGIN_RESPONSE_BODY}" >&2
  exit 1
fi

# Mark onboarding complete so a browser login lands on /photos. Both calls are
# idempotent, and neither is fatal for API-only runs.
curl -sf -m 10 -X POST "${IMMICH_HOST}/api/system-metadata/admin-onboarding" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{"isOnboarded":true}' \
  >/dev/null 2>&1 || true

curl -sf -m 10 -X PUT "${IMMICH_HOST}/api/users/me/onboarding" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{"isOnboarded":true}' \
  >/dev/null 2>&1 || true

# Turn the new-version banner off. The web app opens a modal dialog ("A new
# version of Immich is available") over every signed-in page whenever the
# version check finds a newer release, and its overlay swallows clicks, so a
# browser test fails on whichever element it tries to touch first.
CONFIG_BODY=$(mktemp)
if curl -sf -m 10 "${IMMICH_HOST}/api/system-config" -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | python3 -c 'import json,sys; c=json.load(sys.stdin); c["newVersionCheck"]["enabled"]=False; json.dump(c,sys.stdout)' \
  > "${CONFIG_BODY}" 2>/dev/null; then
  curl -sf -m 10 -X PUT "${IMMICH_HOST}/api/system-config" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H 'Content-Type: application/json' \
    --data-binary "@${CONFIG_BODY}" \
    >/dev/null 2>&1 || true
fi
rm -f "${CONFIG_BODY}"

# Skyramp's client sends: Authorization: Bearer <SKYRAMP_TEST_TOKEN>
echo "${ACCESS_TOKEN}"
