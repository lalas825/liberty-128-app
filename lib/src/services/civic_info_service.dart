import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/officials_data.dart';

class CivicInfoService {
  /// Fetches officials for the given [zipCode] using a Hybrid approach:
  /// 1. Zippopotam.us to get State.
  /// 2. Static Data for Governor and Senators.
  /// 3. Scrapes house.gov for Representative.
  static Future<Map<String, dynamic>> fetchRepresentatives(String zipCode) async {
    try {
      // 1. Get State from Zip
      final stateAbbr = await _fetchStateFromZip(zipCode);
      
      // 2. Lookup Static Data
      final governor = OfficialsData.governors[stateAbbr] ?? "Not Found";
      final senators = OfficialsData.senators[stateAbbr] ?? ["Not Found", "Not Found"];
      
      // 3. Scrape Rep
      final representative = await _scrapeRepresentative(zipCode);

      return {
        'governor': governor,
        'senators': senators,
        'representative': representative,
      };

    } catch (e) {
      throw Exception('Error fetching civic info: $e');
    }
  }

  static Future<String> _fetchStateFromZip(String zip) async {
    final url = Uri.parse('https://api.zippopotam.us/us/$zip');
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final places = data['places'] as List<dynamic>;
      if (places.isNotEmpty) {
        return places.first['state abbreviation'] as String;
      }
    }
    throw Exception("Invalid Zip Code");
  }

  static Future<String> _scrapeRepresentative(String zip) async {
    try {
      final url = Uri.parse('https://ziplook.house.gov/htbin/findrep_house?ZIP=$zip');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = response.body;
        // Regex to find link with name: [First Last](http...)
        // The page typically renders:
        // The representative for this district is:
        // <a href="...">NAME</a>
        
        // Simple regex for the Name pattern inside the specific link structure often used
        // Or look for Title "Rep." or similar? No, the page is weird.
        // Let's look for the first link that contains ".house.gov" and capture the text inside.
        
        // Pattern: <a href="https://LASTNAME.house.gov">First Last</a>
        // Or Markdown style from my tool output: [James A. Himes](https://himes.house.gov/)
        // But http.get returns raw HTML.
        
        // Raw HTML might look like: <a href="https://himes.house.gov">James A. Himes</a>
        
        final regExp = RegExp(r'<a href="https?:\/\/[a-zA-Z0-9-]+\.house\.gov(?:\/contact-me)?">([^<]+)<\/a>');
        final match = regExp.firstMatch(body);
        
        if (match != null) {
          return match.group(1)?.trim() ?? "Not Found";
        }
        
        // Fallback: Try finding common " Representative" text?
        if (body.contains("The representative for this district is:")) {
             // It might be complex. Return a safe fallback.
             return "Check house.gov (Parsing Failed)";
        }
      }
      return "Not Found";
    } catch (e) {
      return "Connection Error";
    }
  }
}
