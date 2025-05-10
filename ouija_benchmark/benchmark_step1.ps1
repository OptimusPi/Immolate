param (
    [string]$OuijaExePath = ".\Ouija.exe",
    [string]$Seed = "5XFVLI",
    [string]$Config = "unit_test1",
    [int]$NumGroups = 1,
    [int]$NumSeeds = 1
)

Write-Host "Step 1: Verifying Egg Seed ($Seed) with basic output checks..."

$command = "$OuijaExePath -s $Seed --config $Config -g $NumGroups -n $NumSeeds"
Write-Host "Executing: $command"

try {
    $output = Invoke-Expression $command | Out-String
    Write-Host "--- Ouija.exe Output Start ---"
    Write-Host $output
    Write-Host "--- Ouija.exe Output End ---"

    $assert1_expected = "Processing results for $NumSeeds seeds"
    $assert2_expected = "`$Search Complete! Found 1 viable out of $NumSeeds total seeds"
    $assert3_expected = "|$Seed" # New assertion
    $assert4_expected = "|$Seed,4,0,2,0" # New assertion for specific result format

    $testPassed = $true

    if ($output -notmatch [regex]::Escape($assert1_expected)) {
        Write-Error "Assertion 1 FAILED: Output did not contain '$assert1_expected'"
        $testPassed = $false
    } else {
        Write-Host "Assertion 1 PASSED: Output contains '$assert1_expected'"
    }

    if ($output -notmatch [regex]::Escape($assert2_expected)) {
        Write-Error "Assertion 2 FAILED: Output did not contain '$assert2_expected'"
        $testPassed = $false
    } else {
        Write-Host "Assertion 2 PASSED: Output contains '$assert2_expected'"
    }

    if ($output -notmatch [regex]::Escape($assert3_expected)) {
        Write-Error "Assertion 3 FAILED: Output did not contain '$assert3_expected'"
        $testPassed = $false
    } else {
        Write-Host "Assertion 3 PASSED: Output contains '$assert3_expected'"
    }

    if ($output -notmatch [regex]::Escape($assert4_expected)) {
        Write-Error "Assertion 4 FAILED: Output did not contain '$assert4_expected'"
        $testPassed = $false
    } else {
        Write-Host "Assertion 4 PASSED: Output contains '$assert4_expected'"
    }


    if ($testPassed) {
        Write-Host "Step 1 PASSED!" -ForegroundColor Green
    } else {
        Write-Host "Step 1 FAILED." -ForegroundColor Red
    }

} catch {
    Write-Error "Error executing Ouija.exe: $($_.Exception.Message)"
    Write-Host "Step 1 FAILED due to execution error." -ForegroundColor Red
}