using namespace System.Management.Automation.Language

$ModuleName = 'PSZebraSGD'
$OutRoot = Join-Path $BuildRoot 'out'
$OutDir = Join-Path $OutRoot $ModuleName
$SrcDir = Join-Path $BuildRoot 'src'

$SrcManifest = Join-Path $SrcDir "$ModuleName.psd1"
$OutManifest = Join-Path $OutDir "$ModuleName.psd1"
$OutModule = Join-Path $OutDir "$ModuleName.psm1"

task Clean {

    if (Test-Path -LiteralPath $OutDir -ErrorAction Stop) {
        Remove-Item -LiteralPath $OutDir -Recurse -Force -ErrorAction Stop
    }
}

task Build Clean, {

    New-Item -ItemType Directory -Path $Outdir -ErrorAction Ignore | Out-Null
    Copy-Item $SrcManifest $OutManifest

    # Concatenate *.ps1 files from src\public and src\private to .psm1 file
    $functionFiles = @(
        Get-ChildItem (Join-Path $SrcDir 'private\*.ps1') -ErrorAction Ignore
        Get-ChildItem (Join-Path $SrcDir 'public\*.ps1') -ErrorAction Ignore
    )
    $moduleContent = ($functionFiles | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
    Set-Content -Path $OutModule -Value $moduleContent

    $publicFunctions = @(Get-ChildItem (Join-Path $SrcDir 'public\*.ps1') -ErrorAction Ignore).BaseName
    Update-ModuleManifest -Path $OutManifest -FunctionsToExport $publicFunctions
}

task Analyze {
    Import-Module PSScriptAnalyzer -ErrorAction Stop

    $Findings = @(
        Invoke-ScriptAnalyzer -Path $SrcDir -Recurse -Severity Warning, Error -ErrorAction Stop
        # Invoke-Build task declarations intentionally use its DSL alias.
        Invoke-ScriptAnalyzer -Path (Join-Path $BuildRoot 'module.build.ps1') -Severity Warning, Error -ExcludeRule PSAvoidUsingCmdletAliases -ErrorAction Stop
    )
    if ($Findings.Count -gt 0) {
        $Findings
        throw "PSScriptAnalyzer reported $($Findings.Count) warning or error findings."
    }
}

task Test {

    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

    $resultsPath = Join-Path $BuildRoot 'testResults.xml'

    $config = New-PesterConfiguration
    $config.Run.Path = (Join-Path $SrcDir 'tests')
    $config.Run.Throw = $true
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = $resultsPath

    $results = Invoke-Pester -Configuration $config

    if ($results.FailedCount -gt 0) {
        throw "$($results.FailedCount) Pester test(s) failed."
    }
}
