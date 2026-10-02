#!/system/bin/sh
MODDIR=${0%/*}

# 1. انتظار اكتمال تشغيل النظام بالكامل
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done
sleep 5

# ملفات الحالة الافتراضية
[ ! -f "$MODDIR/mode" ] && echo "balanced" > "$MODDIR/mode"
[ ! -f "$MODDIR/auto_battery" ] && echo "0" > "$MODDIR/auto_battery"

# ========================================================
# دوال التحكم العتادي بمعالج MediaTek Dimensity 9300+
# ========================================================

# تعطيل خدمات الحماية والخنق في نظام سامسونج
disable_samsung_restrictions() {
    pm disable-user --user 0 com.samsung.android.game.gos >/dev/null 2>&1
    pm disable-user --user 0 com.samsung.android.game.gametools >/dev/null 2>&1
    pm disable-user --user 0 com.samsung.android.game.gamehome >/dev/null 2>&1
    setprop persist.sys.thermal.screen 0
    setprop sys.siop.level 0
    setprop persist.sys.siop.level 0
}

enable_samsung_restrictions() {
    pm enable com.samsung.android.game.gos >/dev/null 2>&1
    pm enable com.samsung.android.game.gametools >/dev/null 2>&1
    setprop persist.sys.thermal.screen 1
}

# تجميد وحدات التبريد الإجبارية (Thermal Cooling Devices) 
freeze_cooling_devices() {
    local state=$1
    for c in /sys/class/thermal/cooling_device*/cur_state; do
        if [ -f "$c" ]; then
            chmod 644 "$c" 2>/dev/null
            echo "$state" > "$c" 2>/dev/null
            [ "$state" = "0" ] && chmod 444 "$c" 2>/dev/null
        fi
    done
}

# رفع سقوف درجات الحرارة وقفلها من التعديل التلقائي
set_thermal_zones() {
    local target_temp=$1
    for zone in /sys/class/thermal/thermal_zone*; do
        if [ -f "$zone/type" ]; then
            type=$(cat "$zone/type" 2>/dev/null)
            case "$type" in
                *cpu*|*soc*|*gpu*|*mtktscpu*|*mtktsgpu*|*vpu*)
                    for trip in $zone/trip_point_*_temp; do
                        if [ -f "$trip" ]; then
                            chmod 644 "$trip" 2>/dev/null
                            echo "$target_temp" > "$trip" 2>/dev/null
                            chmod 444 "$trip" 2>/dev/null
                        fi
                    done
                    ;;
            esac
        fi
    done
}

# محرك كرت الشاشة MediaTek GED ومحرك الألعاب
boost_mtk_gpu() {
    local enable=$1
    # تفعيل وضع الألعاب لمحرك ميديا تيك
    [ -f /sys/module/ged/parameters/gx_game_mode ] && echo "$enable" > /sys/module/ged/parameters/gx_game_mode
    [ -f /sys/module/ged/parameters/gx_force_cpu_boost ] && echo "$enable" > /sys/module/ged/parameters/gx_force_cpu_boost
    [ -f /sys/module/ged/parameters/gx_boost_on ] && echo "$enable" > /sys/module/ged/parameters/gx_boost_on
    [ -f /sys/module/ged/parameters/boost_gpu_enable ] && echo "$enable" > /sys/module/ged/parameters/boost_gpu_enable
}

# تعزيز استجابة مجدول المهام (Scheduler / UCLAMP / Schedtune)
boost_scheduler() {
    local boost_val=$1
    # رفع أولوية الألعاب لتشغيل أنوية Cortex-X4 فوراً
    [ -f /dev/cpuset/top-app/uclamp.min ] && echo "$boost_val" > /dev/cpuset/top-app/uclamp.min
    [ -f /dev/cpuset/top-app/uclamp.latency_sensitive ] && echo "1" > /dev/cpuset/top-app/uclamp.latency_sensitive
    [ -f /dev/stune/top-app/schedtune.boost ] && echo "$boost_val" > /dev/stune/top-app/schedtune.boost
    [ -f /dev/stune/top-app/schedtune.prefer_idle ] && echo "1" > /dev/stune/top-app/schedtune.prefer_idle
}

# إعادة ترددات المعالج للوضع المصنعي الحر
restore_cpu_limits() {
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
        if [ -d "$cpu" ]; then
            chmod 644 "$cpu/scaling_min_freq" 2>/dev/null
            chmod 644 "$cpu/scaling_max_freq" 2>/dev/null
            cat "$cpu/cpuinfo_min_freq" > "$cpu/scaling_min_freq" 2>/dev/null
            cat "$cpu/cpuinfo_max_freq" > "$cpu/scaling_max_freq" 2>/dev/null
            echo "schedutil" > "$cpu/scaling_governor" 2>/dev/null
        fi
    done
}

# ========================================================
# تعريف البروفايلات الحقيقية
# ========================================================

set_profile() {
    case "$1" in
        "gaming")
            # --- بروفايل الألعاب الأقصى (وحش الأداء) ---
            disable_samsung_restrictions
            boost_mtk_gpu 1
            boost_scheduler 100
            freeze_cooling_devices 0
            set_thermal_zones "95000"

            # قفل التردد الأدنى على أعلى سرعة لمنع هبوط الفريمات نهائياً
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
                if [ -d "$cpu" ]; then
                    chmod 644 "$cpu/scaling_min_freq" 2>/dev/null
                    chmod 644 "$cpu/scaling_max_freq" 2>/dev/null
                    # رفع التردد الأدنى إلى 80% من طاقة النواة القصوى
                    MAX=$(cat "$cpu/cpuinfo_max_freq" 2>/dev/null)
                    echo "$MAX" > "$cpu/scaling_max_freq" 2>/dev/null
                    echo "$MAX" > "$cpu/scaling_min_freq" 2>/dev/null
                    echo "performance" > "$cpu/scaling_governor" 2>/dev/null
                fi
            done
            ;;

        "performance")
            # --- بروفايل الأداء العالي المستقر ---
            disable_samsung_restrictions
            boost_mtk_gpu 1
            boost_scheduler 50
            freeze_cooling_devices 0
            set_thermal_zones "85000"

            restore_cpu_limits
            # إعطاء مساحة ترددات عالية مع بقاء الحاكم مرناً
            for cpu in /sys/devices/system/cpu/cpu[4-7]/cpufreq; do
                if [ -d "$cpu" ]; then
                    MID_FREQ="2200000"
                    echo "$MID_FREQ" > "$cpu/scaling_min_freq" 2>/dev/null
                fi
            done
            ;;

        "battery")
            # --- بروفايل توفير الطاقة الفعلي ---
            enable_samsung_restrictions
            boost_mtk_gpu 0
            boost_scheduler 0
            set_thermal_zones "60000"

            # كبح جماح أنوية X4 الأربعة الضخمة (cpu4 إلى cpu7) وقصرها على 1.4GHz
            for cpu in /sys/devices/system/cpu/cpu[4-7]/cpufreq; do
                if [ -d "$cpu" ]; then
                    chmod 644 "$cpu/scaling_max_freq" 2>/dev/null
                    echo "1400000" > "$cpu/scaling_max_freq" 2>/dev/null
                    echo "powersave" > "$cpu/scaling_governor" 2>/dev/null
                fi
            done
            # الأنوية المتوسطة (cpu0 إلى cpu3)
            for cpu in /sys/devices/system/cpu/cpu[0-3]/cpufreq; do
                if [ -d "$cpu" ]; then
                    echo "schedutil" > "$cpu/scaling_governor" 2>/dev/null
                fi
            done
            ;;

        "balanced"|*)
            # --- البروفايل المتوازن اليومي ---
            enable_samsung_restrictions
            boost_mtk_gpu 0
            boost_scheduler 0
            set_thermal_zones "75000"
            restore_cpu_limits
            ;;
    esac

    # تحديث بطاقة التعريف في واجهة KernelSU
    [ -f "$MODDIR/update-desc.sh" ] && sh "$MODDIR/update-desc.sh" "$1"
}

# ========================================================
# حلقة المراقبة والتحكم في الخلفية
# ========================================================

LAST_MODE=""
while true; do
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
