import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  String _studyVersion = '2020'; // Default to 2020 (128 Qs)
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  String get studyVersion => _studyVersion;
  bool get isLoading => _isLoading;
  String? get userName => _userData?['name'];

  String? get photoUrl => _userData?['photo_url'];
  String? get zipCode => _userData?['zip_code'];
  
  DateTime? get examDate {
    final ts = _userData?['interview_date'];
    return (ts is Timestamp) ? ts.toDate() : null;
  }
  
  DateTime? get submissionDate {
    final ts = _userData?['submission_date'];
    return (ts is Timestamp) ? ts.toDate() : null;
  }

  DateTime? get birthday {
    final ts = _userData?['birthday'];
    return (ts is Timestamp) ? ts.toDate() : null;
  }

  UserProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadPrefs();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await fetchUserData(user.uid);
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        _userData = doc.data();
        debugPrint("UserProvider Fetched Data: $_userData"); // Debug Log
        _studyVersion = _userData?['version'] ?? '2020';
      } else {
        debugPrint("UserProvider: No document found for $uid");
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? get civicGovernor => _userData?['civic_governor'] ?? _prefs?.getString('civic_governor');
  String? get civicSenator1 => _userData?['civic_senator1'] ?? _prefs?.getString('civic_senator1');
  String? get civicSenator2 => _userData?['civic_senator2'] ?? _prefs?.getString('civic_senator2');
  String? get civicRepresentative => _userData?['civic_representative'] ?? _prefs?.getString('civic_rep'); // Profile saves as civic_rep
  String? get civicCapital => _userData?['civic_capital'] ?? _prefs?.getString('civic_capital'); // Assume this might be saved later, or we default

  SharedPreferences? _prefs;

  Future<void> updateVersion(String newVersion) async {
    if (_prefs == null) await _loadPrefs();
    await _prefs!.setString('study_version', newVersion); // General string
    await _prefs!.setBool('is_2025_version', newVersion == '2025'); // Boolean for legacy screens
    
    _studyVersion = newVersion;
    notifyListeners();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'version': newVersion}, SetOptions(merge: true)
      );
    }
  }
  
  // Method to refresh data manually (e.g. after edit)
  Future<void> refresh() async {
     final user = FirebaseAuth.instance.currentUser;
     if (user != null) {
       await fetchUserData(user.uid);
     }
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }
}
