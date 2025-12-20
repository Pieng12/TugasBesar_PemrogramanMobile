#!/bin/bash

echo "========================================"
echo "Checking Flutter Device Connection"
echo "========================================"
echo ""

echo "[1] Checking Flutter installation..."
flutter --version
echo ""

echo "[2] Checking connected devices..."
flutter devices
echo ""

echo "[3] Checking ADB devices (Android)..."
if command -v adb &> /dev/null; then
    adb devices
else
    echo "ADB not found in PATH. Make sure Android SDK is installed."
fi
echo ""

echo "========================================"
echo "If your device is not listed above:"
echo "1. Check USB Debugging is enabled on your phone"
echo "2. Try a different USB cable"
echo "3. Install USB drivers for your phone"
echo "========================================"






