import 'package:flutter/material.dart';

import 'presentation/game_page.dart';

void main() => runApp(const BastaApp());

class BastaApp extends StatelessWidget {
  const BastaApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: GamePage());
}
