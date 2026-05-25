import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'package:pms_app/core/theme/app_theme.dart';


// ─── Natural dimensions to keep aspect ratio ──────────────────────────────
const double _imgW = 450;
const double _imgH = 450;

/// Exact outer silhouette of the FRONT body extracted mathematically from the image.
const List<List<double>> _frontSilhouette = [
  [0.22666666666666666, 0.03333333333333333], [0.2, 0.051111111111111114], [0.18444444444444444, 0.09333333333333334], 
  [0.21333333333333335, 0.1511111111111111], [0.14222222222222222, 0.19111111111111112], [0.12444444444444444, 0.21777777777777776], 
  [0.08444444444444445, 0.45555555555555555], [0.04, 0.5111111111111111], [0.05555555555555555, 0.5177777777777778], 
  [0.04888888888888889, 0.5466666666666666], [0.10222222222222223, 0.5488888888888889], [0.16444444444444445, 0.31777777777777777], 
  [0.14888888888888888, 0.5355555555555556], [0.2, 0.8577777777777778], [0.17555555555555555, 0.9444444444444444], 
  [0.21777777777777776, 0.9644444444444444], [0.2288888888888889, 0.9377777777777778], [0.24444444444444444, 0.5711111111111111], 
  [0.24888888888888888, 0.8777777777777778], [0.26, 0.9511111111111111], [0.2733333333333333, 0.9644444444444444], 
  [0.3111111111111111, 0.9444444444444444], [0.2866666666666667, 0.8555555555555555], [0.34, 0.5133333333333333], 
  [0.32222222222222224, 0.31777777777777777], [0.3844444444444444, 0.5488888888888889], [0.43777777777777777, 0.5466666666666666], 
  [0.4311111111111111, 0.5177777777777778], [0.44666666666666666, 0.5133333333333333], [0.4022222222222222, 0.45555555555555555], 
  [0.3622222222222222, 0.21777777777777776], [0.3422222222222222, 0.18888888888888888], [0.2733333333333333, 0.1511111111111111], 
  [0.3, 0.1111111111111111], [0.2822222222222222, 0.04888888888888889]
];

/// Exact outer silhouette of the BACK body extracted mathematically from the image.
const List<List<double>> _backSilhouette = [
  [0.7355555555555555, 0.03333333333333333], [0.7111111111111111, 0.04888888888888889], [0.6933333333333334, 0.09333333333333334], 
  [0.7177777777777777, 0.15555555555555556], [0.6466666666666666, 0.19111111111111112], [0.6288888888888889, 0.21555555555555556], 
  [0.5866666666666667, 0.46], [0.5444444444444444, 0.5155555555555555], [0.56, 0.5177777777777778], [0.5533333333333333, 0.5466666666666666], 
  [0.6066666666666667, 0.5488888888888889], [0.6666666666666666, 0.32], [0.6511111111111111, 0.5222222222222223], 
  [0.7022222222222222, 0.8488888888888889], [0.68, 0.9466666666666667], [0.7177777777777777, 0.9644444444444444], 
  [0.7333333333333333, 0.9355555555555556], [0.7511111111111111, 0.5422222222222223], [0.7622222222222222, 0.6577777777777778], 
  [0.7577777777777778, 0.8755555555555555], [0.7711111111111111, 0.9577777777777777], [0.7822222222222223, 0.9644444444444444], 
  [0.82, 0.9466666666666667], [0.7977777777777778, 0.8466666666666667], [0.8488888888888889, 0.5133333333333333], 
  [0.8311111111111111, 0.31777777777777777], [0.8933333333333333, 0.5488888888888889], [0.9466666666666667, 0.5466666666666666], 
  [0.94, 0.5177777777777778], [0.9555555555555556, 0.5111111111111111], [0.9133333333333333, 0.4622222222222222], 
  [0.8688888888888889, 0.21333333333333335], [0.8488888888888889, 0.18888888888888888], [0.78, 0.15555555555555556], 
  [0.8066666666666666, 0.10888888888888888], [0.7933333333333333, 0.057777777777777775], [0.7711111111111111, 0.035555555555555556]
];

/// Precision hit zones expressed as polygons. Used for both hit-testing and filling red.
const Map<String, List<List<double>>> _zonePolygons = {
  // ── FRONT ───────────────────────────
  'Head': [
    [0.235, 0.03], [0.28, 0.05], [0.29, 0.09], [0.28, 0.13], 
    [0.235, 0.14], [0.19, 0.13], [0.18, 0.09], [0.19, 0.05]
  ],
  'Neck/Shoulder': [
    [0.20, 0.13], [0.27, 0.13], [0.32, 0.15], [0.37, 0.19], 
    [0.38, 0.22], [0.09, 0.22], [0.10, 0.19], [0.15, 0.15]
  ],
  'Chest': [
    [0.09, 0.22], [0.38, 0.22], [0.35, 0.30], [0.33, 0.38], 
    [0.14, 0.38], [0.12, 0.30]
  ],
  'Ribs/Abdomen': [
    [0.14, 0.38], [0.33, 0.38], [0.31, 0.45], [0.32, 0.53], 
    [0.15, 0.53], [0.16, 0.45]
  ],
  'Hip/Pelvis': [
    [0.15, 0.53], [0.32, 0.53], [0.34, 0.58], [0.32, 0.62], 
    [0.235, 0.63], [0.15, 0.62], [0.13, 0.58]
  ],
  'Left Arm': [
    [0.09, 0.22], [0.12, 0.22], [0.11, 0.35], [0.10, 0.45], 
    [0.08, 0.61], [0.04, 0.61], [0.05, 0.45], [0.06, 0.35]
  ],
  'Right Arm': [
    [0.38, 0.22], [0.35, 0.22], [0.36, 0.35], [0.37, 0.45], 
    [0.39, 0.61], [0.43, 0.61], [0.42, 0.45], [0.41, 0.35]
  ],
  'Left Hand': [
    [0.04, 0.61], [0.08, 0.61], [0.10, 0.65], [0.09, 0.70], 
    [0.05, 0.70], [0.02, 0.66]
  ],
  'Right Hand': [
    [0.43, 0.61], [0.39, 0.61], [0.37, 0.65], [0.38, 0.70], 
    [0.42, 0.70], [0.45, 0.66]
  ],
  'Left Thigh': [
    [0.15, 0.62], [0.23, 0.63], [0.21, 0.70], [0.18, 0.76], 
    [0.13, 0.76], [0.13, 0.70]
  ],
  'Right Thigh': [
    [0.32, 0.62], [0.24, 0.63], [0.26, 0.70], [0.29, 0.76], 
    [0.34, 0.76], [0.34, 0.70]
  ],
  'Left Knee': [
    [0.13, 0.76], [0.18, 0.76], [0.18, 0.81], [0.13, 0.81]
  ],
  'Right Knee': [
    [0.34, 0.76], [0.29, 0.76], [0.29, 0.81], [0.34, 0.81]
  ],
  'Left Calf': [
    [0.13, 0.81], [0.18, 0.81], [0.19, 0.88], [0.17, 0.93], 
    [0.18, 0.96], [0.13, 0.96], [0.15, 0.93], [0.14, 0.88]
  ],
  'Right Calf': [
    [0.34, 0.81], [0.29, 0.81], [0.28, 0.88], [0.30, 0.93], 
    [0.29, 0.96], [0.34, 0.96], [0.32, 0.93], [0.33, 0.88]
  ],

  // ── BACK ────────────────────────────
  'Neck (Back)': [
    [0.72, 0.13], [0.79, 0.13], [0.84, 0.15], [0.89, 0.19], 
    [0.90, 0.22], [0.61, 0.22], [0.62, 0.19], [0.67, 0.15]
  ],
  'Upper Back': [
    [0.61, 0.22], [0.90, 0.22], [0.87, 0.30], [0.85, 0.38], 
    [0.66, 0.38], [0.64, 0.30]
  ],
  'Lower Back': [
    [0.66, 0.38], [0.85, 0.38], [0.83, 0.45], [0.84, 0.53], 
    [0.67, 0.53], [0.68, 0.45]
  ],
  'Hip (Back)': [
    [0.67, 0.53], [0.84, 0.53], [0.86, 0.58], [0.84, 0.62], 
    [0.755, 0.63], [0.67, 0.62], [0.65, 0.58]
  ],
  'Left Arm (B)': [
    [0.610, 0.22], [0.640, 0.22], [0.630, 0.35], [0.620, 0.45], 
    [0.600, 0.61], [0.560, 0.61], [0.570, 0.45], [0.580, 0.35]
  ],
  'Right Arm (B)': [
    [0.900, 0.22], [0.870, 0.22], [0.880, 0.35], [0.890, 0.45], 
    [0.910, 0.61], [0.950, 0.61], [0.940, 0.45], [0.930, 0.35]
  ],
  'Left Hand (B)': [
    [0.560, 0.61], [0.600, 0.61], [0.620, 0.65], [0.610, 0.70], 
    [0.570, 0.70], [0.540, 0.66]
  ],
  'Right Hand (B)': [
    [0.950, 0.61], [0.910, 0.61], [0.890, 0.65], [0.900, 0.70], 
    [0.940, 0.70], [0.970, 0.66]
  ],
  'Left Thigh (B)': [
    [0.670, 0.62], [0.750, 0.63], [0.730, 0.70], [0.700, 0.76], 
    [0.650, 0.76], [0.650, 0.70]
  ],
  'Right Thigh (B)': [
    [0.840, 0.62], [0.760, 0.63], [0.780, 0.70], [0.810, 0.76], 
    [0.860, 0.76], [0.860, 0.70]
  ],
  'Left Knee (B)': [
    [0.650, 0.76], [0.700, 0.76], [0.700, 0.81], [0.650, 0.81]
  ],
  'Right Knee (B)': [
    [0.860, 0.76], [0.810, 0.76], [0.810, 0.81], [0.860, 0.81]
  ],
  'Left Calf (B)': [
    [0.650, 0.81], [0.700, 0.81], [0.710, 0.88], [0.690, 0.93], 
    [0.700, 0.96], [0.650, 0.96], [0.670, 0.93], [0.660, 0.88]
  ],
  'Right Calf (B)': [
    [0.860, 0.81], [0.810, 0.81], [0.800, 0.88], [0.820, 0.93], 
    [0.810, 0.96], [0.860, 0.96], [0.840, 0.93], [0.850, 0.88]
  ],
  'Head (Back)': [
    [0.755, 0.03], [0.80, 0.05], [0.81, 0.09], [0.80, 0.13], 
    [0.755, 0.14], [0.71, 0.13], [0.70, 0.09], [0.71, 0.05]
  ]
};

/// Maps chip labels → zone keys
const Map<String, List<String>> _chipToZones = {
  'Head'         : ['Head', 'Head (Back)'],
  'Neck/Shoulder': ['Neck/Shoulder', 'Neck (Back)'],
  'Chest'        : ['Chest'],
  'Ribs/Abdomen' : ['Ribs/Abdomen'],
  'Upper Back'   : ['Upper Back'],
  'Lower Back'   : ['Lower Back'],
  'Hip/Pelvis'   : ['Hip/Pelvis', 'Hip (Back)'],
  'Left Arm'     : ['Left Arm', 'Left Arm (B)'],
  'Right Arm'    : ['Right Arm', 'Right Arm (B)'],
  'Left Hand'    : ['Left Hand', 'Left Hand (B)'],
  'Right Hand'   : ['Right Hand', 'Right Hand (B)'],
  'Joints'       : ['Left Knee', 'Right Knee', 'Left Knee (B)', 'Right Knee (B)'],
  'Muscle'       : ['Left Thigh', 'Right Thigh', 'Left Calf', 'Right Calf',
                    'Left Thigh (B)', 'Right Thigh (B)', 'Left Calf (B)', 'Right Calf (B)'],
  'No Pain'      : [],
  'Other'        : [],
};

String _chipFor(String zoneName) {
  for (final e in _chipToZones.entries) {
    if (e.value.contains(zoneName)) return e.key;
  }
  return zoneName;
}

// ─── Widget ────────────────────────────────────────────────────────────────────

class InteractivePainBody extends StatefulWidget {
  final List<String> selectedAreas;
  final Function(List<String>) onChanged;

  const InteractivePainBody({
    super.key,
    required this.selectedAreas,
    required this.onChanged,
  });

  @override
  State<InteractivePainBody> createState() => _InteractivePainBodyState();
}

class _InteractivePainBodyState extends State<InteractivePainBody> {

  void _toggleChip(String chip) {
    final current = List<String>.from(widget.selectedAreas);
    if (chip == 'No Pain') { widget.onChanged(['No Pain']); return; }
    current.remove('No Pain');
    if (current.contains(chip)) {
      current.remove(chip);
    } else {
      current.add(chip);
    }
    widget.onChanged(current);
  }

  Set<String> get _activeZones {
    final out = <String>{};
    for (final chip in widget.selectedAreas) {
      out.addAll(_chipToZones[chip] ?? []);
    }
    return out;
  }

  /// Compute the rendered image rect inside the container (BoxFit.contain).
  Rect _imageRect(double cW, double cH) {
    final scale = (cW / _imgW) < (cH / _imgH) ? cW / _imgW : cH / _imgH;
    final rW = _imgW * scale;
    final rH = _imgH * scale;
    return Rect.fromLTWH((cW - rW) / 2, (cH - rH) / 2, rW, rH);
  }

  Path _buildPath(List<List<double>> points, Rect imgRect) {
    final path = Path();
    if (points.isEmpty) return path;
    
    path.moveTo(
      imgRect.left + points[0][0] * imgRect.width,
      imgRect.top + points[0][1] * imgRect.height,
    );
    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        imgRect.left + points[i][0] * imgRect.width,
        imgRect.top + points[i][1] * imgRect.height,
      );
    }
    path.close();
    return path;
  }

  void _onTap(Offset local, double cW, double cH) {
    final imgRect = _imageRect(cW, cH);
    if (!imgRect.contains(local)) return;

    for (final entry in _zonePolygons.entries) {
      final path = _buildPath(entry.value, imgRect);
      if (path.contains(local)) {
        _toggleChip(_chipFor(entry.key));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(builder: (ctx, constraints) {
            final cW = constraints.maxWidth;
            final containerH = cW; // square container matches 450×450 image
            final imgRect = _imageRect(cW, containerH);
            final activeZones = _activeZones;

            return GestureDetector(
              onTapUp: (d) => _onTap(d.localPosition, cW, containerH),
              child: SizedBox(
                width: cW,
                height: containerH,
                child: CustomPaint(
                  size: Size(cW, containerH),
                  painter: _VectorBodyPainter(
                    zonePolygons: _zonePolygons,
                    frontSilhouette: _frontSilhouette,
                    backSilhouette: _backSilhouette,
                    activeZones: activeZones,
                    imgRect: imgRect,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // ── Chips ──
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _chipToZones.keys.map(_buildChip).toList(),
        ),
      ],
    );
  }

  Widget _buildChip(String label) {
    final isSelected = widget.selectedAreas.contains(label);
    final isNoPain = label == 'No Pain';
    final col = isNoPain ? context.colors.success : context.colors.error;
    return GestureDetector(
      onTap: () => _toggleChip(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? col.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? col : context.colors.border,
            width: 1.5,
          ),
        ),
        child: Text(label,
          style: context.textStyles.bodyMedium.copyWith(
            fontSize: 12,
            color: isSelected ? col : context.colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Vector Body Painter ────────────────────────────────────────────────────────────

class _VectorBodyPainter extends CustomPainter {
  final Map<String, List<List<double>>> zonePolygons;
  final List<List<double>> frontSilhouette;
  final List<List<double>> backSilhouette;
  final Set<String> activeZones;
  final Rect imgRect;

  const _VectorBodyPainter({
    required this.zonePolygons,
    required this.frontSilhouette,
    required this.backSilhouette,
    required this.activeZones,
    required this.imgRect,
  });

  Path _buildPath(List<List<double>> points) {
    final path = Path();
    if (points.isEmpty) return path;
    
    path.moveTo(
      imgRect.left + points[0][0] * imgRect.width,
      imgRect.top + points[0][1] * imgRect.height,
    );
    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        imgRect.left + points[i][0] * imgRect.width,
        imgRect.top + points[i][1] * imgRect.height,
      );
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Get the exact outer contour paths
    final frontPath = _buildPath(frontSilhouette);
    final backPath = _buildPath(backSilhouette);

    // Combine them into one master clipping/drawing path
    final silhouettePath = Path()
      ..addPath(frontPath, Offset.zero)
      ..addPath(backPath, Offset.zero);

    // 2. Draw the interior zones and highlights
    // We clip to the exact silhouette first, guaranteeing the red highlights
    // NEVER bleed outside the 1-to-1 shape.
    canvas.save();
    canvas.clipPath(silhouettePath);

    final highlightFill = Paint()
      ..color = Colors.red.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    // Draw the internal anatomy dividers (thin grey lines forming the body parts)
    final internalStroke = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final entry in zonePolygons.entries) {
      final path = _buildPath(entry.value);
      
      // The internal dividing lines mapping out the anatomy
      canvas.drawPath(path, internalStroke);

      // The active red highlight
      if (activeZones.contains(entry.key)) {
        canvas.drawPath(path, highlightFill);
      }
    }

    canvas.restore(); // Remove clip so we can draw the thick black outer border

    // 3. Draw the exact 1-to-1 black outer silhouette over the top
    final outerStroke = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(frontPath, outerStroke);
    canvas.drawPath(backPath, outerStroke);
  }

  @override
  bool shouldRepaint(_VectorBodyPainter old) =>
      old.activeZones != activeZones || old.imgRect != imgRect;
}
