function ConvertTo-ZebraPropertyName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Aliases = @{
        'appl.name'                  = 'Application'
        'appl.link_os_version'       = 'Firmware'
        'odometer.total_label_count' = 'LabelsPrinted'
        'wlan.mac_addr'              = 'WlanMacAddr'
    }

    if ($Aliases.ContainsKey($Name)) {
        return $Aliases[$Name]
    }

    $NamePart = ($Name -split '\.')[-1]
    $PascalCaseParts = foreach ($Word in ($NamePart -split '_')) {
        $Word.Substring(0, 1).ToUpperInvariant() + $Word.Substring(1).ToLowerInvariant()
    }

    return $PascalCaseParts -join ''
}
