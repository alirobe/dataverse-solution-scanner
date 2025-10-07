# Backup Solutions from Dataverse Environment
# https://gist.github.com/alirobe/17864cb8336ea9dc3d4da61fb5d6a596

### Settings ###
$skipExisting = $false # change to $true to update
$ErrorActionPreference = "Stop"
$SolutionsRoot = ".\solutions"
$ConfigDir = ".\config"

# Manage Settings
$EnvFile = Join-Path $ConfigDir "environments.json"
$EnvSchema = Join-Path $ConfigDir "environments.schema.json"
Test-Json -Path $EnvFile -SchemaFile $EnvSchema -ErrorAction Stop
$environmentsConfig = Get-Content -Path $EnvFile -Raw | ConvertFrom-Json 

### SCRIPT ###
foreach($envObj in $environmentsConfig.environments) {
    $env = $envObj.name
    $envGuid = $envObj.guid
    Write-Host "Processing environment $env ($envGuid)" -ForegroundColor Green
    $solutionsRoot = Join-Path . 'solutions' $env
    if (-not (Test-Path $solutionsRoot)) { New-Item -ItemType Directory -Path $solutionsRoot | Out-Null }
    pac env select --environment "$envGuid"
    $solutionsList = pac solution list  --environment "$envGuid"
    $solutionsList > (Join-Path $solutionsRoot "list.txt")
    $firstLine = 5 # to be changed if output from pac tool changes
    $existing = Get-ChildItem -Path $solutionsRoot -Directory
    $extracted = @()

    if ($solutionsList.Count -lt 5 -or -not $solutionsList[4].StartsWith("Unique Name")) {
        Write-Host "Unexpected output format. Ensure you are connected to the correct Dataverse organization and the solutions list is formatted correctly."
    }

    foreach ($line in $solutionsList[$firstLine..999]) {
        $solution = $line -split ' ' | Select-Object -First 1
        if ($null -eq $solution -or $solution.Trim() -eq "") {
            continue # ignore blank lines 
        }
        if($line.Trim().EndsWith("True") -or $solution -eq "Default") {
            Write-Host "Skipping managed or default solution: $solution"
            continue
        }
        if($false -eq $line.Trim().EndsWith("False")) {
            Write-Host "Skipping invalid solution definition in line: $line"
            continue
        }
        if($existing.Name -contains $solution) {
            if($skipExisting) {
                Write-Host "Skipping existing solution: $solution (turn off skipExisting to update)"
                continue
            } else {
                Write-Host "Removing existing solution for update: $solution"
                Remove-Item -Path (Join-Path $solutionsRoot $solution) -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "Processing solution: $solution"
        $zipPath = (Join-Path $solutionsRoot "_backups" "$solution.zip")
        $solutionPath = Join-Path $solutionsRoot $solution
        pac solution export --name $solution --path $zipPath --overwrite --managed $false
        if(test-path $solutionPath) {
            Remove-Item $solutionPath -Recurse -Force
            New-Item $solutionPath -ItemType "directory"
        }
        Expand-Archive -Path $zipPath -DestinationPath $solutionPath
        $extracted += $solution
    }

    foreach ($solutionName in $extracted) {
        Write-Host "Processing solution: $solutionName"
        $appPackages = Get-ChildItem -Path (Join-Path $solutionsRoot $solutionName) -Recurse -File -Filter "*.msapp"
        foreach($appPackage in $appPackages) {
            Write-Host "Extracting app package: $($appPackage.FullName)"
            $zipPath = Join-Path $appPackage.Directory "$($appPackage.BaseName).zip"
            Copy-Item -Path $appPackage.FullName -Destination $zipPath -Force
            Expand-Archive -Path $zipPath -DestinationPath (Join-Path $solutionsRoot $solutionName $appPackage.BaseName)
            Remove-Item -Path $zipPath -Force
        }
        Start-Sleep -Seconds 2 # expansion can sometimes exit prematurely
        
    }
}