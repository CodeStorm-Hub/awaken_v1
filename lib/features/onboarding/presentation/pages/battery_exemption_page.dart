import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/battery_exemption_status.dart';
import '../../domain/usecases/check_battery_exemption_status.dart';
import '../../domain/usecases/open_oem_autostart_settings.dart';
import '../../domain/usecases/request_battery_exemption.dart';
import '../../../../core/theme/shape_tokens.dart';

/// Onboarding step (plan H4): explains why the OS's default battery
/// management will silently break alarms, then requests the standard
/// exemption and — on manufacturers known to be more aggressive than
/// stock Android — offers a best-effort deep link into their vendor
/// autostart/protected-apps screen too.
class BatteryExemptionPage extends StatefulWidget {
  const BatteryExemptionPage({this.onContinue, this.onBack, super.key});

  final VoidCallback? onContinue;

  /// Only supplied when this page is reached as an onboarding step (see
  /// `onboarding_page.dart`) — lets the user step back to the notification-
  /// rationale step instead of onboarding being one-way forward only.
  /// `null` when opened standalone from Profile, where there's no previous
  /// onboarding step to return to.
  final VoidCallback? onBack;

  @override
  State<BatteryExemptionPage> createState() => _BatteryExemptionPageState();
}

class _BatteryExemptionPageState extends State<BatteryExemptionPage>
    with WidgetsBindingObserver {
  BatteryExemptionStatus? _status;
  bool _requestingExemption = false;

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

  Future<void> _requestExemption() async {
    setState(() => _requestingExemption = true);
    try {
      await getIt<RequestBatteryExemption>()(const NoParams());
      await _refreshStatus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't open battery settings — please try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingExemption = false);
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showOemStep =
        status != null && status.isAggressiveOem && !status.isExempt;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.onBack != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: widget.onBack,
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                widget.onBack != null ? 6 : 22,
                20,
                6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExpressiveFlower(
                    size: 64,
                    color: scheme.secondaryContainer,
                    // See `alarm_list_page.dart`'s identical fix — light
                    // theme's `secondaryContainer` is nearly invisible
                    // against the page surface without a border.
                    borderColor: scheme.outline,
                    child: Icon(
                      Icons.battery_charging_full,
                      size: 30,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Keep alarms reliable',
                    style: TextStyle(
                      fontSize: 30,
                      height: 36 / 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // The battery-optimization/OEM-autostart-killer problem
                      // this whole page addresses (plan H4) is Android-only —
                      // see `BatteryExemptionRepositoryImpl`'s doc comment on
                      // `getManufacturer()`. The generic body text previously
                      // said "Android can silently stop apps..." even when
                      // this page was reached on iOS via Profile, which is
                      // simply false there.
                      Platform.isAndroid
                          ? 'Android can silently stop apps in the background to save '
                                'power. If that happens to Awaken, your alarm may not ring. '
                                'Allowing unrestricted battery usage keeps it reliable.'
                          : "iOS doesn't have this battery-optimization concept — "
                                "there's nothing to configure here.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (!Platform.isAndroid)
                      const SizedBox.shrink()
                    else if (status == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 36),
                        child: Center(child: ExpressiveLoader()),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            _StatusRow(
                              radius: showOemStep
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(20),
                                      bottom: Radius.circular(8),
                                    )
                                  : ShapeTokens.r20,
                              bg: status.isExempt
                                  ? scheme.primaryContainer
                                  : context.semanticColors.warningContainer,
                              fg: status.isExempt
                                  ? scheme.onPrimaryContainer
                                  : context.semanticColors.onWarningContainer,
                              icon: status.isExempt
                                  ? Icons.check_circle
                                  : Icons.warning,
                              title: status.isExempt
                                  ? 'Exemption granted'
                                  : 'Still restricted',
                              subtitle: status.isExempt
                                  ? 'Battery optimization exemption granted.'
                                  : 'Battery optimization is still restricting Awaken.',
                              actionLabel: status.isExempt ? null : 'Allow',
                              onAction: status.isExempt
                                  ? null
                                  : _requestExemption,
                              busy: _requestingExemption,
                            ),
                            if (showOemStep) ...[
                              const SizedBox(height: 3),
                              _StatusRow(
                                radius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                  bottom: Radius.circular(20),
                                ),
                                bg: scheme.surfaceContainerHigh,
                                fg: scheme.onSurface,
                                icon: Icons.settings,
                                iconColor: scheme.onSurfaceVariant,
                                title:
                                    '${_capitalize(status.manufacturer)} extra step',
                                subtitle:
                                    '${_capitalize(status.manufacturer)} devices often need an '
                                    'extra step: allow Awaken to auto-start in the background.',
                                actionLabel: 'Open',
                                outlined: true,
                                onAction: () =>
                                    getIt<OpenOemAutostartSettings>()(
                                      const NoParams(),
                                    ),
                              ),
                            ],
                            if (!status.isExempt) ...[
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  'You can enable this later in Settings → '
                                  'Battery.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: ShapeTokens.pill,
                    ),
                  ),
                  // `onContinue` is only ever supplied by the onboarding
                  // carousel, which owns advancing to the next step itself.
                  // Opened from Profile (`ProfilePage`'s "Battery & location"
                  // settings row), there's no next step — the button was
                  // simply disabled (`null` callback) with no way to leave
                  // the page except the system back gesture. Falling back to
                  // popping the route makes it a working "Done" instead of a
                  // dead end.
                  onPressed:
                      widget.onContinue ??
                      () => Navigator.of(context).maybePop(),
                  child: Text(widget.onContinue != null ? 'Continue' : 'Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.radius,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.actionLabel,
    this.onAction,
    this.outlined = false,
    this.busy = false,
  });

  final BorderRadius radius;
  final Color bg;
  final Color fg;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool outlined;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: iconColor ?? fg),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            if (busy)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
              )
            else
              outlined
                  ? OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: fg,
                        foregroundColor: bg,
                      ),
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
        ],
      ),
    );
  }
}
