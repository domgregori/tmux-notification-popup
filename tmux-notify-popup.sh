#!/usr/bin/env bash
# tmux-notify-popup: janky notifications using tmux display-popup
# Usage: tmux-notify-popup -m "Message..." [-l 40] [-d 3] [-t "Title"]
# -l LEN    wrap width (default 30)
# -d SEC    auto-clear delay in seconds (default 3)
# -c        center text (default; use -C to disable)
# -T COLOR  text color name or #RRGGBB
# -B COLOR  background color name or #RRGGBB
# -t TITLE  popup title (default "Notification")

set -euo pipefail

LEN=30
DELAY=3
MSG="Notification"
CENTER=true
TITLE=""
TEXT_COLOR=""
BG_COLOR=""
ESC_START=""
ESC_RESET=""
ESC_FG=""
ESC_BG=""

pick_color() {
  if [[ $1 =~ ^#?[0-9A-Fa-f]{6}$ ]]; then
    printf '#%s\n' "${1#\#}"
    return 0
  fi

  case "$1" in
  red) echo "#cc4444" ;;
  light-red) echo "#ff6666" ;;
  yellow) echo "#ccaa33" ;;
  light-yellow) echo "#ffee66" ;;
  green) echo "#44aa44" ;;
  light-green) echo "#66ff99" ;;
  magenta) echo "#aa44aa" ;;
  light-magenta) echo "#ff88ff" ;;
  blue) echo "#4477cc" ;;
  light-blue) echo "#66aaff" ;;
  cyan) echo "#44aaaa" ;;
  light-cyan) echo "#77ffff" ;;
  grey) echo "#777777" ;;
  light-grey) echo "#bbbbbb" ;;
  white) echo "#dddddd" ;;
  black) echo "#111111" ;;
  *)
    printf 'Unknown color: %s\n' "$1" >&2
    exit 2
    ;;
  esac
}

hex_to_rgb() {
  local h="${1#\#}"
  printf "%d;%d;%d" "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

while getopts ":m:l:d:cCT:B:t:" opt; do
  case "$opt" in
  m) MSG="$OPTARG" ;;
  l) LEN="$OPTARG" ;;
  d) DELAY="$OPTARG" ;;
  c) CENTER=true ;;
  C) CENTER=false ;;
  T) TEXT_COLOR="$OPTARG" ;;
  B) BG_COLOR="$OPTARG" ;;
  t) TITLE="$OPTARG" ;;
  :)
    printf 'Option -%s requires an argument\n' "$OPTARG" >&2
    exit 1
    ;;
  \?)
    printf 'Unknown option: -%s\n' "$OPTARG" >&2
    exit 1
    ;;
  esac
done

# Pick colors
if [[ -n $BG_COLOR ]]; then
  BG_HEX="$(pick_color "$BG_COLOR")"
  BG_RGB=$(hex_to_rgb "$BG_HEX")
  printf -v ESC_BG "%b" "\e[48;2;${BG_RGB}m"
  ESC_RESET=${ESC_RESET:-$'\e[0m'}
fi

if [[ -n $TEXT_COLOR ]]; then
  TEXT_HEX="$(pick_color "$TEXT_COLOR")"
  TEXT_RGB=$(hex_to_rgb "$TEXT_HEX")
  printf -v ESC_FG "%b" "\e[38;2;${TEXT_RGB}m"
  ESC_RESET=${ESC_RESET:-$'\e[0m'}
fi

if [[ -n $ESC_FG || -n $ESC_BG ]]; then
  ESC_START="${ESC_FG}${ESC_BG}"
fi

# Wrap and center lines
mapfile -t RAW_LINES < <(printf "%s" "$MSG" | fold -s -w "$LEN")
if ((${#RAW_LINES[@]} == 0)); then
  RAW_LINES=(" ")
fi
LINES=()
for line in "${RAW_LINES[@]}"; do
  if $CENTER; then
    pad=$(((LEN - ${#line}) / 2))
    ((pad < 0)) && pad=0
    line="$(printf "%*s%s" "$pad" "" "$line")"
  fi
  LINES+=("${ESC_START}$(printf "%-${LEN}s" "$line")${ESC_RESET}")
done

# Dimensions (tiny padding)
WIDTH=$((LEN + 2))
HEIGHT=$((${#LINES[@]} + 2))

if ! CLIENT_WIDTH=$(tmux display-message -p '#{client_width}' 2>/dev/null); then
  printf 'tmux-notify-popup: must be run inside an active tmux client\n' >&2
  exit 1
fi

X_POS=$((CLIENT_WIDTH - WIDTH - 1))
((X_POS < 0)) && X_POS=0

CONTENT=$(printf "%s\n" "${LINES[@]}")

# Open popup at top-right; keep the command alive until we clear it
tmux display-popup -b "rounded" -T "$TITLE" -x "$X_POS" -y 0 -w "$WIDTH" -h "$HEIGHT" \
  "printf '%s\n' \"$CONTENT\"; sleep 9999" &

# Auto-clear after delay
(
  sleep "$DELAY"
  tmux display-popup -C
) >/dev/null 2>&1 &
