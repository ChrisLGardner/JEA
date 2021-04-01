$script:localizedDataSession = Get-LocalizedData -DefaultUICulture en-US -FileName 'JeaSessionConfiguration.strings.psd1'

class SessionConfigurationUtility
{
    hidden [bool] TestParameters()
    {
        if (-not $this.SessionType)
        {
            $this.SessionType = 'RestrictedRemoteServer'
        }

        if ($this.RunAsVirtualAccountGroups -and $this.GroupManagedServiceAccount)
        {
            throw $script:localizedDataSession.ConflictRunAsVirtualAccountGroupsAndGroupManagedServiceAccount
        }

        if ($this.GroupManagedServiceAccount -and $this.RunAsVirtualAccount)
        {
            throw $script:localizedDataSession.ConflictRunAsVirtualAccountAndGroupManagedServiceAccount
        }

        if (-not $this.GroupManagedServiceAccount -and $null -eq $this.RunAsVirtualAccount)
        {
            $this.RunAsVirtualAccount = $true
            Write-Warning -Message $script:localizedDataSession.NotDefinedGMSaAndVirtualAccount
        }

        return $true
    }

    ## Get a PS Session Configuration based on its name
    hidden [object] GetPSSessionConfiguration($Name)
    {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $verbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $psSessionConfiguration = Get-PSSessionConfiguration -Name $Name -ErrorAction SilentlyContinue
            $Global:VerbosePreference = $verbosePreferenceBackup

            if ($psSessionConfiguration)
            {
                return $psSessionConfiguration
            }
            else
            {
                return $null
            }
        }
        else
        {
            Write-Verbose -Message $script:localizedDataSession.WinRMNotRunningGetPsSession
            return $null
        }
    }

    ## Unregister a PS Session Configuration based on its name
    hidden [void] UnregisterPSSessionConfiguration($Name)
    {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $verbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $null = Unregister-PSSessionConfiguration -Name $Name -Force -WarningAction 'SilentlyContinue'
            $Global:VerbosePreference = $verbosePreferenceBackup
        }
        else
        {
            throw ($script:localizedDataSession.WinRMNotRunningUnRegisterPsSession -f $Name)
        }
    }

    ## Register a PS Session Configuration and handle a WinRM hanging situation
    hidden [Void] RegisterPSSessionConfiguration($Name, $Path, $Timeout)
    {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            Write-Verbose -Message ($script:localizedDataSession.RegisterPSSessionConfiguration -f $Name,$Path,$Timeout)
            # Register-PSSessionConfiguration has been hanging because the WinRM service is stuck in Stopping state
            # therefore we need to run Register-PSSessionConfiguration within a job to allow us to handle a hanging WinRM service

            # Save the list of services sharing the same process as WinRM in case we have to restart them
            $processId = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name LIKE 'WinRM'" | Select-Object -ExpandProperty ProcessId
            $serviceList = Get-CimInstance -ClassName 'Win32_Service' -Filter "ProcessId=$processId" | Select-Object -ExpandProperty Name
            foreach ($service in $serviceList.clone())
            {
                $dependentServiceList = Get-Service -Name $service | ForEach-Object { $_.DependentServices }
                foreach ($dependentService in $dependentServiceList)
                {
                    if ($dependentService.Status -eq 'Running' -and $serviceList -notcontains $dependentService.Name)
                    {
                        $serviceList += $dependentService.Name
                    }
                }
            }

            if ($Path)
            {
                $registerString = "`$null = Register-PSSessionConfiguration -Name '$Name' -Path '$Path' -NoServiceRestart -Force -ErrorAction 'Stop' -WarningAction 'SilentlyContinue'"
            }
            else
            {
                $registerString = "`$null = Register-PSSessionConfiguration -Name '$Name' -NoServiceRestart -Force -ErrorAction 'Stop' -WarningAction 'SilentlyContinue'"
            }

            $registerScriptBlock = [scriptblock]::Create($registerString)

            if ($Timeout -gt 0)
            {
                $job = Start-Job -ScriptBlock $registerScriptBlock
                Wait-Job -Job $job -Timeout $Timeout
                Receive-Job -Job $job
                Remove-Job -Job $job -Force -ErrorAction 'SilentlyContinue'

                # If WinRM is still Stopping after the job has completed / exceeded $Timeout, force kill the underlying WinRM process
                $winRMService = Get-Service -Name 'WinRM'
                if ($winRMService -and $winRMService.Status -eq 'StopPending')
                {
                    $processId = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name LIKE 'WinRM'" | Select-Object -ExpandProperty ProcessId
                    Write-Verbose -Message ($script:localizedDataSession.ForcingProcessToStop -f $processId)
                    $failureList = @()
                    try
                    {
                        # Kill the process hosting WinRM service
                        Stop-Process -Id $processId -Force
                        Start-Sleep -Seconds 5
                        Write-Verbose -Message ($script:localizedDataSession.RegisterPSSessionConfiguration -f $($serviceList -join ', '))
                        # Then restart all services previously identified
                        foreach ($service in $serviceList)
                        {
                            try
                            {
                                Start-Service -Name $service
                            }
                            catch
                            {
                                $failureList += $script:localizedDataSession.FailureListStartService -f $service
                            }
                        }
                    }
                    catch
                    {
                        $failureList += $script:localizedDataSession.FailureListKillWinRMProcess
                    }

                    if ($failureList)
                    {
                        Write-Verbose -Message ($script:localizedDataSession.FailureListKillWinRMProcess -f $($failureList -join ', '))
                    }
                }
                elseif ($winRMService -and $winRMService.Status -eq 'Stopped')
                {
                    Write-Verbose -Message $script:localizedDataSession.RestartWinRM
                    Start-Service -Name 'WinRM'
                }
            }
            else
            {
                Invoke-Command -ScriptBlock $registerScriptBlock
            }
        }
        else
        {
            throw ($script:localizedDataSession.WinRMNotRunningRegisterPsSession -f $Name)
        }
    }

}
