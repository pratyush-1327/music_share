import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/share_handler/presentation/screens/home_screen.dart';
import 'features/share_handler/presentation/screens/processing_screen.dart';
import 'features/share_handler/presentation/screens/result_screen.dart';
import 'features/share_handler/services/share_intent_service.dart';

void main() {
  runApp(const PulseShareApp());
}

class PulseShareApp extends StatelessWidget {
  const PulseShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ShareIntentService(),
        ),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            navigatorKey: context.read<ShareIntentService>().navigatorKey,
            title: 'PulseShare',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            initialRoute: '/',
            routes: {
              '/': (_) => const HomeScreen(),
              '/processing': (_) => const ProcessingScreen(),
              '/result': (_) => const ResultScreen(),
            },
          );
        },
      ),
    );
  }
}