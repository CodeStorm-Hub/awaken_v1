import 'package:awaken/core/platform/system_capabilities.dart';
import 'package:awaken/features/onboarding/data/repositories/battery_exemption_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSystemCapabilities extends Mock implements SystemCapabilities {}

void main() {
  late BatteryExemptionRepositoryImpl repository;

  setUp(() {
    repository = BatteryExemptionRepositoryImpl(_MockSystemCapabilities());
  });

  group('isAggressiveOem', () {
    // dontkillmyapp.com-documented manufacturers (plan H4) — a typo/removal
    // here silently drops that OEM's autostart-settings nudge with no other
    // signal, so pin the exact set rather than spot-checking one or two.
    const knownAggressive = {
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'realme',
      'vivo',
      'huawei',
      'honor',
      'samsung',
      'oneplus',
      'meizu',
      'asus',
    };

    for (final manufacturer in knownAggressive) {
      test('flags $manufacturer as aggressive', () {
        expect(repository.isAggressiveOem(manufacturer), isTrue);
      });
    }

    test('does not flag an unlisted manufacturer', () {
      expect(repository.isAggressiveOem('google'), isFalse);
      expect(repository.isAggressiveOem('sony'), isFalse);
    });

    test('is case-sensitive — callers must lowercase first', () {
      // getManufacturer() always lowercases before this is called; this
      // pins that isAggressiveOem itself does no normalization, so a
      // future caller can't skip the lowercasing step silently.
      expect(repository.isAggressiveOem('Xiaomi'), isFalse);
    });

    test('empty string is not aggressive', () {
      expect(repository.isAggressiveOem(''), isFalse);
    });
  });
}
