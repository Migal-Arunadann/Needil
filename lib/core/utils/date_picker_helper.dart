import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formatter that automatically formats digits typed as DD/MM/YYYY
/// and expands 2-digit years (e.g. '95' -> '1995') when typed.
class DateSlashInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(digitsOnly[i]);
      if (buffer.length >= 10) break; // DD/MM/YYYY max length
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Custom MaterialLocalizations Delegate that parses DDMMYY, DDMMYYYY,
/// DD/MM/YY, and DD/MM/YYYY seamlessly without returning null ("Invalid format.").
class AppMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const AppMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return const _AppMaterialLocalizations();
  }

  @override
  bool shouldReload(AppMaterialLocalizationsDelegate old) => false;
}

class _AppMaterialLocalizations extends DefaultMaterialLocalizations {
  const _AppMaterialLocalizations();

  @override
  String get dateHelpText => 'dd/mm/yyyy';

  @override
  String get invalidDateFormatLabel => 'Invalid date format (dd/mm/yyyy)';

  @override
  DateTime? parseCompactDate(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final clean = input.trim();

    // 1. Raw digits without slashes (e.g. "140226" -> 14/02/2026; "14021995" -> 14/02/1995)
    final digitsOnly = clean.replaceAll(RegExp(r'[^\d]'), '');
    if (clean == digitsOnly) {
      if (digitsOnly.length == 6) {
        final day = int.tryParse(digitsOnly.substring(0, 2));
        final month = int.tryParse(digitsOnly.substring(2, 4));
        final year2 = int.tryParse(digitsOnly.substring(4, 6));
        if (day != null && month != null && year2 != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final currentYr2 = DateTime.now().year % 100;
          final fullYear = year2 > currentYr2 ? 1900 + year2 : 2000 + year2;
          return _validDateTime(fullYear, month, day);
        }
      } else if (digitsOnly.length == 8) {
        final day = int.tryParse(digitsOnly.substring(0, 2));
        final month = int.tryParse(digitsOnly.substring(2, 4));
        final year = int.tryParse(digitsOnly.substring(4, 8));
        if (day != null && month != null && year != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return _validDateTime(year, month, day);
        }
      }
    }

    // 2. Parsed with slashes, dots, or hyphens (DD/MM/YYYY or DD/MM/YY)
    final parts = clean.split(RegExp(r'[/.\-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      int? year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        if (parts[2].length == 2) {
          final currentYr2 = DateTime.now().year % 100;
          year = year > currentYr2 ? 1900 + year : 2000 + year;
        }
        return _validDateTime(year, month, day);
      }
    }

    return super.parseCompactDate(input);
  }

  DateTime? _validDateTime(int y, int m, int d) {
    try {
      final dt = DateTime(y, m, d);
      if (dt.year == y && dt.month == m && dt.day == d) return dt;
    } catch (_) {}
    return null;
  }
}

/// Post-frame wrapper that attaches live auto-slash formatting to the text field inside DatePickerDialog
class _AutoSlashDatePickerWrapper extends StatefulWidget {
  final Widget child;
  const _AutoSlashDatePickerWrapper({required this.child});

  @override
  State<_AutoSlashDatePickerWrapper> createState() => _AutoSlashDatePickerWrapperState();
}

class _AutoSlashDatePickerWrapperState extends State<_AutoSlashDatePickerWrapper> {
  TextEditingController? _activeController;
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachListener());
  }

  void _attachListener() {
    if (!mounted) return;
    void searchAndAttach(Element element) {
      if (element.widget is TextField) {
        final textField = element.widget as TextField;
        if (textField.controller != null && textField.controller != _activeController) {
          _activeController?.removeListener(_onTextChanged);
          _activeController = textField.controller;
          _activeController?.addListener(_onTextChanged);
        }
      }
      element.visitChildren(searchAndAttach);
    }

    try {
      context.visitChildElements(searchAndAttach);
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _attachListener();
    });
  }

  void _onTextChanged() {
    if (_isFormatting || _activeController == null) return;
    final text = _activeController!.text;
    if (text.isEmpty) return;

    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      if (text != '') {
        _isFormatting = true;
        _activeController!.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
        _isFormatting = false;
      }
      return;
    }

    String formatted = '';
    if (digitsOnly.length <= 2) {
      formatted = digitsOnly;
    } else if (digitsOnly.length <= 4) {
      formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
    } else {
      formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, 4)}/${digitsOnly.substring(4)}';
    }

    if (formatted.length > 10) {
      formatted = formatted.substring(0, 10);
    }

    if (formatted != text) {
      _isFormatting = true;
      _activeController!.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isFormatting = false;
    }
  }

  @override
  void dispose() {
    _activeController?.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Centralized Date Picker helper that enforces DD/MM/YYYY format globally
/// across calendar and text input modes.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  Locale? locale,
}) async {
  final now = DateTime.now();
  final effectiveInitial = initialDate ?? now;
  final effectiveFirst = firstDate ?? DateTime(1920);
  final effectiveLast = lastDate ?? DateTime(now.year + 10);

  final safeInitial = effectiveInitial.isBefore(effectiveFirst)
      ? effectiveFirst
      : (effectiveInitial.isAfter(effectiveLast) ? effectiveLast : effectiveInitial);

  return await showDatePicker(
    context: context,
    initialDate: safeInitial,
    firstDate: effectiveFirst,
    lastDate: effectiveLast,
    initialEntryMode: initialEntryMode,
    selectableDayPredicate: selectableDayPredicate,
    locale: locale ?? const Locale('en', 'GB'),
    builder: (context, child) {
      return Localizations.override(
        context: context,
        delegates: const [
          AppMaterialLocalizationsDelegate(),
        ],
        child: _AutoSlashDatePickerWrapper(
          child: child ?? const SizedBox(),
        ),
      );
    },
  );
}
