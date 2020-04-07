enum Ensure
{
    Present
    Absent
}

[DscResource()]
class JeaRoleCapabilities
{

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    # Where to store the file.
    [DscProperty(Key)]
    [string]$Path

    # Specifies the modules that are automatically imported into sessions that use the role capability file.
    # By default, all of the commands in listed modules are visible. When used with VisibleCmdlets or VisibleFunctions,
    # the commands visible from the specified modules can be restricted. Hashtable with keys ModuleName, ModuleVersion and GUID.
    [DscProperty()]
    [string[]]$ModulesToImport

    # Limits the aliases in the session to those aliases specified in the value of this parameter,
    # plus any aliases that you define in the AliasDefinition parameter. Wildcard characters are supported.
    # By default, all aliases that are defined by the Windows PowerShell engine and all aliases that modules export are
    # visible in the session.
    [DscProperty()]
    [string[]]$VisibleAliases

    # Limits the cmdlets in the session to those specified in the value of this parameter.
    # Wildcard characters and Module Qualified Names are supported.
    [DscProperty()]
    [string[]]$VisibleCmdlets

    #  Limits the functions in the session to those specified in the value of this parameter,
    # plus any functions that you define in the FunctionDefinitions parameter. Wildcard characters are supported.
    [DscProperty()]
    [string[]]$VisibleFunctions

    # Limits the external binaries, scripts and commands that can be executed in the session to those specified in
    # the value of this parameter. Wildcard characters are supported.
    [DscProperty()]
    [string[]]$VisibleExternalCommands

    # Limits the Windows PowerShell providers in the session to those specified in the value of this parameter.
    # Wildcard characters are supported.
    [DscProperty()]
    [string[]]$VisibleProviders

    # Specifies scripts to add to sessions that use the role capability file.
    [DscProperty()]
    [string[]]$ScriptsToProcess

    # Adds the specified aliases to sessions that use the role capability file.
    # Hashtable with keys Name, Value, Description and Options.
    [DscProperty()]
    [string[]]$AliasDefinitions

    # Adds the specified functions to sessions that expose the role capability.
    # Hashtable with keys Name, Scriptblock and Options.
    [DscProperty()]
    [string[]]$FunctionDefinitions

    # Specifies variables to add to sessions that use the role capability file.
    # Hashtable with keys Name, Value, Options.
    [DscProperty()]
    [string[]]$VariableDefinitions

    # Specifies the environment variables for sessions that expose this role capability file.
    # Hashtable of environment variables.
    [DscProperty()]
    [string[]]$EnvironmentVariables

    # Specifies type files (.ps1xml) to add to sessions that use the role capability file.
    # The value of this parameter must be a full or absolute path of the type file names.
    [DscProperty()]
    [string[]]$TypesToProcess

    # Specifies the formatting files (.ps1xml) that run in sessions that use the role capability file.
    # The value of this parameter must be a full or absolute path of the formatting files.
    [DscProperty()]
    [string[]]$FormatsToProcess

    # Specifies the assemblies to load into the sessions that use the role capability file.
    [DscProperty()]
    [string]$Description

    # Description of the role
    [DscProperty()]
    [string[]]$AssembliesToLoad

    hidden [boolean] ValidatePath()
    {
        $FileObject = [System.IO.FileInfo]::new($this.Path)
        Write-Verbose -Message "Validating Path: $($FileObject.Fullname)"
        Write-Verbose -Message "Checking file extension is psrc for: $($FileObject.Fullname)"
        if ($FileObject.Extension -ne '.psrc')
        {
            Write-Verbose -Message "Doesn't have psrc extension for: $($FileObject.Fullname)"
            return $false
        }

        Write-Verbose -Message "Checking parent forlder is RoleCapabilities for: $($FileObject.Fullname)"
        if ($FileObject.Directory.Name -ne 'RoleCapabilities')
        {
            Write-Verbose -Message "Parent folder isn't RoleCapabilities for: $($FileObject.Fullname)"
            return $false
        }

        Write-Verbose -Message "Checking Folder is in PSModulePath is psrc for: $($FileObject.Fullname)"
        $PSModulePathRegexPattern = (([Regex]::Escape($env:PSModulePath)).TrimStart(';').TrimEnd(';') -replace ';', '|')
        if ($FileObject.FullName -notmatch $PSModulePathRegexPattern)
        {
            Write-Verbose -Message "Path isn't part of PSModulePath, valid values are:"
            foreach ($path in $env:PSModulePath -split ';')
            {
                Write-Verbose -Message "$Path"
            }
            return $false
        }

        Write-Verbose -Message "Path is a valid psrc path. Returning true."
        #Wait-Debugger
        return $true
    }

    [JeaRoleCapabilities] Get()
    {
        $currentState = [JeaRoleCapabilities]::new()
        $currentState.Path = $this.Path
        if (Test-Path -Path $this.Path)
        {
            $currentStateFile = Import-PowerShellDataFile -Path $this.Path

            'Copyright', 'GUID', 'Author', 'CompanyName' | Foreach-Object {
                $currentStateFile.Remove($_)
            }

            foreach ($property in $currentStateFile.Keys)
            {
                $propertyType = ($this | Get-Member -Name $property -MemberType Property).Definition.Split(' ')[0]
                $currentState.$property = foreach ($propertyValue in $currentStateFile[$property])
                {
                    if ($propertyValue -is [hashtable] -and $propertyType -ne 'hashtable')
                    {
                        if ($propertyValue.ScriptBlock -is [scriptblock])
                        {
                            $code = $propertyValue.ScriptBlock.Ast.Extent.Text
                            $code -match '(?<=\{)(?<Code>((.|\s)*))(?=\})' | Out-Null
                            $propertyValue.ScriptBlock = [scriptblock]::Create($Matches.Code)
                        }

                        ConvertTo-Expression -Object $propertyValue
                    }
                    elseif ($propertyValue -is [hashtable] -and $propertyType -eq 'hashtable')
                    {
                        $propertyValue
                    }
                    else
                    {
                        $propertyValue
                    }
                }
            }
            $currentState.Ensure = [Ensure]::Present
        }
        else
        {
            $currentState.Ensure = [Ensure]::Absent
        }

        return $currentState
    }

    [void] Set()
    {
        if ($this.Ensure -eq [Ensure]::Present)
        {
            $parameters = Convert-ObjectToHashtable -Object $this

            foreach ($parameter in $parameters.Keys.Where( { $parameters[$_] -match '@{' }))
            {
                $parameters[$parameter] = Convert-StringToObject -InputString $parameters[$parameter]
            }

            $null = New-Item -Path $this.Path -ItemType File -Force

            $parameters = Sync-Parameter -Command (Get-Command -Name New-PSRoleCapabilityFile) -Parameters $parameters
            New-PSRoleCapabilityFile @parameters
        }
        elseif ($this.Ensure -eq [Ensure]::Absent -and (Test-Path -Path $this.Path))
        {
            Remove-Item -Path $this.Path -Confirm:$false -Force
        }

    }

    [bool] Test()
    {
        if (-not ($this.ValidatePath()))
        {
            Write-Error -Message "Invalid path specified. It must point to a Module folder, be a psrc file and the parent folder must be called RoleCapabilities"
            return $false
        }
        if ($this.Ensure -eq [Ensure]::Present -and -not (Test-Path -Path $this.Path))
        {
            return $false
        }
        elseif ($this.Ensure -eq [Ensure]::Present -and (Test-Path -Path $this.Path))
        {

            $currentState = Convert-ObjectToHashtable -Object $this.Get()
            $parameters = Convert-ObjectToHashtable -Object $this

            $cmdlet = Get-Command -Name New-PSRoleCapabilityFile
            $parameters = Sync-Parameter -Command $cmdlet -Parameters $parameters
            $currentState = Sync-Parameter -Command $cmdlet -Parameters $currentState
            $propertiesAsObject = $cmdlet.Parameters.Keys |
            Where-Object { $_ -in $parameters.Keys } |
            Where-Object { $cmdlet.Parameters.$_.ParameterType.FullName -in 'System.Collections.IDictionary', 'System.Collections.Hashtable', 'System.Collections.IDictionary[]', 'System.Object[]' }
            foreach ($p in $propertiesAsObject)
            {
                if ($cmdlet.Parameters.$p.ParameterType.FullName -in 'System.Collections.Hashtable', 'System.Collections.IDictionary', 'System.Collections.IDictionary[]', 'System.Object[]')
                {
                    $parameters."$($p)" = $parameters."$($p)" | Convert-StringToObject
                    $currentState."$($p)" = $currentState."$($p)" | Convert-StringToObject

                }
            }

            $compare = Test-DscParameterState -CurrentValues $currentState -DesiredValues $Parameters -SortArrayValues -TurnOffTypeChecking

            return $compare
        }
        elseif ($this.Ensure -eq [Ensure]::Absent -and (Test-Path -Path $this.Path))
        {
            return $false
        }
        elseif ($this.Ensure -eq [Ensure]::Absent -and -not (Test-Path -Path $this.Path))
        {
            return $true
        }

        return $false
    }
}
