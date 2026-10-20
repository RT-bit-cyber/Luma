# Contributing to Luma

Use an Apple silicon Mac and Xcode 26 or later. Clone this repository and open `Package.swift` in Xcode, or build from the terminal:

```sh
LUMA_APP_PATH="$PWD/dist/Luma.app" ./build.sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" swift test --disable-sandbox
```

Quit an existing app instance before replacing its bundle. Keep your installed app in a stable location when using launch at login.

Policy changes belong in `Sources/LumaCore` with focused tests in `Tests/LumaCoreTests`. Sensor access is isolated in `Sources/AmbientHardware`; the app and interface are in `Sources/Luma`.

For interface changes, inspect the actual app in both appearances and check the window edges, title bar and scrolling on a small display. A successful build does not establish that the live layout or hardware behaviour works. Keep missing sensor samples distinct from a valid zero-lux reading, and preserve the waiting period and separate switching thresholds.

Describe what changed and how you verified it in your pull request. Never commit preferences, credentials, signing certificates or private logs.
