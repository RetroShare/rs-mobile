# Building RetroShare Mobile on Windows

A streamlined guide to setting up your environment and building the RetroShare mobile app.

## 1. Prerequisites

Download and install the following tools:

1.  **Git for Windows**: [gitforwindows.org](https://gitforwindows.org/)
2.  **Flutter SDK**: [flutter.dev](https://docs.flutter.dev/get-started/install/windows)
    *   Extract it to a permanent folder (e.g., `C:\flutter`).
    *   Add `C:\flutter\bin` to your User **Environment Variables** `PATH`.
3.  **Android Studio**: [developer.android.com/studio](https://developer.android.com/studio)

---

## 2. Setup Android Studio

1.  **Install Plugins**: Open Android Studio -> **Plugins** -> Search and install **Flutter** (this will automatically install Dart).
2.  **SDK Tools**: 
    *   Go to **Settings** -> **Languages & Frameworks** -> **Android SDK**.
    *   Select the **SDK Tools** tab.
    *   Check and install:
        *   `Android SDK Command-line Tools (latest)`
        *   `Android SDK Platform-Tools`
        *   `Android SDK Build-Tools`
3.  **Accept Licenses**: Open a Command Prompt (cmd) and run:
    ```bash
    flutter doctor --android-licenses
    ```
    *(Type `y` for all prompts)*

---

## 3. Prepare the Project

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/RetroShare/rs-mobile.git
    cd rs-mobile
    ```
2.  **Fetch Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Open in Android Studio**:
    *   Open Android Studio -> **Open** -> Select the `rs-mobile` folder.
    *   If prompted "Flutter SDK path not given", point it to your flutter folder (e.g., `C:\flutter`).

---

## 4. Build and Run

### Run on a Device/Emulator
1. Connect your Android phone via USB (with **USB Debugging** enabled in Developer Options) or start an emulator.
2. Verify connection:
   ```bash
   flutter devices
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Build the APK
To generate the installer file (`.apk`), run:
```bash
flutter build apk --release
```
The result will be located in:
`build/app/outputs/flutter-apk/app-release.apk`

---

## Troubleshooting

*   **Flutter Doctor**: Run `flutter doctor` at any time to check if your environment is correctly configured.
*   **Service Logs**: To view native RetroShare logs while the app is running:
    ```bash
    adb logcat -s RetroShareService:D
    ```
*   **Port Forwarding**: To access the RetroShare JSON API directly from your PC while debugging:
    ```bash
    adb forward tcp:9091 tcp:9092
    curl http://127.0.0.1:9091/RsJsonApi/version
    ```
