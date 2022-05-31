Install-Module -Name Microsoft.Graph.Identity.SignIns
Install-Module -Name Microsoft.Graph.Users
Connect-MgGraph -TenantId $Env:myTenantId -Scopes User.ReadWrite.All

#New-MgInvitation -InvitedUserDisplayName "John Doe" -InvitedUserEmailAddress John@contoso.com -InviteRedirectUrl "https://myapplications.microsoft.com" -SendInvitationMessage:$true
#Get-MgUser -Filter "Mail eq 'John@contoso.com'"
#Remove-AzureADUser -ObjectId "<UPN>"
#Remove-AzureADUser -UserId john_contoso.com#EXT#@fabrikam.onmicrosoft.com
