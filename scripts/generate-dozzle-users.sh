#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${DOZZLE_ADMIN_USER:?Set DOZZLE_ADMIN_USER in .env}"
: "${DOZZLE_ADMIN_PASSWORD:?Set DOZZLE_ADMIN_PASSWORD in .env}"

mkdir -p config/dozzle

docker run -i --rm amir20/dozzle:latest generate "$DOZZLE_ADMIN_USER" \
  --password "$DOZZLE_ADMIN_PASSWORD" \
  --name "Admin" \
  > config/dozzle/users.yml

echo "Wrote config/dozzle/users.yml for user: $DOZZLE_ADMIN_USER"
