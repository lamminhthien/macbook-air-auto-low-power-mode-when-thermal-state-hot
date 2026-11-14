# thermal-lpm

A bash script for macOS that automatically turns on **Low Power Mode** when the Mac heats up and turns it off when the Mac cools down. Useful for MacBook Air (which has no fan) or whenever you want the machine to shed heat earlier.

## Screenshot
We can check the Thermal State with tool hot from https://github.com/macmade/Hot
<img width="947" height="718" alt="image" src="https://github.com/user-attachments/assets/77efd681-1eae-4370-b62c-5c20cf11244d" />


## How it works

The script reads the Mac's thermal pressure level through `notifyutil` and checks it every few seconds:

- When the level is **>= the ON threshold** (default `1`), it enables Low Power Mode with `pmset`.
- When the level is **<= the OFF threshold** (default `0`), it disables Low Power Mode.
- After each change, the script waits at least `MIN_HOLD` seconds before changing again, to avoid rapid on/off toggling when the temperature hovers around a threshold.
- When the script stops (Ctrl+C or the service is removed), Low Power Mode is restored to the state it had when the script started.

## Requirements

- macOS (tested on MacBook Air)
- `sudo` privileges to change Low Power Mode

## Installation

1. Save the script as `thermal-lpm.sh` and make it executable:

   ```bash
   chmod +x thermal-lpm.sh
   ```

2. Check the current thermal level (no sudo needed):

   ```bash
   ./thermal-lpm.sh --probe
   ```

## Manual usage

Run it directly in Terminal (press Ctrl+C to stop):

```bash
sudo ./thermal-lpm.sh
```

Custom thresholds and timing:

```bash
sudo ./thermal-lpm.sh --on 2 --off 0 --interval 10 --hold 60
```

| Option       | Default | Meaning                                                  |
|--------------|---------|----------------------------------------------------------|
| `--on`       | `1`     | Enable Low Power Mode when the level is >= this value    |
| `--off`      | `0`     | Disable Low Power Mode when the level is <= this value   |
| `--interval` | `10`    | Seconds between checks                                   |
| `--hold`     | `60`    | Minimum seconds between two Low Power Mode changes       |
| `--probe`    | —       | Print the current thermal level and LPM state, then exit |

## Running automatically at boot

The script can be installed as a LaunchDaemon so it starts as soon as the Mac boots, even before you log in.

1. Copy the script to a system location:

   ```bash
   sudo mkdir -p /usr/local/bin
   sudo cp thermal-lpm.sh /usr/local/bin/thermal-lpm
   sudo chown root:wheel /usr/local/bin/thermal-lpm
   sudo chmod 755 /usr/local/bin/thermal-lpm
   ```

2. Create `/Library/LaunchDaemons/com.thermal-lpm.plist` with this content:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>com.thermal-lpm</string>
       <key>ProgramArguments</key>
       <array>
           <string>/usr/local/bin/thermal-lpm</string>
       </array>
       <key>RunAtLoad</key>
       <true/>
       <key>KeepAlive</key>
       <true/>
       <key>StandardOutPath</key>
       <string>/var/log/thermal-lpm.log</string>
       <key>StandardErrorPath</key>
       <string>/var/log/thermal-lpm.err</string>
   </dict>
   </plist>
   ```

   Set the permissions:

   ```bash
   sudo chown root:wheel /Library/LaunchDaemons/com.thermal-lpm.plist
   sudo chmod 644 /Library/LaunchDaemons/com.thermal-lpm.plist
   ```

3. Load the service:

   ```bash
   sudo launchctl bootstrap system /Library/LaunchDaemons/com.thermal-lpm.plist
   ```

## Verifying it works

Watch the log in real time:

```bash
tail -f /var/log/thermal-lpm.log
```

Check that the service is running:

```bash
sudo launchctl print system/com.thermal-lpm | head -20
```

## Updating the script

After editing `thermal-lpm.sh`, copy it again and reload the service:

```bash
sudo cp thermal-lpm.sh /usr/local/bin/thermal-lpm
sudo chown root:wheel /usr/local/bin/thermal-lpm
sudo chmod 755 /usr/local/bin/thermal-lpm
sudo launchctl bootout system/com.thermal-lpm
sudo launchctl bootstrap system /Library/LaunchDaemons/com.thermal-lpm.plist
```

## Uninstalling

```bash
sudo launchctl bootout system/com.thermal-lpm
sudo rm /Library/LaunchDaemons/com.thermal-lpm.plist
sudo rm /usr/local/bin/thermal-lpm
```

To remove the logs as well:

```bash
sudo rm /var/log/thermal-lpm.log /var/log/thermal-lpm.err
```

## Troubleshooting

**"Please run with sudo" message**
Changing Low Power Mode requires root privileges. Run the script with `sudo`.

**Low Power Mode keeps toggling on and off**
Increase `--hold` (for example `120`), or set `--off` lower than `--on` to leave a buffer zone, for example `--on 1 --off 0`.

**`--probe` prints no thermal level**
Check whether `notifyutil -g com.apple.system.thermalpressurelevel` returns a number. If it doesn't, your macOS version may not expose this key.

**Service doesn't run after reboot**
Check `/var/log/thermal-lpm.err` for errors. Make sure the plist is owned by `root:wheel` with mode `644`.

## Notes

- The default ON threshold of `1` was chosen for MacBook Air based on initial observation. If your machine behaves differently, use `--probe` to check and adjust.
- When the Mac shuts down or restarts, the script stops and Low Power Mode is restored to the state it had at that moment. When the Mac starts again, the script records the current state and resumes.
