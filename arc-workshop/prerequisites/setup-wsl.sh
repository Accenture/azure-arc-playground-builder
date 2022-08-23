#usage
#curl https://raw.githubusercontent.com/Accenture/azure-arc-playground-builder/main/arc-workshop/prerequisites/setup-wsl.sh | sudo bash

#azure cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

#helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash

#kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo mv kubectl /usr/local/bin/kubectl

#kubectx/kubens
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

#azure extensions
az extension add --upgrade --yes -n connectedk8s -o none
az extension add --upgrade --yes -n k8s-extension -o none
az extension add --upgrade --yes -n customlocation -o none

#k9s
curl -L -o k9s.tar.gz https://github.com/derailed/k9s/releases/download/v0.26.3/k9s_Linux_x86_64.tar.gz
tar -xvf k9s.tar.gz
sudo mv k9s /usr/local/bin/k9s
rm k9s.tar.gz README.md LICENSE