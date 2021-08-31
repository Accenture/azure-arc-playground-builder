This is a SUPER rough cut - have been working on this the past few days and wanted to get it out while I wrap it up. Feedback on issues or Twitter [lyledodge](https://twitter.com/lyledodge).

Our goal for this repo is to make it EASY for Windows developers using WSL and developing for AKS or Arc enabled Kubernetes scenarios to just get working - Azure App platform on Arc enabled Kubernetes, Data, AI/ML, etc., without the overhead of the full Azure Arc Jumpbox.

The contents below are also in [arc-enabled-microk8s-all-in-one.bat](scripts/arc-enabled-microk8s-all-in-one.bat).

- Make sure you use useast or the other one - will document shortly (only two places enabled for azure app service on arc enabled kubernetes)
- SP_OBJECTID is needed because the service principal is used to login to azure cli - link in comment below to issue

Once this runs, you'll have a microk8s cluster up in Azure arc enabled.

I'll be adding on the app service extensions and documenting more this week - specifically the AAD permissions needed for the service principal, and the permission in the azure subscription.

```dos
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

```
