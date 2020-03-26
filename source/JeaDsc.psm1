using namespace System.Management.Automation.Language

## Convert a string representing a Hashtable into a Hashtable
function Convert-StringToHashtable
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$HashtableAsString
    )

    if ($HashtableAsString -eq $null)
    {
        $HashtableAsString = '@{}'
    }
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($HashtableAsString, [ref] $null, [ref] $null)
    $data = $ast.Find( { $args[0] -is [System.Management.Automation.Language.HashtableAst] }, $false )

    return [Hashtable] $data.SafeGetValue()
}

## Convert a string representing an array of Hashtables
function Convert-StringToArrayOfHashtable
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$LiteralString
    )

    $items = @()

    if ($LiteralString -eq $null)
    {
        return $items
    }

    # match single hashtable or array of hashtables
    $predicate = {
        param (
            [Parameter(Mandatory = $true)]    
            [System.Management.Automation.Language.Ast]$ast
        )

        if ($ast -is [System.Management.Automation.Language.HashtableAst])
        {
            return ($ast.Parent -is [System.Management.Automation.Language.ArrayLiteralAst]) -or `
            ($ast.Parent -is [System.Management.Automation.Language.CommandExpressionAst])
        }

        return $false
    }

    $rootAst = [System.Management.Automation.Language.Parser]::ParseInput($LiteralString, [ref] $null, [ref] $null)
    $data = $rootAst.FindAll($predicate, $false)

    foreach ($datum in $data)
    {
        $items += $datum.SafeGetValue()
    }

    return $items
}

## Convert a string representing an array of strings or Hashtables into an array of objects
function Convert-StringToArrayOfObject
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$LiteralString
    )

    $items = @()

    if ($LiteralString -eq $null)
    {
        return $items
    }

    $items += if ($LiteralString -like '*@{*')
    {
        foreach ($value in $LiteralString)
        {
            Invoke-Expression -Command $value
        }
    }
    else
    {
        $LiteralString
    }

    return $items
}

function Convert-ObjectToHashtable
{
    param (
        [Parameter(Mandatory = $true)]
        [object]$Object
    )

    $parameters = @{ }
    foreach ($parameter in $Object.PSObject.Properties.Where( { $_.Value }))
    {
        $parameters.Add($parameter.Name, $parameter.Value)
    }

    return $parameters
}

function Compare-JeaConfiguration
{
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$ReferenceObject,

        [Parameter(Mandatory = $true)]
        [hashtable]$DifferenceObject
    )

    $referenceObjectOrdered = [System.Collections.Specialized.OrderedDictionary]@{ }
    $ReferenceObject.Keys |
    Sort-Object -Descending |
    ForEach-Object {
        $referenceObjectOrdered.Insert(0, $_, $ReferenceObject["$_"])
    }

    $differenceObjectOrdered = [System.Collections.Specialized.OrderedDictionary]@{ }
    $DifferenceObject.Keys |
    Sort-Object -Descending |
    ForEach-Object {
        $differenceObjectOrdered.Insert(0, $_, $DifferenceObject["$_"])
    }

    if ($referenceObjectOrdered.functionDefinitions)
    {
        $referenceObjectOrdered.functionDefinitions = foreach ($functionDefinition in $referenceObjectOrdered.functionDefinitions)
        {
            $functionDefinition = Invoke-Expression -Command $functionDefinition | ConvertTo-Expression | Out-String
            $functionDefinition -replace ' ', ''
        }
    }

    if ($differenceObjectOrdered.functionDefinitions)
    {
        $differenceObjectOrdered.functionDefinitions = foreach ($functionDefinition in $differenceObjectOrdered.functionDefinitions)
        {
            $functionDefinition = Invoke-Expression -Command $functionDefinition | ConvertTo-Expression | Out-String
            $functionDefinition -replace ' ', ''
        }
    }

    if ($referenceObjectOrdered.VisibleCmdlets)
    {
        $referenceObjectOrdered.VisibleCmdlets = foreach ($visibleCmdlet in $referenceObjectOrdered.VisibleCmdlets)
        {
            if ($referenceObjectOrdered.VisibleCmdlets[0] -match '@{')
            {
                $functionDefinition = Invoke-Expression -Command $visibleCmdlet | ConvertTo-Expression | Out-String
                $functionDefinition -replace ' ', ''
            }
            else
            {
                $referenceObjectOrdered.VisibleCmdlets
            }
        }
    }

    if ($differenceObjectOrdered.VisibleCmdlets)
    {
        $differenceObjectOrdered.VisibleCmdlets = foreach ($visibleCmdlet in $differenceObjectOrdered.VisibleCmdlets)
        {
            if ($differenceObjectOrdered.VisibleCmdlets[0] -match '@{')
            {
                $functionDefinition = Invoke-Expression -Command $visibleCmdlet | ConvertTo-Expression | Out-String
                $functionDefinition -replace ' ', ''
            }
            else
            {
                $differenceObjectOrdered.VisibleCmdlets
            }
        }
    }

    if ($referenceObjectOrdered.RoleDefinitions)
    {
        $referenceObjectOrdered.RoleDefinitions = foreach ($roleDefinition in $referenceObjectOrdered.RoleDefinitions)
        {
            $RoleDefinition = Invoke-Expression -Command $roleDefinition | ConvertTo-Expression | Out-String
            $RoleDefinition -replace ' ', ''
        }
    }

    if ($differenceObjectOrdered.RoleDefinitions)
    {
        $differenceObjectOrdered.RoleDefinitions = foreach ($roleDefinition in $differenceObjectOrdered.RoleDefinitions)
        {
            $RoleDefinition = Invoke-Expression -Command $roleDefinition | ConvertTo-Expression | Out-String
            $RoleDefinition -replace ' ', ''
        }
    }

    $referenceJson = ConvertTo-Json -InputObject $referenceObjectOrdered -Depth 100
    $differenceJson = ConvertTo-Json -InputObject $differenceObjectOrdered -Depth 100

    if ($referenceJson -ne $differenceJson)
    {
        Write-Verbose "Existing Configuration: $ReferenceJson"
        Write-Verbose "New COnfiguration: $differenceJson"

        return $false
    }
    else
    {
        return $true
    }
}

function ConvertTo-Expression
{
    <#
            .SYNOPSIS
            Serializes an object to a PowerShell expression.

            .DESCRIPTION
            The ConvertTo-Expression cmdlet converts (serialize) an object to a
            PowerShell expression. The object can be stored in a variable, file or
            any other common storage for later use or to be ported to another
            system.

            Converting back from an expression
            An expression can be restored to an object by preceding it with an
            ampersand (&):

            $Object = &($Object | ConverTo-Expression)

            An expression that is casted to a string can be restored to an
            object using the native Invoke-Expression cmdlet:

            $Object = Invoke-Expression [string]($Object | ConverTo-Expression)

            An expression that is stored in a PowerShell (.ps1) file might also
            be directly invoked by the PowerShell dot-sourcing technique, e.g.:

            $Object | ConvertTo-Expression | Out-File .\Expression.ps1
            $Object = . .\Expression.ps1

            .INPUTS
            Any. Each objects provided through the pipeline will converted to an
            expression. To concatinate all piped objects in a single expression,
            use the unary comma operator, e.g.: ,$Object | ConvertTo-Expression

            .OUTPUTS
            System.Management.Automation.ScriptBlock[]. ConvertTo-Expression
            returns a PowerShell expression (ScriptBlock) for each input object.
            A PowerShell expression default display output is a Sytem.String.

            .PARAMETER InputObject
            Specifies the objects to convert to a PowerShell expression. Enter a
            variable that contains the objects, or type a command or expression
            that gets the objects. You can also pipe one or more objects to
            ConvertTo-Expression.

            .PARAMETER Depth
            Specifies how many levels of contained objects are included in the
            PowerShell representation. The default value is 9.

            .PARAMETER Expand
            Specifies till what level the contained objects are expanded over
            separate lines and indented according to the -Indentation and
            -IndentChar parameters. The default value is equal to the -Depth value.

            A negative value will remove redundant spaces and compress the
            PowerShell expression to a single line (except for multi-line strings).

            Xml documents and multi-line strings are embedded in a "here string"
            and aligned to the left.

            .PARAMETER Indentation
            Specifies how many IndentChars to write for each level in the
            hierarchy.

            .PARAMETER IndentChar
            Specifies which character to use for indenting.

            .PARAMETER Strong
            By default, the ConvertTo-Expression cmdlet will return a weakly typed
            expression which is best for transfing objects between differend
            PowerShell systems.
            The -Strong parameter will strickly define value types and objects
            in a way that they can still be read by same PowerShell system and
            PowerShell system with the same configuration (installed modules etc.).

            .PARAMETER Explore
            In explore mode, all type prefixes are omitted in the output expression
            (objects will cast to to hash tables). In case the -Strong parameter is
            also supplied, all orginal (.Net) type names are shown.
            The -Explore switch is usefull for exploring object hyrachies and data
            type, not for saving and transfering objects.

            .EXAMPLE

            PS C:\> (Get-UICulture).Calendar | ConvertTo-Expression

            [pscustomobject]@{
            'AlgorithmType' = 1
            'CalendarType' = 1
            'Eras' = ,1
            'IsReadOnly' = $false
            'MaxSupportedDateTime' = [datetime]'9999-12-31T23:59:59.9999999'
            'MinSupportedDateTime' = [datetime]'0001-01-01T00:00:00.0000000'
            'TwoDigitYearMax' = 2029
            }

            PS C:\> (Get-UICulture).Calendar | ConvertTo-Expression -Strong

            [pscustomobject]@{
            'AlgorithmType' = [System.Globalization.CalendarAlgorithmType]'SolarCalendar'
            'CalendarType' = [System.Globalization.GregorianCalendarTypes]'Localized'
            'Eras' = [array][int]1
            'IsReadOnly' = [bool]$false
            'MaxSupportedDateTime' = [datetime]'9999-12-31T23:59:59.9999999'
            'MinSupportedDateTime' = [datetime]'0001-01-01T00:00:00.0000000'
            'TwoDigitYearMax' = [int]2029
            }

            .EXAMPLE

            PS C:\>Get-Date | Select-Object -Property * | ConvertTo-Expression | Out-File .\Now.ps1

            PS C:\>$Now = .\Now.ps1 # $Now = Get-Content .\Now.Ps1 -Raw | Invoke-Expression

            PS C:\>$Now

            Date        : 1963-10-07 12:00:00 AM
            DateTime    : Monday, October 7, 1963 10:47:00 PM
            Day         : 7
            DayOfWeek   : Monday
            DayOfYear   : 280
            DisplayHint : DateTime
            Hour        : 22
            Kind        : Local
            Millisecond : 0
            Minute      : 22
            Month       : 1
            Second      : 0
            Ticks       : 619388596200000000
            TimeOfDay   : 22:47:00
            Year        : 1963

            .EXAMPLE

            PS C:\>@{Account="User01";Domain="Domain01";Admin="True"} | ConvertTo-Expression -Expand -1 # Compress the PowerShell output

            @{'Admin'='True';'Account'='User01';'Domain'='Domain01'}

            .EXAMPLE

            PS C:\>WinInitProcess = Get-Process WinInit | ConvertTo-Expression # Convert the WinInit Process to a PowerShell expression

            .EXAMPLE

            PS C:\>Get-Host | ConvertTo-Expression -Depth 4 # Reveal complex object hierarchies

            .LINK
            https://www.powershellgallery.com/packages/ConvertFrom-Expression
    #>
    [CmdletBinding()]
    [OutputType([ScriptBlock])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeLine = $true)]
        [Alias('InputObject')]
        [object]$Object,
        
        [Parameter()]
        [int]$Depth = 9,

        [Parameter()]
        [int]$Expand = $Depth,
        
        [Parameter()]
        [int]$Indentation = 1,
        
        [Parameter()]
        [string]$IndentChar = "`t",
        
        [Parameter()]
        [switch]$Strong,
        
        [Parameter()]
        [switch]$Explore,
        
        [Parameter()]
        [switch]$Concatenate,

        [Parameter()]
        [string]$NewLine = [System.Environment]::NewLine
    )
    begin
    {
        if (-not $PSCmdlet.MyInvocation.ExpectingInput)
        {
            if ($Concatenate)
            {
                Write-Warning 'The concatenate switch only applies to pipeline input'
            }
            else
            {
                $Concatenate = $true
            }
        }
        $tab = $IndentChar * $Indentation
        function Serialize
        {
            param (
                [Parameter(Mandatory = $true)]
                [object]$Object,

                [Parameter(Mandatory = $true)]
                $Iteration,

                [Parameter(Mandatory = $true)]
                $Indent
            )
            function Quote
            {
                param (
                    [Parameter(Mandatory = $true)]
                    [string]$Item
                )
                "'$($Item.Replace('''', ''''''))'"
            }

            function Here
            {
                param (
                    [Parameter(Mandatory = $true)]
                    [string]$Item
                )

                if ($Item -Match '[\r\n]')
                {
                    "@'$NewLine$item$NewLine'@$NewLine"
                }
                else
                {
                    Quote -Item $item
                }
            }
            function Stringify
            {
                param        (
                    [Parameter(Mandatory = $true)]
                    $Object,
                    
                    [Parameter()]
                    $Cast = $Type
                )

                $explicit = $PSBoundparameters.ContainsKey('Cast')
                function Prefix
                {
                    if ($Explore)
                    {
                        if ($Strong)
                        {
                            "[$Type]"
                        }
                    }
                    elseif ($Strong -or $Explicit)
                    {
                        if ($Cast)
                        {
                            "[$Cast]"
                        }
                    }
                }
                function Iterate
                {
                    param (
                        [Parameter(Mandatory = $true)]
                        [object]$Object,
                        
                        [Parameter()]
                        [switch]$ListItem,
                        
                        [Parameter()]
                        [switch]$Level
                    )
                    if ($Iteration -lt $Depth)
                    {
                        Serialize -Object $Object -Iteration ($Iteration + 1) -Indent ($Indent + 1 - [int][bool]$Level)
                    }
                    else
                    {
                        "'...'"
                    }
                }
                if ($Object -is [string])
                {
                    (Prefix) + $Object
                }
                else
                {
                    $list = $null
                    $properties = $null
                    $Methods = $Object.PSObject.Methods.Name

                    if ($Methods -Contains 'GetEnumerator')
                    {
                        if ($Methods -Contains 'get_Keys' -and $Methods -Contains 'get_Values')
                        {
                            $list = [Ordered]@{ }
                            foreach ($key in $Object.get_Keys())
                            {
                                $list[(Quote -Item $key)] = Iterate -Object $Object[$key]
                            }
                        }
                        else
                        {
                            $list = @(foreach ($item in $Object)
                                {
                                    Iterate -Object $item -ListItem -Level:($Count -eq 1 -or ($null -eq $Indent -and -not $Explore -and -not $Strong))
                                })
                        }
                    }
                    else
                    {
                        $properties = $Object.PSObject.Properties | Where-Object { $_.MemberType -eq 'Property' }
                        if (-not $properties)
                        {
                            $properties = $Object.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }
                        }
                        if ($properties)
                        {
                            $List = [Ordered]@{ }
                            foreach ($Property in $Properties)
                            {
                                $list[(Quote $Property.Name)] = Iterate -Object $Property.Value
                            }
                        }
                    }
                    if ($list -is [Array])
                    {
                        if (-not $Explicit)
                        {
                            $Cast = 'array'
                        }
                        if (-not $list.Count)
                        {
                            (Prefix) + '@()'
                        }
                        elseif ($list.Count -eq 1)
                        {
                            if ($Strong)
                            {
                                (Prefix) + "$list"
                            }
                            elseif ($listItem)
                            {
                                "(,$list)"
                            }
                            else
                            {
                                ",$list"
                            }
                        }
                        elseif ($Indent -ge $Expand - 1)
                        {
                            $content = if ($Expand -ge 0)
                            {
                                $list -Join ', '
                            }
                            else
                            {
                                $list -Join ','
                            }
                            if ($listItem -or $Strong)
                            {
                                (Prefix) + "($content)"
                            }
                            else
                            {
                                $content
                            }
                        }
                        elseif ($null -eq $Indent -and -not $Strong)
                        {
                            $list -Join ",$NewLine"
                        }
                        else
                        {
                            $lineFeed = $NewLine + ($tab * $Indent)
                            $content = "$lineFeed$tab" + ($List -Join ",$lineFeed$tab")
                            if ($listItem -or $Strong)
                            {
                                (Prefix) + "($content$lineFeed)"
                            }
                            else
                            {
                                $content
                            }
                        }
                    }
                    elseif ($list -is [System.Collections.Specialized.OrderedDictionary])
                    {
                        if (-not $Explicit)
                        {
                            if ($properties)
                            {
                                $explicit = $true
                                $cast = 'pscustomobject'
                            }
                            else
                            {
                                $cast = 'hashtable'
                            }
                        }
                        if (-not $list.Count)
                        {
                            (Prefix) + '@{}'
                        }
                        elseif ($Expand -lt 0)
                        {
                            (Prefix) + '@{' + (@(foreach ($key in $list.get_Keys())
                                    {
                                        "$key=$($list.$key)"
                                    }) -Join ';') + '}'
                        }
                        elseif ($list.Count -eq 1 -or $Indent -ge $Expand - 1)
                        {
                            (Prefix) + '@{' + (@(foreach ($key in $list.get_Keys())
                                    {
                                        "$key = $($list.$key)"
                                    }) -Join '; ') + '}'
                        }
                        else
                        {
                            $lineFeed = $NewLine + ($tab * $Indent)
                            (Prefix) + "@{$lineFeed$tab" + (@(foreach ($key in $list.get_Keys())
                                    {
                                        if (($list.$key)[0] -NotMatch '[\S]')
                                        {
                                            "$key =$($list.$key)".TrimEnd()
                                        }
                                        else
                                        {
                                            "$key = $($list.$key)".TrimEnd()
                                        }
                                    }) -Join "$lineFeed$tab") + "$lineFeed}"
                        }
                    }
                    else
                    {
                        (Prefix) + ",$list"
                    }
                }
            }
            if ($null -eq $Object)
            {
                '$null'
            }
            else
            {
                $type = $Object.GetType()
                if ($Object -is [bool])
                {
                    if ($Object)
                    {
                        Stringify -Object '$true'
                    }
                    else
                    {
                        Stringify -Object '$false'
                    }
                }
                elseif ($Object -is [char])
                {
                    Stringify -Object "'$($Object)'" -Cast $Type
                }
                elseif ($Type.IsPrimitive)
                {
                    Stringify -Object "$Object"
                }
                elseif ($Object -is [string])
                {
                    Stringify -Object (Here $Object)
                }
                elseif ($Object -is [datetime])
                {
                    Stringify -Object "'$($Object.ToString('o'))'" -Cast $Type
                }
                elseif ($Object -is [System.Version] -or $Type.Name -eq 'SemVer')
                {
                    Stringify -Object "'$Object'" -Cast $Type
                }
                elseif ($Type.Name -eq 'SemanticVersion')
                {
                    Stringify -Object "'$Object'" -Cast semver
                }
                elseif ($Object -is [System.Enum])
                {
                    if ($Strong)
                    {
                        Stringify -Object "'$Object'" -Cast $Type
                    }
                    else
                    {
                        Stringify -Object "$(0 + $Object)"
                    }
                }
                elseif ($Object -is [scriptblock])
                {
                    if ($Object -Match "\#.*?$")
                    {
                        Stringify -Object "{$Object$NewLine}"
                    }
                    else
                    {
                        Stringify -Object "{$Object}"
                    }
                }
                elseif ($Object -is [System.RuntimeTypeHandle])
                {
                    Stringify -Object "$($Object.Value)"
                }
                elseif ($Object -is [xml])
                {
                    $sw = New-Object System.IO.StringWriter
                    $xw = New-Object System.Xml.XmlTextWriter($sw)
                    $xw.Formatting = if ($Indent -lt $Expand - 1)
                    {
                        'Indented'
                    }
                    else
                    {
                        'None'
                    }
                    $xw.Indentation = $Indentation
                    $xw.IndentChar = $IndentChar
                    $Object.WriteContentTo($xw)
                    Stringify -Object (Here -Item $sw) -Cast $Type
                }
                elseif ($Object -is [System.Data.DataTable])
                {
                    Stringify -Object $Object.Rows
                }
                elseif ($Type.Name -eq 'OrderedDictionary')
                {
                    Stringify -Object $Object -Cast ordered
                }
                elseif ($Object -is [ValueType])
                {
                    Stringify -Object "'$($Object)'" -Cast $Type
                }
                else
                {
                    Stringify -Object $Object
                }
            }
        }
    }
    process
    {
        $expression = (Serialize -Object $Object).TrimEnd()
        try
        {
            [ScriptBlock]::Create($expression)
        }
        catch
        {
            $PSCmdlet.WriteError($_)
            $expression
        }
    }
}

function Convert-StringToObject
{
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$InputString
    )

    foreach ($string in $InputString)
    {
        $parseErrors = @()
        $fakeCommand = "Totally-NotACmdlet -Fakeparameter $string"
        $ast = [Parser]::ParseInput($fakeCommand, [ref]$null, [ref]$parseErrors)
        if (-not $parseErrors)
        {
            # Use Ast.Find() to locate the CommandAst parsed from our fake command
            $cmdAst = $ast.Find( {
                    param (
                        [Parameter(Mandatory = $true)]
                        [System.Management.Automation.Language.Ast]$ChildAst
                    )
                    $ChildAst -is [CommandAst]
                }
                , $false
            )
            # Grab the user-supplied arguments (index 0 is the command name, 1 is our fake parameter)
            $allArgumentAst = $cmdAst.CommandElements.Where( { $_ -isnot [CommandparameterAst] -and $_.Value -ne 'Totally-NotACmdlet' })
            foreach ($argumentAst in $allArgumentAst)
            {
                if ($argumentAst -is [ArrayLiteralAst])
                {
                    # Argument was a list
                    foreach ($element in $argumentAst.Elements)
                    {
                        if ($element.StaticType.Name -eq 'String')
                        {
                            $element.value
                        }
                        if ($element.StaticType.Name -eq 'Hashtable')
                        {
                            [Hashtable]$element.SafeGetValue()
                        }
                    }
                }
                else
                {
                    if ($argumentAst -is [HashtableAst])
                    {
                        $ht = [Hashtable]$argumentAst.SafeGetValue()
                        for ($i = 1; $i -lt $ht.Keys.Count; $i++)
                        {
                            $value = $ht[([array]$ht.Keys)[$i]]
                            if ($value -is [scriptblock])
                            {
                                $scriptBlockText = $value.Ast.Extent.Text

                                if ($scriptBlockText[$value.Ast.Extent.StartOffset] -eq '{' -and $scriptBlockText[$endOffset - 1] -eq '}')
                                {
                                    $scriptBlockText = $scriptBlockText.Substring(0, $scriptBlockText.Length - 1)
                                    $scriptBlockText = $scriptBlockText.Substring(1, $scriptBlockText.Length - 1)
                                }

                                $ht[([array]$ht.Keys)[$i]] = [scriptblock]::Create($scriptBlockText)
                            }
                        }
                        $ht
                    }
                    elseif ($argumentAst -is [StringConstantExpressionAst])
                    {
                        $argumentAst.Value
                    }
                    else
                    {
                        Write-Error -Message "Input was not a valid hashtable, string or collection of both. Please check the contents and try again."
                    }
                }
            }
        }
    }
}
