# worse_query

### A sandbox escape for iOS 26.0 - 26.7.2 / 27.2.

This is a proof-of-concept for developers and isn't useful by itself.

worse_query is the direct successor to [bad_query](https://github.com/forcequitOS/bad_query) and essentially replaces it. To use worse_query, you'll have to set up an App Group container for your app.

worse_query can access these paths:

```
/var/containers/Data/System (iOS 27)
/var/containers/Shared/SystemGroup/* (iOS 27)
/var/mobile/Containers/Data/Application/*
/var/mobile/Containers/Data/InternalDaemon/*
/var/mobile/Containers/Data/PluginKitPlugin/*
/var/mobile/Containers/Shared/AppGroup/*
/var/mobile/Containers/Shared/AppGroup (iOS 27)
```

<sub>**This is not relevant to a jailbreak and never will be.** Please don't mislead people into believing otherwise.</sub>

---

## Fork additions: file browser UI

This fork adds a browser front-end on top of the exploit, so you can inspect other apps' data containers without copy-pasting paths out of a log:

- **Browser tab**: "Scan for Apps" brute-forces inode → path via `fsgetpath` (`pathleak`), resolves each container's bundle ID + display name from its metadata, then tap-to-browse with `FileManager`. Roots section covers App Groups, PluginKit, InternalDaemon, SystemGroup and System paths. Search by name or bundle ID.
- **File detail**: metadata, text/plist preview, copy path, share/export.
- **Tools tab**: the original path/consume/release + enumeration + live log.
- The App Group ID is read from the app's own signature entitlements at runtime — the same binary works under any signer's group.

### Requirements

- A **paid** Apple Developer account — the exploit needs an App Group entitlement; free accounts can't provision one.
- Physical iOS device on 26.0–26.7.2 or 27.x, Developer Mode on, dev cert trusted.

### Build / install without a Mac

The `Build` GitHub Action produces an unsigned `worse_query-unsigned.ipa` artifact. To use it from Linux (or any OS):

```bash
# 1. Register your own App ID + App Group in the Apple developer portal,
#    create a development provisioning profile for them.
# 2. Re-sign with your identity + your group ID:
zsign -k dev.p12 -m profile.mobileprovision \
      -e entitlements.plist worse_query-unsigned.ipa

# 3. Install + launch:
ideviceinstaller -i worse_query-unsigned.ipa
# or: pymobiledevice3 apps install worse_query-unsigned.ipa
```

`entitlements.plist` here just needs `com.apple.security.application-groups` containing *your* group ID — the app picks it up at runtime.

### Enabling Developer Mode (CLI)

```bash
# Reveal the toggle in Settings (one-time, before it shows up):
idevicedevmodectl reveal

# Check status:
idevicedevmodectl list

# Enable remotely — only works with NO passcode set:
idevicedevmodectl enable

# With a passcode, do it on the device instead:
# Settings → Privacy & Security → Developer Mode → reboot → tap "Turn On"
```