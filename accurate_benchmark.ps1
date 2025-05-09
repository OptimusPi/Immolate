# accurate_benchmark.ps1
# Tests the Ouija.exe performance with different seed counts
# Uses Measure-Command for accurate timing

# Configuration
$exePath = "x:\Immolate\Ouija.exe"
$baseArgs = "-s 5XFVLI --config egg -g 32"
$seedCounts = @(100000, 1000000, 10000000, 50000000, 250000000)
$results = @()

# Header
Write-Host "Running Ouija performance benchmark with accurate timing..." -ForegroundColor Green
Write-Host "Base command: $exePath $baseArgs -n <count>" -ForegroundColor Cyan
Write-Host ""

# Create results table header
$tableFormat = "{0,-15} {1,-15} {2,-15}"
Write-Host ($tableFormat -f "Seed Count", "Duration (s)", "Seeds/Second") -ForegroundColor Yellow
Write-Host ($tableFormat -f "-----------", "------------", "------------") -ForegroundColor Yellow

# Run tests for each seed count
foreach ($seedCount in $seedCounts) {
    Write-Host "Testing with $seedCount seeds..." -NoNewline
    
    # Use Measure-Command for accurate timing
    $commandOutput = $null
    $timeMeasurement = Measure-Command {
        $commandOutput = & $exePath -s 5XFVLI --config egg -g 32 -n $seedCount 2>&1
    }
    
    # Calculate performance metrics
    $duration = $timeMeasurement.TotalSeconds
    $seedsPerSecond = $seedCount / $duration
    
    # Count actual results found (lines containing specific output format)
    # Note: This can be adjusted based on the actual output format
    $resultCount = ($commandOutput | Where-Object { $_ -match '^\|?[A-Z0-9]{1,8},[0-9]+,[0-9]+' }).Count
    
    # Store results
    $results += [PSCustomObject]@{
        'SeedCount' = $seedCount
        'Duration' = [math]::Round($duration, 2)
        'SeedsPerSecond' = [math]::Round($seedsPerSecond, 2)
        'ResultsFound' = $resultCount
    }
    
    # Print results line
    Write-Host " Done in $([math]::Round($duration, 2)) seconds" -ForegroundColor Green
    Write-Host ($tableFormat -f $seedCount, [math]::Round($duration, 2), [math]::Round($seedsPerSecond, 2))
    Write-Host "  Results found: $resultCount" -ForegroundColor Cyan
}

# Save results to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = "x:\Immolate\benchmark_accurate_results_$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host ""
Write-Host "Results summary:" -ForegroundColor Green
$results | Format-Table -AutoSize
Write-Host "Results saved to: $csvPath" -ForegroundColor Cyan
