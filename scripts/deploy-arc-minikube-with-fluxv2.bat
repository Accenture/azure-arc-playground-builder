REM SET LOCATION, AND SET RG, REMOVING ANY '.'
set location=eastus
set rg=%USERNAME%-%RANDOM%
set rg=%rg:.=%
set minikube=%rg%-minikube

rem small node default
minikube start -p %minikube% --hyperv-virtual-switch "External Virtual Switch"

rem bigger multinode for workstations
rem minikube start -p %minikube% --nodes 3 --memory=16g --cpus=4 --disk-size=80g --hyperv-virtual-switch "External Virtual Switch"

echo creating resource group
call az group create --name %rg% --location %location%

echo az cli and extension updates
call az upgrade
call az extension add --name connectedk8s
call az provider register --namespace Microsoft.Kubernetes
call az provider register --namespace Microsoft.KubernetesConfiguration
call az provider register --namespace Microsoft.ExtendedLocation
call az feature register --namespace Microsoft.ContainerService --name AKS-ExtensionManager
call az feature show --namespace Microsoft.ContainerService --name AKS-ExtensionManager
call az feature register --namespace Microsoft.KubernetesConfiguration --name fluxConfigurations
call az feature show --namespace Microsoft.KubernetesConfiguration --name fluxConfigurations
call az provider show -n Microsoft.Kubernetes -o table
call az provider show -n Microsoft.KubernetesConfiguration -o table
call az provider show -n Microsoft.ExtendedLocation -o table

echo connecting minikube
call az connectedk8s connect --name %minikube% --resource-group %rg%
call az connectedk8s list --resource-group %rg% --output table

echo adding flux v2 extensions ** make sure you have them downloaded in your windows Downloads folder **
call az extension remove -n k8s-configuration
call az extension add --source %userprofile%\Downloads\k8s_configuration-1.1.0b1-py3-none-any.whl --yes
call az extension remove -n k8s-extension-private
call az extension add --source %userprofile%\Downloads\k8s_extension_private-0.7.1b1-py3-none-any.whl --yes

echo deploying samle flux v2 app on cluster
call az k8s-configuration flux create -g %rg% -c %minikube% -t connectedClusters -n gitops-demo --namespace gitops-demo --scope cluster -u https://github.com/Azure/arc-k8s-demo --branch main --kustomization name=kustomization1 prune=true

echo ========================================
echo HERE IS YOUR TEARDOWN SCRIPT, COPY IT
echo ========================================
echo minikube delete -p %minikube%
echo az group delete --name %rg% -y --no-wait

echo hit enter to quit this script
pause