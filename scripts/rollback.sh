#!/bin/bash
# Usage: ./scripts/rollback.sh <staging|production>
# Returns both Deployments in an environment to their previous revision.
set -uo pipefail

ENV="${1:?environment required}"

echo "==> Rolling back $ENV to the previous version"
for COMPONENT in backend frontend; do
  if kubectl -n "$ENV" rollout history "deployment/${COMPONENT}" 2>/dev/null | grep -qE '^2'; then
    kubectl -n "$ENV" rollout undo "deployment/${COMPONENT}"
    kubectl -n "$ENV" rollout status "deployment/${COMPONENT}" --timeout=120s
  else
    echo "No previous revision for $COMPONENT in $ENV (first deploy), nothing to roll back to"
  fi
done

kubectl -n "$ENV" get deploy -o wide
