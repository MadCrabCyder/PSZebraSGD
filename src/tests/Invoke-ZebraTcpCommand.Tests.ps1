BeforeAll {
    . "$PSScriptRoot/../private/Invoke-ZebraTcpCommand.ps1"
}

Describe 'Invoke-ZebraTcpCommand' {
    It 'requires <_>' -ForEach @('ComputerName', 'Command') {
        $Parameter = (Get-Command Invoke-ZebraTcpCommand).Parameters[$_]
        $Parameter.Attributes.Mandatory | Should -Contain $true
    }

    It 'rejects port <_> during parameter binding' -ForEach @(0, 65536) {
        $Port = $_
        { Invoke-ZebraTcpCommand -ComputerName localhost -Command 'test' -Port $Port } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-ZebraTcpCommand'
    }
}
