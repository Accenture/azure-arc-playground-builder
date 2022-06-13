Write-Host "Current User Environment Variables"

Write-Host "myTenantId                 :",$([Environment]::GetEnvironmentVariable('myTenantId', 'User'))
Write-Host "mySubscriptionId           :",$([Environment]::GetEnvironmentVariable('mySubscriptionId', 'User'))
Write-Host "myResourceGroup            :",$([Environment]::GetEnvironmentVariable('myResourceGroup', 'User'))
Write-Host "myServicePrincipalId       :",$([Environment]::GetEnvironmentVariable('myServicePrincipalId', 'User'))
Write-Host "myServicePrincipalObjectId :",$([Environment]::GetEnvironmentVariable('myServicePrincipalObjectId', 'User'))
Write-Host "myServicePrincipalSecret   :",$([Environment]::GetEnvironmentVariable('myServicePrincipalSecret', 'User'))
Write-Host "myAzureLocation            :",$([Environment]::GetEnvironmentVariable('myAzureLocation', 'User'))