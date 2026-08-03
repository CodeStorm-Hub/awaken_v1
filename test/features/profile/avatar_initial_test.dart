import 'package:awaken/core/theme/expressive_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatarInitial', () {
    test('anonymous user always gets the guest initial', () {
      expect(
        avatarInitial(isAnonymous: true, displayName: 'Anything', email: 'a@b.com'),
        'G',
      );
    });

    test('uses the first letter of displayName when present', () {
      expect(
        avatarInitial(isAnonymous: false, displayName: 'kai', email: 'kai@example.com'),
        'K',
      );
    });

    test('falls back to email when displayName is null', () {
      expect(
        avatarInitial(isAnonymous: false, displayName: null, email: 'zed@example.com'),
        'Z',
      );
    });

    test(
      'empty-string displayName does not throw and falls back to email — '
      'previously a RangeError via `(displayName ?? email ?? "A")[0]`, since '
      '`??` only guards null, not an empty string',
      () {
        expect(
          avatarInitial(isAnonymous: false, displayName: '', email: 'zed@example.com'),
          'Z',
        );
      },
    );

    test('empty-string displayName and email both empty falls back to A', () {
      expect(
        avatarInitial(isAnonymous: false, displayName: '', email: ''),
        'A',
      );
    });

    test('null displayName and null email falls back to A', () {
      expect(
        avatarInitial(isAnonymous: false, displayName: null, email: null),
        'A',
      );
    });
  });
}
