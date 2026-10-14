# flutter_local_notifications: R8 strips classes it needs to reschedule
# reminders after reboot and to restore notification action receivers.
# Documented in the plugin README under "Proguard rules".
-keep class com.dexterous.** { *; }
