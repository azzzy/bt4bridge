# Quick Start: PG_BT4 Bridge Menu Bar App

## Installation (30 seconds)

```bash
# 1. Build the app bundle
./build_app.sh

# 2. Install to Applications
cp -r '.build/release/PG_BT4 Bridge.app' /Applications/

# 3. Launch the app
open '/Applications/PG_BT4 Bridge.app'
```

That's it! The app will appear in your menu bar (top-right, near the clock).

## First Time Setup

### Grant Bluetooth Permission

When you first launch the app, macOS will ask for Bluetooth permission:

1. Click "OK" to allow Bluetooth access
2. The app needs this to connect to your PG_BT4 device

### Connect Your Device

1. Turn on your PG_BT4 foot controller
2. Click the menu bar icon (🎧)
3. You'll see "Scanning for PG_BT4..." 
4. Within a few seconds, it will show "Connected ✅"

## Using the App

### Menu Bar Icon

The icon changes to show connection status:
- **Gray headphones** = Disconnected
- **Orange/Yellow headphones** = Scanning
- **Green/Colored headphones** = Connected

### Menu Overview

Click the icon to see:

```
🎧 PG_BT4 Bridge
├─ Status Section
│  ├─ Connection: Connected ✅
│  ├─ Device: PG_BT4  
│  ├─ Signal: -45 dBm (signal strength)
│  └─ MIDI: Active
├─────────────────
├─ LED Indicators (shows current state)
│  ├─ ● LED 1  ON  (red circle)
│  ├─ ○ LED 2  OFF (gray circle)
│  ├─ ● LED 3  ON
│  └─ ○ LED 4  OFF
├─────────────────
├─ Reconnect (force reconnection)
├─────────────────
├─ ☐ Launch at Login (start at boot)
├─ About PG_BT4 Bridge
└─ Quit PG_BT4 Bridge
```

## Using in Your DAW

### 1. Configure MIDI Input

In your DAW's MIDI preferences:
1. Enable **"PG_BT4 Bridge"** as an input device
2. The device will appear in your MIDI input list

### 2. Button Mapping

The 4 foot switches send these MIDI messages:
- **Button 1** → CC 80 (channel 1)
- **Button 2** → CC 81 (channel 1)  
- **Button 3** → CC 82 (channel 1)
- **Button 4** → CC 83 (channel 1)

Values: `127` when pressed, `0` when released

### 3. LED Control (NEW!)

You can control the LEDs from your DAW by sending MIDI to **"PG_BT4 Bridge"** output:

- **CC 16** → LED 1
- **CC 17** → LED 2
- **CC 18** → LED 3  
- **CC 19** → LED 4

Values:
- `0-63` = LED OFF
- `64-127` = LED ON

The menu will show the current LED states in real-time!

## Common Tasks

### Force Reconnect

If the device becomes unresponsive:
1. Click menu bar icon
2. Select "Reconnect"
3. App will disconnect and scan again

### Check Connection Quality

1. Open the menu
2. Look at "Signal:" line
3. Typical values:
   - `-30 to -50 dBm` = Excellent
   - `-50 to -70 dBm` = Good
   - `-70 to -90 dBm` = Fair (move closer)

### Monitor LED States

1. Send MIDI CC 16-19 from your DAW
2. Open the menu
3. LED indicators update in real-time:
   - Red ● = LED is ON
   - Gray ○ = LED is OFF

### Quit the App

1. Click menu bar icon
2. Select "Quit PG_BT4 Bridge"
3. App will cleanly disconnect and exit

## Troubleshooting

### Icon doesn't appear in menu bar

- Check if app is running: `ps aux | grep bt4bridge`
- Try quitting all instances and relaunching
- Check Console.app for error messages

### Device won't connect

1. Make sure PG_BT4 is powered on
2. Ensure no other app is connected to it (close phone apps!)
3. Try the "Reconnect" option
4. Check Bluetooth is enabled in System Preferences

### LED indicators not updating

1. Verify you're sending to "PG_BT4 Bridge" MIDI **output** (not input)
2. Use CC 16-19 (not 80-83)
3. Close and reopen the menu to refresh
4. Check DAW's MIDI monitor to verify messages are being sent

### MIDI not working in DAW

1. Verify "PG_BT4 Bridge" is enabled in DAW's MIDI preferences
2. Press a button and check for "RAW RX" in Console.app logs
3. Use your DAW's MIDI monitor to see incoming messages
4. Restart your DAW if you started it before the bridge

## Tips & Tricks

### Launch at Login

1. Check "Launch at Login" in the menu
2. App will start automatically when you log in
3. Note: Backend integration is still in progress

### Keep it Running

The app uses almost no resources when idle:
- <10MB memory
- 0% CPU when no MIDI activity
- Safe to leave running 24/7

### DAW Integration Examples

**Ableton Live**: Map buttons to scene triggers
**Logic Pro**: Assign to markers or automation
**Reaper**: Use for custom actions
**Any DAW**: Record automation for LED states!

## Getting Help

- Check the main README.md for detailed documentation
- See specs/002-menu-bar-application/ for technical details
- Open an issue on GitHub for bugs or questions

## What's Next?

Try these features:
1. ✅ Connect your PG_BT4
2. ✅ Map buttons in your DAW
3. ✅ Control LEDs from your DAW
4. ✅ Monitor LED states in the menu
5. ✅ Set up Launch at Login
6. ✅ Enjoy hands-free DAW control!

---

**Questions?** The menu bar app is a drop-in replacement for the CLI version - all the same features, plus a much nicer interface!
