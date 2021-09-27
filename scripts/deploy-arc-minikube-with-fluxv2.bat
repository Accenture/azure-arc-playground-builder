minikube start --memory=10g --cpus=4 --disk-size=80g --hyperv-virtual-switch "External Virtual Switch"

REM SET LOCATION, AND SET RG, REMOVING ANY '.'
set location=eastus
set rg=%USERNAME%-%RANDOM%
set rg=%rg:.=%
set minikube=%rg%-minikube

echo 'creating resource group'
az group create --name %rg% --location %location%

echo 'az cli and extension updates'
az upgrade
az extension add --name connectedk8s
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.ExtendedLocation
az feature register --namespace Microsoft.ContainerService --name AKS-ExtensionManager
az feature show --namespace Microsoft.ContainerService --name AKS-ExtensionManager
az feature register --namespace Microsoft.KubernetesConfiguration --name fluxConfigurations
az feature show --namespace Microsoft.KubernetesConfiguration --name fluxConfigurations
az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table

echo 'connecting minikube'
az connectedk8s connect --name %minikube% --resource-group %rg%
az connectedk8s list --resource-group %rg% --output table

echo 'adding flux v2 extensions - make sure you have them downloaded in your windows Downloads folder'
az extension remove -n k8s-configuration
az extension add --source %userprofile%\Downloads\k8s_configuration-1.1.0b1-py3-none-any.whl --yes
az extension remove -n k8s-extension-private
az extension add --source %userprofile%\Downloads\k8s_extension_private-0.7.1b1-py3-none-any.whl --yes

echo 'deploying samle flux v2 on cluster 1'
az k8s-configuration flux create -g %rg% -c %minikube% -t connectedClusters -n gitops-demo --namespace gitops-demo --scope cluster -u https://github.com/Azure/arc-k8s-demo --branch main --kustomization name=kustomization1 prune=true
