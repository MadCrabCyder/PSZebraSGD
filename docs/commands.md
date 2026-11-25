# Commands

| Function | Description |
|---|---|
| `Get-ZebraPrinter` | Queries a few common identification variables. |
| `Get-ZebraConfiguration` | Reads one or more SGD variables into one object with converted property names. |
| `Set-ZebraConfiguration` | Writes one SGD variable (supports `-WhatIf`). |
| `Invoke-ZebraSGD` | Generic get/set/do transport wrapper. |

## Examples

Load the functions as shown in the [quick start](../README.md#quick-start) and replace `192.0.2.10` with your printer's address.

```powershell
Get-ZebraPrinter -ComputerName 192.0.2.10
$SGDVariables = @(
    'device.product_name'
    'device.unique_id'
    'appl.name'
)
Get-ZebraConfiguration -ComputerName 192.0.2.10 -Name $SGDVariables
Set-ZebraConfiguration -ComputerName 192.0.2.10 -Name device.friendly_name -Value 'Warehouse 01' -WhatIf
```

`Get-ZebraConfiguration` returns one object with `ComputerName` and one property per requested variable. Property names are generated from the SGD names, with aliases for known names such as `appl.name` → `Application`.

**Caution:** SGD `setvar` and `do` commands can alter device operation. Verify the command's permissions and model support before applying it. `Invoke-ZebraSGD` does not yet validate against the catalogue.
