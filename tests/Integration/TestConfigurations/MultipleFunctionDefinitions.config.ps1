function F1
{
    Get-Date
    Get-Process
}

function F2
{
    Get-Service | Where-Object Status -eq running
}

configuration MultipleFunctionDefinitions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Import-DscResource -ModuleName JeaDsc

    $visibleFunctions = 'F1', 'F2'

    $functionDefinitions = @()
    foreach ($visibleFunction in $visibleFunctions)
    {
        $functionDefinitions += @{
            Name        = $visibleFunction
            ScriptBlock = (Get-Command -Name $visibleFunction).ScriptBlock
        } | ConvertTo-Expression
    }

    node localhost {

        JeaRoleCapabilities MultipleFunctionDefinitions {
            Path = $Path
            Ensure = 'Present'
            FunctionDefinitions = $functionDefinitions
            VisibleFunctions = $visibleFunctions
        }

    }
}
