#Requires -Version 7
# Backs up every unmanaged solution in each environment listed in config/environments.json:
# a zip per solution under _backups (ready for pac solution import), unpacked beside it a file per component,
# and each canvas app's Power Fx source (Src/*.pa.yaml), so changes show up as readable diffs.
[CmdletBinding()]
param(
    # Keep solutions that are already backed up and only fetch new ones
    [switch]$SkipExisting,
    # Publish all customisations first, so exports include unpublished changes. This publishes everyone's work in progress
    [switch]$Publish,
    [string]$Root = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'

$configDir = Join-Path $Root 'config'
$envFile = Join-Path $configDir 'environments.json'
Test-Json -Path $envFile -SchemaFile (Join-Path $configDir 'environments.schema.json') | Out-Null
$config = Get-Content $envFile -Raw | ConvertFrom-Json

# solution list --json arrived in Power Platform CLI 2
$pacMajor = [int]((pac | Select-String 'Version: (\d+)').Matches[0].Groups[1].Value)
if ($pacMajor -lt 2) { throw "Power Platform CLI 2 or later is needed (this is $pacMajor). Update it with: pac install latest" }

function Invoke-Pac {
    $output = pac @args
    if ($LASTEXITCODE) { throw "pac $($args[0..1] -join ' ') failed:`n$($output -join "`n")" }
    $output
}

# Each canvas app's Power Fx source, the part of a .msapp that belongs in source control
function Expand-CanvasSource([IO.FileInfo]$App) {
    $target = Join-Path $App.DirectoryName "$($App.BaseName)_src"
    $archive = [IO.Compression.ZipFile]::OpenRead($App.FullName)
    try {
        $sources = $archive.Entries | Where-Object { $_.FullName -match '^Src[\\/].+\.pa\.yaml$' }
        if (-not $sources) { Write-Warning "No Src/*.pa.yaml in $($App.Name)"; return }
        foreach ($entry in $sources) {
            $path = Join-Path $target ($entry.FullName -replace '\\', '/')
            New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $path, $true)
        }
    } finally { $archive.Dispose() }
}

foreach ($environment in $config.environments) {
    $name = $environment.name
    $guid = $environment.guid
    Write-Host "Environment $name ($guid)" -ForegroundColor Green
    $folder = Join-Path $Root 'solutions' $name
    $backups = Join-Path $folder '_backups'
    New-Item -ItemType Directory -Force $backups | Out-Null

    if ($Publish) {
        Write-Host 'Publishing all customisations'
        Invoke-Pac solution publish --environment $guid | Out-Null
    }

    $list = (Invoke-Pac solution list --environment $guid --json) -join "`n"
    $solutions = $list.Substring($list.IndexOf('[')) | ConvertFrom-Json
    $solutions | ConvertTo-Json | Set-Content (Join-Path $folder 'solutions.json')

    # Managed solutions belong to someone else's source, and Default can't be exported
    foreach ($solution in $solutions | Where-Object { -not $_.IsManaged -and $_.SolutionUniqueName -ne 'Default' }) {
        $unique = $solution.SolutionUniqueName
        $unpacked = Join-Path $folder $unique
        if ($SkipExisting -and (Test-Path $unpacked)) {
            Write-Host "Skipping $unique (already backed up)"
            continue
        }
        Write-Host "Exporting $unique $($solution.VersionNumber)"
        $zip = Join-Path $backups "$unique.zip"
        try {
            Invoke-Pac solution export --environment $guid --name $unique --path $zip --overwrite | Out-Null
        } catch {
            Write-Warning $_
            continue
        }
        if (Test-Path $unpacked) { Remove-Item $unpacked -Recurse -Force }
        Invoke-Pac solution unpack --zipfile $zip --folder $unpacked --packagetype Unmanaged --allowWrite | Out-Null
        Get-ChildItem $unpacked -Recurse -File -Filter *.msapp | ForEach-Object { Expand-CanvasSource $_ }
    }
}
