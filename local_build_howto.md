# How-To: Build libretroshare Locally (WSL or Linux)

The `libretroshare` Android build process uses native Linux shell scripts (`misc/Android/prepare-toolchain-clang.sh`) and build tools (`make`, `wget`, `tar`, `sed`, `configure`) to download and compile C++ dependencies.

Because of this, you **cannot compile the library natively on Windows CMD or PowerShell**. You must run the build inside **WSL (Windows Subsystem for Linux)**, or on any Linux machine — the steps below are identical, only Step 1 is WSL-specific.

Everything here was verified on Ubuntu 24.04 with NDK `29.0.14206865` on 2026-08-17.

---

## Step 1: Set Up WSL (Windows only)

1. Open **PowerShell** as Administrator and run:
   ```powershell
   wsl --install
   ```
   This gives you WSL 2, which is what you want — WSL 1 is not supported here. The Android NDK only ships an `linux-x86_64` toolchain, so an ARM Windows machine cannot run this build.
2. Restart your computer if prompted. Set up your username and password when the Ubuntu terminal opens.

## Step 2: Install the host packages

```bash
sudo apt update
sudo apt install -y build-essential wget unzip tar python3 openjdk-17-jdk qemu-user \
cmake autoconf automake libtool pkg-config doxygen
```

> [!IMPORTANT]
> Two traps in this list:
>
> - **`qemu-user`, not `qemu-user-static`.** `build_librnp` passes `-DCMAKE_CROSSCOMPILING_EMULATOR="/usr/bin/qemu-${arch}"` — a hardcoded absolute path to the *non-static* binary. `qemu-user-static` only installs `/usr/bin/qemu-aarch64-static`, and the build fails on the missing file. A symlink works too.
> - **JDK 17, not a newer one.** The Gradle wrapper is 7.2 with Android Gradle Plugin 7.1; under JDK 21 it aborts while compiling `settings.gradle` with `Unsupported class file major version 65`. If your distribution defaults to a newer JDK, pass `JAVA_HOME` explicitly as shown in Step 5. JDK 11 also works but is not needed.
>
> On Debian and Ubuntu there is no `/usr/bin/libtool` — the package ships `libtoolize` and the m4 macros. That is normal, do not try to "fix" it.

## Step 3: Install the Android SDK & NDK

The toolchain script installs exactly the versions the build expects, so let it do the work:

```bash
mkdir -p ~/rs-android-work && cd ~/rs-android-work
export ANDROID_SDK_PATH="$HOME/Android/sdk"
~/libretroshare/misc/Android/prepare-toolchain-clang.sh install_android_sdk
```

Adjust the script path to wherever you cloned libretroshare in Step 4 — you can also run Step 4 first.

> [!IMPORTANT]
> - Run the script from a **dedicated working directory**: it downloads into `$(pwd)` and writes its `<toolchain>_build_report/` there. Launching it from inside the source tree litters it.
> - `install_android_sdk` starts with `rm -rf "$ANDROID_SDK_PATH"`. Never point it at an SDK you care about, and note the default is `/opt/android-sdk/`, which needs root — hence the `ANDROID_SDK_PATH` override.
> - `install_android_sdk` is **not** part of the default task sequence, which is why it is invoked by name.

If you prefer to install the SDK by hand, install the components the script installs — **`platforms;android-21`** and **`build-tools;29.0.3`**, plus **`ndk;29.0.14206865`**. `libretroshare/build.gradle` declares `compileSdkVersion 21` and `ndkVersion 29.0.14206865`, so a platform-34 / build-tools-34 SDK does not satisfy it.

Expect about **2.8 GB** for the SDK and NDK, and budget around **20 GB** in total: `bootstrap_toolchain` copies the whole NDK llvm prebuilt once per API level / architecture / build type, and every C++ dependency is built from source into a private sysroot.

## Step 4: Clone libretroshare

> [!IMPORTANT]
> **Clone libretroshare on its own, not the RetroShare super-project.**
> ```bash
> cd ~
> git clone https://github.com/RetroShare/libretroshare.git
> cd libretroshare
> ```
> Inside the super-project, `../supportlibs/librnp/CMakeLists.txt` exists, and `libretroshare/CMakeLists.txt` then builds rnp **inline** instead of using the one `build_librnp` already installed in the sysroot. That inline build cannot work when cross-compiling: rnp's CMake *runs* a `findopensslfeatures` helper it has just compiled for Android. On a plain Linux host the binary cannot be executed at all; under WSL, where binfmt hands it to qemu, it dies with
> ```
> qemu-aarch64: Could not open '/system/bin/linker64': No such file or directory
> ```
> The standalone clone is also what the upstream GitLab CI uses, so it is the better-tested path.

Then point the build at your SDK:

```bash
echo "sdk.dir=$HOME/Android/sdk" > local.properties
```

## Step 5: Build the AAR

```bash
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ./gradlew assembleDebug \
  -PANDROID_MIN_API_LEVEL=24 \
  -PNATIVE_TOOLCHAINS_DIR="$HOME/Builds/rs-android-toolchains/"
```

The result is `build/outputs/aar/libretroshare-MinApiLevel24-debug.aar`.

Only `arm64-v8a` is produced: `build.gradle` defaults the ABI list to that single entry and throws for anything else, so you need a physical 64-bit ARM device, not an x86 emulator.

> [!IMPORTANT]
> **Always pass `-PNATIVE_TOOLCHAINS_DIR`.** It defaults to `build/native_toolchains/`, so the multi-GB cross toolchain lands inside the Gradle build directory, where the build itself deletes it — a `gradlew clean`, or simply a `release` build cleaning up after a `debug` one, costs you the entire dependency chain again. Upstream CI passes this option for the same reason.
>
> The first run builds openssl, zlib, bzip2, json-c, rnp, sqlite, rapidjson, restbed, xapian, miniupnpc and pHash from source. Later runs reuse the toolchain directory and only rebuild libretroshare itself, which takes a few minutes.

### Filesystem case-sensitivity (WSL only)

The NDK sysroot contains 8 pairs of headers differing only by case — `linux/netfilter/xt_rateest.h` and `xt_RATEEST.h`, `xt_MARK.h` and `xt_mark.h`, and so on. `bootstrap_toolchain` copies that sysroot wholesale, so **the copy fails with `File exists` if the destination is on a case-insensitive Windows drive**. The RetroShare sources themselves contain no such collision; the NDK does.

The practical consequence: what must live on the case-sensitive WSL filesystem is the **toolchain directory**, which is exactly what `-PNATIVE_TOOLCHAINS_DIR="$HOME/Builds/..."` guarantees. Keeping the source tree on the WSL filesystem too is still strongly recommended, but for a different reason — building through `/mnt/c` is several times slower, and Windows Defender scanning every generated object file makes it worse.

If you must keep the checkout on the Windows drive, enable case sensitivity from an Administrator PowerShell and normalise line endings:

```powershell
fsutil file setCaseSensitiveInfo "C:\path\to\libretroshare" enable
```

```bash
cd /mnt/c/path/to/libretroshare
rm -rf build
git add --renormalize .
git checkout -- .
```

### Resource limits

The script builds with `make -j$(nproc)`, which is about cores and ignores memory. libretroshare has a few very heavy translation units — `src/jsonapi/jsonapi.cpp` above all — and several of them compiling at once will exhaust the RAM of a machine that has plenty of cores. The compiler is then killed and the build stops on

```
Terminated
make[2]: *** [.../jsonapi.cpp.o] Error 143
```

Error 143 is SIGTERM, i.e. the out-of-memory killer, not a compile error. Budget roughly **2 GB of free RAM per job** and throttle accordingly:

```bash
export HOST_NUM_CPU=2
```

Under WSL this bites sooner than you would expect, because WSL 2 caps its VM at roughly half the host RAM while still exposing every host core to `nproc`.

Note that `build_libretroshare` removes its build directory before configuring, so a run killed halfway costs you the whole compile. Better to under-subscribe than to retry.

### When a dependency fails

`prepare-toolchain-clang.sh` records one log per task under `<toolchain>_build_report/` and **skips any task whose log already exists, even if that task failed**. Only the tasks named on the command line are reset. So to retry after a failure, name them:

```bash
cd ~/rs-android-work
ANDROID_NDK_PATH="$HOME/Android/sdk/ndk/29.0.14206865" \
NATIVE_LIBS_TOOLCHAIN_PATH="$HOME/Builds/rs-android-toolchains/24-arm64-debug/" \
ANDROID_PLATFORM_VER=24 ANDROID_NDK_ARCH=arm64 TOOLCHAIN_BUILD_TYPE=Debug \
~/libretroshare/misc/Android/prepare-toolchain-clang.sh build_librnp build_libretroshare
```

Running the script with **no argument** wipes the report directory and rebuilds every dependency from scratch.

## Step 6: Use the AAR in rs-mobile

Copy the artifact into the app's `libs/` directory, creating it if needed:

```bash
mkdir -p ~/rs-mobile/android/app/libs
cp ~/libretroshare/build/outputs/aar/libretroshare-MinApiLevel24-debug.aar \
   ~/rs-mobile/android/app/libs/
```

From WSL, a Windows checkout is reachable as `/mnt/c/Users/<you>/.../rs-mobile/android/app/libs/`.

Then, in `rs-mobile/android/app/build.gradle`, **comment out the published dependency** and reference the file — declaring both pulls the same classes in twice:

```groovy
dependencies {
//  implementation "org.retroshare.service:libretroshare-MinApiLevel24-debug:ebbc30e3"
    implementation files('libs/libretroshare-MinApiLevel24-debug.aar')
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

## Step 7: Run the Flutter project

```bash
flutter clean
flutter run
```

---

## Known blockers on an unpatched master (2026-08-17)

There is no Android CI on GitHub — the AAR jobs live in `libretroshare/.gitlab-ci.yml` and only run on GitLab runners with extra storage. Nothing on a pull request exercises this toolchain, so it drifts. A build from today's master hits these, in this order:

- **rnp: the emulator is prepended twice.** `LIBRNP_SOURCE_VERSION` defaults to `origin/main`, and rnp merged its own `CMAKE_CROSSCOMPILING_EMULATOR` support upstream (`rnpgp/rnp 0a0672af`, 2026-07-31) while the script still patches it in. The probe becomes `qemu-aarch64 /usr/bin/qemu-aarch64 findopensslfeatures`, and configure dies on `Invalid ELF image for this architecture`.
- **rnp: the feature probe does not link libdl.** rnp links it statically when cross-compiling, but OpenSSL 1.1.1's `libcrypto.a` pulls in `dso_dlfcn.o` and nothing puts `libdl` on the link line, so it fails with `undefined symbol: dlopen`. The NDK does ship a static `libdl.a` defining those symbols; it has to be linked *after* `libcrypto.a`.
- **libtiff: `pow` is not found.** `cmake/FindCMath.cmake` probes `pow(3)` with no library, then with whatever `find_library(NAMES m)` returned. On Android libm sits under the API level directory of the sysroot, which the script does not put in `CMAKE_LIBRARY_PATH`, so the second probe is identical to the first and configure aborts with `Could NOT find CMath (missing: CMath_pow)`. This takes cimg and pHash down with it.
- **rnp built inline** when the checkout is inside the RetroShare super-project — avoided by the standalone clone of Step 4.

Each of these has a fix pending against libretroshare. Until they are merged, build from a branch carrying them.
