import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/logic/viewmodels/onboarding_viewmodel.dart';
import 'src/ui/screens/onboarding_screen.dart';
import 'src/ui/screens/home_screen.dart';
import 'src/ui/screens/voice_practice_screen.dart';
// Note: QuizScreen might be imported in HomeScreen directly or used via named route if we register it.
// Just ensuring we have the necessary screens for the requested named routes.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(); // COMMENTED OUT FOR NOW
  
  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  runApp(MyApp(initialRoute: hasSeenOnboarding ? '/home' : '/onboarding'));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingViewModel()),
      ],
      child: MaterialApp(
        title: 'Liberty 128',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF112D50),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          textTheme: GoogleFonts.publicSansTextTheme(),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: const Color(0xFF112D50),
            secondary: const Color(0xFF00C4B4),
          ),
        ),
        initialRoute: initialRoute,
        routes: {
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const HomeScreen(),
          '/voice': (context) => const VoicePracticeScreen(),
        },
      ),
    );
  }
}
