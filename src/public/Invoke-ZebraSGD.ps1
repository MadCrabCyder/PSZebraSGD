function Invoke-ZebraSGD {
    <#
    .SYNOPSIS
        Sends a Get, Set or Do SGD command to a Zebra printer.
    .DESCRIPTION
        Get reads the reply, even under WhatIf. Set and Do support confirmation and WhatIf.
        Neither waits for a reply or verifies printer acceptance.
    .PARAMETER ComputerName
        Printer hostname or IP address.
    .PARAMETER Operation
        Get reads a variable, Set writes a variable and Do requests an action.
    .PARAMETER Name
        SGD variable or action name, such as device.friendly_name.
    .PARAMETER Value
        Argument for Set or Do. Defaults to an empty string. Double quotes, carriage returns and
        line feeds are rejected for all operations, even though Get does not send a value.
    .PARAMETER Port
        Printer TCP port. Defaults to 9100.
    .PARAMETER TimeoutMilliseconds
        Timeout for connecting and for individual socket operations. Defaults to 3000 milliseconds.
    .EXAMPLE
        Invoke-ZebraSGD -ComputerName 192.0.2.10 -Operation Get -Name device.friendly_name
    .INPUTS
        None.
    .OUTPUTS
        System.String. Get returns the trimmed reply. Set and Do return no output.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Set', 'Do')]
        [string]$Operation,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z][a-zA-Z0-9_.-]*$')]
        [string]$Name,

        [string]$Value = '',

        [int]$Port = 9100,

        [int]$TimeoutMilliseconds = 3000
    )

    if ($Value.Contains('"') -or $Value.Contains("`r") -or $Value.Contains("`n")) {
        throw 'Value contains unsupported quote or newline characters.'
    }

    $Command = switch ($Operation) {
        'Get' {
            '! U1 getvar "{0}"' -f $Name
        }
        'Set' {
            '! U1 setvar "{0}" "{1}"' -f $Name, $Value
        }
        'Do' {
            '! U1 do "{0}" "{1}"' -f $Name, $Value
        }
    }

    $TcpParameters = @{
        ComputerName        = $ComputerName
        Command             = $Command
        Port                = $Port
        TimeoutMilliseconds = $TimeoutMilliseconds
    }

    if ($Operation -eq 'Get') {
        return Invoke-ZebraTcpCommand @TcpParameters
    }

    if ($PSCmdlet.ShouldProcess($ComputerName, "$Operation SGD $Name")) {
        Invoke-ZebraTcpCommand @TcpParameters -NoResponse
    }
}
