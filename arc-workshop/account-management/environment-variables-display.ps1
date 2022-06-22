Write-Host "Current User Environment Variables"
Write-Host "--------------------------------------------------------------------------------"
Write-Host "myTenantId                 :",$([Environment]::GetEnvironmentVariable('myTenantId', 'User'))
Write-Host "mySubscriptionId           :",$([Environment]::GetEnvironmentVariable('mySubscriptionId', 'User'))
Write-Host "myResourceGroup            :",$([Environment]::GetEnvironmentVariable('myResourceGroup', 'User'))
Write-Host "myServicePrincipalId       :",$([Environment]::GetEnvironmentVariable('myServicePrincipalId', 'User'))
Write-Host "myServicePrincipalObjectId :",$([Environment]::GetEnvironmentVariable('myServicePrincipalObjectId', 'User'))
Write-Host "myServicePrincipalSecret   :",$([Environment]::GetEnvironmentVariable('myServicePrincipalSecret', 'User'))
Write-Host "myAzureLocation            :",$([Environment]::GetEnvironmentVariable('myAzureLocation', 'User'))
Write-Host "myAzureADGroup             :",$([Environment]::GetEnvironmentVariable('myAzureADGroup', 'User'))
Write-Host "--------------------------------------------------------------------------------"
Write-Host ""
Write-Host "Commands to replicate to .profile for Linux"
Write-Host "--------------------------------------------------------------------------------"
Write-Host "export myTenantId=",$([Environment]::GetEnvironmentVariable('myTenantId', 'User'))
Write-Host "export mySubscriptionId=",$([Environment]::GetEnvironmentVariable('mySubscriptionId', 'User'))
Write-Host "export myResourceGroup=",$([Environment]::GetEnvironmentVariable('myResourceGroup', 'User'))
Write-Host "export myServicePrincipalId=",$([Environment]::GetEnvironmentVariable('myServicePrincipalId', 'User'))
Write-Host "export myServicePrincipalObjectId=",$([Environment]::GetEnvironmentVariable('myServicePrincipalObjectId', 'User'))
Write-Host "export myServicePrincipalSecret=",$([Environment]::GetEnvironmentVariable('myServicePrincipalSecret', 'User'))
Write-Host "export myAzureLocation=",$([Environment]::GetEnvironmentVariable('myAzureLocation', 'User'))
Write-Host "export myAzureADGroup=",$([Environment]::GetEnvironmentVariable('myAzureADGroup', 'User'))
Write-Host "--------------------------------------------------------------------------------"

