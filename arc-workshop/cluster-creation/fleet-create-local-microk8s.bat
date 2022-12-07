rem make sure you create an external network in Hyper-V called "External"
rem also make sure all your environment variables are set from ..\account-management\environment-variables-set.ps1

call fleet-create-local-microk8s-single.bat na-us-wa-sea-04
call fleet-create-local-microk8s-single.bat na-us-wa-sea-05
call fleet-create-local-microk8s-single.bat na-us-mi-det-03
call fleet-create-local-microk8s-single.bat na-us-mi-det-04
