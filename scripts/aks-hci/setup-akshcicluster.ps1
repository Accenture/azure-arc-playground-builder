$cred = Get-Credential
Connect-AzAccount -Tenant <id> -Credential $cred -ServicePrincipal

# Retrieve the subscription and tenant ID
$subList = Get-AzSubscription -TenantId <id>
# Display those in a grid, select the chosen subscription, then press OK.
if (($subList).count -gt 1) {
    $subList | Out-GridView -OutputMode Single | Set-AzContext
}

# Retrieve the subscription and tenant ID
$sub = (Get-AzContext).Subscription.Id
$tenant = (Get-AzContext).Tenant.Id

# First create a resource group in Azure that will contain the registration artifacts
$rg = "azstack-hci-bfcc"

# For an Interactive Login with a user account:
# spn needs access to lookup the rg in this command
Set-AksHciRegistration -SubscriptionId $sub -ResourceGroupName $rg -TenantId $tenant -Credential $cred

Install-AksHci

# Allow PowerShell to show more than 4 versions in the output
$FormatEnumerationLimit = -1
Get-AksHciKubernetesVersion

New-AksHciCluster -Name akshciclus001 -controlPlaneNodeCount 1 -linuxNodeCount 1 -windowsNodeCount 0

Get-AksHciCluster

Get-AksHciCredential -Name akshciclus001 -Confirm
dir $env:USERPROFILE\.kube
