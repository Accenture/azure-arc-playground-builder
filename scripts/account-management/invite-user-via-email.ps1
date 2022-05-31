param($Email)

New-MgInvitation -InvitedUserEmailAddress $Email -InviteRedirectUrl "https://ambg.io/" -SendInvitationMessage:$true
