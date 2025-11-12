#!/usr/bin/env bash
# run_makeself_home.sh
# Usage: ./run_makeself_home.sh [path-to-archive]
# Default archive: $HOME/test_obf.sh
set -euo pipefail

ARCHIVE="${1:-$HOME/test_obf.sh}"

if [[ ! -f "$ARCHIVE" ]]; then
    echo "Archive not found: $ARCHIVE" >/dev/null 2>&1
    exit 2
fi

chmod +x "$ARCHIVE"

EXTRACT_DIR="$HOME/makeself_extracted_$(date +%s)"
mkdir -p "$EXTRACT_DIR"
LOGFILE="$EXTRACT_DIR/run_$(basename "$ARCHIVE" .sh).log"

# Try --noexec first, capture its output to the logfile
if bash "$ARCHIVE" --noexec --target "$EXTRACT_DIR" >>"$LOGFILE" 2>&1; then
    echo "Extraction via --noexec succeeded." >> "$LOGFILE"
else
    echo "Archive doesn't support --noexec or failed; extracting normally (see $LOGFILE)..." >> "$LOGFILE"
    bash "$ARCHIVE" --target "$EXTRACT_DIR" >>"$LOGFILE" 2>&1
fi

# Detect candidate startup script (prefer test.sh)
CAND="$EXTRACT_DIR/test.sh"
if [[ ! -f "$CAND" ]]; then
    CAND=$(find "$EXTRACT_DIR" -maxdepth 1 -type f -executable | head -n1 || true)
fi

if [[ -z "$CAND" ]]; then
    echo "No startup script found. Inspect $EXTRACT_DIR manually." >> "$LOGFILE"
    exit 4
fi

chmod +x "$CAND"

# Suppress all output by redirecting to /dev/null
(
    cd "$EXTRACT_DIR"
    # Run the startup script in background with nohup, redirect all output to /dev/null
    nohup "./$(basename "$CAND")" >> /dev/null 2>&1 &
    CHILD_PID=$!
    # Optionally log the PID to the log file
    echo "Launched $(basename "$CAND") pid=$CHILD_PID" >> "$LOGFILE"
)

# Print success message to console, but suppress everything else
echo "Run successfully done."

exit 0
