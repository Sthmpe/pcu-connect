import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils', () {
    test('normalizes Nigerian numbers to E.164 with country code', () {
      expect(PhoneUtils.normalizeToE164('08035550101'), '+2348035550101');
      expect(PhoneUtils.normalizeToE164('0803 555 0101'), '+2348035550101');
      expect(PhoneUtils.normalizeToE164('+234 803 555 0101'), '+2348035550101');
    });

    test('validates E.164 format correctly', () {
      expect(PhoneUtils.isValidE164('+2348035550101'), isTrue);
      expect(PhoneUtils.isValidE164('08035550101'), isFalse);
      expect(PhoneUtils.isValidE164('invalid'), isFalse);
    });

    test('masks phone numbers for privacy', () {
      expect(PhoneUtils.maskPhone('+2348035550101'), '+23480 *** 0101');
      expect(PhoneUtils.maskPhone('123'), '***');
    });
  });
}
