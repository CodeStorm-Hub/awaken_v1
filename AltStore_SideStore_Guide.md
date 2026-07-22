# Sideloading Flutter iOS Apps on Windows using AltStore / SideStore

This guide outlines how to configure **AltStore** or **SideStore** on Windows and set up a **GitHub Actions** CI/CD pipeline to compile your Flutter iOS app into an unsigned `.ipa` file for local testing.

---

## Part 1: Sideloading with AltStore

AltStore allows you to sideload up to 3 apps at a time. The apps remain active for 7 days, after which they must be refreshed while connected to the same Wi-Fi network as your PC.

### 1. Prerequisites (Windows)
1. **Uninstall Microsoft Store Versions**: Ensure you uninstall any versions of iTunes or iCloud downloaded from the Microsoft Store.
2. **Install Official Apple Versions**:
   * [Download official iTunes for Windows (64-bit)](https://www.apple.com/itunes/download/win64)
   * [Download official iCloud for Windows](https://updates.cdn-apple.com/2020/windows/001-39955-20201021-22A8B28C-12A3-11EB-9F40-84E387593D64/iCloudSetup.exe)
3. Restart your PC after installing both and sign in to the iCloud desktop application using your Apple ID.

### 2. Configure iTunes Wi-Fi Sync
1. Open iTunes and connect your iPhone/iPad to your PC via a USB cable.
2. Select **Trust this Computer** on your iOS device.
3. In iTunes, select your device, go to the **Summary** tab, scroll down to **Options**, and check **Sync with this [device] over Wi-Fi**. Click **Apply**.

### 3. Install AltServer
1. Download **AltInstaller** from [altstore.io](https://altstore.io/).
2. Extract the file and run `Setup.exe` to install.
3. Launch **AltServer** as Administrator from your Start menu. It will run in your Windows system tray.

### 4. Deploy AltStore to your Device
1. Keep the iPhone plugged in via USB.
2. Click the **AltServer** icon in the system tray.
3. Select **Install AltStore** -> Choose your device.
4. Enter your Apple ID and password. *(Note: Generating an App-Specific Password via appleid.apple.com is recommended).*
5. AltStore will install on your home screen.

### 5. Trust Profile & Enable Developer Mode (On iOS)
1. Go to **Settings > General > VPN & Device Management** on your device, tap your Apple ID, and select **Trust**.
2. **For iOS 16+**: Go to **Settings > Privacy & Security > Developer Mode**, toggle it **On**, and restart your phone. Confirm by tapping **Turn On** after rebooting.

---

## Part 2: Standalone Sideloading with SideStore

SideStore is a fork of AltStore that runs completely on-device. After the initial setup, it does not require you to turn on your PC to refresh apps.

### 1. Generate Pairing File
1. Download the **JitterbugPair** utility for Windows from the [SideStore website](https://sidestore.io/).
2. Plug your iPhone into your PC via USB.
3. Run `jitterbugpair.exe` in a terminal/command prompt.
4. Rename the generated `.mobiledevicepairing` file to `device.plist` and send it to your iPhone (e.g., save it in your Files app).

### 2. Sideload SideStore
1. Sideload the `SideStore.ipa` (downloadable from [sidestore.io](https://sidestore.io/)) onto your device using Sideloadly or AltStore.
2. Trust the app in your device's settings.

### 3. Configure local VPN loopback
1. Install **WireGuard** from the App Store.
2. Open SideStore, select your `device.plist` file, and follow the prompt to install the VPN profile.
3. Enable the **SideStore VPN** toggle in WireGuard.
4. Log into SideStore on your device with your Apple ID and configure a public Anisette server in the settings. You can now sideload `.ipa` files directly on your phone.

---

## Part 3: Building the Unsigned `.ipa` using GitHub Actions

Since you don't own a Mac, you can run a GitHub runner in the cloud to build the `.ipa`. AltStore/SideStore will handle the code signing locally, so you must compile the app using the `--no-codesign` flag.

### 1. Workflow Configuration
Create a file in your project repository under `.github/workflows/build_ios.yml` and paste the following YAML configuration:

```yaml
name: Build Flutter iOS (Unsigned)

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch: # Allows manual trigger from the GitHub Actions UI

jobs:
  build:
    runs-on: macos-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Build iOS Archive (Unsigned)
        run: flutter build ipa --no-codesign

      - name: Upload Unsigned IPA
        uses: actions/upload-artifact@v4
        with:
          name: ios-unsigned-ipa
          path: build/ios/ipa/*.ipa
```

### 2. How to Retrieve the `.ipa`
1. Commit and push this file to your GitHub repository.
2. Go to the **Actions** tab on your GitHub repository page.
3. Select the **Build Flutter iOS (Unsigned)** workflow and click **Run workflow** (or wait for a push to trigger it).
4. Once completed, scroll down to the **Artifacts** section at the bottom of the run page.
5. Download the `ios-unsigned-ipa` zip file, extract it to retrieve your `.ipa` file, and send it to your iPhone for installation via AltStore/SideStore.
