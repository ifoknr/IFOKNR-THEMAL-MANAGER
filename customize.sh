##########################################################################################
# IFOKNR - Thermal Manager installer (customize.sh, used by Magisk 20.4+/KernelSU/APatch)
# Module files are extracted automatically; this script only prints info and sets perms.
##########################################################################################

ui_print "****************************************"
ui_print "       IFOKNR - Thermal Manager         "
ui_print "   Galaxy Tab S10 Ultra (Dimensity 9300) "
ui_print "       Custom Fork by @ifoknr           "
ui_print "****************************************"

# التحقق من نوع المعالج / المنصة
PLATFORM="$(getprop ro.board.platform)"
case "$PLATFORM" in
  mt6989*) 
    ui_print "- Detected platform: $PLATFORM (Dimensity 9300/9300+)" 
    ;;
  *)
    ui_print "! Warning: platform '$PLATFORM' is not mt6989."
    ui_print "! This module is made for the Galaxy Tab S10 Ultra; use at your own risk."
    ;;
esac

ui_print "- Setting file permissions..."

# 1. ضبط الصلاحيات الافتراضية لكافة المجلدات (0755) والملفات (0644)
set_perm_recursive "$MODPATH" 0 0 0755 0644

# 2. منح صلاحية التشغيل والتنفيذ لجميع سكربتات النظام الأساسية
[ -f "$MODPATH/service.sh" ] && set_perm "$MODPATH/service.sh" 0 0 0755
[ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755
[ -f "$MODPATH/update-desc.sh" ] && set_perm "$MODPATH/update-desc.sh" 0 0 0755
[ -f "$MODPATH/config.sh" ] && set_perm "$MODPATH/config.sh" 0 0 0755

# 3. التأكد من صلاحيات مجلد وملفات الـ WebUI
if [ -d "$MODPATH/webroot" ]; then
  set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644
fi

# 4. التأكد من صلاحيات القراءة لملفات البانر والأيقونة بأي صيغة (PNG / JPG / WEBP)
for img in "$MODPATH"/banner.* "$MODPATH"/icon.*; do
  if [ -f "$img" ]; then
    set_perm "$img" 0 0 0644
  fi
done

ui_print "- Installation complete successfully!"
