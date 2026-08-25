import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

/// Anuncia y encuentra salas usando DNS-SD/mDNS. No hay ningún servicio cloud.
class LocalRoom {
  const LocalRoom({required this.id, required this.host, required this.port});
  final String id;
  final String host;
  final int port;
}

class LocalDiscoveryService {
  static const _serviceType = '_basta._tcp';
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;

  Future<void> advertise({required String roomId, required int port}) async {
    _broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: 'Basta-$roomId',
        type: _serviceType,
        port: port,
        attributes: {'roomId': roomId, 'protocol': '1'},
      ),
    );
    await _broadcast!.ready;
    await _broadcast!.start();
  }

  Future<void> discover(void Function(LocalRoom room) onRoom) async {
    _discovery = BonsoirDiscovery(type: _serviceType);
    await _discovery!.ready;
    _subscription = _discovery!.eventStream!.listen((event) async {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound &&
          event.service != null) {
        await event.service!.resolve(_discovery!.serviceResolver);
      }
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved &&
          event.service is ResolvedBonsoirService) {
        final service = event.service! as ResolvedBonsoirService;
        final roomId = service.attributes['roomId'];
        final host = service.host;
        if (roomId != null && host != null) {
          onRoom(LocalRoom(id: roomId, host: host, port: service.port));
        }
      }
    });
    await _discovery!.start();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _discovery?.stop();
    await _broadcast?.stop();
  }
}
