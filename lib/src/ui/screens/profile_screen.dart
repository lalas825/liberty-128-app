import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/civic_info_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State Variables
  final TextEditingController _nameController = TextEditingController();
  DateTime? _examDate;
  double _voiceSpeed = 1.0;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _isLoading = true;
  
  // Image State
  String? _profileImagePath;
  final ImagePicker _picker = ImagePicker();

  // Civic Info State
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _governorController = TextEditingController();
  final TextEditingController _senator1Controller = TextEditingController();
  final TextEditingController _senator2Controller = TextEditingController();
  final TextEditingController _repController = TextEditingController();
  bool _isSearchingCivic = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // Load Data from SharedPreferences
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? "";
      
      final dateStr = prefs.getString('exam_date');
      if (dateStr != null) {
        _examDate = DateTime.tryParse(dateStr);
      }

      _voiceSpeed = prefs.getDouble('voice_speed') ?? 1.0;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _profileImagePath = prefs.getString('profile_image_path');
      

      
      _zipController.text = prefs.getString('civic_zip') ?? "";
      _governorController.text = prefs.getString('civic_governor') ?? "";
      _senator1Controller.text = prefs.getString('civic_senator1') ?? "";
      _senator2Controller.text = prefs.getString('civic_senator2') ?? "";
      _repController.text = prefs.getString('civic_rep') ?? "";

      _isLoading = false;
    });
  }

  // Save Data Helpers
  Future<void> _saveName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', value);
    setState(() {}); // Trigger rebuild to update Avatar if relying on initials
  }

  Future<void> _saveExamDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exam_date', date.toIso8601String());
    setState(() {
      _examDate = date;
    });
  }

  Future<void> _saveVoiceSpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_speed', value);
    setState(() {
      _voiceSpeed = value;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', value);
    setState(() {
      _darkModeEnabled = value;
    });
    // Note: Theme change requires top-level callback in real app
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Theme preference saved (Refresh needed)")));
  }
  
  // Image Picker Logic
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', image.path);
        setState(() {
          _profileImagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to pick image")),
      );
    }
    }


  // Civic Info Logic
  Future<void> _fetchCivicInfo() async {
    final zip = _zipController.text.trim();
    if (zip.isEmpty || zip.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 5-digit Zip Code"))
      );
      return;
    }

    setState(() => _isSearchingCivic = true);

    try {
      final data = await CivicInfoService.fetchRepresentatives(zip);
      
      final governor = data['governor'] ?? "Not Found";
      final senators = data['senators'] as List<dynamic>? ?? [];
      final rep = data['representative'] ?? "Not Found";

      setState(() {
        _governorController.text = governor;
        _senator1Controller.text = senators.isNotEmpty ? senators[0] : "Not Found";
        _senator2Controller.text = senators.length > 1 ? senators[1] : "Not Found";
        _repController.text = rep;
      });

      // Save to Prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('civic_zip', zip);
      await prefs.setString('civic_governor', _governorController.text);
      await prefs.setString('civic_senator1', _senator1Controller.text);
      await prefs.setString('civic_senator2', _senator2Controller.text);
      await prefs.setString('civic_rep', _repController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Officials Updated!"), backgroundColor: Colors.green)
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingCivic = false);
    }
  }

  // Reset Logic
  Future<void> _resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    // CLEAR EVERYTHING
    await prefs.clear();
    
    if (mounted) {
      // Navigate to Onboarding and remove back stack
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
    }
  }

  // Logic: Calculate Days Until Exam
  String _getDaysUntilExam() {
    if (_examDate == null) return "Set Exam Date";
    final now = DateTime.now();
    // Reset time to midnight for accurate day comparison
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(_examDate!.year, _examDate!.month, _examDate!.day);
    final difference = exam.difference(today).inDays;

    if (difference < 0) return "Included Exam Date"; // Or "Exam Passed"
    return "$difference Days Until Interview";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Colors
    final Color federalBlue = const Color(0xFF112D50);
    final Color sectionTitleColor = Colors.grey.shade700;
    
    // Avatar Image Provider
    ImageProvider? avatarImage;
    if (_profileImagePath != null) {
      final file = File(_profileImagePath!);
      if (file.existsSync()) {
        avatarImage = FileImage(file);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Study Command Center", 
          style: GoogleFonts.publicSans(color: federalBlue, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // --- HEADER SECTION ---
             Center(
               child: Column(
                 children: [
                   GestureDetector(
                     onTap: _pickImage,
                     child: Stack(
                       children: [
                         CircleAvatar(
                           radius: 50,
                           backgroundColor: federalBlue.withOpacity(0.1),
                           backgroundImage: avatarImage,
                           child: avatarImage == null
                               ? Text(
                                   _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : "U",
                                   style: GoogleFonts.publicSans(fontSize: 40, color: federalBlue, fontWeight: FontWeight.bold),
                                 )
                               : null, // Show nothing if image is there
                         ),
                         // Camera Icon Overlay
                         Positioned(
                           bottom: 0,
                           right: 0,
                           child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: const BoxDecoration(
                               color: Colors.white,
                               shape: BoxShape.circle,
                               boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                             ),
                             child: Icon(Icons.camera_alt, color: federalBlue, size: 20),
                           ),
                         )
                       ],
                     ),
                   ),
                   const SizedBox(height: 16),
                   // Editable Name
                   TextField(
                     controller: _nameController,
                     textAlign: TextAlign.center,
                     style: GoogleFonts.publicSans(fontSize: 22, fontWeight: FontWeight.bold, color: federalBlue),
                     decoration: const InputDecoration(
                       hintText: "Enter Your Name",
                       border: InputBorder.none,
                       hintStyle: TextStyle(color: Colors.grey)
                     ),
                     onChanged: _saveName, 
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 32),
             
             // --- MY LOCAL GOVERNMENT ---
             Text("MY LOCAL GOVERNMENT", style: GoogleFonts.publicSans(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
             const SizedBox(height: 8),
             Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Zip Search Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _zipController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Zip Code",
                                hintText: "Enter Zip",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: federalBlue,
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: IconButton(
                              icon: _isSearchingCivic 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.search, color: Colors.white),
                              onPressed: _isSearchingCivic ? null : _fetchCivicInfo,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Fields
                      _buildCivicField("My Governor", _governorController),
                      const SizedBox(height: 12),
                      _buildCivicField("My Senator 1", _senator1Controller),
                      const SizedBox(height: 12),
                      _buildCivicField("My Senator 2", _senator2Controller),
                      const SizedBox(height: 12),
                      _buildCivicField("My Representative", _repController),
                    ],
                  ),
                ),
             ),
             const SizedBox(height: 32),

             // --- EXAM DETAILS ---
             Text("EXAM DETAILS", style: GoogleFonts.publicSans(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
             const SizedBox(height: 8),
             Card(
               elevation: 0,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
               child: ListTile(
                 leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                 title: Text(_examDate == null ? "Set Exam Date" : DateFormat.yMMMMd().format(_examDate!), 
                   style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)
                 ),
                 subtitle: const Text("Tap to select your interview date"),
                 trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                 onTap: () async {
                   final DateTime? picked = await showDatePicker(
                     context: context,
                     initialDate: _examDate ?? DateTime.now().add(const Duration(days: 30)),
                     firstDate: DateTime.now(),
                     lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                   );
                   if (picked != null) {
                     _saveExamDate(picked);
                   }
                 },
               ),
             ),
             const SizedBox(height: 32),

             // --- SETTINGS ---
             Text("SETTINGS", style: GoogleFonts.publicSans(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
             const SizedBox(height: 8),
             Card(
               elevation: 0,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
               child: Column(
                 children: [
                   // Voice Speed
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                               Text("Interviewer Voice Speed", style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
                               Text("${_voiceSpeed.toStringAsFixed(1)}x", style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: federalBlue)),
                           ],
                         ),
                         Slider(
                           value: _voiceSpeed,
                           min: 0.5,
                           max: 1.5,
                           divisions: 10,
                           activeColor: federalBlue,
                           onChanged: _saveVoiceSpeed,
                         ),
                       ],
                     ),
                   ),
                   const Divider(height: 1),
                   
                   // Notifications
                   SwitchListTile(
                     title: Text("Daily Reminders", style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
                     subtitle: const Text("Get study reminders at 9:00 AM"),
                     value: _notificationsEnabled,
                     activeColor: const Color(0xFF00C4B4),
                     onChanged: _toggleNotifications,
                   ),
                    const Divider(height: 1),

                   // Dark Mode
                   SwitchListTile(
                     title: Text("Dark Mode", style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
                     value: _darkModeEnabled,
                     activeColor: const Color(0xFF00C4B4),
                     onChanged: _toggleDarkMode,
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 32),

             // --- DANGER ZONE ---
             Text("DANGER ZONE", style: GoogleFonts.publicSans(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
             const SizedBox(height: 8),
             SizedBox(
               width: double.infinity,
               child: OutlinedButton(
                 onPressed: () {
                   showDialog(
                     context: context, 
                     builder: (context) => AlertDialog(
                       title: const Text("Reset All Progress?"),
                       content: const Text("This will delete ALL data (name, date, photos, scores) and restart the app."),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                         TextButton(
                           onPressed: () {
                             Navigator.pop(context); // Close dialog
                             _resetProgress();
                           }, 
                           child: const Text("Reset Everything", style: TextStyle(color: Colors.red))
                          ),
                       ],
                     )
                   );
                 },
                 style: OutlinedButton.styleFrom(
                   foregroundColor: Colors.red,
                   side: const BorderSide(color: Colors.red),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                 ),
                 child: Text("Reset All Progress", style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
               ),
             ),
             const SizedBox(height: 40),
           ],
        ),
      ),
    );
  }

  Widget _buildCivicField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: const Color(0xFF112D50)),
    );
  }
}
