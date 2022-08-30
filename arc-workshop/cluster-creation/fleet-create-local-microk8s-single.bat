set clusterid=%1

multipass launch -c 6 -m 24g -d 80g -n %clusterid% --network name=External lts

rem tooling
multipass exec %clusterid% -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %clusterid% -- bash -c "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash"
multipass exec %clusterid% -- bash -c "sudo snap install kubectl --classic"

rem microk8s
multipass exec %clusterid% -- bash -c "sudo snap install microk8s --classic --channel=1.24/stable"
multipass exec %clusterid% -- bash -c "sudo iptables -P FORWARD ACCEPT"
multipass exec %clusterid% -- bash -c "mkdir ~/.kube"
multipass exec %clusterid% -- bash -c "sudo usermod -a -G microk8s $USER"
multipass exec %clusterid% -- bash -c "sudo chown -f -R $USER ~/.kube"
multipass exec %clusterid% -- bash -c "microk8s config > ~/.kube/config"
multipass exec %clusterid% -- bash -c "sudo microk8s status --wait-ready"

ping -n 10 127.0.0.1 > NUL
multipass exec %clusterid% -- bash -c "sudo microk8s enable dns storage ingress helm3 dashboard"

REM pause here until things are settled down and you see everything is ok and no more deployments are pending!!!
ping -n 60 127.0.0.1 > NUL
multipass exec %clusterid% -- bash -c "sudo microk8s kubectl get all --all-namespaces"

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

rem now connect the k8s cluster
multipass exec %clusterid% -- bash -c "az group create -n %clusterid% -l %myAzureLocation%"
multipass exec %clusterid% -- bash -c "az connectedk8s connect --name %clusterid% --resource-group %clusterid% --custom-locations-oid %myAzureServicePrincipalObjectId%"
multipass exec %clusterid% -- bash -c "az connectedk8s enable-features --name %clusterid% --resource-group %clusterid% --custom-locations-oid %myAzureServicePrincipalObjectId% --features cluster-connect custom-locations"

rem setup azure policy, azure defender for cloud, azure monitor for containers
multipass exec %clusterid% -- bash -c "az monitor log-analytics workspace create -g %clusterid% --workspace-name %clusterid%
multipass exec %clusterid% -- bash -c "az k8s-extension create --name azuremonitor-containers --cluster-name %clusterid% --resource-group %clusterid% --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings logAnalyticsWorkspaceResourceID='/subscriptions/%myAzureSubscriptionId%/resourceGroups/%clusterid%/providers/Microsoft.OperationalInsights/workspaces/%clusterid%'"
multipass exec %clusterid% -- bash -c "az k8s-extension create --name microsoft.policyinsights --cluster-type connectedClusters --cluster-name %clusterid% --resource-group %clusterid% --extension-type Microsoft.PolicyInsights --name microsoft.policyinsights"
multipass exec %clusterid% -- bash -c "az k8s-extension create --name microsoft.azuredefender.kubernetes --cluster-type connectedClusters --cluster-name %clusterid% --resource-group %clusterid% --extension-type microsoft.azuredefender.kubernetes"

rem next steps - add app plat extensions and custom location?