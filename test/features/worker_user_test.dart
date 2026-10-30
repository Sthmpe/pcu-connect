import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/domain/entities/worker_user.dart';

void main() {
  group('WorkerUser', () {
    test('correctly identifies admin roles', () {
      const admin = WorkerUser(
        id: 'W001',
        name: 'Opeyemi Olanite',
        email: 'olaniteolanight@gmail.com',
        phone: '08000000001',
        role: 'Admin',
        active: true,
      );
      const hod = WorkerUser(
        id: 'W001',
        name: 'Pastor',
        email: 'pastor@gmail.com',
        phone: '08000000002',
        role: 'HOD',
        active: true,
      );
      const worker = WorkerUser(
        id: 'W005',
        name: 'David Olanite',
        email: 'davidolanite0@gmail.com',
        phone: '08000000003',
        role: 'Worker',
        active: true,
      );

      expect(admin.isAdmin, isTrue);
      expect(hod.isAdmin, isTrue);
      expect(worker.isAdmin, isFalse);
    });

    test('serializes and deserializes from JSON', () {
      final json = {
        'id': 'W005',
        'name': 'David Olanite',
        'email': 'davidolanite0@gmail.com',
        'phone': '08000000003',
        'role': 'Worker',
        'active': 'Yes',
      };

      final user = WorkerUser.fromJson(json);
      expect(user.id, 'W005');
      expect(user.name, 'David Olanite');
      expect(user.active, isTrue);
      expect(user.isAdmin, isFalse);
    });
  });
}
