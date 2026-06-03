# OpenVision UI Architecture & Migration Guide

Esta guía detalla la arquitectura de interfaz de usuario de OpenVision, destacando los patrones de diseño, jerarquía de vistas y técnicas de *glassmorphism* utilizadas, para que puedas replicar y migrar esta interfaz a una nueva aplicación desde cero.

## 1. Filosofía de Diseño

El diseño de OpenVision se centra en una experiencia inmersiva e interceptable, utilizando:
- **Glassmorphism**: Uso extensivo de materiales translúcidos (`.ultraThinMaterial`) y fondos semitransparentes (`.opacity(0.1)`).
- **Animaciones fluidas**: Transiciones suaves impulsadas por `.animation(.spring(response: 0.4, dampingFraction: 0.8))`.
- **Fondos dinámicos**: Un `AnimatedBackground` animado y un `ParticleEffect` brindan profundidad sin distraer.
- **Microinteracciones**: Efectos hápticos (`UIImpactFeedbackGenerator`) atados a botones principales.

## 2. Jerarquía Principal (`MainTabView.swift`)

La navegación principal no usa un `TabView` tradicional, sino un menú tipo "cajón 3D" (Drawer Menu).

```swift
ZStack {
    // 1. Vista Principal (Fondo)
    VoiceAgentView(isMenuOpen: $isMenuOpen)
        .scaleEffect(isMenuOpen ? 0.95 : 1.0)
        .blur(radius: isMenuOpen ? 2 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isMenuOpen)
        .onTapGesture { /* Cierra el menú al tocar el fondo */ }
        .disabled(isMenuOpen)

    // 2. Menú Lateral (Superpuesto)
    HamburgerMenuView(isOpen: $isMenuOpen, currentSheet: $currentSheet)
}
// Manejo de modales (History, Settings, Debug) a través de .sheet()
```

**Clave de la UI**: Al abrir el menú, la vista principal (`VoiceAgentView`) se encoge ligeramente y se desenfoca, dando la ilusión de un menú físico deslizándose sobre el contenido.

## 3. Vista Central (`VoiceAgentView.swift`)

La vista principal del agente está estructurada en un `ZStack` (para poner el fondo debajo) y un `VStack` vertical para los elementos interactivos.

```swift
VStack(spacing: 0) {
    topBar          // Barra superior (Menú, estado, toggles)
        .padding()
    
    chatHistory     // ScrollView con los mensajes
    
    textInputBox    // Caja de texto y botón del micrófono
        .padding()
}
.background(
    ZStack {
        AnimatedBackground() // Gradientes moviéndose
        ParticleEffect(particleCount: 30).opacity(0.5) // Partículas flotando
    }
    .ignoresSafeArea()
)
.overlay(errorOverlay) // Para mostrar errores críticos
```

### 3.1 Top Bar
La barra superior tiene elementos encapsulados en "píldoras" (Capsules) glassmórficas.
- **Receta de la píldora**:
```swift
.padding(.horizontal, 16)
.padding(.vertical, 8)
.background(
    Capsule()
        .fill(.ultraThinMaterial)
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
)
```

### 3.2 Chat History
Usa un `ScrollViewReader` junto a un `ScrollView` y un `LazyVStack` para autoscroll hacia abajo cuando llegan mensajes nuevos:
- Renderiza componentes modulares `ChatMessageBubble` y `ActiveTurnBubble`.
- Usa `.id(message.id)` y `.id("bottomSpacer")` para dirigir el foco.

### 3.3 Text Input & Mic Control
La parte inferior contiene la entrada multimodal (texto, foto y voz).
- **El botón del micrófono** cambia dinámicamente de color según el estado (`agentState`), que varía entre: `.idle` (Gris), `.connecting` (Naranja), `.listening` (Azul), `.thinking` (Morado), `.speaking` (Verde).

## 4. Patrones de Estado y Arquitectura

Para la nueva app, te recomiendo seguir este mismo patrón de inyección de dependencias y estado:

- `@StateObject` **Services/Managers**: Los manejadores vitales (Settings, Conexión, Audio) son Singletons inicializados en el entry point de la app (`App.swift`) y pasados al árbol de vistas con `.environmentObject()`.
- **Enums de Estado Visual**: Usa Enums como `AgentState` para controlar los colores y textos de la UI automáticamente y evitar variables booleanas esparcidas.

## 5. Check-list para la Migración
Para migrar el esqueleto visual a la nueva app:
1. Copiar/Recrear `AnimatedBackground.swift` y `ParticleEffect.swift` (o prescindir de ellos si quieres algo más limpio).
2. Crear un layout base de `ZStack` para manejar el efecto *drawer* del menú.
3. Copiar los estilos de `.ultraThinMaterial` y bordes sutiles transparentes (`stroke`) para conseguir el Glassmorphism.
4. Copiar los componentes `ChatMessageBubble` y `ActiveTurnBubble` asumiendo que el modelo de datos cambiará.

*Esta guía está diseñada para que puedas estructurar visualmente cualquier aplicación SwiftUI usando los mismos principios que hicieron destacar a OpenVision.*
