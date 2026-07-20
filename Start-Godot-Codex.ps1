$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

Write-Host "Open this project in Godot before starting Codex." -ForegroundColor Yellow

& codex
