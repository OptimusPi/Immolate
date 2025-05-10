param (
    [string]$OuijaExePath = "..\Ouija.exe", # Adjusted path
    [string]$Seed = "5XFVLI",
    [string]$Config = "egg"
)

Write-Host "Benchmark Step 2: Testing parameter variations..."
$overallSuccess = $true

# Helper function to run a test and check output
function Test-OuijaRun {
    param (
        [string]$TestName,
        [string]$FullCommand,
        [string]$ExpectedStringInOutput
    )
    Write-Host "`n--- Testing: $TestName ---"
    Write-Host "Executing: $FullCommand"
    $testSpecificSuccess = $true
    try {
        $output = Invoke-Expression $FullCommand | Out-String
        # Write-Host "Output: $output" # Uncomment for debugging full output

        if ($output -notmatch [regex]::Escape($ExpectedStringInOutput)) {
            Write-Error "$TestName FAILED: Output did not contain '$ExpectedStringInOutput'"
            $script:overallSuccess = $false
            $testSpecificSuccess = $false
        } else {
            Write-Host "$TestName PASSED: Output contains '$ExpectedStringInOutput'" -ForegroundColor Green
        }
    } catch {
        Write-Error "$TestName FAILED: Error executing Ouija.exe: $($_.Exception.Message)"
        $script:overallSuccess = $false
        $testSpecificSuccess = $false
    }
    return $testSpecificSuccess
}

# Test Block 1: Varying -n with -g 1
Write-Host "`n--- Test Block 1: Testing -n parameter with -g 1 (varying number of seeds) ---"
$numSeedsToTestN = @(1, 32, 100)
foreach ($currentNumSeeds in $numSeedsToTestN) {
    $command = "$OuijaExePath -s $Seed --config $Config -g 1 -n $currentNumSeeds"
    $expectedOutput = "Processing results for $currentNumSeeds seeds"
    Test-OuijaRun -TestName "Vary -n ($currentNumSeeds) with -g 1" -FullCommand $command -ExpectedStringInOutput $expectedOutput
}

# Test Block 2: Varying -n with -g 32
Write-Host "`n--- Test Block 2: Testing -n parameter with -g 32 (varying number of seeds) ---"
$numSeedsToTestG32 = @(1, 32, 100) # Can be the same or different array
foreach ($currentNumSeeds in $numSeedsToTestG32) {
    $command = "$OuijaExePath -s $Seed --config $Config -g 32 -n $currentNumSeeds"
    $expectedOutput = "Processing results for $currentNumSeeds seeds"
    Test-OuijaRun -TestName "Vary -n ($currentNumSeeds) with -g 32" -FullCommand $command -ExpectedStringInOutput $expectedOutput
}

# Test Block 3: Varying -b with -g 32 -n 1
Write-Host "`n--- Test Block 3: Testing -b parameter with -g 32 -n 1 (varying batch multiplier) ---"
$batchMultipliersToTest = @(1, 2, 4, 8)
$numSeedsForBatchTest = 1 # -n is fixed at 1 for this block
foreach ($currentBatchMultiplier in $batchMultipliersToTest) {
    $command = "$OuijaExePath -s $Seed --config $Config -g 32 -n $numSeedsForBatchTest -b $currentBatchMultiplier"
    $expectedOutput = "Processing results for $numSeedsForBatchTest seeds"
    Test-OuijaRun -TestName "Vary -b ($currentBatchMultiplier) with -g 32 -n $numSeedsForBatchTest" -FullCommand $command -ExpectedStringInOutput $expectedOutput
}

Write-Host "`n--- Benchmark Step 2 Summary ---"
if ($overallSuccess) {
    Write-Host "All tests in Step 2 PASSED!" -ForegroundColor Green
} else {
    Write-Host "One or more tests in Step 2 FAILED." -ForegroundColor Red
}