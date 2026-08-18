# Build libretroshare locally

Use Linux or WSL 2 to build the Android `libretroshare` AAR. The build scripts require Linux tools and cannot run directly in Windows PowerShell or Command Prompt.

These instructions were tested with Ubuntu 24.04, JDK 17, and Android NDK `29.0.14206865`.

## 1. Set up WSL (Windows only)

Open PowerShell as Administrator:

```powershell
wsl --install
```

Restart Windows if prompted, then finish the Ubuntu setup. Use WSL 2 on an x86-64 machine.

## 2. Install build dependencies

In Linux or WSL:

```bash
sudo apt update
sudo apt install -y build-essential wget unzip tar python3 openjdk-17-jdk \
  qemu-user cmake autoconf automake libtool pkg-config doxygen
```

Use `qemu-user`, not `qemu-user-static`, because the build expects executables such as `/usr/bin/qemu-aarch64`.

## 3. Clone libretroshare

Clone `libretroshare` as a standalone repository. Do not build it from inside the RetroShare super-project.

```bash
cd ~
git clone https://github.com/RetroShare/libretroshare.git
cd libretroshare
```

## 4. Install the Android SDK and NDK

Run the installer from a separate working directory because it stores downloads and build reports in the current directory.

```bash
mkdir -p ~/rs-android-work
cd ~/rs-android-work
export ANDROID_SDK_PATH="$HOME/Android/sdk"
~/libretroshare/misc/Android/prepare-toolchain-clang.sh install_android_sdk
```

> **Warning:** The installer deletes the directory specified by `ANDROID_SDK_PATH` before installing. Do not point it to an SDK directory you need to keep.

The required components are:

- Android platform 21
- Android build tools 29.0.3
- Android NDK 29.0.14206865

Create `local.properties` in the `libretroshare` checkout:

```bash
cd ~/libretroshare
echo "sdk.dir=$HOME/Android/sdk" > local.properties
```

Allow about 20 GB of free disk space for the SDK, NDK, dependencies, and native toolchains.

## 5. Build the AAR

```bash
cd ~/libretroshare
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ./gradlew assembleDebug \
  -PANDROID_MIN_API_LEVEL=24 \
  -PNATIVE_TOOLCHAINS_DIR="$HOME/Builds/rs-android-toolchains/"
```

The first build compiles all native dependencies and can take a long time. Later builds reuse `NATIVE_TOOLCHAINS_DIR`.

The generated file is:

```text
build/outputs/aar/libretroshare-MinApiLevel24-debug.aar
```

This build produces the `arm64-v8a` ABI, so test it on a 64-bit ARM device rather than an x86 Android emulator.

## 6. Add the AAR to rs-mobile

Copy the AAR into the Flutter project's Android app:

```bash
mkdir -p ~/rs-mobile/android/app/libs
cp ~/libretroshare/build/outputs/aar/libretroshare-MinApiLevel24-debug.aar \
  ~/rs-mobile/android/app/libs/
```

If `rs-mobile` is on a Windows drive, access it from WSL through `/mnt/c/Users/<username>/...`.

In `rs-mobile/android/app/build.gradle`, replace the published `libretroshare` dependency with the local file:

```groovy
dependencies {
    // implementation "org.retroshare.service:libretroshare-MinApiLevel24-debug:<version>"
    implementation files('libs/libretroshare-MinApiLevel24-debug.aar')
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

Do not enable both dependencies, because they contain the same classes.

## 7. Run rs-mobile

```bash
flutter clean
flutter run
```

## Troubleshooting

### The compiler is terminated

The build runs one job per CPU core and may run out of memory. Limit the number of jobs before rebuilding:

```bash
export HOST_NUM_CPU=2
```

Allow roughly 2 GB of free memory per build job.

### The toolchain copy fails with `File exists`

The Android NDK contains filenames that differ only by letter case. Keep `NATIVE_TOOLCHAINS_DIR` on the case-sensitive Linux filesystem, as shown above. Keeping the source checkout in WSL is also faster than building through `/mnt/c`.

### A dependency failed and is skipped on retry

The build script records completed tasks in its build report, including failed tasks. Retry the failed tasks by naming them explicitly:

```bash
cd ~/rs-android-work
ANDROID_NDK_PATH="$HOME/Android/sdk/ndk/29.0.14206865" \
NATIVE_LIBS_TOOLCHAIN_PATH="$HOME/Builds/rs-android-toolchains/24-arm64-debug/" \
ANDROID_PLATFORM_VER=24 ANDROID_NDK_ARCH=arm64 TOOLCHAIN_BUILD_TYPE=Debug \
~/libretroshare/misc/Android/prepare-toolchain-clang.sh \
  build_librnp build_libretroshare
```

Replace the task names with the dependencies that failed. Running the script without task names clears the report and rebuilds all dependencies.
