# Package lists for install.sh (sourced, not run): everything CTS1 needs, per distro.
# Package managers skip what is already installed.

# Arch and CachyOS: official repos (pacman).
ARCH_PKGS=(
    # Shell
    quickshell qt6-declarative qt6-5compat qt6-wayland
    pipewire wireplumber networkmanager bluez
    # Timer bell (pw-play, bell.oga)
    pipewire-audio sound-theme-freedesktop
    # Compositor and session
    sway swayidle xdg-desktop-portal-gtk polkit-gnome xorg-sessreg
    # Login screen
    greetd cage
    # Wallpaper and its colors
    awww python python-pillow
    # Visualizers, launcher, brightness
    cava fuzzel brightnessctl ddcutil
    # Screen recorder
    gpu-screen-recorder slurp jq libnotify xdg-utils xdg-user-dirs
    # Profile picture picker
    zenity
    # Screenshots, clipboard
    grim swappy wl-clipboard cliphist
    # Dark mode
    adw-gtk-theme papirus-icon-theme gsettings-desktop-schemas dconf glib2
    # Fonts
    ttf-material-symbols-variable ttf-jetbrains-mono-nerd fontconfig
    # Terminal
    kitty fastfetch
)

# Arch and CachyOS: AUR only, installed through paru or yay.
ARCH_AUR=(python-materialyoucolor qtengine ttf-rubik-vf)

FEDORA_PKGS=(
    qt6-qtdeclarative qt6-qt5compat qt6-qtwayland
    pipewire wireplumber NetworkManager bluez pipewire-utils sound-theme-freedesktop
    sway swayidle xdg-desktop-portal-gtk lxqt-policykit sessreg
    greetd cage
    python3 python3-pillow
    cava fuzzel brightnessctl ddcutil
    slurp jq libnotify xdg-utils xdg-user-dirs
    zenity
    grim swappy wl-clipboard cliphist
    adw-gtk3-theme papirus-icon-theme gsettings-desktop-schemas dconf glib2
    google-rubik-fonts fontconfig
    kitty fastfetch
)

DEBIAN_PKGS=(
    qml6-module-qtquick qml6-module-qtquick-layouts qml6-module-qtquick-effects
    qml6-module-qtquick-controls qml6-module-qtquick-window qml6-module-qtquick-shapes
    qml6-module-qt-labs-folderlistmodel qml6-module-qt5compat-graphicaleffects qt6-wayland
    pipewire wireplumber network-manager bluez pipewire-bin sound-theme-freedesktop
    sway swayidle xdg-desktop-portal-gtk mate-polkit x11-xserver-utils
    greetd cage
    python3 python3-pil
    cava fuzzel brightnessctl ddcutil
    slurp jq libnotify-bin xdg-utils xdg-user-dirs
    zenity
    grim swappy wl-clipboard cliphist
    papirus-icon-theme gsettings-desktop-schemas dconf-gsettings-backend libglib2.0-bin
    fontconfig
    kitty fastfetch
)

# What Fedora and Debian don't package (or package too old), and what to look for.
# install.sh checks each one itself (have_<name>), however it was installed.
# Not on Debian: qtengine needs Qt 6.9 and Debian 13 has 6.8, so install.sh only mentions it there.
declare -A FEDORA_MISSING=(
    [quickshell]="Quickshell 0.3 or newer (Fedora's 0.2.1 has no Networking module): COPR errornointernet/quickshell, or build it from source (quickshell.org)"
    [materialyoucolor]="Python module materialyoucolor: from PyPI (pip install materialyoucolor)"
    [qtengine]="qtengine (Qt theme plugin): build it from github.com/kossLAN/qtengine"
    [awww]="awww (wallpaper daemon): build it from source (Rust)"
    [gpu_screen_recorder]="gpu-screen-recorder: from COPR or Flatpak"
    [material_symbols]="Material Symbols Rounded font: variablefont/ in github.com/google/material-design-icons (Fedora's material-icons-fonts is a different font), installed system-wide (/usr/local/share/fonts: the login screen can't read your own fonts)"
    [jetbrains_nerd]="JetBrainsMonoNL Nerd Font Mono (Kitty's font): from github.com/ryanoasis/nerd-fonts (Fedora's jetbrains-mono-fonts has no Nerd icons)"
)
declare -A DEBIAN_MISSING=(
    [quickshell]="Quickshell 0.3 or newer: trixie-backports has 0.3.0, or build it from source (quickshell.org)"
    [materialyoucolor]="Python module materialyoucolor: from PyPI, for the system python3 (pip install --user --break-system-packages materialyoucolor)"
    [awww]="awww (wallpaper daemon): build it from source (needs Rust 1.89 or newer: rustup)"
    [gpu_screen_recorder]="gpu-screen-recorder: build it from source"
    [rubik]="Rubik font: from github.com/googlefonts/rubik, installed system-wide (/usr/local/share/fonts: the login screen can't read your own fonts)"
    [material_symbols]="Material Symbols Rounded font: variablefont/ in github.com/google/material-design-icons, installed system-wide (/usr/local/share/fonts)"
    [adw_gtk3]="adw-gtk3 theme: from github.com/lassekongo83/adw-gtk3"
    [jetbrains_nerd]="JetBrainsMonoNL Nerd Font Mono (Kitty's font): from github.com/ryanoasis/nerd-fonts (fonts-jetbrains-mono has no Nerd icons)"
)
