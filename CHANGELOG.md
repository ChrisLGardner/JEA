The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# Change log for JeaDsc

## [Unreleased]

### Added

- Adding herited classes that contains helper methods.
- Adding Reason class.
- Adding Reasons property in JeaSessionConfiguration and JeaRoleCapabilities resources.
  It'a a requirement of [Guest Configuration](https://docs.microsoft.com/en-us/azure/governance/policy/how-to/guest-configuration-create#get-targetresource-requirements)
- Adding pester tests to check Reasons property.

### Changed

- Moving the class based resources from nested modules to root module.
- Moving LocalizedData of class based resources in .strings.psd1 files.
Based on [stylesguidelines](https://dsccommunity.org/styleguidelines/localization/) of DscCommunity.

### Removed

- Removing dummy object

## [0.7.2] - 2020-09-29

### Changed

- Moving code from constructor to separate method.

## [0.7.1] - 2020-08-26

- Renamed 'Test-DscParameterState' to 'Test-DscParameterState2' for a conflict with 'DscResource.Common'.
- Removing functions provided by 'DscResource.Common'
- Making property 'RoleDefinitions' non-mandatory
- Replacing 'New-PSRoleCapabilityFile' by writing the file directly
- Making 'ConvertTo-Expression' visible as it is required also from the outside
- Renamed variable '$parameters' into '$desiredState'
- Removing pre-release tag

### Added

- Migrated the resource to Sampler

### Changed

- Fixed a lot of issues.

### Deprecated

- None

### Removed

- None

### Fixed

- None

### Security

- None
