import 'package:flutter/material.dart';
import 'presentation/routes/app_router.dart';

void main() {
  runApp(const ProcessManagerApp());
}

class ProcessManagerApp extends StatelessWidget {
  const ProcessManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NR Container',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
