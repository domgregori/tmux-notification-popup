#!/usr/bin/env bash
# tmux-notify-popup: janky notifications using tmux display-popup
# Usage: tmux-notify-popup -m "Message..." [-l 40] [-d 3] [-t "Title"]
# -l LEN    wrap width (default 30, accepts e.g. 40%)
# -d SEC    auto-clear delay in seconds (default 3)
# -C        don't center text
# -c COLOR  text color name or #RRGGBB
# -b COLOR  background color name or #RRGGBB
# -B COLOR  border color name or #RRGGBB
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
BORDER_COLOR=""
ICON=""
ICON_POSITION="left"
MSG_SET=false
BORDER_STYLE=""
POPUP_STYLE=""

pick_color() {
  if [[ $1 =~ ^#?[0-9A-Fa-f]{6}$ ]]; then
    printf '#%s\n' "${1#\#}"
    return 0
  fi

  case "$1" in
  red) echo "#d20f39" ;;
  light-red) echo "#e78284" ;;
  yellow) echo "#df8e1d" ;;
  light-yellow) echo "#e5c890" ;;
  green) echo "#40a02b" ;;
  light-green) echo "#a6d189" ;;
  magenta) echo "#e64553" ;;
  light-magenta) echo "#ea999c" ;;
  blue) echo "#1e66f5" ;;
  light-blue) echo "#8caaee" ;;
  cyan) echo "#04a5e5" ;;
  light-cyan) echo "#99d1db" ;;
  grey) echo "#6c6f85" ;;
  light-grey) echo "#a5adce" ;;
  gray) echo "#6c6f85" ;;
  light-gray) echo "#a5adce" ;;
  white) echo "#c6d0f5" ;;
  black) echo "#181926" ;;
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

while getopts ":m:l:d:Cc:b:B:t:i:I:" opt; do
  case "$opt" in
  m)
    MSG="$OPTARG"
    MSG_SET=true
    ;;
  l) LEN_SPEC="$OPTARG" ;;
  d) DELAY="$OPTARG" ;;
  C) CENTER=false ;;
  c) TEXT_COLOR="$OPTARG" ;;
  b) BG_COLOR="$OPTARG" ;;
  B) BORDER_COLOR="$OPTARG" ;;
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
POPUP_STYLE=""
if [[ -n $BG_COLOR ]]; then
  POPUP_STYLE="bg=$(pick_color "$BG_COLOR")"
fi
if [[ -n $TEXT_COLOR ]]; then
  if [[ -n $POPUP_STYLE ]]; then
    POPUP_STYLE+=",fg=$(pick_color "$TEXT_COLOR")"
  else
    POPUP_STYLE="fg=$(pick_color "$TEXT_COLOR")"
  fi
fi

BORDER_STYLE=""
if [[ -n $BORDER_COLOR ]]; then
  BORDER_HEX="$(pick_color "$BORDER_COLOR")"
  BORDER_STYLE="fg=${BORDER_HEX}"
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
  LINES+=("${HIDE_CURSOR}${prefix}${line}${suffix}")
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

DISPLAY_ARGS=(-b "rounded" -T "$TITLE" -x "$X_POS" -y 0 -w "$WIDTH" -h "$HEIGHT")
if [[ -n $POPUP_STYLE ]]; then
  DISPLAY_ARGS+=(-s "$POPUP_STYLE")
fi
if [[ -n $BORDER_STYLE ]]; then
  DISPLAY_ARGS+=(-S "$BORDER_STYLE")
fi

DISPLAY_CMD=('sh' '-c' 'printf %s "$1"; sleep 9999' 'tmux-notify' "$CONTENT")
tmux display-popup "${DISPLAY_ARGS[@]}" "${DISPLAY_CMD[@]}" &

# Auto-clear after delay
if [[ $DELAY -gt 0 ]]; then
  (
    sleep "$DELAY"
    tmux display-popup -C
  ) >/dev/null 2>&1 &
fi
