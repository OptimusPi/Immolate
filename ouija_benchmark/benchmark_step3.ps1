param (
    [string]$OuijaExePath = "..\\Ouija.exe", # Assumes script is in ouija_benchmark, Ouija.exe is one level up
    [string]$Seed = "5XFVLI",
    [string]$Config = "egg",
    [int]$NumGroups = 32 # Defaulting to 32 as per your comments
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

Write-Host "Benchmark Step 3: Testing seeds-per-second for various -b (batchMultiplier) values."
Write-Host "Using: OuijaExePath='$OuijaExePath', Seed='$Seed', Config='$Config', NumGroups='$NumGroups'"
Write-Host "----------------------------------------------------------------------------------------------------"
Write-Host ("{0,-15} {1,-18} {2,-15} {3,-15} {4,-20}" -f "NumSeedsTotal", "BatchMultiplier", "TimeTaken(s)", "KSeeds/s (App)", "FullCommand") # Changed header
Write-Host "----------------------------------------------------------------------------------------------------"

$numSeedsToSearchList = @(10000, 50000, 75000, 100000, 250000, 1000000, 5000000, 314000000)
$batchMultiplierList = @(1, 64, 128, 256) # Updated batch multiplier list

$overallSuccess = $true

foreach ($numSeedsTotal in $numSeedsToSearchList) {
    Write-Host # Add a blank line for readability between numSeedsTotal blocks
    foreach ($batchMultiplier in $batchMultiplierList) {
        $command = "$OuijaExePath -s $Seed --config $Config -g $NumGroups -n $numSeedsTotal -b $batchMultiplier"
        $kSeedsPerSecondString = "N/A" # Changed variable name for clarity
        $timeTakenSeconds = "N/A"

        try {
            # Write-Host ("Running: -n {0,-12} -b {1,-3} ..." -f $numSeedsTotal, $batchMultiplier) -NoNewline
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $output = Invoke-Expression "$command 2>&1" | Out-String # Capture stdout and stderr
            $stopwatch.Stop()
            $timeTakenSeconds = ($stopwatch.Elapsed.TotalSeconds).ToString("F2")

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Ouija.exe exited with code $LASTEXITCODE for command: $command"
                # Truncate output if it's too long for a single line warning
                $errorOutputForDisplay = if ($output.Length -gt 200) { $output.Substring(0, 200) + "..." } else { $output }
                Write-Warning "Output: $errorOutputForDisplay"
                $overallSuccess = $false
            }

            # Try to parse seeds/s
            $match = $output | Select-String -Pattern "@\s*([\d\.]+)\s*seeds/s"
            if ($match) {
                $seedsPerSecondParsed = $match.Matches[0].Groups[1].Value
                try {
                    $seedsPerSecondNumeric = [double]$seedsPerSecondParsed
                    $kSeedsPerSecond = $seedsPerSecondNumeric / 1000
                    $kSeedsPerSecondString = $kSeedsPerSecond.ToString("F2") # Format to 2 decimal places
                    # Write-Host (" -> Done ({0}s, {1} Kseeds/s)" -f $timeTakenSeconds, $kSeedsPerSecondString) -ForegroundColor Green
                } catch {
                    Write-Warning " -> Done ({$timeTakenSeconds}s) - Could not convert '$seedsPerSecondParsed' to number for Kseeds/s calculation."
                    $kSeedsPerSecondString = "ParseErr"
                }
            } else {
                Write-Warning " -> Done ({$timeTakenSeconds}s) - Could not parse seeds/s rate."
                if ($LASTEXITCODE -eq 0) { # Only mark as overall failure if Ouija didn't report an error code itself
                    # This case might mean the output format changed or the run was too short for the summary line
                    # For very small -n, the summary line might not appear if no viable seeds are found or if it exits early.
                    # Consider if this should be a failure or just a note. For now, not failing overallSuccess.
                }
            }
            
            # Log the result line
            $formattedNumSeedsTotal = Format-NumberKM $numSeedsTotal
            Write-Host ("{0,-15} {1,-18} {2,-15} {3,-15} {4,-20}" -f $formattedNumSeedsTotal, $batchMultiplier, $timeTakenSeconds, $kSeedsPerSecondString, $command) -ForegroundColor Cyan


        } catch {
            Write-Error "Exception during execution for command: $command"
            Write-Error $_.Exception.Message
            $overallSuccess = $false
            # Log the failed attempt
            $formattedNumSeedsTotalOnError = Format-NumberKM $numSeedsTotal
            Write-Host ("{0,-15} {1,-18} {2,-15} {3,-15} {4,-20}" -f $formattedNumSeedsTotalOnError, $batchMultiplier, "ERROR", "ERROR", $command) -ForegroundColor Red
        }
    }
}

Write-Host "----------------------------------------------------------------------------------------------------"
Write-Host "Benchmark Step 3 Complete."
if (!$overallSuccess) {
    Write-Warning "One or more runs encountered errors or non-zero exit codes."
}