#Region '.\prefix.ps1' 0
$script:dscResourceCommonModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules/DscResource.Common'
Import-Module -Name $script:dscResourceCommonModulePath

$script:computerManagementDscCommonModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules/ComputerManagementDsc.Common'
Import-Module -Name $script:computerManagementDscCommonModulePath

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'
#EndRegion '.\prefix.ps1' 8
#Region '.\Enum\1.Ensure.ps1' 0
<#
    .SYNOPSIS
        The possible states for the DSC resource parameter Ensure.
#>
enum Ensure
{
    Present
    Absent
}
#EndRegion '.\Enum\1.Ensure.ps1' 10
#Region '.\Classes\010.ResourceBase.ps1' 0
<#
    .SYNOPSIS
        A class with methods that are equal for all class-based resources.

    .DESCRIPTION
        A class with methods that are equal for all class-based resources.

    .NOTES
        This class should be able to be inherited by all DSC resources. This class
        shall not contain any DSC properties, neither shall it contain anything
        specific to only a single resource.
#>

class ResourceBase
{
    # Property for holding localization strings
    hidden [System.Collections.Hashtable] $localizedData = @{}

    # Property for derived class to set properties that should not be enforced.
    hidden [System.String[]] $ExcludeDscProperties = @()

    # Default constructor
    ResourceBase()
    {
        <#
            TODO: When this fails, for example when the localized string file is missing
                  the LCM returns the error 'Failed to create an object of PowerShell
                  class SqlDatabasePermission' instead of the actual error that occurred.
        #>
        $this.localizedData = Get-LocalizedDataRecursive -ClassName ($this | Get-ClassName -Recurse)
    }

    [ResourceBase] Get()
    {
        $this.Assert()

        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Type 'Key'

        Write-Verbose -Message ($this.localizedData.GetCurrentState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        $getCurrentStateResult = $this.GetCurrentState($keyProperty)

        $dscResourceObject = [System.Activator]::CreateInstance($this.GetType())

        # Set values returned from the derived class' GetCurrentState().
        foreach ($propertyName in $this.PSObject.Properties.Name)
        {
            if ($propertyName -in @($getCurrentStateResult.Keys))
            {
                $dscResourceObject.$propertyName = $getCurrentStateResult.$propertyName
            }
        }

        $keyPropertyAddedToCurrentState = $false

        # Set key property values unless it was returned from the derived class' GetCurrentState().
        foreach ($propertyName in $keyProperty.Keys)
        {
            if ($propertyName -notin @($getCurrentStateResult.Keys))
            {
                # Add the key value to the instance to be returned.
                $dscResourceObject.$propertyName = $this.$propertyName

                $keyPropertyAddedToCurrentState = $true
            }
        }

        if (($this | Test-ResourceHasDscProperty -Name 'Ensure') -and -not $getCurrentStateResult.ContainsKey('Ensure'))
        {
            # Evaluate if we should set Ensure property.
            if ($keyPropertyAddedToCurrentState)
            {
                <#
                    A key property was added to the current state, assume its because
                    the object did not exist in the current state. Set Ensure to Absent.
                #>
                $dscResourceObject.Ensure = [Ensure]::Absent
                $getCurrentStateResult.Ensure = [Ensure]::Absent
            }
            else
            {
                $dscResourceObject.Ensure = [Ensure]::Present
                $getCurrentStateResult.Ensure = [Ensure]::Present
            }
        }

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        $propertiesNotInDesiredState = $this.Compare($getCurrentStateResult, @())

        <#
            Return the correct values for Reasons property if the derived DSC resource
            has such property and it hasn't been already set by GetCurrentState().
        #>
        if (($this | Test-ResourceHasDscProperty -Name 'Reasons') -and -not $getCurrentStateResult.ContainsKey('Reasons'))
        {
            # Always return an empty array if all properties are in desired state.
            $dscResourceObject.Reasons = $propertiesNotInDesiredState |
                ConvertTo-Reason -ResourceName $this.GetType().Name
        }

        # Return properties.
        return $dscResourceObject
    }

    [void] Set()
    {
        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Type 'Key'

        Write-Verbose -Message ($this.localizedData.SetDesiredState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        $this.Assert()

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        $propertiesNotInDesiredState = $this.Compare()

        if ($propertiesNotInDesiredState)
        {
            $propertiesToModify = $propertiesNotInDesiredState | ConvertFrom-CompareResult

            $propertiesToModify.Keys |
                ForEach-Object -Process {
                    Write-Verbose -Message ($this.localizedData.SetProperty -f $_, $propertiesToModify.$_)
                }

            <#
                Call the Modify() method with the properties that should be enforced
                and was not in desired state.
            #>
            $this.Modify($propertiesToModify)
        }
        else
        {
            Write-Verbose -Message $this.localizedData.NoPropertiesToSet
        }
    }

    [System.Boolean] Test()
    {
        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Type 'Key'

        Write-Verbose -Message ($this.localizedData.TestDesiredState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        $this.Assert()

        $isInDesiredState = $true

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        $propertiesNotInDesiredState = $this.Compare()

        if ($propertiesNotInDesiredState)
        {
            $isInDesiredState = $false
        }

        if ($isInDesiredState)
        {
            Write-Verbose $this.localizedData.InDesiredState
        }
        else
        {
            Write-Verbose $this.localizedData.NotInDesiredState
        }

        return $isInDesiredState
    }

    <#
        Returns a hashtable containing all properties that should be enforced and
        are not in desired state, or $null if all enforced properties are in
        desired state.

        This method should normally not be overridden.
    #>
    hidden [System.Collections.Hashtable[]] Compare()
    {
        # Get the current state, all properties except Read properties .
        $currentState = $this.Get() | Get-DscProperty -Type @('Key', 'Mandatory', 'Optional')

        return $this.Compare($currentState, @())
    }

    <#
        Returns a hashtable containing all properties that should be enforced and
        are not in desired state, or $null if all enforced properties are in
        desired state.

        This method should normally not be overridden.
    #>
    hidden [System.Collections.Hashtable[]] Compare([System.Collections.Hashtable] $currentState, [System.String[]] $excludeProperties)
    {
        # Get the desired state, all assigned properties that has an non-null value.
        $desiredState = $this | Get-DscProperty -Type @('Key', 'Mandatory', 'Optional') -HasValue

        $CompareDscParameterState = @{
            CurrentValues     = $currentState
            DesiredValues     = $desiredState
            Properties        = $desiredState.Keys
            ExcludeProperties = ($excludeProperties + $this.ExcludeDscProperties) | Select-Object -Unique
            IncludeValue      = $true
            # This is needed to sort complex types.
            SortArrayValues   = $true
        }

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        return (Compare-DscParameterState @CompareDscParameterState)
    }

    # This method should normally not be overridden.
    hidden [void] Assert()
    {
        # Get the properties that has a non-null value and is not of type Read.
        $desiredState = $this | Get-DscProperty -Type @('Key', 'Mandatory', 'Optional') -HasValue

        $this.AssertProperties($desiredState)
    }

    <#
        This method can be overridden if resource specific property asserts are
        needed. The parameter properties will contain the properties that was
        assigned a value.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidEmptyNamedBlocks', '')]
    hidden [void] AssertProperties([System.Collections.Hashtable] $properties)
    {
    }

    <#
        This method must be overridden by a resource. The parameter properties will
        contain the properties that should be enforced and that are not in desired
        state.
    #>
    hidden [void] Modify([System.Collections.Hashtable] $properties)
    {
        throw $this.localizedData.ModifyMethodNotImplemented
    }

    <#
        This method must be overridden by a resource. The parameter properties will
        contain the key properties.
    #>
    hidden [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        throw $this.localizedData.GetCurrentStateMethodNotImplemented
    }
}
#EndRegion '.\Classes\010.ResourceBase.ps1' 261
#Region '.\Classes\020.PSResourceRepository.ps1' 0
<#
    .SYNOPSIS
        A class for configuring PowerShell Repositories.

    .PARAMETER Ensure
        If the repository should be present or absent on the server
        being configured. Default values is 'Present'.

    .PARAMETER Name
        Specifies the name of the repository to manage.

    .PARAMETER SourceLocation
        Specifies the URI for discovering and installing modules from
        this repository. A URI can be a NuGet server feed, HTTP, HTTPS,
        FTP or file location.

    .PARAMETER Credential
        Specifies credentials of an account that has rights to register a repository.

    .PARAMETER ScriptSourceLocation
        Specifies the URI for the script source location.

    .PARAMETER PublishLocation
        Specifies the URI of the publish location. For example, for
        NuGet-based repositories, the publish location is similar
        to http://someNuGetUrl.com/api/v2/Packages.

    .PARAMETER ScriptPublishLocation
        Specifies the URI for the script publish location.

    .PARAMETER Proxy
        Specifies the URI of the proxy to connect to this PSResourceRepository.

    .PARAMETER ProxyCredential
        Specifies the Credential to connect to the PSResourceRepository proxy.

    .PARAMETER InstallationPolicy
        Specifies the installation policy. Valid values are  'Trusted'
        or 'Untrusted'. The default value is 'Untrusted'.

    .PARAMETER PackageManagementProvider
        Specifies a OneGet package provider. Default value is 'NuGet'.

    .PARAMETER Default
        Specifies whether to set the default properties for the default PSGallery PSRepository.
        Default may only be used in conjunction with a PSRepositoryResource named PSGallery.
        The properties SourceLocation, ScriptSourceLocation, PublishLocation, ScriptPublishLocation, Credential,
        and PackageManagementProvider may not be used in conjunction with Default.
        When the Default parameter is used, properties are not enforced when PSGallery properties are changed outside of Dsc.

    .EXAMPLE
        Invoke-DscResource -ModuleName ComputerManagementDsc -Name PSResourceRepository -Method Get -Property @{
            Name                      = 'PSTestRepository'
            SourceLocation            = 'https://www.nuget.org/api/v2'
            ScriptSourceLocation      = 'https://www.nuget.org/api/v2/package/'
            PublishLocation           = 'https://www.nuget.org/api/v2/items/psscript/'
            ScriptPublishLocation     = 'https://www.nuget.org/api/v2/package/'
            InstallationPolicy        = 'Trusted'
            PackageManagementProvider = 'NuGet'
        }
        This example shows how to call the resource using Invoke-DscResource.
#>
[DscResource()]
class PSResourceRepository : ResourceBase
{
    [DscProperty()]
    [Ensure]
    $Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [System.String]
    $Name

    [DscProperty()]
    [System.String]
    $SourceLocation

    [DscProperty()]
    [PSCredential]
    $Credential

    [DscProperty()]
    [System.String]
    $ScriptSourceLocation

    [DscProperty()]
    [System.String]
    $PublishLocation

    [DscProperty()]
    [System.String]
    $ScriptPublishLocation

    [DscProperty()]
    [System.String]
    $Proxy

    [DscProperty()]
    [pscredential]
    $ProxyCredential

    [DscProperty()]
    [ValidateSet('Untrusted', 'Trusted')]
    [System.String]
    $InstallationPolicy

    [DscProperty()]
    [System.String]
    $PackageManagementProvider

    [DscProperty()]
    [Nullable[System.Boolean]]
    $Default

    PSResourceRepository () : base ()
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'Name',
            'Default'
        )
    }

    [PSResourceRepository] Get()
    {
        return ([ResourceBase]$this).Get()
    }

    [void] Set()
    {
        ([ResourceBase]$this).Set()
    }

    [Boolean] Test()
    {
        return ([ResourceBase] $this).Test()
    }

    hidden [void] Modify([System.Collections.Hashtable] $properties)
    {
        $params = @{
            Name = $this.Name
        }

        if ($properties.ContainsKey('Ensure') -and $properties.Ensure -eq 'Absent' -and $this.Ensure -eq 'Absent')
        {
            # Ensure was not in desired state so the repository should be removed
            Write-Verbose -Message ($this.localizedData.RemoveExistingRepository -f $this.Name)

            Unregister-PSRepository @params

            return
        }
        elseif ($properties.ContainsKey('Ensure') -and $properties.Ensure -eq 'Present' -and $this.Ensure -eq 'Present')
        {
            # Ensure was not in desired state so the repository should be created
            $register = $true

        }
        else
        {
            # Repository exist but one or more properties are not in desired state
            $register = $false
        }

        foreach ($key in $properties.Keys.Where({ $_ -ne 'Ensure' }))
        {
            $params[$key] = $properties.$key
        }

        if ($register)
        {
            if ($this.Name -eq 'PSGallery')
            {
                Write-Verbose -Message ($this.localizedData.RegisterDefaultRepository -f $this.Name)

                Register-PSRepository -Default

                #* The user may have specified Proxy & Proxy Credential, or InstallationPolicy params
                Set-PSRepository @params
            }
            else
            {
                if ([System.String]::IsNullOrEmpty($this.SourceLocation))
                {
                    $errorMessage = $this.LocalizedData.SourceLocationRequiredForRegistration

                    New-InvalidArgumentException -ArgumentName 'SourceLocation' -Message $errorMessage
                }

                if ($params.Keys -notcontains 'SourceLocation')
                {
                    $params['SourceLocation'] = $this.SourceLocation
                }

                Write-Verbose -Message ($this.localizedData.RegisterRepository -f $this.Name, $this.SourceLocation)

                Register-PSRepository @params
            }
        }
        else
        {
            Write-Verbose -Message ($this.localizedData.UpdateRepository -f $this.Name, $this.SourceLocation)

            Set-PSRepository @params
        }
    }

    hidden [System.Collections.Hashtable] GetCurrentState ([System.Collections.Hashtable] $properties)
    {
        $returnValue = @{
            Ensure = [Ensure]::Absent
            Name   = $this.Name
        }

        Write-Verbose -Message ($this.localizedData.GetTargetResourceMessage -f $this.Name)

        $repository = Get-PSRepository -Name $this.Name -ErrorAction SilentlyContinue

        if ($repository)
        {
            $returnValue.Ensure                    = [Ensure]::Present
            $returnValue.SourceLocation            = $repository.SourceLocation
            $returnValue.ScriptSourceLocation      = $repository.ScriptSourceLocation
            $returnValue.PublishLocation           = $repository.PublishLocation
            $returnValue.ScriptPublishLocation     = $repository.ScriptPublishLocation
            $returnValue.Proxy                     = $repository.Proxy
            $returnValue.ProxyCredential           = $repository.ProxyCredental
            $returnValue.InstallationPolicy        = $repository.InstallationPolicy
            $returnValue.PackageManagementProvider = $repository.PackageManagementProvider
        }
        else
        {
            Write-Verbose -Message ($this.localizedData.RepositoryNotFound -f $this.Name)
        }

        return $returnValue
    }

    <#
        The parameter properties will contain the properties that was
        assigned a value.
    #>
    hidden [void] AssertProperties([System.Collections.Hashtable] $properties)
    {
        Assert-Module -ModuleName PowerShellGet
        Assert-Module -ModuleName PackageManagement

        $assertBoundParameterParameters = @{
            BoundParameterList = $properties
            MutuallyExclusiveList1 = @(
                'Default'
            )
            MutuallyExclusiveList2 = @(
                'SourceLocation'
                'PackageSourceLocation'
                'ScriptPublishLocation'
                'ScriptSourceLocation'
                'Credential'
                'PackageManagementProvider'
            )
        }

        Assert-BoundParameter @assertBoundParameterParameters

        if ($this.Name -eq 'PSGallery')
        {
            if (-not $this.Default -and $this.Ensure -eq 'Present')
            {
                $errorMessage = $this.localizedData.NoDefaultSettingsPSGallery

                New-InvalidArgumentException -ArgumentName 'Default' -Message $errorMessage
            }
        }
        else
        {
            if ($this.Default)
            {
                $errorMessage = $this.localizedData.DefaultSettingsNoPSGallery

                New-InvalidArgumentException -ArgumentName 'Default' -Message $errorMessage
            }
        }

        if ($this.ProxyCredential -and (-not $this.Proxy))
        {
            $errorMessage = $this.localizedData.ProxyCredentialPassedWithoutProxyUri

            New-InvalidArgumentException -ArgumentName 'ProxyCredential' -Message $errorMessage
        }
    }
}
#EndRegion '.\Classes\020.PSResourceRepository.ps1' 293
#Region '.\Private\ConvertFrom-CompareResult.ps1' 0
<#
    .SYNOPSIS
        Returns a hashtable with property name and their expected value.

    .PARAMETER CompareResult
       The result from Compare-DscParameterState.

    .EXAMPLE
        ConvertFrom-CompareResult -CompareResult (Compare-DscParameterState)

        Returns a hashtable that contain all the properties not in desired state
        and their expected value.

    .OUTPUTS
        [System.Collections.Hashtable]
#>
function ConvertFrom-CompareResult
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Collections.Hashtable[]]
        $CompareResult
    )

    begin
    {
        $returnHashtable = @{}
    }

    process
    {
        $CompareResult | ForEach-Object -Process {
            $returnHashtable[$_.Property] = $_.ExpectedValue
        }
    }

    end
    {
        return $returnHashtable
    }
}
#EndRegion '.\Private\ConvertFrom-CompareResult.ps1' 45
#Region '.\Private\ConvertTo-Reason.ps1' 0
<#
    .SYNOPSIS
        Returns a array of the type `[Reason]`.

    .DESCRIPTION
        This command converts the array of properties that is returned by the command
        `Compare-DscParameterState`. The result is an array of the type `[Reason]` that
        can be returned in a DSC resource's property **Reasons**.

    .PARAMETER Property
       The result from the command Compare-DscParameterState.

    .PARAMETER ResourceName
       The name of the resource. Will be used to populate the property Code with
       the correct value.

    .EXAMPLE
        ConvertTo-Reason -Property (Compare-DscParameterState) -ResourceName 'MyResource'

        Returns an array of `[Reason]` that contain all the properties not in desired
        state and why a specific property is not in desired state.

    .OUTPUTS
        [Reason[]]
#>
function ConvertTo-Reason
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('UseSyntacticallyCorrectExamples', '', Justification = 'Because the rule does not yet support parsing the code when the output type is not available. The ScriptAnalyzer rule UseSyntacticallyCorrectExamples will always error in the editor due to https://github.com/indented-automation/Indented.ScriptAnalyzerRules/issues/8.')]
    [CmdletBinding()]
    [OutputType([Reason[]])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.Collections.Hashtable[]]
        $Property,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceName
    )

    begin
    {
        # Always return an empty array if there are no properties to add.
        $reasons = [Reason[]] @()
    }

    process
    {
        foreach ($currentProperty in $Property)
        {
            if ($currentProperty.ExpectedValue -is [System.Enum])
            {
                # Return the string representation of the value (instead of the numeric value).
                $propertyExpectedValue = $currentProperty.ExpectedValue.ToString()
            }
            else
            {
                $propertyExpectedValue = $currentProperty.ExpectedValue
            }

            if ($property.ActualValue -is [System.Enum])
            {
                # Return the string representation of the value so that conversion to json is correct.
                $propertyActualValue = $currentProperty.ActualValue.ToString()
            }
            else
            {
                $propertyActualValue = $currentProperty.ActualValue
            }

            <#
                In PowerShell 7 the command ConvertTo-Json returns 'null' on null
                value, but not in Windows PowerShell. Switch to output empty string
                if value is null.
            #>
            if ($PSVersionTable.PSEdition -eq 'Desktop')
            {
                if ($null -eq $propertyExpectedValue)
                {
                    $propertyExpectedValue = ''
                }

                if ($null -eq $propertyActualValue)
                {
                    $propertyActualValue = ''
                }
            }

            # Convert the value to Json to be able to easily visualize complex types
            $propertyActualValueJson = $propertyActualValue | ConvertTo-Json -Compress
            $propertyExpectedValueJson = $propertyExpectedValue | ConvertTo-Json -Compress

            # If the property name contain the word Path, remove '\\' from path.
            if ($currentProperty.Property -match 'Path')
            {
                $propertyActualValueJson = $propertyActualValueJson -replace '\\\\', '\'
                $propertyExpectedValueJson = $propertyExpectedValueJson -replace '\\\\', '\'
            }

            $reasons += [Reason] @{
                Code   = '{0}:{0}:{1}' -f $ResourceName, $currentProperty.Property
                # Convert the object to JSON to handle complex types.
                Phrase = 'The property {0} should be {1}, but was {2}' -f @(
                    $currentProperty.Property,
                    $propertyExpectedValueJson,
                    $propertyActualValueJson
                )
            }
        }
    }

    end
    {
        return $reasons
    }
}
#EndRegion '.\Private\ConvertTo-Reason.ps1' 120
#Region '.\Private\Get-ClassName.ps1' 0
<#
    .SYNOPSIS
        Get the class name of the passed object, and optional an array with
        all inherited classes.

    .PARAMETER InputObject
       The object to be evaluated.

    .PARAMETER Recurse
       Specifies if the class name of inherited classes shall be returned. The
       recursive stops when the first object of the type `[System.Object]` is
       found.

    .EXAMPLE
        Get-ClassName -InputObject $this -Recurse

        Get the class name of the current instance and all the inherited (parent)
        classes.

    .OUTPUTS
        [System.String[]]
#>
function Get-ClassName
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Because the rule does not understands that the command returns [System.String[]] when using , (comma) in the return statement')]
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Recurse
    )

    # Create a list of the inherited class names
    $class = @($InputObject.GetType().FullName)

    if ($Recurse.IsPresent)
    {
        $parentClass = $InputObject.GetType().BaseType

        while ($parentClass -ne [System.Object])
        {
            $class += $parentClass.FullName

            $parentClass = $parentClass.BaseType
        }
    }

    return , [System.String[]] $class
}
#EndRegion '.\Private\Get-ClassName.ps1' 56
#Region '.\Private\Get-DscProperty.ps1' 0

<#
    .SYNOPSIS
        Returns DSC resource properties that is part of a class-based DSC resource.

    .DESCRIPTION
        Returns DSC resource properties that is part of a class-based DSC resource.
        The properties can be filtered using name, type, or has been assigned a value.

    .PARAMETER InputObject
        The object that contain one or more key properties.

    .PARAMETER Name
        Specifies one or more property names to return. If left out all properties
        are returned.

    .PARAMETER Type
        Specifies one or more property types to return. If left out all property
        types are returned.

    .PARAMETER HasValue
        Specifies to return only properties that has been assigned a non-null value.
        If left out all properties are returned regardless if there is a value
        assigned or not.

    .EXAMPLE
        Get-DscProperty -InputObject $this

        Returns all DSC resource properties of the DSC resource.

    .EXAMPLE
        Get-DscProperty -InputObject $this -Name @('MyProperty1', 'MyProperty2')

        Returns the specified DSC resource properties names of the DSC resource.

    .EXAMPLE
        Get-DscProperty -InputObject $this -Type @('Mandatory', 'Optional')

        Returns the specified DSC resource property types of the DSC resource.

    .EXAMPLE
        Get-DscProperty -InputObject $this -Type @('Optional') -HasValue

        Returns the specified DSC resource property types of the DSC resource,
        but only those properties that has been assigned a non-null value.

    .OUTPUTS
        [System.Collections.Hashtable]
#>
function Get-DscProperty
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter()]
        [System.String[]]
        $Name,

        [Parameter()]
        [System.String[]]
        $ExcludeName,

        [Parameter()]
        [ValidateSet('Key', 'Mandatory', 'NotConfigurable', 'Optional')]
        [System.String[]]
        $Type,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $HasValue
    )

    $property = $InputObject.PSObject.Properties.Name |
        Where-Object -FilterScript {
            <#
                Return all properties if $Name is not assigned, or if assigned
                just those properties.
            #>
            (-not $Name -or $_ -in $Name) -and

            <#
                Return all properties if $ExcludeName is not assigned. Skip
                property if it is included in $ExcludeName.
            #>
            (-not $ExcludeName -or ($_ -notin $ExcludeName)) -and

            # Only return the property if it is a DSC property.
            $InputObject.GetType().GetMember($_).CustomAttributes.Where(
                {
                    $_.AttributeType.Name -eq 'DscPropertyAttribute'
                }
            )
        }

    if (-not [System.String]::IsNullOrEmpty($property))
    {
        if ($PSBoundParameters.ContainsKey('Type'))
        {
            $propertiesOfType = @()

            $propertiesOfType += $property | Where-Object -FilterScript {
                $InputObject.GetType().GetMember($_).CustomAttributes.Where(
                    {
                        <#
                            To simplify the code, ignoring that this will compare
                            MemberNAme against type 'Optional' which does not exist.
                        #>
                        $_.NamedArguments.MemberName -in $Type
                    }
                ).NamedArguments.TypedValue.Value -eq $true
            }

            # Include all optional parameter if it was requested.
            if ($Type -contains 'Optional')
            {
                $propertiesOfType += $property | Where-Object -FilterScript {
                    $InputObject.GetType().GetMember($_).CustomAttributes.Where(
                        {
                            $_.NamedArguments.MemberName -notin @('Key', 'Mandatory', 'NotConfigurable')
                        }
                    )
                }
            }

            $property = $propertiesOfType
        }
    }

    # Return a hashtable containing each key property and its value.
    $getPropertyResult = @{}

    foreach ($currentProperty in $property)
    {
        if ($HasValue.IsPresent)
        {
            $isAssigned = Test-ResourceDscPropertyIsAssigned -Name $currentProperty -InputObject $InputObject

            if (-not $isAssigned)
            {
                continue
            }
        }

        $getPropertyResult.$currentProperty = $InputObject.$currentProperty
    }

    return $getPropertyResult
}
#EndRegion '.\Private\Get-DscProperty.ps1' 154
#Region '.\Private\Get-LocalizedDataRecursive.ps1' 0
<#
    .SYNOPSIS
        Get the localization strings data from one or more localization string files.
        This can be used in classes to be able to inherit localization strings
        from one or more parent (base) classes.

        The order of class names passed to parameter `ClassName` determines the order
        of importing localization string files. First entry's localization string file
        will be imported first, then next entry's localization string file, and so on.
        If the second (or any consecutive) entry's localization string file contain a
        localization string key that existed in a previous imported localization string
        file that localization string key will be ignored. Making it possible for a
        child class to override localization strings from one or more parent (base)
        classes.

    .PARAMETER ClassName
        An array of class names, normally provided by `Get-ClassName -Recurse`.

    .EXAMPLE
        Get-LocalizedDataRecursive -ClassName $InputObject.GetType().FullName

        Returns a hashtable containing all the localized strings for the current
        instance.

    .EXAMPLE
        Get-LocalizedDataRecursive -ClassName (Get-ClassNamn -InputObject $this -Recurse)

        Returns a hashtable containing all the localized strings for the current
        instance and any inherited (parent) classes.

    .OUTPUTS
        [System.Collections.Hashtable]
#>
function Get-LocalizedDataRecursive
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]]
        $ClassName
    )

    begin
    {
        $localizedData = @{}
    }

    process
    {
        foreach ($name in $ClassName)
        {
            if ($name -match '\.psd1')
            {
                # Assume we got full file name.
                $localizationFileName = $name
            }
            else
            {
                # Assume we only got class name.
                $localizationFileName = '{0}.strings.psd1' -f $name
            }

            Write-Debug -Message ('Importing localization data from {0}' -f $localizationFileName)

            # Get localized data for the class
            $classLocalizationStrings = Get-LocalizedData -DefaultUICulture 'en-US' -FileName $localizationFileName -ErrorAction 'Stop'

            # Append only previously unspecified keys in the localization data
            foreach ($key in $classLocalizationStrings.Keys)
            {
                if (-not $localizedData.ContainsKey($key))
                {
                    $localizedData[$key] = $classLocalizationStrings[$key]
                }
            }
        }
    }

    end
    {
        Write-Debug -Message ('Localization data: {0}' -f ($localizedData | ConvertTo-JSON))

        return $localizedData
    }
}
#EndRegion '.\Private\Get-LocalizedDataRecursive.ps1' 88
#Region '.\Private\Test-ResourceDscPropertyIsAssigned.ps1' 0
<#
    .SYNOPSIS
        Tests whether the class-based resource property is assigned a non-null value.

    .DESCRIPTION
        Tests whether the class-based resource property is assigned a non-null value.

    .PARAMETER InputObject
        Specifies the object that contain the property.

    .PARAMETER Name
        Specifies the name of the property.

    .EXAMPLE
        Test-ResourceDscPropertyIsAssigned -InputObject $this -Name 'MyDscProperty'

        Returns $true or $false whether the property is assigned or not.

    .OUTPUTS
        [System.Boolean]
#>
function Test-ResourceDscPropertyIsAssigned
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $isAssigned = -not ($null -eq $InputObject.$Name)

    return $isAssigned
}
#EndRegion '.\Private\Test-ResourceDscPropertyIsAssigned.ps1' 41
#Region '.\Private\Test-ResourceHasDscProperty.ps1' 0
<#
    .SYNOPSIS
        Tests whether the class-based resource has the specified property.

    .DESCRIPTION
        Tests whether the class-based resource has the specified property.

    .PARAMETER InputObject
        Specifies the object that should be tested for existens of the specified
        property.

    .PARAMETER Name
        Specifies the name of the property.

    .PARAMETER HasValue
        Specifies if the property should be evaluated to have a non-value. If
        the property exist but is assigned `$null` the command returns `$false`.

    .EXAMPLE
        Test-ResourceHasDscProperty -InputObject $this -Name 'MyDscProperty'

        Returns $true or $false whether the property exist or not.

    .EXAMPLE
        Test-ResourceHasDscProperty -InputObject $this -Name 'MyDscProperty' -HasValue

        Returns $true if the property exist and is assigned a non-null value, if not
        $false is returned.

    .OUTPUTS
        [System.Boolean]
#>
function Test-ResourceHasDscProperty
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $HasValue
    )

    $hasProperty = $false

    $isDscProperty = (Get-DscProperty @PSBoundParameters).ContainsKey($Name)

    if ($isDscProperty)
    {
        $hasProperty = $true
    }

    return $hasProperty
}
#EndRegion '.\Private\Test-ResourceHasDscProperty.ps1' 63
