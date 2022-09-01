# Arc enabled Rancher Desktop

This is a quick lap around Rancher Desktop, and Arc enabling Rancher Desktop. Make sure you have already done the [prerequisites](../prerequisites/README.md).

## Why Rancher Desktop?

Arc enabling Rancher Desktop is a SUPER useful way to get familiar with Arc enabled Kubernetes, test things local, not spend a lot of money, and more. If you encounter any issues, you can just delete your resource group in Azure, and reset Kubernetes by opening up Rancher Desktop and clicking **Reset Kubernetes** on the **Troubleshooting** tab.

### Arc enable your Rancher Desktop

```bash
export $clusterid=<some-friendly-name>

# create a resource group for your arc enabled Kubernetes clusters
az group create --name $myAzureResourceGroup --location $myAzureLocation

# arc connect the cluster
az connectedk8s connect --name $clusterid --resource-group $myAzureResourceGroup --custom-locations-oid $myAzureServicePrincipalObjectId

# enable custom-locations and cluster-connect (the proxy access)
az connectedk8s enable-features --name $clusterid --resource-group $clusterid --custom-locations-oid $myAzureServicePrincipalObjectId --features cluster-connect custom-locations
```

So what did we just do? The first two lines created a resource group in Azure to house our Arc enabled Kubernetes cluster, and Arc enabled it.

That last line enables custom locations on the cluster which we will use later, as well as cluster-connect. This is the cool part that allows us to get access to an Arc enabled Kubernetes cluster via a proxy through the Azure control plane.

Now that you've done these two - take a look at the two ways you can connect to this cluster.

Back at the terminal, type in **kubectx**. You'll see an entry for *rancher-desktop*. That's your connection locally to the cluster.

Now type in the below:

```bash
az connectedk8s proxy -n $clusterid -g $myAzureResourceGroup
```

You'll see some stuff happen, then it will say there is a proxy running. Open up a second terminal.

In the new terminal, type in **kubectx**. You'll now see anotehr entry that matches your friendly name you Arc enabled the cluster with. Do a **kubectx <friendly-name>** to switch to it, and then **kubectl get nodes** and you should see the same thing!

Note you can also use k9s this way - whatever your current kubecontext is pointing at, you can point k9s at.
