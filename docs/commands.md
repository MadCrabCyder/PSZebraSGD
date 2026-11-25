# Commands

| Function | Description |
|---|---|
| `Get-ZebraPrinter` | Queries a few common identification variables. |
| `Get-ZebraConfiguration` | Reads one or more SGD variables into one object with converted property names. |
| `Set-ZebraConfiguration` | Writes one or more SGD variables (supports per-setting `-WhatIf` and confirmation). |
| `Invoke-ZebraSGD` | Reads or writes an SGD variable or requests a printer action. |

## Examples

Load the module as shown in the [quick start](../README.md#quick-start). Replace `192.0.2.10` with your printer's address. Use `-Port` if the printer listens on a port other than TCP 9100.

### Audit a printer and read configuration

Use `Get-ZebraPrinter` for the standard audit fields, `Get-ZebraConfiguration` for a group of settings, and `Invoke-ZebraSGD -Operation Get` for a single raw reply.

```powershell
Get-ZebraPrinter -ComputerName 192.0.2.10

$SGDVariables = @(
    'ezpl.media_type'
    'ezpl.tear_off'
    'media.printmode'
)

$Settings = Get-ZebraConfiguration -ComputerName 192.0.2.10 -Name $SGDVariables
$Settings.MediaType

Invoke-ZebraSGD -ComputerName 192.0.2.10 -Operation Get -Name 'device.friendly_name'
```

`Get-ZebraConfiguration` returns one object with `ComputerName` and a property for each requested variable, such as `MediaType` for `ezpl.media_type`. If a read fails, it warns, leaves that property null, and continues reading the other settings.

### Preview configuration changes

Pass `-Name` and `-Value` for one change or `-Configuration` for a group. Each setting has its own confirmation and `-WhatIf` check.

```powershell
Set-ZebraConfiguration -ComputerName 192.0.2.10 -Name device.friendly_name -Value 'Warehouse 01' -WhatIf

$Configuration = [ordered]@{
    'ezpl.media_type' = 'gap/notch'
    'ezpl.tear_off'   = '2'
    'media.printmode' = 'T'
}

Set-ZebraConfiguration -ComputerName 192.0.2.10 -Configuration $Configuration -WhatIf
```

Use `[ordered]@{}` when writes must run in the order shown. A later failure can leave earlier changes applied. After checking the preview and model support, remove `-WhatIf`, confirm the changes, and read the settings back with `Get-ZebraConfiguration`.

### Calibrate the loaded media

Load the intended label stock before using `zpl.calibrate`. On supported models, this action measures the loaded media and updates `zpl.label_length`. [Zebra programming guide](https://www.zebra.com/content/dam/support-dam/en/documentation/unrestricted/guide/software/zpl-zbi2-pg-en.pdf#page=1069)

```powershell
Invoke-ZebraSGD -ComputerName 192.0.2.10 -Operation Do -Name 'zpl.calibrate' -WhatIf
```

After running the action and waiting for calibration to finish, read the detected length with `Invoke-ZebraSGD -Operation Get -Name 'zpl.label_length' -ComputerName 192.0.2.10`.

### Restart a printer

Use `device.reset` during a maintenance window. The printer may be temporarily unreachable while it restarts. Zebra shows `do` in its [clock-setting example](https://docs.zebra.com/us/en/printers/software/zpl-pg/c-sgd-printer-commands/r-sgd-rtc-time.html), while the [command reference](https://www.zebra.com/content/dam/support-dam/en/documentation/unrestricted/guide/software/zpl-zbi2-pg-en.pdf#page=743) lists `setvar`. Check which form your printer model and firmware support before running the example.

```powershell
Invoke-ZebraSGD -ComputerName 192.0.2.10 -Operation Do -Name 'device.reset' -WhatIf
```

For either `Do` example, the module supplies an empty argument by default. Check model and firmware support, then remove `-WhatIf` and confirm when ready. `Do` sends the command without waiting for a printer reply. After a restart, wait for the printer to come back online before checking it with `Get-ZebraPrinter`.
