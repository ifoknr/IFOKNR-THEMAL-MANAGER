##########################################################################################
# IFOKNR - Thermal Manager installer (customize.sh, used by Magisk 20.4+/KernelSU/APatch)
# Module files are extracted automatically; this script only prints info and sets perms.
##########################################################################################

ui_print "****************************************"
ui_print "       IFOKNR - Thermal Manager         "
ui_print "   Galaxy Tab S10 Ultra (Dimensity 9300) "
ui_print "       Custom Fork by @ifoknr           "
ui_print "****************************************"

PLATFORM="$(getprop ro.board.platform)"
case "$PLATFORM" in
  mt6989*) ui_print "- Detected platform: $PLATFORM (Dimensity 9300/9300+)" ;;
  *)
    ui_print "! Warning: platform '$PLATFORM' is not mt6989."
    ui_print "! This module is made for the Galaxy Tab S10 Ultra; use at your own risk."
    ;;
esac

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/update-desc.sh" 0 0 0755
