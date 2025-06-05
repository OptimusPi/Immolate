# rebuild.ps1
# This script cleans and rebuilds the Immolate project

Write-Host "Starting clean rebuild process..." -ForegroundColor Cyan

# Clean up operations
Write-Host "Checking build directory..." -ForegroundColor Yellow
if (Test-Path ".\build") {
    Remove-Item -Recurse -Force build
    Write-Host "Build directory removed." -ForegroundColor Green
} else {
    Write-Host "Build directory is already empty." -ForegroundColor Green
}

Write-Host "Checking cached template binary..." -ForegroundColor Yellow
if (Test-Path ".\filters\ouija_template.bin") {
    Remove-Item .\filters\ouija_template.bin
    Write-Host "Template binary 'ouija_template' removed." -ForegroundColor Green
} else {
    Write-Host "Template binary 'ouija_template' already does not exist." -ForegroundColor Green
}
if (Test-Path ".\filters\ouija_template_erratic_ranks.bin") {
    Remove-Item .\filters\ouija_template_erratic_ranks.bin
    Write-Host "Template binary 'ouija_template_erratic_ranks' removed." -ForegroundColor Green
} else {
    Write-Host "Template binary 'ouija_template_erratic_ranks' already does not exist." -ForegroundColor Green
}
if (Test-Path ".\filters\ouija_template_erratic_ranks.bin") {
    Remove-Item .\filters\ouija_template_erratic_suits.bin
    Write-Host "Template binary 'ouija_template_erratic_suits' removed." -ForegroundColor Green
} else {
    Write-Host "Template binary 'ouija_template_erratic_suits' already does not exist." -ForegroundColor Green
}
if (Test-Path ".\filters\ouija_template_negatives.bin") {
    Remove-Item .\filters\ouija_template_negatives.bin
    Write-Host "Template binary 'ouija_template_negatives' removed." -ForegroundColor Green
} else {
    Write-Host "Template binary 'ouija_template_negatives' already does not exist." -ForegroundColor Green
}
if (Test-Path ".\filters\ouija_template_anaglyph.bin") {
    Remove-Item .\filters\ouija_template_anaglyph.bin
    Write-Host "Template binary 'ouija_template_anaglyph' removed." -ForegroundColor Green
} else {
    Write-Host "Template binary 'ouija_template_anaglyph' already does not exist." -ForegroundColor Green
}

# Run CMake to configure the project
Write-Host "Running CMake configuration..." -ForegroundColor Yellow

# Get the absolute path to the vcpkg toolchain file
$vcpkgToolchain = Join-Path $PSScriptRoot "vcpkg\scripts\buildsystems\vcpkg.cmake"

# Verify the toolchain file exists
if (-not (Test-Path $vcpkgToolchain)) {
    Write-Host "ERROR: vcpkg toolchain file not found at: $vcpkgToolchain" -ForegroundColor Red
    Write-Host "Make sure vcpkg submodule is initialized: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 1
}

Write-Host "Using vcpkg toolchain: $vcpkgToolchain" -ForegroundColor Green
$configResult = cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE="$vcpkgToolchain"
$configSuccess = $LASTEXITCODE -eq 0

if (-not $configSuccess) {
    Write-Host "CMake configuration failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Clean rebuild failed!" -ForegroundColor Red
    exit 1
}

# Build the project
Write-Host "Building project..." -ForegroundColor Yellow
$buildResult = cmake --build build --config Release
$buildSuccess = $LASTEXITCODE -eq 0

if (-not $buildSuccess) {
    Write-Host "Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Clean rebuild failed!" -ForegroundColor Red
    exit 1
}

# Copy the output executable to the root directory
$source = ".\build\Release\Ouija.exe" # Changed from Immolate.exe to Ouija.exe
$destination = ".\Ouija.exe" # Changed destination name to match executable name
if (Test-Path $source) {
    Copy-Item -Path $source -Destination $destination -Force
    Write-Host "Copied output to Ouija.exe" -ForegroundColor Green
} else {
    Write-Host "Build output not found at $source. Ensure the build was successful." -ForegroundColor Red
    Write-Host "Clean rebuild failed!" -ForegroundColor Red
    exit 1
}

# Activate Python virtual environment
Write-Host "Activating Python virtual environment..." -ForegroundColor Yellow
try {
    & ".\.venv\Scripts\activate.ps1"
    Write-Host "Virtual environment activated." -ForegroundColor Green
} catch {
    Write-Host "Failed to activate virtual environment. GUI may not run correctly." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}

# Notify the user
Write-Host "Clean rebuild complete!" -ForegroundColor Green
Write-Host "You can now run the GUI with:" -ForegroundColor Cyan
Write-Host ".\.venv\Scripts\Activate.ps1 && python run_ouija_mvc.py" -ForegroundColor Cyan