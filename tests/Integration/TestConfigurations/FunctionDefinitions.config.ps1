Configuration FunctionDefinitions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Import-DscResource -ModuleName JeaDsc

    node localhost {

        JeaRoleCapabilities FunctionDefinitions {
            Path = $Path
            Ensure = 'Present'
            FunctionDefinitions = '@{Name = "Get-ExampleData"; ScriptBlock = {Get-Command} }'
            VisibleFunctions = 'Get-ExampleData'
        }

    }
}
