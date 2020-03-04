@{

    RootModule           = 'JeaDsc.psm1'

    ModuleVersion        = '0.1.0'

    GUID                 = 'c7c41e83-55c3-4e0f-9c4f-88de602e04db'

    Author               = 'Chris Gardner'

    Copyright            = '(c) Chris Gardner. All rights reserved.'

    Description          = 'This module contains resources to configure Just Enough Administration endpoints.'

    PowerShellVersion    = '5.1'

    NestedModules        = @(
        'DSCClassResources\JeaSessionConfiguration\JeaSessionConfiguration.psd1'
        'DSCClassResources\JeaRoleCapabilities\JeaRoleCapabilities.psd1'
    )

    FunctionsToExport    = @(
        'Compare-JeaConfiguration'
        'Convert-ObjectToHashtable'
        'Convert-StringToObject'
        'Convert-StringToHashtable'
        'Convert-StringToArrayOfObject'
        'Convert-StringToArrayOfHashtable'
        'ConvertTo-Expression'
    )

    DscResourcesToExport = @(
        'JeaSessionConfiguration',
        'JeaRoleCapabilities'
    )

    PrivateData          = @{

        PSData = @{

            Tags       = @('DesiredStateConfiguration', 'DSC', 'DSCResource', 'JEA', 'JustEnoughAdministration')

            LicenseUri = 'https://github.com/ChrisLGardner/JeaDsc/blob/master/LICENSE.txt'

            ProjectUri = 'https://github.com/ChrisLGardner/JeaDsc'

        }

    }
}
