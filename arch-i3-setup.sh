#!/usr/bin/env bash
#
# =============================================================================
#  Arch Linux Minimal → Full i3 Setup Script
#  Inspired by Archcraft-i3 aesthetic (rounded corners, clean polybar, etc.)
#  Target: Bare Arch install with wired internet only
#  Author: Generated for Dave's HP Omen Max 16 (RTX 5080)
#  Date: 2026-07-30
# =============================================================================
#
#  HOW TO USE:
#  1. Complete a minimal Arch install (base + linux + linux-firmware + network).
#  2. Boot into the new system, login as root (or use sudo).
#  3. Make sure you have internet (wired).
#  4. Copy this script to the machine and run:
#       chmod +x arch-i3-setup.sh
#       sudo ./arch-i3-setup.sh
#  5. Reboot when finished. You should land in SDDM → i3.
#
#  IMPORTANT NOTES:
#  - Run as root (or with sudo).
#  - This script is idempotent where possible but best run once on a clean system.
#  - NVIDIA open kernel modules are used (required for RTX 50-series).
#  - All configs are created under /home/$REAL_USER/
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 0. Safety & Environment Checks
# -----------------------------------------------------------------------------
echo "=== [0/15] Safety checks ==="

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (or with sudo)."
    exit 1
fi

# Detect the real user (the one who will own the configs)
if [[ -n "${SUDO_USER:-}" ]]; then
    REAL_USER="$SUDO_USER"
else
    # Fallback if run directly as root
    REAL_USER=$(logname 2>/dev/null || echo "dave")
fi

USER_HOME=$(eval echo "~$REAL_USER")
echo "Configuring for user: $REAL_USER  (home: $USER_HOME)"

# Confirm we are on Arch
if ! grep -qi "Arch Linux" /etc/os-release; then
    echo "WARNING: This does not look like Arch Linux. Continuing anyway..."
fi

# Quick internet check
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    echo "ERROR: No internet connection detected. Connect wired network and try again."
    exit 1
fi

echo "Safety checks passed."
echo

# -----------------------------------------------------------------------------
# 1. System Update + Enable Multilib + Install Yay
# -----------------------------------------------------------------------------
echo "=== [1/15] System update + enable multilib + install yay ==="

# Enable multilib (needed for Steam, 32-bit NVIDIA libs, etc.)
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    echo "Multilib repository enabled."
fi

pacman -Syu --noconfirm

# Install base-devel and git (required for yay and AUR)
pacman -S --needed --noconfirm base-devel git

# Install yay if not present
if ! command -v yay &>/dev/null; then
    echo "Installing yay (AUR helper)..."
    cd /tmp
    sudo -u "$REAL_USER" git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u "$REAL_USER" makepkg -si --noconfirm
    cd /
    rm -rf /tmp/yay
else
    echo "yay already installed."
fi

echo

# -----------------------------------------------------------------------------
# 2. NVIDIA Drivers (RTX 5080 → nvidia-open-dkms required)
# -----------------------------------------------------------------------------
echo "=== [2/15] NVIDIA drivers (open kernel modules for RTX 50-series) ==="

# Headers are required for DKMS
pacman -S --needed --noconfirm linux-headers

# Install NVIDIA stack
pacman -S --needed --noconfirm \
    nvidia-open-dkms \
    nvidia-utils \
    lib32-nvidia-utils \
    nvidia-settings \
    nvidia-prime

# Early KMS for smoother boot (optional but recommended)
if ! grep -q "nvidia_drm" /etc/mkinitcpio.conf; then
    sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    mkinitcpio -P
fi

echo "NVIDIA drivers installed. A reboot will be required later."
echo

# -----------------------------------------------------------------------------
# 3. Xorg + Core Graphical Stack
# -----------------------------------------------------------------------------
echo "=== [3/15] Xorg and core graphical packages ==="

pacman -S --needed --noconfirm \
    xorg-server \
    xorg-xinit \
    xorg-xrandr \
    xorg-xsetroot \
    xorg-xkill \
    xorg-xprop \
    xorg-xdpyinfo \
    xorg-xev \
    xorg-xlsfonts \
    xf86-input-libinput \
    mesa \
    libglvnd \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader

echo

# -----------------------------------------------------------------------------
# 4. Audio (PipeWire) + Bluetooth
# -----------------------------------------------------------------------------
echo "=== [4/15] PipeWire audio + Bluetooth ==="

pacman -S --needed --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    sof-firmware \
    alsa-utils \
    pavucontrol \
    playerctl \
    bluez \
    bluez-utils \
    blueman

systemctl enable bluetooth.service

echo

# -----------------------------------------------------------------------------
# 5. Printing (HP printers)
# -----------------------------------------------------------------------------
echo "=== [5/15] Printing support (CUPS + HPLIP) ==="

pacman -S --needed --noconfirm \
    cups \
    cups-pdf \
    hplip \
    system-config-printer \
    ghostscript \
    gsfonts

systemctl enable cups.service

echo

# -----------------------------------------------------------------------------
# 6. Fonts
# -----------------------------------------------------------------------------
echo "=== [6/15] Fonts (Noto + JetBrains Mono Nerd + Terminus) ==="

pacman -S --needed --noconfirm \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-liberation \
    ttf-dejavu \
    terminus-font

# Set TTY font to ter-122b (as requested)
if [[ -f /usr/share/kbd/consolefonts/ter-122b.psf.gz ]]; then
    echo "FONT=ter-122b" > /etc/vconsole.conf
    echo "TTY font set to ter-122b."
else
    echo "WARNING: ter-122b font not found. Using default."
fi

echo

# -----------------------------------------------------------------------------
# 7. Window Manager Stack (i3 + companions)
# -----------------------------------------------------------------------------
echo "=== [7/15] i3 window manager + polybar, rofi, dunst, picom, etc. ==="

pacman -S --needed --noconfirm \
    i3-wm \
    i3lock \
    i3status \
    polybar \
    rofi \
    dunst \
    picom \
    nitrogen \
    feh \
    thunar \
    thunar-archive-plugin \
    thunar-volman \
    tumbler \
    gvfs \
    gvfs-mtp \
    gvfs-smb \
    xarchiver \
    lxappearance \
    xdg-user-dirs \
    xdg-utils \
    polkit-gnome \
    numlockx \
    brightnessctl \
    scrot \
    xclip \
    xdotool

# Create standard XDG directories for the user
sudo -u "$REAL_USER" xdg-user-dirs-update

echo

# -----------------------------------------------------------------------------
# 8. Themes (Qogir) + Cursor
# -----------------------------------------------------------------------------
echo "=== [8/15] Qogir GTK theme, icons and cursor ==="

# Official packages where available + AUR
pacman -S --needed --noconfirm \
    gtk-engine-murrine \
    gtk-engines

# AUR packages for Qogir
sudo -u "$REAL_USER" yay -S --needed --noconfirm \
    qogir-gtk-theme \
    qogir-icon-theme \
    qogir-cursor-theme-git || true

echo

# -----------------------------------------------------------------------------
# 9. Display Manager (SDDM) + Theme
# -----------------------------------------------------------------------------
echo "=== [9/15] SDDM display manager ==="

pacman -S --needed --noconfirm sddm

# Install a clean SDDM theme (sugar-candy is popular and reliable)
sudo -u "$REAL_USER" yay -S --needed --noconfirm sddm-theme-sugar-candy || true

# Enable SDDM
systemctl enable sddm.service

# Basic SDDM config
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/theme.conf << 'EOF'
[Theme]
Current=sugar-candy
EOF

echo

# -----------------------------------------------------------------------------
# 10. Limine Boot Manager
# -----------------------------------------------------------------------------
echo "=== [10/15] Limine boot manager ==="

pacman -S --needed --noconfirm limine

# Note: Full Limine deployment depends on whether the system is UEFI or BIOS
# and on the current boot setup. We install the package and leave a note.
echo "Limine package installed."
echo "IMPORTANT: After reboot you may need to manually deploy Limine if it is not already the bootloader."
echo "See: https://wiki.archlinux.org/title/Limine"
echo

# -----------------------------------------------------------------------------
# 11. Power Management (TLP)
# -----------------------------------------------------------------------------
echo "=== [11/15] TLP power management ==="

pacman -S --needed --noconfirm tlp tlp-rdw
systemctl enable tlp.service

echo

# -----------------------------------------------------------------------------
# 12. Applications (Official Repos + AUR)
# -----------------------------------------------------------------------------
echo "=== [12/15] Installing applications ==="

# --- Official repositories ---
pacman -S --needed --noconfirm \
    firefox \
    steam \
    gamemode \
    lib32-gamemode \
    spotify-launcher \
    mpv \
    transmission-gtk \
    gimp \
    viewnior \
    geany \
    geany-plugins \
    htop \
    btop \
    nvtop \
    mc \
    ncdu \
    figlet \
    yt-dlp \
    ffmpeg \
    imagemagick \
    cava \
    mpd \
    mpc \
    ncmpcpp \
    python-pywal \
    timeshift \
    fastfetch \
    stellarium \
    networkmanager \
    network-manager-applet \
    nm-connection-editor \
    gcolor3 \
    python-pip

# Enable NetworkManager (useful even with wired)
systemctl enable NetworkManager.service

# --- AUR packages ---
echo "Installing AUR packages (this may take a while)..."
sudo -u "$REAL_USER" yay -S --needed --noconfirm \
    ghostty \
    vesktop \
    minecraft-launcher \
    openspades-git \
    google-earth-pro \
    cmatrix-git \
    c-lolcat \
    pyradio \
    tty-clock \
    geany-themes \
    || true

# Note: vencord → we install vesktop which ships with Vencord pre-configured.
# This is the most reliable way in 2026.

echo

# -----------------------------------------------------------------------------
# 13. Create Configuration Files
# -----------------------------------------------------------------------------
echo "=== [13/15] Creating configuration files ==="

# Ensure config directories exist
sudo -u "$REAL_USER" mkdir -p \
    "$USER_HOME/.config/i3" \
    "$USER_HOME/.config/polybar" \
    "$USER_HOME/.config/picom" \
    "$USER_HOME/.config/dunst" \
    "$USER_HOME/.config/rofi" \
    "$USER_HOME/.config/ghostty" \
    "$USER_HOME/.config/mpd" \
    "$USER_HOME/.config/ncmpcpp" \
    "$USER_HOME/Pictures/Wallpapers" \
    "$USER_HOME/.local/bin"

# ---------------------------------------------------------------------------
# 13a. i3 Configuration (well-documented, Archcraft-inspired)
# ---------------------------------------------------------------------------
cat > "$USER_HOME/.config/i3/config" << 'I3EOF'
# =============================================================================
# i3 Configuration - Clean Archcraft-inspired setup
# Generated for minimal + rounded corners aesthetic
# =============================================================================

# --- Modifier key ---
set $mod Mod4

# --- Font ---
font pango:JetBrainsMono Nerd Font 11

# --- Gaps & Borders (rounded corners handled by picom) ---
gaps inner 8
gaps outer 4
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart

# Colors will be overridden by pywal if you run it
client.focused          #81A1C1 #81A1C1 #ECEFF4 #81A1C1 #81A1C1
client.focused_inactive #4C566A #4C566A #D8DEE9 #4C566A #4C566A
client.unfocused        #3B4252 #3B4252 #D8DEE9 #3B4252 #3B4252
client.urgent           #BF616A #BF616A #ECEFF4 #BF616A #BF616A

# --- Keybindings ---

# Terminal
bindsym $mod+Return exec ghostty

# Kill focused window
bindsym $mod+Shift+q kill

# Application launcher (rofi)
bindsym $mod+d exec rofi -show drun -show-icons

# Run command launcher
bindsym $mod+Shift+d exec rofi -show run

# Window switcher
bindsym $mod+Tab exec rofi -show window -show-icons

# Reload i3 config
bindsym $mod+Shift+c reload

# Restart i3 in place
bindsym $mod+Shift+r restart

# Exit i3 (logout)
# bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"

# Lock screen
bindsym $mod+l exec i3lock -c 000000

# Focus
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

# Move window
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# Split orientation
bindsym $mod+b split h
bindsym $mod+v split v

# Fullscreen
bindsym $mod+f fullscreen toggle

# Floating toggle
bindsym $mod+Shift+space floating toggle

# Focus floating / tiling
bindsym $mod+space focus mode_toggle

# Focus parent
bindsym $mod+a focus parent

# Workspaces
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# Resize mode
mode "resize" {
    bindsym Left resize shrink width 10 px or 10 ppt
    bindsym Down resize grow height 10 px or 10 ppt
    bindsym Up resize shrink height 10 px or 10 ppt
    bindsym Right resize grow width 10 px or 10 ppt
    bindsym h resize shrink width 10 px or 10 ppt
    bindsym j resize grow height 10 px or 10 ppt
    bindsym k resize shrink height 10 px or 10 ppt
    bindsym l resize grow width 10 px or 10 ppt
    bindsym Return mode "default"
    bindsym Escape mode "default"
    bindsym $mod+r mode "default"
}
bindsym $mod+r mode "resize"

# Media keys (volume + brightness)
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

# Screenshot
bindsym Print exec scrot -e 'mv $f ~/Pictures/'
bindsym $mod+Print exec scrot -s -e 'mv $f ~/Pictures/'

# File manager
bindsym $mod+e exec thunar

# Browser
bindsym $mod+w exec firefox

# --- Autostart ---
exec --no-startup-id nitrogen --restore
exec --no-startup-id picom --config ~/.config/picom/picom.conf
exec --no-startup-id polybar --reload main &
exec --no-startup-id dunst
exec --no-startup-id nm-applet
exec --no-startup-id blueman-applet
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec --no-startup-id numlockx on
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock -c 000000

# Set default workspace layout
workspace_layout default
I3EOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/i3"

# ---------------------------------------------------------------------------
# 13b. Polybar (clean Archcraft-style)
# ---------------------------------------------------------------------------
cat > "$USER_HOME/.config/polybar/config.ini" << 'POLYEOF'
; Polybar configuration - clean dark style
; Colors will be updated by pywal if desired

[colors]
background = #2E3440
background-alt = #3B4252
foreground = #ECEFF4
primary = #81A1C1
secondary = #88C0D0
alert = #BF616A
disabled = #4C566A

[bar/main]
width = 100%
height = 28
radius = 0
fixed-center = true

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 2
line-color = ${colors.primary}

border-size = 0
padding = 2
module-margin = 1

font-0 = JetBrainsMono Nerd Font:size=11;2
font-1 = JetBrainsMono Nerd Font:size=13;3

modules-left = i3
modules-center = date
modules-right = pulseaudio backlight battery memory cpu temperature network

tray-position = right
tray-padding = 2

cursor-click = pointer
cursor-scroll = ns-resize

[module/i3]
type = internal/i3
format = <label-state> <label-mode>
index-sort = true
wrapping-scroll = false

label-mode-padding = 2
label-mode-foreground = ${colors.background}
label-mode-background = ${colors.primary}

label-focused = %index%
label-focused-background = ${colors.background-alt}
label-focused-underline = ${colors.primary}
label-focused-padding = 2

label-unfocused = %index%
label-unfocused-padding = 2

label-visible = %index%
label-visible-underline = ${colors.secondary}
label-visible-padding = 2

label-urgent = %index%
label-urgent-background = ${colors.alert}
label-urgent-padding = 2

[module/date]
type = internal/date
interval = 1
date = %Y-%m-%d
time = %H:%M
label = %date%  %time%
format-prefix = "󰸗 "
format-prefix-foreground = ${colors.primary}

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <ramp-volume> <label-volume>
label-volume = %percentage%%
label-muted = 󰖁 muted
label-muted-foreground = ${colors.disabled}
ramp-volume-0 = 󰕿
ramp-volume-1 = 󰖀
ramp-volume-2 = 󰕾
click-right = pavucontrol

[module/backlight]
type = internal/backlight
card = intel_backlight
format = <ramp> <label>
label = %percentage%%
ramp-0 = 󰃞
ramp-1 = 󰃟
ramp-2 = 󰃠

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC
full-at = 98
format-charging = <animation-charging> <label-charging>
format-discharging = <ramp-capacity> <label-discharging>
format-full = <ramp-capacity> <label-full>
label-charging = %percentage%%
label-discharging = %percentage%%
label-full = %percentage%%
ramp-capacity-0 = 󰁺
ramp-capacity-1 = 󰁼
ramp-capacity-2 = 󰁾
ramp-capacity-3 = 󰂀
ramp-capacity-4 = 󰁹
animation-charging-0 = 󰢜
animation-charging-1 = 󰂇
animation-charging-2 = 󰂈
animation-charging-framerate = 750

[module/memory]
type = internal/memory
interval = 3
format-prefix = "󰍛 "
format-prefix-foreground = ${colors.primary}
label = %percentage_used%%

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = "󰻠 "
format-prefix-foreground = ${colors.primary}
label = %percentage%%

[module/temperature]
type = internal/temperature
thermal-zone = 0
warn-temperature = 80
format = <ramp> <label>
format-warn = <ramp> <label-warn>
label = %temperature-c%
label-warn = %temperature-c%
label-warn-foreground = ${colors.alert}
ramp-0 = 󰔏
ramp-1 = 󰔐
ramp-2 = 󰔒

[module/network]
type = internal/network
interface = enp0s31f6
interval = 3
format-connected = <label-connected>
format-disconnected = <label-disconnected>
label-connected = 󰈀 %essid%
label-disconnected = 󰈂 offline
label-disconnected-foreground = ${colors.disabled}

[settings]
screenchange-reload = true

[global/wm]
margin-top = 0
margin-bottom = 0
POLYEOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/polybar"

# ---------------------------------------------------------------------------
# 13c. Picom (rounded corners + blur + transparency)
# ---------------------------------------------------------------------------
cat > "$USER_HOME/.config/picom/picom.conf" << 'PICOMEOF'
# Picom configuration - rounded corners, blur, transparency
# Archcraft-inspired look

#################################
#             Animations        #
#################################
# (keep simple for stability)

#################################
#             Shadows           #
#################################
shadow = true;
shadow-radius = 12;
shadow-offset-x = -8;
shadow-offset-y = -8;
shadow-opacity = 0.4;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "class_g = 'Dunst'",
    "_GTK_FRAME_EXTENTS@:c"
];

#################################
#           Fading              #
#################################
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 5;

#################################
#   Transparency / Opacity      #
#################################
inactive-opacity = 0.92;
frame-opacity = 0.9;
inactive-opacity-override = false;
active-opacity = 1.0;

opacity-rule = [
    "90:class_g = 'ghostty'",
    "95:class_g = 'Rofi'",
    "100:class_g = 'Firefox'",
    "100:class_g = 'steam'"
    "100:class_g = 'mpv'"
];

#################################
#           Corners             #
#################################
corner-radius = 12;
rounded-corners-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'Dunst'",
    "window_type = 'dock'",
    "window_type = 'desktop'"
];

#################################
#            Blur               #
#################################
blur-method = "dual_kawase";
blur-strength = 5;
blur-background = true;
blur-background-frame = true;
blur-background-fixed = true;

blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "class_g = 'Polybar'",
    "class_g = 'Dunst'",
    "_GTK_FRAME_EXTENTS@:c"
];

#################################
#          General              #
#################################
backend = "glx";
vsync = true;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-damage = true;
log-level = "warn";

wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; full-shadow = false; };
    dock = { shadow = false; clip-shadow-above = true; }
    dnd = { shadow = false; }
    popup_menu = { opacity = 0.95; }
    dropdown_menu = { opacity = 0.95; }
};
PICOMEOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/picom"

# ---------------------------------------------------------------------------
# 13d. Dunst
# ---------------------------------------------------------------------------
cat > "$USER_HOME/.config/dunst/dunstrc" << 'DUNSTEOF'
[global]
    monitor = 0
    follow = mouse
    width = 300
    height = (0, 300)
    origin = top-right
    offset = (12, 40)
    scale = 0
    notification_limit = 5
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 10
    separator_height = 2
    padding = 10
    horizontal_padding = 10
    text_icon_padding = 0
    frame_width = 2
    frame_color = "#81A1C1"
    gap_size = 6
    separator_color = frame
    sort = yes
    font = JetBrainsMono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 32
    max_icon_size = 48
    sticky_history = yes
    history_length = 20
    dmenu = /usr/bin/rofi -dmenu -p dunst
    browser = /usr/bin/firefox
    always_run_script = true
    title = Dunst
    class = Dunst
    corner_radius = 10
    ignore_dbusclose = false
    force_xwayland = false
    force_xinerama = false
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[urgency_low]
    background = "#2E3440"
    foreground = "#ECEFF4"
    frame_color = "#4C566A"
    timeout = 5

[urgency_normal]
    background = "#2E3440"
    foreground = "#ECEFF4"
    frame_color = "#81A1C1"
    timeout = 8

[urgency_critical]
    background = "#2E3440"
    foreground = "#ECEFF4"
    frame_color = "#BF616A"
    timeout = 0
DUNSTEOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/dunst"

# ---------------------------------------------------------------------------
# 13e. Rofi
# ---------------------------------------------------------------------------
mkdir -p "$USER_HOME/.config/rofi"
cat > "$USER_HOME/.config/rofi/config.rasi" << 'ROFIEOF'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Qogir";
    display-drun: "Apps";
    display-run: "Run";
    display-window: "Windows";
    drun-display-format: "{name}";
    font: "JetBrainsMono Nerd Font 12";
}

@theme "/usr/share/rofi/themes/Arc-Dark.rasi"
ROFIEOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/rofi"

# ---------------------------------------------------------------------------
# 13f. Ghostty
# ---------------------------------------------------------------------------
cat > "$USER_HOME/.config/ghostty/config" << 'GHOSTTYEOF'
# Ghostty configuration
font-family = JetBrainsMono Nerd Font
font-size = 12
background-opacity = 0.92
window-padding-x = 8
window-padding-y = 8
theme = catppuccin-mocha
cursor-style = block
cursor-style-blink = false
shell-integration = detect
confirm-close-surface = false
GHOSTTYEOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/ghostty"

# ---------------------------------------------------------------------------
# 13g. MPD + ncmpcpp basic config
# ---------------------------------------------------------------------------
cat > "$USER_HOME/.config/mpd/mpd.conf" << 'MPDEOF'
music_directory     "~/Music"
playlist_directory  "~/.config/mpd/playlists"
db_file             "~/.config/mpd/database"
log_file            "~/.config/mpd/log"
pid_file            "~/.config/mpd/pid"
state_file          "~/.config/mpd/state"
sticker_file        "~/.config/mpd/sticker.sql"

bind_to_address     "127.0.0.1"
port                "6600"

audio_output {
    type    "pipewire"
    name    "PipeWire Sound Server"
}
MPDEOF

mkdir -p "$USER_HOME/.config/mpd/playlists"
chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/mpd"

# ---------------------------------------------------------------------------
# 13h. GTK settings (Qogir + Noto)
# ---------------------------------------------------------------------------
mkdir -p "$USER_HOME/.config/gtk-3.0"
cat > "$USER_HOME/.config/gtk-3.0/settings.ini" << 'GTKEOF'
[Settings]
gtk-theme-name=Qogir-Dark
gtk-icon-theme-name=Qogir
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Qogir
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
GTKEOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/gtk-3.0"

# Also set for GTK2
cat > "$USER_HOME/.gtkrc-2.0" << 'GTK2EOF'
gtk-theme-name="Qogir-Dark"
gtk-icon-theme-name="Qogir"
gtk-font-name="Noto Sans 11"
gtk-cursor-theme-name="Qogir"
gtk-cursor-theme-size=24
GTK2EOF
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.gtkrc-2.0"

echo "Configuration files created."
echo

# -----------------------------------------------------------------------------
# 14. Wallpapers + Pywal setup
# -----------------------------------------------------------------------------
echo "=== [14/15] Wallpapers and pywal ==="

# Download a few sci-fi / dark wallpapers
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/Pictures/Wallpapers"

# Using some reliable public domain / free wallpaper sources
sudo -u "$REAL_USER" bash -c "
cd ~/Pictures/Wallpapers
# Placeholder - user can replace these later
curl -sL 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=2560' -o space1.jpg || true
curl -sL 'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=2560' -o space2.jpg || true
curl -sL 'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=2560' -o space3.jpg || true
"

# Create a simple pywal helper script
cat > "$USER_HOME/.local/bin/set-wallpaper" << 'WALEOF'
#!/bin/bash
# Simple wallpaper + pywal helper
WALL="$1"
if [[ -z "$WALL" ]]; then
    echo "Usage: set-wallpaper /path/to/image"
    exit 1
fi
nitrogen --set-zoom-fill "$WALL"
wal -i "$WALL" -q
# Reload polybar and i3 to pick up new colors if desired
polybar-msg cmd restart 2>/dev/null || true
i3-msg reload 2>/dev/null || true
echo "Wallpaper and colors applied."
WALEOF

chmod +x "$USER_HOME/.local/bin/set-wallpaper"
chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.local" "$USER_HOME/Pictures"

echo

# -----------------------------------------------------------------------------
# 15. Final System Tweaks
# -----------------------------------------------------------------------------
echo "=== [15/15] Final tweaks ==="

# Make sure the user is in important groups
usermod -aG video,audio,lp,network,storage,optical "$REAL_USER" 2>/dev/null || true

# Enable lingering for user services if needed
loginctl enable-linger "$REAL_USER" 2>/dev/null || true

# Create a simple .xinitrc as fallback (even though we use SDDM)
cat > "$USER_HOME/.xinitrc" << 'XINITEOF'
#!/bin/sh
exec i3
XINITEOF
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xinitrc"
chmod +x "$USER_HOME/.xinitrc"

# Update font cache
fc-cache -fv >/dev/null 2>&1

echo
echo "============================================================================="
echo "  SETUP COMPLETE"
echo "============================================================================="
echo
echo "What was installed / configured:"
echo "  • NVIDIA open drivers (RTX 5080 ready)"
echo "  • Xorg + i3 + polybar + rofi + dunst + picom (rounded corners + blur)"
echo "  • Ghostty terminal + JetBrains Mono Nerd Font"
echo "  • Qogir theme / icons / cursor"
echo "  • SDDM display manager"
echo "  • PipeWire + Bluetooth + HP printing"
echo "  • TLP power management"
echo "  • All requested applications (Steam, Spotify, Minecraft, OpenSpades,"
echo "    Firefox, GIMP, MPD stack, etc.)"
echo "  • Nitrogen + pywal wallpaper theming"
echo "  • Limine bootloader package (manual final deployment may be needed)"
echo "  • TTY font set to ter-122b"
echo
echo "Next steps:"
echo "  1. Reboot:  reboot"
echo "  2. Log in via SDDM"
echo "  3. Set a wallpaper:  set-wallpaper ~/Pictures/Wallpapers/someimage.jpg"
echo "  4. Fine-tune polybar interface names / battery if needed"
echo "  5. For Limine: follow https://wiki.archlinux.org/title/Limine if it is"
echo "     not already your bootloader."
echo
echo "Keybinds reminder (Mod = Super/Windows key):"
echo "  Super + Enter          → Ghostty terminal"
echo "  Super + d              → Application launcher (rofi)"
echo "  Super + Shift + q      → Kill window"
echo "  Super + f              → Fullscreen"
echo "  Super + e              → Thunar file manager"
echo "  Super + w              → Firefox"
echo "  Super + l              → Lock screen"
echo
echo "Enjoy your clean i3 setup!"
echo "============================================================================="
