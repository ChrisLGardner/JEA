$modulePath = Join-Path -Path $PSScriptRoot -ChildPath Modules

Import-Module -Name (Join-Path -Path $modulePath -ChildPath DscResource.Common)
Import-Module -Name (Join-Path -Path $modulePath -ChildPath (Join-Path -Path JeaDsc.Common -ChildPath JeaDsc.Common.psm1))

$script:localizedDataRole = Get-LocalizedData -DefaultUICulture en-US -FileName 'JeaRoleCapabilities.strings.psd1'

class RoleCapabilitiesUtility
{
    hidden [boolean] ValidatePath()
    {
        $fileObject = [System.IO.FileInfo]::new($this.Path)
        Write-Verbose -Message ($script:localizedDataRole.ValidatingPath -f $fileObject.Fullname)
        Write-Verbose -Message ($script:localizedDataRole.CheckPsrcExtension -f $fileObject.Fullname)
        if ($fileObject.Extension -ne '.psrc')
        {
            Write-Verbose -Message ($script:localizedDataRole.NotPsrcExtension -f $fileObject.Fullname)
            return $false
        }

        Write-Verbose -Message ($script:localizedDataRole.CheckParentFolder -f $fileObject.Fullname)
        if ($fileObject.Directory.Name -ne 'RoleCapabilities')
        {
            Write-Verbose -Message ($script:localizedDataRole.NotRoleCapabilitiesParent -f $fileObject.Fullname)
            return $false
        }


        Write-Verbose -Message $script:localizedDataRole.ValidePsrcPath
        return $true
    }
}
