#!/system/bin/sh
MODDIR=${0%/*}

case "$1" in
    gaming|19) ICON="🎮 [Gaming]" ;;
    performance|6) ICON="⚡ [Performance]" ;;
    battery|1) ICON="🔋 [Battery Saver]" ;;
    *) ICON="⚖️ [Balanced]" ;;
esac

sed -i "s/^description=.*/description=Performance profiles, auto game mode and thermal guard for Galaxy Tab S10 Ultra (Dimensity 9300+). Current: $ICON/" "$MODDIR/module.prop"
