package com.pika.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

private val LightColors =
    lightColorScheme(
        primary = PikaBlue,
        surface = Color.White,
        background = PikaBg,
    )

@Composable
fun PikaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        typography = androidx.compose.material3.Typography(),
        content = content,
    )
}

