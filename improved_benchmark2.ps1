# improved_benchmark2.ps1
# Tests the Ouija.exe performance with different seed counts
# Uses Measure-Command for accurate timing

# Configuration
$exePath = "x:\Immolate\Ouija.exe"
$baseArgs = "-s 5XFVLI --config egg -g 32"
$seedCounts = @(1000, 10000, 100000, 1000000)  # Reduced to avoid excessive waiting
$results = @()

# Header
Write-Host "Running improved Ouija performance benchmark with stride mechanism..."
Write-Host ""
Write-Host "Base command: $exePath $baseArgs -n <count>"
Write-Host ""

# Run tests for each seed count
foreach ($seedCount in $seedCounts) {
    Write-Host "Testing with $seedCount seeds..." -NoNewline
    
    # Create a new logfile for this run
    $logFile = "x:\Immolate\benchmark_run_$seedCount.log"
    
    # Use Measure-Command to get accurate execution time
    $timeResult = Measure-Command {
        Start-Process -FilePath $exePath -ArgumentList "-s", "5XFVLI", "--config", "egg", "-g", "32", "-n", "$seedCount" -NoNewWindow -Wait -RedirectStandardOutput $logFile
    }
    
    # Get the duration in seconds
    $duration = $timeResult.TotalSeconds
    
    # Calculate seeds per second
    $seedsPerSecond = [math]::Round($seedCount / $duration, 2)
    
    # Try to get more accurate metrics from the log file if available
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Raw
        if ($logContent -match "Finished processing \d+ seeds in ([0-9.]+) seconds \(Top speed: ([0-9.]+) seeds/s\)") {
            $reportedDuration = [double]$matches[1]
            $reportedSeedsPerSecond = [double]$matches[2]
            
            Write-Host " Done in $([math]::Round($duration, 2)) seconds (measured externally)"
            Write-Host "   Program reported: $reportedDuration seconds, $reportedSeedsPerSecond seeds/s"
            
            # Use the reported values since they're more accurate for internal processing
            $duration = $reportedDuration
            $seedsPerSecond = $reportedSeedsPerSecond
        }
        
        # Clean up the log file
        Remove-Item $logFile
    }
    else {
        Write-Host " Done in $([math]::Round($duration, 2)) seconds ($seedsPerSecond seeds/s)"
    }
    
    # Store results
    $results += [PSCustomObject]@{
        'Seed Count' = $seedCount
        'Duration (s)' = [math]::Round($duration, 2)
        'Seeds/Second' = [math]::Round($seedsPerSecond, 2)
    }
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
