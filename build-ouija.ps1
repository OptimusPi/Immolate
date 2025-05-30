# Recompile.ps1
# This script simplifies the re-compilation process for the Ouija variant of the Immolate-based project.

# Navigate to the project directory
cd "x:\Immolate"

# Run CMake to configure the project
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=".\vcpkg\scripts\buildsystems\vcpkg.cmake" -DCMAKE_BUILD_TYPE=Release

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