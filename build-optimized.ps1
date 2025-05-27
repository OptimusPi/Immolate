# This script builds an optimized version of Ouija with advanced performance flags

# Set error action preference to stop on any error
$ErrorActionPreference = 'Stop'

Write-Host "Building performance-optimized Ouija..." -ForegroundColor Cyan

# Check if any previous optimized build exists
if (Test-Path ".\build-optimized") {
    Write-Host "Cleaning previous optimized build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force build-optimized
}

# Create new build directory
Write-Host "Creating fresh build directory..." -ForegroundColor Green
New-Item -Path ".\build-optimized" -ItemType Directory | Out-Null

# Define optimization variants to try
Write-Host "Configuring project with optimizations..." -ForegroundColor Yellow

# Configure with advanced optimizations
cmake -S . -B build-optimized -DCMAKE_TOOLCHAIN_FILE=".\vcpkg\scripts\buildsystems\vcpkg.cmake" -DCMAKE_BUILD_TYPE=Release

# Build the project with maximum optimization
Write-Host "Building with maximum optimizations..." -ForegroundColor Yellow
cmake --build build-optimized --config Release --parallel

# Copy the output executable to Ouija-optimized.exe
$source = ".\build-optimized\Release\Ouija.exe"
$destination = ".\Ouija-optimized.exe"

if (Test-Path $source) {
    Copy-Item -Path $source -Destination $destination -Force
    Write-Host "Optimized build completed! Executable saved as Ouija-optimized.exe" -ForegroundColor Green
    
    # Preserve original if it exists
    if (Test-Path ".\Ouija.exe") {
        Copy-Item -Path ".\Ouija.exe" -Destination ".\Ouija-original.exe" -Force
        Write-Host "Original executable preserved as Ouija-original.exe" -ForegroundColor Green
        
        # Make optimized version the default
        Copy-Item -Path $destination -Destination ".\Ouija.exe" -Force
        Write-Host "Optimized version set as default Ouija.exe" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Performance optimization complete!" -ForegroundColor Cyan
    Write-Host "Run your benchmarks with 'Ouija.exe' or the specific 'Ouija-optimized.exe'" -ForegroundColor Cyan
} else {
    Write-Host "Build failed - optimized executable not found!" -ForegroundColor Red
}
