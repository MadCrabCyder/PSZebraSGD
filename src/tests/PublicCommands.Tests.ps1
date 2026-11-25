BeforeAll {
    . "$PSScriptRoot/../private/Invoke-ZebraTcpCommand.ps1"
    . "$PSScriptRoot/../private/ConvertTo-ZebraPropertyName.ps1"
    . "$PSScriptRoot/../public/Invoke-ZebraSGD.ps1"
    . "$PSScriptRoot/../public/Get-ZebraConfiguration.ps1"
    . "$PSScriptRoot/../public/Set-ZebraConfiguration.ps1"
    . "$PSScriptRoot/../public/Get-ZebraPrinter.ps1"
}

Describe 'ConvertTo-ZebraPropertyName' {
    It 'converts the final dot-separated segment to PascalCase' -ForEach @(
        @{ Name = 'interface.network.active.mac_addr'; Expected = 'MacAddr' }
        @{ Name = 'device.product_name'; Expected = 'ProductName' }
    ) {
        ConvertTo-ZebraPropertyName -Name $Name | Should -BeExactly $Expected
    }

    It 'uses the known property alias <Name>' -ForEach @(
        @{ Name = 'appl.name'; Expected = 'Application' }
        @{ Name = 'appl.link_os_version'; Expected = 'Firmware' }
        @{ Name = 'odometer.total_label_count'; Expected = 'LabelsPrinted' }
        @{ Name = 'wlan.mac_addr'; Expected = 'WlanMacAddr' }
    ) {
        ConvertTo-ZebraPropertyName -Name $Name | Should -BeExactly $Expected
    }

    It 'matches aliases without regard to case' {
        ConvertTo-ZebraPropertyName -Name 'WLAN.MAC_ADDR' | Should -BeExactly 'WlanMacAddr'
    }

    It 'rejects null or empty input' -ForEach @(
        @{ Name = $null }
        @{ Name = '' }
    ) {
        { ConvertTo-ZebraPropertyName -Name $Name } | Should -Throw
    }
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
        $script:RequestedCommands = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-ZebraTcpCommand {
            $script:RequestedCommands.Add($Command)
            $Command
        }
    }

    It 'accepts an array of names and returns one ordered object with named values' {
        $SGDVariables = @(
            'device.product_name'
            'device.unique_id'
            'device.friendly_name'
            'appl.name'
            'appl.link_os_version'
            'ip.active_network'
            'interface.network.active.mac_addr'
            'ezpl.media_type'
            'ezpl.tear_off'
            'ezpl.print_width'
            'media.printmode'
            'zpl.label_top'
            'ezpl.label_length_max'
            'zpl.left_position'
        )

        $Result = @(Get-ZebraConfiguration -ComputerName localhost -Name $SGDVariables -Port 9200)

        (Get-Command Get-ZebraConfiguration).Parameters['Name'].ParameterType | Should -Be ([string[]])
        $Result | Should -HaveCount 1
        $Result[0] | Should -BeOfType ([PSCustomObject])
        $Result[0].PSObject.Properties.Name | Should -Be @(
            'ComputerName'
            'ProductName'
            'UniqueId'
            'FriendlyName'
            'Application'
            'Firmware'
            'ActiveNetwork'
            'MacAddr'
            'MediaType'
            'TearOff'
            'PrintWidth'
            'Printmode'
            'LabelTop'
            'LabelLengthMax'
            'LeftPosition'
        )
        $Result[0].ComputerName | Should -BeExactly 'localhost'
        $Result[0].ProductName | Should -BeExactly '! U1 getvar "device.product_name"'
        $Result[0].Application | Should -BeExactly '! U1 getvar "appl.name"'
        $Result[0].MacAddr | Should -BeExactly '! U1 getvar "interface.network.active.mac_addr"'
        $Result[0].Printmode | Should -BeExactly '! U1 getvar "media.printmode"'
        foreach ($Variable in $SGDVariables) {
            $PropertyName = ConvertTo-ZebraPropertyName -Name $Variable
            $ExpectedValue = '! U1 getvar "{0}"' -f $Variable
            $Result[0].PSObject.Properties[$PropertyName].Value | Should -BeExactly $ExpectedValue
        }
        $script:RequestedCommands | Should -Be @(
            '! U1 getvar "device.product_name"'
            '! U1 getvar "device.unique_id"'
            '! U1 getvar "device.friendly_name"'
            '! U1 getvar "appl.name"'
            '! U1 getvar "appl.link_os_version"'
            '! U1 getvar "ip.active_network"'
            '! U1 getvar "interface.network.active.mac_addr"'
            '! U1 getvar "ezpl.media_type"'
            '! U1 getvar "ezpl.tear_off"'
            '! U1 getvar "ezpl.print_width"'
            '! U1 getvar "media.printmode"'
            '! U1 getvar "zpl.label_top"'
            '! U1 getvar "ezpl.label_length_max"'
            '! U1 getvar "zpl.left_position"'
        )
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 14 -ParameterFilter {
            $ComputerName -eq 'localhost' -and $Port -eq 9200 -and -not $NoResponse
        }
    }

    It 'returns one composite object for a single requested name' {
        $Result = @(Get-ZebraConfiguration -ComputerName localhost -Name 'device.unique_id')

        $Result | Should -HaveCount 1
        $Result[0].PSObject.Properties.Name | Should -Be @('ComputerName', 'UniqueId')
        $Result[0].UniqueId | Should -BeExactly '! U1 getvar "device.unique_id"'
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 1 -ParameterFilter {
            $Command -ceq '! U1 getvar "device.unique_id"' -and $Port -eq 9100
        }
    }

    It 'warns and leaves a failed field null while continuing with later fields' {
        Mock Write-Warning {}
        Mock Invoke-ZebraTcpCommand {
            $script:RequestedCommands.Add($Command)
            throw 'Fixture read failure'
        } -ParameterFilter {
            $Command -ceq '! U1 getvar "device.unique_id"'
        }

        $Result = Get-ZebraConfiguration -ComputerName localhost -Name 'device.unique_id', 'appl.name'

        $Result.UniqueId | Should -BeNullOrEmpty
        $Result.Application | Should -BeExactly '! U1 getvar "appl.name"'
        Should -Invoke Write-Warning -Exactly -Times 1 -ParameterFilter {
            $Message -match 'device\.unique_id' -and $Message -match 'Fixture read failure'
        }
        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 2
        $script:RequestedCommands | Should -Be @(
            '! U1 getvar "device.unique_id"'
            '! U1 getvar "appl.name"'
        )
    }

    It 'rejects empty names before sending any commands' {
        { Get-ZebraConfiguration -ComputerName localhost -Name @() } | Should -Throw

        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 0
    }

    It 'rejects duplicate output property names before sending commands' -ForEach @(
        @{ Names = @('device.unique_id', 'device.unique_id') }
        @{ Names = @('interface.network.active.mac_addr', 'other.mac_addr') }
        @{ Names = @('odometer.total_label_count', 'device.labelsprinted') }
        @{ Names = @('device.computer_name') }
    ) {
        { Get-ZebraConfiguration -ComputerName localhost -Name $Names } | Should -Throw

        Should -Invoke Invoke-ZebraTcpCommand -Exactly -Times 0
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
        $Printer.PSObject.Properties.Name | Should -Be @(
            'ComputerName'
            'ProductName'
            'UniqueId'
            'FriendlyName'
            'Application'
            'Firmware'
            'ActiveNetwork'
            'MacAddr'
            'LabelsPrinted'
        )
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
