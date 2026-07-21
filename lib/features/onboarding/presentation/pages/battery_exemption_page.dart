import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/battery_exemption_status.dart';
import '../../domain/usecases/check_battery_exemption_status.dart';
import '../../domain/usecases/open_oem_autostart_settings.dart';
import '../../domain/usecases/request_battery_exemption.dart';

/// Onboarding step (plan H4): explains why the OS's default battery
/// management will silently break alarms, then requests the standard
/// exemption and — on manufacturers known to be more aggressive than
/// stock Android — offers a best-effort deep link into their vendor
/// autostart/protected-apps screen too.
class BatteryExemptionPage extends StatefulWidget {
  const BatteryExemptionPage({this.onContinue, super.key});

  final VoidCallback? onContinue;

  @override
  State<BatteryExemptionPage> createState() => _BatteryExemptionPageState();
}

class _BatteryExemptionPageState extends State<BatteryExemptionPage> with WidgetsBindingObserver {
  BatteryExemptionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have granted the exemption in a system settings screen
    // and returned via the back button — recheck rather than assume.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await getIt<CheckBatteryExemptionStatus>()(const NoParams());
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Keep alarms reliable')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Android can silently stop apps in the background to save '
              'power. If that happens to Awaken, your alarm may not ring. '
              'Allowing unrestricted battery usage keeps it reliable.',
            ),
            const SizedBox(height: 24),
            if (status == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                children: [
                  Icon(
                    status.isExempt ? Icons.check_circle : Icons.warning_amber,
                    color: status.isExempt ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.isExempt
                          ? 'Battery optimization exemption granted.'
                          : 'Battery optimization is still restricting Awaken.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!status.isExempt)
                FilledButton(
                  onPressed: () async {
                    await getIt<RequestBatteryExemption>()(const NoParams());
                    await _refreshStatus();
                  },
                  child: const Text('Allow unrestricted battery usage'),
                ),
              if (status.isAggressiveOem) ...[
                const SizedBox(height: 16),
                Text(
                  '${_capitalize(status.manufacturer)} devices often need an extra '
                  'step: allow Awaken to auto-start in the background.',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    await getIt<OpenOemAutostartSettings>()(const NoParams());
                  },
                  child: Text('Open ${_capitalize(status.manufacturer)} settings'),
                ),
              ],
            ],
            const Spacer(),
            FilledButton.tonal(
              onPressed: widget.onContinue,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
