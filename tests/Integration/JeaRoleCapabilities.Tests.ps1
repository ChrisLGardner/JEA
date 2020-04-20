Using Module JeaDsc

$script:dscModuleName = 'JeaDsc'
$script:dscResourceName = 'JeaRoleCapabilities'

try
{
    Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

#$script:testEnvironment = Initialize-TestEnvironment `
#    -DSCModuleName $script:dscModuleName `
#    -DSCResourceName $script:dscResourceName `
#    -ResourceType 'Mof' `
#    -TestType 'Integration'

#Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')


InModuleScope JeaDsc {
    Describe "Integration testing JeaRoleCapabilities" -Tag Integration {

        BeforeAll {
            #$modulePath = Resolve-Path -Path $PSScriptRoot\..\..
            #$oldPsModulePath = $Env:PSModulePath
            #$env:PSModulePath += ";$modulePath"
            #[System.Environment]::SetEnvironmentVariable('PSModulePath', $env:PSModulePath, 'Machine')
            #$env:PSModulePath += ";TestDrive:\"

            $buildBox = $true
            #if ($env:SYSTEM_DEFAULTWORKINGDIRECTORY) {
                winrm quickconfig -quiet -force
                $buildBox = $false
            #}
        }

        AfterAll {
            #[System.Environment]::SetEnvironmentVariable('PSModulePath', $oldPsModulePath, 'Machine')
        }

        BeforeEach {
            $class = [JeaRoleCapabilities]::New()
            $class.Path = 'TestDrive:\ModuleFolder\RoleCapabilities\ExampleRole.psrc'
        }

        Context "Testing Get method when Ensure is Present" {

            It "Should return an object of JeaRoleCapabilities type" {

                $null = New-Item -Path $class.Path -Force
                $null = New-PSRoleCapabilityFile -Path $class.Path -VisibleCmdlets 'Get-Command'

                $Result = $class.Get()

                $Result.GetType().Name | Should -Be 'JeaRoleCapabilities'
            }

            It "Should remove Copyright, GUID, Author and CompanyName from the object after importing the psrc" {

                $null = New-Item -Path $class.Path -Force
                $null = New-PSRoleCapabilityFile -Path $class.Path -VisibleCmdlets 'Get-Command'

                $Result = $class.Get()

                $Result.PSObject.Properties | Should -Not -Contain 'Copyright'
                $Result.PSObject.Properties | Should -Not -Contain 'GUID'
                $Result.PSObject.Properties | Should -Not -Contain 'Author'
                $Result.PSObject.Properties | Should -Not -Contain 'CompanyName'
            }

            It "Should return an object with property Ensure set to Present" {

                $null = New-Item -Path $class.Path -Force
                $null = New-PSRoleCapabilityFile -Path $class.Path -VisibleCmdlets 'Get-Command'

                $Result = $class.Get()

                $Result.Ensure | Should -Be 'Present'
            }

            It "Should populate returned properties from VisibleCmdlets in psrc file" {

                $null = New-Item -Path $class.Path -Force
                $null = New-PSRoleCapabilityFile -Path $class.Path -VisibleCmdlets 'Get-Command'

                $Result = $class.Get()

                $Result.VisibleCmdlets | Should -Be 'Get-Command'
            }

        }

        Context "Testing Get method when Ensure is Absent" {

            It "Should return an object of JeaRoleCapabilities type" {

                $Result = $class.Get()

                $Result.GetType().Name | Should -Be 'JeaRoleCapabilities'
            }

            It "Should return an object with property Ensure set to Present" {

                $Result = $class.Get()

                $Result.Ensure | Should -Be 'Absent'
            }
        }

        Context "Testing Set method when Ensure is Present" {

            It "Should create a new RoleCapbailities folder and populate with a psrc file with 1 visible function" {
                $class.VisibleFunctions = 'Get-Service'
                $class.Set()

                Test-Path -Path $class.Path | Should -Be $true
                $result = Import-PowerShellDataFile -Path $class.Path
                $result.VisibleFunctions | Should -Be 'Get-Service'
            }

            It "Should create a new psrc with 1 visible function and all Get cmdlets visible" {
                $class.VisibleCmdlets = 'Get-*'
                $class.VisibleFunctions = 'New-Example'
                $class.Set()

                Test-Path -Path $class.Path | Should -Be $true
                $result = Import-PowerShellDataFile -Path $class.Path
                $result.VisibleFunctions | Should -Be 'New-Example'
                $result.VisibleCmdlets | Should -Be 'Get-*'
            }

            It "Should create a new psrc from an array of strings with 1 visible function and all cmdlets in DnsServer module and Restart-Service visible" {
                $class.VisibleCmdlets = 'DnsServer\*', "@{'Name' = 'Restart-Service';'Parameters' = @{'Name' = 'Name';'ValidateSet' = 'Dns' } }"
                $class.VisibleFunctions = 'New-Example'
                $class.Set()

                Test-Path -Path $class.Path | Should -Be $true
                $result = Import-PowerShellDataFile -Path $class.Path
                $result.VisibleFunctions | Should -Be 'New-Example'
                $result.VisibleCmdlets[0] | Should -Be 'DnsServer\*'
                $result.VisibleCmdlets[1] | Should -BeOfType [Hashtable]
                $result.VisibleCmdlets[1].Name | Should -Be 'Restart-Service'
                $result.VisibleCmdlets[1].Parameters.Name | Should -Be 'Name'
                $result.VisibleCmdlets[1].Parameters.ValidateSet | Should -Be 'Dns'
            }

            It "Should create a new psrc from a single string with 1 visible function and all cmdlets in DnsServer module and Restart-Service visible" {
                $class.VisibleCmdlets = 'DnsServer\*, @{"Name" = "Restart-Service";"Parameters" = @{"Name" = "Name";"ValidateSet" = "Dns" } }'
                $class.VisibleFunctions = 'New-Example'
                $class.Set()

                Test-Path -Path $class.Path | Should -Be $true
                $result = Import-PowerShellDataFile -Path $class.Path
                $result.VisibleFunctions | Should -Be 'New-Example'
                $result.VisibleCmdlets[0] | Should -Be 'DnsServer\*'
                $result.VisibleCmdlets[1] | Should -BeOfType [Hashtable]
                $result.VisibleCmdlets[1].Name | Should -Be 'Restart-Service'
                $result.VisibleCmdlets[1].Parameters.Name | Should -Be 'Name'
                $result.VisibleCmdlets[1].Parameters.ValidateSet | Should -Be 'Dns'
            }

            It "Should create a psrc with a function definition and a visible function for that custom function" {
                $class.FunctionDefinitions = "@{Name = 'Get-ExampleFunction'; ScriptBlock = {Get-Command} }"
                $class.VisibleFunctions = 'Get-ExampleFunction'
                $class.Set()

                Test-Path -Path $class.Path | Should -Be $true
                $result = Import-PowerShellDataFile -Path $class.Path
                $result.VisibleFunctions | Should -Be 'Get-ExampleFunction'
                $result.FunctionDefinitions.Name | Should -Be 'Get-ExampleFunction'
                $result.FunctionDefinitions.Scriptblock | Should -Be '{Get-Command}'
                $result.FunctionDefinitions.Scriptblock | Should -BeOfType [ScriptBlock]
            }

            It "Should create a psrc with 2 function definitions and 2 visible function for those custom function" {
                $class.FunctionDefinitions = "@{Name = 'Get-ExampleFunction'; ScriptBlock = {Get-Command} }","@{Name = 'Get-OtherExample'; ScriptBlock = {Get-Command} }"
                $class.VisibleFunctions = 'Get-ExampleFunction','Get-OtherExample'
                $class.Set()

                Test-Path -Path $class.Path | Should -Be $true
                $result = Import-PowerShellDataFile -Path $class.Path
                $result.VisibleFunctions | Should -Be 'Get-ExampleFunction','Get-OtherExample'
                $result.FunctionDefinitions[0].Name | Should -Be 'Get-ExampleFunction'
                $result.FunctionDefinitions[0].Scriptblock | Should -Be '{Get-Command}'
                $result.FunctionDefinitions[0].Scriptblock | Should -BeOfType [ScriptBlock]
                $result.FunctionDefinitions[1].Name | Should -Be 'Get-OtherExample'
                $result.FunctionDefinitions[1].Scriptblock | Should -Be '{Get-Command}'
                $result.FunctionDefinitions[1].Scriptblock | Should -BeOfType [ScriptBlock]
            }
        }

        Context "Testing Set method when Ensure is Absent" {

            It "Should remove the role capabilities file" {
                New-Item -Path 'TestDrive:\RemoveMe\RoleCapabilities\ExampleRole.psrc' -Force

                $class.Ensure = [Ensure]::Absent
                $class.Path = 'TestDrive:\RemoveMe\RoleCapabilities\ExampleRole.psrc'
                $class.Set()

                Test-Path -Path 'TestDrive:\RemoveMe\RoleCapabilities\ExampleRole.psrc' | Should -Be $false

            }
        }

        Context "Testing Applying BasicVisibleCmdlets Configuration File" {

            It "Should apply the example BasicVisibleCmdlets configuration without throwing" -Skip:$buildBox {
                $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'TestConfigurations\BasicVisibleCmdlets.config.ps1'
                . $configFile

                $mofOutputFolder = 'TestDrive:\Configurations\BasicVisibleCmdlets'
                $PsrcPath = Join-Path (Get-Item TestDrive:\).FullName -ChildPath 'BasicVisibleCmdlets\RoleCapabilities\BasicVisibleCmdlets.psrc'
                BasicVisibleCmdlets -OutputPath $mofOutputFolder -Path $PsrcPath
                { Start-DscConfiguration -Path $mofOutputFolder -Wait -Force } | Should -Not -Throw
            }

            It "Should be able to call Get-DscConfiguration without throwing" -Skip:$buildBox {
                { Get-DscConfiguration -ErrorAction Stop } | Should -Not -Throw
            }

            It "Should have created the psrc file and set the VisibleCmdlets to Get-Service" -Skip:$buildBox {
                Test-Path -Path 'TestDrive:\BasicVisibleCmdlets\RoleCapabilities\BasicVisibleCmdlets.psrc' | Should -Be $true

                $results = Import-PowerShellDataFile -Path 'TestDrive:\BasicVisibleCmdlets\RoleCapabilities\BasicVisibleCmdlets.psrc'

                $results.VisibleCmdlets | Should -Be 'Get-Service'
            }
        }

        Context "Testing Applying WildcardVisibleCmdlets Configuration File" {

            It "Should apply the example WildcardVisibleCmdlets configuration without throwing" -Skip:$buildBox {
                $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'TestConfigurations\WildcardVisibleCmdlets.config.ps1'
                . $configFile

                $mofOutputFolder = 'TestDrive:\Configurations\WildcardVisibleCmdlets'
                $PsrcPath = Join-Path (Get-Item TestDrive:\).FullName -ChildPath 'WildcardVisibleCmdlets\RoleCapabilities\WildcardVisibleCmdlets.psrc'
                WildcardVisibleCmdlets -OutputPath $mofOutputFolder -Path $PsrcPath
                { Start-DscConfiguration -Path $mofOutputFolder -Wait -Force } | Should -Not -Throw
            }

            It "Should be able to call Get-DscConfiguration without throwing" -Skip:$buildBox {
                { Get-DscConfiguration -ErrorAction Stop } | Should -Not -Throw
            }

            It "Should have created the psrc file and set the VisibleCmdlets to Get-* and DnsServer\*" -Skip:$buildBox {
                Test-Path -Path 'TestDrive:\WildcardVisibleCmdlets\RoleCapabilities\WildcardVisibleCmdlets.psrc' | Should -Be $true

                $results = Import-PowerShellDataFile -Path 'TestDrive:\WildcardVisibleCmdlets\RoleCapabilities\WildcardVisibleCmdlets.psrc'

                $results.VisibleCmdlets | Should -Be 'Get-*','DnsServer\*'
            }
        }

        Context "Testing Applying FunctionDefinitions Configuration File" {

            It "Should apply the example FunctionDefinitions configuration without throwing" -Skip:$buildBox {
                $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'TestConfigurations\FunctionDefinitions.config.ps1'
                . $configFile

                $mofOutputFolder = 'TestDrive:\Configurations\FunctionDefinitions'
                $PsrcPath = Join-Path (Get-Item TestDrive:\).FullName -ChildPath 'FunctionDefinitions\RoleCapabilities\FunctionDefinitions.psrc'
                FunctionDefinitions -OutputPath $mofOutputFolder -Path $PsrcPath
                { Start-DscConfiguration -Path $mofOutputFolder -Wait -Force } | Should -Not -Throw
            }

            It "Should be able to call Get-DscConfiguration without throwing" -Skip:$buildBox {
                { Get-DscConfiguration -ErrorAction Stop } | Should -Not -Throw
            }

            It "Should have created the psrc file and set the FunctionDefinitions and VisibleFunctions to Get-ExampleData" -Skip:$buildBox {
                Test-Path -Path 'TestDrive:\FunctionDefinitions\RoleCapabilities\FunctionDefinitions.psrc' | Should -Be $true

                $results = Import-PowerShellDataFile -Path 'TestDrive:\FunctionDefinitions\RoleCapabilities\FunctionDefinitions.psrc'

                $results.FunctionDefinitions.Name | Should -Be 'Get-ExampleData'
                $results.FunctionDefinitions.ScriptBlock | Should -Be '{Get-Command}'
                $results.FunctionDefinitions.ScriptBlock | Should -BeOfType [ScriptBlock]
            }
        }

        Context "Testing Applying FailingFunctionDefinitions Configuration File" {

            It "Should throw when attempting to apply the example FunctionDefinitions configuration" -Skip:$buildBox {
                $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'TestConfigurations\FailingFunctionDefinitions.config.ps1'
                . $configFile

                $mofOutputFolder = 'TestDrive:\Configurations\FailingFunctionDefinitions'
                $PsrcPath = Join-Path (Get-Item TestDrive:\).FullName -ChildPath 'FailingFunctionDefinitions\RoleCapabilities\FailingFunctionDefinitions.psrc'
                FailingFunctionDefinitions -OutputPath $mofOutputFolder -Path $PsrcPath
                { Start-DscConfiguration -Path $mofOutputFolder -Wait -Force -ErrorAction Stop } | Should -Throw
            }

            It "Should not have created the psrc file" -Skip:$buildBox {
                Test-Path -Path 'TestDrive:\FailingFunctionDefinitions\RoleCapabilities\FailingFunctionDefinitions.psrc' | Should -Be $false
            }
        }
    }
}
