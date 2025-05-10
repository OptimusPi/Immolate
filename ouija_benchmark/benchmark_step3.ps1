param (
    [string]$OuijaExePath = ".\Ouija.exe", # Assumes script is in ouija_benchmark, Ouija.exe is one level up
    [string]$Seed = "5XFVLI",
    [string]$Config = "egg"
    # Removed $NumGroups from params as we will loop through it
)

# Helper function to format numbers into K (thousands) or M (millions)
function Format-NumberKM {
    param (
        [long]$Number
    )
    if ($Number -ge 1000000) {
        return "{0:N0} M" -f ($Number / 1000000)
    } elseif ($Number -ge 1000) {
        return "{0:N0} K" -f ($Number / 1000)
    }
    return $Number.ToString()
}

Write-Host "Benchmark Step 3: Testing seeds-per-second for various -g (NumGroups) and -b (batchMultiplier) values."
Write-Host "Using: OuijaExePath='$OuijaExePath', Seed='$Seed', Config='$Config'"
Write-Host "-----------------------------------------------------------------------------------------------------------------" # Adjusted width
Write-Host ("{0,-10} {1,-15} {2,-18} {3,-15} {4,-15} {5,-20}" -f "NumGroups", "NumSeedsTotal", "BatchMultiplier", "TimeTaken(s)", "KSeeds/s (App)", "FullCommand") # Added NumGroups to header
Write-Host "-----------------------------------------------------------------------------------------------------------------" # Adjusted width

$numGroupsList = @(32, 64, 128, 256) # List of -g values to test
$numSeedsToSearchList = @(10000, 100000, 1000000, 5000000, 10000000, 25000000, 50000000, 250000000, 1000000000)
$batchMultiplierList = @(1, 2, 4, 8, 16, 32, 64, 128)

$overallSuccess = $true

foreach ($currentNumGroups in $numGroupsList) {
    Write-Host # Add a blank line for readability between NumGroups blocks
    Write-Host "Testing with NumGroups (-g): $currentNumGroups"
    Write-Host "-----------------------------------------------------------------------------------------------------------------" # Adjusted width

    foreach ($numSeedsTotal in $numSeedsToSearchList) {
        Write-Host # Add a blank line for readability between numSeedsTotal blocks
        foreach ($batchMultiplier in $batchMultiplierList) {
            $command = "$OuijaExePath -s $Seed --config $Config -g $currentNumGroups -n $numSeedsTotal -b $batchMultiplier"
            $kSeedsPerSecondString = "N/A"
            $timeTakenSeconds = "N/A"

            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $output = Invoke-Expression "$command 2>&1" | Out-String # Capture stdout and stderr
                $stopwatch.Stop()
                $timeTakenSeconds = ($stopwatch.Elapsed.TotalSeconds).ToString("F2")

                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Ouija.exe exited with code $LASTEXITCODE for command: $command"
                    $errorOutputForDisplay = if ($output.Length -gt 200) { $output.Substring(0, 200) + "..." } else { $output }
                    Write-Warning "Output: $errorOutputForDisplay"
                    $overallSuccess = $false
                }

                $match = $output | Select-String -Pattern "@\s*([\d\.]+)\s*seeds/s"
                if ($match) {
                    $seedsPerSecondParsed = $match.Matches[0].Groups[1].Value
                    try {
                        $seedsPerSecondNumeric = [double]$seedsPerSecondParsed
                        $kSeedsPerSecond = $seedsPerSecondNumeric / 1000
                        $kSeedsPerSecondString = $kSeedsPerSecond.ToString("F2")
                    } catch {
                        Write-Warning "Could not convert '$seedsPerSecondParsed' to number for Kseeds/s calculation for command: $command"
                        $kSeedsPerSecondString = "ParseErr"
                    }
                } else {
                    Write-Warning "Could not parse seeds/s rate for command: $command"
                    # No overall failure here, as some runs might be too short or not produce the summary line
                }
                
                $formattedNumSeedsTotal = Format-NumberKM $numSeedsTotal
                Write-Host ("{0,-10} {1,-15} {2,-18} {3,-15} {4,-15} {5,-20}" -f $currentNumGroups, $formattedNumSeedsTotal, $batchMultiplier, $timeTakenSeconds, $kSeedsPerSecondString, $command) -ForegroundColor Cyan

            } catch {
                Write-Error "Exception during execution for command: $command"
                Write-Error $_.Exception.Message
                $overallSuccess = $false
                $formattedNumSeedsTotalOnError = Format-NumberKM $numSeedsTotal
                Write-Host ("{0,-10} {1,-15} {2,-18} {3,-15} {4,-15} {5,-20}" -f $currentNumGroups, $formattedNumSeedsTotalOnError, $batchMultiplier, "ERROR", "ERROR", $command) -ForegroundColor Red
            }
        }
    }
}

Write-Host "-----------------------------------------------------------------------------------------------------------------" # Adjusted width
Write-Host "Benchmark Step 3 Complete."
if (!$overallSuccess) {
    Write-Warning "One or more runs encountered errors or non-zero exit codes."
}