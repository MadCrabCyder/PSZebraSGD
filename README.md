# PSZebraSGD

PowerShell module for Zebra SGD (Set-Get-Do) over TCP/9100.

## Quick start

From the repository root, build and import the module in Windows PowerShell 5.1 or PowerShell 7 with InvokeBuild installed:

```powershell
Invoke-Build Build
Import-Module ./out/PSZebraSGD/PSZebraSGD.psd1
```

Build assembles `out/PSZebraSGD/PSZebraSGD.psm1` from sorted private scripts followed by sorted public scripts. It uses `src/PSZebraSGD.psd1` as the manifest template, preserving its metadata and replacing only `FunctionsToExport` in the generated manifest. Keep `FunctionsToExport = @()` in the source manifest.

To add a command, declare exactly one ordinary top-level function in a matching `<FunctionName>.ps1` file under `src/public/` and rebuild. Keep private helpers in `src/private/`. Build validates source syntax and public declarations before replacing an existing package; invalid source leaves the previous package intact. Both generated files use UTF-8 with BOM for Windows PowerShell 5.1 compatibility.

`Invoke-Build Clean` removes only the generated `out/PSZebraSGD/` directory. Other files and directories under `out/` are preserved.

Paths resolve from the selected build file. From another working directory, use `Invoke-Build Build -File 'C:/path/to/PSZebraSGD/module.build.ps1'`.

Replace `192.0.2.10` with your printer's address. The last command previews the change.

```powershell
Get-ZebraPrinter -ComputerName 192.0.2.10
Invoke-ZebraSGD -ComputerName 192.0.2.10 -Operation Get -Name device.unique_id
Set-ZebraConfiguration -ComputerName 192.0.2.10 -Name device.friendly_name -Value 'Warehouse 01' -WhatIf
```

## Tests

Install InvokeBuild and Pester 5 if needed, then run from the repository root:

```powershell
Invoke-Build Test
```

## Status and limitations

The TCP client can truncate replies that arrive in multiple parts if the next part is delayed. A write request returning without error does **not** prove the printer accepted it. Avoid concurrent commands against the same printer until transport behaviour is verified.

## Licence and trademarks

This project is independent of Zebra Technologies and is not endorsed by Zebra. Zebra trademarks remain with their respective owners. Do not copy Zebra documentation verbatim into this repository.
