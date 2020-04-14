function Get-DscConfigurationVersion
{
    New-Object -TypeName PSObject -Property @{
        Version     = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name Version
        Environment = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name Environment
        GitCommitId = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name GitCommitId
        BuildDate   = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name BuildDate
    }
}

function Test-DscConfiguration
{
    PSDesiredStateConfiguration\Test-DscConfiguration -Detailed -Verbose
}

function Update-DscConfiguration
{
    PSDesiredStateConfiguration\Update-DscConfiguration -Wait -Verbose
}

function Get-DscLcmControllerSummary
{
    Import-Csv -Path C:\ProgramData\Dsc\LcmController\LcmControllerSummary.txt
}

function Start-DscConfiguration
{
    PSDesiredStateConfiguration\Start-DscConfiguration -UseExisting -Wait -Verbose
}

$visibleFunctions = 'Test-DscConfiguration', 'Get-DscConfigurationVersion', 'Update-DscConfiguration', 'Get-DscLcmControllerSummary', 'Start-DscConfiguration'
$functionDefinitions = @()
foreach ($visibleFunction in $visibleFunctions)
{
    $functionDefinitions += @{
        Name        = $visibleFunction
        ScriptBlock = (Get-Command -Name $visibleFunction).ScriptBlock
    } | ConvertTo-Expression
}

Configuration DscDiagnostic
{
    Import-DscResource -Module JeaDsc

    JeaRoleCapabilities DiagnosticRole
    {
        Path                = 'C:\Program Files\WindowsPowerShell\Modules\DscDiagnostics\RoleCapabilities\DiagnosticRole.psrc'
        VisibleFunctions    = $visibleFunctions
        FunctionDefinitions = $functionDefinitions
    }

    JeaSessionConfiguration DscDiagnosticEndpoint
    {
        Ensure          = 'Present'
        DependsOn       = '[JeaRoleCapabilities]DiagnosticRole'
        Name            = 'DSC'
        RoleDefinitions = '@{ Everyone = @{ RoleCapabilities = "DiagnosticRole" } }'
        SessionType     = 'RestrictedRemoteServer'
        ModulesToImport = 'PSDesiredStateConfiguration'
    }

}

#Remove-Item -Path C:\DSC\* -ErrorAction SilentlyContinue
#DscDiagnostic -OutputPath C:\DSC -Verbose
#
#Start-DscConfiguration -Path C:\DSC -Wait -Verbose -Force
