import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/design_system.dart';
import '../auth/login_screen.dart';
import '../profile.dart';
import 'my_requests_screen.dart';
import 'request_form_screen.dart';

class CitizenDashboard extends StatelessWidget {
  const CitizenDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return RescueGradientScaffold(
      child: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          final data = userSnap.data?.data() as Map<String, dynamic>?;
          final name = data?['name'] ?? 'Citizen';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const RescueLogo(size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Good day,',
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Logout',
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () async {
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                color: AppColors.primary,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.emergency_rounded, color: Colors.white, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Need Medical Transport?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Request Transport',
                      icon: Icons.add_rounded,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RequestFormScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () => _confirmHotline(context),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call RESCUE 35 Hotline'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _stats(uid),
              const SizedBox(height: 18),
              _tips(),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyRequestsScreen(),
                      ),
                    ),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _recentRequests(uid),
            ],
          );
        },
      ),
    );
  }

  Widget _stats(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transport_requests')
          .where('userID', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int count(String status) {
          return docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == status;
          }).length;
        }

        return Row(
          children: [
            _statCard('Pending', count('pending'), AppColors.pending),
            const SizedBox(width: 10),
            _statCard('Approved', count('approved'), AppColors.secondary),
            const SizedBox(width: 10),
            _statCard('Completed', count('completed'), AppColors.completed),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: const TextStyle(color: AppColors.textGray)),
          ],
        ),
      ),
    );
  }

  Widget _tips() {
    return const GlassCard(
      padding: EdgeInsets.all(16),
      radius: 18,
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: AppColors.secondary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Emergency tip: keep the patient reachable, prepare valid ID, and describe symptoms clearly.',
              style: TextStyle(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentRequests(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transport_requests')
          .where('userID', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const GlassCard(
            child: Center(
              child: Text(
                'No requests yet.',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
          );
        }

        // Client-side sort + limit 3 — same approach na gumana sa MyRequestsScreen
        final docs = [...snap.data!.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['requestDate'] as Timestamp?;
            final bDate = bData['requestDate'] as Timestamp?;
            return (bDate?.millisecondsSinceEpoch ?? 0)
                .compareTo(aDate?.millisecondsSinceEpoch ?? 0);
          });

        final recent = docs.take(3).toList();

        return Column(
          children: recent.map((doc) => _requestCard(doc)).toList(),
        );
      },
    );
  }

  Widget _requestCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';
    final tracking = data['trackingNumber'] ?? doc.id;
    final patientName = (data['patientName'] ?? data['patientname'] ?? 'Patient').toString();
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Row(
        children: [
          const Icon(Icons.route_outlined, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data['location'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  tracking,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _statusBadge(status),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

  Future<void> _confirmHotline(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call RESCUE 35 Hotline?'),
        content: const Text('Hotline: 911 / MDRRMO Lal-lo configured number'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call'),
          ),
        ],
      ),
    );
  }
}