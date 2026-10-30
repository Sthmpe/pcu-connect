/// E.164 Phone Normalization & Privacy Masking Utilities
abstract class PhoneUtils {
  /// Normalizes raw phone strings into strict E.164 format (+[country_code][number])
  static String normalizeToE164(
    String rawPhone, {
    String defaultCountryCode = '234',
  }) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return '';

    if (rawPhone.trim().startsWith('+')) {
      return '+$digitsOnly';
    }

    if (digitsOnly.startsWith('0')) {
      return '+$defaultCountryCode${digitsOnly.substring(1)}';
    }

    return '+$digitsOnly';
  }

  /// Masks phone numbers for privacy in broad viewer reports (e.g. +234 803 *** 1234)
  static String maskPhone(String phoneE164) {
    if (phoneE164.length < 8) return '***';
    final prefix = phoneE164.substring(0, 6);
    final suffix = phoneE164.substring(phoneE164.length - 4);
    return '$prefix *** $suffix';
  }

  /// Validates basic E.164 format
  static bool isValidE164(String phoneE164) {
    final e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');
    return e164Regex.hasMatch(phoneE164);
  }
}
