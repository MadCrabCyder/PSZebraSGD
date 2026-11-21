BeforeAll {
    . "$PSScriptRoot/../private/Invoke-ZebraTcpCommand.ps1"
    . "$PSScriptRoot/../public/Invoke-ZebraSGD.ps1"
    . "$PSScriptRoot/../public/Get-ZebraConfiguration.ps1"
    . "$PSScriptRoot/../public/Set-ZebraConfiguration.ps1"
    . "$PSScriptRoot/../public/Get-ZebraPrinter.ps1"
}

Describe 'Invoke-ZebraSGD' {
    BeforeEach {
        Mock Invoke-ZebraTcpCommand {
            if (-not $NoResponse) {
                'Office Printer'
            }
        }
    }

    It 'sends getvar on the default port and returns the reply, including under WhatIf' {
        Invoke-ZebraSGD -ComputerName localhost -Operation Get -Name device.friendly_name -WhatIf |
            Should -BeExactly 'Office Printer'

        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 1 -ParameterFilter {
            $Command -ceq '! U1 getvar "device.friendly_name"' -and $ComputerName -eq 'localhost' -and
            $Port -eq 9100 -and $TimeoutMilliseconds -eq 3000 -and -not $NoResponse
        }
    }

    It 'sends <Operation> with a quoted value and requests no response' -ForEach @(
        @{ Operation = 'Set'; Value = 'Office Printer'; Expected = '! U1 setvar "example.name" "Office Printer"' }
        @{ Operation = 'Do'; Value = ''; Expected = '! U1 do "example.name" ""' }
    ) {
        $Parameters = @{
            ComputerName        = 'localhost'
            Operation           = $Operation
            Name                = 'example.name'
            Value               = $Value
            Port                = 9200
            TimeoutMilliseconds = 1250
            Confirm             = $false
        }
        Invoke-ZebraSGD @Parameters | Should -BeNullOrEmpty

        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 1 -ParameterFilter {
            $Command -ceq $Expected -and $NoResponse -and $ComputerName -eq 'localhost' -and
            $Port -eq 9200 -and $TimeoutMilliseconds -eq 1250
        }
    }

    It 'does not send <_> under WhatIf' -ForEach @('Set', 'Do') {
        Invoke-ZebraSGD -ComputerName localhost -Operation $_ -Name example.name -Value 'example' -WhatIf
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 0
    }

    It 'rejects <Case> before sending anything' -ForEach @(
        @{ Case = 'an unknown operation'; Operation = 'Write'; Name = 'example.name'; Value = 'example' }
        @{ Case = 'a malformed name'; Operation = 'Set'; Name = 'two words'; Value = 'example' }
        @{ Case = 'a quoted value'; Operation = 'Set'; Name = 'example.name'; Value = 'a"b' }
        @{ Case = 'a carriage return'; Operation = 'Set'; Name = 'example.name'; Value = "a`rb" }
        @{ Case = 'a line feed'; Operation = 'Set'; Name = 'example.name'; Value = "a`nb" }
    ) {
        {
            Invoke-ZebraSGD -ComputerName localhost -Operation $Operation -Name $Name -Value $Value -Confirm:$false
        } | Should -Throw
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 0
    }
}

Describe 'Configuration commands' {
    BeforeEach {
        Mock Invoke-ZebraTcpCommand { $Command }
    }

    It 'returns a named configuration record for each requested setting in request order' {
        $Records = @(Get-ZebraConfiguration -ComputerName localhost -Name 'device.unique_id', 'appl.name' -Port 9200)

        $Records | Should -HaveCount 2
        $Records.ComputerName | Should -Be @('localhost', 'localhost')
        $Records.Name | Should -Be @('device.unique_id', 'appl.name')
        $Records.Value | Should -BeExactly @('! U1 getvar "device.unique_id"', '! U1 getvar "appl.name"')
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 2 -ParameterFilter { $Port -eq 9200 -and -not $NoResponse }
    }

    It 'sets the requested value on the selected printer and port' {
        Set-ZebraConfiguration -ComputerName localhost -Name device.friendly_name -Value 'West Desk' -Port 9200 -Confirm:$false

        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 1 -ParameterFilter {
            $Command -ceq '! U1 setvar "device.friendly_name" "West Desk"' -and
            $ComputerName -eq 'localhost' -and $Port -eq 9200 -and $NoResponse
        }
    }

    It 'does not send a configuration update under WhatIf' {
        Set-ZebraConfiguration -ComputerName localhost -Name device.friendly_name -Value 'West Desk' -WhatIf
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 0
    }
}

Describe 'Get-ZebraPrinter' {
    It 'warns about an unavailable field and returns the remaining identity data' {
        Mock Write-Warning {}
        Mock Invoke-ZebraTcpCommand {
            switch -CaseSensitive -Exact ($Command) {
                '! U1 getvar "device.product_name"' { 'ZD421' }
                '! U1 getvar "device.unique_id"' { 'unit-123' }
                '! U1 getvar "device.friendly_name"' { throw 'Fixture read failure' }
                '! U1 getvar "appl.name"' { 'Example application' }
                '! U1 getvar "appl.link_os_version"' { '1.2' }
                '! U1 getvar "ip.active_network"' { 'wired' }
                '! U1 getvar "interface.network.active.mac_addr"' { '00:11:22:33:44:55' }
                '! U1 getvar "odometer.total_label_count"' { '12345' }
            }
        }

        $Printer = Get-ZebraPrinter -ComputerName localhost -Port 9200

        $Printer.ComputerName | Should -BeExactly 'localhost'
        $Printer.ProductName | Should -BeExactly 'ZD421'
        $Printer.UniqueId | Should -BeExactly 'unit-123'
        $Printer.PSObject.Properties.Name | Should -Contain 'FriendlyName'
        $Printer.FriendlyName | Should -BeNullOrEmpty
        $Printer.Application | Should -BeExactly 'Example application'
        $Printer.Firmware | Should -BeExactly '1.2'
        $Printer.ActiveNetwork | Should -BeExactly 'wired'
        $Printer.MacAddr | Should -BeExactly '00:11:22:33:44:55'
        $Printer.LabelsPrinted | Should -BeExactly '12345'
        Should -Invoke Write-Warning -Exactly -Times 1
        Should -Invoke Write-Warning -Exactly -Times 1 -ParameterFilter {
            $Message -match 'device\.friendly_name' -and $Message -match 'Fixture read failure'
        }
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 8 -ParameterFilter {
            $ComputerName -eq 'localhost' -and $Port -eq 9200 -and -not $NoResponse
        }
    }
}
