import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_colors.dart';
import '../../widgets/design_system.dart';
import '../profile.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return RescueGradientScaffold(
      child: Column(
        children: [
          AppBar(
            title: const Text('My Requests'),
            actions: [
              IconButton(
                tooltip: 'Profile',
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(role: 'citizen'),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transport_requests')
                  .where('userID', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load requests right now.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textGray),
                      ),
                    ),
                  );
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No requests yet.',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  );
                }
                final docs = [...snap.data!.docs]
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aDate = aData['requestDate'] as Timestamp?;
                    final bDate = bData['requestDate'] as Timestamp?;
                    return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                      aDate?.millisecondsSinceEpoch ?? 0,
                    );
                  });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    return _RequestCard(doc: docs[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders one transport request card. Patient details (name, age, sex,
/// contact number, barangay) live in a separate `patients` collection —
/// the transport_requests doc only stores a `patientID` reference — so
/// this widget fetches that patient doc once and merges it in before
/// displaying the card.
class _RequestCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _RequestCard({required this.doc});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  late Future<DocumentSnapshot<Map<String, dynamic>>?> _patientFuture;

  @override
  void initState() {
    super.initState();
    _patientFuture = _loadPatient();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadPatient() {
    final data = widget.doc.data() as Map<String, dynamic>;
    final patientID = (data['patientID'] ?? '').toString();
    if (patientID.isEmpty) return Future.value(null);
    return FirebaseFirestore.instance
        .collection('patients')
        .doc(patientID)
        .get();
  }

  /// The database stores names as "LASTNAME, FIRSTNAME MI." for consistency.
  /// For display in the UI, convert that back into a natural
  /// "Firstname Mi. Lastname" reading order (title case).
  String _displayName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return 'Patient';

    if (!trimmed.contains(',')) {
      // Not in "LAST, FIRST MI." format — just title-case whatever is there.
      return trimmed.split(RegExp(r'\s+')).map(_titleCase).join(' ');
    }

    final parts = trimmed.split(',');
    final last = _titleCase(parts[0].trim());
    final rest = parts.length > 1 ? parts[1].trim() : '';
    final restTokens =
        rest.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (restTokens.isEmpty) return last;

    final lastToken = restTokens.last;
    final isMi = lastToken.replaceAll('.', '').length == 1;

    if (isMi && restTokens.length > 1) {
      final first =
          restTokens.sublist(0, restTokens.length - 1).map(_titleCase).join(' ');
      final mi = '${lastToken.replaceAll('.', '').toUpperCase()}.';
      return '$first $mi $last';
    }

    final first = restTokens.map(_titleCase).join(' ');
    return '$first $last';
  }

  String _titleCase(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _patientFuture,
      builder: (context, patientSnap) {
        final requestData = widget.doc.data() as Map<String, dynamic>;
        final patientData = patientSnap.data?.data() ?? const {};
        final patientLoading =
            patientSnap.connectionState == ConnectionState.waiting;

        final status = requestData['status'] ?? 'pending';

        final rawPatientName = (patientData['patientname'] ??
                requestData['patientName'] ??
                requestData['patientname'] ??
                '')
            .toString();
        final patientName = patientLoading ? 'Loading…' : _displayName(rawPatientName);

        final location = (requestData['location'] ?? '-').toString();
        final date = (requestData['requestDate'] as Timestamp?)
                ?.toDate()
                .toString()
                .substring(0, 16) ??
            '-';

        final age = (patientData['age'] ?? '').toString();
        final sex = (patientData['sex'] ?? '').toString();
        final contactNumber =
            (patientData['contactNumber'] ?? '-').toString();
        final barangay = (patientData['barangay'] ?? '-').toString();
        final hospital = (requestData['destinationHospital'] ?? '-').toString();
        final scheduleDate = requestData['scheduleDate'] as Timestamp?;
        final scheduleDateStr = scheduleDate != null
            ? scheduleDate.toDate().toString().substring(0, 10)
            : '-';
        final scheduleTime = (requestData['scheduleTime'] ?? '-').toString();
        final notes = (requestData['additionalNotes'] ?? '').toString().trim();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          requestData['trackingNumber'] ?? widget.doc.id,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${requestData['description'] ?? '-'}\nSubmitted: $date',
                style: const TextStyle(color: AppColors.textGray, height: 1.35),
              ),
              const Divider(height: 26),
              _detailRow(
                  Icons.badge_outlined,
                  'Patient',
                  [age.isEmpty ? null : '$age yrs old', sex.isEmpty ? null : sex]
                      .whereType<String>()
                      .join(' · ')),
              _detailRow(Icons.phone_outlined, 'Contact', contactNumber),
              _detailRow(Icons.map_outlined, 'Barangay', barangay),
              _detailRow(
                  Icons.local_hospital_outlined, 'Destination', hospital),
              _detailRow(Icons.event_outlined, 'Schedule',
                  '$scheduleDateStr · $scheduleTime'),
              if (notes.isNotEmpty)
                _detailRow(Icons.note_alt_outlined, 'Notes', notes),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGray,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'approved' => AppColors.secondary,
      'in-transit' => AppColors.accent,
      'completed' => AppColors.completed,
      _ => AppColors.pending,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}