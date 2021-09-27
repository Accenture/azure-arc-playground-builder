location=eastus
rg=$USER-$RANDOM
cluster1=$rg-aks1
cluster2=$rg-aks2
win_home_raw="$(cmd.exe /c "<nul set /p=%UserProfile%" 2>/dev/null)"
win_home="$(wslpath $win_home_raw)"
echo $rg
echo $cluster1
echo $cluster2

echo 'creating resource group'
az group create --name $rg --location $location

echo 'creating clusters - first one as --no-wait, second as wait'
az aks create -g $rg -n $cluster1 --enable-managed-identity --no-wait
az aks create -g $rg -n $cluster2 --enable-managed-identity

echo 'storing kube credentials'
az aks get-credentials --resource-group $rg --name $cluster1
az aks get-credentials --resource-group $rg --name $cluster2

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

echo 'connecting cluster 1'
kubectx $cluster1
az connectedk8s connect --name $cluster1 --resource-group $rg
az connectedk8s list --resource-group $rg --output table
kubectl get deployments,pods -n azure-arc

echo 'connecting cluster 2'
kubectx $cluster2
az connectedk8s connect --name $cluster2 --resource-group $rg
az connectedk8s list --resource-group $rg --output table
kubectl get deployments,pods -n azure-arc

echo 'adding flux v2 extensions - make sure you have them downloaded in your windows Downloads folder'
az extension remove -n k8s-configuration
az extension add --source $win_home/Downloads/k8s_configuration-1.1.0b1-py3-none-any.whl --yes
az extension remove -n k8s-extension-private
az extension add --source $win_home/Downloads/k8s_extension_private-0.7.1b1-py3-none-any.whl --yes

echo 'deploying samle flux v2 on cluster 1'
az k8s-configuration flux create \
    -g $rg -c $cluster1 -t connectedClusters \
    -n gitops-demo --namespace gitops-demo --scope cluster \
    -u https://github.com/Azure/arc-k8s-demo --branch main --kustomization name=kustomization1 prune=true

echo 'deploying samle flux v2 on cluster 2'
az k8s-configuration flux create \
    -g $rg -c $cluster2 -t connectedClusters \
    -n gitops-demo --namespace gitops-demo --scope cluster \
    -u https://github.com/Azure/arc-k8s-demo --branch main --kustomization name=kustomization1 prune=true

echo 'cluster info'
kubectx $cluster1
kubectl cluster-info
kubectx $cluster2
kubectl cluster-info
