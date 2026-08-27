import 'package:flutter_test/flutter_test.dart';
import 'package:pms_app/features/auth/models/clinic_model.dart';

void main() {
  group('ClinicModel Subscription Expiry & Lockout Tests', () {
    test('Active subscription with future end date', () {
      final futureDate = DateTime.now().add(const Duration(days: 15));
      final clinic = ClinicModel(
        id: 'c1',
        name: 'Alpha Clinic',
        username: 'alpha',
        clinicId: 'NDL001',
        bedCount: 5,
        email: 'alpha@test.com',
        phone: '1234567890',
        subscriptionStatus: 'active',
        subscriptionEndDate: futureDate,
      );

      expect(clinic.isSubscriptionActive, isTrue);
      expect(clinic.isInGracePeriod, isFalse);
      expect(clinic.isHardLocked, isFalse);
      expect(clinic.daysUntilExpiration, greaterThanOrEqualTo(14));
    });

    test('Subscription within 3-day grace period is active with isInGracePeriod true', () {
      // Expired 1 day ago (within 3-day grace period)
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final clinic = ClinicModel(
        id: 'c2',
        name: 'Beta Clinic',
        username: 'beta',
        clinicId: 'NDL002',
        bedCount: 5,
        email: 'beta@test.com',
        phone: '1234567890',
        subscriptionStatus: 'active',
        subscriptionEndDate: pastDate,
      );

      expect(clinic.isSubscriptionActive, isTrue, reason: 'Grace period keeps subscription active');
      expect(clinic.isInGracePeriod, isTrue);
      expect(clinic.isHardLocked, isFalse);
      expect(clinic.daysUntilExpiration, lessThan(0));
    });

    test('Subscription past 3-day grace period is hard locked and inactive', () {
      // Expired 4 days ago (beyond 3-day grace period)
      final pastDate = DateTime.now().subtract(const Duration(days: 4));
      final clinic = ClinicModel(
        id: 'c3',
        name: 'Gamma Clinic',
        username: 'gamma',
        clinicId: 'NDL003',
        bedCount: 5,
        email: 'gamma@test.com',
        phone: '1234567890',
        subscriptionStatus: 'active',
        subscriptionEndDate: pastDate,
      );

      expect(clinic.isSubscriptionActive, isFalse);
      expect(clinic.isInGracePeriod, isFalse);
      expect(clinic.isHardLocked, isTrue);
    });

    test('Explicit expired status is inactive and hard locked', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final clinic = ClinicModel(
        id: 'c4',
        name: 'Delta Clinic',
        username: 'delta',
        clinicId: 'NDL004',
        bedCount: 5,
        email: 'delta@test.com',
        phone: '1234567890',
        subscriptionStatus: 'expired',
        subscriptionEndDate: pastDate,
      );

      expect(clinic.isSubscriptionActive, isFalse);
      expect(clinic.isHardLocked, isTrue);
    });

    test('Lifetime access (null end date) is always active', () {
      final clinic = ClinicModel(
        id: 'c5',
        name: 'Epsilon Clinic',
        username: 'epsilon',
        clinicId: 'NDL005',
        bedCount: 5,
        email: 'eps@test.com',
        phone: '1234567890',
        subscriptionStatus: 'active',
        subscriptionEndDate: null,
      );

      expect(clinic.isSubscriptionActive, isTrue);
      expect(clinic.isInGracePeriod, isFalse);
      expect(clinic.isHardLocked, isFalse);
      expect(clinic.daysUntilExpiration, isNull);
    });
  });
}
