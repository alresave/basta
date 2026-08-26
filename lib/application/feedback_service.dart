import 'dart:async';

import 'package:flutter/services.dart';

/// Retroalimentación nativa reutilizable. Los sonidos del sistema permiten
/// funcionar sin descargar paquetes ni assets y respetan el modo silencioso.
class FeedbackService {
  const FeedbackService();

  Future<void> wheelStarted() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> wheelStopped() => SystemSound.play(SystemSoundType.click);

  Future<void> roundBell() => SystemSound.play(SystemSoundType.alert);

  Future<void> countdownTick() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.selectionClick();
  }

  Future<void> judgeGavel() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.mediumImpact();
  }

  Future<void> victoryFanfare() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
  }

  Future<void> bastaPressed() => HapticFeedback.heavyImpact();

  Future<void> verdict({required bool valid}) async {
    await (valid ? HapticFeedback.mediumImpact() : HapticFeedback.vibrate());
  }
}
