The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# Change log for JeaDsc

## [Unreleased]

### Added

- Adding herited classes that contains helper methods.

### Changed

- Moving code from constructor to separate method.
- Moving the class based resources from nested modules to root module.

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
