$MyAzureTenantId = Read-Host -Prompt 'Input your Tenant Id'
$MyAzureSubscriptionId = Read-Host -Prompt 'Input your Subscription Id'
$MyAzureResourceGroup = Read-Host -Prompt 'Input your Resource Group'
$MyAzureServicePrincipalId = Read-Host -Prompt 'Input your Service Principal Id'
$MyAzureServicePrincipalObjectId = Read-Host -Prompt 'Input your Service Principal ObjectId'
$MyAzureServicePrincipalSecret = Read-Host -Prompt 'Input your Service Principal Secret'
$MyAzureLocation = Read-Host -Prompt "Input your main Azure location"
$MyAzureADGroup = Read-Host -Prompt "Input your main Azure AD Security Group"

Write-Host "Setting User Environment Variables"

[System.Environment]::SetEnvironmentVariable('myAzureTenantId',$MyAzureTenantId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureSubscriptionId',$MyAzureSubscriptionId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureResourceGroup',$MyAzureResourceGroup,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureServicePrincipalId',$MyAzureServicePrincipalId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureServicePrincipalObjectId',$MyAzureServicePrincipalObjectId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureServicePrincipalSecret',$MyAzureServicePrincipalSecret,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureLocation',$MyAzureLocation,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureADGroup',$MyAzureADGroup,[System.EnvironmentVariableTarget]::User)

Write-Host "Done Setting User Environment Variables"
