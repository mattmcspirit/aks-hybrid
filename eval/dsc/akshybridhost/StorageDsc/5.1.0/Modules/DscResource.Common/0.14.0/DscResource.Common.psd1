@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'DscResource.Common.psm1'

    # Version number of this module.
    ModuleVersion     = '0.14.0'

    # ID used to uniquely identify this module
    GUID              = '9c9daa5b-5c00-472d-a588-c96e8e498450'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Common functions used in DSC Resources'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Assert-BoundParameter','Assert-ElevatedUser','Assert-IPAddress','Assert-Module','Compare-DscParameterState','Compare-ResourcePropertyState','ConvertFrom-DscResourceInstance','ConvertTo-CimInstance','ConvertTo-HashTable','Get-ComputerName','Get-DscProperty','Get-LocalizedData','Get-LocalizedDataForInvariantCulture','Get-TemporaryFolder','New-InvalidArgumentException','New-InvalidDataException','New-InvalidOperationException','New-InvalidResultException','New-NotImplementedException','New-ObjectNotFoundException','Remove-CommonParameter','Set-DscMachineRebootRequired','Set-PSModulePath','Test-AccountRequirePassword','Test-DscParameterState','Test-DscProperty','Test-IsNanoServer','Test-IsNumericType')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DSC', 'Localization')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/DscResource.Common/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/DscResource.Common'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [0.14.0] - 2022-12-31

### Added

- Added private function `Assert-RequiredCommandParameter` that throws an
  exception if a specified parameter is not assigned a value, and optionally
  throws only if a specific parameter is passed. - [Issue #92](https://github.com/dsccommunity/DscResource.Common/issues/92)
  - Related to SqlServerDsc [Issue #1796](https://github.com/dsccommunity/SqlServerDsc/issues/1796).
- Added public function `Test-AccountRequirePassword` that returns true or
  false whether an account need a password to be passed - [Issue #93](https://github.com/dsccommunity/DscResource.Common/issues/93)
  - Related to SqlServerDsc [Issue #1794](https://github.com/dsccommunity/SqlServerDsc/issues/1794).
- Added public command `Get-DscProperty` that returns a hashtable of available
  properties for a class-based resource. See comment-based help for more
  information.
- Added public command `Test-DscProperty` that returns a true or false
  whether a property exist in a class-based resource. See comment-based help
  for more information.
- Added private function `Test-DscPropertyIsAssigned` that returns a true
  or false whether a property in a class-based resource has a non-null value.

### Changed

- DscResource.Common
  - Updated Visual Studio Code project settings to configure testing for Pester 5.
- `Assert-BoundParameter`
  - Now has a new parameter set that calls `Assert-RequiredCommandParameter`
    which will throw an exception if a specified parameter is not assigned
    a value, and optionally throws only if a specific parameter is passed.

### Fixed

- Fixed unit tests for `Assert-ElevatedUser` and `Test-IsNumericType` so
  the public function is tested correctly using the exported function.
- Fixed unit tests to easier run test both from command line and inside
  Visual Studio Code.

'

            Prerelease   = ''
        } # End of PSData hashtable

    } # End of PrivateData hashtable
}
