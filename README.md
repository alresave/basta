# Basta P2P

Base Flutter para un juego Basta / Tutti Frutti sin backend: un teléfono es Host WebSocket en la Wi-Fi y publica su sala con mDNS/DNS-SD (`_basta._tcp`). Los clientes descubren esa sala y se conectan directamente a la IP/puerto local.

Actualmente el modo LAN está implementado. La sección **Ruta a multijugador por Internet** describe el trabajo necesario para que los jugadores puedan invitarse y jugar desde redes distintas.

## Diseño

```text
presentation/            UI y bindings de Flutter
application/             GameController: reglas y máquina de estados
domain/models/            Player, GameState, RoundData (sin dependencias de red)
data/network/             WebSocket local + anuncio/escaneo Zeroconf
data/protocol/            Envoltorio JSON tipado de eventos
```

El Host es la fuente autoritativa de `GameState`; los clientes sólo solicitan acciones. Esto evita divergencias de tiempo, letra y penalizaciones entre pares.

## Protocolo WebSocket JSON

Todos los mensajes tienen esta forma:

```json
{"event":"LETTER_STOPPED","payload":{"letter":"M"}}
```

Eventos de dominio: `LOBBY_STATE`, `START_LETTER_SPIN`, `LETTER_STOPPED`, `TRIGGER_BASTA`, `FREEZE_INPUTS`, `INVALIDATE_CURRENT_CATEGORY`, `CHALLENGE_CHECKING`, `JURY_VOTE_STARTED`, `JURY_VOTE` y `CHALLENGE_RESOLVED`.

Los enums internos usan lowerCamelCase, pero la capa de protocolo los serializa con estos literales exactos en mayúsculas.

Los auxiliares `joinLobby` y `submitAnswers` permiten la entrada y entrega de datos. `TRIGGER_BASTA` inicia un contador local de 10 s y sólo el Host emite `FREEZE_INPUTS` al finalizar, por lo que conserva la autoridad del estado.

## Tribunal de Palabras

El Host consulta primero `assets/dictionary_es.json` (más un vocabulario mínimo en código) y sólo si no encuentra la palabra consulta Free Dictionary con un límite de 3 segundos. Una respuesta confirmada queda marcada en `RoundData.validCategoriesByPlayer` y vale 100 puntos. Si no hay confirmación, el Host abre un jurado sincronizado de 5 segundos; cada cliente puede emitir un único `JURY_VOTE` y el Host resuelve por mayoría simple. Los empates y la ausencia de votos rechazan la palabra.

## Ciclo de vida

La UI registra `GameController` como `WidgetsBindingObserver`. Si la aplicación de un jugador deja `resumed` mientras edita una categoría, emite `INVALIDATE_CURRENT_CATEGORY`; el Host la guarda en `RoundData` para que el puntaje ignore esa casilla.

## Ruta a multijugador por Internet

El descubrimiento mDNS y `SocketService` actual sólo funcionan dentro de la misma red Wi‑Fi. Para partidas móviles remotas se necesita un servicio en Internet; Google Play Games y Game Center pueden ser complementos sociales, pero no sustituyen una red unificada Android+iOS.

### Arquitectura objetivo

```text
App Android / iOS
  └─ enlace o código de sala
       └─ API de salas + autenticación opcional
            ├─ base de datos: sala, jugadores, GameRegistry y reconexiones
            └─ canal en tiempo real: WebSocket / Realtime
                 └─ Host lógico autoritativo o servidor autoritativo
```

Se puede usar Supabase (Postgres + Realtime + Edge Functions) o Firebase como backend. La primera versión debe conservar el `GameController` y los eventos de dominio; sólo cambia el adaptador de transporte local por un `RemoteGameTransport` autenticado.

### Flujo de una partida remota

1. El creador inicia sesión de forma anónima o con una cuenta y crea una sala.
2. El backend genera un código corto y un enlace, por ejemplo `https://basta.app/sala/ABCD12`.
3. El creador comparte el enlace mediante el selector nativo del sistema; el receptor abre la app o la instala y entra en la sala.
4. Cada dispositivo se suscribe al canal de la sala. El backend valida que el jugador pertenece a ella y reenvía los eventos del juego.
5. El Host lógico mantiene la autoridad sobre letra, temporizadores, impugnaciones y puntos. Para mayor resistencia, esa autoridad puede migrarse a una función de servidor.
6. Si un cliente se desconecta, guarda su identidad y último estado confirmado; al volver, se vuelve a suscribir y recibe un `LOBBY_STATE` completo con el `GameRegistry` acumulado.
7. Al terminar, el backend persiste el resumen y permite consultar o compartir el marcador.

### Implementación por etapas

- [ ] Crear el proyecto backend, tablas/colecciones para `rooms`, `room_players` y snapshots de `GameRegistry`.
- [ ] Añadir identidad anónima persistente y control de acceso por miembro de sala.
- [ ] Implementar API para crear, unirse, abandonar y cerrar salas; generar código corto y deep link.
- [ ] Crear `RemoteGameTransport` sobre WebSocket/Supabase Realtime y conservar `SocketService` para modo LAN.
- [ ] Validar en servidor los mensajes críticos (`STOP_LETTER`, votos, puntajes y cambios de fase) y limitar spam/reintentos.
- [ ] Añadir reanudación de sesión y presencia: timeout, reconexión, reenvío del estado completo y abandono definitivo.
- [ ] Probar Android↔iOS por Wi‑Fi, datos móviles y redes NAT restrictivas.
- [ ] Configurar deep links/App Links (Android) y Universal Links (iOS), además de una landing de descarga.

> WebRTC sólo es recomendable si se necesita P2P directo. Requiere señalización y, en la práctica, un servidor TURN para redes que bloquean conexiones entrantes. Un canal WebSocket administrado es más simple y fiable para Basta.

## Ejecutar

```bash
flutter pub get
flutter run
```

En Android se requieren permisos de Internet y red Wi‑Fi local. En iOS, el proyecto debe declarar la descripción de red local y Bonjour para `_basta._tcp` en `Info.plist` mientras exista el modo LAN. El modo remoto requiere HTTPS/WSS, deep links y las políticas de privacidad de la plataforma.
