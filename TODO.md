# Bitácora y pendientes — Basta P2P

Fecha: 2026-08-26

## Hecho hoy

### Parte 1 de 3 — Base P2P local

- [x] Inicializada la arquitectura Flutter modular (`domain`, `data`, `application`, `presentation`).
- [x] Añadidos los modelos `Player`, `GameState`, `GameConfig` y `RoundData`.
- [x] Implementado anuncio y descubrimiento de salas por mDNS/DNS-SD (`_basta._tcp`).
- [x] Implementado Host WebSocket local, cliente y protocolo JSON tipado.
- [x] Definida la máquina de estados de lobby, giro, respuesta, cuenta Basta y congelamiento.
- [x] Añadida invalidación de categoría al enviar la app a segundo plano.
- [x] Commit: `cec7da1 feat: initialize local P2P Basta architecture`.

### Parte 2 de 3 — Pantalla de juego del cliente

- [x] Creada `GameScreen` con tarjetas de categorías y estados Pendiente / En progreso / Completada.
- [x] Añadido modal de captura rápida y control de teclado/categoría activa.
- [x] Añadido botón `¡BASTA!`, habilitado sólo al completar todas las categorías.
- [x] Añadido banner no intrusivo de cuenta regresiva, háptico y bloqueo final de inputs.
- [x] Permitido que cualquier cliente solicite Basta, manteniendo al Host como autoridad.
- [x] Corregida la sincronización de `RoundData` para clientes antes de recibir la letra.
- [x] Commit: `61a24a7 feat: add interactive client game screen`.

### Parte 3 de 3 — Fase de revisión animada

- [x] Creada `ShowcaseScreen` con carrusel por categoría y revelado flip/fade simultáneo.
- [x] Implementada normalización de texto y detección de coincidencias mediante Levenshtein.
- [x] Agrupadas coincidencias por todos los jugadores involucrados.
- [x] Reglas de puntos por coincidencia: 2 jugadores = 50, 3 = 30, 4 = 25, 5 o más = 20 puntos por jugador.
- [x] Añadido resaltado amarillo y etiquetas de coincidencia.
- [x] Añadido evento WebSocket `CHALLENGE_WORD` y acción de impugnación por palabra.
- [x] Añadidas pruebas unitarias del comparador de palabras y puntuación.
- [x] Commit: `9ae1919 feat: add animated round review showcase`.

### Parte 4 — Tribunal de Palabras

- [x] Implementado `WordValidationService` offline-first con diccionario JSON embebido y consulta remota de respaldo.
- [x] Añadido `ChallengeModal` sincronizado: veredicto con definición o votación de jurado de 5 segundos.
- [x] Añadidos eventos WebSocket de comprobación, voto, inicio de jurado y resolución.
- [x] Registrada la validez de casillas confirmadas por el Tribunal (100 pts).
- [x] Commit: `effd43d feat: add word challenge tribunal`.

### Parte 5 — Puntuación y final de partida

- [x] Implementado `ScoreCalculatorService`: 100 pts única, 50 pts repetida, 0 pts inválida/vacía/cancelada y +20 por defensa exitosa.
- [x] Creado `GameRegistry` con historial de rondas, acumulados y letras ya jugadas; persistencia local con `shared_preferences`.
- [x] Implementada rotación del jugador que detiene el abecedario y prevención de letras repetidas.
- [x] Creada `LeaderboardScreen` con posiciones y premios Enciclopedia, Abogado y Poeta.
- [x] Commit: `f22700c feat: add scoring and final leaderboard`.

### Parte 6 — UX, Android y distribución

- [x] Añadido `FeedbackService` para sonidos del sistema y hápticos de giro, inicio, cuenta regresiva, Basta, juicio y victoria.
- [x] Añadido banner global de desconexión y reconexión rápida al Host sin perder el registro de puntos.
- [x] Generada la plataforma Android, permisos de red local y APK release verificable.
- [x] Actualizado `bonsoir` a 7.1.5 y migrado el descubrimiento mDNS a su API actual.
- [x] Generados recursos visuales para launcher/adaptive icon Android.
- [x] Añadida landing de descarga y workflow de GitHub Pages que compila y publica el APK.
- [x] Commit: `2dbfef8 feat: add Android release and download page`.

## Pendiente

- [x] Añadir flujo visual de lobby: buscar salas, unirse, configurar categorías y comenzar partida.
- [x] Completar reconexión del Host y validación/autorización de mensajes de red (la alerta y reconexión de clientes ya están implementadas).
- [ ] Configurar permisos de red local/Bonjour para iOS y realizar pruebas físicas de descubrimiento Android/iOS.
- [ ] Añadir pruebas de integración para el flujo Host–Cliente y transición de rondas.
- [ ] Configurar keystore de release, `applicationId` definitivo e íconos nativos antes de distribuir por Play Store.
- [ ] Habilitar GitHub Pages con fuente **GitHub Actions** y confirmar la primera publicación del workflow.
