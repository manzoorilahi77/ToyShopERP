# run_local.ps1
# Run this instead of 'flutter run' to automatically set up port forwarding
# for all connected Android devices/emulators before starting the app.

Write-Host ">> Setting up adb port forwarding..." -ForegroundColor Cyan

# Get all connected devices (skip the first header line)
$adbDevices = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\tdevice$" }

if (-not $adbDevices) {
    Write-Host "  No devices connected. Connect a device or start an emulator first." -ForegroundColor Yellow
} else {
    foreach ($line in $adbDevices) {
        $deviceId = ($line -split "`t")[0].Trim()
        Write-Host "  Forwarding port 5000 on: $deviceId" -ForegroundColor Green
        adb -s $deviceId reverse tcp:5000 tcp:5000
    }
}

Write-Host ""
Write-Host ">> Starting Flutter app..." -ForegroundColor Cyan
flutter run
