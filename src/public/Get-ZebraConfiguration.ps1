function Get-ZebraConfiguration {
    <#
    .SYNOPSIS
        Reads named SGD settings from a Zebra printer.

    .DESCRIPTION
        Queries the requested names in order and returns one object with a property for each name.
        Property names use ConvertTo-ZebraPropertyName. A failed query warns and leaves that
        property's value null while the remaining names are queried.

    .PARAMETER ComputerName
        Printer hostname or IP address.

    .PARAMETER Name
        One or more SGD variable names that map to unique output property names.

    .PARAMETER Port
        Printer TCP port. Defaults to 9100.

    .EXAMPLE
        $SGDVariables = @(
            'device.product_name'
            'device.unique_id'
            'appl.name'
        )
        Get-ZebraConfiguration -ComputerName 192.0.2.10 -Name $SGDVariables

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. Contains ComputerName and one property per
        requested SGD variable. Empty input or duplicate output property names are rejected.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [int]$Port = 9100
    )

    $SeenPropertyNames = @{ ComputerName = $true }
    foreach ($SettingName in $Name) {
        $PropertyName = ConvertTo-ZebraPropertyName -Name $SettingName
        if ($SeenPropertyNames.ContainsKey($PropertyName)) {
            throw "SGD variable '$SettingName' maps to duplicate output property '$PropertyName'."
        }

        $SeenPropertyNames[$PropertyName] = $true
    }

    $Properties = [ordered]@{
        ComputerName = $ComputerName
    }

    foreach ($SettingName in $Name) {
        $PropertyName = ConvertTo-ZebraPropertyName -Name $SettingName
        $ReadParameters = @{
            ComputerName = $ComputerName
            Operation    = 'Get'
            Name         = $SettingName
            Port         = $Port
        }

        try {
            $Properties[$PropertyName] = Invoke-ZebraSGD @ReadParameters
        } catch {
            Write-Warning "${SettingName}: $_"
            $Properties[$PropertyName] = $null
        }
    }

    [PSCustomObject]$Properties
}
