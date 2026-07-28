/// Registry of legal documents shipped as assets. Bump [version] when a
/// document changes so consent is re-captured.
class LegalDoc {
  const LegalDoc(this.key, this.title, this.asset, this.version);
  final String key;
  final String title;
  final String asset;
  final String version;
}

const kTerms =
    LegalDoc('terms', 'Terms of Service', 'assets/legal/terms.md', '0.1');
const kPrivacy =
    LegalDoc('privacy', 'Privacy Policy', 'assets/legal/privacy.md', '0.1');
const kRiderAgreement = LegalDoc('rider_agreement', 'Rider Agreement',
    'assets/legal/rider_agreement.md', '0.1');
const kDriverAgreement = LegalDoc('driver_agreement', 'Driver Agreement',
    'assets/legal/driver_agreement.md', '0.1');
