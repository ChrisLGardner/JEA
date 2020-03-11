using namespace System.Management.Automation.Language

## Convert a string representing a Hashtable into a Hashtable
Function Convert-StringToHashtable {
    param(
        [Parameter(Mandatory)]
        [string]$HashtableAsString
    )

    if ($HashtableAsString -eq $null) {
        $HashtableAsString = '@{}'
    }
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($HashtableAsString, [ref] $null, [ref] $null)
    $data = $ast.Find( { $args[0] -is [System.Management.Automation.Language.HashtableAst] }, $false )

    return [Hashtable] $data.SafeGetValue()
}

## Convert a string representing an array of Hashtables
function Convert-StringToArrayOfHashtable {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralString
    )

    $items = @()

    if ($LiteralString -eq $null) {
        return $items
    }

    # match single hashtable or array of hashtables
    $predicate = {
        param($ast)

        if ($ast -is [System.Management.Automation.Language.HashtableAst]) {
            return ($ast.Parent -is [System.Management.Automation.Language.ArrayLiteralAst]) -or `
            ($ast.Parent -is [System.Management.Automation.Language.CommandExpressionAst])
        }

        return $false
    }

    $rootAst = [System.Management.Automation.Language.Parser]::ParseInput($LiteralString, [ref] $null, [ref] $null)
    $data = $rootAst.FindAll($predicate, $false)

    foreach ($datum in $data) {
        $items += $datum.SafeGetValue()
    }

    return $items
}

## Convert a string representing an array of strings or Hashtables into an array of objects
function Convert-StringToArrayOfObject {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralString
    )

    $items = @()

    if ($LiteralString -eq $null) {
        return $items
    }

    $items += if ($LiteralString -like '*@{*') {
        foreach ($value in $LiteralString) {
            Invoke-Expression -Command $value
        }
    }
    else {
        $LiteralString
    }

    return $items
}

Function Convert-ObjectToHashtable {
    param(
        [Parameter(Mandatory)]
        [object]$Object
    )

    $Parameters = @{ }
    foreach ($Parameter in $Object.PSObject.Properties.Where( { $_.Value })) {
        $Parameters.Add($Parameter.Name, $Parameter.Value)
    }

    return $Parameters
}

Function Compare-JeaConfiguration {
    [cmdletbinding()]
    param (
        [parameter(Mandatory)]
        [hashtable]$ReferenceObject,

        [parameter(Mandatory)]
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

    if ($referenceObjectOrdered.FunctionDefinitions) {
        $referenceObjectOrdered.FunctionDefinitions = foreach ($functionDefinition in $referenceObjectOrdered.FunctionDefinitions) {
            $functionDefinition = Invoke-Expression -Command $functionDefinition | ConvertTo-Expression | Out-String
            $functionDefinition -replace ' ', ''
        }
    }

    if ($differenceObjectOrdered.FunctionDefinitions) {
        $differenceObjectOrdered.FunctionDefinitions = foreach ($functionDefinition in $differenceObjectOrdered.FunctionDefinitions) {
            $functionDefinition = Invoke-Expression -Command $functionDefinition | ConvertTo-Expression | Out-String
            $functionDefinition -replace ' ', ''
        }
    }
    
    if ($referenceObjectOrdered.VisibleCmdlets) {
        $referenceObjectOrdered.VisibleCmdlets = foreach ($visibleCmdlet in $referenceObjectOrdered.VisibleCmdlets) {
            $functionDefinition = Invoke-Expression -Command $VisibleCmdlet | ConvertTo-Expression | Out-String
            $functionDefinition -replace ' ', ''
        }
    }

    if ($differenceObjectOrdered.VisibleCmdlets) {
        $differenceObjectOrdered.VisibleCmdlets = foreach ($visibleCmdlet in $differenceObjectOrdered.VisibleCmdlets) {
            $functionDefinition = Invoke-Expression -Command $VisibleCmdlet | ConvertTo-Expression | Out-String
            $functionDefinition -replace ' ', ''
        }
    }

    if ($referenceObjectOrdered.RoleDefinitions) {
        $referenceObjectOrdered.RoleDefinitions = foreach ($roleDefinition in $referenceObjectOrdered.RoleDefinitions) {
            $RoleDefinition = Invoke-Expression -Command $roleDefinition | ConvertTo-Expression | Out-String
            $RoleDefinition -replace ' ', ''
        }
    }

    if ($differenceObjectOrdered.RoleDefinitions) {
        $differenceObjectOrdered.RoleDefinitions = foreach ($roleDefinition in $differenceObjectOrdered.RoleDefinitions) {
            $RoleDefinition = Invoke-Expression -Command $roleDefinition | ConvertTo-Expression | Out-String
            $RoleDefinition -replace ' ', ''
        }
    }

    $referenceJson = ConvertTo-Json -InputObject $referenceObjectOrdered -Depth 100
    $differenceJson = ConvertTo-Json -InputObject $differenceObjectOrdered -Depth 100

    if ($referenceJson -ne $differenceJson) {
        Write-Verbose "Existing Configuration: $ReferenceJson"
        Write-Verbose "New COnfiguration: $differenceJson"

        return $false
    }
    else {
        return $true
    }
}

Function ConvertTo-Expression {
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

            $Object = Invoke-Expression [String]($Object | ConverTo-Expression)

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
            'IsReadOnly' = $False
            'MaxSupportedDateTime' = [datetime]'9999-12-31T23:59:59.9999999'
            'MinSupportedDateTime' = [datetime]'0001-01-01T00:00:00.0000000'
            'TwoDigitYearMax' = 2029
            }

            PS C:\> (Get-UICulture).Calendar | ConvertTo-Expression -Strong

            [pscustomobject]@{
            'AlgorithmType' = [System.Globalization.CalendarAlgorithmType]'SolarCalendar'
            'CalendarType' = [System.Globalization.GregorianCalendarTypes]'Localized'
            'Eras' = [array][int]1
            'IsReadOnly' = [bool]$False
            'MaxSupportedDateTime' = [datetime]'9999-12-31T23:59:59.9999999'
            'MinSupportedDateTime' = [datetime]'0001-01-01T00:00:00.0000000'
            'TwoDigitYearMax' = [int]2029
            }

            .EXAMPLE

            PS C:\>Get-Date | Select-Object -Property * | ConvertTo-Expression | Out-File .\Now.ps1

            PS C:\>$Now = .\Now.ps1	# $Now = Get-Content .\Now.Ps1 -Raw | Invoke-Expression

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

            PS C:\>@{Account="User01";Domain="Domain01";Admin="True"} | ConvertTo-Expression -Expand -1	# Compress the PowerShell output

            @{'Admin'='True';'Account'='User01';'Domain'='Domain01'}

            .EXAMPLE

            PS C:\>WinInitProcess = Get-Process WinInit | ConvertTo-Expression	# Convert the WinInit Process to a PowerShell expression

            .EXAMPLE

            PS C:\>Get-Host | ConvertTo-Expression -Depth 4	# Reveal complex object hierarchies

            .LINK
            https://www.powershellgallery.com/packages/ConvertFrom-Expression
    #>
    [CmdletBinding()][OutputType([ScriptBlock])]Param (
        [Parameter(ValueFromPipeLine = $True)][Alias('InputObject')]$Object, [Int]$Depth = 9, [Int]$Expand = $Depth,
        [Int]$Indentation = 1, [String]$IndentChar = "`t", [Switch]$Strong, [Switch]$Explore, [Switch]$Concatenate,
        [String]$NewLine = [System.Environment]::NewLine
    )
    Begin {
        If (!$PSCmdlet.MyInvocation.ExpectingInput) { If ($Concatenate) { Write-Warning 'The concatenate switch only applies to pipeline input' } Else { $Concatenate = $True } }
        $Tab = $IndentChar * $Indentation
        Function Serialize($Object, $Iteration, $Indent) {
            Function Quote ([String]$Item) { "'$($Item.Replace('''', ''''''))'" }
            Function Here ([String]$Item) { If ($Item -Match '[\r\n]') { "@'$NewLine$Item$NewLine'@$NewLine" } Else { Quote $Item } }
            Function Stringify ($Object, $Cast = $Type) {
                $Explicit = $PSBoundParameters.ContainsKey('Cast')
                Function Prefix { If ($Explore) { If ($Strong) { "[$Type]" } } ElseIf ($Strong -or $Explicit) { If ($Cast) { "[$Cast]" } } }
                Function Iterate($Object, [Switch]$ListItem, [Switch]$Level) {
                    If ($Iteration -lt $Depth) { Serialize $Object -Iteration ($Iteration + 1) -Indent ($Indent + 1 - [Int][Bool]$Level) } Else { "'...'" }
                }
                If ($Object -is [String]) { (Prefix) + $Object } Else {
                    $List, $Properties = $Null; $Methods = $Object.PSObject.Methods.Name
                    If ($Methods -Contains 'GetEnumerator') {
                        If ($Methods -Contains 'get_Keys' -and $Methods -Contains 'get_Values') {
                            $List = [Ordered]@{ }; ForEach ($Key in $Object.get_Keys()) { $List[(Quote $Key)] = Iterate $Object[$Key] }
                        }
                        Else {
                            $List = @(ForEach ($Item in $Object) { Iterate $Item -ListItem -Level:($Count -eq 1 -or ($Null -eq $Indent -and !$Explore -and !$Strong)) })
                        }
                    }
                    Else {
                        $Properties = $Object.PSObject.Properties | Where-Object { $_.MemberType -eq 'Property' }
                        If (!$Properties) { $Properties = $Object.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } }
                        If ($Properties) { $List = [Ordered]@{ }; ForEach ($Property in $Properties) { $List[(Quote $Property.Name)] = Iterate $Property.Value } }
                    }
                    If ($List -is [Array]) {
                        If (!$Explicit) { $Cast = 'array' }
                        If (!$List.Count) { (Prefix) + '@()' }
                        ElseIf ($List.Count -eq 1) {
                            If ($Strong) { (Prefix) + "$List" }
                            ElseIf ($ListItem) { "(,$List)" }
                            Else { ",$List" }
                        }
                        ElseIf ($Indent -ge $Expand - 1) {
                            $Content = If ($Expand -ge 0) { $List -Join ', ' } Else { $List -Join ',' }
                            If ($ListItem -or $Strong) { (Prefix) + "($Content)" } Else { $Content }
                        }
                        ElseIf ($Null -eq $Indent -and !$Strong) { $List -Join ",$NewLine" }
                        Else {
                            $LineFeed = $NewLine + ($Tab * $Indent)
                            $Content = "$LineFeed$Tab" + ($List -Join ",$LineFeed$Tab")
                            If ($ListItem -or $Strong) { (Prefix) + "($Content$LineFeed)" } Else { $Content }
                        }
                    }
                    ElseIf ($List -is [System.Collections.Specialized.OrderedDictionary]) {
                        If (!$Explicit) { If ($Properties) { $Explicit = $True; $Cast = 'pscustomobject' } Else { $Cast = 'hashtable' } }
                        If (!$List.Count) { (Prefix) + '@{}' }
                        ElseIf ($Expand -lt 0) { (Prefix) + '@{' + (@(ForEach ($Key in $List.get_Keys()) { "$Key=$($List.$Key)" }) -Join ';') + '}' }
                        ElseIf ($List.Count -eq 1 -or $Indent -ge $Expand - 1) {
                            (Prefix) + '@{' + (@(ForEach ($Key in $List.get_Keys()) { "$Key = $($List.$Key)" }) -Join '; ') + '}'
                        }
                        Else {
                            $LineFeed = $NewLine + ($Tab * $Indent)
                            (Prefix) + "@{$LineFeed$Tab" + (@(ForEach ($Key in $List.get_Keys()) {
                                        If (($List.$Key)[0] -NotMatch '[\S]') { "$Key =$($List.$Key)".TrimEnd() } Else { "$Key = $($List.$Key)".TrimEnd() }
                                    }) -Join "$LineFeed$Tab") + "$LineFeed}"
                        }
                    }
                    Else { (Prefix) + ",$List" }
                }
            }
            If ($Null -eq $Object) { "`$Null" } Else {
                $Type = $Object.GetType()
                If ($Object -is [Boolean]) { If ($Object) { Stringify '$True' } Else { Stringify '$False' } }
                ElseIf ($Object -is [Char]) { Stringify "'$($Object)'" $Type }
                ElseIf ($Type.IsPrimitive) { Stringify "$Object" }
                ElseIf ($Object -is [String]) { Stringify (Here $Object) }
                ElseIf ($Object -is [DateTime]) { Stringify "'$($Object.ToString('o'))'" $Type }
                ElseIf ($Object -is [Version] -or $Type.Name -eq 'SemVer') { Stringify "'$Object'" $Type }
                ElseIf ($Type.Name -eq 'SemanticVersion') { Stringify "'$Object'" 'semver' }
                ElseIf ($Object -is [Enum]) { If ($Strong) { Stringify "'$Object'" $Type } Else { Stringify "$(0 + $Object)" } }
                ElseIf ($Object -is [ScriptBlock]) { If ($Object -Match "\#.*?$") { Stringify "{$Object$NewLine}" } Else { Stringify "{$Object}" } }
                ElseIf ($Object -is [RuntimeTypeHandle]) { Stringify "$($Object.Value)" }
                ElseIf ($Object -is [Xml]) {
                    $SW = New-Object System.IO.StringWriter; $XW = New-Object System.Xml.XmlTextWriter $SW
                    $XW.Formatting = If ($Indent -lt $Expand - 1) { 'Indented' } Else { 'None' }
                    $XW.Indentation = $Indentation; $XW.IndentChar = $IndentChar; $Object.WriteContentTo($XW); Stringify (Here $SW) $Type
                }
                ElseIf ($Object -is [System.Data.DataTable]) { Stringify $Object.Rows }
                ElseIf ($Type.Name -eq "OrderedDictionary") { Stringify $Object ordered }
                ElseIf ($Object -is [ValueType]) { Stringify "'$($Object)'" $Type }
                Else { Stringify $Object }
            }
        }
    }
    Process {
        $Expression = (Serialize $Object).TrimEnd()
        Try { [ScriptBlock]::Create($Expression) } Catch { $PSCmdlet.WriteError($_); $Expression }
    }
}

function Convert-StringToObject {
    [cmdletbinding()]
    param (
        [string[]]$InputString
    )

    foreach ($string in $InputString) {
        $ParseErrors = @()
        $FakeCommand = "Totally-NotACmdlet -FakeParameter $string"
        $AST = [Parser]::ParseInput($FakeCommand, [ref]$null, [ref]$ParseErrors)
        if (-not $ParseErrors) {
            # Use Ast.Find() to locate the CommandAst parsed from our fake command
            $CmdAst = $AST.Find( { param($ChildAst) $ChildAst -is [CommandAst] }, $false)
            # Grab the user-supplied arguments (index 0 is the command name, 1 is our fake parameter)
            $AllArgumentAst = $CmdAst.CommandElements.Where( { $_ -isnot [CommandParameterAst] -and $_.Value -ne 'Totally-NotACmdlet' })
            foreach ($ArgumentAst in $AllArgumentAst) {
                if ($ArgumentAst -is [ArrayLiteralAst]) {
                    # Argument was a list
                    foreach ($Element in $ArgumentAst.Elements) {
                        if ($Element.StaticType.Name -eq 'String') {
                            $Element.value
                        }
                        if ($Element.StaticType.Name -eq 'Hashtable') {
                            [Hashtable]$Element.SafeGetValue()
                        }
                    }
                }
                else {
                    if ($ArgumentAst -is [HashtableAst]) {
                        $ht = [Hashtable]$ArgumentAst.SafeGetValue()
                        for ($i = 1; $i -lt $ht.Keys.Count; $i++) {
                            $value = $ht[([array]$ht.Keys)[$i]]
                            if ($value -is [scriptblock]) {

                                $scriptBlockText = $value.Ast.Extent.Text

                                if ($scriptBlockText[$value.Ast.Extent.StartOffset] -eq '{' -and $scriptBlockText[$endOffset - 1] -eq '}') {

                                    $scriptBlockText = $scriptBlockText.Substring(0, $scriptBlockText.Length - 1)
                                    $scriptBlockText = $scriptBlockText.Substring(1, $scriptBlockText.Length - 1)
                                }

                                $ht[([array]$ht.Keys)[$i]] = [scriptblock]::Create($scriptBlockText)
                            }
                        }
                        $ht
                    }
                    elseif ($ArgumentAst -is [StringConstantExpressionAst]) {
                        $ArgumentAst.Value
                    }
                    else {
                        Write-Error -Message "Input was not a valid hashtable, string or collection of both. Please check the contents and try again."
                    }
                }
            }
        }
    }
}
