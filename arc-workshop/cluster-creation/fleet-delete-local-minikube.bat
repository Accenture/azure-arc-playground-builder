rem also make sure all your environment variables are set from ..\account-management\environment-variables-set.ps1

az group delete --yes --no-wait --name na-us-wa-sea-01
az group delete --yes --no-wait --name na-us-wa-sea-02
az group delete --yes --no-wait --name na-us-wa-sea-03
az group delete --yes --no-wait --name na-us-wa-sam-01
az group delete --yes --no-wait --name na-us-mi-det-01
az group delete --yes --no-wait --name na-us-mi-det-02
az group delete --yes --no-wait --name na-us-ca-lax-01
az group delete --yes --no-wait --name na-us-ca-lax-02

multipass delete na-us-wa-sea-01
multipass delete na-us-wa-sea-02
multipass delete na-us-wa-sea-03
multipass delete na-us-wa-sam-01
multipass delete na-us-mi-det-01
multipass delete na-us-mi-det-02
multipass delete na-us-ca-lax-01
multipass delete na-us-ca-lax-02

multipass purge
