function Get-ZebraPrinter {
    <#
    .SYNOPSIS
        Reads identification and firmware information from a Zebra printer.

    .DESCRIPTION
        Queries SGD variables in sequence. If a query throws, the command warns,
        leaves that property null and continues with the remaining variables.

    .PARAMETER ComputerName
        Printer hostname or IP address.

    .PARAMETER Port
        Printer TCP port. Defaults to 9100.

    .EXAMPLE
        Get-ZebraPrinter -ComputerName 192.0.2.10

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. Contains ComputerName, ProductName, UniqueId,
        FriendlyName, Application, Firmware, ActiveNetwork, MacAddr and LabelsPrinted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [int]$Port = 9100
    )

    $Fields = @(
        'device.product_name'
        'device.unique_id'
        'device.friendly_name'
        'appl.name'
        'appl.link_os_version'
        'ip.active_network'
        'interface.network.active.mac_addr'
        'odometer.total_label_count'
    )

    $Values = @{}
    foreach ($Field in $Fields) {
        $ReadParameters = @{
            ComputerName = $ComputerName
            Operation    = 'Get'
            Name         = $Field
            Port         = $Port
        }

        try {
            $Values[$Field] = Invoke-ZebraSGD @ReadParameters
        } catch {
            Write-Warning "${Field}: $_"
            $Values[$Field] = $null
        }
    }

    $Properties = [ordered]@{
        ComputerName = $ComputerName
    }

    foreach ($Field in $Fields) {
        $PropertyName = ConvertTo-ZebraPropertyName -Name $Field
        $Properties[$PropertyName] = $Values[$Field]
    }

    [PSCustomObject]$Properties
}
