/// A saved card. Mirrors a `payment_methods` row — display metadata only,
/// the card itself lives in Stripe.
class PaymentMethod {
  PaymentMethod({
    required this.id,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.isDefault = false,
  });

  final String id;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final bool isDefault;

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
        id: j['id'] as String,
        brand: j['brand'] as String?,
        last4: j['last4'] as String?,
        expMonth: (j['exp_month'] as num?)?.toInt(),
        expYear: (j['exp_year'] as num?)?.toInt(),
        isDefault: j['is_default'] as bool? ?? false,
      );

  String get displayBrand {
    final b = brand;
    if (b == null || b.isEmpty) return 'Card';
    return b[0].toUpperCase() + b.substring(1);
  }

  String get expiresLabel {
    if (expMonth == null || expYear == null) return '';
    return '${expMonth.toString().padLeft(2, '0')}/$expYear';
  }
}
