<#
.SYNOPSIS
Setup script for Norderstedt-Roblox City Importer MVP

.DESCRIPTION
This script installs the necessary global dependencies (pnpm, uv, rokit) for Windows.
#>

Write-Host "Setting up Norderstedt-Roblox City Importer toolchain..." -ForegroundColor Cyan

# Check for Node.js
if (!(Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is not installed. Please install Node.js."
    exit 1
}

# Install pnpm
Write-Host "Installing pnpm globally via npm..."
npm install -g pnpm

# Install uv (Python package manager)
if (!(Get-Command "python" -ErrorAction SilentlyContinue)) {
    Write-Error "Python is not installed. Please install Python 3.12+."
    exit 1
}

Write-Host "Installing uv via pip..."
pip install uv

# Note for Roblox tools
Write-Host "Please ensure you install Rokit (https://github.com/rojo-rbx/rokit) for managing Roblox toolchains like Rojo."
Write-Host "Setup complete. You can now run 'pnpm install' in the root directory." -ForegroundColor Green
