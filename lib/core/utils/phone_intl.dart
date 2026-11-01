/// Nigerian phone numbers in international form for wa.me links:
/// "0803 123-4567" becomes "2348031234567". Spaces, dashes, brackets and a
/// leading + are removed. Null when there is no usable number.
String? nigerianInternational(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('234')) return digits.length >= 12 ? digits : null;
  if (digits.startsWith('0') && digits.length == 11) return '234${digits.substring(1)}';
  if (digits.length == 10 && RegExp(r'^[789]').hasMatch(digits)) return '234$digits';
  return digits.length >= 10 ? digits : null;
}
