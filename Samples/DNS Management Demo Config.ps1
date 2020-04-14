Configuration DnsAdmin
{
    Import-DscResource -Module JeaDsc

    File StartupScript
    {
        DestinationPath = 'C:\ProgramData\DnsManagementEndpoint\Startup.ps1'
        Contents        = @'
Write-Host 'DNS Management Endpoint' -ForegroundColor Green
'@
        Ensure          = 'Present'
        Type            = 'File'
        Force           = $true
    }

    JeaRoleCapabilities DnsAdminRoleCapability
    {
        Path           = 'C:\Program Files\WindowsPowerShell\Modules\DnsAdministration\RoleCapabilities\DnsAdmin.psrc'
        VisibleCmdlets = "@{
            Name       = 'Restart-Service'
            Parameters = @{
                Name        = 'Name'
                ValidateSet = 'Dns'
            }
        }"
        Description    = 'DnsAdmin demo role capability file'
    }

    JeaRoleCapabilities DnsViewerRoleCapability
    {
        Path                = 'C:\Program Files\WindowsPowerShell\Modules\DnsAdministration\RoleCapabilities\DnsViewer.psrc'
        VisibleCmdlets      = 'DnsServer\Get-*'
        VisibleFunctions    = 'Get-DnsServerLog'
        FunctionDefinitions = '@{
            Name = "Get-DnsServerLog"
            ScriptBlock = { param([long]$MaxEvents = 100) Get-WinEvent -ProviderName Microsoft-Windows-Dns-Server-Service -MaxEvents $MaxEvents }
        }'
        Description         = 'DnsViewer demo role capability file'
    }

    JeaSessionConfiguration DnsManagementEndpoint
    {
        Name                = 'DnsManagement'
        RoleDefinitions     = "@{
            'Contoso\DnsAdmins'    = @{ RoleCapabilities = 'DnsAdmin' }
            'Contoso\Domain Users' = @{ RoleCapabilities = 'DnsViewer' }
        }"
        TranscriptDirectory = 'C:\ProgramData\DnsManagementEndpoint\Transcripts'
        ScriptsToProcess    = 'C:\ProgramData\DnsManagementEndpoint\Startup.ps1'
        DependsOn           = '[JeaRoleCapabilities]DnsAdminRoleCapability', '[JeaRoleCapabilities]DnsViewerRoleCapability'
    }
}

#Remove-Item -Path C:\DSC\* -ErrorAction SilentlyContinue
#DnsAdmin -OutputPath C:\DSC -Verbose
#
#Start-DscConfiguration -Path C:\DSC -Wait -Verbose -Force
