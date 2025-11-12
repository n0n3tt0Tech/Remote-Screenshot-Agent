#!/usr/bin/env bash

# -------------------- Self-daemonize and single-instance lock --------------------
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script_path="$script_dir/$(basename -- "${BASH_SOURCE[0]}")"
if [[ "${1:-}" != "--daemon" ]]; then
  nohup "$script_path" --daemon >"$HOME/capture.log" 2>&1 & disown || true
  echo "[+] Spawned to background. Logs: $HOME/capture.log"
  exit 0
fi

set -euo pipefail
umask 077

mkdir -p "$HOME/.cache"
exec 9>"$HOME/.cache/capture.lock"
if ! flock -n 9; then
  echo "[i] Already running."
  exit 0
fi

# ---------------------------- CONFIG --------------------------------------------
INTERVAL=30
OUTDIR="$HOME/Pictures/Screenshots"

FOCUSED_WINDOW_ONLY=false
INCLUDE_POINTER=false

# Force a specific backend (optional): "gnome" | "spectacle" | "grim" | "scrot" | ""
BACKEND_OVERRIDE=""

# Use nc on the VM
REMOTE_ENABLE=true
REMOTE_METHOD="nc"
REMOTE_HOST="192.168.100.36"   # <- set to your host IP
REMOTE_PORT=9001
# --------------------------------------------------------------------------------

mkdir -p "$OUTDIR"

SESSION="${XDG_SESSION_TYPE:-}"
DESKTOP="$(printf '%s' "${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')"

have() { command -v "$1" >/dev/null 2>&1; }

# Prefer native Wayland/gui tools first; scrot last (often fails on Wayland)
pick_backend() {
  if [[ -n "$BACKEND_OVERRIDE" ]]; then
    echo "$BACKEND_OVERRIDE"; return
  fi
  if have gnome-screenshot; then echo "gnome"; return; fi
  if have spectacle; then echo "spectacle"; return; fi
  if have grim; then echo "grim"; return; fi
  if have scrot; then echo "scrot"; return; fi
  echo ""
}

capture_with_backend() {
  # $1=backend $2=filepath
  local b="$1" file="$2"
  case "$b" in
    scrot)
      local args=()
      [[ "$FOCUSED_WINDOW_ONLY" == true ]] && args+=("-u")
      [[ "$INCLUDE_POINTER" == true ]] && args+=("-p")
      scrot "${args[@]}" "$file"
      ;;
    gnome)
      local args=()
      [[ "$FOCUSED_WINDOW_ONLY" == true ]] && args+=("-w")
      [[ "$INCLUDE_POINTER" == true ]] && args+=("-p")
      gnome-screenshot "${args[@]}" -f "$file"
      ;;
    spectacle)
      local args=("-b" "-o" "$file")
      [[ "$FOCUSED_WINDOW_ONLY" == true ]] && args+=("-a")
      [[ "$INCLUDE_POINTER" == true ]] && args+=("--cursor")
      spectacle "${args[@]}"
      ;;
    grim)
      if [[ "$FOCUSED_WINDOW_ONLY" == true ]]; then
        echo "[i] Focused-window capture not available with grim without extra tools; capturing full screen."
      fi
      grim "$file"
      ;;
    *)
      return 1 ;;
  esac
}

send_remote() {
  [[ "$REMOTE_ENABLE" == true ]] || return 0
  local file="$1"
  # Detect nc variant; use the right flags and a timeout
  local help opts=()
  help="$(nc -h 2>&1 || true)"
  if grep -q ' -N ' <<<"$help"; then
    opts=(-N -w 5)      # OpenBSD nc
  else
    opts=(-w 5 -q 1)    # traditional/BusyBox nc
  fi
  if nc "${opts[@]}" "$REMOTE_HOST" "$REMOTE_PORT" < "$file"; then
    echo "[+] Sent via nc: $file"
    return 0
  else
    echo "[!] nc send failed: $file"
    return 1
  fi
}

screenshot_once() {
  # Build a list of backends to try: chosen one first, then fallbacks
  local primary; primary="$(pick_backend)"
  local backends=()
  if [[ -n "$primary" ]]; then backends+=("$primary"); fi
  # Append the rest (no duplicates)
  for b in gnome spectacle grim scrot; do
    [[ "$b" != "$primary" ]] && have "$b" && backends+=("$b")
  done
  if ((${#backends[@]}==0)); then
    echo "[!] No screenshot tool available."; return 1
  fi

  local b file sz ok=1
  for b in "${backends[@]}"; do
    file="$(mktemp "$OUTDIR/shot_$(date +%Y%m%d_%H%M%S)_${b}_XXXXXX.png")"
    if capture_with_backend "$b" "$file"; then
      sz=$(stat -c%s "$file" || echo 0)
      echo "[+] Saved ($b): $file (${sz} bytes)"
      if [[ "$sz" -gt 0 ]]; then
        [[ "$REMOTE_ENABLE" == true ]] && send_remote "$file" || true
        ok=0
        break
      else
        echo "[!] $b produced 0 bytes; removing and trying next backend."
        rm -f "$file" || true
      fi
    else
      echo "[!] $b failed to run; trying next."
      rm -f "$file" || true
    fi
  done

  return "$ok"
}

main() {
  echo "[dbg] DISPLAY=${DISPLAY:-unset} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset} XDG_SESSION_TYPE=${SESSION:-unset} DESKTOP=${DESKTOP:-unset} DBUS=${DBUS_SESSION_BUS_ADDRESS:-unset}"

  if [[ -z "$(pick_backend)" ]]; then
    echo "[!] No screenshot tool found. Try: sudo apt install gnome-screenshot spectacle grim scrot" >&2
    exit 1
  fi

  echo "[+] Saving to: $OUTDIR"
  echo "[+] Interval: ${INTERVAL}s"
  [[ "$REMOTE_ENABLE" == true ]] && echo "[+] Remote: nc -> $REMOTE_HOST:$REMOTE_PORT"

  trap 'echo; echo "[+] Stopped."; exit 0' INT

  sleep 2  # give session a moment

  while true; do
    if ! screenshot_once; then
      echo "[!] All backends failed this cycle."
    fi
    sleep "$INTERVAL"
  done
}

main "$@"
