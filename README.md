# Azure Arc App & Data Services Quickstart
This repo contains infrastructure-as-code automation scripts & templates to deploy an Azure Arc quickstart Hello World app. This quickstart highlights [recently announced](https://azure.microsoft.com/en-us/updates/public-preview-run-app-service-on-kubernetes-or-anywhere-with-azure-arc/) Azure Arc App Service & Data Services. The intention of this repo is to accelerate prototyping local App Service & Data on Arc enabled Kubernetes.

The set of scripts & templates in this repo do the following:
1. Create an Azure Arc connected Kubernetes cluster, either AKS or Docker Desktop single node clusters
1. Create Azure App Service and Azure Data services on top of the Arc connected Kubernetes cluster
1. Deploy & configure a Hello World web app on Arc App Service and connect to the Arc Data services backend, either SQL Managed Instance or PostgreSQL

## Prerequisites

- [Set up Workstation](docs/prerequisites.md)

## Deployment Scripts

- [Arc App Service + Arc SQL Managed Instance or PostgreSQL Hyperscale on AKS](docs/deploying-arc-aks.md)
- [Arc App Service on local Docker Desktop](docs/deploying-arc-appservice-ddk8s.md)

## Demo
![Arc Demo](img/arc-demo.mp4)

## Next Steps
Check out Microsoft's [Azure Arc Jumpstart - ArcBox](https://azurearcjumpstart.io/azure_jumpstart_arcbox/). ArcBox is a larger-scale Arc sandbox, capable of evaluating Azure Arc scenarios on a more "on-prem" production-like Kubernetes environment.
