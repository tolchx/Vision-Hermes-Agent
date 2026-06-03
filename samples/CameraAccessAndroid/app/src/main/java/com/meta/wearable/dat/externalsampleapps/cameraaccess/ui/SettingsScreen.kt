package com.meta.wearable.dat.externalsampleapps.cameraaccess.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var geminiAPIKey by remember { mutableStateOf(SettingsManager.geminiAPIKey) }
    var systemPrompt by remember { mutableStateOf(SettingsManager.geminiSystemPrompt) }
    var hermesHost by remember { mutableStateOf(SettingsManager.hermesHost) }
    var hermesPort by remember { mutableStateOf(SettingsManager.hermesPort.toString()) }
    var hermesHookToken by remember { mutableStateOf(SettingsManager.hermesHookToken) }
    var hermesGatewayToken by remember { mutableStateOf(SettingsManager.hermesGatewayToken) }
    var webrtcSignalingURL by remember { mutableStateOf(SettingsManager.webrtcSignalingURL) }
    var showResetDialog by remember { mutableStateOf(false) }

    fun save() {
        SettingsManager.geminiAPIKey = geminiAPIKey.trim()
        SettingsManager.geminiSystemPrompt = systemPrompt.trim()
        SettingsManager.hermesHost = hermesHost.trim()
        hermesPort.trim().toIntOrNull()?.let { SettingsManager.hermesPort = it }
        SettingsManager.hermesHookToken = hermesHookToken.trim()
        SettingsManager.hermesGatewayToken = hermesGatewayToken.trim()
        SettingsManager.webrtcSignalingURL = webrtcSignalingURL.trim()
    }

    fun reload() {
        geminiAPIKey = SettingsManager.geminiAPIKey
        systemPrompt = SettingsManager.geminiSystemPrompt
        hermesHost = SettingsManager.hermesHost
        hermesPort = SettingsManager.hermesPort.toString()
        hermesHookToken = SettingsManager.hermesHookToken
        hermesGatewayToken = SettingsManager.hermesGatewayToken
        webrtcSignalingURL = SettingsManager.webrtcSignalingURL
    }

    Column(modifier = modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Settings") },
            navigationIcon = {
                IconButton(onClick = {
                    save()
                    onBack()
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                }
            },
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Gemini section
            SectionHeader("Gemini API")
            MonoTextField(
                value = geminiAPIKey,
                onValueChange = { geminiAPIKey = it },
                label = "API Key",
                placeholder = "Enter Gemini API key",
            )

            SectionHeader("System Prompt")
            OutlinedTextField(
                value = systemPrompt,
                onValueChange = { systemPrompt = it },
                label = { Text("System prompt") },
                modifier = Modifier.fillMaxWidth().height(200.dp),
                textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
            )

            // Hermes section
            SectionHeader("Hermes")
            MonoTextField(
                value = hermesHost,
                onValueChange = { hermesHost = it },
                label = "Host",
                placeholder = "http://your-mac.local",
                keyboardType = KeyboardType.Uri,
            )
            MonoTextField(
                value = hermesPort,
                onValueChange = { hermesPort = it },
                label = "Port",
                placeholder = "18789",
                keyboardType = KeyboardType.Number,
            )
            MonoTextField(
                value = hermesHookToken,
                onValueChange = { hermesHookToken = it },
                label = "Hook Token",
                placeholder = "Hook token",
            )
            MonoTextField(
                value = hermesGatewayToken,
                onValueChange = { hermesGatewayToken = it },
                label = "Gateway Token",
                placeholder = "Gateway auth token",
            )

            // WebRTC section
            SectionHeader("WebRTC")
            MonoTextField(
                value = webrtcSignalingURL,
                onValueChange = { webrtcSignalingURL = it },
                label = "Signaling URL",
                placeholder = "wss://your-server.example.com",
                keyboardType = KeyboardType.Uri,
            )

            // Reset
            TextButton(onClick = { showResetDialog = true }) {
                Text("Reset to Defaults", color = Color.Red)
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text("Reset Settings") },
            text = { Text("This will reset all settings to the values built into the app.") },
            confirmButton = {
                TextButton(onClick = {
                    SettingsManager.resetAll()
                    reload()
                    showResetDialog = false
                }) {
                    Text("Reset", color = Color.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
private fun MonoTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        placeholder = { Text(placeholder) },
        modifier = Modifier.fillMaxWidth(),
        textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
    )
}
