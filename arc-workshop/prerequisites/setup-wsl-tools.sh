#usage
#curl https://raw.githubusercontent.com/Accenture/azure-arc-playground-builder/main/arc-workshop/prerequisites/setup-wsl-tools.sh | bash

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

#azure cli config preferences
az config set extension.use_dynamic_install=yes_without_prompt

#azure extensions
az extension add --upgrade --yes --name connectedk8s --output none
az extension add --upgrade --yes --name k8s-extension --output none
az extension add --upgrade --yes --name customlocation --output none
az extension add --upgrade --yes --name appservice-kube --output none

#k9s
curl -L -o k9s.tar.gz https://github.com/derailed/k9s/releases/download/v0.26.3/k9s_Linux_x86_64.tar.gz
tar -xvf k9s.tar.gz
sudo mv k9s /usr/local/bin/k9s
rm k9s.tar.gz README.md LICENSE

#octant
curl -LO https://github.com/vmware-tanzu/octant/releases/download/v0.25.1/octant_0.25.1_Linux-64bit.deb
sudo dpkg -i octant_0.25.1_Linux-64bit.deb
rm octant_0.25.1_Linux-64bit.deb

#OPTIONAL SECTION EXAMPLES

#dotnet 6 sdk / runtime on debian
#wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
#sudo dpkg -i packages-microsoft-prod.deb
#rm packages-microsoft-prod.deb
#sudo apt-get update && sudo apt-get install -y dotnet-sdk-6.0
#sudo apt-get update && sudo apt-get install -y aspnetcore-runtime-6.0
