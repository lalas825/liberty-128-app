import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

import 'src/ui/screens/profile_setup_screen.dart';
import 'src/ui/screens/login_screen.dart';
import 'src/logic/viewmodels/onboarding_viewmodel.dart';
import 'src/ui/screens/onboarding_screen.dart';
import 'src/ui/screens/home_screen.dart';
import 'src/ui/screens/voice_practice_screen.dart';
// Note: QuizScreen might be imported in HomeScreen directly or used via named route if we register it.
// Just ensuring we have the necessary screens for the requested named routes.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = true; // Forced for testing

  String initialRoute = '/onboarding';

  if (hasSeenOnboarding) {
    initialRoute = '/login';
    
    // Check Auth State
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check Profile State
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['isProfileComplete'] == true) {
          initialRoute = '/home';
        } else {
          initialRoute = '/profile_setup';
        }
      } catch (e) {
        // Fallback to login on error
        initialRoute = '/login';
      }
    }
  }

  runApp(MyApp(initialRoute: initialRoute));
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
        title: 'Citizen 128',
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
          '/login': (context) => const LoginScreen(),
          '/profile_setup': (context) => const ProfileSetupScreen(),
          '/home': (context) => const HomeScreen(),
          '/voice': (context) => const VoicePracticeScreen(),
        },
      ),
    );
  }
}
