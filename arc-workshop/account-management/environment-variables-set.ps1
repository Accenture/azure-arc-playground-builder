$MyTenantId = Read-Host -Prompt 'Input your Tenant Id'
$MySubscriptionId = Read-Host -Prompt 'Input your Subscription Id'
$MyResourceGroup = Read-Host -Prompt 'Input your Resource Group'
$MyServicePrincipalId = Read-Host -Prompt 'Input your Service Principal Id'
$MyServicePrincipalObjectId = Read-Host -Prompt 'Input your Service Principal ObjectId'
$MyServicePrincipalSecret = Read-Host -Prompt 'Input your Service Principal Secret'
$MyAzureLocation = Read-Host -Prompt "Input your main Azure location"
$MyAzureADGroup = Read-Host -Prompt "Input your main Azure AD Security Group"

Write-Host "Setting User Environment Variables"

[System.Environment]::SetEnvironmentVariable('myTenantId',$MyTenantId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('mySubscriptionId',$MySubscriptionId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myResourceGroup',$MyResourceGroup,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myServicePrincipalId',$MyServicePrincipalId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myServicePrincipalObjectId',$MyServicePrincipalObjectId,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myServicePrincipalSecret',$MyServicePrincipalSecret,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureLocation',$MyAzureLocation,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('myAzureADGroup',$MyAzureADGroup,[System.EnvironmentVariableTarget]::User)

Write-Host "Done Setting User Environment Variables"
