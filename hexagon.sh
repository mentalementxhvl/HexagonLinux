#!/usr/bin/env bash
#


echo -e "\033[38;5;153m  __    __    __________   ___     ___        __        __  .__   __.  __    __  ___   ___\033[0m"
echo -e "\033[38;5;159m |  |  |  | |   ____\\  \\ /  /    /   \\      |  |     |  | |  \\ |  | |  |  |  | \\  \\ /  / \033[0m"
echo -e "\033[38;5;195m |  |__|  | |  |__    \\   /    /  ^  \\     |  |     |  | |   \\|  | |  |  |  |  \\  V  /  \033[0m"
echo -e "\033[37m |   __   | |   __|    >   <    /  /_\\  \\    |  |     |  | |  . \`  | |  |  |  |   >   <   \033[0m"
echo -e "\033[38;5;231m |  |  |  | |  |____ /  .  \\  /  _____  \\   |  \`----.|  | |  |\\   | |  \`--'  |  /  .  \\  \033[0m"
echo -e "\033[97m |__|  |__| |_______/__/ \\__\\/__/     \\__\\  |_______||__| |__| \__|  \\______/  /__/ \\__\\\033[0m"
echo ""

set -uo pipefail

PREFIX_DIR="${HOME}/.local/share/wineprefixes/hexagon"
export WINEPREFIX="$PREFIX_DIR"

log()  { echo -e "\033[1;36m[fix]\033[0m $*" >&2; }
warn() { echo -e "\033[1;33m[fix][attention]\033[0m $*" >&2; }
err()  { echo -e "\033[1;31m[fix][erreur]\033[0m $*" >&2; }

if [ ! -d "$PREFIX_DIR" ]; then
    err "Prefix introuvable: $PREFIX_DIR"
    exit 1
fi

if find "$PREFIX_DIR/drive_c" -iname "*Hexagon*" 2>/dev/null | grep -q .; then
    log "You already have Hexagon"
fi

log "Application of mouse stability fixes (MouseWarpOverride)..."
wine reg add "HKCU\\Software\\Wine\\DirectInput" /v "MouseWarpOverride" /t REG_SZ /d "force" /f >/dev/null 2>&1
winecfg -v winxp >/dev/null 2>&1

log "Executables found in the prefix:"
mapfile -t EXES < <(find "$PREFIX_DIR/drive_c" -iname "*.exe" 2>/dev/null | grep -vi '\\windows\\' )
for e in "${EXES[@]}"; do echo "  - $e" >&2; done

LAUNCHER_EXE=""
for e in "${EXES[@]}"; do
    if [[ "$e" == *"HexagonPlayerLauncher"* || "$e" == *"Bootstrapper"* || "$e" == *"Launcher"* ]]; then
        LAUNCHER_EXE="$e"
        break
    fi
done

CLIENT_EXE=""
for e in "${EXES[@]}"; do
    if [[ "$e" == *"RobloxPlayerBeta"* ]]; then
        CLIENT_EXE="$e"
        break
    fi
done


log "Searching for registered URL schemes (roblox/hexagon)..."
CANDIDATES=(roblox-player roblox robloxplayer hexagon-player hexagon)
FOUND_SCHEME=""
FOUND_CMD=""

for scheme in "${CANDIDATES[@]}"; do
    out="$(wine reg query "HKEY_CLASSES_ROOT\\${scheme}" /v "URL Protocol" 2>/dev/null)"
    if [ -n "$out" ]; then
        cmd_out="$(wine reg query "HKEY_CLASSES_ROOT\\${scheme}\\shell\\open\\command" /ve 2>/dev/null)"
        cmd_line="$(echo "$cmd_out" | grep -oP '(?<=REG_SZ\s{4}).*' | head -n1)"
        if [ -n "$cmd_line" ]; then
            FOUND_SCHEME="$scheme"
            FOUND_CMD="$cmd_line"
            log "Found: scheme '$scheme' -> $cmd_line"
            break
        fi
    fi
done


TARGET_EXE="$LAUNCHER_EXE"
[ -z "$TARGET_EXE" ] && TARGET_EXE="$CLIENT_EXE"

if [ -z "$TARGET_EXE" ]; then
    err "Unable to determine which .exe to launch."
    exit 1
fi

DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/hexagon-protocol-handler.desktop"
mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Hexagon Protocol Handler
Comment=Handler pour les liens ${FOUND_SCHEME}://
Exec=env WINEPREFIX="${PREFIX_DIR}" wine "${TARGET_EXE}" %u
Terminal=false
NoDisplay=true
MimeType=x-scheme-handler/${FOUND_SCHEME};
EOF


update-desktop-database "$DESKTOP_DIR" 2>/dev/null
if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default hexagon-protocol-handler.desktop "x-scheme-handler/${FOUND_SCHEME}"
    log "Association registered successfully."
else
    err "xdg-mime not found."
fi

log "Done. The mouse is now optimized for older clients don't forget to press F11 for 0 lag of your mouse"
