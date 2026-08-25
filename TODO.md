# Bitácora y pendientes — Basta P2P

Fecha: 2026-08-25

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

> Anotación de continuidad: hasta este punto está completada la **tercera parte** del desarrollo solicitado. La siguiente iteración debe partir de `ShowcaseScreen` y del evento `CHALLENGE_WORD` para implementar la resolución autoritativa de impugnaciones y el cálculo final de puntajes.

## Pendiente

- [ ] Implementar resolución y persistencia en `GameState` de las impugnaciones recibidas por el Host.
- [ ] Implementar cálculo final de puntos y tabla de resultados por ronda/partida.
- [ ] Añadir flujo visual de lobby: buscar salas, unirse, configurar categorías y comenzar partida.
- [ ] Añadir reconexión, manejo de desconexiones y validación de mensajes de red.
- [ ] Configurar permisos de red local/Bonjour de Android e iOS en los proyectos de plataforma generados.
- [ ] Añadir pruebas de integración para el flujo Host–Cliente y transición de rondas.
