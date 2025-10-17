#!/usr/bin/env bash
# tmux-notify-popup: janky notifications using tmux display-popup
# Usage: tmux-notify-popup -m "Message..." [-l 40] [-d 3] [-t "Title"]
# -l LEN    wrap width (default 30, accepts e.g. 40%)
# -d SEC    auto-clear delay in seconds (default 3)
# -c        center text (default; use -C to disable)
# -T COLOR  text color name or #RRGGBB
# -B COLOR  background color name or #RRGGBB
# -i ICON   emoji or string placed top-left of popup
# -I POS    icon position: left (default) or right
# -t TITLE  popup title (default "Notification")
# stdin     message content (used when -m not supplied)

set -euo pipefail

LEN_SPEC=30
LEN=30
DELAY=3
MSG="Notification"
CENTER=true
TITLE=""
TEXT_COLOR=""
BG_COLOR=""
ICON=""
ICON_POSITION="left"
MSG_SET=false
STYLE_PREFIX=""
STYLE_SUFFIX=""

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

setup_icon_padding() {
  ICON_PAD_WIDTH=0
  ICON_PREFIX_FIRST=""
  ICON_PREFIX_OTHER=""
  ICON_SUFFIX_FIRST=""
  ICON_SUFFIX_OTHER=""

  [[ -z $ICON ]] && return

  ICON_WIDTH=2
  ICON_PAD_WIDTH=$((ICON_WIDTH + 1))

  local icon_space icon_pad space_before_icon
  icon_space=$(printf "%*s" "$ICON_PAD_WIDTH" "")
  space_before_icon=$(printf "%*s" "$((ICON_PAD_WIDTH - ICON_WIDTH))" "")
  icon_pad="${ICON} "

  case "$ICON_POSITION" in
  right)
    ICON_PREFIX_FIRST=""
    ICON_PREFIX_OTHER=""
    ICON_SUFFIX_FIRST="${space_before_icon}${ICON}"
    ICON_SUFFIX_OTHER="$icon_space"
    ;;
  *)
    ICON_PREFIX_FIRST="$icon_pad"
    ICON_PREFIX_OTHER="$icon_space"
    ICON_SUFFIX_FIRST=""
    ICON_SUFFIX_OTHER=""
    ;;
  esac
}

while getopts ":m:l:d:cCT:B:t:i:I:" opt; do
  case "$opt" in
  m)
    MSG="$OPTARG"
    MSG_SET=true
    ;;
  l) LEN_SPEC="$OPTARG" ;;
  d) DELAY="$OPTARG" ;;
  c) CENTER=true ;;
  C) CENTER=false ;;
  T) TEXT_COLOR="$OPTARG" ;;
  B) BG_COLOR="$OPTARG" ;;
  t) TITLE="$OPTARG" ;;
  i) ICON="$OPTARG" ;;
  I) ICON_POSITION="$OPTARG" ;;
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

if ! $MSG_SET && [[ ! -t 0 ]]; then
  READ_STDIN="$(cat)"
  if [[ -n $READ_STDIN ]]; then
    MSG="$READ_STDIN"
    MSG_SET=true
  fi
fi

if ! CLIENT_WIDTH=$(tmux display-message -p '#{client_width}' 2>/dev/null); then
  printf 'tmux-notify-popup: must be run inside an active tmux client\n' >&2
  exit 1
fi

case "$ICON_POSITION" in
left | right) ;;
*)
  printf 'Invalid icon position: %s (use "left" or "right")\n' "$ICON_POSITION" >&2
  exit 1
  ;;
esac

if [[ $LEN_SPEC =~ ^([0-9]+)%$ ]]; then
  PERCENT_VALUE=${BASH_REMATCH[1]}
  LEN=$((CLIENT_WIDTH * PERCENT_VALUE / 100))
  ((LEN < 1)) && LEN=1
elif [[ $LEN_SPEC =~ ^[0-9]+$ ]]; then
  LEN=$LEN_SPEC
  ((LEN < 1)) && LEN=1
else
  printf 'Invalid length: %s\n' "$LEN_SPEC" >&2
  exit 1
fi

# Pick colors
if [[ -n $TEXT_COLOR ]]; then
  STYLE_PREFIX+=$(printf '\e[38;2;%sm' "$(hex_to_rgb "$(pick_color "$TEXT_COLOR")")")
fi

if [[ -n $BG_COLOR ]]; then
  STYLE_PREFIX+=$(printf '\e[48;2;%sm' "$(hex_to_rgb "$(pick_color "$BG_COLOR")")")
fi

if [[ -n $STYLE_PREFIX ]]; then
  STYLE_SUFFIX=$'\e[0m'
fi

HIDE_CURSOR=$(printf '\e[?25l')

setup_icon_padding

# Wrap and center lines
mapfile -t RAW_LINES < <(printf "%s" "$MSG" | fold -s -w "$LEN")
if ((${#RAW_LINES[@]} == 0)); then
  RAW_LINES=(" ")
fi
LINES=()
for idx in "${!RAW_LINES[@]}"; do
  line="${RAW_LINES[$idx]}"
  if $CENTER; then
    line_len=${#line}
    pad=$(((LEN - line_len) / 2))
    ((pad < 0)) && pad=0
    line="$(printf "%*s%s" "$pad" "" "$line")"
  fi
  line="$(printf "%-${LEN}s" "$line")"
  if [[ -n $ICON ]]; then
    if ((idx == 0)); then
      prefix="$ICON_PREFIX_FIRST"
      suffix="$ICON_SUFFIX_FIRST"
    else
      prefix="$ICON_PREFIX_OTHER"
      suffix="$ICON_SUFFIX_OTHER"
    fi
  else
    prefix=""
    suffix=""
  fi
  LINES+=("${HIDE_CURSOR}${STYLE_PREFIX}${prefix}${line}${suffix}${STYLE_SUFFIX}")
done

# Dimensions (tiny padding)
WIDTH=$((LEN + ICON_PAD_WIDTH + 2))
HEIGHT=$((${#LINES[@]} + 2))

X_POS=$((CLIENT_WIDTH - WIDTH - 1))
((X_POS < 0)) && X_POS=0

CONTENT=$( (
  IFS=$'\n'
  printf "%s" "${LINES[*]}"
))

# Open popup at top-right; keep the command alive until we clear it
tmux display-popup -b "rounded" -T "$TITLE" -x "$X_POS" -y 0 -w "$WIDTH" -h "$HEIGHT" \
  "printf '%s' \"$CONTENT\";  sleep 9999" &

# Auto-clear after delay
if [[ $DELAY -gt 0 ]]; then
  (
    sleep "$DELAY"
    tmux display-popup -C
  ) >/dev/null 2>&1 &
fi
