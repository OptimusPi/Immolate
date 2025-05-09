# improved_benchmark.ps1
# Tests the Ouija.exe performance with different seed counts
# More accurate timing by capturing actual processing output

# Configuration
$exePath = "x:\Immolate\Ouija.exe"
$baseArgs = "-s 5XFVLI --config egg -g 32"
$seedCounts = @(1000, 10000, 100000, 1000000)  # Reduced the max to avoid excessive waiting
$results = @()

# Header
Write-Host "Running improved Ouija performance benchmark with stride mechanism..."
Write-Host ""
Write-Host "Base command: $exePath $baseArgs -n <count>"
Write-Host ""

# Run tests for each seed count
foreach ($seedCount in $seedCounts) {
    Write-Host "Testing with $seedCount seeds..." -NoNewline
    
    # Capture the output to extract the processing time
    $output = & $exePath -s 5XFVLI --config egg -g 32 -n $seedCount | Out-String
    
    # Extract the processing information from the output
    if ($output -match "Finished processing \d+ seeds in ([0-9.]+) seconds \(Top speed: ([0-9.]+) seeds/s\)") {
        $duration = [double]$matches[1]
        $seedsPerSecond = [double]$matches[2]
    } else {
        # Fallback if pattern not found
        $duration = 0
        $seedsPerSecond = 0
        Write-Host " Failed to extract timing information!" -ForegroundColor Red
    }
    
    # Store results
    $results += [PSCustomObject]@{
        'Seed Count' = $seedCount
        'Duration (s)' = [math]::Round($duration, 2)
        'Seeds/Second' = [math]::Round($seedsPerSecond, 2)
    }
    
    Write-Host " Done in $([math]::Round($duration, 2)) seconds ($([math]::Round($seedsPerSecond, 2)) seeds/s)"
}

# Display results table
Write-Host ""
Write-Host "Improved Performance Benchmark Results:" -ForegroundColor Green
$results | Format-Table -AutoSize

# Save results to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = "x:\Immolate\benchmark_stride_improved_results_$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "Results saved to: $csvPath" -ForegroundColor Cyan
