$ErrorActionPreference = 'Stop'

Write-Host "PowerShell $($PSVersionTable.PSVersion)"
Write-Host "Edition: $($PSVersionTable.PSEdition)"

# Ensure TLS 1.2 for Windows PowerShell 5.1
if ($PSVersionTable.PSVersion.Major -eq 5) {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12
}

$dependencies = @{
    Pester      = [version]'5.0.0'
    InvokeBuild = [version]'5.14.0'
}

foreach ($name in $dependencies.Keys) {
    $minimumVersion = $dependencies[$name]

    $installed = Get-Module -ListAvailable -Name $name |
        Where-Object { $_.Version -ge $minimumVersion } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $installed) {
        Write-Host "Installing $name >= $minimumVersion"

        $InstallParams = @{
            Name               = $name
            MinimumVersion     = $minimumVersion
            Scope              = 'CurrentUser'
            Repository         = 'PSGallery'
            Force              = $true
            SkipPublisherCheck = $true
            ErrorAction        = 'Stop'
        }

        Install-Module @InstallParams
    }

    Import-Module $name -MinimumVersion $minimumVersion
}

# Run the existing InvokeBuild task
Invoke-Build Test

if (-not $?) {
    exit 1
}
