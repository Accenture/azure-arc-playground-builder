rem make sure you create an external network in Hyper-V called "External"
rem also make sure all your environment variables are set from ..\account-management\environment-variables-set.ps1

call az group create -n %myResourceGroup% -l %myAzureLocation%

call fleet-create-local-microk8s-single.bat seattle-04
call fleet-create-local-microk8s-single.bat seattle-05
call fleet-create-local-microk8s-single.bat seattle-06
