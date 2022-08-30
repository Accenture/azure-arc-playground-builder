# todos
# pin version to 1.24.0 or latest

# create resource group
az group create -n $myAzureResourceGroup -l $myAzureLocation

# create clusters
az aks create -g $myAzureResourceGroup -n aks-seattle-01 --enable-managed-identity --node-count 1 --enable-aad --aad-admin-group-object-ids $myAzureADGroup --aad-tenant-id $myAzureTenantId --kubernetes-version 1.24.0
az aks get-credentials -n aks-seattle-01 -g $myAzureResourceGroup
kubectx aks-seattle-01
az connectedk8s connect -g $myAzureResourceGroup -n aksarc-seattle-01

az aks create -g $myAzureResourceGroup -n aks-seattle-02 --enable-managed-identity --node-count 1 --enable-aad --aad-admin-group-object-ids $myAzureADGroup --aad-tenant-id $myAzureTenantId --kubernetes-version 1.24.0
az aks get-credentials -n aks-seattle-02 -g $myAzureResourceGroup
kubectx aks-seattle-02
az connectedk8s connect -g $myAzureResourceGroup -n aksarc-seattle-02

