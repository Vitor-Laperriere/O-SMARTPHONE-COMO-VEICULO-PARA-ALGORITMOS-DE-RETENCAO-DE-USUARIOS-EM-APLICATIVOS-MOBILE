package com.example.foco_tela

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class FocoNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        AndroidNotificationStore.recordPosted(applicationContext, sbn)
    }
}
