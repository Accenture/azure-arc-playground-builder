Import-Module AksHci
Get-Command -Module AksHci

Initialize-AksHciNode

New-Item -Path "V:\" -Name "AKS-HCI" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "Images" -ItemType "directory" -Force
New-Item -Path "V:\AKS-HCI\" -Name "Config" -ItemType "directory" -Force

$vnet = New-AksHciNetworkSetting -Name "mgmtvnet" -vSwitchName "InternalNAT" `
    -vipPoolStart "192.168.0.150" -vipPoolEnd "192.168.0.250"

Set-AksHciConfig -vnet $vnet -imageDir "V:\AKS-HCI\Images" -cloudConfigLocation "V:\AKS-HCI\Config" -Verbose