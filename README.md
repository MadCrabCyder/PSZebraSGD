# PSZebraSGD

![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PSZebraSGD)
![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PSZebraSGD)
![Pester Tests](https://github.com/MadCrabCyder/PSZebraSGD/actions/workflows/run-tests.yml/badge.svg)

Manage Zebra printers with PowerShell using SGD (Set-Get-Do) commands over TCP (default port 9100). Read printer details and settings, update configuration, and run SGD commands

## Quick start

Use Windows PowerShell 5.1 or PowerShell 7.

### Install from PowerShell Gallery

Install [PSZebraSGD from PowerShell Gallery](https://www.powershellgallery.com/packages/PSZebraSGD) for your user account.

```powershell
Install-Module -Name PSZebraSGD -Scope CurrentUser
```

## Examples

Replace the example addresses with your printers’ addresses.

### Audit a printer

```powershell
Get-ZebraPrinter -ComputerName 192.0.2.10
```

Example output

```text
ComputerName  : 192.0.2.10
ProductName   : GK261
UniqueId      : 18J261900123
FriendlyName  : Warehouse M10
Application   : V60.10.10
Firmware      : 7.1
ActiveNetwork : Internal Wired
MacAddr       : 02:00:00:00:00:01
LabelsPrinted : 100
```

### Set one configuration value

```powershell
Set-ZebraConfiguration -ComputerName 192.0.2.10 -Name 'ezpl.print_method' -Value 'direct thermal' -WhatIf
```

### Set several values on multiple printers

```powershell
$Printers = @(
    '192.0.2.10'
    '192.0.2.11'
    '192.0.2.12'
    '192.0.2.13'
)

$Configuration = [ordered]@{
    'ezpl.media_type'       = 'gap/notch'
    'ezpl.tear_off'          = '2'
    'ezpl.print_width'      = '800'
    'media.printmode'       = 'T'
    'zpl.label_top'         = '40'
    'ezpl.label_length_max' = '39'
}

foreach ($Printer in $Printers) {
    Set-ZebraConfiguration -ComputerName $Printer -Configuration $Configuration -WhatIf
}
```

Both setter examples preview each change with `-WhatIf`. Verify that the settings and values are supported by your
printer model, then remove `-WhatIf` and confirm the changes to apply them. The ordered dictionary keeps settings in
the order shown. If a write fails, earlier settings may already have been applied.

See the [command guide](docs/commands.md) for more examples.

## Development

Build assembles `out/PSZebraSGD/PSZebraSGD.psm1` from private scripts followed by public scripts and generates
`out/PSZebraSGD/PSZebraSGD.psd1` from the source manifest, `src/PSZebraSGD.psd1`. Keep `FunctionsToExport = @()` in
the source manifest and let Build generate the export list.

The source manifest's `ModuleVersion = '0.1.0'` is a placeholder. When you push a release tag such as `v1.0.0`,
GitHub Actions sets `ModuleVersion` to `1.0.0` in the generated manifest and publishes that version to PowerShell Gallery.

To add a command, declare one top-level function in a matching `<FunctionName>.ps1` file under `src/public/` and
rebuild. Keep private helpers in `src/private/`.

`Invoke-Build Clean` removes only the generated `out/PSZebraSGD/` directory. Paths resolve from the selected build
file, so you can run `Invoke-Build Build -File 'C:/path/to/PSZebraSGD/module.build.ps1'` from another working directory.

### Build from source

With InvokeBuild installed, run these commands from the repository root.

```powershell
Invoke-Build Build
Import-Module ./out/PSZebraSGD/PSZebraSGD.psd1
```

### Tests and analysis

Install InvokeBuild and Pester 5 if needed, then run from the repository root:

```powershell
Invoke-Build Test
```

With PSScriptAnalyzer installed, run `Invoke-Build Analyze` to check `src/` and the build script. Warnings and errors fail
the task.

## Status and limitations

After receiving data, the TCP client treats a closed connection or a 250 ms gap between chunks as the end of a reply.
A later chunk can be missed if it arrives after that gap. Avoid concurrent commands to the same printer.

Writes return after sending the command. Read settings back with `Get-ZebraConfiguration` to check that the printer applied them.

## Licence and trademarks

This project is independent of Zebra Technologies and is not endorsed by Zebra. Zebra trademarks remain with their respective
owners. Do not copy Zebra documentation verbatim into this repository.
