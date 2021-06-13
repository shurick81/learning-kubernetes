# Deploy Using Windows:

```PowerShell
cd "C:\projects\learning-kubernetes\labs\00 - install the cluster\terraform"
Remove-Item .terraform.tfstate.lock.info -Recurse
Remove-Item terraform.tfstate
Remove-Item terraform.tfstate.backup
Sleep 5;
docker run --rm -v ${PWD}/..:/workplace -w /workplace/terraform hashicorp/terraform:light init
docker run --rm -v ${PWD}/..:/workplace -w /workplace/terraform `
    -e TF_VAR_ARM_CLIENT_ID=$env:ARM_CLIENT_ID `
    -e TF_VAR_ARM_CLIENT_SECRET=$env:ARM_CLIENT_SECRET `
    -e TF_VAR_ARM_SUBSCRIPTION_ID=$env:ARM_SUBSCRIPTION_ID `
    -e TF_VAR_ARM_TENANT_ID=$env:ARM_TENANT_ID `
    -e TF_VAR_VM_ADMIN_PASSWORD=$env:VM_ADMIN_PASSWORD `
    hashicorp/terraform:light `
    apply -auto-approve
```

# Connect:

Check public IPs and ports in load balancer Inbound NAT Rules

```PowerShell
ssh-keygen -R kubernetes-lab-slkdfjh-vm00.westeurope.cloudapp.azure.com
ssh aleks@20.93.148.249 -p 50001
```

# Test load balancer

```bash
nc -v 20.93.148.249 6443
```

# Install binaries on each vm

```bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo apt-get remove containerd runc
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

# Configure control plane

## On the first node

```
sudo kubeadm init --control-plane-endpoint "20.86.176.83:6443" --upload-certs
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```
