import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/user_provider.dart';
import 'dart:typed_data';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers & State
  final _nameController = TextEditingController();
  final _zipController = TextEditingController();
  
  DateTime? _birthday;
  DateTime? _subDate;
  DateTime? _interviewDate;
  String _studyVersion = '2020'; // Default 2020
  
  Uint8List? _imageBytes; // Platform-agnostic image handling
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  String? _uploadStatus; // To show progress "Uploading image..."

  // --- Pickers ---

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Image Picker Error: $e");
    }
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    DateTime initial = DateTime.now();
    DateTime first = DateTime(1900);
    DateTime last = DateTime(2100);

    if (type == 'birthday') {
      initial = DateTime.now().subtract(const Duration(days: 365 * 30));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF112D50),
              onPrimary: Colors.white,
              onSurface: Color(0xFF112D50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (type == 'birthday') _birthday = picked;
        if (type == 'sub') _subDate = picked;
        if (type == 'interview') _interviewDate = picked;
      });
    }
  }

  // --- Save Logic ---

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate Dates (Basic)
    if (_birthday == null) {
      _showSnack("Please enter your Date of Birth");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user found");

      String? photoUrl;

      // 1. Upload Image (Using putData for cross-platform support)
      if (_imageBytes != null) {
        setState(() => _uploadStatus = "Uploading photo...");
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_photos')
            .child('${user.uid}.jpg');
        
        await ref.putData(_imageBytes!);
        photoUrl = await ref.getDownloadURL();
      }

      setState(() => _uploadStatus = "Saving profile...");

      // 2. Write to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'zip_code': _zipController.text.trim(),
        'birthday': Timestamp.fromDate(_birthday!),
        'submission_date': _subDate != null ? Timestamp.fromDate(_subDate!) : null,
        'interview_date': _interviewDate != null ? Timestamp.fromDate(_interviewDate!) : null,
        'version': _studyVersion,
        'photo_url': photoUrl,
        'isProfileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update Provider & Navigate
      if (mounted) {
         // Force refresh of user data so Home/Profile screens have the latest
         await Provider.of<UserProvider>(context, listen: false).refresh();
         Navigator.pushReplacementNamed(context, '/home');
      }

    } catch (e) {
      _showSnack("Error: $e");
    } finally {
       if (mounted) setState(() { _isLoading = false; _uploadStatus = null; });
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
      );
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final federalBlue = const Color(0xFF112D50);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Setup Profile", style: GoogleFonts.publicSans(color: federalBlue, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                      child: _imageBytes == null 
                        ? Icon(Icons.person, size: 60, color: Colors.grey.shade400)
                        : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: federalBlue, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Name
              _buildLabel("Full Name"),
              TextFormField(
                controller: _nameController,
                decoration: _inputDeco("Enter full name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              // Zip
              _buildLabel("Zip Code"),
              TextFormField(
                controller: _zipController,
                keyboardType: TextInputType.number,
                maxLength: 5,
                decoration: _inputDeco("12345").copyWith(counterText: ""),
                validator: (v) => (v!.length != 5) ? "Must be 5 digits" : null,
              ),
              const SizedBox(height: 16),

              // Birthday
              _buildLabel("Date of Birth"),
              _buildDatePicker(
                label: _birthday == null ? "Select Date" : DateFormat.yMMMMd().format(_birthday!),
                onTap: () => _selectDate(context, 'birthday'),
              ),
              const SizedBox(height: 16),

              // Submission Date
              _buildLabel("Form N-400 Submission Date (Optional)"),
              _buildDatePicker(
                label: _subDate == null ? "Not Submitted yet" : DateFormat.yMMMMd().format(_subDate!),
                onTap: () => _selectDate(context, 'sub'),
              ),
              const SizedBox(height: 16),

              // Interview Date
              _buildLabel("Interview Date (Optional)"),
              _buildDatePicker(
                label: _interviewDate == null ? "Not Scheduled yet" : DateFormat.yMMMMd().format(_interviewDate!),
                onTap: () => _selectDate(context, 'interview'),
              ),
              const SizedBox(height: 16),

              // Version Dropdown
              _buildLabel("Civics Test Version"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _studyVersion,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: '2020', child: Text("2020 Version (128 Questions)")),
                      DropdownMenuItem(value: '2008', child: Text("2008 Version (100 Questions)")),
                    ],
                    onChanged: (val) => setState(() => _studyVersion = val!),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: federalBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text(_uploadStatus ?? "Saving...", style: const TextStyle(color: Colors.white))
                      ])
                    : Text("Save & Continue", style: GoogleFonts.publicSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: GoogleFonts.publicSans(fontWeight: FontWeight.w600, color: const Color(0xFF112D50))),
      ),
    );
  }

  Widget _buildDatePicker({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.publicSans(fontSize: 16, color: const Color(0xFF112D50))),
            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    );
  }
}
