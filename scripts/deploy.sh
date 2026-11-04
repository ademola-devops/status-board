#!/bin/bash
# Usage: ./scripts/deploy.sh <staging|production> <image-tag>
# Deploys both components to one environment. Rolls back automatically if a rollout fails.
set -euo pipefail

ENV="${1:?environment required: staging or production}"
TAG="${2:?image tag required}"

case "$ENV" in
  staging)    PORT=8081 ;;
  production) PORT=80 ;;
  *) echo "Unknown environment: $ENV"; exit 1 ;;
esac

if [[ ! "$TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid tag: $TAG"; exit 1
fi

cd "$(dirname "$0")/.."

render() {
  sed -e "s|NAMESPACE|${ENV}|g" \
      -e "s|IMAGE_TAG|${TAG}|g" \
      -e "s|FRONTEND_PORT|${PORT}|g" "$1"
}

echo "==> Deploying tag $TAG to $ENV (frontend on port $PORT)"
kubectl apply -f "k8s/config-${ENV}.yaml"

# ConfigMap changes only reach pods on restart, so record them in the pod template
CONFIG_HASH=$(sha256sum "k8s/config-${ENV}.yaml" | cut -c1-12)

FAILED=0
for COMPONENT in backend frontend; do
  render "k8s/${COMPONENT}.yaml" | kubectl apply -f -
  kubectl -n "$ENV" patch deployment "$COMPONENT" -p \
    "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"config-hash\":\"${CONFIG_HASH}\"}}}}}" >/dev/null
  if ! kubectl -n "$ENV" rollout status "deployment/${COMPONENT}" --timeout=120s; then
    FAILED=1
    break
  fi
done

if [ "$FAILED" -eq 1 ]; then
  ./scripts/rollback.sh "$ENV"
  exit 1
fi

kubectl -n "$ENV" get pods,svc
