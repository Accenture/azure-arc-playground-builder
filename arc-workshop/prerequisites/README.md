# Prerequisites

Follow the steps below to get your Windows 11 with WSL2 machine up and running for the Arc workshop.

- [Install Windows Subsystem for Linux 2 (WSL2)](https://docs.microsoft.com/windows/wsl/install)
- [Install Rancher Desktop](https://rancherdesktop.io/)
- (Optional) [Install Windows Terminal Preview](https://apps.microsoft.com/store/detail/windows-terminal-preview/9N8G5RFZ9XK3)

Once you've done that, install the Azure CLI, kubectl, kubens, kubectx, helm3, k9s, and some of the Azure CLI extensions in your linux environment.

```bash
curl https://raw.githubusercontent.com/Accenture/azure-arc-playground-builder/main/arc-workshop/prerequisites/setup-wsl-tools.sh | bash
```

At this point, you can login to your Azure environment by logging into [portal.azure.com](https://portal.azure.com) in a browser, navigating to the Azure Active Directory that contains the Azure subscription you want to work with, copying that Tenant ID, and executing the command:

```bash
az login --tenant <GUID>
```

At this point, you should be logged into Azure from WSL2 and ready to go, head back to the main workshop landing.
