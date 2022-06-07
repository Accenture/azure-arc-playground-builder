Param(
    [Parameter()]
    $Email
)

# https://docs.microsoft.com/en-us/powershell/module/microsoft.graph.identity.signins/new-mginvitation?view=graph-powershell-1.0
# todo:
# - wait for 30s 
# -   add to aad group that has access to azure subscription
# -   add to aad group that has access to aad app admin
# - make sure we know cleanup script to delete user

Connect-MgGraph -TenantId $Env:myTenantId -Scopes user.readwrite.all
New-MgInvitation  -InvitedUserEmailAddress $Email -InviteRedirectUrl "https://go.accenture.com/azurehack" -SendInvitationMessage:$true

$UserId = (Get-MgUser -Filter "Mail eq '$Email'").Id
$UserPrincipalName =  (Get-MgUser -Filter "Mail eq '$Email'").UserPrincipalName
$GroupObjectId = (Get-AzureADGroup -Filter "DisplayName eq 'Hackathon'").ObjectId

