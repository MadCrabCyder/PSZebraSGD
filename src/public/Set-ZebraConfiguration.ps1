function Set-ZebraConfiguration {
    <#
    .SYNOPSIS
        Writes one or more SGD settings to a Zebra printer.

    .DESCRIPTION
        Sends each setvar command after confirmation without waiting for a reply. Configuration
        entries are sent sequentially; if a write fails, earlier settings may already be applied.
        A successful write does not confirm that the printer accepted the value.

    .PARAMETER ComputerName
        Printer hostname or IP address.

    .PARAMETER Name
        SGD variable to set when using the NameValue parameter set.

    .PARAMETER Value
        Setting value when using the NameValue parameter set. Double quotes, carriage returns
        and line feeds are unsupported.

    .PARAMETER Configuration
        Hashtable of SGD variable names and values to set sequentially. Use an ordered hashtable
        when the setting order matters. Double quotes, carriage returns and line feeds are
        unsupported.

    .PARAMETER Port
        Printer TCP port. Defaults to 9100.

    .EXAMPLE
        Set-ZebraConfiguration -ComputerName 192.0.2.10 -Name device.friendly_name -Value 'West Desk' -WhatIf

    .EXAMPLE
        $Configuration = [ordered]@{
            'ezpl.media_type' = 'gap/notch'
            'ezpl.tear_off'   = '2'
        }
        Set-ZebraConfiguration -ComputerName 192.0.2.10 -Configuration $Configuration -WhatIf

    .INPUTS
        None.

    .OUTPUTS
        None.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'NameValue')]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory, ParameterSetName = 'NameValue')]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'NameValue')]
        [string]$Value,

        [Parameter(Mandatory, ParameterSetName = 'Configuration')]
        [System.Collections.IDictionary]$Configuration,

        [int]$Port = 9100
    )

    if ($PSCmdlet.ParameterSetName -eq 'NameValue') {
        $Settings = @{ $Name = $Value }
    } else {
        if ($Configuration.Count -eq 0) {
            throw 'Configuration must contain at least one SGD setting.'
        }

        $Settings = $Configuration
    }

    foreach ($SettingName in $Settings.Keys) {
        $SettingValue = $Settings[$SettingName]
        if ($PSCmdlet.ShouldProcess($ComputerName, "Set SGD $SettingName")) {
            $SetParameters = @{
                ComputerName = $ComputerName
                Operation    = 'Set'
                Name         = $SettingName
                Value        = $SettingValue
                Port         = $Port
                Confirm      = $false
            }

            Invoke-ZebraSGD @SetParameters
        }
    }
}
