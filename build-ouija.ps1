# Recompile.ps1
# This script simplifies the re-compilation process for the Ouija variant of the Immolate-based project.

# Navigate to the project directory (ensure we're in the right location)
Set-Location $PSScriptRoot

# Get the absolute path to the vcpkg toolchain file
$vcpkgToolchain = Join-Path $PSScriptRoot "vcpkg\scripts\buildsystems\vcpkg.cmake"

# Verify the toolchain file exists
if (-not (Test-Path $vcpkgToolchain)) {
    Write-Host "ERROR: vcpkg toolchain file not found at: $vcpkgToolchain" -ForegroundColor Red
    Write-Host "Make sure vcpkg submodule is initialized: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 1
}

# Run CMake to configure the project
Write-Host "Configuring with vcpkg toolchain: $vcpkgToolchain" -ForegroundColor Green
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE="$vcpkgToolchain" -DCMAKE_BUILD_TYPE=Release

# Build the project with maximum optimizations
cmake --build build --config Release --parallel

# Copy the output executable to Ouija.exe
$source = ".\build\Release\Ouija.exe"
$destination = ".\Ouija.exe"
if (Test-Path $source) {
    Copy-Item -Path $source -Destination $destination -Force
    Write-Host "Copied output to Ouija.exe" -ForegroundColor Green
} else {
    Write-Host "Build output not found. Ensure the build was successful." -ForegroundColor Red
}

# Notify the user
Write-Host "Recompilation complete!" -ForegroundColor Green