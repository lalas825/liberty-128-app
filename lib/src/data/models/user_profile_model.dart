class UserProfile {
  final String uid;
  final String email;
  final DateTime? filingDate;
  final String? zipCode;
  final bool isPremium;

  const UserProfile({
    required this.uid,
    required this.email,
    this.filingDate,
    this.zipCode,
    this.isPremium = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String,
      filingDate: json['filingDate'] != null
          ? DateTime.parse(json['filingDate'] as String)
          : null,
      zipCode: json['zipCode'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'filingDate': filingDate?.toIso8601String(),
      'zipCode': zipCode,
      'isPremium': isPremium,
    };
  }

  /// Critical Logic: Return true if filingDate is on or after October 20, 2025.
  static bool is2025Version(DateTime filingDate) {
    final cutoffDate = DateTime(2025, 10, 20);
    // Use isAfter or isAtSameMomentAs to include the date itself.
    // Or simpler: compare headers/day or direct logic:
    return filingDate.isAfter(cutoffDate) || filingDate.isAtSameMomentAs(cutoffDate);
  }
}
