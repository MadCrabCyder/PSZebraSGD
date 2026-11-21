function Set-ZebraConfiguration {
    <#
    .SYNOPSIS
        Writes one SGD setting to a Zebra printer.
    .DESCRIPTION
        Sends a setvar command after confirmation without waiting for a reply.
        A successful write does not confirm that the printer accepted the value.
    .PARAMETER ComputerName
        Printer hostname or IP address.
    .PARAMETER Name
        SGD variable to set.
    .PARAMETER Value
        Setting value. Double quotes, carriage returns and line feeds are unsupported.
    .PARAMETER Port
        Printer TCP port. Defaults to 9100.
    .EXAMPLE
        Set-ZebraConfiguration -ComputerName 192.0.2.10 -Name device.friendly_name -Value 'West Desk' -WhatIf
    .INPUTS
        None.
    .OUTPUTS
        None.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [int]$Port = 9100
    )

    if ($PSCmdlet.ShouldProcess($ComputerName, "Set SGD $Name")) {
        $SetParameters = @{
            ComputerName = $ComputerName
            Operation    = 'Set'
            Name         = $Name
            Value        = $Value
            Port         = $Port
            Confirm      = $false
        }

        Invoke-ZebraSGD @SetParameters
    }
}
