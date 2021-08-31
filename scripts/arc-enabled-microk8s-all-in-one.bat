SET RESOURCE_GROUP=
SET CUSTOM_LOCATION=
SET TENANT_ID=
SET SP_ID=
SET SP_SECRET=
SET SP_OBJECTID=
SET VM_NAME=
SET LOCATION=

REM spin up ubuntu server vm
multipass launch --cpus 6 --mem 16G --disk 80G --name %VM_NAME%

REM install microk8s
multipass exec %VM_NAME% -- bash -c "sudo snap install microk8s --classic --channel=latest/stable"
multipass exec %VM_NAME% -- bash -c "sudo iptables -P FORWARD ACCEPT"

REM install other tooling
multipass exec %VM_NAME% -- bash -c "sudo snap install kubectl --classic"
multipass exec %VM_NAME% -- bash -c "curl -sL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash"

REM setup permissions and other stuff
multipass exec %VM_NAME% -- bash -c "mkdir ~/.kube"
multipass exec %VM_NAME% -- bash -c "sudo usermod -a -G microk8s $USER"
multipass exec %VM_NAME% -- bash -c "sudo chown -f -R $USER ~/.kube"
multipass exec %VM_NAME% -- bash -c "microk8s config > ~/.kube/config"

REM enable other microk8s stuff
multipass exec %VM_NAME% -- bash -c "sudo microk8s status --wait-ready"
multipass exec %VM_NAME% -- bash -c "sudo microk8s enable dns storage ingress"

REM pause here until things are settled down and you see everything is OK!!!
multipass exec %VM_NAME% -- bash -c "sudo microk8s kubectl get all --all-namespaces"

REM azure cli
multipass exec %VM_NAME% -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"

REM azure cli extensions
multipass exec %VM_NAME% az -- extension add --upgrade --yes -n connectedk8s -o none
multipass exec %VM_NAME% az -- extension add --upgrade --yes -n k8s-extension -o none
multipass exec %VM_NAME% az -- extension add --upgrade --yes -n customlocation -o none
multipass exec %VM_NAME% az -- extension add --upgrade --yes -n arcdata -o none
multipass exec %VM_NAME% az -- extension add --yes --source "https://aka.ms/appsvc/appservice_kube-latest-py2.py3-none-any.whl" -o none

REM azure cli login using service principal
multipass exec %VM_NAME% az -- login --service-principal -u %SP_ID% -p %SP_SECRET%  --tenant %TENANT_ID%

REM azure cli register custom locations
REM todo document minimum permissions needed
REM (AuthorizationFailed) The client 'guid' with object id 'guid' does not have authorization to perform action 'Microsoft.ExtendedLocation/register/action' over scope '/subscriptions/guid' or the scope is invalid. If access was recently granted, please refresh your credentials.
REM todo document "Kubernetes Cluster - Azure Arc Onboarding" role
multipass exec %VM_NAME% az -- provider register --namespace Microsoft.ExtendedLocation --wait -o none

REM pause here until things are settled down!!!
multipass exec %VM_NAME% -- bash -c "sudo microk8s kubectl get all --all-namespaces"

REM arc connect
REM todo fix - https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/troubleshootingREMenable-custom-locations-using-service-principal
REM todo fix - set minimum service principal permissions in aad and on subscription
multipass exec %VM_NAME% az -- connectedk8s connect --name %CUSTOM_LOCATION% --resource-group %RESOURCE_GROUP% --location %LOCATION% --custom-locations-oid %SP_OBJECTID%

REM next steps - add on app service extensions (use other .sh scripts as example)
