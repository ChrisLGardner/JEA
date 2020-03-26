Configuration GeneralServerMaintenance
{
    Import-DscResource -Module JeaDsc

    File StartupScript {
        DestinationPath = 'C:\ProgramData\DnsManagementEndpoint\Startup.ps1'
        Contents        = @'
Write-Host 'General Server Maintenance Endpoint' -ForegroundColor Green
'@
        Ensure          = 'Present'
        Type            = 'File'
        Force           = $true
    }

    JeaRoleCapabilities GeneralLevel1 {
        Path                    = 'C:\Program Files\WindowsPowerShell\Modules\GeneralServerMaintenance\RoleCapabilities\GeneralLevel1.psrc'
        Description             = 'This role capability exposes basic networking, security, and configuration settings for the local server.'
        VisibleCmdlets          = 'Get-WindowsFeature',
        'Get-HotFix',
        'Defender\*',
        'NetAdapter\*',
        'NetConnection\*',
        'NetSecurity\Get-*',
        'NetTCPIP\*',
        'Clear-DnsClientCache',
        'Set-DnsClientServerAddress',
        'Resolve-DnsName',
        'Get-Service',
        'Restart-Service',
        'Get-Process',
        'Stop-Process',
        'Get-SystemInfo',
        'Restart-Computer',
        'Test-Connection',
        'Microsoft.PowerShell.LocalAccounts\Get-*'
        VisibleExternalCommands = 'C:\Windows\System32\gpupdate.exe', 'C:\Windows\System32\gpresult.exe'
    }

    JeaRoleCapabilities GeneralLevel2 {
        Path                    = 'C:\Program Files\WindowsPowerShell\Modules\GeneralServerMaintenance\RoleCapabilities\GeneralLevel2.psrc'
        Description             = 'This role capability exposes advanced networking, security, and configuration settings for the local server.'
        VisibleCmdlets          = 'ServerManager\*',
        'Get-WinEvent',
        '*-EventLog',
        'Get-HotFix',
        'Defender\*',
        'NetAdapter\*',
        'NetConnection\*',
        'NetSecurity\*',
        'NetTCPIP\*',
        'DnsClient\*',
        'Get-Service',
        'Restart-Service',
        'Resume-Service',
        'Set-Service',
        'Start-Service',
        'Stop-Service',
        'Suspend-Service',
        'Get-Process',
        'Stop-Process',
        'Get-SystemInfo',
        'Restart-Computer',
        'Stop-Computer',
        'Test-Connection',
        'Microsoft.PowerShell.LocalAccounts\Get-*'
        VisibleExternalCommands = 'C:\Windows\System32\gpupdate.exe', 'C:\Windows\System32\gpresult.exe'
    }

    JeaRoleCapabilities IisLevel1 {
        Path           = 'C:\Program Files\WindowsPowerShell\Modules\GeneralServerMaintenance\RoleCapabilities\IisLevel1.psrc'
        Description    = 'This role capability enables management of a local IIS server.'
        VisibleCmdlets =  'WebAdministration\Get-*',
        'Start-WebAppPool',
        'Restart-WebAppPool',
        'Stop-Website',
        'Start-Website',
        'Get-IISSite',
        'Start-IISSite',
        'Stop-IISSite',
        'Get-IISAppPool'
    }

    JeaRoleCapabilities IisLevel2 {
        Path           = 'C:\Program Files\WindowsPowerShell\Modules\GeneralServerMaintenance\RoleCapabilities\IisLevel2.psrc'
        Description    = 'This role capability enables management of a local IIS server and firewall rules.'
        VisibleCmdlets =  'WebAdministration\Clear-WebConfiguration',
        'WebAdministration\ConvertTo-WebApplication',
        'WebAdministration\Get-*',
        'WebAdministration\New-WebBinding',
        'WebAdministration\Remove-WebApplication',
        'WebAdministration\Remove-WebAppPool',
        'WebAdministration\Remove-WebBinding',
        'WebAdministration\Remove-Website',
        'WebAdministration\Remove-WebVirtualDirectory',
        'WebAdministration\Restart-WebApppool',
        'WebAdministration\Set-WebBinding',
        'WebAdministration\Start-WebAppPool',
        'WebAdministration\Start-Website',
        'WebAdministration\Stop-WebAppPool',
        'WebAdministration\Stop-Website',
        'IISAdministration\Get-IISAppPool',
        'IISAdministration\Remove-IISSite',
        'IISAdministration\Start-IISSite',
        'IISAdministration\Stop-IISSite',
        'NetSecurity\*'
    }

    JeaSessionConfiguration GeneralServerMaintenanceEndpoint {
        Name                = 'GeneralServerMaintenance'
        TranscriptDirectory = 'C:\ProgramData\GeneralServerMaintenance\Transcripts'
        ScriptsToProcess    = 'C:\ProgramData\GeneralServerMaintenance\Startup.ps1'
        #DependsOn           = '[JeaRoleCapabilities]DnsAdminRoleCapability'
        SessionType         = 'RestrictedRemoteServer'
        RunAsVirtualAccount =  $true
        RoleDefinitions     = "@{
            'Contoso\Chile'      = @{ RoleCapabilities = 'GeneralLevel1' }
            'Contoso\Peru'       = @{ RoleCapabilities = 'GeneralLevel1', 'GeneralLevel2' }
            'Contoso\Venezuela'  = @{ RoleCapabilities = 'IisLevel1' }
            'Contoso\Uruguay'    = @{ RoleCapabilities = 'IisLevel1', 'IisLevel2' }
        }"
    }

}

Remove-Item -Path C:\DSC\*
GeneralServerMaintenance -OutputPath C:\DSC -Verbose

Start-DscConfiguration -Path C:\DSC -Wait -Verbose -Force
