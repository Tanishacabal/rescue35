import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../widgets/design_system.dart';

class TermsScreen extends StatefulWidget {
  final Widget next;

  const TermsScreen({super.key, required this.next});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _terms = false;
  bool _privacy = false;

  @override
  Widget build(BuildContext context) {
    final canContinue = _terms && _privacy;
    return RescueGradientScaffold(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Row(
            children: [
              RescueLogo(size: 52),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms & Privacy',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      'Required for first launch',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _termItem(Icons.privacy_tip_outlined,
                    'Data Privacy Act of 2012 and user consent'),
                _termItem(Icons.document_scanner_outlined,
                    'OCR consent for patient care report processing'),
                _termItem(Icons.local_hospital_outlined,
                    'Emergency medical transport policy and LGU review'),
                _termItem(Icons.warning_amber_rounded,
                    'False request penalties and misuse reporting'),
                _termItem(Icons.verified_user_outlined,
                    'Account verification before citizen transport requests'),
                const Divider(height: 28),
                CheckboxListTile(
                  value: _terms,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => setState(() => _terms = value ?? false),
                  title: const Text('I agree to the Terms and Conditions'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _privacy,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) =>
                      setState(() => _privacy = value ?? false),
                  title: const Text('I agree to the Privacy Policy'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Accept and Continue',
            icon: Icons.check_circle_outline_rounded,
            onPressed: canContinue
                ? () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => widget.next),
                    )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _termItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.secondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(height: 1.35)),
          ),
        ],
      ),
    );
  }
}
