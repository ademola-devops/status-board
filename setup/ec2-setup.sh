#!/bin/bash
# One-time setup for a fresh Ubuntu 24.04 EC2 instance (t3.medium).
# Run as the ubuntu user:  bash setup/ec2-setup.sh
# Installs: Docker, Java 21, Jenkins, k3s. Contains no secrets.
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "Run as the ubuntu user, not root."; exit 1
fi

echo "==> [1/6] 2 GB swap (4 GB RAM is tight for Jenkins + Kubernetes)"
if ! swapon --show | grep -q '/swapfile'; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

echo "==> [2/6] Docker, Git, Java 21"
sudo apt-get update
sudo apt-get install -y docker.io git curl wget gnupg fontconfig openjdk-21-jre-headless
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

echo "==> [3/6] Jenkins"
sudo wget -qO /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
EXPECTED="5E386EADB55F01504CAE8BCF7198F4B714ABFC68"
ACTUAL=$(gpg --show-keys --with-colons /usr/share/keyrings/jenkins-keyring.asc | awk -F: '/^fpr/ {print $10; exit}')
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "Jenkins key fingerprint mismatch: $ACTUAL"; exit 1
fi
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
sudo apt-get update
sudo apt-get install -y jenkins
sudo usermod -aG docker jenkins

echo "==> [4/6] k3s (Traefik off so the app can own ports 80 and 8081)"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
until sudo k3s kubectl get nodes 2>/dev/null | grep -q ' Ready'; do sleep 3; done

echo "==> [5/6] Kubeconfig for you and for Jenkins"
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$USER:$USER" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
grep -q 'KUBECONFIG=' ~/.bashrc || echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc

sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config

sudo mkdir -p /etc/systemd/system/jenkins.service.d
printf '[Service]\nEnvironment="KUBECONFIG=/var/lib/jenkins/.kube/config"\n' \
  | sudo tee /etc/systemd/system/jenkins.service.d/kube.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl restart jenkins

echo "==> [6/6] Verifying"
export KUBECONFIG="$HOME/.kube/config"
kubectl get nodes
sudo -u jenkins docker ps
sudo -u jenkins env KUBECONFIG=/var/lib/jenkins/.kube/config kubectl get nodes

until sudo test -f /var/lib/jenkins/secrets/initialAdminPassword; do sleep 3; done
echo
echo "=============================================="
echo "Public IP: $(curl -s http://checkip.amazonaws.com)"
echo "Jenkins unlock password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "=============================================="
echo "Log out and back in so 'docker' works without sudo."
