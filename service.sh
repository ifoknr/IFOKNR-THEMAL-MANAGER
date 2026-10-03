#!/system/bin/sh
MODDIR=${0%/*}
LOG="$MODDIR/service.log"
ORIG="$MODDIR/orig"
CPUFREQ=/sys/devices/system/cpu/cpufreq
GED=/sys/module/ged/parameters

# Frequency (kHz) above which a cpufreq policy is treated as a "big" cluster.
# On the Dimensity 9300+ this selects the Cortex-X4 clusters (cpu4-6 / cpu7)
# and leaves the Cortex-A720 cluster (cpu0-3) to the stock scheduler.
BIG_MIN_KHZ=2500000
GAMING_FLOOR_KHZ=1800000
BATTERY_CAP_KHZ=1400000

# Thermal guard (Gaming only): above TEMP_LIMIT (deg C) the frequency floor is
# dropped and Samsung GOS is re-enabled; it resumes at TEMP_LIMIT - TEMP_HYST.
TEMP_LIMIT_DEFAULT=75
TEMP_HYST=7

echo $$ > "$MODDIR/service.pid"

log() {
    echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"
}

# Keep the log small
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 65536 ] && : > "$LOG"

# Wait for the system to finish booting
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done
sleep 5

# Base files
[ ! -f "$MODDIR/mode" ] && echo "balanced" > "$MODDIR/mode"
[ ! -f "$MODDIR/current_mode" ] && echo "0" > "$MODDIR/current_mode"
[ ! -f "$MODDIR/auto_battery" ] && echo "0" > "$MODDIR/auto_battery"

PLATFORM="$(getprop ro.board.platform)"
case "$PLATFORM" in
    mt6989*) log "Platform $PLATFORM (Dimensity 9300/9300+)" ;;
    *) log "WARNING: platform '$PLATFORM' is not mt6989; tweaks are node-guarded but untested here" ;;
esac

# ---------------------------------------------------------------- helpers ---

# w <value> <file>: write if the node exists, never leave it read-only
w() {
    [ -e "$2" ] || return 1
    chmod 644 "$2" 2>/dev/null
    echo "$1" > "$2" 2>/dev/null
}

# Policies of the big clusters (auto-detected by max frequency)
big_policies() {
    for pol in "$CPUFREQ"/policy*; do
        [ -r "$pol/cpuinfo_max_freq" ] || continue
        max=$(cat "$pol/cpuinfo_max_freq" 2>/dev/null)
        [ "$max" -ge "$BIG_MIN_KHZ" ] 2>/dev/null && echo "$pol"
    done
}

has_gov() {   # has_gov <policy> <governor>
    case " $(cat "$1/scaling_available_governors" 2>/dev/null) " in
        *" $2 "*) return 0 ;;
    esac
    return 1
}

# Remember the stock governor of every policy once per boot, before any change
save_original_governors() {
    mkdir -p "$ORIG"
    for pol in "$CPUFREQ"/policy*; do
        [ -r "$pol/scaling_governor" ] || continue
        cat "$pol/scaling_governor" > "$ORIG/$(basename "$pol")" 2>/dev/null
    done
}

# Back to stock limits and stock governors
reset_frequencies() {
    for pol in "$CPUFREQ"/policy*; do
        [ -d "$pol" ] || continue
        w "$(cat "$pol/cpuinfo_min_freq" 2>/dev/null)" "$pol/scaling_min_freq"
        w "$(cat "$pol/cpuinfo_max_freq" 2>/dev/null)" "$pol/scaling_max_freq"
        orig=$(cat "$ORIG/$(basename "$pol")" 2>/dev/null)
        if [ -n "$orig" ]; then
            w "$orig" "$pol/scaling_governor"
        elif has_gov "$pol" schedutil; then
            w schedutil "$pol/scaling_governor"
        fi
    done
}

# MediaTek GED GPU / frame boost
set_gpu_boost() {
    for n in gx_game_mode boost_gpu_enable gx_force_cpu_boost; do
        w "$1" "$GED/$n"
    done
}

# Prefer sugov_ext (MediaTek's governor), fall back to schedutil, and zero the
# up-rate limit in the per-policy directory where it really lives.
apply_fast_governor() {
    for pol in "$CPUFREQ"/policy*; do
        [ -d "$pol" ] || continue
        if has_gov "$pol" sugov_ext; then
            gov=sugov_ext
        elif has_gov "$pol" schedutil; then
            gov=schedutil
        else
            continue
        fi
        w "$gov" "$pol/scaling_governor"
        w 0 "$pol/$gov/up_rate_limit_us"
    done
}

gos_disable() {
    pm disable-user --user 0 com.samsung.android.game.gos >/dev/null 2>&1
    [ "$1" = "all" ] && \
        pm disable-user --user 0 com.samsung.android.game.gametools >/dev/null 2>&1
}

gos_enable() {
    pm enable com.samsung.android.game.gos >/dev/null 2>&1
    pm enable com.samsung.android.game.gametools >/dev/null 2>&1
}

norm_mode() {
    case "$1" in
        gaming|19) echo gaming ;;
        performance|6) echo performance ;;
        battery|1) echo battery ;;
        *) echo balanced ;;
    esac
}

# Hottest relevant thermal zone in deg C (read-only; zones are never modified).
# Prints 0 when no matching zone is found.
get_soc_temp() {
    max=0
    for z in /sys/class/thermal/thermal_zone*; do
        case "$(cat "$z/type" 2>/dev/null)" in
            *cpu*|*soc*|*gpu*|*big*|*mtk*) ;;
            *) continue ;;
        esac
        v=$(cat "$z/temp" 2>/dev/null)
        [ -n "$v" ] || continue
        [ "$v" -gt 1000 ] 2>/dev/null && v=$((v / 1000))
        [ "$v" -gt 0 ] 2>/dev/null && [ "$v" -lt 150 ] 2>/dev/null || continue
        [ "$v" -gt "$max" ] && max=$v
    done
    echo "$max"
}

get_temp_limit() {
    l=$(cat "$MODDIR/temp_limit" 2>/dev/null)
    case "$l" in
        ''|*[!0-9]*) echo "$TEMP_LIMIT_DEFAULT" ;;
        *) echo "$l" ;;
    esac
}

# Gaming CPU floor on the big clusters only
apply_gaming_floor() {
    for pol in $(big_policies); do
        max=$(cat "$pol/cpuinfo_max_freq" 2>/dev/null)
        floor=$GAMING_FLOOR_KHZ
        [ "$floor" -gt "$max" ] 2>/dev/null && floor=$max
        w "$floor" "$pol/scaling_min_freq"
    done
}

set_profile() {
    case "$(norm_mode "$1")" in
        gaming)
            gos_disable all
            reset_frequencies
            set_gpu_boost 1
            apply_fast_governor
            apply_gaming_floor
            ;;
        performance)
            gos_disable
            reset_frequencies
            set_gpu_boost 1
            apply_fast_governor
            ;;
        battery)
            gos_enable
            set_gpu_boost 0
            # Reset first so a leftover Gaming floor never exceeds the new cap
            reset_frequencies
            for pol in $(big_policies); do
                w "$BATTERY_CAP_KHZ" "$pol/scaling_max_freq"
                has_gov "$pol" powersave && w powersave "$pol/scaling_governor"
            done
            ;;
        *)
            gos_enable
            set_gpu_boost 0
            reset_frequencies
            ;;
    esac

    log "Profile applied: $(norm_mode "$1")"
    [ -f "$MODDIR/update-desc.sh" ] && sh "$MODDIR/update-desc.sh" "$1"
}

screen_is_on() {
    dumpsys power 2>/dev/null | grep -q "mWakefulness=Awake"
}

# ------------------------------------------------------------------- main ---

save_original_governors

if [ -z "$(big_policies)" ]; then
    log "No cpufreq policy >= ${BIG_MIN_KHZ} kHz found: CPU floor/cap will not be applied"
fi
if [ "$(get_soc_temp)" = "0" ]; then
    log "No usable thermal zone found: Gaming thermal guard is inactive"
fi

LAST_MODE=""
GAME_HOT=0

while true; do
    CURRENT_MODE=$(norm_mode "$(cat "$MODDIR/mode" 2>/dev/null)")
    AUTO_BAT=$(cat "$MODDIR/auto_battery" 2>/dev/null)

    # dumpsys is expensive: only query the screen when the feature is enabled
    EFFECTIVE="$CURRENT_MODE"
    if [ "$AUTO_BAT" = "1" ] && ! screen_is_on; then
        EFFECTIVE="battery"
    fi

    if [ "$EFFECTIVE" != "$LAST_MODE" ]; then
        GAME_HOT=0
        set_profile "$EFFECTIVE"
        LAST_MODE="$EFFECTIVE"
    fi

    # Thermal guard: Gaming only
    if [ "$EFFECTIVE" = "gaming" ]; then
        TEMP=$(get_soc_temp)
        LIMIT=$(get_temp_limit)
        if [ "$GAME_HOT" = "0" ] && [ "$TEMP" -ge "$LIMIT" ]; then
            GAME_HOT=1
            reset_frequencies
            gos_enable
            log "Thermal guard: ${TEMP}C >= ${LIMIT}C, Gaming floor released and GOS re-enabled"
        elif [ "$GAME_HOT" = "1" ] && [ "$TEMP" -le $((LIMIT - TEMP_HYST)) ]; then
            GAME_HOT=0
            set_profile "gaming"
            log "Thermal guard: ${TEMP}C, Gaming restored"
        fi
    fi

    sleep 5
done
