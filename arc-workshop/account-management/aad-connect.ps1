Write-Host "Connecting to Microsoft Graph for Tenant Id $Env:myTenantId"
Connect-MgGraph -TenantId $Env:myTenantId -Scopes "User.ReadWrite.All","Application.ReadWrite.All","Group.ReadWrite.All", "Directory.ReadWrite.All"
