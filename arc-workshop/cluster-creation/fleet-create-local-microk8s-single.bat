set clustername=%1
set arcclustername=arc-%1

multipass launch -c 4 -m 16g -d 80g -n %clustername% --network name=External lts

rem pause

rem tooling
multipass exec %clustername% -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
multipass exec %clustername% -- bash -c "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash"
multipass exec %clustername% -- bash -c "sudo snap install kubectl --classic"

rem microk8s
multipass exec %clustername% -- bash -c "sudo snap install microk8s --classic --channel=1.24/stable"
multipass exec %clustername% -- bash -c "sudo iptables -P FORWARD ACCEPT"
multipass exec %clustername% -- bash -c "mkdir ~/.kube"
multipass exec %clustername% -- bash -c "sudo usermod -a -G microk8s $USER"
multipass exec %clustername% -- bash -c "sudo chown -f -R $USER ~/.kube"
multipass exec %clustername% -- bash -c "microk8s config > ~/.kube/config"
multipass exec %clustername% -- bash -c "sudo microk8s status --wait-ready"
multipass exec %clustername% -- bash -c "sudo microk8s enable dns hostpath-storage ingress helm3 dashboard"

rem https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md
REM pause here until things are settled down and you see everything is ok and no more deployments are pending!!!
multipass exec %clustername% -- bash -c "sudo microk8s kubectl get all --all-namespaces"

rem sleep for 1 min
ping -n 60 127.0.0.1 > NUL
multipass exec %clustername% -- bash -c "sudo microk8s kubectl get all --all-namespaces"
rem pause

rem azure stuff
multipass exec %clustername% -- bash -c "az login --service-principal -u %myServicePrincipalId% -p %myServicePrincipalSecret% --tenant %myTenantId%"
multipass exec %clustername% -- bash -c "az account set --subscription %mySubscriptionId%"
multipass exec %clustername% -- bash -c "az extension add --upgrade --yes -n connectedk8s -o none"
multipass exec %clustername% -- bash -c "az extension add --upgrade --yes -n k8s-extension -o none"
multipass exec %clustername% -- bash -c "az extension add --upgrade --yes -n customlocation -o none"
multipass exec %clustername% -- bash -c "az provider register --namespace Microsoft.Kubernetes --wait -o none"
multipass exec %clustername% -- bash -c "az provider register --namespace Microsoft.KubernetesConfiguration --wait -o none"
multipass exec %clustername% -- bash -c "az provider register --namespace Microsoft.ExtendedLocation --wait -o none"

rem now connect the k8s cluster
multipass exec %clustername% -- bash -c "az connectedk8s connect --name %arcclustername% --resource-group %myResourceGroup% --custom-locations-oid %myServicePrincipalObjectId%"
multipass exec %clustername% -- bash -c "az connectedk8s enable-features --name %arcclustername% --resource-group %myResourceGroup% --custom-locations-oid %myServicePrincipalObjectId% --features cluster-connect custom-locations"
