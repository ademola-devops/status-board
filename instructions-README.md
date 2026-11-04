## Setup

### 1. AWS
- EC2 `t3.medium`, Ubuntu Server 24.04 LTS (x86_64), 20 GB gp3
- Security group inbound:
  - 22 from **your IP**
  - 8080 from GitHub webhook ranges (`hooks` in https://api.github.com/meta) and your IP
  - 80 and 8081 from your IP (or anywhere, to share the app)
  - Keep 6443 and 10250 **closed**

### 2. Server
```bash
git clone https://github.com/ademola-devops/status-board.git
cd status-board
bash setup/ec2-setup.sh
```

### 3. Jenkins (`http://<ec2-public-ip>:8080`)
- Unlock with the printed password, install suggested plugins, create admin user
- Credential: **Username with password**, ID `dockerhub-creds`, username `ademoladevops`, password = DockerHub access token (Read & Write)
- New Item → **Pipeline** `status-board`
  - Tick **GitHub hook trigger for GITScm polling**
  - Pipeline script from SCM → Git → repo HTTPS URL → branch `*/main` → script path `Jenkinsfile`
- Run **Build Now** once (registers the webhook trigger)

### 4. GitHub webhook
Repo → Settings → Webhooks → Add:
- Payload URL: `http://<ec2-public-ip>:8080/github-webhook/`
- Content type: `application/json`, event: push

## Tests to prove it works

| Test | How | Expected |
|---|---|---|
| Push triggers pipeline | Edit `MESSAGE` in `k8s/config-staging.yaml`, push | Build starts, waits at approval |
| Config per environment | Open both URLs | Different environment names and messages |
| Promotion | Click **Promote** | Production shows the new version |
| Failed release is blocked | Change `/healthz` in `backend/index.js` to return 500, push | Staging rolls back, production untouched |
| Self-healing | `kubectl -n production delete pod -l app=backend --wait=false` | Page keeps working, new pod appears |
| No secrets in repo | `git grep -nE "dckr_pat|BEGIN .*PRIVATE KEY"` | No matches |

## Useful commands
```bash
kubectl get pods,svc -n staging
kubectl get pods,svc -n production
kubectl -n production rollout history deployment/backend
./scripts/rollback.sh production
```

## Cost control
Stop the instance after each session. The public IP changes on start, so update the webhook URL (or use an Elastic IP).
