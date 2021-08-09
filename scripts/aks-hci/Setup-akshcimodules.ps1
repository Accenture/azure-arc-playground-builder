# Login to Azure
Connect-AzAccount -Tenant <id> -

# Optional - if you wish to switch to a different subscription
# First, get all available subscriptions as the currently logged in user
$subList = Get-AzSubscription
# Display those in a grid, select the chosen subscription, then press OK.
if (($subList).count -gt 1) {
    $subList | Out-GridView -OutputMode Single | Set-AzContext
}

Register-AzResourceProvider -ProviderNamespace Microsoft.Kubernetes
Register-AzResourceProvider -ProviderNamespace Microsoft.KubernetesConfiguration
