/// A driver's uploaded verification document (row in `driver_documents`).
class DriverDocument {
  DriverDocument({
    required this.docType,
    required this.storagePath,
    this.status = 'pending',
    this.expiryDate,
    this.note,
  });

  final String docType;
  final String storagePath;
  final String status; // pending | approved | rejected
  final DateTime? expiryDate;
  final String? note;

  factory DriverDocument.fromJson(Map<String, dynamic> j) => DriverDocument(
        docType: j['doc_type'] as String,
        storagePath: j['storage_path'] as String,
        status: j['status'] as String? ?? 'pending',
        expiryDate: j['expiry_date'] != null
            ? DateTime.tryParse(j['expiry_date'] as String)
            : null,
        note: j['note'] as String?,
      );
}
