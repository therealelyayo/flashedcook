#!/bin/bash
set -e

# startVNC.sh - starts Xvfb, x11vnc, noVNC/websockify and Chromium
# Uses ENV RESOLUTION and USERAGENT from the container environment.

DISPLAY="${DISPLAY:-:0}"

# Choose X screen size
if [ -n "$RESOLUTION" ]; then
  SCREEN="$RESOLUTION"
  echo "Using RESOLUTION from env: $SCREEN"
else
  SCREEN="1920x1080x24"
  echo "No RESOLUTION set; using fallback: $SCREEN"
fi

# Ensure dbus machine-id exists
if [ ! -f /var/lib/dbus/machine-id ]; then
  dbus-uuidgen > /var/lib/dbus/machine-id || true
fi

# Start X virtual framebuffer
echo "Starting Xvfb on $DISPLAY -screen 0 $SCREEN"
Xvfb "$DISPLAY" -screen 0 "$SCREEN" &

# small wait for X to come up
sleep 1

export DISPLAY

# Start a lightweight session/window manager if available
if command -v xfce4-session >/dev/null 2>&1; then
  echo "Starting xfce4-session"
  xfce4-session &>/dev/null &
else
  # try a minimal window manager if you prefer (openbox, etc.) - optional
  echo "xfce4-session not found; continuing without full session"
fi

# Start x11vnc to serve the X display
echo "Starting x11vnc (listening on 5900)"
x11vnc -display "$DISPLAY" -nopw -forever -shared -rfbport 5900 &

# Start noVNC / websockify if present
if [ -d "$HOME/noVNC" ]; then
  cd "$HOME/noVNC"
  # Prefer bundled run script if present; otherwise fallback
  if [ -x utils/websockify/run ]; then
    echo "Starting websockify (bundled) to serve noVNC on 5980 -> localhost:5900"
    ./utils/websockify/run --web . 5980 localhost:5900 &
  else
    # attempt to run python wrapper
    echo "Starting websockify (python) to serve noVNC on 5980 -> localhost:5900"
    python3 utils/websockify/run --web . 5980 localhost:5900 &
  fi
else
  echo "noVNC not found at $HOME/noVNC; skipping web UI startup"
fi

# Build Chromium flags at runtime so USERAGENT and other envs can be used
DEFAULT_CHROMIUM_FLAGS="--disable-gpu --disable-software-rasterizer --disable-dev-shm-usage --start-maximized --no-sandbox --password-store=basic --noerrdialogs --no-first-run"
CHROMIUM_FLAGS="${CHROMIUM_FLAGS:-$DEFAULT_CHROMIUM_FLAGS}"

# Add USERAGENT at runtime if provided
if [ -n "$USERAGENT" ]; then
  # No extra quoting here so the final args are tokenized properly
  CHROMIUM_FLAGS="$CHROMIUM_FLAGS --user-agent=$USERAGENT"
  echo "Using USERAGENT: $USERAGENT"
fi

# Optionally open a URL on start; otherwise leave desktop for manual use
START_URL="${START_URL:-http://localhost:5980/vnc.html}"

# Start Chromium
if command -v chromium >/dev/null 2>&1; then
  echo "Launching Chromium: $START_URL"
  chromium $CHROMIUM_FLAGS "$START_URL" &>/dev/null &
else
  echo "Chromium not found; skipping browser launch"
fi

# Wait (keep container running)
wait