REM docs - https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli
rem docs - https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-connected-cluster
rem az ad sp create-for-rbac --role Contributor --scopes /subscriptions/%mySubscriptionId%
rem needed for https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/troubleshooting#enable-custom-locations-using-service-principal
rem az ad sp show --id %myservicePrincipalId% --query objectId -o tsv
rem az login --service-principal -u %servicePrincipalId% -p %servicePrincipalSecret% --tenant %myTenantId%

rem need to setup environment variables for:
rem   myTenantId, mySubscriptionId, myServicePrincipalId, myServicePrincipalObjectId, myServicePrincipalSecret, myResourceGroup

set currentuser=%username%
set currentuser=%currentuser:.=%
set currentuser=%currentuser:-=%
set randomnumber=%random%
set localclustername=microk8s-%currentuser%-%randomnumber%
set arcclustername=arc-%localclustername%

rem todo fix cluster name - not minikube!

multipass launch -c 6 -m 32g -d 80g -n %localclustername%  impish

rem pause

rem tooling
multipass exec %localclustername% -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %localclustername% -- bash -c "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -"
multipass exec %localclustername% -- bash -c "sudo apt-get install apt-transport-https --yes"
multipass exec %localclustername% -- bash -c "echo 'deb https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list"
multipass exec %localclustername% -- bash -c "sudo apt-get update"
multipass exec %localclustername% -- bash -c "sudo apt-get install helm"
multipass exec %localclustername% -- bash -c "sudo snap install kubectl --classic"

rem microk8s
multipass exec %localclustername% -- bash -c "sudo snap install microk8s --classic --channel=latest/stable"
multipass exec %localclustername% -- bash -c "sudo iptables -P FORWARD ACCEPT"
multipass exec %localclustername% -- bash -c "mkdir ~/.kube"
multipass exec %localclustername% -- bash -c "sudo usermod -a -G microk8s $USER"
multipass exec %localclustername% -- bash -c "sudo chown -f -R $USER ~/.kube"
multipass exec %localclustername% -- bash -c "microk8s config > ~/.kube/config"
multipass exec %localclustername% -- bash -c "sudo microk8s status --wait-ready"
multipass exec %localclustername% -- bash -c "sudo microk8s enable dns storage ingress"

REM pause here until things are settled down and you see everything is ok and no more deployments are pending!!!
multipass exec %localclustername% -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem sleep for 1 min
ping -n 6 127.0.0.1 > NUL
multipass exec %localclustername% -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem pause

rem azure stuff
multipass exec %localclustername% -- bash -c "az login --service-principal -u %myServicePrincipalId% -p %myServicePrincipalSecret% --tenant %myTenantId%"
multipass exec %localclustername% -- bash -c "az account set --subscription %mySubscriptionId%"
multipass exec %localclustername% -- bash -c "az extension add --upgrade --yes -n connectedk8s -o none"
multipass exec %localclustername% -- bash -c "az extension add --upgrade --yes -n k8s-extension -o none"
multipass exec %localclustername% -- bash -c "az extension add --upgrade --yes -n customlocation -o none"
multipass exec %localclustername% -- bash -c "az provider register --namespace Microsoft.Kubernetes --wait -o none"
multipass exec %localclustername% -- bash -c "az provider register --namespace Microsoft.KubernetesConfiguration --wait -o none"
multipass exec %localclustername% -- bash -c "az provider register --namespace Microsoft.ExtendedLocation --wait -o none"

rem now connect the k8s cluster
multipass exec %localclustername% -- bash -c "az connectedk8s connect --name %arcclustername% --resource-group %myResourceGroup% --custom-locations-oid %myServicePrincipalObjectId%"
multipass exec %localclustername% -- bash -c "az connectedk8s enable-features --name %arcclustername% --resource-group %myResourceGroup% --custom-locations-oid %myServicePrincipalObjectId% --features cluster-connect custom-locations"
