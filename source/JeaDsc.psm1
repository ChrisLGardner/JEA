$script:localizedData = Get-LocalizedData -DefaultUICulture en-US

function Get-Dummy
{
    Write-Debug $script:localizedData.Dummy
}
