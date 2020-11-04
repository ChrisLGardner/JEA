$modulePath = Join-Path -Path $PSScriptRoot -ChildPath Modules

Import-Module -Name (Join-Path -Path $modulePath -ChildPath DscResource.Common)
Import-Module -Name (Join-Path -Path $modulePath -ChildPath (Join-Path -Path JeaDsc.Common -ChildPath JeaDsc.Common.psm1))

$script:localizedDataRole = Get-LocalizedData -DefaultUICulture en-US -FileName 'JeaRoleCapabilities.strings.psd1'

class RoleCapabilitiesUtility
{
    hidden [boolean] ValidatePath()
    {
        $fileObject = [System.IO.FileInfo]::new($this.Path)
        Write-Verbose -Message "Validating Path: $($fileObject.Fullname)"
        Write-Verbose -Message "Checking file extension is psrc for: $($fileObject.Fullname)"
        if ($fileObject.Extension -ne '.psrc')
        {
            Write-Verbose -Message "Doesn't have psrc extension for: $($fileObject.Fullname)"
            return $false
        }

        Write-Verbose -Message "Checking parent forlder is RoleCapabilities for: $($fileObject.Fullname)"
        if ($fileObject.Directory.Name -ne 'RoleCapabilities')
        {
            Write-Verbose -Message "Parent folder isn't RoleCapabilities for: $($fileObject.Fullname)"
            return $false
        }


        Write-Verbose -Message 'Path is a valid psrc path. Returning true.'
        return $true
    }
}
