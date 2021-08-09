# project-lima-demo

## Prepare the workstation

- [Set up your Workstation](https://github.com/lyledodgegh/aite/blob/main/articles/setup-wsl-azure-developer-machine.md)

## Demo deployment scripts

- [Arc App Service on Docker Desktop]([deploy-arc-ddk8s.azcli](scripts/deploy-arc-ddk8s.azcli))
- [Arc App Service + Arc SQL Managed Instance or PostgreSQL Hyperscale on AKS]([deploy-arc-aks.azcli](scripts/deploy-arc-aks.azcli))

## Key Takeaways

- I can modernize without migrating
- I can use Azure application platform on Kubernetes
- I understand the options for state management on Kubernetes and Azure multitenant
- I understand the new gitops through arc for kubernetes deployment models

## Showcase Demo Scope

- Read the [AMBG Lima ViewPoint](https://ts.accenture.com/sites/AMBGAdvisory-Seattle-MicrosoftProjectLima/Shared%20Documents/Microsoft%20Project%20Lima/AMBG%20Viewpoint%20-%20Microsoft%20Project%20Lima.pptx?web=1)
- This repo should serve as build/run/deployable bits for anyone with an Azure subscription. The demo scope:
  - Something simple - a web app (Azure web app) backed by a data store (sql server)
  - Deploy the solution on Azure multitenant (Azure App Service + Azure SQL Database)
  - Deploy the solution on Azure Kubernetes Service (LIMA with SQL Containers)
  - Deploy the solution on on-premises Kubernetes (tbd - Kind? Minikube? Commercial k8s in a VM?)
  - Options
    - SQL Server has built-in replication options - do we set up the multitenant as a master and others as replicas that can push to master? This would be awesome to have the multitenant be the master but showing downstream locations being kept in sync.
- The demo portion on the [Digital Showcase](https://showcase.avanade.com) should be a recorded demo and PowerPoint deck, due to the complexities of deploying/running Kubernetes on premises (your laptop) and Azure.

## Relevant Software and Documentation Links

- todo - public docs
- todo - azure stack hci download

## Environment Setup and Instructions

1. Review the base landing at [github.com/microsoft/project-lima-private-preview](https://github.com/microsoft/project-lima-private-preview).
1. Work with an Accenture employee that has an Azure subscription that has already been onboarded with EUAP access to features (currently l.dodge and l.beck).
    1. [AMBG Studios Azure Subscription - Access](https://ts.accenture.com/sites/AMBGAdvisory-Seattle/SitePages/Access-to-the-Studio-Azure-Subscription.aspx)
1. Prepare a developer machine:
    1. [Setting up a WSL based Azure Developer Machine](https://azureintheenterprise.com/articles/setup-wsl-azure-developer-machine.html)
1. Setup Azure Kubernetes Service on Azure Stack HCI
    1. [Azure Stack HCI Download](https://azure.microsoft.com/products/azure-stack/hci/hci-download/)
        1. `Invoke-WebRequest -Uri <source> -OutFile <destination>`
        1. [Install Windows Admin Center on Azure Stack HCI](https://docs.microsoft.com/windows-server/manage/windows-admin-center/deploy/install)
