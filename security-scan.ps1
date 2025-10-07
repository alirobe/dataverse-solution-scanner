$ErrorActionPreference = "Stop"
$SolutionsRoot = ".\solutions"
$OutputDir = ".\output"
$ConfigDir = ".\config"

# Manage Settings
$EnvFile = Join-Path $ConfigDir "environments.json"
$EnvSchema = Join-Path $ConfigDir "environments.schema.json"
Test-Json -Path $EnvFile -SchemaFile $EnvSchema -ErrorAction Stop | Out-Null
$environmentsConfig = Get-Content -Path $EnvFile -Raw | ConvertFrom-Json 

$SettingsFile = Join-Path $ConfigDir "security-scan.json"
$settingsSchema = Join-Path $ConfigDir "security-scan.schema.json"
Test-Json -Path $SettingsFile -SchemaFile $settingsSchema -ErrorAction Stop | Out-Null
$settingsConfig = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json

$outDir = Join-Path (Get-Location).Path $OutputDir
$includeExt = $settingsConfig.filetypes

foreach ($envObj in $environmentsConfig.environments) {
    $env = $envObj.name
    $envExemptions = $envObj.securityScan.exemptions
    $envOut = Join-Path $outDir $env
    $solutions = Get-ChildItem -Path ($SolutionsRoot + "\" + $env) -Directory
    Write-Host "Processing environment '$env', Scanning $($solutions.Count) solutions ..."
    $findings = @()
    
    foreach ($dir in $solutions) {
        # Write-Host "Scanning solution directory: $dir" -ForegroundColor Cyan
        $files = Get-ChildItem -Path $dir.FullName -Recurse -File | Where-Object { $includeExt -contains $_.Extension }
        
        foreach ($file in $files) {
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
            # Write-Host $envExemptions.files
            foreach($exemptFile in $envExemptions.files) {
                $fileRegex = [regex]::new($exemptFile)
                # Write-Host "Checking file: $($file.FullName) against pattern: $exemptFile"
                if ($fileRegex.isMatch($file.FullName)) {
                    $content = $false 
                    # Write-Host "Exempted file: $($file.FullName) by pattern $exemptFile" -ForegroundColor Yellow
                }
            }
            
            if (-not $content) { continue }
            
            foreach ($rule in $settingsConfig.rules) {
                $regex = [regex]::new($rule.pattern)
                $exemptPatterns = @()
                $globalRuleExemptions = $settingsConfig.exemptions.$($rule.id)
                $envRuleExemptions = $envExemptions.$($rule.id)
                if($envRuleExemptions) { $exemptPatterns += $envRuleExemptions }
                if($globalRuleExemptions) { $exemptPatterns += $globalRuleExemptions }
                if ($regex.IsMatch($content)) {
                    $lines = ($content -split "`n")
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i]
                        $regexMatches = $regex.Matches($line)
                        foreach ($m in $regexMatches) {
                            $isExempt = $false
                            foreach ($pat in $exemptPatterns) {
                                if ($line -match $pat) {
                                    # Write-Host "Exempted: $($line[0..250]) by pattern $pat"
                                    $isExempt = $true
                                    break
                                }
                            }
                            if (-not $isExempt) {
                                $findings += [pscustomobject]@{
                                    ruleId        = $rule.id
                                    severity      = $rule.severity
                                    file          = $file.FullName
                                    lineNumber    = ($i + 1)
                                    match         = $m.Value
                                    lineBeginning = $line.Substring(0, [Math]::Min(100, $line.Length)).Trim()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    New-Item -Path $envOut -ItemType Directory -Force | Out-Null
    $findingsJsonPath = Join-Path $envOut "security-scan-latest.json"
    $findingsCsvPath = Join-Path  $envOut ("security-scan-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".csv")

    $findings | ConvertTo-Json -Depth 5 | Out-File -FilePath $findingsJsonPath -Encoding utf8
    $findings | Select-Object ruleId, severity, file, lineNumber, match | Export-Csv -NoTypeInformation -Path $findingsCsvPath -Encoding UTF8
    Write-Host "Security scan complete. $($findings.Count) findings. Reports at $OutputDir" -ForegroundColor Green
}
