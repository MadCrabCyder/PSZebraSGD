@{
 RootModule = 'PSZebraSGD.psm1'
 ModuleVersion = '0.1.0'
 GUID = 'b5c18c4b-9e93-4a6f-9407-85d7dbf7c163'
 Author = 'Mad Crab Cyder'
 CompanyName = 'Mad Crab Cyder Productions'
 Description = @'
A PowerShell module for managing and automating Zebra printers using SGD (Set-Get-Do) commands over TCP port 9100. Query
printer information and device status, retrieve and modify configuration settings, execute printer commands, and streamline
printer administration, monitoring, and inventory management.
'@
 PowerShellVersion = '5.1'
 FunctionsToExport = @()
 CmdletsToExport = @()
 VariablesToExport = @()
 AliasesToExport = @()

 PrivateData = @{
    PSData = @{
        Tags = @('Zebra', 'ZebraPrinter', 'SGD', 'SetGetDo', 'Printer')
        LicenseUri = 'https://github.com/MadCrabCyder/PSZebraSGD/blob/main/LICENSE'
        ProjectUri = 'https://github.com/MadCrabCyder/PSZebraSGD'
    }
 }
}
