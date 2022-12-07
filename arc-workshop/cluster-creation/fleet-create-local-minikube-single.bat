set clusterid=%1

multipass launch -c 6 -m 8g -d 40g -n %clusterid% --network name=External minikube

rem tooling
multipass exec %clusterid% -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %clusterid% -- bash -c "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash"

rem azure stuff
multipass exec %clusterid% -- bash -c "az config set extension.use_dynamic_install=yes_without_prompt"
multipass exec %clusterid% -- bash -c "az login --service-principal -u %myAzureServicePrincipalId% -p %myAzureServicePrincipalSecret% --tenant %myAzureTenantId%"
multipass exec %clusterid% -- bash -c "az account set --subscription %myAzureSubscriptionId%"
multipass exec %clusterid% -- bash -c "az extension add --upgrade --yes -n connectedk8s -o none"
multipass exec %clusterid% -- bash -c "az extension add --upgrade --yes -n k8s-extension -o none"
multipass exec %clusterid% -- bash -c "az extension add --upgrade --yes -n customlocation -o none"
multipass exec %clusterid% -- bash -c "az provider register --namespace Microsoft.Kubernetes --wait -o none"
multipass exec %clusterid% -- bash -c "az provider register --namespace Microsoft.KubernetesConfiguration --wait -o none"
multipass exec %clusterid% -- bash -c "az provider register --namespace Microsoft.ExtendedLocation --wait -o none"
multipass exec %clusterid% -- bash -c "wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh"
multipass exec %clusterid% -- bash -c "bash ~/install_linux_azcmagent.sh"

rem create the resource group for this cluster
multipass exec %clusterid% -- bash -c "az group create -n %clusterid% -l %myAzureLocation%"

rem now connect the host os
multipass exec %clusterid% -- bash -c "sudo azcmagent connect --service-principal-id %myAzureServicePrincipalId% --service-principal-secret %myAzureServicePrincipalSecret% --resource-group %clusterid% --tenant-id %myAzureTenantId% --location %MyAzureLocation% --subscription-id %myAzureSubscriptionId% --cloud AzureCloud --correlation-id 01324567-890a-bcde-f012-34567890abcd"

rem now connect the k8s cluster and enable the cluster proxy
multipass exec %clusterid% -- bash -c "az connectedk8s connect --name %clusterid% --resource-group %clusterid% --custom-locations-oid %myAzureServicePrincipalObjectId%"
multipass exec %clusterid% -- bash -c "az connectedk8s enable-features --name %clusterid% --resource-group %clusterid% --custom-locations-oid %myAzureServicePrincipalObjectId% --features cluster-connect custom-locations"

rem setup azure policy, azure defender for cloud, azure monitor for containers
multipass exec %clusterid% -- bash -c "az monitor log-analytics workspace create -g %clusterid% --workspace-name %clusterid%
multipass exec %clusterid% -- bash -c "az k8s-extension create --name azuremonitor-containers --cluster-name %clusterid% --resource-group %clusterid% --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID='/subscriptions/%myAzureSubscriptionId%/resourceGroups/%clusterid%/providers/Microsoft.OperationalInsights/workspaces/%clusterid%'"
multipass exec %clusterid% -- bash -c "az k8s-extension create --name microsoft.policyinsights --cluster-type connectedClusters --cluster-name %clusterid% --resource-group %clusterid% --extension-type Microsoft.PolicyInsights"
multipass exec %clusterid% -- bash -c "az k8s-extension create --name microsoft.azuredefender.kubernetes --cluster-type connectedClusters --cluster-name %clusterid% --resource-group %clusterid% --extension-type microsoft.azuredefender.kubernetes"

rem next steps - add app plat extensions and custom location?
rem az monitor log-analytics workspace show --resource-group lyle-29 --workspace-name lyle-29 --query customerId --output tsv
rem tempLogAnalyticsWorkspaceId=$(az monitor log-analytics workspace show resource-group $clusterid --workspace-name $workspaceName \
rem     --query customerId \
rem     --output tsv)
rem logAnalyticsWorkspaceIdEnc=$(printf %s $logAnalyticsWorkspaceId | base64 -w0) # Needed for the next step
rem logAnalyticsKey=$(az monitor log-analytics workspace get-shared-keys \
rem     --resource-group $groupName \
rem     --workspace-name $workspaceName \
rem     --query primarySharedKey \
rem     --output tsv)
rem logAnalyticsKeyEnc=$(printf %s $logAnalyticsKey | base64 -w0) # Needed for the next step


