# ShotShuttle — Remote Screenshot Agent (for lab/consented use)

ShotShuttle is a lightweight background agent that periodically captures desktop screenshots (full screen or active window) on X11/Wayland and forwards them to a designated host. It auto-detects the best available capture backend (scrot, gnome-screenshot, spectacle, grim), generates unique filenames, and streams images over TCP with timeouts and simple retry logic. The agent can self-daemonize or run as a user service, with clear logs for easy auditing and troubleshooting. Configuration is straightforward—intervals, backends, and host/port—making it handy for demos, QA, and lab automation. ShotShuttle is designed for lawful, informed, consented environments; do not deploy it for covert monitoring or on systems you do not own.

1. We need to obfuscate the the original bash scrip 'payload.sh'. For this purpose, we will make the archive 'payload_obf.sh'. You must have the tool 'Makeself' installed to make the archive.

Prepare a directory with your script:
mkdir -p ~/test_obf
cp /path/to/payload.sh ~/test_obf/
makeself ~/test_obf payload_obf.sh "My test archive" ./payload.sh
