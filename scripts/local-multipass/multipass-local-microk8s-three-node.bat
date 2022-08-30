REM TODO - PASS IN subscription, minikube local name, minikube remote name, resource group, location, service principal info
REM TODO - change commands to multipass exec
REM docs - https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli
rem docs - https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-connected-cluster
rem az ad sp create-for-rbac --role Contributor --scopes /subscriptions/%myAzureSubscriptionId%
rem needed for https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/troubleshooting#enable-custom-locations-using-service-principal
rem az ad sp show --id %myAzureServicePrincipalId% --query objectId -o tsv
rem az login --service-principal -u %servicePrincipalId% -p %servicePrincipalSecret% --tenant %myAzureTenantId%

rem checks for multipass, sets currentuser, randomnumber, clustername, arcclustername
rem need to setup servicePrincipalAppId, servicePrincipalPassword, servicePrincipalTenant, subscriptionId

set currentuser=%username%
set currentuser=%currentuser:.=%
set currentuser=%currentuser:-=%
set randomnumber=%random%
set localclustername=microk8s-%currentuser%-%randomnumber%
set arcclustername=arc-%localclustername%

rem todo fix cluster name - not minikube!

multipass launch -c 4 -m 16g -d 80g -n %localclustername%-1  impish
multipass launch -c 4 -m 16g -d 80g -n %localclustername%-2  impish
multipass launch -c 4 -m 16g -d 80g -n %localclustername%-3  impish

rem pause

rem tooling
multipass exec %localclustername%-1 -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %localclustername%-1 -- bash -c "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -"
multipass exec %localclustername%-1 -- bash -c "sudo apt-get install apt-transport-https --yes"
multipass exec %localclustername%-1 -- bash -c "echo 'deb https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list"
multipass exec %localclustername%-1 -- bash -c "sudo apt-get update"
multipass exec %localclustername%-1 -- bash -c "sudo apt-get install helm"
multipass exec %localclustername%-1 -- bash -c "sudo snap install kubectl --classic"

rem microk8s
multipass exec %localclustername%-1 -- bash -c "sudo snap install microk8s --classic --channel=latest/stable"
multipass exec %localclustername%-1 -- bash -c "sudo iptables -P FORWARD ACCEPT"
multipass exec %localclustername%-1 -- bash -c "mkdir ~/.kube"
multipass exec %localclustername%-1 -- bash -c "sudo usermod -a -G microk8s $USER"
multipass exec %localclustername%-1 -- bash -c "sudo chown -f -R $USER ~/.kube"
multipass exec %localclustername%-1 -- bash -c "microk8s config > ~/.kube/config"
multipass exec %localclustername%-1 -- bash -c "sudo microk8s status --wait-ready"
multipass exec %localclustername%-1 -- bash -c "sudo microk8s enable dns storage ingress"

REM pause here until things are settled down and you see everything is ok and no more deployments are pending!!!
multipass exec %localclustername%-1 -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem sleep for 1 min
ping -n 6 127.0.0.1 > NUL
multipass exec %localclustername%-1 -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem pause

rem azure stuff
multipass exec %localclustername%-1 -- bash -c "az login --service-principal -u %myAzureServicePrincipalId% -p %myAzureServicePrincipalSecret% --tenant %myAzureTenantId%"
multipass exec %localclustername%-1 -- bash -c "az account set --subscription %myAzureSubscriptionId%"
multipass exec %localclustername%-1 -- bash -c "az extension add --upgrade --yes -n connectedk8s -o none"
multipass exec %localclustername%-1 -- bash -c "az extension add --upgrade --yes -n k8s-extension -o none"
multipass exec %localclustername%-1 -- bash -c "az extension add --upgrade --yes -n customlocation -o none"
multipass exec %localclustername%-1 -- bash -c "az provider register --namespace Microsoft.ExtendedLocation --wait -o none"

rem pause
rem tooling
multipass exec %localclustername%-2 -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %localclustername%-2 -- bash -c "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -"
multipass exec %localclustername%-2 -- bash -c "sudo apt-get install apt-transport-https --yes"
multipass exec %localclustername%-2 -- bash -c "echo 'deb https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list"
multipass exec %localclustername%-2 -- bash -c "sudo apt-get update"
multipass exec %localclustername%-2 -- bash -c "sudo apt-get install helm"
multipass exec %localclustername%-2 -- bash -c "sudo snap install kubectl --classic"

rem microk8s
multipass exec %localclustername%-2 -- bash -c "sudo snap install microk8s --classic --channel=latest/stable"
multipass exec %localclustername%-2 -- bash -c "sudo iptables -P FORWARD ACCEPT"
multipass exec %localclustername%-2 -- bash -c "mkdir ~/.kube"
multipass exec %localclustername%-2 -- bash -c "sudo usermod -a -G microk8s $USER"
multipass exec %localclustername%-2 -- bash -c "sudo chown -f -R $USER ~/.kube"
multipass exec %localclustername%-2 -- bash -c "microk8s config > ~/.kube/config"
multipass exec %localclustername%-2 -- bash -c "sudo microk8s status --wait-ready"
multipass exec %localclustername%-2 -- bash -c "sudo microk8s enable dns storage ingress"

REM pause here until things are settled down and you see everything is ok and no more deployments are pending!!!
multipass exec %localclustername%-2 -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem sleep for 1 min
ping -n 6 127.0.0.1 > NUL
multipass exec %localclustername%-2 -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem pause

rem azure stuff
multipass exec %localclustername%-2 -- bash -c "az login --service-principal -u %myAzureServicePrincipalId% -p %myAzureServicePrincipalSecret% --tenant %myAzureTenantId%"
multipass exec %localclustername%-2 -- bash -c "az account set --subscription %myAzureSubscriptionId%"
multipass exec %localclustername%-2 -- bash -c "az extension add --upgrade --yes -n connectedk8s -o none"
multipass exec %localclustername%-2 -- bash -c "az extension add --upgrade --yes -n k8s-extension -o none"
multipass exec %localclustername%-2 -- bash -c "az extension add --upgrade --yes -n customlocation -o none"
multipass exec %localclustername%-2 -- bash -c "az provider register --namespace Microsoft.ExtendedLocation --wait -o none"



rem tooling
multipass exec %localclustername%-3 -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %localclustername%-3 -- bash -c "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -"
multipass exec %localclustername%-3 -- bash -c "sudo apt-get install apt-transport-https --yes"
multipass exec %localclustername%-3 -- bash -c "echo 'deb https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list"
multipass exec %localclustername%-3 -- bash -c "sudo apt-get update"
multipass exec %localclustername%-3 -- bash -c "sudo apt-get install helm"
multipass exec %localclustername%-3 -- bash -c "sudo snap install kubectl --classic"

rem microk8s
multipass exec %localclustername%-3 -- bash -c "sudo snap install microk8s --classic --channel=latest/stable"
multipass exec %localclustername%-3 -- bash -c "sudo iptables -P FORWARD ACCEPT"
multipass exec %localclustername%-3 -- bash -c "mkdir ~/.kube"
multipass exec %localclustername%-3 -- bash -c "sudo usermod -a -G microk8s $USER"
multipass exec %localclustername%-3 -- bash -c "sudo chown -f -R $USER ~/.kube"
multipass exec %localclustername%-3 -- bash -c "microk8s config > ~/.kube/config"
multipass exec %localclustername%-3 -- bash -c "sudo microk8s status --wait-ready"
multipass exec %localclustername%-3 -- bash -c "sudo microk8s enable dns storage ingress"

REM pause here until things are settled down and you see everything is ok and no more deployments are pending!!!
multipass exec %localclustername%-3 -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem sleep for 1 min
ping -n 6 127.0.0.1 > NUL
multipass exec %localclustername%-3 -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem pause

rem azure stuff
multipass exec %localclustername%-3 -- bash -c "az login --service-principal -u %myAzureServicePrincipalId% -p %myAzureServicePrincipalSecret% --tenant %myAzureTenantId%"
multipass exec %localclustername%-3 -- bash -c "az account set --subscription %myAzureSubscriptionId%"
multipass exec %localclustername%-3 -- bash -c "az extension add --upgrade --yes -n connectedk8s -o none"
multipass exec %localclustername%-3 -- bash -c "az extension add --upgrade --yes -n k8s-extension -o none"
multipass exec %localclustername%-3 -- bash -c "az extension add --upgrade --yes -n customlocation -o none"
multipass exec %localclustername%-3 -- bash -c "az provider register --namespace Microsoft.ExtendedLocation --wait -o none"

rem now do 2nd and 3rd nodes and add them to cluster.

rem get command to join 2nd node...
set "joinCommand="
for /f "skip=1 delims=" %%a in (
 'multipass exec %localclustername%-1 -- bash -c "microk8s add-node"'
) do if not defined sid set "joinCommand=%%a"
multipass exec %localclustername%-2 -- bash -c "%joinCommand%"

rem get command to join 3rd node...
set "joinCommand="
for /f "skip=1 delims=" %%a in (
 'multipass exec %localclustername%-1 -- bash -c "microk8s add-node"'
) do if not defined sid set "joinCommand=%%a"
multipass exec %localclustername%-3 -- bash -c "%joinCommand%"

rem now connect the k8s cluster
multipass exec %localclustername%-1 -- bash -c "az connectedk8s connect --name %arcclustername% --resource-group %myAzureResourceGroup% --custom-locations-oid %myAzureServicePrincipalObjectId%"
multipass exec %localclustername%-1 -- bash -c "az connectedk8s enable-features --name %arcclustername% --resource-group %myAzureResourceGroup% --custom-locations-oid %myAzureServicePrincipalObjectId% --features cluster-connect custom-locations"

rem delete scripts
echo multipass delete %localclustername%-3
echo multipass delete %localclustername%-2
echo multipass delete %localclustername%-1
echo multipass purge
pause

REM azure cli extensions
rem multipass exec %localclustername% az -- extension add --upgrade --yes -n arcdata -o none
rem multipass exec %localclustername% az -- extension add --yes --source "https://aka.ms/appsvc/appservice_kube-latest-py2.py3-none-any.whl" -o none
