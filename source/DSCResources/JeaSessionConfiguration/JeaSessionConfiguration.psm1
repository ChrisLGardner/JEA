enum Ensure {
    Present
    Absent
}

[DscResource()]
class JeaSessionConfiguration {
    ## The optional state that ensures the endpoint is present or absent. The defualt value is [Ensure]::Present.
    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    ## The mandatory endpoint name. Use 'Microsoft.PowerShell' by default.
    [DscProperty(Key)]
    [string] $Name = 'Microsoft.PowerShell'

    ## The mandatory role definition map to be used for the endpoint. This
    ## should be a string that represents the Hashtable used for the RoleDefinitions
    ## property in New-PSSessionConfigurationFile, such as:
    ## RoleDefinitions = '@{ Everyone = @{ RoleCapabilities = "BaseJeaCapabilities" } }'
    [Dscproperty(Mandatory)]
    [string] $RoleDefinitions
    
    ## run the endpoint under a Virtual Account
    [DscProperty()]
    [bool] $RunAsVirtualAccount

    ## The optional groups to be used when the endpoint is configured to
    ## run as a Virtual Account
    [DscProperty()]
    [string[]] $RunAsVirtualAccountGroups

    ## The optional Group Managed Service Account (GMSA) to use for this
    ## endpoint. If configured, will disable the default behaviour of
    ## running as a Virtual Account
    [DscProperty()]
    [string] $GroupManagedServiceAccount

    ## The optional directory for transcripts to be saved to
    [DscProperty()]
    [string] $TranscriptDirectory

    ## The optional startup script for the endpoint
    [DscProperty()]
    [string[]] $ScriptsToProcess

    ## The optional session type for the endpoint
    [DscProperty()]
    [string] $SessionType

    ## The optional switch to enable mounting of a restricted user drive
    [Dscproperty()]
    [bool] $MountUserDrive

    ## The optional size of the user drive. The default is 50MB.
    [Dscproperty()]
    [long] $UserDriveMaximumSize

    ## The optional expression declaring which domain groups (for example,
    ## two-factor authenticated users) connected users must be members of. This
    ## should be a string that represents the Hashtable used for the RequiredGroups
    ## property in New-PSSessionConfigurationFile, such as:
    ## RequiredGroups = '@{ And = "RequiredGroup1", @{ Or = "OptionalGroup1", "OptionalGroup2" } }'
    [Dscproperty()]
    [string] $RequiredGroups

    ## The optional modules to import when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## ModulesToImport = "'MyCustomModule', @{ ModuleName = 'MyCustomModule'; ModuleVersion = '1.0.0.0'; GUID = '4d30d5f0-cb16-4898-812d-f20a6c596bdf' }"
    [Dscproperty()]
    [string] $ModulesToImport

    ## The optional aliases to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleAliases

    ## The optional cmdlets to make visible when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## VisibleCmdlets = "'Invoke-Cmdlet1', @{ Name = 'Invoke-Cmdlet2'; Parameters = @{ Name = 'Parameter1'; ValidateSet = 'Item1', 'Item2' }, @{ Name = 'Parameter2'; ValidatePattern = 'L*' } }"
    [Dscproperty()]
    [string[]] $VisibleCmdlets

    ## The optional functions to make visible when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## VisibleFunctions = "'Invoke-Function1', @{ Name = 'Invoke-Function2'; Parameters = @{ Name = 'Parameter1'; ValidateSet = 'Item1', 'Item2' }, @{ Name = 'Parameter2'; ValidatePattern = 'L*' } }"
    [Dscproperty()]
    [string[]] $VisibleFunctions

    ## The optional external commands (scripts and applications) to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleExternalCommands

    ## The optional providers to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleProviders

    ## The optional aliases to be defined when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## AliasDefinitions = "@{ Name = 'Alias1'; Value = 'Invoke-Alias1'}, @{ Name = 'Alias2'; Value = 'Invoke-Alias2'}"
    [Dscproperty()]
    [string] $AliasDefinitions

    ## The optional functions to define when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## FunctionDefinitions = "@{ Name = 'MyFunction'; ScriptBlock = { param($MyInput) $MyInput } }"
    [Dscproperty()]
    [string[]] $FunctionDefinitions

    ## The optional variables to define when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## VariableDefinitions = "@{ Name = 'Variable1'; Value = { 'Dynamic' + 'InitialValue' } }, @{ Name = 'Variable2'; Value = 'StaticInitialValue' }"
    [Dscproperty()]
    [string] $VariableDefinitions

    ## The optional environment variables to define when applied to a session
    ## This should be a string that represents a Hashtable
    ## EnvironmentVariables = "@{ Variable1 = 'Value1'; Variable2 = 'Value2' }"
    [Dscproperty()]
    [string] $EnvironmentVariables

    ## The optional type files (.ps1xml) to load when applied to a session
    [Dscproperty()]
    [string[]] $TypesToProcess

    ## The optional format files (.ps1xml) to load when applied to a session
    [Dscproperty()]
    [string[]] $FormatsToProcess

    ## The optional assemblies to load when applied to a session
    [Dscproperty()]
    [string[]] $AssembliesToLoad

    ## The optional number of seconds to wait for registering the endpoint to complete.
    ## 0 for no timeout
    [int] $HungRegistrationTimeout = 10
    
    JeaSessionConfiguration() {
        if (-not $this.SessionType) {
            $this.SessionType = 'RestrictedRemoteServer'
        }
        
        if ($this.RunAsVirtualAccountGroups -and $this.GroupManagedServiceAccount) {
            throw "The RunAsVirtualAccountGroups setting can not be used when a configuration is set to run as a Group Managed Service Account"
        }
        
        if ($this.GroupManagedServiceAccount -and $this.RunAsVirtualAccount) {
            throw "The properties 'GroupManagedServiceAccount' and 'RunAsVirtualAccount' cannot be used together."
        }

        if (-not $this.GroupManagedServiceAccount) {
            $this.RunAsVirtualAccount = $true
            Write-Warning "'GroupManagedServiceAccount' and 'RunAsVirtualAccount' are not defined, setting 'RunAsVirtualAccount' to 'true'."
        }
    }

    ## Applies the JEA configuration
    [void] Set() {
        $ErrorActionPreference = 'Stop'

        $psscPath = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + ".pssc")
        $configurationFileArguments = @{
            Path        = $psscPath
            SessionType = $this.SessionType
        }

        $Parameters = Convert-ObjectToHashtable($this)
        $Parameters.Remove('Ensure')
        $Parameters.Remove('HungRegistrationTimeout')
        $Parameters.Remove('Name')
        $Parameters.Add('Path', $psscPath)

        if ($this.Ensure -eq [Ensure]::Present) {

            foreach ($Parameter in $Parameters.Keys.Where( { $Parameters[$_] -match '@{' })) {
                $Parameters[$Parameter] = Convert-StringToObject -InputString $Parameters[$Parameter]
            }

            ## Convert the RoleDefinitions string to the actual hashtable
            $configurationFileArguments["RoleDefinitions"] = Convert-StringToHashtable -HashtableAsString $this.RoleDefinitions

            ## Set up the JEA identity            
            if ($this.RunAsVirtualAccount) {
                $configurationFileArguments['RunAsVirtualAccount'] = $true
            }

            if ($this.RunAsVirtualAccountGroups) {
                $configurationFileArguments["RunAsVirtualAccount"] = $true
                $configurationFileArguments["RunAsVirtualAccountGroups"] = $this.RunAsVirtualAccountGroups
            }
            elseif ($this.GroupManagedServiceAccount) {
                $configurationFileArguments["GroupManagedServiceAccount"] = $this.GroupManagedServiceAccount -replace '\$$', ''
            }
            else {
                $configurationFileArguments["RunAsVirtualAccount"] = $true
            }

            ## Transcripts
            if ($this.TranscriptDirectory) {
                $configurationFileArguments["TranscriptDirectory"] = $this.TranscriptDirectory
            }

            ## SessionType
            if ($this.SessionType) {
                $configurationFileArguments["SessionType"] = $this.SessionType
            }

            ## Startup scripts
            if ($this.ScriptsToProcess) {
                $configurationFileArguments["ScriptsToProcess"] = $this.ScriptsToProcess
            }

            ## Mount user drive
            if ($this.MountUserDrive) {
                $configurationFileArguments["MountUserDrive"] = $this.MountUserDrive
            }

            ## User drive maximum size
            if ($this.UserDriveMaximumSize) {
                $configurationFileArguments["UserDriveMaximumSize"] = $this.UserDriveMaximumSize
                $configurationFileArguments["MountUserDrive"] = $true
            }

            ## Required groups
            if ($this.RequiredGroups) {
                ## Convert the RequiredGroups string to the actual Hashtable
                $requiredGroupsHash = Convert-StringToHashtable -HashtableAsString $this.RequiredGroups
                $configurationFileArguments["RequiredGroups"] = $requiredGroupsHash
            }

            ## Modules to import
            if ($this.ModulesToImport) {
                $configurationFileArguments["ModulesToImport"] = Convert-StringToArrayOfObject -LiteralString $this.ModulesToImport
            }

            ## Visible aliases
            if ($this.VisibleAliases) {
                $configurationFileArguments["VisibleAliases"] = $this.VisibleAliases
            }

            ## Visible cmdlets
            if ($this.VisibleCmdlets) {
                Write-Verbose "VisibleCmdlets: $($this.VisibleCmdlets)"
                $configurationFileArguments["VisibleCmdlets"] = Convert-StringToArrayOfObject -LiteralString $this.VisibleCmdlets
            }

            ## Visible functions
            if ($this.VisibleFunctions) {
                $configurationFileArguments["VisibleFunctions"] = Convert-StringToArrayOfObject -LiteralString $this.VisibleFunctions
            }

            ## Visible external commands
            if ($this.VisibleExternalCommands) {
                $configurationFileArguments["VisibleExternalCommands"] = $this.VisibleExternalCommands
            }

            ## Visible providers
            if ($this.VisibleProviders) {
                $configurationFileArguments["VisibleProviders"] = $this.VisibleProviders
            }

            ## Visible providers
            if ($this.VisibleProviders) {
                $configurationFileArguments["VisibleProviders"] = $this.VisibleProviders
            }

            ## Alias definitions
            if ($this.AliasDefinitions) {
                $configurationFileArguments["AliasDefinitions"] = Convert-StringToArrayOfHashtable -LiteralString $this.AliasDefinitions
            }

            ## Function definitions
            if ($this.FunctionDefinitions) {
                $configurationFileArguments["FunctionDefinitions"] = Convert-StringToArrayOfHashtable -LiteralString $this.FunctionDefinitions
            }

            ## Variable definitions
            if ($this.VariableDefinitions) {
                $configurationFileArguments["VariableDefinitions"] = Convert-StringToArrayOfHashtable -LiteralString $this.VariableDefinitions
            }

            ## Environment variables
            if ($this.EnvironmentVariables) {
                $configurationFileArguments["EnvironmentVariables"] = Convert-StringToHashtable -HashtableAsString $this.EnvironmentVariables
            }

            ## Types to process
            if ($this.TypesToProcess) {
                $configurationFileArguments["TypesToProcess"] = $this.TypesToProcess
            }

            ## Formats to process
            if ($this.FormatsToProcess) {
                $configurationFileArguments["FormatsToProcess"] = $this.FormatsToProcess
            }

            ## Assemblies to load
            if ($this.AssembliesToLoad) {
                $configurationFileArguments["AssembliesToLoad"] = $this.AssembliesToLoad
            }
        }

        ## Register the endpoint
        try {
            ## If we are replacing Microsoft.PowerShell, create a 'break the glass' endpoint
            if ($this.Name -eq "Microsoft.PowerShell") {
                $breakTheGlassName = "Microsoft.PowerShell.Restricted"
                if (-not ($this.GetPSSessionConfiguration($breakTheGlassName))) {
                    $this.RegisterPSSessionConfiguration($breakTheGlassName, $null, $this.HungRegistrationTimeout)
                }
            }

            ## Remove the previous one, if any.
            if ($this.GetPSSessionConfiguration($this.Name)) {
                $this.UnregisterPSSessionConfiguration($this.Name)
            }

            if ($this.Ensure -eq [Ensure]::Present) {
                ## Create the configuration file
                $r = @{}
                New-PSSessionConfigurationFile @configurationFileArguments #-RoleDefinitions $r
                ## Register the configuration file
                $this.RegisterPSSessionConfiguration($this.Name, $psscPath, $this.HungRegistrationTimeout)

            }
        }
        catch {
            Write-Error -ErrorRecord $_
        }
        finally {
            if (Test-Path $psscPath) {
                Remove-Item $psscPath
            }
        }
    }

    # Tests if the resource is in the desired state.
    [bool] Test() {
        $currentState = Convert-ObjectToHashtable -Object $this.Get()

        # short-circuit if the resource is not present and is not supposed to be present
        if ($this.Ensure -eq [Ensure]::Absent) {
            if ($currentState.Ensure -eq [Ensure]::Absent) {
                return $true
            }

            Write-Verbose "Name present: $($currentState.Name)"
            return $false
        }

        if ($currentState.Name -ne $this.Name) {
            Write-Verbose "Name not equal: $($currentState.Name)"
            return $false
        }

        $parameters = Convert-ObjectToHashtable -Object $this
        $parameters.Remove('HungRegistrationTimeout')
        $currentState.Remove('HungRegistrationTimeout')

        $compare = Compare-JeaConfiguration -ReferenceObject $currentState -DifferenceObject $parameters

        return $compare
    }

    ## A simple comparison for complex objects used in JEA configurations.
    ## We don't need anything extensive, as we should be the only ones changing them.
    hidden [bool] ComplexObjectsEqual($object1, $object2) {
        if ($object1.Count -ne $object2.Count) {
            return $false
        }

        if ($object1 -isnot [System.Array]) {
            $object1 = @($object1)
        }
        if ($object2 -isnot [System.Array]) {
            $object2 = @($object2)
        }

        for ($i = 0; $i -lt $object1.Count; $i++) {
            $object1ordered = [System.Collections.Specialized.OrderedDictionary]@{ }
            $object1[$i].Keys | Sort-Object -Descending | ForEach-Object { $object1ordered.Insert(0, $_, $object1[$i]["$_"]) }

            $object2ordered = [System.Collections.Specialized.OrderedDictionary]@{ }
            $object2[$i].Keys | Sort-Object -Descending | ForEach-Object { $object2ordered.Insert(0, $_, $object2[$i]["$_"]) }

            $json1 = ConvertTo-Json -InputObject $object1ordered -Depth 100
            $json2 = ConvertTo-Json -InputObject $object2ordered -Depth 100

            if ($json1 -ne $json2) {
                Write-Verbose "object1: $json1"
                Write-Verbose "object2: $json2"
            }

            if ($json1 -ne $json2) {
                return $false
            }
        }

        return $true
    }

    ## Get a PS Session Configuration based on its name
    hidden [Object] GetPSSessionConfiguration($Name) {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running') {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $VerbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $PSSessionConfiguration = Get-PSSessionConfiguration -Name $Name -ErrorAction 'SilentlyContinue'
            $Global:VerbosePreference = $VerbosePreferenceBackup
            
            if ($PSSessionConfiguration) {
                return $PSSessionConfiguration
            }
            else {
                return $null
            }
        }
        else {
            Write-Verbose 'WinRM service is not running. Cannot get PS Session Configuration(s).'
            return $null
        }
    }

    ## Unregister a PS Session Configuration based on its name
    hidden [Void] UnregisterPSSessionConfiguration($Name) {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running') {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $VerbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $null = Unregister-PSSessionConfiguration -Name $Name -Force -WarningAction 'SilentlyContinue'
            $Global:VerbosePreference = $VerbosePreferenceBackup
        }
        else {
            Throw "WinRM service is not running. Cannot unregister PS Session Configuration '$Name'."
        }
    }

    ## Register a PS Session Configuration and handle a WinRM hanging situation
    hidden [Void] RegisterPSSessionConfiguration($Name, $Path, $Timeout) {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running') {
            Write-Verbose "Will register PSSessionConfiguration with argument: Name = '$Name', Path = '$Path' and Timeout = '$Timeout'"
            # Register-PSSessionConfiguration has been hanging because the WinRM service is stuck in Stopping state
            # therefore we need to run Register-PSSessionConfiguration within a job to allow us to handle a hanging WinRM service

            # Save the list of services sharing the same process as WinRM in case we have to restart them
            $processId = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name LIKE 'WinRM'" | Select-Object -Expand 'ProcessId'
            $serviceList = @(Get-CimInstance -ClassName 'Win32_Service' -Filter "ProcessId=$processId" | Select-Object -Expand 'Name')
            foreach ($service in $serviceList.clone()) {
                $dependentServiceList = Get-Service -Name $service | ForEach-Object { $_.DependentServices }
                foreach ($dependentService in $dependentServiceList) {
                    if ($dependentService.Status -eq 'Running' -and $serviceList -notcontains $dependentService.Name) {
                        $serviceList += $dependentService.Name
                    }
                }
            }

            if ($Path) {
                $registerString = "`$null = Register-PSSessionConfiguration -Name '$Name' -Path '$Path' -NoServiceRestart -Force -ErrorAction 'Stop' -WarningAction 'SilentlyContinue'"
            }
            else {
                $registerString = "`$null = Register-PSSessionConfiguration -Name '$Name' -NoServiceRestart -Force -ErrorAction 'Stop' -WarningAction 'SilentlyContinue'"
            }

            $registerScriptBlock = [Scriptblock]::Create($registerString)

            if ($Timeout -gt 0) {
                $job = Start-Job -ScriptBlock $registerScriptBlock
                Wait-Job -Job $job -Timeout $Timeout
                Receive-Job -Job $job
                Remove-Job -Job $job -Force -ErrorAction 'SilentlyContinue'

                # If WinRM is still Stopping after the job has completed / exceeded $Timeout, force kill the underlying WinRM process
                $winRMService = Get-Service -Name 'WinRM'
                if ($winRMService -and $winRMService.Status -eq 'StopPending') {
                    $processId = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name LIKE 'WinRM'" | Select-Object -Expand 'ProcessId'
                    Write-Verbose "WinRM seems hanging in Stopping state. Forcing process $processId to stop"
                    $failureList = @()
                    try {
                        # Kill the process hosting WinRM service
                        Stop-Process -Id $processId -Force
                        Start-Sleep -Seconds 5
                        Write-Verbose "Restarting services: $($serviceList -join ', ')"
                        # Then restart all services previously identified
                        foreach ($service in $serviceList) {
                            try {
                                Start-Service -Name $service
                            }
                            catch {
                                $failureList += "Start service $service"
                            }
                        }
                    }
                    catch {
                        $failureList += "Kill WinRM process"
                    }

                    if ($failureList) {
                        Write-Verbose "Failed to execute following operation(s): $($failureList -join ', ')"
                    }
                }
                elseif ($winRMService -and $winRMService.Status -eq 'Stopped') {
                    Write-Verbose '(Re)starting WinRM service'
                    Start-Service -Name 'WinRM'
                }
            }
            else {
                Invoke-Command -ScriptBlock $registerScriptBlock
            }
        }
        else {
            Throw "WinRM service is not running. Cannot register PS Session Configuration '$Name'"
        }
    }

    # Gets the resource's current state.
    [JeaSessionConfiguration] Get() {
        $currentState = New-Object JeaSessionConfiguration
        $CurrentState.Name = $this.Name
        $CurrentState.Ensure = [Ensure]::Present

        $sessionConfiguration = $this.GetPSSessionConfiguration($this.Name)
        if (-not $sessionConfiguration -or -not $sessionConfiguration.ConfigFilePath) {
            $currentState.Ensure = [Ensure]::Absent
            return $currentState
        }

        $configFile = Import-PowerShellDataFile $sessionConfiguration.ConfigFilePath

        'Copyright', 'GUID', 'Author', 'CompanyName', 'SchemaVersion' | Foreach-Object {
            $configFile.Remove($_)
        }  

        foreach ($Property in $configFile.Keys) {
            $currentState.$Property = foreach ($propertyValue in $configFile[$Property]) {
                if ($propertyValue -is [hashtable]) {
                    if ($propertyValue.ScriptBlock -is [scriptblock]) {
                        $code = $propertyValue.ScriptBlock.Ast.Extent.Text
                        $code -match '(?<=\{\{)(?<Code>((.|\s)*))(?=\}\})' | Out-Null
                        $propertyValue.ScriptBlock = [scriptblock]::Create($Matches.Code)
                    }

                    ConvertTo-Expression -Object $propertyValue
                }
                else {
                    $propertyValue
                }
            }
        }

        return $currentState
    }
}
