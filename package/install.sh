#!/usr/bin/env bash
# CTS1 installer, for Arch, CachyOS, Fedora and Debian. Run it as yourself (not root) from the clone:
#
#   package/install.sh --check          what is done and what is left; changes nothing
#   package/install.sh                  every step that is not done yet, in order
#   package/install.sh darkmode configs only these steps
#   package/install.sh --list           the steps
#
# Each step first checks the system and skips itself when it is already done, so it is safe to run again.
# Configs of yours that it would replace are listed first, with one question for all of them; there is no backup.
# It stops (exit 2) where you have to act, for example installing what your distro doesn't package. It never
# updates the system and never changes which login screen runs (README.md, Login screen).
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
CHECK=0
source "$REPO/package/packages.sh"

STEPS=(preflight packages darkmode configs session greeter verify)
declare -A ABOUT=(
    [preflight]="user, distro and clone path (check only)"
    [packages]="CTS1's packages (and what your distro doesn't package)"
    [darkmode]="dark GTK and Qt apps: GTK settings, gsettings, qtengine"
    [configs]="Kitty and fastfetch configs"
    [session]="the sway session entry for the login screen, login record (utmp group)"
    [greeter]="CTS1's login screen files, the greeter's home folder, color sync"
    [verify]="final checks (check only)"
)

# ---------- helpers ----------

say()  { printf '%s\n' "$*"; }
section() { printf '\n== %s: %s\n' "$1" "${ABOUT[$1]}"; }
warn() { printf '   ! %s\n' "$*" >&2; }
die()  { printf '   x %s\n' "$*" >&2; exit 1; }
# Stop here; the user acts, then runs it again.
stop() { printf '\n-> %s\n   Then run %s again.\n' "$*" "$REPO/package/install.sh"; exit 2; }
run()  { say "   \$ $*"; "$@"; }
# sudo -A when a password dialog is set up (SUDO_ASKPASS), plain sudo otherwise.
root() { say "   \$ sudo $*"; if [[ -n ${SUDO_ASKPASS:-} ]]; then sudo -A "$@"; else sudo "$@"; fi; }

DISTRO=$(. /etc/os-release && printf '%s' "${ID:-}")
case $DISTRO in
    arch|cachyos) FAMILY=arch ;;
    fedora|debian) FAMILY=$DISTRO ;;
    *) FAMILY= ;;
esac

# ---------- packages ----------

missing_pkgs() {
    case $FAMILY in
        arch) pacman -T "$@" || true ;;
        fedora) local p; for p in "$@"; do rpm -q "$p" >/dev/null 2>&1 || printf '%s\n' "$p"; done ;;
        debian) local p; for p in "$@"; do
                    [[ $(dpkg-query -W -f '${Status}' "$p" 2>/dev/null) == "install ok installed" ]] || printf '%s\n' "$p"
                done ;;
    esac
}

font_installed() { [[ -n $(fc-list ":family=$1" family 2>/dev/null) ]]; }
# The login screen runs as greetd's user, which can't read fonts in your home folder.
font_installed_system() { fc-list ":family=$1" file 2>/dev/null | grep -q -v "^$HOME/"; }
# Checks for what Fedora and Debian don't package, however it was installed.
have_quickshell() {
    local v
    v=$(qs --version 2>/dev/null | awk '{print $2; exit}') || return 1
    [[ -n $v && $(printf '0.3\n%s\n' "$v" | sort -V | head -1) == 0.3 ]]
}
have_materialyoucolor() { python3 -c 'import materialyoucolor' 2>/dev/null; }
have_qtengine() {
    compgen -G '/usr/lib*/qt6/plugins/platformthemes/libqt6engine-plugin.so' >/dev/null ||
        compgen -G '/usr/lib/*-linux-gnu/qt6/plugins/platformthemes/libqt6engine-plugin.so' >/dev/null ||
        compgen -G '/usr/local/lib*/qt6/plugins/platformthemes/libqt6engine-plugin.so' >/dev/null
}
have_awww() { command -v awww >/dev/null; }
have_gpu_screen_recorder() { command -v gpu-screen-recorder >/dev/null; }
have_rubik() { font_installed_system Rubik; }
have_material_symbols() { font_installed_system 'Material Symbols Rounded'; }
have_adw_gtk3() {
    local d
    for d in /usr/share/themes ~/.local/share/themes ~/.themes; do [[ -d $d/adw-gtk3-dark ]] && return 0; done
    return 1
}
have_jetbrains_nerd() { font_installed 'JetBrainsMonoNL Nerd Font Mono'; }

# Names (keys of FEDORA_MISSING / DEBIAN_MISSING) whose check fails.
missing_extras() {
    local -n hints="${FAMILY^^}_MISSING"
    local n
    for n in "${!hints[@]}"; do "have_$n" || printf '%s\n' "$n"; done | sort
}

aur_helper() { command -v paru || command -v yay || true; }

# ---------- configs that may replace the user's own ----------

# Repo file -> where it goes. Written by the darkmode and configs steps.
declare -A DARK_FILES=(
    ["$REPO/shell/darkmode/gtk-3.0-settings.ini"]="$HOME/.config/gtk-3.0/settings.ini"
    ["$REPO/shell/darkmode/qtengine.json"]="$HOME/.config/qtengine/config.json"
)
declare -A CONF_FILES=(
    ["$REPO/sway-config/kitty/kitty.conf"]="$HOME/.config/kitty/kitty.conf"
    ["$REPO/sway-config/fastfetch/config.jsonc"]="$HOME/.config/fastfetch/config.jsonc"
)
GSETTINGS=(color-scheme:"'prefer-dark'" gtk-theme:"'adw-gtk3-dark'")

files_match() {   # name of a source->target map
    local -n map=$1
    local s
    for s in "${!map[@]}"; do cmp -s "$s" "${map[$s]}" || return 1; done
}
install_files() {
    local -n map=$1
    local s
    for s in "${!map[@]}"; do install -D -m 644 "$s" "${map[$s]}" && say "   wrote ${map[$s]}"; done
}
# Existing files (and gsettings values) of the user's that a step would replace.
would_replace() {
    local -n map=$1
    local s
    for s in "${!map[@]}"; do [[ -e ${map[$s]} ]] && ! cmp -s "$s" "${map[$s]}" && printf '%s\n' "${map[$s]}"; done
    return 0
}
gsettings_replaced() {
    local kv
    for kv in "${GSETTINGS[@]}"; do
        local cur; cur=$(gsettings get org.gnome.desktop.interface "${kv%%:*}" 2>/dev/null) || continue
        [[ $cur == "${kv#*:}" ]] || printf 'gsettings org.gnome.desktop.interface %s (now %s)\n' "${kv%%:*}" "$cur"
    done
}

# ---------- steps: done_<step> checks (read-only), do_<step> acts ----------

done_preflight() { return 1; }
do_preflight() {
    [[ $EUID -ne 0 ]] || die "run it as yourself, not root (it asks for your password where it needs root)"
    [[ -n $FAMILY ]] || die "this is '${DISTRO:-unknown}': CTS1's installer supports Arch, CachyOS, Fedora and Debian only"
    [[ $REPO != *[[:space:]]* ]] || die "the clone's path has a space ($REPO): the session entry can't use it; clone it elsewhere"
    command -v sudo >/dev/null || die "sudo is not installed"
    say "   ok: $DISTRO, clone at $REPO"
}

done_packages() {
    case $FAMILY in
        arch) [[ -z $(missing_pkgs "${ARCH_PKGS[@]}" "${ARCH_AUR[@]}") ]] ;;
        fedora) [[ -z $(missing_pkgs "${FEDORA_PKGS[@]}") && -z $(missing_extras) ]] ;;
        debian) [[ -z $(missing_pkgs "${DEBIAN_PKGS[@]}") && -z $(missing_extras) ]] ;;
    esac
}
do_packages() {
    local todo helper n
    case $FAMILY in
        arch)
            # --needed: never reinstall what is there. No -Sy: a refresh without the upgrade is a partial upgrade.
            todo=$(missing_pkgs "${ARCH_PKGS[@]}")
            [[ -z $todo ]] || root pacman -S --needed $todo
            todo=$(missing_pkgs "${ARCH_AUR[@]}")
            if [[ -n $todo ]]; then
                helper=$(aur_helper)
                [[ -n $helper ]] || stop "These come from the AUR: $(echo $todo). Install an AUR helper (paru or yay) first."
                if [[ -n ${SUDO_ASKPASS:-} ]]; then
                    run "$helper" -S --needed --sudoflags -A $todo
                else
                    run "$helper" -S --needed $todo
                fi
            fi ;;
        fedora)
            todo=$(missing_pkgs "${FEDORA_PKGS[@]}")
            [[ -z $todo ]] || root dnf install $todo ;;
        debian)
            todo=$(missing_pkgs "${DEBIAN_PKGS[@]}")
            [[ -z $todo ]] || root apt-get install $todo
            have_qtengine || say "   note: no qtengine (it needs Qt 6.9, Debian 13 has 6.8): Qt apps keep Qt's own look" ;;
    esac
    if [[ $FAMILY != arch ]]; then
        local -n hints="${FAMILY^^}_MISSING"
        todo=$(missing_extras)
        if [[ -n $todo ]]; then
            say ""
            say "   Not packaged by ${DISTRO^}, install these yourself:"
            for n in $todo; do say "   - ${hints[$n]}"; done
            stop "Install the items above."
        fi
    fi
}

done_darkmode() { files_match DARK_FILES && [[ -z $(gsettings_replaced) ]]; }
do_darkmode() {
    local kv
    install_files DARK_FILES
    for kv in "${GSETTINGS[@]}"; do run gsettings set org.gnome.desktop.interface "${kv%%:*}" "${kv#*:}"; done
}

done_configs() { files_match CONF_FILES; }
do_configs() { install_files CONF_FILES; }

# The one "Sway" entry on the login screen: it takes the place of the one sway ships.
SESSION_FILE=/usr/share/wayland-sessions/sway.desktop
# Arch: pacman never installs sway's own entry again, so a sway update can't replace this one. Fedora and Debian
# have no such setting: after a sway update puts theirs back, run this step again.
NOEXTRACT="NoExtract = ${SESSION_FILE#/}"
session_entry() { sed -e '/^#/d' -e "s|^Exec=.*|Exec=$REPO/sway-config/bin/sway|" "$REPO/sway-config/sway.desktop"; }
noextract_set() { [[ $FAMILY != arch ]] || grep -qxF "$NOEXTRACT" /etc/pacman.conf; }
in_utmp() { getent group utmp | cut -d: -f4 | tr ',' '\n' | grep -qxF "$USER"; }
done_session() {
    cmp -s <(session_entry) "$SESSION_FILE" && noextract_set || return 1
    ! getent group utmp >/dev/null || in_utmp
}
do_session() {
    local tmp
    if ! noextract_set; then
        root sed -i "/^\[options\]/a # CTS1: keep sway's own session entry from replacing CTS1's\n$NOEXTRACT" /etc/pacman.conf
    fi
    if ! cmp -s <(session_entry) "$SESSION_FILE"; then
        tmp=$(mktemp)
        session_entry >"$tmp"
        root install -D -m 644 "$tmp" "$SESSION_FILE"
        rm -f "$tmp"
    fi
    # The sway wrapper writes a login record with sessreg, which needs the utmp group.
    if ! getent group utmp >/dev/null; then
        warn "no utmp group on this system: the session runs without a login record"
    elif ! in_utmp; then
        root usermod -aG utmp "$USER"
        say "   utmp group: takes effect at your next login"
    fi
}

# greetd's own user: each distro names it differently.
case $FAMILY in
    arch) GREETER_USER=greeter ;;
    fedora) GREETER_USER=greetd ;;
    debian) GREETER_USER=_greetd ;;
    *) GREETER_USER= ;;
esac
GREETER_DIR=/usr/local/share/cts1-greeter
GREETER_HOME=/var/lib/greetd
UNIT_DIR=/usr/local/lib/systemd/system
greeter_files_match() {
    diff -rq -x install.sh -x systemd "$REPO/greeter" "$GREETER_DIR" >/dev/null 2>&1 &&
        cmp -s "$REPO/greeter/systemd/cts1-greeter-sync@.path" "$UNIT_DIR/cts1-greeter-sync@.path" &&
        cmp -s "$REPO/greeter/systemd/cts1-greeter-sync@.service" "$UNIT_DIR/cts1-greeter-sync@.service"
}
greeter_home_ok() {
    [[ $(getent passwd "$GREETER_USER" | cut -d: -f6) == "$GREETER_HOME" ]] &&
        [[ $(stat -c %U "$GREETER_HOME" 2>/dev/null) == "$GREETER_USER" ]]
}
sync_watching() {
    systemctl is-enabled -q "cts1-greeter-sync@$USER.path" && systemctl is-active -q "cts1-greeter-sync@$USER.path"
}
done_greeter() {
    greeter_files_match && greeter_home_ok && sync_watching
}
do_greeter() {
    getent passwd "$GREETER_USER" >/dev/null || die "no '$GREETER_USER' user: greetd is not installed (run the packages step)"
    greeter_files_match || root "$REPO/greeter/install.sh"
    # The greeter keeps the last user and session in its home folder.
    if ! greeter_home_ok; then
        root install -d -o "$GREETER_USER" -g "$GREETER_USER" -m 750 "$GREETER_HOME"
        root usermod -d "$GREETER_HOME" "$GREETER_USER"
    fi
    # Copies your color scheme and wallpaper to the login screen, now and whenever they change.
    # reset-failed: a watcher that hit a start limit stays failed until reset.
    sync_watching || root sh -c "systemctl reset-failed 'cts1-greeter-sync@$USER.path' 'cts1-greeter-sync@$USER.service' 2>/dev/null;
        systemctl enable --now 'cts1-greeter-sync@$USER.path'"
}

done_verify() { return 1; }
do_verify() {
    local bad=0
    say "   sway: $(sway --version 2>/dev/null || echo 'not found')"
    say "   Quickshell: $(qs --version 2>/dev/null | head -1 || echo 'not found')"
    [[ -e $SESSION_FILE ]] && say "   session entry: $SESSION_FILE" || { warn "no session entry ($SESSION_FILE)"; bad=1; }
    [[ -d $GREETER_DIR ]] && say "   login screen files: $GREETER_DIR" || { warn "login screen not installed"; bad=1; }
    if [[ $(readlink /etc/systemd/system/display-manager.service 2>/dev/null) == */greetd.service ]] &&
        grep -q "$GREETER_DIR/start.sh" /etc/greetd/config.toml 2>/dev/null; then
        say "   login screen: CTS1's (greetd)"
    else
        say "   login screen: not switched to CTS1's; that is a manual step (README.md, Login screen)"
    fi
    say "   Log out and pick the \"Sway\" session that runs $REPO/sway-config/bin/sway."
    return $bad
}

# ---------- main ----------

case "${1:-}" in
    --list) for s in "${STEPS[@]}"; do printf '%-10s %s\n' "$s" "${ABOUT[$s]}"; done; exit 0 ;;
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
selected=("$@")
(( ${#selected[@]} )) || selected=("${STEPS[@]}")
for s in "${selected[@]}"; do [[ -n ${ABOUT[$s]:-} ]] || die "unknown step '$s' (see --list)"; done
[[ -n $FAMILY ]] || die "this is '${DISTRO:-unknown}': CTS1's installer supports Arch, CachyOS, Fedora and Debian only"

# One question for every config of the user's that this run would replace. No: those steps are skipped.
skip=()
if (( ! CHECK )); then
    replace=()
    for s in "${selected[@]}"; do
        case $s in
            darkmode) done_darkmode || mapfile -t -O "${#replace[@]}" replace < <(would_replace DARK_FILES; gsettings_replaced) ;;
            configs) done_configs || mapfile -t -O "${#replace[@]}" replace < <(would_replace CONF_FILES) ;;
        esac
    done
    if (( ${#replace[@]} )); then
        say "These settings of yours will be replaced by CTS1's (no backup is made):"
        printf '   %s\n' "${replace[@]}"
        read -r -p "Replace them? [y/N] " answer
        [[ $answer == [yY]* ]] || skip=(darkmode configs)
    fi
fi

left=()
failed=0
for s in "${selected[@]}"; do
    if [[ $s == preflight || $s == verify ]]; then
        section "$s"; "do_$s" || { left+=("$s"); failed=1; }; continue
    fi
    if "done_$s"; then
        printf '   %-10s done\n' "$s"
    elif (( CHECK )); then
        printf '   %-10s to do: %s\n' "$s" "${ABOUT[$s]}"; left+=("$s")
    elif [[ " ${skip[*]} " == *" $s "* ]]; then
        printf '   %-10s skipped: your files were kept\n' "$s"; left+=("$s")
    else
        section "$s"; "do_$s"
        "done_$s" || { warn "$s: not complete yet (see above)"; left+=("$s"); failed=1; }
    fi
done
say ""
if (( ${#left[@]} )); then say "Left: ${left[*]}"; else say "All done."; fi
(( CHECK )) && exit 0
exit $failed
