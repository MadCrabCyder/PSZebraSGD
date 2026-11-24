function Invoke-ZebraTcpCommand {
    <#
    .SYNOPSIS
        Sends one command over a new TCP connection.

    .DESCRIPTION
        Encodes the command as ASCII with a trailing CRLF. Unless NoResponse is set,
        collects response bytes until the peer closes or the stream is quiet for 250 milliseconds.
        Quiet-gap completion is a best-effort heuristic, not a universal SGD response terminator;
        verify response timing against supported printers before relying on it in production.
        The total response deadline is TimeoutMilliseconds after the command is written.
        Decodes the received bytes as UTF-8 and trims leading and trailing whitespace.

    .PARAMETER ComputerName
        Printer hostname or IP address.

    .PARAMETER Command
        Command text without its terminating CRLF.

    .PARAMETER Port
        TCP port from 1 through 65535. Defaults to 9100.

    .PARAMETER TimeoutMilliseconds
        Connect and send timeout, and total response deadline in milliseconds, from 100 through
        60000. Defaults to 3000.

    .PARAMETER MaxResponseBytes
        Largest accepted reply in bytes, from 1 through 1048576. Defaults to 65536.
        Reading more than this limit raises an error.

    .PARAMETER NoResponse
        Returns after the write without reading a reply or confirming acceptance.

    .EXAMPLE
        Invoke-ZebraTcpCommand -ComputerName 192.0.2.10 -Command '! U1 getvar "device.unique_id"'

    .INPUTS
        None.

    .OUTPUTS
        System.String. Returns the trimmed reply unless NoResponse is set, in which case there is
        no output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string]$Command,

        [ValidateRange(1, 65535)]
        [int]$Port = 9100,

        [ValidateRange(100, 60000)]
        [int]$TimeoutMilliseconds = 3000,

        [ValidateRange(1, 1048576)]
        [int]$MaxResponseBytes = 65536,

        [switch]$NoResponse
    )

    $Client = [System.Net.Sockets.TcpClient]::new()

    try {
        $ConnectTask = $Client.ConnectAsync($ComputerName, $Port)
        if (-not $ConnectTask.Wait($TimeoutMilliseconds)) {
            throw "Connection timed out: ${ComputerName}:$Port"
        }

        $Client.SendTimeout = $TimeoutMilliseconds
        $Client.ReceiveTimeout = $TimeoutMilliseconds
        $Stream = $Client.GetStream()
        $Payload = [System.Text.Encoding]::ASCII.GetBytes($Command + "`r`n")
        $Stream.Write($Payload, 0, $Payload.Length)

        if ($NoResponse) {
            return
        }

        $ResponseTimeoutMilliseconds = 250
        $ResponseTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $Buffer = [byte[]]::new(4096)
        $Response = [System.IO.MemoryStream]::new()

        try {
            while ($true) {
                $RemainingMilliseconds = $TimeoutMilliseconds - $ResponseTimer.ElapsedMilliseconds
                if ($RemainingMilliseconds -le 0) {
                    throw 'Timed out waiting for the printer response.'
                }

                $ReadTimeoutMilliseconds = $RemainingMilliseconds
                if ($Response.Length -gt 0) {
                    $ReadTimeoutMilliseconds = [Math]::Min(
                        $ResponseTimeoutMilliseconds,
                        $RemainingMilliseconds
                    )
                }
                $Stream.ReadTimeout = [int][Math]::Max(1, $ReadTimeoutMilliseconds)

                try {
                    $BytesRead = $Stream.Read($Buffer, 0, $Buffer.Length)
                } catch [System.IO.IOException] {
                    $SocketException = $_.Exception.InnerException
                    $IsReadTimeout = $SocketException -is [System.Net.Sockets.SocketException] -and
                        $SocketException.SocketErrorCode -eq [System.Net.Sockets.SocketError]::TimedOut

                    if (-not $IsReadTimeout) {
                        throw
                    }

                    if ($Response.Length -eq 0 -or
                        $ResponseTimer.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
                        throw 'Timed out waiting for the printer response.'
                    }

                    break
                }

                if ($ResponseTimer.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
                    throw 'Timed out waiting for the printer response.'
                }

                if ($BytesRead -eq 0) {
                    if ($Response.Length -eq 0) {
                        throw 'The printer closed the connection without a response.'
                    }

                    break
                }

                if ($Response.Length + $BytesRead -gt $MaxResponseBytes) {
                    throw 'Response exceeds MaxResponseBytes.'
                }
                $Response.Write($Buffer, 0, $BytesRead)
            }

            return [System.Text.Encoding]::UTF8.GetString($Response.ToArray()).Trim()
        } finally {
            $Response.Dispose()
        }
    } finally {
        $Client.Dispose()
    }
}
