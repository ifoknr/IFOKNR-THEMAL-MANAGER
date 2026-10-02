#!/system/bin/sh
MODDIR=${0%/*}

# تسجيل معرف العملية للواجهة
echo $$ > "$MODDIR/service.pid"

# انتظار اكتمال إقلاع النظام
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done
sleep 5

# إنشاء الملفات التأسيسية
[ ! -f "$MODDIR/mode" ] && echo "balanced" > "$MODDIR/mode"
[ ! -f "$MODDIR/current_mode" ] && echo "0" > "$MODDIR/current_mode"
[ ! -f "$MODDIR/auto_battery" ] && echo "0" > "$MODDIR/auto_battery"

# دالة إعادة ضبط ترددات المعالج للوضع الحر
reset_frequencies() {
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
        if [ -d "$cpu" ]; then
            chmod 644 "$cpu/scaling_min_freq" "$cpu/scaling_max_freq" 2>/dev/null
            cat "$cpu/cpuinfo_min_freq" > "$cpu/scaling_min_freq" 2>/dev/null
            cat "$cpu/cpuinfo_max_freq" > "$cpu/scaling_max_freq" 2>/dev/null
            echo "schedutil" > "$cpu/scaling_governor" 2>/dev/null
        fi
    done
}

# دالة محرك الرسوميات لميديا تيك
set_gpu_boost() {
    local val=$1
    [ -f /sys/module/ged/parameters/gx_game_mode ] && echo "$val" > /sys/module/ged/parameters/gx_game_mode
    [ -f /sys/module/ged/parameters/boost_gpu_enable ] && echo "$val" > /sys/module/ged/parameters/boost_gpu_enable
    [ -f /sys/module/ged/parameters/gx_force_cpu_boost ] && echo "$val" > /sys/module/ged/parameters/gx_force_cpu_boost
}

set_profile() {
    case "$1" in
        "gaming"|"19")
            pm disable-user --user 0 com.samsung.android.game.gos >/dev/null 2>&1
            pm disable-user --user 0 com.samsung.android.game.gametools >/dev/null 2>&1
            setprop persist.sys.thermal.screen 0
            
            reset_frequencies
            set_gpu_boost 1

            # تطبيق حاكم sugov_ext وتسريع الاستجابة الفورية
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
                [ -d "$cpu" ] && echo "sugov_ext" > "$cpu/scaling_governor" 2>/dev/null
            done
            for pol in /sys/devices/system/cpu/cpufreq/policy*; do
                [ -d "$pol" ] && echo "sugov_ext" > "$pol/scaling_governor" 2>/dev/null
            done
            [ -d /sys/devices/system/cpu/cpufreq/sugov_ext ] && echo 0 > /sys/devices/system/cpu/cpufreq/sugov_ext/up_rate_limit_us 2>/dev/null

            # رفع الحد الأدنى للأنوية Cortex-X4 إلى 1.8GHz لمنع تساقط الفريمات
            for cpu in /sys/devices/system/cpu/cpu[4-7]/cpufreq; do
                [ -d "$cpu" ] && echo "1800000" > "$cpu/scaling_min_freq" 2>/dev/null
            done
            ;;

        "performance"|"6")
            pm disable-user --user 0 com.samsung.android.game.gos >/dev/null 2>&1
            setprop persist.sys.thermal.screen 0
            
            reset_frequencies
            set_gpu_boost 1

            # تطبيق حاكم sugov_ext وتسريع الاستجابة الفورية
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
                [ -d "$cpu" ] && echo "sugov_ext" > "$cpu/scaling_governor" 2>/dev/null
            done
            for pol in /sys/devices/system/cpu/cpufreq/policy*; do
                [ -d "$pol" ] && echo "sugov_ext" > "$pol/scaling_governor" 2>/dev/null
            done
            [ -d /sys/devices/system/cpu/cpufreq/sugov_ext ] && echo 0 > /sys/devices/system/cpu/cpufreq/sugov_ext/up_rate_limit_us 2>/dev/null
            ;;

        "battery"|"1")
            pm enable com.samsung.android.game.gos >/dev/null 2>&1
            setprop persist.sys.thermal.screen 1
            set_gpu_boost 0

            # تقييد الأنوية الكبرى إلى 1.4GHz لتوفير الشحن
            for cpu in /sys/devices/system/cpu/cpu[4-7]/cpufreq; do
                if [ -d "$cpu" ]; then
                    echo "1400000" > "$cpu/scaling_max_freq" 2>/dev/null
                    echo "powersave" > "$cpu/scaling_governor" 2>/dev/null
                fi
            done
            ;;

        "balanced"|"0"|*)
            pm enable com.samsung.android.game.gos >/dev/null 2>&1
            setprop persist.sys.thermal.screen 1
            set_gpu_boost 0
            reset_frequencies
            ;;
    esac

    # تحديث بطاقة التعريف
    [ -f "$MODDIR/update-desc.sh" ] && sh "$MODDIR/update-desc.sh" "$1"
}

# المراقبة الدورية لتطبيق الأنماط
LAST_MODE=""
while true; do
    echo $$ > "$MODDIR/service.pid"
    CURRENT_MODE=$(cat "$MODDIR/mode" 2>/dev/null)
    AUTO_BAT=$(cat "$MODDIR/auto_battery" 2>/dev/null)
    SCREEN_ON=$(dumpsys power | grep -q "mWakefulness=Awake" && echo "1" || echo "0")

    if [ "$AUTO_BAT" = "1" ] && [ "$SCREEN_ON" = "0" ]; then
        if [ "$LAST_MODE" != "screen_off_battery" ]; then
            set_profile "battery"
            LAST_MODE="screen_off_battery"
        fi
    else
        if [ "$CURRENT_MODE" != "$LAST_MODE" ]; then
            set_profile "$CURRENT_MODE"
            LAST_MODE="$CURRENT_MODE"
        fi
    fi
    sleep 4
done
