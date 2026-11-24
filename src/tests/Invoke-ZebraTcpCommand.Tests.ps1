BeforeAll {
    . "$PSScriptRoot/../private/Invoke-ZebraTcpCommand.ps1"

    function Start-FakeZebraServer {
        param(
            [object[]]$Chunks = @(),
            [int]$HoldOpenMilliseconds = 0
        )

        $Plan = [PSCustomObject]@{
            Chunks               = @($Chunks)
            HoldOpenMilliseconds = $HoldOpenMilliseconds
        }
        $PlanJson = ConvertTo-Json -InputObject $Plan -Depth 5 -Compress

        $Job = Start-Job -ArgumentList $PlanJson -ScriptBlock {
            param($PlanJson)

            $Plan = ConvertFrom-Json -InputObject $PlanJson
            $Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
            $Listener.Start()

            try {
                Write-Output ([PSCustomObject]@{
                    State = 'Ready'
                    Port  = $Listener.LocalEndpoint.Port
                })

                $Client = $Listener.AcceptTcpClient()
                try {
                    $Stream = $Client.GetStream()
                    $Stream.ReadTimeout = 5000
                    $Buffer = New-Object byte[] 256
                    $Request = New-Object 'System.Collections.Generic.List[byte]'

                    while ($Request.Count -lt 4096) {
                        $BytesRead = $Stream.Read($Buffer, 0, $Buffer.Length)
                        if ($BytesRead -eq 0) {
                            break
                        }

                        for ($Index = 0; $Index -lt $BytesRead; $Index++) {
                            $Request.Add($Buffer[$Index])
                        }

                        if ($Request.Count -ge 2 -and
                            $Request[$Request.Count - 2] -eq 13 -and
                            $Request[$Request.Count - 1] -eq 10) {
                            break
                        }
                    }

                    $RequestBytes = $Request.ToArray()
                    Write-Output ([PSCustomObject]@{
                        State              = 'Received'
                        Command            = [System.Text.Encoding]::ASCII.GetString($RequestBytes)
                        RequestBytesBase64 = [System.Convert]::ToBase64String($RequestBytes)
                    })

                    foreach ($Chunk in @($Plan.Chunks)) {
                        if ($Chunk.DelayMilliseconds -gt 0) {
                            Start-Sleep -Milliseconds $Chunk.DelayMilliseconds
                        }

                        $ResponseBytes = [System.Text.Encoding]::UTF8.GetBytes($Chunk.Text)
                        if ($ResponseBytes.Length -gt 0) {
                            $Stream.Write($ResponseBytes, 0, $ResponseBytes.Length)
                            $Stream.Flush()
                        }
                    }

                    if ($Plan.HoldOpenMilliseconds -gt 0) {
                        Start-Sleep -Milliseconds $Plan.HoldOpenMilliseconds
                    }

                    Write-Output ([PSCustomObject]@{ State = 'Completed' })
                } finally {
                    $Client.Dispose()
                }
            } finally {
                $Listener.Stop()
            }
        }

        $Deadline = [DateTime]::UtcNow.AddSeconds(5)
        $Ready = $null
        do {
            if ($Job.ChildJobs[0].HasMoreData) {
                $Ready = Receive-Job -Job $Job -Keep |
                    Where-Object { $_.State -eq 'Ready' } |
                    Select-Object -First 1
            }

            if ($Ready) {
                return [PSCustomObject]@{
                    Job  = $Job
                    Port = $Ready.Port
                }
            }

            if ($Job.State -ne 'Running') {
                throw 'The fake Zebra TCP server did not start.'
            }

            Start-Sleep -Milliseconds 20
        } while ([DateTime]::UtcNow -lt $Deadline)

        Stop-Job -Job $Job -ErrorAction SilentlyContinue
        Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
        throw 'Timed out waiting for the fake Zebra TCP server to start.'
    }

    function Get-FakeZebraServerOutput {
        param($Server)

        Receive-Job -Job $Server.Job -Keep
    }

    function Wait-FakeZebraServerEvent {
        param(
            $Server,
            [string]$State
        )

        $Deadline = [DateTime]::UtcNow.AddSeconds(2)
        do {
            $Event = Get-FakeZebraServerOutput -Server $Server |
                Where-Object { $_.State -eq $State } |
                Select-Object -First 1

            if ($Event) {
                return $Event
            }

            Start-Sleep -Milliseconds 20
        } while ([DateTime]::UtcNow -lt $Deadline)

        throw "Timed out waiting for fake server event '$State'."
    }
}

Describe 'Invoke-ZebraTcpCommand' {
    AfterEach {
        if ($script:FakeZebraServer) {
            Stop-Job -Job $script:FakeZebraServer.Job -ErrorAction SilentlyContinue
            Remove-Job -Job $script:FakeZebraServer.Job -Force -ErrorAction SilentlyContinue
            $script:FakeZebraServer = $null
        }
    }

    It 'requires <_>' -ForEach @('ComputerName', 'Command') {
        $Parameter = (Get-Command Invoke-ZebraTcpCommand).Parameters[$_]
        $Parameter.Attributes.Mandatory | Should -Contain $true
    }

    It 'rejects port <_> during parameter binding' -ForEach @(0, 65536) {
        $Port = $_
        { Invoke-ZebraTcpCommand -ComputerName localhost -Command 'test' -Port $Port } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-ZebraTcpCommand'
    }

    It 'sends the ASCII command followed by CRLF and returns a closed response' {
        $script:FakeZebraServer = Start-FakeZebraServer -Chunks @(
            [PSCustomObject]@{ Text = 'ready'; DelayMilliseconds = 0 }
        )
        $Parameters = @{
            ComputerName = '127.0.0.1'
            Port         = $script:FakeZebraServer.Port
            Command      = '! U1 getvar "device.unique_id"'
        }

        $Response = Invoke-ZebraTcpCommand @Parameters

        $Response | Should -Be 'ready'

        $ExpectedBytes = [System.Text.Encoding]::ASCII.GetBytes('! U1 getvar "device.unique_id"' + "`r`n")
        $Received = Get-FakeZebraServerOutput -Server $script:FakeZebraServer |
            Where-Object { $_.State -eq 'Received' } |
            Select-Object -First 1
        $Received.RequestBytesBase64 | Should -Be ([System.Convert]::ToBase64String($ExpectedBytes))
    }

    It 'combines response chunks separated by a short delay' {
        $script:FakeZebraServer = Start-FakeZebraServer -Chunks @(
            [PSCustomObject]@{ Text = 'first'; DelayMilliseconds = 0 }
            [PSCustomObject]@{ Text = 'second'; DelayMilliseconds = 100 }
        )
        $Parameters = @{
            ComputerName = '127.0.0.1'
            Port         = $script:FakeZebraServer.Port
            Command      = 'test'
        }

        $Response = Invoke-ZebraTcpCommand @Parameters

        $Response | Should -Be 'firstsecond'
    }

    It 'throws when no first response byte arrives before the response deadline' {
        $script:FakeZebraServer = Start-FakeZebraServer -HoldOpenMilliseconds 1500
        $Parameters = @{
            ComputerName        = '127.0.0.1'
            Port                = $script:FakeZebraServer.Port
            Command             = 'test'
            TimeoutMilliseconds = 500
        }

        {
            Invoke-ZebraTcpCommand @Parameters
        } | Should -Throw
    }

    It 'throws when the peer closes before sending response bytes' {
        $script:FakeZebraServer = Start-FakeZebraServer
        $Parameters = @{
            ComputerName = '127.0.0.1'
            Port         = $script:FakeZebraServer.Port
            Command      = 'test'
        }

        {
            Invoke-ZebraTcpCommand @Parameters
        } | Should -Throw
    }

    It 'returns response bytes when the peer closes after sending them' {
        $script:FakeZebraServer = Start-FakeZebraServer -Chunks @(
            [PSCustomObject]@{ Text = 'closed'; DelayMilliseconds = 0 }
        )
        $Parameters = @{
            ComputerName = '127.0.0.1'
            Port         = $script:FakeZebraServer.Port
            Command      = 'test'
        }

        $Response = Invoke-ZebraTcpCommand @Parameters

        $Response | Should -Be 'closed'
    }

    It 'uses a quiet interval to complete a response while the peer remains open' {
        $script:FakeZebraServer = Start-FakeZebraServer -Chunks @(
            [PSCustomObject]@{ Text = 'quiet'; DelayMilliseconds = 0 }
        ) -HoldOpenMilliseconds 1000
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()
        $Parameters = @{
            ComputerName       = '127.0.0.1'
            Port               = $script:FakeZebraServer.Port
            Command            = 'test'
            TimeoutMilliseconds = 2000
        }

        $Response = Invoke-ZebraTcpCommand @Parameters

        $Timer.Stop()
        $Response | Should -Be 'quiet'
        $Timer.ElapsedMilliseconds | Should -BeGreaterThan 150
        $Timer.ElapsedMilliseconds | Should -BeLessThan 1500
    }

    It 'throws when the total response deadline expires before a trickled reply becomes quiet' {
        $script:FakeZebraServer = Start-FakeZebraServer -Chunks @(
            [PSCustomObject]@{ Text = 'first'; DelayMilliseconds = 0 }
            [PSCustomObject]@{ Text = 'second'; DelayMilliseconds = 200 }
        ) -HoldOpenMilliseconds 1000
        $Parameters = @{
            ComputerName       = '127.0.0.1'
            Port               = $script:FakeZebraServer.Port
            Command            = 'test'
            TimeoutMilliseconds = 400
        }

        {
            Invoke-ZebraTcpCommand @Parameters
        } | Should -Throw
    }

    It 'rejects a response larger than MaxResponseBytes' {
        $script:FakeZebraServer = Start-FakeZebraServer -Chunks @(
            [PSCustomObject]@{ Text = 'oversized'; DelayMilliseconds = 0 }
        )
        $Parameters = @{
            ComputerName     = '127.0.0.1'
            Port             = $script:FakeZebraServer.Port
            Command          = 'test'
            MaxResponseBytes = 3
        }

        {
            Invoke-ZebraTcpCommand @Parameters
        } | Should -Throw
    }

    It 'returns after writing NoResponse without waiting for a reply' {
        $script:FakeZebraServer = Start-FakeZebraServer -HoldOpenMilliseconds 2000
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()
        $Parameters = @{
            ComputerName       = '127.0.0.1'
            Port               = $script:FakeZebraServer.Port
            Command            = 'test'
            TimeoutMilliseconds = 1000
            NoResponse         = $true
        }

        $Output = @(Invoke-ZebraTcpCommand @Parameters)

        $Timer.Stop()
        $Output | Should -BeNullOrEmpty
        $Timer.ElapsedMilliseconds | Should -BeLessThan 750

        $Received = Wait-FakeZebraServerEvent -Server $script:FakeZebraServer -State 'Received'
        $Received.Command | Should -Be "test`r`n"
    }
}
