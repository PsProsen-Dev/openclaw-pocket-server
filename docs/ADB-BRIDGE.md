# ADB Bridge — Connect Termux to Android OS

To give OpenClaw the ability to **control other apps on the phone** (tap, swipe, type, read screen), you need an ADB bridge between Termux and the Android OS.

This is what powers the [android-automation-agent](https://github.com/Mohd-Mursaleen/android-automation-agent).

---

## How It Works

```
OpenClaw Skill
     ↓
  Termux
     ↓  (ADB over TCP)
 Android OS
     ↓
  Any App
```

ADB normally requires a USB cable + a computer. But using `adb tcpip` mode, you connect once via USB, then switch to wireless — so Termux can issue ADB commands to the same device over localhost.

---

## Step 1 — Install Android Tools in Termux

```bash
pkg install android-tools
```

Installs `adb` inside Termux. This is the client that will send commands to the Android OS.

---

## Step 2 — Enable Developer Options on Your Phone

1. Go to **Settings → About Phone**
2. Tap **Build Number** 7 times until you see "You are now a developer"
3. Go to **Settings → Developer Options**
4. Enable **USB Debugging**

---

## Step 3 — Switch ADB to TCP Mode (From Your Computer)

Connect your phone to your **computer** via USB cable. Then on your computer:

```bash
adb tcpip 5555
```

This tells the Android OS to accept ADB connections on port 5555 over the network.
You only need to do this once. After this, disconnect the USB cable.

---

## Step 4 — Connect Termux to Android via ADB

Now inside Termux on the phone:

```bash
adb connect localhost:5555
```

This connects the Termux ADB client to the Android OS ADB server running on the same device.
You should see: `connected to localhost:5555`

---

## Step 5 — Verify the Connection

```bash
adb devices
```

Expected output:
```
List of devices attached
localhost:5555    device
```

If you see `device` (not `unauthorized`), the bridge is active.

---

## Using ADB in OpenClaw Skills

Once the bridge is connected, your OpenClaw skills can call ADB commands to:

- `adb shell input tap 500 800` — tap a screen coordinate
- `adb shell input text "hello"` — type text into a focused field
- `adb shell input swipe 300 800 300 400 300` — swipe gesture
- `adb shell screencap -p /sdcard/screen.png` — take a screenshot
- `adb shell dumpsys window windows` — get current foreground app
- `adb shell am start -n com.package/.Activity` — launch an app

See [android-automation-agent](https://github.com/Mohd-Mursaleen/android-automation-agent) for a full working skill built on this.

---

## Notes

- The ADB connection resets on phone reboot. Re-run `adb connect localhost:5555` after restart.
- `adb tcpip 5555` only needs to be run once (survives reboots on most devices, but if it resets, reconnect USB and run it again).
- No root required for any of this.
