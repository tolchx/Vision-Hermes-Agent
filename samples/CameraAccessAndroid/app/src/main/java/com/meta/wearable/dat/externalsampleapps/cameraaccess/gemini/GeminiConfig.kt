package com.meta.wearable.dat.externalsampleapps.cameraaccess.gemini

import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager

object GeminiConfig {
    const val WEBSOCKET_BASE_URL =
        "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
    const val MODEL = "models/gemini-2.5-flash-native-audio-preview-12-2025"

    const val INPUT_AUDIO_SAMPLE_RATE = 16000
    const val OUTPUT_AUDIO_SAMPLE_RATE = 24000
    const val AUDIO_CHANNELS = 1
    const val AUDIO_BITS_PER_SAMPLE = 16

    const val VIDEO_FRAME_INTERVAL_MS = 1000L
    const val VIDEO_JPEG_QUALITY = 50

    val systemInstruction: String
        get() = SettingsManager.geminiSystemPrompt

    val apiKey: String
        get() = SettingsManager.geminiAPIKey

    val hermesHost: String
        get() = SettingsManager.hermesHost

    val hermesPort: Int
        get() = SettingsManager.hermesPort

    val hermesHookToken: String
        get() = SettingsManager.hermesHookToken

    val hermesGatewayToken: String
        get() = SettingsManager.hermesGatewayToken

    fun websocketURL(): String? {
        if (apiKey == "YOUR_GEMINI_API_KEY" || apiKey.isEmpty()) return null
        return "$WEBSOCKET_BASE_URL?key=$apiKey"
    }

    val isConfigured: Boolean
        get() = apiKey != "YOUR_GEMINI_API_KEY" && apiKey.isNotEmpty()

    val isHermesConfigured: Boolean
        get() = hermesGatewayToken != "YOUR_OPENCLAW_GATEWAY_TOKEN"
                && hermesGatewayToken.isNotEmpty()
                && hermesHost != "http://YOUR_MAC_HOSTNAME.local"
}
