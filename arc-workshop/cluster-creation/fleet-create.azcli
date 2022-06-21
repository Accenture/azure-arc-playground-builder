# todos
# pin version to 1.24.0 or latest

# create resource group
az group create -n $myResourceGroup -l $myAzureLocation

# create clusters
az aks create -g $myResourceGroup -n aks-seattle-01 --enable-managed-identity --node-count 1 --enable-aad --aad-admin-group-object-ids $myAzureADGroup --aad-tenant-id $myTenantId --kubernetes-version 1.24.0
az aks get-credentials -n aks-seattle-01 -g $myResourceGroup
kubectx aks-seattle-01
az connectedk8s connect -g $myResourceGroup -n aksarc-seattle-01

az aks create -g $myResourceGroup -n aks-seattle-02 --enable-managed-identity --node-count 1 --enable-aad --aad-admin-group-object-ids $myAzureADGroup --aad-tenant-id $myTenantId --kubernetes-version 1.24.0
az aks get-credentials -n aks-seattle-02 -g $myResourceGroup
kubectx aks-seattle-02
az connectedk8s connect -g $myResourceGroup -n aksarc-seattle-02

