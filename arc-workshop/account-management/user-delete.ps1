Param(
    [Parameter()]
    $Email
)


Write-Host "Connecting to Microsoft Graph for Tenant Id $Env:myTenantId"
Connect-MgGraph -TenantId $Env:myTenantId -Scopes "User.ReadWrite.All","Application.ReadWrite.All","Group.ReadWrite.All", "Directory.ReadWrite.All"

Remove-MgUser -UserId (Get-MgUser -Filter "Mail eq '$Email'").Id

Read-Host -Prompt 'All done - press enter to continue!'
