import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'app_text_field.dart';

/// List of countries for the country dropdown.
const kCountries = [
  'India', 'United States', 'United Kingdom', 'Canada', 'Australia',
  'United Arab Emirates', 'Singapore', 'Germany', 'France', 'Netherlands',
  'New Zealand', 'Saudi Arabia', 'Qatar', 'Bahrain', 'Kuwait', 'Nepal',
  'Sri Lanka', 'Bangladesh', 'Pakistan', 'Malaysia', 'Others',
];

/// Indian states for the state dropdown.
const kIndianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
  'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
  'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
  'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Ladakh',
  'Lakshadweep', 'Puducherry',
];

/// Reusable location form widget.
/// Order: Pincode → Country → State → City → Area
/// Entering a 6-digit pincode auto-fills country/state/city/area via India Post API.
class LocationFields extends StatefulWidget {
  final TextEditingController pincodeCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController areaCtrl;

  /// Whether all fields (except maybe area) are mandatory.
  final bool allRequired;

  const LocationFields({
    super.key,
    required this.pincodeCtrl,
    required this.countryCtrl,
    required this.stateCtrl,
    required this.cityCtrl,
    required this.areaCtrl,
    this.allRequired = true,
  });

  @override
  State<LocationFields> createState() => _LocationFieldsState();
}

class _LocationFieldsState extends State<LocationFields> {
  bool _isLookingUp = false;
  String? _lookupError;

  // Available areas from pincode lookup (multiple post offices in same pin)
  List<String> _areaOptions = [];

  @override
  void initState() {
    super.initState();
    widget.pincodeCtrl.addListener(_onPincodeChanged);
  }

  @override
  void dispose() {
    widget.pincodeCtrl.removeListener(_onPincodeChanged);
    super.dispose();
  }

  void _onPincodeChanged() {
    final pin = widget.pincodeCtrl.text.trim();
    if (pin.length == 6 && RegExp(r'^\d{6}$').hasMatch(pin)) {
      _lookupPincode(pin);
    } else {
      setState(() { _lookupError = null; _areaOptions = []; });
    }
  }

  Future<void> _lookupPincode(String pin) async {
    setState(() { _isLookingUp = true; _lookupError = null; });
    try {
      final res = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pin'),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final offices = data[0]['PostOffice'] as List;
          if (offices.isNotEmpty) {
            final first = offices[0] as Map<String, dynamic>;
            final state = first['State'] as String? ?? '';
            final district = first['District'] as String? ?? '';
            final country = first['Country'] as String? ?? 'India';

            // Collect all unique locality names
            final areas = offices
                .map((o) => (o as Map)['Name']?.toString() ?? '')
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList();
            areas.sort();

            setState(() {
              _areaOptions = areas;
              _isLookingUp = false;
            });

            widget.countryCtrl.text = country;
            widget.stateCtrl.text = state;
            widget.cityCtrl.text = district;
            // Auto-set area to first option if not already filled
            if (widget.areaCtrl.text.isEmpty && areas.isNotEmpty) {
              widget.areaCtrl.text = areas.first;
            }
            return;
          }
        }
        setState(() {
          _isLookingUp = false;
          _lookupError = 'Pincode not found. Please fill manually.';
        });
      } else {
        setState(() { _isLookingUp = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = 'Network error. Please fill manually.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIndian = widget.countryCtrl.text.trim().isEmpty ||
        widget.countryCtrl.text.trim() == 'India';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Pincode ─────────────────────────────────────────────────
        Stack(
          alignment: Alignment.centerRight,
          children: [
            AppTextField(
              controller: widget.pincodeCtrl,
              label: widget.allRequired ? 'Pincode *' : 'Pincode',
              hint: '6-digit code',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              prefixIcon: const Icon(Icons.pin_drop_rounded,
                  color: AppColors.textHint),
              validator: widget.allRequired
                  ? (v) => (v == null || v.trim().isEmpty)
                      ? 'Pincode is required'
                      : null
                  : null,
              textInputAction: TextInputAction.next,
            ),
            if (_isLookingUp)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
                ),
              ),
          ],
        ),

        if (_lookupError != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _lookupError!,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.warning, fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 14),

        // ── Country dropdown ─────────────────────────────────────────
        _DropdownField(
          label: widget.allRequired ? 'Country *' : 'Country',
          value: widget.countryCtrl.text.isNotEmpty
              ? widget.countryCtrl.text
              : null,
          items: kCountries,
          icon: Icons.public_rounded,
          required: widget.allRequired,
          onChanged: (v) {
            if (v != null) {
              widget.countryCtrl.text = v;
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 14),

        // ── State dropdown (India) or free text ───────────────────────
        if (isIndian)
          _DropdownField(
            label: widget.allRequired ? 'State *' : 'State',
            value: kIndianStates.contains(widget.stateCtrl.text)
                ? widget.stateCtrl.text
                : null,
            items: kIndianStates,
            icon: Icons.flag_rounded,
            required: widget.allRequired,
            onChanged: (v) {
              if (v != null) widget.stateCtrl.text = v;
              setState(() {});
            },
          )
        else
          AppTextField(
            controller: widget.stateCtrl,
            label: widget.allRequired ? 'State / Province *' : 'State / Province',
            prefixIcon: const Icon(Icons.flag_rounded, color: AppColors.textHint),
            validator: widget.allRequired
                ? (v) => (v == null || v.trim().isEmpty) ? 'State is required' : null
                : null,
            textInputAction: TextInputAction.next,
          ),
        const SizedBox(height: 14),

        // ── City ─────────────────────────────────────────────────────
        AppTextField(
          controller: widget.cityCtrl,
          label: widget.allRequired ? 'City / District *' : 'City / District',
          prefixIcon: const Icon(Icons.location_city_rounded,
              color: AppColors.textHint),
          validator: widget.allRequired
              ? (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null
              : null,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // ── Area dropdown if options exist, else free text ────────────
        if (_areaOptions.isNotEmpty)
          _DropdownField(
            label: widget.allRequired ? 'Area / Locality *' : 'Area / Locality',
            value: _areaOptions.contains(widget.areaCtrl.text)
                ? widget.areaCtrl.text
                : (_areaOptions.isNotEmpty ? _areaOptions.first : null),
            items: _areaOptions,
            icon: Icons.map_rounded,
            required: widget.allRequired,
            onChanged: (v) {
              if (v != null) widget.areaCtrl.text = v;
            },
          )
        else
          AppTextField(
            controller: widget.areaCtrl,
            label: widget.allRequired ? 'Area / Locality *' : 'Area / Locality',
            prefixIcon: const Icon(Icons.map_rounded, color: AppColors.textHint),
            validator: widget.allRequired
                ? (v) => (v == null || v.trim().isEmpty) ? 'Area is required' : null
                : null,
            textInputAction: TextInputAction.next,
          ),
      ],
    );
  }
}

/// Internal dropdown field widget.
class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final bool required;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.required,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      style: AppTextStyles.bodyMedium,
      dropdownColor: AppColors.surface,
      isExpanded: true,
      hint: Text('Select', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? '$label is required' : null
          : null,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: AppTextStyles.bodyMedium),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
