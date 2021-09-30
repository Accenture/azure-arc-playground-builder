set location=eastus
set rg=%USERNAME%-%RANDOM%
set rg=%rg:.=%
set minikube=%rg%-minikube
set cluster1=%rg%-aks1
set cluster2=%rg%-aks2

echo 'creating resource group'
call az group create --name %rg% --location %location%

echo 'creating clusters - first one as --no-wait, second as wait'
call az aks create -g %rg% -n %cluster1% --enable-managed-identity --generate-ssh-keys --no-wait
call az aks create -g %rg% -n %cluster2% --enable-managed-identity --generate-ssh-keys

echo 'storing kube credentials'
call az aks get-credentials --resource-group %rg% --name %cluster1%
call az aks get-credentials --resource-group %rg% --name %cluster2%

echo 'az cli and extension updates'
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

rem todo - fix these using right info...

echo 'connecting cluster 1'
kubectx %cluster1%
call az connectedk8s connect --name %cluster1% --resource-group %rg%
call az connectedk8s list --resource-group %rg% --output table
kubectl get deployments,pods -n azure-arc

echo 'connecting cluster 2'
kubectx %cluster2%
call az connectedk8s connect --name %cluster2% --resource-group %rg%
call az connectedk8s list --resource-group %rg% --output table
kubectl get deployments,pods -n azure-arc

echo 'adding flux v2 extensions - make sure you have them downloaded in your windows Downloads folder'
call az extension remove -n k8s-configuration
call az extension add --source %userprofile%\Downloads\k8s_configuration-1.1.0b1-py3-none-any.whl --yes
call az extension remove -n k8s-extension-private
call az extension add --source %userprofile%\Downloads\k8s_extension_private-0.7.1b1-py3-none-any.whl --yes

echo 'deploying samle flux v2 on cluster 1'
call az k8s-configuration flux create \
    -g %rg% -c %cluster1% -t connectedClusters \
    -n gitops-demo --namespace gitops-demo --scope cluster \
    -u https://github.com/Azure/arc-k8s-demo --branch main --kustomization name=kustomization1 prune=true

echo 'deploying samle flux v2 on cluster 2'
call az k8s-configuration flux create \
    -g %rg% -c %cluster2% -t connectedClusters \
    -n gitops-demo --namespace gitops-demo --scope cluster \
    -u https://github.com/Azure/arc-k8s-demo --branch main --kustomization name=kustomization1 prune=true

echo 'cluster info'
kubectx %cluster1%
kubectl cluster-info
kubectx %cluster2%
kubectl cluster-info
