# Quick steps for Arc enabled Rancher Desktop

- [Setup WSL2 on Windows 11](https://docs.microsoft.com/windows/wsl/install)
- [Install Rancher Desktop](https://rancherdesktop.io/)
  - Enable the WSL Integration to Ubuntu
  - Pick the latest Kubernetes version
- [Install the Azure CLI in WSL2](https://docs.microsoft.com/cli/azure/install-azure-cli)

Once you're done with that, From the Azure CLI

```bash
az connectedk8s connect --name MYCLUSTERNAME --resource-group myAzureResourceGroup
```

```powershell
az 
```
