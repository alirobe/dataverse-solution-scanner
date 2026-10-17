#Requires -Version 7
# Runs backup-solutions.ps1 end to end against a stand-in pac, so changes can be checked without a Dataverse environment.
# pwsh tests/smoke.ps1
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..' 'backup-solutions.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) "dss-smoke-$PID"
New-Item -ItemType Directory -Force (Join-Path $work 'config') | Out-Null
Copy-Item (Join-Path $PSScriptRoot '..' 'config' 'environments.schema.json') (Join-Path $work 'config')
@{ environments = @(@{ name = 'Dev'; guid = '00000000-0000-0000-0000-000000000001'; securityScan = @{ exemptions = @{ 'potential-secret' = @(''); 'external-url' = @('') } } }) } |
    ConvertTo-Json -Depth 6 | Set-Content (Join-Path $work 'config' 'environments.json')

$global:pacVersion = '2.13.1'
$global:pacCalls = [Collections.Generic.List[string]]::new()
function global:pac {
    $a = [string[]]$args
    $value = { param($flag) $a[[array]::IndexOf($a, $flag) + 1] }
    $global:pacCalls.Add($a -join ' ')
    $global:LASTEXITCODE = 0
    switch ($a[0..1] -join ' ') {
        '' { 'Microsoft PowerPlatform CLI'; "Version: $global:pacVersion+smoke" }
        'solution list' {
            'Connected to Dev'
            '[{"SolutionUniqueName":"Core","FriendlyName":"Core","VersionNumber":"1.0.0.3","IsManaged":false},
              {"SolutionUniqueName":"Vendor","FriendlyName":"Vendor","VersionNumber":"2.0","IsManaged":true},
              {"SolutionUniqueName":"Default","FriendlyName":"Default Solution","VersionNumber":"1.0","IsManaged":false},
              {"SolutionUniqueName":"Broken","FriendlyName":"Broken","VersionNumber":"1.0","IsManaged":false}]'
        }
        'solution export' {
            if ((& $value '--name') -eq 'Broken') { $global:LASTEXITCODE = 1; 'Error: export failed'; return }
            Set-Content (Join-Path $work 'stub.txt') 'zip'
            Compress-Archive (Join-Path $work 'stub.txt') (& $value '--path') -Force
        }
        'solution unpack' {
            $folder = & $value '--folder'
            New-Item -ItemType Directory -Force (Join-Path $folder 'Other'), (Join-Path $folder 'CanvasApps') | Out-Null
            Set-Content (Join-Path $folder 'Other' 'Solution.xml') '<ImportExportXml />'
            $app = Join-Path $work 'app'
            New-Item -ItemType Directory -Force (Join-Path $app 'Src') | Out-Null
            Set-Content (Join-Path $app 'Src' 'App.pa.yaml') 'App:'
            Set-Content (Join-Path $app 'Header.json') '{}'
            [IO.Compression.ZipFile]::CreateFromDirectory($app, (Join-Path $folder 'CanvasApps' 'core_app.msapp'))
            Remove-Item $app -Recurse
        }
    }
}

$failed = 0
function Check([string]$name, [bool]$ok) {
    Write-Host ("{0}  {1}" -f ($ok ? 'pass' : 'FAIL'), $name)
    if (-not $ok) { $script:failed++ }
}
$dev = Join-Path $work 'solutions' 'Dev'
try {
    & $script -Root $work -WarningVariable warnings -WarningAction SilentlyContinue
    Check 'saves the solution list' (Test-Path (Join-Path $dev 'solutions.json'))
    Check 'keeps the zip for import' (Test-Path (Join-Path $dev '_backups' 'Core.zip'))
    Check 'unpacks a file per component' (Test-Path (Join-Path $dev 'Core' 'Other' 'Solution.xml'))
    Check 'extracts canvas app source' (Test-Path (Join-Path $dev 'Core' 'CanvasApps' 'core_app_src' 'Src' 'App.pa.yaml'))
    Check 'skips managed and Default' (-not (Test-Path (Join-Path $dev 'Vendor')) -and -not (Test-Path (Join-Path $dev 'Default')))
    Check 'warns on a failed export and carries on' (($warnings -join ' ') -match 'export' -and -not (Test-Path (Join-Path $dev 'Broken')))

    $global:pacCalls.Clear()
    & $script -Root $work -SkipExisting -Publish -WarningAction SilentlyContinue
    Check '-SkipExisting leaves existing solutions' (-not ($global:pacCalls -match 'export --environment \S+ --name Core'))
    Check '-Publish publishes first' ($global:pacCalls[1] -like 'solution publish*')

    $global:pacVersion = '1.40.4'
    $threw = $false
    try { & $script -Root $work } catch { $threw = $_ -match 'pac install latest' }
    Check 'stops on Power Platform CLI 1' $threw
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item function:global:pac
}
Write-Host "$failed failed"
exit $failed
