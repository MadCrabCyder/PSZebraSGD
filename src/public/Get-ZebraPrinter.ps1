function Get-ZebraPrinter {
    <#
    .SYNOPSIS
        Reads identification and firmware information from a Zebra printer.
    .DESCRIPTION
        Queries four SGD variables in sequence. If a query throws, the command warns,
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
        System.Management.Automation.PSCustomObject. Contains ComputerName, UniqueId, FriendlyName,
        Application and Firmware.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [int]$Port = 9100
    )

    $Fields = @('device.product_name', 'device.unique_id', 'device.friendly_name', 'appl.name', 'appl.link_os_version', 'ip.active_network', 'interface.network.active.mac_addr','odometer.total_label_count')

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

    [PSCustomObject]@{
        ComputerName  = $ComputerName
        ProductName   = $Values['device.product_name']
        UniqueId      = $Values['device.unique_id']
        FriendlyName  = $Values['device.friendly_name']
        Application   = $Values['appl.name']
        Firmware      = $Values['appl.link_os_version']
        ActiveNetwork = $Values['ip.active_network']
        MacAddr       = $Values['interface.network.active.mac_addr']
        LabelsPrinted = $Values['odometer.total_label_count']
    }
}
