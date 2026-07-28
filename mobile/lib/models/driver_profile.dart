/// A driver's own record — mirrors a `drivers` row.
class DriverProfile {
  DriverProfile({
    required this.id,
    this.vehicle,
    this.plate,
    this.rating = 5.0,
    this.isAvailable = false,
    this.verified = false,
    this.verificationStatus = 'unverified',
    this.insuranceExpiry,
  });

  final String id;
  final String? vehicle;
  final String? plate;
  final double rating;
  final bool isAvailable;
  final bool verified;
  final String verificationStatus; // unverified | pending | approved | rejected
  final DateTime? insuranceExpiry;

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        id: j['id'] as String,
        vehicle: j['vehicle'] as String?,
        plate: j['license_plate'] as String?,
        rating: (j['rating'] as num?)?.toDouble() ?? 5.0,
        isAvailable: j['is_available'] as bool? ?? false,
        verified: j['verified'] as bool? ?? false,
        verificationStatus:
            j['verification_status'] as String? ?? 'unverified',
        insuranceExpiry: j['insurance_expiry'] != null
            ? DateTime.tryParse(j['insurance_expiry'] as String)
            : null,
      );

  String get vehicleLabel {
    final v = vehicle?.trim();
    final p = plate?.trim();
    if ((v == null || v.isEmpty) && (p == null || p.isEmpty)) {
      return 'No vehicle yet';
    }
    if (p == null || p.isEmpty) return v!;
    if (v == null || v.isEmpty) return p;
    return '$v · $p';
  }
}
