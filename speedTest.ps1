# Define the array of thread group sizes
$threadGroups = @(32, 64, 128, 256)
$workSizes = @(6000000, 92000000, 1000000000)

# Loop through each thread group size
foreach ($g in $threadGroups) {
    # Loop through each work size
    foreach ($workSize in $workSizes) {
        # regular authored version
        Write-Host "Running with -g $g and work size $workSize..."
        $elapsedTime = Measure-Command { ./Immolate.exe -f simple_skips -s BASHBO -n $workSize -g $g }
        Write-Host ("[unoptimized] Elapsed time for -g {0}, work size {1}: {2}" -f $g, $workSize, $elapsedTime.ToString())

        # Wait for 2 seconds before the next iteration
        Start-Sleep -Seconds 8
    }

    # Loop through each work size
    foreach ($workSize in $workSizes) {
        # regular authored version
        Write-Host "Running with -g $g and work size $workSize..."
        $elapsedTime = Measure-Command { ./Immolate.exe -f simple_skips_optimized -s BASHBO -n $workSize -g $g }
        Write-Host ("[optimized] Elapsed time for -g {0}, work size {1}: {2}" -f $g, $workSize, $elapsedTime.ToString())

        # Wait for 2 seconds before the next iteration
        Start-Sleep -Seconds 8
    }
}