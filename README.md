# Basta P2P

Juego Flutter de Basta / Tutti Frutti con dos modos: LAN P2P mediante WebSocket y mDNS/DNS-SD (`_basta._tcp`), y salas remotas mediante Supabase Realtime. En ambos, el Host lógico conserva la autoridad sobre letras, temporizadores, impugnaciones y puntos.

## Diseño

```text
presentation/            UI y bindings de Flutter
application/             GameController: reglas y máquina de estados
domain/models/            Player, GameState, RoundData (sin dependencias de red)
data/network/             WebSocket local + anuncio/escaneo Zeroconf
data/remote/              Salas Supabase y transporte Realtime privado
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

## Configuración de partida

Las categorías iniciales son **Nombre**, **Flor o fruto**, **Animal**, **Ciudad o país** y **Cosa**. En el lobby, el Host puede añadir o eliminar categorías antes de iniciar. La letra vigente se muestra de forma destacada en la pantalla de ronda.

## Multijugador por Internet (Supabase)

El modo LAN sigue disponible sin backend. Para jugar desde redes distintas se implementó un adaptador de salas remotas sobre Supabase: inicio de sesión anónimo, creación/unión por código corto, tablas `rooms`, `room_players` y `room_events`, y broadcast privado de Realtime con políticas RLS.

### Preparación local

1. Aplica las migraciones en `supabase/migrations/` al proyecto Supabase enlazado.
2. Activa **Anonymous Sign-Ins** en Supabase Authentication.
3. Copia `.env.example` a `.env` y completa `SUPABASE_URL` y `SUPABASE_ANON_KEY` localmente. Nunca versionar `.env`.
4. Ejecuta el modo remoto con:

```bash
sh tool/run_remote.sh
```

El script pasa las credenciales mediante `--dart-define`; no se guardan dentro de la app ni en el repositorio.

### Flujo de una partida remota

1. El creador inicia sesión anónima y crea una sala; recibe un código corto.
2. Cada invitado introduce ese código y se une a la sala.
3. Los miembros se suscriben al canal Realtime privado de la sala.
4. El Host recibe las acciones, actualiza el estado autoritativo y emite el estado sincronizado a los jugadores.

### Pendiente de la versión remota

- [ ] Realizar una prueba completa en dos dispositivos y redes distintas: crear/unirse, rondas, jurado, puntos y marcador final.
- [ ] Añadir compartir código/enlace y deep links: Android App Links e iOS Universal Links.
- [ ] Implementar presencia, reconexión remota y abandono de salas con reenvío del último estado completo.
- [ ] Mover validaciones críticas y límites anti-spam al servidor/Edge Functions.
- [ ] Persistir el resumen final de la partida en Supabase y permitir compartirlo.
- [ ] Probar Android↔iOS por Wi‑Fi, datos móviles y redes NAT restrictivas.

> WebRTC sólo es recomendable si se necesita P2P directo. Requiere señalización y, en la práctica, un servidor TURN para redes que bloquean conexiones entrantes. Un canal WebSocket administrado es más simple y fiable para Basta.

## Ejecutar

```bash
flutter pub get
flutter run
```

En Android se requieren permisos de Internet y red Wi‑Fi local. En iOS, el proyecto debe declarar la descripción de red local y Bonjour para `_basta._tcp` en `Info.plist` mientras exista el modo LAN. El modo remoto requiere HTTPS/WSS, deep links y las políticas de privacidad de la plataforma.

## Android: firma y distribución

El release local se firma con un keystore local referenciado por `android/key.properties`; ambos están ignorados por Git. Usa `android/key.properties.example` como plantilla y conserva el keystore y sus contraseñas en un gestor de secretos.

El workflow de GitHub Pages (`.github/workflows/pages.yml`) genera el APK firmado desde estos secretos de GitHub Actions:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

El keystore se recrea sólo durante la ejecución de CI y se publica el APK resultante en la página de descarga. El identificador configurado actualmente es `com.alresave.basta`; antes de publicar en Play Store hay que confirmar su disponibilidad y titularidad, configurar los secretos de CI, versionar los releases, completar la ficha de Play y hacer pruebas en dispositivos reales.
