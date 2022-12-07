rem also make sure all your environment variables are set from ..\account-management\environment-variables-set.ps1

az group delete --yes --no-wait --name na-us-wa-sea-04
az group delete --yes --no-wait --name na-us-wa-sea-05
az group delete --yes --no-wait --name na-us-mi-det-03
az group delete --yes --no-wait --name na-us-mi-det-04

multipass delete na-us-wa-sea-04
multipass delete na-us-wa-sea-05
multipass delete na-us-mi-det-03
multipass delete na-us-mi-det-04

multipass purge
