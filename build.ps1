[CmdletBinding()]
param (
    [Switch]$Clean,
    [Switch]$PrecompileKernels
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$BuildDir = Join-Path $ScriptDir "build"
$OuijaExecutablePath = Join-Path $BuildDir "Release\\Ouija.exe" # Common CMake output for Release
$FiltersDir = Join-Path $ScriptDir "filters"

Write-Host "Build script started..."
Write-Host "Workspace Root: $ScriptDir"
Write-Host "Build Directory: $BuildDir"
if ($Clean) { Write-Host "Clean build requested." }
if ($PrecompileKernels) { Write-Host "Kernel pre-compilation requested after build." }

# 1. Clean Build Directory (if -Clean is specified)
if ($Clean) {
    if (Test-Path $BuildDir) {
        Write-Host "Cleaning build directory: $BuildDir"
        Remove-Item -Recurse -Force $BuildDir
    } else {
        Write-Host "Build directory does not exist, no need to clean."
    }

    # Clean ouija_search.bin from project root
    $mainKernelBin = Join-Path $ScriptDir "ouija_search.bin"
    if (Test-Path $mainKernelBin) {
        Write-Host "Removing main kernel binary: $mainKernelBin"
        Remove-Item -Force $mainKernelBin
    } else {
        Write-Host "Main kernel binary not found, no need to clean: $mainKernelBin"
    }

    # Clean all ouija_*.bin files from filters directory
    $filterBinFiles = Get-ChildItem -Path $FiltersDir -Filter "ouija_*.bin"
    if ($filterBinFiles) {
        Write-Host "Removing filter kernel binaries from: $FiltersDir"
        foreach ($binFile in $filterBinFiles) {
            Write-Host "  Removing $($binFile.FullName)"
            Remove-Item -Force $binFile.FullName
        }
    } else {
        Write-Host "No filter kernel binaries found in $FiltersDir, no need to clean."
    }
}

# 2. Create Build Directory if it doesn't exist
if (-not (Test-Path $BuildDir)) {
    Write-Host "Creating build directory: $BuildDir"
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

# 3. Configure and Build (CMake example)
Write-Host "Navigating to build directory: $BuildDir"
Push-Location $BuildDir

try {
    Write-Host "Configuring project with CMake..."
    cmake ..  # Assumes CMakeLists.txt is in $ScriptDir (parent of $BuildDir)
              # Add generator if needed, e.g., cmake .. -G "Visual Studio 17 2022"

    Write-Host "Building project (Release configuration)..."
    cmake --build . --config Release
    # For MSBuild directly if you have a solution (adjust path/name as needed):
    # msbuild Ouija.sln /p:Configuration=Release

    Write-Host "Build completed successfully."

    # 4. Precompile Kernels (if -PrecompileKernels is specified and build was successful)
    if ($PrecompileKernels) {
        # This block should be correctly placed after the build commands.
        # Ensure current directory is the script's root directory ($ScriptDir or $PSScriptRoot)
        # If the build happens in a different location, ensure you are back in the root.
        # The Pop-Location / Push-Location logic from your previous script version is good here.
        if ($PWD.Path -eq $BuildDir) {
            Pop-Location # Go back to $ScriptDir from $BuildDir
        }
        Push-Location $PSScriptRoot # Ensure we are in the script's root directory

        Write-Host "Pre-compiling OpenCL kernels..."
        $sourceExePath = Join-Path $BuildDir "Release" "Ouija.exe" # Path to the freshly built Ouija.exe
        
        if (-not (Test-Path $sourceExePath)) {
            Write-Error "Ouija.exe not found at $sourceExePath. Build might have failed. Cannot pre-compile kernels."
            # Consider exiting or returning if this is critical
        } else {
            # Temporarily copy Ouija.exe to the project root ($PSScriptRoot)
            $ouijaExeInRootDir = Join-Path $PSScriptRoot "Ouija.exe" # Target path in root: X:\\Immolate\\Ouija.exe
            
            try {
                Write-Host "Copying $sourceExePath to $ouijaExeInRootDir for pre-compilation."
                Copy-Item -Path $sourceExePath -Destination $ouijaExeInRootDir -Force
                
                # --- Main Kernel Pre-compilation (Parallel with filters) ---
                Write-Host "--------------------------------------------------"
                Write-Host "Pre-compiling main kernel: ouija_search.cl (in parallel with filters)"
                Write-Host "Ouija executable for main kernel: $ouijaExeInRootDir"
                Write-Host "--------------------------------------------------"
                $jobs = @()
                # Add main kernel job
                $mainKernelScriptBlock = {
                    param($currentCopiedExePath)
                    $mainKernelArgs = @("-n", "0")
                    $mainKernelCommand = "& `"$currentCopiedExePath`" $mainKernelArgs"
                    Write-Host "Starting job for main kernel (Command: $mainKernelCommand)"
                    Invoke-Expression $mainKernelCommand
                }
                $jobs += Start-Job -ScriptBlock $mainKernelScriptBlock -ArgumentList $ouijaExeInRootDir

                # --- Filter Kernels Pre-compilation (Parallel) ---
                Write-Host "--------------------------------------------------"
                Write-Host "Starting parallel pre-compilation of Ouija filter kernels (ouija_*.cl)..."
                Write-Host "Ouija executable for filters: $ouijaExeInRootDir"
                $filtersSourceDir = Join-Path $PSScriptRoot "filters"
                Write-Host "Filters directory: $filtersSourceDir"
                Write-Host "--------------------------------------------------"

                $filterFiles = Get-ChildItem -Path $filtersSourceDir -Filter "ouija_*.cl"

                foreach ($file in $filterFiles) {
                    $filterName = $file.BaseName
                    $scriptBlock = {
                        param($currentCopiedExePath, $currentFilterName)
                        $filterCommandArgs = @("-f", $currentFilterName, "-n", "0") # Compile-only mode
                        $commandToRun = "& `"$currentCopiedExePath`" $filterCommandArgs"
                        Write-Host "Starting job for filter: $currentFilterName (Command: $commandToRun)"
                        Invoke-Expression $commandToRun # Ouija.exe in root will find filters in ./filters/
                    }
                    $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $ouijaExeInRootDir, $filterName
                }

                Write-Host "Waiting for all kernel compilation jobs to complete..."
                $jobs | Wait-Job | Receive-Job # Add -ErrorAction SilentlyContinue to Receive-Job if needed
                Write-Host "All kernel compilation jobs finished."

            } catch {
                Write-Error "An error occurred during the pre-compilation process: $($_.Exception.Message)"
            }
        }
        Pop-Location # Match the Push-Location $PSScriptRoot
        Write-Host "Kernel pre-compilation section finished."
    }

} catch {
    Write-Error "Build process failed: $($_.Exception.Message)"
    exit 1
} finally {
    if ($PWD.Path -eq $BuildDir) { # Ensure we pop location only if we pushed it
        Pop-Location
    }
}

# After all build and optional pre-compilation steps,
# ensure Ouija.exe is copied to the root directory if the build was successful.
$FinalSourceExe = Join-Path $BuildDir "Release\Ouija.exe" # $BuildDir is $PSScriptRoot\build
$FinalDestinationExe = Join-Path $ScriptDir "Ouija.exe"   # $ScriptDir is $PSScriptRoot

# Only copy if not already present (from precompilation), or if missing
if (-not (Test-Path $FinalDestinationExe)) {
    if (Test-Path $FinalSourceExe) {
        Write-Host "Copying $FinalSourceExe to $FinalDestinationExe as final step..." -ForegroundColor Green
        Copy-Item -Path $FinalSourceExe -Destination $FinalDestinationExe -Force
        Write-Host "Ouija.exe finalized in root directory: $FinalDestinationExe" -ForegroundColor Green
    } else {
        # This condition implies the build might have failed to produce the executable,
        # though cmake --build errors should have stopped the script earlier.
        Write-Warning "Build output $FinalSourceExe not found after build process. Cannot copy to root directory."
    }
} else {
    Write-Host "Ouija.exe already present in root directory, skipping redundant copy." -ForegroundColor Yellow
}

Write-Host "Build script finished."
