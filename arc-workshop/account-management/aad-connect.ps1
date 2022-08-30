Write-Host "Connecting to Microsoft Graph for Tenant Id $Env:myAzureTenantId"
Connect-MgGraph -TenantId $Env:myAzureTenantId -Scopes "User.ReadWrite.All","Application.ReadWrite.All","Group.ReadWrite.All", "Directory.ReadWrite.All"
