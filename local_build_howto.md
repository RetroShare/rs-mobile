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
3. Open your **WSL Ubuntu terminal** and install the compilation tools (including the autotools/cmake packages needed for C++ dependencies):
   ```bash
   sudo apt update
   sudo apt install -y build-essential wget unzip tar python3 openjdk-17-jdk qemu-user-static cmake autoconf automake libtool pkg-config
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
   sdkmanager "platforms;android-34" "build-tools;34.0.0" "ndk;29.0.14206865"
   ```

---

## Step 3: Compile the AAR inside WSL

> [!IMPORTANT]
> **Filesystem Case-Sensitivity & Build Speed Warning:**
> The Android NDK includes header files that differ only by case (like `xt_rateest.h` and `xt_RATEEST.h`). Windows filesystems (`/mnt/c/`) are case-insensitive by default and will cause the copy/compile tasks to fail with `File exists` errors. Compiling on `/mnt/c/` is also extremely slow.
> 
> **It is highly recommended to clone and build your project inside the native WSL filesystem (Option A).**

### Option A: Clone and Build in WSL (Recommended)

1. Clone the repository inside your WSL home directory (e.g. `/home/username/`):
   ```bash
   cd ~
   git clone --recursive https://github.com/RetroShare/RetroShare.git
   cd RetroShare/libretroshare
   ```
2. Create/update the `local.properties` file:
   ```bash
   echo "sdk.dir=/home/$(whoami)/android/sdk" > local.properties
   ```
3. Compile the library:
   ```bash
   ./gradlew assembleDebug -PANDROID_MIN_API_LEVEL=24
   ```
   *Your compiled AAR will be located at:* `~/RetroShare/libretroshare/build/outputs/aar/libretroshare-MinApiLevel24-debug.aar`

### Option B: Build on Windows Drive `/mnt/c/` (Requires Case Sensitivity)

If you must work on your Windows drive:
1. Open **Windows PowerShell as Administrator** and enable case sensitivity on the `libretroshare` folder:
   ```powershell
   fsutil file setCaseSensitiveInfo "C:\Users\Username\Documents\GitHub\RetroShare\libretroshare" enable
   ```
2. Inside WSL, clean any previous build cache, re-normalize line endings, and run the build:
   ```bash
   cd /mnt/c/Users/Username/Documents/GitHub/RetroShare/libretroshare
   rm -rf build
   # Ensure all shell scripts use Unix line endings (LF)
   git add --renormalize .
   git checkout -- .
   echo "sdk.dir=/home/$(whoami)/android/sdk" > local.properties
   ./gradlew assembleDebug -PANDROID_MIN_API_LEVEL=24
   ```

---

## Step 4: Copy the AAR to your Mobile Project

1. Locate the compiled `libretroshare-MinApiLevel24-debug.aar` file.
   - If you built on the **WSL filesystem (Option A)**, you can copy it to your Windows mobile project folder directly from WSL:
     ```bash
     cp ~/RetroShare/libretroshare/build/outputs/aar/libretroshare-MinApiLevel24-debug.aar /mnt/c/Users/Username/Documents/GitHub/rs-mobile/android/app/libs/
     ```
   - If you built on the **Windows drive (Option B)**, it will be at:
     `C:\Users\Username\Documents\GitHub\RetroShare\libretroshare\build\outputs\aar\libretroshare-MinApiLevel24-debug.aar`
2. Ensure the destination folder exists:
   - Path: `C:\Users\Username\Documents\GitHub\rs-mobile\android\app\libs\`
3. Place `libretroshare-MinApiLevel24-debug.aar` in that `libs/` folder.

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
