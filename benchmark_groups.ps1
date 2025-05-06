# Benchmark script to test Ouiji.exe with different thread group sizes
# This script measures execution time of Ouiji.exe with different -g parameters

# Configuration
$seed = "5XFVLI"
$config = "egg"
$seedCounts = @(10000, 100000, 600000)  # Different seed counts to test
$groupSizes = @(32, 48, 56, 64, 112, 128, 224)
$iterations = 3  # Number of runs for each group size to average results

# Create results array
$allResults = @()

# Run Ouiji once at the beginning to ensure OpenCL code is compiled
Write-Host "Performing initial compilation run..." -NoNewline
& .\Ouiji.exe -s $seed -g 64 -n 10000 --config $config | Out-Null
Write-Host " Done!"

# Loop through each seed count
foreach ($seedCount in $seedCounts) {
    Write-Host "`n====================================================="
    Write-Host "Starting benchmark with $seedCount seeds"
    Write-Host "Seed: $seed, Config: $config"
    Write-Host "====================================================="
    
    $results = @()
    
    foreach ($size in $groupSizes) {
        Write-Host "Testing with -g $size, -n $seedCount..." -NoNewline
        
        # Run multiple iterations to get a more reliable measurement
        $totalMs = 0
        
        for ($i = 0; $i -lt $iterations; $i++) {
            # Measure the command execution time
            $timing = Measure-Command {
                & .\Ouiji.exe -s $seed -g $size -n $seedCount --config $config | Out-Null
            }
            
            $totalMs += $timing.TotalMilliseconds
        }
        
        # Calculate average
        $avgMs = $totalMs / $iterations
        
        # Store result
        $result = [PSCustomObject]@{
            SeedCount = $seedCount
            GroupSize = $size
            AverageTimeMs = [math]::Round($avgMs, 2)
            AverageTimeSeconds = [math]::Round($avgMs / 1000, 2)
        }
        $results += $result
        $allResults += $result
        
        Write-Host " Done! Average: $($result.AverageTimeSeconds) seconds"
    }
    
    # Display results for this seed count sorted by execution time
    Write-Host "`nResults Summary for $seedCount seeds (sorted by execution time):"
    Write-Host "====================================================="
    $results | Sort-Object AverageTimeMs | Format-Table -Property GroupSize, @{Name="Average Time"; Expression={"{0:N2} seconds" -f ($_.AverageTimeSeconds)}}, @{Name="Time (ms)"; Expression={"{0:N2}" -f $_.AverageTimeMs}}
    
    # Determine optimal group size (fastest) for this seed count
    $optimal = ($results | Sort-Object AverageTimeMs)[0]
    Write-Host "Optimal thread group size for $seedCount seeds: -g $($optimal.GroupSize) ($($optimal.AverageTimeSeconds) seconds)"
}

# Export all results to CSV for further analysis
$allResults | Export-Csv -Path "benchmark_results_all.csv" -NoTypeInformation
Write-Host "`nAll results exported to benchmark_results_all.csv"

# Create a pivot table-like summary showing the optimal group size for each seed count
Write-Host "`nOptimal Group Sizes Summary:"
Write-Host "====================================================="
$summary = @()
foreach ($seedCount in $seedCounts) {
    $seedResults = $allResults | Where-Object { $_.SeedCount -eq $seedCount }
    $optimal = ($seedResults | Sort-Object AverageTimeMs)[0]
    $summary += [PSCustomObject]@{
        SeedCount = $seedCount
        OptimalGroupSize = $optimal.GroupSize
        Time = "$($optimal.AverageTimeSeconds) seconds"
    }
}

$summary | Format-Table -Property SeedCount, OptimalGroupSize, Time