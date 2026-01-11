import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../logic/viewmodels/onboarding_viewmodel.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Access the Logic (ViewModel)
    final viewModel = Provider.of<OnboardingViewModel>(context);

    // Color Palette from Stitch Design
    final Color federalBlue = const Color(0xFF112D50);
    final Color libertyGreen = const Color(0xFF00C4B4);
    final Color bgLight = const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          // --- HEADER SECTION (Hero) ---
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: federalBlue,
              image: DecorationImage(
                image: NetworkImage(
                    'https://images.unsplash.com/photo-1550565118-c974095cc3d8?q=80&w=1000&auto=format&fit=crop'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    federalBlue.withOpacity(0.85), BlendMode.srcOver),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance,
                          color: libertyGreen, size: 28),
                      SizedBox(width: 8),
                      Text(
                        "OFFICIAL PREP PARTNER",
                        style: GoogleFonts.publicSans(
                          color: libertyGreen,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    "US Citizenship Prep",
                    style: GoogleFonts.publicSans(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    "Master the civics test with confidence.",
                    style: GoogleFonts.publicSans(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- MAIN CONTENT ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: federalBlue, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Your test version depends on when you filed your Form N-400. Select your filing date below.",
                            style: GoogleFonts.publicSans(
                              color: federalBlue.withOpacity(0.8),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Label
                  Text(
                    "APPLICATION FILING DATE",
                    style: GoogleFonts.publicSans(
                      color: federalBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),

                  SizedBox(height: 12),
                  // --- DATE PICKER CARD ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: ColorScheme.light(primary: federalBlue),
                      ),
                      child: CalendarDatePicker(
                        initialDate: viewModel.selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        onDateChanged: (newDate) {
                          viewModel.selectDate(newDate);
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // --- DYNAMIC FEEDBACK CARD ---
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: viewModel.is2025Version
                          ? libertyGreen.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: viewModel.is2025Version
                            ? libertyGreen
                            : Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DETECTED VERSION",
                              style: GoogleFonts.publicSans(
                                color: viewModel.is2025Version
                                    ? Colors.teal
                                    : Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              viewModel.is2025Version
                                  ? "2025 Version (128 Qs)"
                                  : "Legacy 2008 (100 Qs)",
                              style: GoogleFonts.publicSans(
                                color: federalBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          viewModel.is2025Version
                              ? Icons.check_circle
                              : Icons.history,
                          color: viewModel.is2025Version
                              ? libertyGreen
                              : Colors.blue,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- FOOTER BUTTON ---
          Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: federalBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: viewModel.isLoading
                    ? null
                    : () => viewModel.saveAndStart(context),
                child: viewModel.isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Start Studying",
                            style: GoogleFonts.publicSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
