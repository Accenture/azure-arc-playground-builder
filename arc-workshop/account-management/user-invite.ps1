Param(
    [Parameter()]
    $Email
)

Write-Host "Connecting to Microsoft Graph for Tenant Id $Env:myAzureTenantId"
Connect-MgGraph -TenantId $Env:myAzureTenantId -Scopes "User.ReadWrite.All","Application.ReadWrite.All","Group.ReadWrite.All", "Directory.ReadWrite.All"

Write-Host "Inviting $Email to the tenant"
New-MgInvitation  -InvitedUserEmailAddress $Email -InviteRedirectUrl "https://go.accenture.com/azurehack" -SendInvitationMessage:$true

Write-Host "Invited $Email to tenant, waiting 30 seconds"
Start-Sleep -Seconds 30

$UserId=(Get-MgUser -Filter "Mail eq '$Email'").Id
$HackathonGroupId=(Get-MgGroup -Filter "DisplayName eq 'Hackathon'").Id

Write-Host "UserId=$UserId"
Write-Host "HackathonGroupId=$HackathonGroupId"

Read-Host -Prompt "If UserId isn't found, abort!"

Write-Host "Adding to Hackthaon Azure AD Group"
New-MgGroupMember -GroupId $HackathonGroupId -DirectoryObjectId $UserId

Read-Host -Prompt 'All done - press enter to continue!'
