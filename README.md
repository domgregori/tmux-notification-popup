# tmux-notify-popup

`tmux-notify-popup.sh` is a lightweight helper that turns `tmux display-popup` into a quick notification panel. Pipe text into it or pass a message with flags and it renders a styled popup in the current tmux client.

## Requirements

- tmux ≥ 3.2 with `display-popup` support.
- Run the script from inside an attached tmux client.

Install by placing `tmux-notify-popup.sh` somewhere on your `$PATH` and making it executable:

```sh
chmod +x /path/to/tmux-notify-popup.sh
```

## Usage

```
tmux-notify-popup.sh -m "Message" [options]

Options:
  -m TEXT    Message body; omit to read from stdin
  -l LEN     Wrap width (default 30, accepts percentages like 40%)
  -d SEC     Auto-dismiss delay in seconds (default 3, 0 keeps it open)
  -C         Do not center the wrapped lines
  -c COLOR   Text color name or #RRGGBB
  -b COLOR   Popup background color name or #RRGGBB
  -B COLOR   Border color name or #RRGGBB
  -i ICON    Icon/emoji to render next to the message
  -I POS     Icon position: `left` (default) or `right`
  -t TITLE   Popup title (default "Notification")
  -x POS     Horizontal position (`C`, `R`, `P`, `M`, `W`, percentage, or absolute)
  -y POS     Vertical position (`C`, `P`, `M`, `S`, percentage, or absolute)
  -h         Show inline help

Position shortcuts mirror tmux’s popup coordinates:
  C centre of the terminal, R right edge, P pane origin, M mouse position,
  W window position on the status line, S line adjacent to the status line, n% percentages.

Predefined color names:
  red light-red yellow light-yellow green light-green
  magenta light-magenta blue light-blue cyan light-cyan
  grey light-grey gray light-gray white black
```

Any `#RRGGBB` value is accepted for colors.

## Examples

**Basic notification (piped input):**

```sh
echo "Build finished successfully" | tmux-notify-popup.sh
```

**Custom colors and title:**

```sh
tmux-notify-popup.sh -m "Tests failed" \
  -c white -b "#a60000" -B green -t "CI Alert"
```

**Add an icon on the right and keep it open until dismissed:**

```sh
tmux-notify-popup.sh -m "Deployment complete" \
  -i ✅ -I right -d 0
```

**Percentage width and explicit positioning:**

```sh
tmux-notify-popup.sh -m "Lunch in 10" -l 40% -x C -y 10
```

**Show command output safely:**

```sh
git status --short | tmux-notify-popup.sh -l 50 -t "Repo status"
```

## Tips

- Combine with cron jobs, Git hooks, CI scripts, or any shell pipeline to surface quick status messages in tmux.
- Trigger the script multiple times for multiple popups; each one auto-clears after the configured delay.
- Use `-d 0` to leave the popup until you close it manually (`Esc` by default).
