rem make sure you create an external network in Hyper-V called "External"
rem also make sure all your environment variables are set from ..\account-management\environment-variables-set.ps1

call fleet-create-local-minikube-single.bat na-us-wa-sea-01
call fleet-create-local-minikube-single.bat na-us-wa-sea-02
call fleet-create-local-minikube-single.bat na-us-wa-sea-03

call fleet-create-local-minikube-single.bat na-us-wa-sam-01

call fleet-create-local-minikube-single.bat na-us-mi-det-01
call fleet-create-local-minikube-single.bat na-us-mi-det-02

call fleet-create-local-minikube-single.bat na-us-ca-lax-01
call fleet-create-local-minikube-single.bat na-us-ca-lax-02