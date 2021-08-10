# Setup a WSL2 based Azure developer machine

## Install and update WSL 2 on Windows 10

- If you're doing this in a Hyper-V VM, on the host enable nested Hyper-V
  - `Set-VMProcessor -VMName <VMName> -ExposeVirtualizationExtensions $true`
- [Windows Subsystem for Linux Installation Guide for Windows 10 (docs.microsoft.com)](https://docs.microsoft.com/windows/wsl/install-win10)

### WSL2 tooling setup

Run these commands in your WSL2 Linux terminal

```bash
# Disable WSL2 login message and update packages
touch .hushlogin && sudo apt-get update && sudo apt-get -y upgrade

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install go
wget https://golang.org/dl/go1.16.7.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.16.7.linux-amd64.tar.gz
rm go1.16.7.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install kubectl, kubelet, kubeadm
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl kubelet kubeadm

# Install kubectx
wget https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx
chmod +x kubectx
sudo mv kubectx /usr/local/bin/
wget https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubens
chmod +x kubens
sudo mv kubens /usr/local/bin/

# Install KIND
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x kind
sudo mv ./kind /usr/local/bin/

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh
```

## Docker setup

- [Download Docker Desktop](https://desktop.docker.com/win/stable/amd64/Docker%20Desktop%20Installer.exe)
  - You'll have to logout and log back in
  - Settings -> Resources -> WSL Integration -> Enable Ubuntu
  - Settings -> Kubernetes -> Enable Kubernetes
  - Click Apply & Restart, click ok on the install dialog

## Visual Studio Code + Extensions

- [Visual Studio Code - 64 bit User Installer](https://code.visualstudio.com/docs/?dv=win64user)
- [Visual Studio Code - Marketplace Extensions](https://marketplace.visualstudio.com/vscode)
  - [Remote - WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
  - [Remote - Containers](ms-vscode-remote.remote-containers)
  - [Docker](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker)
  - [Bridge to Kubernetes](https://marketplace.visualstudio.com/items?itemName=mindaro.mindaro)
  - [Kubernetes](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tool)
  - [YAML by Red Hat](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)
  - [Visual Studio IntelliCode](https://marketplace.visualstudio.com/items?itemName=VisualStudioExptTeam.vscodeintellicode)
  - [Prettier - Code formatter](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)

## Azure Service Prinicpal setup
* Azure Arc Data services require a service principal to publish usage and metric data to Azure
* It is recommended to scope the service principal to a specific Azure subscription.
```bash
az ad sp create-for-rbac -n "<Unique SP Name>" --role contributor
```
