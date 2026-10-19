#!/bin/bash
# sync.sh USER (root, run by cts1-greeter-sync@USER.service): copy the user's scheme and wallpaper to
# /var/lib/cts1-greeter. The user's files are read AS THE USER (setpriv), so a symlink can't make root copy what the
# user couldn't read. Needs jq.
set -eu

user=${1:?usage: sync.sh USER}
home=$(getent passwd "$user" | cut -d: -f6)
[ -n "$home" ] && [ "$home" != / ] || { echo "sync: no home folder for $user" >&2; exit 1; }
state=$home/.local/state/cts1
out=/var/lib/cts1-greeter
max_image=$((50 * 1024 * 1024))

as_user() {
    setpriv --reuid="$user" --regid="$(id -g "$user")" --init-groups -- "$@"
}

install -d -m 755 "$out"
tmp=$(mktemp -d "$out/.sync.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# scheme.json -> the theme's keys (the SDDM theme's theme.conf mapping).
colours='{}'
if as_user cat "$state/scheme.json" > "$tmp/scheme.json" 2>/dev/null; then
    colours=$(jq -c '.colours | {
        background: ("#" + .background),
        mainCard: ("#" + .background),
        subComponents: ("#" + .surfaceContainer),
        text: ("#" + .text),
        primary: ("#" + .primary_paletteKeyColor),
        textOnPrimary: ("#" + .onPrimary),
        secondary: ("#" + .secondary),
        textOnSecondary: ("#" + .onSecondary),
        tertiary: ("#" + .tertiary),
        inverseOnSurface: ("#" + .inverseOnSurface),
        surfaceContainerHigh: ("#" + .surfaceContainerHigh),
        outline: ("#" + .outline),
        error: ("#" + .error),
        m3primary: ("#" + .primary),
        secondaryContainer: ("#" + .secondaryContainer),
        textOnSurfaceVariant: ("#" + .onSurfaceVariant),
        surfaceContainerHighest: ("#" + .surfaceContainerHighest)
    } | with_entries(select(.value | test("^#[0-9a-fA-F]{6}$")))' "$tmp/scheme.json") || colours='{}'
else
    echo "sync: no readable $state/scheme.json; greeter keeps its default colors" >&2
fi

# The wallpaper wallpaper-set saved, copied as wallpaper.<ext>.
wallpaper=""
ext=""
src=$(as_user cat "$state/wallpaper" 2>/dev/null | head -n 1 || true)
if [ -n "$src" ]; then
    ext=$(printf '%s' "${src##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
    jpg | jpeg | png | webp | gif | bmp) max=$max_image ;;
    *) ext="" ;;
    esac
    if [ -n "$ext" ] && as_user head -c $((max + 1)) -- "$src" > "$tmp/wallpaper.$ext" 2>/dev/null \
        && [ "$(stat -c %s "$tmp/wallpaper.$ext")" -le "$max" ] && [ -s "$tmp/wallpaper.$ext" ]; then
        wallpaper="$out/wallpaper.$ext"
    else
        rm -f "$tmp/wallpaper.$ext"
        echo "sync: wallpaper $src unreadable, too big or not a picture; greeter keeps the old one" >&2
        wallpaper=$(ls "$out"/wallpaper.* 2>/dev/null | head -n 1 || true)
    fi
fi

jq -n --argjson c "$colours" --arg w "$wallpaper" '$c + (if $w == "" then {} else {wallpaper: $w} end)' > "$tmp/config.json"

# Swap in; the greeter re-reads config.json when it changes.
chmod 644 "$tmp"/*
if [ -f "$tmp/wallpaper.$ext" ] 2>/dev/null; then
    for old in "$out"/wallpaper.*; do
        [ -e "$old" ] && [ "$old" != "$out/wallpaper.$ext" ] && rm -f "$old"
    done
    mv -f "$tmp/wallpaper.$ext" "$out/wallpaper.$ext"
fi
mv -f "$tmp/config.json" "$out/config.json"
echo "sync: greeter updated from $user's CTS1 scheme${wallpaper:+ and wallpaper}"
