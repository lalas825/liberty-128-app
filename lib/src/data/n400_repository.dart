import 'dart:convert';
import 'package:flutter/services.dart';

class N400Repository {
  // Load the JSON data from assets
  Future<Map<String, dynamic>> loadVocabularyData() async {
    try {
      // 1. Load the string from the file
      final String response = await rootBundle.loadString('assets/n400_data.json');
      
      // 2. Decode the string into a Map (JSON Object)
      final data = await json.decode(response);
      
      return data;
    } catch (e) {
      print("Error loading N400 data: $e");
      return {}; // Return empty map on error
    }
  }
}