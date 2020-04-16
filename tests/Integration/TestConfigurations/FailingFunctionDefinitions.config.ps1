Configuration FailingFunctionDefinitions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Import-DscResource -ModuleName JeaDsc

    node localhost {

        JeaRoleCapabilities FailingFunctionDefinitions {
            Path = $Path
            Ensure = 'Present'
            FunctionDefinitions = '@{Name = "Get-ExampleData"; ScriptBlock = {Get-Command} }'
        }

    }
}
