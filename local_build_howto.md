# How-To: Build libretroshare Locally on Windows (via WSL)

The `libretroshare` Android build process uses native Linux shell scripts (`misc/Android/prepare-toolchain-clang.sh`) and build tools (`make`, `wget`, `tar`, `sed`, `configure`) to download and compile C++ dependencies.

Because of this, you **cannot compile the library natively on Windows CMD or PowerShell**. You must run the build inside **WSL (Windows Subsystem for Linux)**.

---

## Step 1: Set Up WSL (Windows Subsystem for Linux)

1. Open **PowerShell** as Administrator and run:
   ```powershell
   wsl --install
   ```
2. Restart your computer if prompted. Set up your username and password when the Ubuntu terminal opens.
3. Open your **WSL Ubuntu terminal** and install the compilation tools:
   ```bash
   sudo apt update
   sudo apt install -y build-essential wget unzip tar python3 openjdk-17-jdk qemu-user-static
   ```

---

## Step 2: Install Linux Android SDK & NDK inside WSL

Since the compilation script requires the Linux toolchain and QEMU emulator, you must install the Linux Android SDK and NDK inside WSL:

1. Create a directory for the Android SDK inside WSL:
   ```bash
   mkdir -p ~/android/sdk
   cd ~/android
   ```
2. Download and extract the Android Command Line Tools:
   ```bash
   wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
   unzip commandlinetools-linux-11076708_latest.zip
   mkdir -p ~/android/sdk/cmdline-tools
   mv cmdline-tools ~/android/sdk/cmdline-tools/latest
   ```
3. Set the environment variables (you can add these to your `~/.bashrc` file to make them permanent):
   ```bash
   export ANDROID_HOME=$HOME/android/sdk
   export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
   ```
4. Accept licenses and install the required Platform tools, Build-Tools, and NDK:
   ```bash
   yes | sdkmanager --licenses
   sdkmanager "platforms;android-34" "build-tools;34.0.0" "ndk;28.2.13676358"
   ```

---

## Step 3: Compile the AAR inside WSL

1. Navigate to your repository (WSL mounts your C drive under `/mnt/c/`):
   ```bash
   cd /mnt/c/Users/Username/Documents/GitHub/RetroShare/libretroshare
   ```
2. Create/update the `local.properties` file inside WSL to point to your WSL Android SDK path:
   ```bash
   echo "sdk.dir=/home/$(whoami)/android/sdk" > local.properties
   ```
3. Start the build:
   ```bash
   ./gradlew assembleDebug -PANDROID_MIN_API_LEVEL=24
   ```

Once the build finishes successfully, the compiled AAR will be located at:
`C:\Users\Username\Documents\GitHub\RetroShare\libretroshare\build\outputs\aar\libretroshare-MinApiLevel24-debug.aar`

---

## Step 4: Copy the AAR to your Mobile Project

1. Navigate to the `rs-mobile` Android app source folder:
   `C:\Users\Username\Documents\GitHub\rs-mobile\android\app\`
2. Create a new directory named `libs` if it does not exist:
   - Final path: `C:\Users\Username\Documents\GitHub\rs-mobile\android\app\libs\`
3. Copy the compiled file `libretroshare-MinApiLevel24-debug.aar` from Step 3 into this new `libs/` folder.

---

## Step 5: Update rs-mobile Build Configurations

Modify your `rs-mobile` project's Android build gradle configuration to reference the local file.

1. Open `C:\Users\Username\Documents\GitHub\rs-mobile\android\app\build.gradle`.
2. Locate the `dependencies` block and change the `libretroshare` declaration:

```groovy
dependencies {
    // Reference the locally copied AAR file directly
    implementation files('libs/libretroshare-MinApiLevel24-debug.aar')
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

---

## Step 6: Run the Flutter Project

Clean previous builds and run your app. You can do this from standard Windows PowerShell or Android Studio:

```bash
flutter clean
flutter run
```
