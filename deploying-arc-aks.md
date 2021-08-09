# Deploy Azure App Service on Azure Arc Connected AKS with Arc SQL Managed Intance

This demo .azcli script will deploy a Hello World webapp on Azure App Service for Kubernetes and an Arc SQL Managed Instance database backend. Deploying Arc PostgreSQL Hyperscale is also supported through the --arc-sql-db-type argument.

## Prerequisites

- [Set up your Workstation](https://github.com/lyledodgegh/aite/blob/main/articles/setup-wsl-azure-developer-machine.md)
- Ensure azure-cli versions 2.26.0 or 2.26.1 are not installed (see Known Issues)

    ```bash
    # check azure-cli version
    az version
    # upgrade to 2.27.* if needed
    az upgrade
    ```
## Executing the script
**NOTE: Complete all prerequisites before proceeding with these steps**
1. Clone the repository to a local directory
1. Open a WSL2 terminal
1. Ensure you are logged in the azure-cli
1. Change directory to the 'scripts' folder where you cloned the repository
1. Execute the script
    ```bash
    SERVICE_PRINCIPAL_ID='<spn id>'
    SERVICE_PRINCIPAL_SECRET='<spn secret>'
    SQL_PASSWORD='<sql admin password>'
    ./deploy-arc-aks.azcli --location eastus \
        --custom-location-name demo-site-virginia \
        --spn-id $SERVICE_PRINCIPAL_ID \
        --spn-secret $SERVICE_PRINCIPAL_SECRET \
        --sql-username demoadmin \
        --sql-password $SQL_PASSWORD \
        --arc-sql-db-type sqlmi
    ```
1. Browse to the hello world webapp

The deploy-arc-aks.azcli script receives the following arguments:
![Aks Options](images/aks-help.png)

## Microsoft Documentation References
- [Connect an existing Kubernetes cluster to Azure Arc](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli)
- [Set up an Azure Arc Kubernetes Cluster to run App Services](https://docs.microsoft.com/en-us/azure/app-service/manage-create-arc-environment)
- [App Service on Azure Arc (Preview)](https://docs.microsoft.com/en-us/azure/app-service/overview-arc-integration)
- [Azure Database for PostgreSQL - Hyperscale (Citus)](https://docs.microsoft.com/en-us/azure/postgresql/hyperscale/)

## Known Issues
- Azure CLI versions 2.26.1 & 2.26.0 currently fail during extension commands. Please use a newer version, or downgrade to known working version: 2.25.0-1.