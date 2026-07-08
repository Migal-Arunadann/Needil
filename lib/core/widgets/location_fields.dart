import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/theme/app_theme.dart';


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

    // ── Try primary API (India Post) with retry ──
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final http.Response res;
        if (kIsWeb) {
          res = await http.get(
            Uri.parse('https://api.postalpincode.in/pincode/$pin'),
          ).timeout(const Duration(seconds: 12));
        } else {
          final innerClient = HttpClient()
            ..badCertificateCallback = (X509Certificate cert, String host, int port) {
              return host == 'api.postalpincode.in';
            };
          final client = IOClient(innerClient);
          res = await client.get(
            Uri.parse('https://api.postalpincode.in/pincode/$pin'),
          ).timeout(const Duration(seconds: 12));
          client.close();
        }

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

              final areas = offices
                  .map((o) => (o as Map)['Name']?.toString() ?? '')
                  .where((n) => n.isNotEmpty)
                  .toSet()
                  .toList();
              areas.sort();

              widget.countryCtrl.text = country;
              widget.stateCtrl.text = state;
              widget.cityCtrl.text = district;
              if (widget.areaCtrl.text.isEmpty && areas.isNotEmpty) {
                widget.areaCtrl.text = areas.first;
              }
              setState(() { _areaOptions = areas; _isLookingUp = false; });
              return;
            }
          }
          // API responded but pincode not found — try fallback
          break;
        }
        // Non-200 status — retry
        if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
      } catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        break;
      }
    }

    // ── Fallback API (zippopotam.us) ──
    try {
      final res = await http.get(
        Uri.parse('https://api.zippopotam.us/in/$pin'),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final places = data['places'] as List?;
        if (places != null && places.isNotEmpty) {
          final first = places[0] as Map<String, dynamic>;
          final state = first['state'] as String? ?? '';
          final placeName = first['place name'] as String? ?? '';
          final country = data['country'] as String? ?? 'India';

          final areas = places
              .map((p) => (p as Map)['place name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toSet()
              .toList();
          areas.sort();

          widget.countryCtrl.text = country;
          widget.stateCtrl.text = state;
          widget.cityCtrl.text = placeName;
          if (widget.areaCtrl.text.isEmpty && areas.isNotEmpty) {
            widget.areaCtrl.text = areas.first;
          }
          setState(() { _areaOptions = areas; _isLookingUp = false; });
          return;
        }
      }

      // Fallback also failed
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = 'Pincode not found. Please fill manually.';
        });
      }
    } on SocketException {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = 'No internet connection. Please fill manually.';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = 'Request timed out. Please fill manually.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupError = 'Could not look up pincode. Please fill manually.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIndian = widget.countryCtrl.text.trim().isEmpty ||
        widget.countryCtrl.text.trim() == 'India';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        final pincodeField = Stack(
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
              prefixIcon: Icon(Icons.pin_drop_rounded,
                  color: context.colors.textHint),
              validator: widget.allRequired
                  ? (v) => (v == null || v.trim().isEmpty)
                      ? 'Pincode is required'
                      : null
                  : null,
              textInputAction: TextInputAction.next,
            ),
            if (_isLookingUp)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: context.colors.primary, strokeWidth: 2),
                ),
              ),
          ],
        );

        final pincodeSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            pincodeField,
            if (_lookupError != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _lookupError!,
                  style: context.textStyles.caption
                      .copyWith(color: context.colors.warning, fontSize: 11),
                ),
              ),
            ],
          ],
        );

        final countryField = _DropdownField(
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
        );

        final stateField = isIndian
            ? _DropdownField(
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
            : AppTextField(
                controller: widget.stateCtrl,
                label: widget.allRequired ? 'State / Province *' : 'State / Province',
                prefixIcon: Icon(Icons.flag_rounded, color: context.colors.textHint),
                validator: widget.allRequired
                    ? (v) => (v == null || v.trim().isEmpty) ? 'State is required' : null
                    : null,
                textInputAction: TextInputAction.next,
              );

        final cityField = AppTextField(
          controller: widget.cityCtrl,
          label: widget.allRequired ? 'City / District *' : 'City / District',
          prefixIcon: Icon(Icons.location_city_rounded,
              color: context.colors.textHint),
          validator: widget.allRequired
              ? (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null
              : null,
          textInputAction: TextInputAction.next,
        );

        final areaField = _areaOptions.isNotEmpty
            ? _DropdownField(
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
            : AppTextField(
                controller: widget.areaCtrl,
                label: widget.allRequired ? 'Area / Locality *' : 'Area / Locality',
                prefixIcon: Icon(Icons.map_rounded, color: context.colors.textHint),
                validator: widget.allRequired
                    ? (v) => (v == null || v.trim().isEmpty) ? 'Area is required' : null
                    : null,
                textInputAction: TextInputAction.next,
              );

        if (isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: pincodeSection),
                  const SizedBox(width: 16),
                  Expanded(child: countryField),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: stateField),
                  const SizedBox(width: 16),
                  Expanded(child: cityField),
                  const SizedBox(width: 16),
                  Expanded(child: areaField),
                ],
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pincodeSection,
              const SizedBox(height: 14),
              countryField,
              const SizedBox(height: 14),
              stateField,
              const SizedBox(height: 14),
              cityField,
              const SizedBox(height: 14),
              areaField,
            ],
          );
        }
      },
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      final textDark = const Color(0xFF161616);
      final border = const Color(0xFFE8E6E2);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: border,
                width: 1,
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: const Color(0xFF999999), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: textDark,
              ),
              dropdownColor: Colors.white,
              isExpanded: true,
              hint: Text('Select', style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFFA0A0A0))),
              validator: required
                  ? (v) => (v == null || v.isEmpty) ? '$label is required' : null
                  : null,
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item, style: GoogleFonts.inter(fontSize: 15, color: textDark)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.textStyles.caption.copyWith(color: context.colors.textHint),
        prefixIcon: Icon(icon, color: context.colors.textHint, size: 20),
        filled: true,
        fillColor: context.colors.surface,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.error),
        ),
      ),
      style: context.textStyles.bodyMedium,
      dropdownColor: context.colors.surface,
      isExpanded: true,
      hint: Text('Select', style: context.textStyles.caption.copyWith(color: context.colors.textHint)),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? '$label is required' : null
          : null,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: context.textStyles.bodyMedium),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
