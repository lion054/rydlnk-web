import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/driver_repository.dart';
import '../../models/driver_document.dart';
import '../../models/driver_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/errors.dart';

class _DocSpec {
  const _DocSpec(this.type, this.label, this.icon, {this.needsExpiry = false});
  final String type;
  final String label;
  final IconData icon;
  final bool needsExpiry;
}

const _required = [
  _DocSpec('national_id', 'National ID', Icons.badge_outlined),
  _DocSpec('drivers_license', "Driver's licence", Icons.card_membership_outlined,
      needsExpiry: true),
  _DocSpec('vehicle_registration', 'Vehicle registration',
      Icons.description_outlined),
  _DocSpec('insurance', 'Insurance', Icons.shield_outlined, needsExpiry: true),
];

class DriverVerificationScreen extends StatefulWidget {
  const DriverVerificationScreen({super.key});

  @override
  State<DriverVerificationScreen> createState() =>
      _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  final _repo = DriverRepository();
  DriverProfile? _driver;
  Map<String, DriverDocument> _docs = {};
  bool _loading = true;
  String? _uploading;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final driver = await _repo.myDriver();
    final docs = await _repo.myDocuments();
    if (!mounted) return;
    setState(() {
      _driver = driver;
      _docs = {for (final d in docs) d.docType: d};
      _loading = false;
    });
  }

  Future<void> _upload(_DocSpec spec) async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 80);
    if (x == null) return;
    DateTime? expiry;
    if (spec.needsExpiry && mounted) {
      expiry = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 180)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
        helpText: 'Expiry date on the ${spec.label.toLowerCase()}',
      );
      if (expiry == null) return; // expiry required for these docs
    }
    setState(() => _uploading = spec.type);
    HapticFeedback.lightImpact();
    try {
      final bytes = await x.readAsBytes();
      await _repo.uploadDocument(
          docType: spec.type, bytes: bytes, expiry: expiry);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _repo.requestVerification();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Submitted for review. We\'ll be in touch.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _allUploaded => _required.every((s) => _docs.containsKey(s.type));

  @override
  Widget build(BuildContext context) {
    final status = _driver?.verificationStatus ?? 'unverified';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Verification', style: AppType.h3),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                _StatusBanner(status: status),
                const SizedBox(height: 20),
                Text('Required documents',
                    style: AppType.h2.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  'Clear photos of each. Riders never see these — they are used '
                  'only to verify you.',
                  style: AppType.caption,
                ),
                const SizedBox(height: 12),
                for (final spec in _required) ...[
                  _DocTile(
                    spec: spec,
                    doc: _docs[spec.type],
                    busy: _uploading == spec.type,
                    onUpload: () => _upload(spec),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                if (status != 'pending' && status != 'approved')
                  Material(
                    color: _allUploaded
                        ? AppColors.primary
                        : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: (_allUploaded && !_submitting) ? _submit : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: Text(
                            _submitting ? 'Submitting…' : 'Submit for review',
                            style:
                                AppType.button.copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Verification is manual today: our team reviews your documents '
                  'and a background check before approving you to drive.',
                  style: AppType.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    late final Color color, bg;
    late final IconData icon;
    late final String title, subtitle;
    switch (status) {
      case 'approved':
        color = AppColors.primary;
        bg = AppColors.primaryTint;
        icon = Icons.verified_rounded;
        title = 'Verified';
        subtitle = 'You can accept trips.';
        break;
      case 'pending':
        color = AppColors.accentBlue;
        bg = AppColors.accentBlueTint;
        icon = Icons.hourglass_top_rounded;
        title = 'Under review';
        subtitle = 'We\'re checking your documents.';
        break;
      case 'rejected':
        color = AppColors.danger;
        bg = AppColors.dangerTint;
        icon = Icons.error_outline_rounded;
        title = 'Needs attention';
        subtitle = 'Please re-upload the flagged documents.';
        break;
      default:
        color = AppColors.warning;
        bg = AppColors.warningTint;
        icon = Icons.upload_file_rounded;
        title = 'Get verified';
        subtitle = 'Upload your documents to start driving.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.bodyStrong),
                const SizedBox(height: 2),
                Text(subtitle, style: AppType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.spec,
    required this.doc,
    required this.busy,
    required this.onUpload,
  });

  final _DocSpec spec;
  final DriverDocument? doc;
  final bool busy;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final uploaded = doc != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: uploaded ? AppColors.primary : AppColors.border,
            width: uploaded ? 1.3 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(spec.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.label, style: AppType.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  !uploaded
                      ? 'Not uploaded'
                      : doc!.status == 'approved'
                          ? 'Approved'
                          : doc!.status == 'rejected'
                              ? (doc!.note ?? 'Rejected — re-upload')
                              : 'Uploaded · pending review',
                  style: AppType.caption.copyWith(
                    color: doc?.status == 'rejected'
                        ? AppColors.danger
                        : AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))
          else
            GestureDetector(
              onTap: onUpload,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(uploaded ? 'Replace' : 'Upload',
                    style: AppType.captionStrong
                        .copyWith(color: AppColors.primary, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
