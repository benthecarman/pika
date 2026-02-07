package com.pika.app

import android.app.Application
import android.content.Context
import androidx.test.runner.AndroidJUnitRunner
import java.io.File

/**
 * Instrumentation tests must be deterministic and not depend on public Nostr relays.
 * We force-disable networking for tests by writing pika_config.json into the app filesDir
 * before the app process starts.
 */
class PikaTestRunner : AndroidJUnitRunner() {
    override fun newApplication(cl: ClassLoader?, className: String?, context: Context?): Application {
        val app = super.newApplication(cl, className, context)
        runCatching {
            val path = File(app.filesDir, "pika_config.json")
            path.writeText("""{"disable_network":true}""")
        }
        return app
    }
}

