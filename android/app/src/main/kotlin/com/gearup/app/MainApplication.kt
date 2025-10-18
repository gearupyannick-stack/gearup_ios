package com.gearup.app

import android.app.Application
import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // 1. Initialise Firebase avant App Check (bien que Firebase.initializeApp dans Flutter le fasse)
        // FirebaseApp.initializeApp(this); 

        // 2. Initialisation App Check au point le plus précoce
        val appCheck = FirebaseAppCheck.getInstance()

        if (BuildConfig.DEBUG) {
            // Utilise le mode Debug Token UNIQUEMENT pour le développement
            appCheck.installAppCheckProviderFactory(
                DebugAppCheckProviderFactory.getInstance()
            )
        } else {
            // Utilise Play Integrity pour la production
            appCheck.installAppCheckProviderFactory(
                PlayIntegrityAppCheckProviderFactory.getInstance()
            )
        }
    }
}
