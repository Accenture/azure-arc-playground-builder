Write-Host "Current User Environment Variables"
Write-Host "--------------------------------------------------------------------------------"
Write-Host "myAzureTenantId                 :",$([Environment]::GetEnvironmentVariable('myAzureTenantId', 'User'))
Write-Host "myAzureSubscriptionId           :",$([Environment]::GetEnvironmentVariable('myAzureSubscriptionId', 'User'))
Write-Host "myAzureResourceGroup            :",$([Environment]::GetEnvironmentVariable('myAzureResourceGroup', 'User'))
Write-Host "myAzureServicePrincipalId       :",$([Environment]::GetEnvironmentVariable('myAzureServicePrincipalId', 'User'))
Write-Host "myAzureServicePrincipalObjectId :",$([Environment]::GetEnvironmentVariable('myAzureServicePrincipalObjectId', 'User'))
Write-Host "myAzureServicePrincipalSecret   :",$([Environment]::GetEnvironmentVariable('myAzureServicePrincipalSecret', 'User'))
Write-Host "myAzureLocation            :",$([Environment]::GetEnvironmentVariable('myAzureLocation', 'User'))
Write-Host "myAzureADGroup             :",$([Environment]::GetEnvironmentVariable('myAzureADGroup', 'User'))
Write-Host "--------------------------------------------------------------------------------"
Write-Host ""
Write-Host "Commands to replicate to .profile for Linux"
Write-Host "--------------------------------------------------------------------------------"
Write-Host "export myAzureTenantId=",$([Environment]::GetEnvironmentVariable('myAzureTenantId', 'User'))
Write-Host "export myAzureSubscriptionId=",$([Environment]::GetEnvironmentVariable('myAzureSubscriptionId', 'User'))
Write-Host "export myAzureResourceGroup=",$([Environment]::GetEnvironmentVariable('myAzureResourceGroup', 'User'))
Write-Host "export myAzureServicePrincipalId=",$([Environment]::GetEnvironmentVariable('myAzureServicePrincipalId', 'User'))
Write-Host "export myAzureServicePrincipalObjectId=",$([Environment]::GetEnvironmentVariable('myAzureServicePrincipalObjectId', 'User'))
Write-Host "export myAzureServicePrincipalSecret=",$([Environment]::GetEnvironmentVariable('myAzureServicePrincipalSecret', 'User'))
Write-Host "export myAzureLocation=",$([Environment]::GetEnvironmentVariable('myAzureLocation', 'User'))
Write-Host "export myAzureADGroup=",$([Environment]::GetEnvironmentVariable('myAzureADGroup', 'User'))
Write-Host "--------------------------------------------------------------------------------"

