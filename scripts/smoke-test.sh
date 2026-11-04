#!/bin/bash
# Usage: ./scripts/smoke-test.sh <staging|production> <expected-tag>
# Checks the environment through its public entry point (the frontend LoadBalancer).
set -euo pipefail

ENV="${1:?environment required}"
TAG="${2:?expected tag required}"

case "$ENV" in
  staging)    URL="http://localhost:8081" ;;
  production) URL="http://localhost:80" ;;
  *) echo "Unknown environment: $ENV"; exit 1 ;;
esac

echo "==> Smoke testing $ENV at $URL"

for i in $(seq 1 20); do
  if curl -fsS "$URL/healthz" >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for $URL ($i/20)"
  sleep 3
done

curl -fsS "$URL/healthz" >/dev/null || { echo "FAIL: frontend /healthz"; exit 1; }
echo "PASS: frontend is healthy"

BODY=$(curl -fsS "$URL/api/info") || { echo "FAIL: /api/info unreachable"; exit 1; }
echo "Response: $BODY"

echo "$BODY" | grep -q "\"environment\":\"$ENV\"" || { echo "FAIL: wrong environment"; exit 1; }
echo "PASS: environment is $ENV"

echo "$BODY" | grep -q "\"version\":\"$TAG\"" || { echo "FAIL: expected version $TAG"; exit 1; }
echo "PASS: version is $TAG"
