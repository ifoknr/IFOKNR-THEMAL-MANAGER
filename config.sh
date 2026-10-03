##########################################################################################
# IFOKNR - Thermal Manager Installation Configuration
##########################################################################################

SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true

print_modname() {
  ui_print "****************************************"
  ui_print "       IFOKNR - Thermal Manager         "
  ui_print "   Galaxy Tab S10 Ultra (Dimensity 9300) "
  ui_print "       Custom Fork by @ifoknr           "
  ui_print "****************************************"
}

on_install() {
  ui_print "- Extracting module files..."
  unzip -o "$ZIPFILE" 'webroot/*' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'service.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'update-desc.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'module.prop' -d $MODPATH >&2
}

set_permissions() {
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm $MODPATH/service.sh 0 0 0755
  set_perm $MODPATH/update-desc.sh 0 0 0755
}