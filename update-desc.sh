#!/system/bin/sh
MODDIR=${0%/*}
MODE=$1

case "$MODE" in
    "gaming"|"19") ICON="🎮 [Gaming]" ;;
    "performance"|"6") ICON="⚡ [Performance]" ;;
    "battery"|"1") ICON="🔋 [Battery Saver]" ;;
    "balanced"|"0"|*) ICON="⚖️ [Balanced]" ;;
esac

sed -i "s/^description=.*/description=Custom fork by ifoknr for Tab S10 Ultra. Current: $ICON/" "$MODDIR/module.prop"