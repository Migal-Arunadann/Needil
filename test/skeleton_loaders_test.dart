import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/shimmer_effect.dart';
import 'package:pms_app/features/dashboard/widgets/dashboard_widgets.dart';

void main() {
  group('Shimmer & Skeleton Loader Tests', () {
    testWidgets('ShimmerEffect renders children and animates without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ShimmerEffect(
              child: Column(
                children: const [
                  SkeletonBox(width: 100, height: 20),
                  SkeletonCircle(size: 40),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerEffect), findsOneWidget);
      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.byType(SkeletonCircle), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('DashboardSkeletonView renders desktop and mobile layouts without overflow', (tester) async {
      // Test desktop layout
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DashboardSkeletonView(isDesktop: true, showBottomCards: true),
            ),
          ),
        ),
      );

      expect(find.byType(DashboardSkeletonView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Test mobile layout
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DashboardSkeletonView(isDesktop: false, showBottomCards: true),
            ),
          ),
        ),
      );

      expect(find.byType(DashboardSkeletonView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
