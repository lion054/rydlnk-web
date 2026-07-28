import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/onboarding_screen.dart';
import 'screens/root_router.dart';
import 'state/app_session.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await AppSession.init();

  // Restore a prior session so returning users skip onboarding.
  final signedIn = AppSession.isSignedIn;
  if (signedIn) {
    await AppSession.loadProfile();
  }

  runApp(RydlnkApp(signedIn: signedIn));
}

class RydlnkApp extends StatelessWidget {
  const RydlnkApp({super.key, this.signedIn = false});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rydlnk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: signedIn ? rootForRole() : const OnboardingScreen(),
    );
  }
}
