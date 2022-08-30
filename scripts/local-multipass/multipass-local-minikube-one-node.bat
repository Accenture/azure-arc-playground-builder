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
call helper-setup.bat

multipass launch -c 4 -m 16g -d 80g -n %localclustername%  minikube

multipass exec %localclustername% -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %localclustername% -- bash -c "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -"
multipass exec %localclustername% -- bash -c "sudo apt-get install apt-transport-https --yes"

multipass exec %localclustername% -- bash -c "echo 'deb https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list"

multipass exec %localclustername% -- bash -c "sudo apt-get update"
multipass exec %localclustername% -- bash -c "sudo apt-get install helm"

multipass exec %localclustername% -- bash -c "az login --service-principal -u %myAzureServicePrincipalId% -p %myAzureServicePrincipalSecret% --tenant %myAzureTenantId%"
multipass exec %localclustername% -- bash -c "az account set --subscription %myAzureSubscriptionId%"
multipass exec %localclustername% -- bash -c "az extension add --name connectedk8s"
multipass exec %localclustername% -- bash -c "az connectedk8s connect --name %arcclustername% --resource-group %myAzureResourceGroup% --custom-locations-oid %myAzureServicePrincipalObjectId%"
multipass exec %localclustername% -- bash -c "az connectedk8s enable-features --name %arcclustername% --resource-group %myAzureResourceGroup% --custom-locations-oid %myAzureServicePrincipalObjectId% --features cluster-connect custom-locations"
