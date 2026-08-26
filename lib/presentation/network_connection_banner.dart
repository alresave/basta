import 'package:flutter/material.dart';

import '../application/game_controller.dart';

class NetworkConnectionBanner extends StatelessWidget {
  const NetworkConnectionBanner({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final alert = controller.networkAlert;
    if (alert == null) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10)
              ],
            ),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(alert, style: const TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: controller.reconnect,
                child: const Text('RECONECTAR',
                    style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
