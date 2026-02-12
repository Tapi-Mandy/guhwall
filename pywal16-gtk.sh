#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# pywal16-gtk  —  Intelligent GTK 3 & GTK 4 / libadwaita theming via pywal16
# ─────────────────────────────────────────────────────────────────────────────
# Reads ~/.cache/wal/colors.json (or a custom path) and generates proper
# @define-color CSS for both GTK 3 and GTK 4, using perceptual hue detection
# to assign accent / error / success / warning roles and lightness math for
# the surface-elevation hierarchy.
#
# Dependencies: bash ≥ 4, jq, bc
# Usage:        pywal16-gtk.sh [--dry-run] [/path/to/colors.json]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
COLORS_JSON="${HOME}/.cache/wal/colors.json"
GTK3_DIR="${HOME}/.config/gtk-3.0"
GTK4_DIR="${HOME}/.config/gtk-4.0"
DRY_RUN=false

# ── Parse args ──────────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: pywal16-gtk.sh [--dry-run] [/path/to/colors.json]"
            echo ""
            echo "Generates GTK 3 & GTK 4 colors.css from pywal16 palette."
            echo ""
            echo "Options:"
            echo "  --dry-run   Print generated CSS to stdout, don't write files"
            echo "  --help      Show this help"
            exit 0
            ;;
        *) COLORS_JSON="$arg" ;;
    esac
done

# ── Dependency check ────────────────────────────────────────────────────────
for cmd in jq bc; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "error: '$cmd' is required but not installed." >&2
        exit 1
    fi
done

# ── Auto-generate fallback colors.json if missing ──────────────────────────
# Instead of erroring, we bootstrap a sensible default palette so the script
# works out-of-the-box on any system — even before 'wal -i' has been run.
_generate_fallback_colors() {
    local target_dir
    target_dir="$(dirname "$1")"
    mkdir -p "$target_dir"
    printf '%s\n' \
        '{' \
        '  "special": {' \
        '    "background": "#1a1a2e",' \
        '    "foreground": "#e0def4",' \
        '    "cursor": "#e0def4"' \
        '  },' \
        '  "colors": {' \
        '    "color0": "#1a1a2e",' \
        '    "color1": "#e06c75",' \
        '    "color2": "#98c379",' \
        '    "color3": "#e5c07b",' \
        '    "color4": "#61afef",' \
        '    "color5": "#c678dd",' \
        '    "color6": "#56b6c2",' \
        '    "color7": "#e0def4",' \
        '    "color8": "#2e2e42",' \
        '    "color9": "#e06c75",' \
        '    "color10": "#98c379",' \
        '    "color11": "#e5c07b",' \
        '    "color12": "#61afef",' \
        '    "color13": "#c678dd",' \
        '    "color14": "#56b6c2",' \
        '    "color15": "#e0def4"' \
        '  }' \
        '}' > "$1"
    echo "  ⚠  colors.json not found — generated fallback palette at $1"
    echo "     Run 'wal -i <wallpaper>' for real wallpaper-based colors."
}

if [[ ! -f "$COLORS_JSON" ]]; then
    _generate_fallback_colors "$COLORS_JSON"
elif ! jq empty "$COLORS_JSON" 2>/dev/null; then
    echo "  ⚠  colors.json at '$COLORS_JSON' is corrupted — regenerating..."
    rm -f "$COLORS_JSON"
    _generate_fallback_colors "$COLORS_JSON"
fi

# ═══════════════════════════════════════════════════════════════════════════
#  Color math utilities  (pure bash + bc)
# ═══════════════════════════════════════════════════════════════════════════

# hex_to_rgb "#AABBCC"  →  sets R G B (0-255)
hex_to_rgb() {
    local hex="${1#\#}"
    R=$(( 16#${hex:0:2} ))
    G=$(( 16#${hex:2:2} ))
    B=$(( 16#${hex:4:2} ))
}

# rgb_to_hex R G B  →  prints "#rrggbb"
rgb_to_hex() {
    printf '#%02x%02x%02x' "$1" "$2" "$3"
}

# hex_to_hsl "#AABBCC"  →  sets H (0-360) S (0-100) L (0-100) as floats
hex_to_hsl() {
    hex_to_rgb "$1"
    local r g b
    r=$(echo "scale=6; $R / 255" | bc)
    g=$(echo "scale=6; $G / 255" | bc)
    b=$(echo "scale=6; $B / 255" | bc)

    local cmax cmin delta
    cmax=$(echo "$r $g $b" | tr ' ' '\n' | sort -g | tail -1)
    cmin=$(echo "$r $g $b" | tr ' ' '\n' | sort -g | head -1)
    delta=$(echo "scale=6; $cmax - $cmin" | bc)

    # Lightness
    L=$(echo "scale=4; ($cmax + $cmin) / 2 * 100" | bc)

    # Saturation
    if (( $(echo "$delta == 0" | bc -l) )); then
        S="0"
        H="0"
    else
        if (( $(echo "$L > 50" | bc -l) )); then
            S=$(echo "scale=4; $delta / (2 - $cmax - $cmin) * 100" | bc)
        else
            S=$(echo "scale=4; $delta / ($cmax + $cmin) * 100" | bc)
        fi

        # Hue
        if (( $(echo "$cmax == $r" | bc -l) )); then
            H=$(echo "scale=4; (($g - $b) / $delta) * 60" | bc)
        elif (( $(echo "$cmax == $g" | bc -l) )); then
            H=$(echo "scale=4; ((($b - $r) / $delta) + 2) * 60" | bc)
        else
            H=$(echo "scale=4; ((($r - $g) / $delta) + 4) * 60" | bc)
        fi

        # Normalize hue to [0, 360)
        if (( $(echo "$H < 0" | bc -l) )); then
            H=$(echo "scale=4; $H + 360" | bc)
        fi
    fi
}

# hsl_to_hex H S L  →  prints "#rrggbb"
# H: 0-360, S: 0-100, L: 0-100
hsl_to_hex() {
    local h="$1" s="$2" l="$3"
    local r g b

    s=$(echo "scale=6; $s / 100" | bc)
    l=$(echo "scale=6; $l / 100" | bc)

    if (( $(echo "$s == 0" | bc -l) )); then
        r=$(echo "scale=0; $l * 255 / 1" | bc)
        g="$r"; b="$r"
    else
        local q p
        if (( $(echo "$l < 0.5" | bc -l) )); then
            q=$(echo "scale=6; $l * (1 + $s)" | bc)
        else
            q=$(echo "scale=6; $l + $s - $l * $s" | bc)
        fi
        p=$(echo "scale=6; 2 * $l - $q" | bc)

        # hue_to_rgb helper — reads p, q and a normalized hue t
        _hue2rgb() {
            local pp="$1" qq="$2" t="$3"
            # normalize t to [0,1)
            if (( $(echo "$t < 0" | bc -l) )); then t=$(echo "$t + 1" | bc); fi
            if (( $(echo "$t > 1" | bc -l) )); then t=$(echo "$t - 1" | bc); fi

            if (( $(echo "$t < 1/6" | bc -l) )); then
                echo "scale=6; $pp + ($qq - $pp) * 6 * $t" | bc
            elif (( $(echo "$t < 1/2" | bc -l) )); then
                echo "$qq"
            elif (( $(echo "$t < 2/3" | bc -l) )); then
                echo "scale=6; $pp + ($qq - $pp) * (2/3 - $t) * 6" | bc
            else
                echo "$pp"
            fi
        }

        local hNorm
        hNorm=$(echo "scale=6; $h / 360" | bc)

        r=$(_hue2rgb "$p" "$q" "$(echo "scale=6; $hNorm + 1/3" | bc)")
        g=$(_hue2rgb "$p" "$q" "$hNorm")
        b=$(_hue2rgb "$p" "$q" "$(echo "scale=6; $hNorm - 1/3" | bc)")

        r=$(echo "scale=0; ($r * 255 + 0.5) / 1" | bc)
        g=$(echo "scale=0; ($g * 255 + 0.5) / 1" | bc)
        b=$(echo "scale=0; ($b * 255 + 0.5) / 1" | bc)
    fi

    # clamp
    (( r > 255 )) && r=255; (( r < 0 )) && r=0
    (( g > 255 )) && g=255; (( g < 0 )) && g=0
    (( b > 255 )) && b=255; (( b < 0 )) && b=0

    rgb_to_hex "$r" "$g" "$b"
}

# lighten_hex "#rrggbb" amount  →  prints lightened hex
# amount is 0-100 (percentage points to add to L)
lighten_hex() {
    hex_to_hsl "$1"
    local newL
    newL=$(echo "scale=4; l = $L + $2; if (l > 100) l = 100; l" | bc)
    hsl_to_hex "$H" "$S" "$newL"
}

# darken_hex "#rrggbb" amount  →  prints darkened hex
darken_hex() {
    hex_to_hsl "$1"
    local newL
    newL=$(echo "scale=4; l = $L - $2; if (l < 0) l = 0; l" | bc)
    hsl_to_hex "$H" "$S" "$newL"
}

# Get saturation of a hex color (returns float 0-100)
get_saturation() {
    hex_to_hsl "$1"
    echo "$S"
}

# Hue distance considering circularity (returns 0-180)
hue_distance() {
    local d
    d=$(echo "scale=4; d = $1 - $2; if (d < 0) d = -d; if (d > 180) d = 360 - d; d" | bc)
    echo "$d"
}

# Determine if a color is "light" (L > 50)
is_light() {
    hex_to_hsl "$1"
    (( $(echo "$L > 50" | bc -l) ))
}

# Pick a contrasting foreground for a given background
contrast_fg() {
    if is_light "$1"; then
        echo "#1a1a1a"
    else
        echo "#ffffff"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  Read pywal palette
# ═══════════════════════════════════════════════════════════════════════════
echo "── pywal16-gtk ──────────────────────────────────────────"
echo "  Reading: $COLORS_JSON"

BG=$(jq -r '.special.background' "$COLORS_JSON")
FG=$(jq -r '.special.foreground' "$COLORS_JSON")

declare -a WAL_COLORS
for i in $(seq 0 15); do
    WAL_COLORS[$i]=$(jq -r ".colors.color${i}" "$COLORS_JSON")
done

echo "  Background : $BG"
echo "  Foreground : $FG"
echo "  Palette    : ${WAL_COLORS[1]} ${WAL_COLORS[2]} ${WAL_COLORS[3]} ${WAL_COLORS[4]} ${WAL_COLORS[5]} ${WAL_COLORS[6]}"

# ═══════════════════════════════════════════════════════════════════════════
#  Intelligent role assignment via hue analysis
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "  Analyzing hues..."

# We analyze colors 1-6 (the main non-bg/fg/dim colors) for role assignment
# Track best candidates for each role
BEST_ACCENT=""
BEST_ACCENT_SAT=0
BEST_RED=""
BEST_RED_DIST=999
BEST_GREEN=""
BEST_GREEN_DIST=999
BEST_YELLOW=""
BEST_YELLOW_DIST=999

for i in 1 2 3 4 5 6; do
    c="${WAL_COLORS[$i]}"
    hex_to_hsl "$c"
    local_h="$H"
    local_s="$S"
    local_l="$L"

    # Skip very desaturated colors (< 15% saturation)
    if (( $(echo "$local_s < 15" | bc -l) )); then
        continue
    fi

    # ── Best accent: highest saturation ──
    if (( $(echo "$local_s > $BEST_ACCENT_SAT" | bc -l) )); then
        BEST_ACCENT="$c"
        BEST_ACCENT_SAT="$local_s"
    fi

    # ── Best red: hue closest to 0/360 (within ±40°) ──
    red_d=""
    red_d=$(hue_distance "$local_h" "0")
    if (( $(echo "$red_d < 40 && $red_d < $BEST_RED_DIST" | bc -l) )); then
        BEST_RED="$c"
        BEST_RED_DIST="$red_d"
    fi

    # ── Best green: hue closest to 140° (within ±50°) ──
    green_d=""
    green_d=$(hue_distance "$local_h" "140")
    if (( $(echo "$green_d < 50 && $green_d < $BEST_GREEN_DIST" | bc -l) )); then
        BEST_GREEN="$c"
        BEST_GREEN_DIST="$green_d"
    fi

    # ── Best yellow/orange: hue closest to 45° (within ±30°) ──
    yellow_d=""
    yellow_d=$(hue_distance "$local_h" "45")
    if (( $(echo "$yellow_d < 30 && $yellow_d < $BEST_YELLOW_DIST" | bc -l) )); then
        BEST_YELLOW="$c"
        BEST_YELLOW_DIST="$yellow_d"
    fi
done

# ── Fallbacks ───────────────────────────────────────────────────────────────
# If no suitable hue was found, use sensible defaults
[[ -z "$BEST_ACCENT" ]]  && BEST_ACCENT="${WAL_COLORS[4]}"
[[ -z "$BEST_RED" ]]     && BEST_RED="#ff6b6b"
[[ -z "$BEST_GREEN" ]]   && BEST_GREEN="#51cf66"
[[ -z "$BEST_YELLOW" ]]  && BEST_YELLOW="#ffd43b"

# ── Derive accent_color (lighter variant for focus rings / links) ──
ACCENT_COLOR=$(lighten_hex "$BEST_ACCENT" 15)
ACCENT_FG=$(contrast_fg "$BEST_ACCENT")

# ── Derive error/destructive/success/warning fg colors ──
ERROR_FG=$(contrast_fg "$BEST_RED")
SUCCESS_FG=$(contrast_fg "$BEST_GREEN")
WARNING_FG=$(contrast_fg "$BEST_YELLOW")

echo "  Accent     : $BEST_ACCENT  (saturation: $BEST_ACCENT_SAT)"
echo "  Accent fg  : $ACCENT_FG"
echo "  Accent ring: $ACCENT_COLOR"
echo "  Error      : $BEST_RED"
echo "  Success    : $BEST_GREEN"
echo "  Warning    : $BEST_YELLOW"

# ═══════════════════════════════════════════════════════════════════════════
#  Surface elevation hierarchy
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "  Computing surface elevations..."

WINDOW_BG="$BG"
WINDOW_FG="$FG"
HEADERBAR_BG=$(lighten_hex "$BG" 3)
VIEW_BG="$BG"
VIEW_FG="$FG"
CARD_BG=$(lighten_hex "$BG" 5)
SIDEBAR_BG=$(lighten_hex "$BG" 4)
POPOVER_BG=$(lighten_hex "$BG" 6)
DIALOG_BG=$(lighten_hex "$BG" 8)
NAV_SIDEBAR_BG=$(lighten_hex "$BG" 3)

echo "  Window     : $WINDOW_BG"
echo "  Headerbar  : $HEADERBAR_BG"
echo "  Card       : $CARD_BG"
echo "  Sidebar    : $SIDEBAR_BG"
echo "  Popover    : $POPOVER_BG"
echo "  Dialog     : $DIALOG_BG"

# ═══════════════════════════════════════════════════════════════════════════
#  Generate CSS
# ═══════════════════════════════════════════════════════════════════════════

generate_css() {
    local version="$1"  # "gtk3" or "gtk4"
    cat <<EOF
/*
 * GTK Colors — Generated by pywal16-gtk
 * Source: ${COLORS_JSON}
 * Version: ${version}
 * Generated: $(date '+%Y-%m-%d %H:%M:%S')
 */

/* ── Accent ─────────────────────────────────────────────── */
@define-color accent_color ${ACCENT_COLOR};
@define-color accent_fg_color ${ACCENT_FG};
@define-color accent_bg_color ${BEST_ACCENT};

/* ── Destructive / Error ────────────────────────────────── */
@define-color destructive_bg_color ${BEST_RED};
@define-color destructive_fg_color ${ERROR_FG};
@define-color error_bg_color ${BEST_RED};
@define-color error_fg_color ${ERROR_FG};

/* ── Success ────────────────────────────────────────────── */
@define-color success_bg_color ${BEST_GREEN};
@define-color success_fg_color ${SUCCESS_FG};
@define-color success_color ${BEST_GREEN};

/* ── Warning ────────────────────────────────────────────── */
@define-color warning_bg_color ${BEST_YELLOW};
@define-color warning_fg_color ${WARNING_FG};
@define-color warning_color ${BEST_YELLOW};

/* ── Window ─────────────────────────────────────────────── */
@define-color window_bg_color ${WINDOW_BG};
@define-color window_fg_color ${WINDOW_FG};

/* ── Views ──────────────────────────────────────────────── */
@define-color view_bg_color ${VIEW_BG};
@define-color view_fg_color ${VIEW_FG};

/* ── Headerbar ──────────────────────────────────────────── */
@define-color headerbar_bg_color ${HEADERBAR_BG};
@define-color headerbar_fg_color ${WINDOW_FG};

/* ── Sidebar ────────────────────────────────────────────── */
@define-color sidebar_bg_color ${SIDEBAR_BG};
@define-color sidebar_fg_color ${WINDOW_FG};

/* ── Cards ──────────────────────────────────────────────── */
@define-color card_bg_color ${CARD_BG};
@define-color card_fg_color ${WINDOW_FG};

/* ── Popovers ───────────────────────────────────────────── */
@define-color popover_bg_color ${POPOVER_BG};
@define-color popover_fg_color ${WINDOW_FG};

/* ── Dialogs ────────────────────────────────────────────── */
@define-color dialog_bg_color ${DIALOG_BG};
@define-color dialog_fg_color ${WINDOW_FG};

/* ── Backdrop / Unfocused — prevents white flash ────────── */
@define-color headerbar_backdrop_color @window_bg_color;
@define-color sidebar_backdrop_color @sidebar_bg_color;
@define-color theme_unfocused_fg_color @window_fg_color;
@define-color theme_unfocused_text_color @view_fg_color;
@define-color theme_unfocused_bg_color @window_bg_color;
@define-color theme_unfocused_base_color @window_bg_color;
@define-color theme_unfocused_selected_bg_color @accent_bg_color;
@define-color theme_unfocused_selected_fg_color @accent_fg_color;

/* ── Pywal raw palette (for custom widgets) ─────────────── */
@define-color wal_bg ${BG};
@define-color wal_fg ${FG};
@define-color wal_color0 ${WAL_COLORS[0]};
@define-color wal_color1 ${WAL_COLORS[1]};
@define-color wal_color2 ${WAL_COLORS[2]};
@define-color wal_color3 ${WAL_COLORS[3]};
@define-color wal_color4 ${WAL_COLORS[4]};
@define-color wal_color5 ${WAL_COLORS[5]};
@define-color wal_color6 ${WAL_COLORS[6]};
@define-color wal_color7 ${WAL_COLORS[7]};
@define-color wal_color8 ${WAL_COLORS[8]};
@define-color wal_color9 ${WAL_COLORS[9]};
@define-color wal_color10 ${WAL_COLORS[10]};
@define-color wal_color11 ${WAL_COLORS[11]};
@define-color wal_color12 ${WAL_COLORS[12]};
@define-color wal_color13 ${WAL_COLORS[13]};
@define-color wal_color14 ${WAL_COLORS[14]};
@define-color wal_color15 ${WAL_COLORS[15]};
EOF

    # GTK 4 extra: navigation sidebar styling
    if [[ "$version" == "gtk4" ]]; then
        cat <<EOF

.navigation-sidebar {
    background-color: ${NAV_SIDEBAR_BG};
}
EOF
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  Write or display
# ═══════════════════════════════════════════════════════════════════════════

if $DRY_RUN; then
    echo ""
    echo "═══ GTK 3 colors.css ═══"
    generate_css "gtk3"
    echo ""
    echo "═══ GTK 4 colors.css ═══"
    generate_css "gtk4"
else
    # Ensure directories exist
    mkdir -p "$GTK3_DIR" "$GTK4_DIR"

    # Auto-create gtk.css with @import if missing or lacking the import
    for d in "$GTK3_DIR" "$GTK4_DIR"; do
        if [[ ! -f "$d/gtk.css" ]]; then
            echo '@import "colors.css";' > "$d/gtk.css"
            echo "  ✓ Created $d/gtk.css (with colors.css import)"
        elif ! grep -q 'colors.css' "$d/gtk.css" 2>/dev/null; then
            # Prepend the import to the existing file
            tmp=$(mktemp)
            { echo '@import "colors.css";'; cat "$d/gtk.css"; } > "$tmp"
            mv "$tmp" "$d/gtk.css"
            echo "  ✓ Added colors.css import to $d/gtk.css"
        fi
    done

    # Backup existing files
    for d in "$GTK3_DIR" "$GTK4_DIR"; do
        if [[ -f "$d/colors.css" ]]; then
            cp "$d/colors.css" "$d/colors.css.bak"
        fi
    done

    # Write GTK 3
    generate_css "gtk3" > "$GTK3_DIR/colors.css"
    echo ""
    echo "  ✓ Wrote $GTK3_DIR/colors.css"

    # Write GTK 4
    generate_css "gtk4" > "$GTK4_DIR/colors.css"
    echo "  ✓ Wrote $GTK4_DIR/colors.css"

    # gtk.css import already handled above — no warning needed

    echo ""
    echo "  Backups saved as colors.css.bak"
    echo "  Restart GTK apps to see changes."
fi

echo ""
echo "── done ────────────────────────────────────────────────"
