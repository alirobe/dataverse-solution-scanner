# Backup Solutions from Dataverse Environment
# https://gist.github.com/alirobe/17864cb8336ea9dc3d4da61fb5d6a596

### Settings ###
$skipExisting = $false # change to $true to update

### Script ###
$ErrorActionPreference = 'Stop'
$solutionsList = pac solution list
$solutionsList > "solutions/list.txt"
$firstLine = 5 # to be changed if output from pac tool changes
$solutionsRoot = Join-Path . 'solutions'
if (-not (Test-Path $solutionsRoot)) { New-Item -ItemType Directory -Path $solutionsRoot | Out-Null }
$existing = if (Test-Path $solutionsRoot) { Get-ChildItem -Path $solutionsRoot -Directory } else { @() }
$extracted = @()

if ($solutionsList.Count -lt 5 -or -not $solutionsList[4].StartsWith("Unique Name")) {
    Write-Host "Unexpected output format. Ensure you are connected to the correct Dataverse organization and the solutions list is formatted correctly."
}

foreach ($line in $solutionsList[$firstLine..999]) {
    $solution = $line -split ' ' | Select-Object -First 1
    if($line.Trim().EndsWith("True") -or $solution -eq "Default") {
        Write-Host "Skipping managed or default solution: $solution"
        continue
    }
    if ($null -eq $solution -or $solution.Trim() -eq "" -or -not $line.Trim().EndsWith("False")) {
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
    pac solution export --name $solution
    Expand-Archive -Path "$solution.zip" -DestinationPath (Join-Path $solutionsRoot $solution)
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
    Remove-Item -Path "$solutionName.zip"
}
