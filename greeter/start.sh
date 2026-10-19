#!/bin/bash
# greetd's default_session: the greeter in cage, on the GPU the firmware booted on (boot_vga; cardN can change between
# boots). -d: no Qt title bar; -s keeps Ctrl+Alt+Fn working.
for c in /sys/class/drm/card[0-9]*; do
    [ "$(cat "$c/device/boot_vga" 2>/dev/null)" = 1 ] && export WLR_DRM_DEVICES="/dev/dri/${c##*/}"
done
# Output to the journal (cts1-greeter), not the VT.
exec systemd-cat --identifier=cts1-greeter -- cage -d -s -- qs -p "$(dirname "$(readlink -f "$0")")"
