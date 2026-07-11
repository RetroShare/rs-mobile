# How-To: Build RetroShare Mobile for Windows (Desktop)

This guide walks you through setting up your environment, compiling the Flutter frontend for Windows Desktop, and configuring it to run alongside the RetroShare C++ backend daemon.

---

## Architecture Overview

On Windows, the application consists of two parts:
1. **Frontend (`rs-mobile`):** A native Windows desktop Flutter application (`retroshare-mobile.exe`).
2. **Backend (`retroshare-service`):** A local background C++ daemon (`retroshare-service.exe`) that handles the core protocol and exposes a JSON-RPC API.

The Flutter frontend automatically manages the backend's lifecycle (launching it on startup, connecting to `127.0.0.1:9092`, and killing it on exit) when placed in the same directory.

---

## 1. Prerequisites

Ensure you have the following installed on your Windows machine:

1. **Flutter SDK:** [flutter.dev/docs/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
2. **Visual Studio 2022:** Community Edition is sufficient.
   * *Critical:* During installation, check the **"Desktop development with C++"** workload (installs MSVC, CMake, and the Windows SDK).
3. **Git for Windows:** [gitforwindows.org](https://gitforwindows.org/)

---

## 2. Compile the Flutter Frontend

1. Open a standard Windows Command Prompt or PowerShell and enable the Windows target platform in Flutter:
   ```powershell
   flutter config --enable-windows-desktop
   ```

2. If the `windows` directory does not exist in your `rs-mobile` project yet, generate it:
   ```powershell
   flutter create --platforms=windows .
   ```

3. Compile the Windows Desktop application:
   ```powershell
   flutter run -d windows
   ```
   *Your built frontend binary will be located at:* `build\windows\x64\runner\Debug\retroshare-mobile.exe`

---

## 3. Run the Integrated Application

The frontend needs a running `retroshare-service.exe` backend daemon and its dependencies to connect to.

### Step A: Configure Backend & DLL Dependencies
To run the service, you need the compiled `retroshare-service.exe` and any required dependency DLLs (like `libstdc++-6.dll`, Botan, Qt, etc. depending on your build).

* **Option 1 (System-wide PATH):** If your backend daemon uses DLLs from an installation (like MSYS2/MinGW), add the directory containing those DLLs (e.g. `C:\msys64\mingw64\bin`) to your User **Environment Variables** `PATH`.
* **Option 2 (Standalone):** Place all required dependency DLLs directly in the directory where `retroshare-service.exe` and `retroshare-mobile.exe` will reside.

### Step B: Combine & Launch
1. Copy the compiled `retroshare-service.exe` file into your `rs-mobile` build output folder, putting it right next to `retroshare-mobile.exe`:
   * **Target Path:** `C:\Users\Username\Documents\GitHub\rs-mobile\build\windows\x64\runner\Debug\`
2. Open PowerShell, navigate to the `rs-mobile` project directory, and launch the app:
   ```powershell
   flutter run -d windows
   ```
   *The Flutter app will start, automatically spin up the `retroshare-service.exe` subprocess in the background, connect to it, and terminate it cleanly when you exit.*

---

## Troubleshooting

### "Invalid argument" CMake Copy Errors
If you run `flutter run` and receive an `Invalid argument` or `Access Denied` error while copying files:
1. This is caused by one or more stale instances of `retroshare-mobile.exe` running in the background and locking the build files.
2. Open PowerShell and force-terminate any running instances:
   ```powershell
   Stop-Process -Name retroshare-mobile -Force
   ```
3. Re-run `flutter run -d windows`.
