# create a resource group named the same as the cluster name
az group create --name $clusterid --location $myAzureLocation

# arc connect the cluster
az connectedk8s connect --name $clusterid --resource-group $clusterid --custom-locations-oid $myServicePrincipalObjectId

# enable custom-locations and cluster-connect (the proxy access)
az connectedk8s enable-features --name $clusterid --resource-group $clusterid --custom-locations-oid $myServicePrincipalObjectId --features cluster-connect custom-locations

# create a log analytics workspace for the extensions below
az monitor log-analytics workspace create --resource-group $clusterid --workspace-name $clusterid

# extension azure monitor for containers
az k8s-extension create --name azuremonitor-containers --cluster-type connectedClusters --cluster-name $clusterid --resource-group $clusterid --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID="/subscriptions/$mySubscriptionId/resourceGroups/$clusterid/providers/Microsoft.OperationalInsights/workspaces/$clusterid"

# extension aks policy for arc connected kubernetes
az k8s-extension create --cluster-type connectedClusters --cluster-name $clusterid --resource-group $clusterid --extension-type Microsoft.PolicyInsights --name microsoft.policyinsights

# extension azure defender for kubernetes
az k8s-extension create --name microsoft.azuredefender.kubernetes --cluster-type connectedClusters --cluster-name $clusterid --resource-group $clusterid --extension-type microsoft.azuredefender.kubernetes
