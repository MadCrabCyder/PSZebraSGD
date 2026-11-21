function Get-ZebraConfiguration {
    <#
    .SYNOPSIS
        Reads named SGD settings from a Zebra printer.
    .DESCRIPTION
        Queries each name in the supplied order. Repeated names are queried again.
    .PARAMETER ComputerName
        Printer hostname or IP address.
    .PARAMETER Name
        One or more SGD variable names.
    .PARAMETER Port
        Printer TCP port. Defaults to 9100.
    .EXAMPLE
        Get-ZebraConfiguration -ComputerName 192.0.2.10 -Name device.unique_id, appl.name
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. Each record has ComputerName, Name and Value properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string[]]$Name,

        [int]$Port = 9100
    )

    foreach ($SettingName in $Name) {
        $ReadParameters = @{
            ComputerName = $ComputerName
            Operation    = 'Get'
            Name         = $SettingName
            Port         = $Port
        }

        [PSCustomObject]@{
            ComputerName = $ComputerName
            Name         = $SettingName
            Value        = Invoke-ZebraSGD @ReadParameters
        }
    }
}
