# Status Board

A two-tier app released through a staged CI/CD pipeline:
**GitHub → Jenkins → DockerHub → Kubernetes (staging) → approval → Kubernetes (production)**.

The page shows the running version, the environment, and which pod answered.
Refresh it and watch the pod name change: that is the Service load balancing across replicas.

## Architecture

| Piece | What it is | Why |
|---|---|---|
| `backend/` | Express API: `/api/info`, `/healthz` | Reports version, environment, hostname |
| `frontend/` | nginx serving a page that polls `/api/info` | nginx forwards `/api/` to the backend Service |
| `k8s/` | Deployments, Services, one ConfigMap per environment | Same image, different config per environment |
| `scripts/deploy.sh` | Applies manifests, waits for rollout, rolls back on failure | The only place `kubectl apply` runs |
| `scripts/smoke-test.sh` | Checks health, environment and version | Gates promotion to production |
| `scripts/rollback.sh` | `kubectl rollout undo` for both components | Returns to the last working version |
| `Jenkinsfile` | The pipeline | Build once, deploy many |
| `setup/ec2-setup.sh` | One-time server setup | Docker, Java 21, Jenkins, k3s |

### Environments

| Environment | Namespace | URL |
|---|---|---|
| Staging | `staging` | `http://<ec2-public-ip>:8081` |
| Production | `production` | `http://<ec2-public-ip>` |

## Pipeline stages

1. **Checkout** — tag = short git commit SHA
2. **Build Images** — backend and frontend
3. **Push to DockerHub** — `ademoladevops/status-backend`, `ademoladevops/status-frontend`
4. **Deploy to Staging** — rolls back automatically if pods never become ready
5. **Smoke Test Staging** — `/healthz`, correct environment, correct version
6. **Approve Release** — manual click in Jenkins (30 min timeout)
7. **Deploy to Production** — the same images, no rebuild
8. **Smoke Test Production** — rolls back production if it fails

