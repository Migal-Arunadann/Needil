/// Reusable form validators.
class Validators {
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? minLength(String? value, int min, [String fieldName = 'This field']) {
    if (value == null || value.trim().length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  static const Map<String, int> countryPhoneCodes = {
    '+91': 10,
    '+1': 10,
    '+44': 10,
    '+61': 9,
    '+65': 8,
    '+971': 9,
    '+966': 9,
  };

  static String? phone(String? value, {String countryCode = '+91'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    final cleanCode = countryCode.replaceAll('+', '');
    
    int expectedLength = 10;
    if (cleanCode == '91' || cleanCode == '1' || cleanCode == '44') {
      expectedLength = 10;
    } else if (cleanCode == '61' || cleanCode == '971' || cleanCode == '966') {
      expectedLength = 9;
    } else if (cleanCode == '65') {
      expectedLength = 8;
    } else {
      if (!RegExp(r'^[0-9]{8,15}$').hasMatch(cleaned)) {
        return 'Enter a valid phone number';
      }
      return null;
    }

    if (cleaned.length != expectedLength || !RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
      return 'Phone number must be $expectedLength digits';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? number(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (int.tryParse(value.trim()) == null) {
      return '$fieldName must be a number';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'This field']) {
    final numError = number(value, fieldName);
    if (numError != null) return numError;
    if (int.parse(value!.trim()) <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }
}

class PhoneParser {
  static (String countryCode, String nationalNumber) parse(String? fullPhone) {
    if (fullPhone == null || fullPhone.isEmpty) {
      return ('+91', '');
    }
    
    final clean = fullPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    for (final code in ['+91', '+1', '+44', '+61', '+65', '+971', '+966']) {
      if (clean.startsWith(code)) {
        return (code, clean.substring(code.length));
      }
    }
    
    for (final code in ['91', '1', '44', '61', '65', '971', '966']) {
      if (clean.startsWith(code)) {
        final remaining = clean.substring(code.length);
        final cleanCode = '+$code';
        int expectedLength = 10;
        if (code == '61' || code == '971' || code == '966') expectedLength = 9;
        if (code == '65') expectedLength = 8;
        
        if (remaining.length == expectedLength) {
          return (cleanCode, remaining);
        }
      }
    }
    
    if (clean.length == 10) {
      return ('+91', clean);
    }
    
    return ('+91', clean);
  }
}
