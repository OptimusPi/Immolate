# Recompile.ps1
# This script simplifies the re-compilation process for the Ouiji variant of the Immolate-based project.

# Navigate to the project directory
cd "x:\Immolate"

# Run CMake to configure the project
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE="x:\Immolate\vcpkg\scripts\buildsystems\vcpkg.cmake"

# Build the project
cmake --build build --config Release

# Copy the output executable to Ouiji.exe
$source = "x:\Immolate\build\Release\Ouiji.exe"
$destination = "x:\Immolate\Ouiji.exe"
if (Test-Path $source) {
    Copy-Item -Path $source -Destination $destination -Force
    Write-Host "Copied output to Ouiji.exe" -ForegroundColor Green
} else {
    Write-Host "Build output not found. Ensure the build was successful." -ForegroundColor Red
}

# Notify the user
Write-Host "Recompilation complete!" -ForegroundColor Green