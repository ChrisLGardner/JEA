Configuration WildcardVisibleCmdlets {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Import-DscResource -ModuleName JeaDsc

    node localhost {

        JeaRoleCapabilities WildcardVisibleCmdlets {
            Path = $Path
            Ensure = 'Present'
            VisibleCmdlets = 'Get-*','DnsServer\*'
        }

    }
}
