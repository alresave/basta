# Basta Local

Base Flutter para un juego Basta / Tutti Frutti sin backend: un teléfono es Host WebSocket en la Wi-Fi y publica su sala con mDNS/DNS-SD (`_basta._tcp`). Los clientes descubren esa sala y se conectan directamente a la IP/puerto local.

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

## Ejecutar

```bash
flutter pub get
flutter run
```

En Android se requiere el permiso `INTERNET` (normalmente presente en debug) y en iOS el proyecto debe declarar la descripción de red local y Bonjour para `_basta._tcp` en `Info.plist` antes de distribuir.
