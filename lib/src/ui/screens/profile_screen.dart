import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/civic_info_service.dart';
import '../../logic/providers/user_provider.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State Variables
  final TextEditingController _nameController = TextEditingController();
  DateTime? _examDate;
  bool _isLoading = true;
  
  // Image State
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  // Load Data from UserProvider
  Future<void> _loadProfileData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.refresh();
    
    if (!mounted) return;
    
    setState(() {
      _nameController.text = userProvider.userName ?? "";
      _examDate = userProvider.examDate;
      _zipController.text = userProvider.zipCode ?? "";
      
      if (_zipController.text.length == 5 && _governorController.text.isEmpty) {
         _fetchCivicInfo(); 
      }
      
      _isLoading = false;
    });
  }

  // Save Data Helpers
  Future<void> _updateFirestore(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        data, SetOptions(merge: true)
      );
      if (mounted) {
         Provider.of<UserProvider>(context, listen: false).refresh();
      }
    }
  }

  Future<void> _saveName(String value) async {
    setState(() {}); 
    await _updateFirestore({'name': value});
  }

  Future<void> _saveExamDate(DateTime date) async {
    setState(() {
      _examDate = date;
    });
    await _updateFirestore({'interview_date': Timestamp.fromDate(date)});
  }
  
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
       Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // Image Picker Logic 
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() => _isLoading = true);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
           final bytes = await image.readAsBytes();
           final ref = FirebaseStorage.instance.ref().child('user_photos').child('${user.uid}.jpg');
           await ref.putData(bytes);
           final url = await ref.getDownloadURL();
           await _updateFirestore({'photo_url': url});
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      setState(() => _isLoading = false);
    }
  }

  // Civic Info Logic
  Future<void> _fetchCivicInfo() async {
    final zip = _zipController.text.trim();
    if (zip.isEmpty || zip.length != 5) {
      if (_isSearchingCivic) return; 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid 5-digit Zip Code")));
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

      // Also Update User Profile with Zip for permanence
      _updateFirestore({'zip_code': zip});

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSearchingCivic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final Color federalBlue = AppColors.navyBlue; // Updated to Navy Blue
    final Color sectionTitleColor = Colors.grey.shade700;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Profile", style: GoogleFonts.publicSans(color: federalBlue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // --- HEADER (PHOTO + NAME) ---
             Consumer<UserProvider>(
               builder: (context, userProvider, _) {
                 final photo = userProvider.photoUrl;
                 return Center(
                   child: Column(
                     children: [
                       GestureDetector(
                         onTap: _pickImage,
                         child: Stack(
                           children: [
                             Container(
                               width: 100,
                               height: 100,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 color: federalBlue.withOpacity(0.1),
                               ),
                               child: ClipOval(
                                 child: photo != null
                                     ? Image.network(
                                         photo,
                                         fit: BoxFit.cover,
                                         errorBuilder: (context, error, stackTrace) {
                                           debugPrint("Profile Image Load Error: $error");
                                           // Fallback to Initials on Error (e.g., CORS)
                                           return Center(
                                             child: Text(
                                               _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : "U",
                                               style: GoogleFonts.publicSans(fontSize: 40, color: federalBlue, fontWeight: FontWeight.bold),
                                             ),
                                           );
                                         },
                                         loadingBuilder: (context, child, loadingProgress) {
                                           if (loadingProgress == null) return child;
                                           return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                                         },
                                       )
                                     : Center(
                                         child: Text(
                                           _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : "U",
                                           style: GoogleFonts.publicSans(fontSize: 40, color: federalBlue, fontWeight: FontWeight.bold),
                                         ),
                                       ),
                               ),
                             ),
                             Positioned(
                               bottom: 0, right: 0,
                               child: Container(
                                 padding: const EdgeInsets.all(4),
                                 decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                                 child: Icon(Icons.camera_alt, color: federalBlue, size: 20),
                               ),
                             )
                           ],
                         ),
                       ),
                       const SizedBox(height: 16),
                       TextField(
                         controller: _nameController,
                         textAlign: TextAlign.center,
                         style: GoogleFonts.publicSans(fontSize: 22, fontWeight: FontWeight.bold, color: federalBlue),
                         decoration: const InputDecoration(hintText: "Enter Your Name", border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)),
                         onChanged: _saveName, 
                       ),
                     ],
                   ),
                 );
               }
             ),
             const SizedBox(height: 32),
             
             // --- SECTION A: CASE DETAILS ---
             Text("CASE DETAILS", style: GoogleFonts.publicSans(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
             const SizedBox(height: 8),
             Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    // Interview Date
                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                      title: Text(_examDate == null ? "Set Exam Date" : DateFormat.yMMMMd().format(_examDate!), style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _examDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) _saveExamDate(picked);
                      },
                    ),
                    const Divider(height: 1),
                    // Version Toggle
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        // Logic: '2025' means new/Trump/Strict version. '2008' means Standard.
                        // Default in Provider is '2020'. Let's map 2020->2025 for clarity or treat 2020 as 2008?
                        // User Prompt: "2008 Version (100Q) vs 2025 Version (128Q)"
                        final current = userProvider.studyVersion;
                        final is2025 = (current == '2025' || current == '2020'); 
                        
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.quiz, color: Colors.orangeAccent),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Civics Version", style: GoogleFonts.publicSans(fontWeight: FontWeight.w600)),
                                    Text(is2025 ? "128 Questions (2020/2025)" : "100 Questions (2008)", style: GoogleFonts.publicSans(fontSize: 12, color: Colors.grey)),
                                  ],
                                )
                              ),
                              Switch(
                                value: is2025, 
                                activeColor: federalBlue,
                                onChanged: (val) {
                                  // Toggle
                                  userProvider.updateVersion(val ? '2025' : '2008');
                                }
                              )
                            ],
                          ),
                        );
                      }
                    )
                  ],
                ),
             ),
             const SizedBox(height: 32),

             // --- SECTION B: LOCATION ---
             Text("LOCATION & REPS", style: GoogleFonts.publicSans(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
             const SizedBox(height: 8),
             Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _zipController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Zip Code",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(color: federalBlue, borderRadius: BorderRadius.circular(8)),
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
                      _buildCivicField("Governor", _governorController),
                      const SizedBox(height: 12),
                      _buildCivicField("Senator 1", _senator1Controller),
                      const SizedBox(height: 12),
                      _buildCivicField("Senator 2", _senator2Controller),
                      const SizedBox(height: 12),
                      _buildCivicField("Representative", _repController),
                    ],
                  ),
                ),
             ),

             const SizedBox(height: 40),
             
             // --- FOOTER: LOGOUT ---
             SizedBox(
               width: double.infinity,
               child: TextButton.icon(
                 onPressed: _signOut,
                 icon: const Icon(Icons.logout, color: Colors.red),
                 label: Text("Log Out", style: GoogleFonts.publicSans(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                 style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
               ),
             ),
             const SizedBox(height: 20),
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
