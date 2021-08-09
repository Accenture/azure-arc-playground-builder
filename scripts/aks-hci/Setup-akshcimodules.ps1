# Login to Azure
Connect-AzAccount -Tenant 580fb630-a6a8-4c62-b9d0-ad28387a279a -

# Optional - if you wish to switch to a different subscription
# First, get all available subscriptions as the currently logged in user
$subList = Get-AzSubscription
# Display those in a grid, select the chosen subscription, then press OK.
if (($subList).count -gt 1) {
    $subList | Out-GridView -OutputMode Single | Set-AzContext
}

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration