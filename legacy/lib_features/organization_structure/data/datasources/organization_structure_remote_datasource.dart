import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/firebase_service.dart';
import '../../domain/models/location_model.dart';
import '../../domain/models/organization_model.dart';
import '../../domain/models/unit_model.dart';

class OrganizationStructureRemoteDatasource {
  final FirebaseService _firebaseService;

  OrganizationStructureRemoteDatasource({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;

  Future<OrganizationModel?> getOrganization(String organizationId) async {
    final document = await _firestore
        .collection('organizations')
        .doc(organizationId)
        .get();
    if (!document.exists) return null;
    return OrganizationModel.fromJson(document.id, document.data()!);
  }

  Future<List<LocationModel>> getLocations(String organizationId) async {
    final snapshot = await _firestore
        .collection('locations')
        .where('organizationId', isEqualTo: organizationId)
        .get();
    final locations = snapshot.docs
        .map((document) => LocationModel.fromJson(document.id, document.data()))
        .toList();
    locations.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return locations;
  }

  Future<List<UnitModel>> getUnits(String organizationId) async {
    final snapshot = await _firestore
        .collection('units')
        .where('organizationId', isEqualTo: organizationId)
        .get();
    final units = snapshot.docs
        .map((document) => UnitModel.fromJson(document.id, document.data()))
        .toList();
    units.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return units;
  }

  Future<void> saveOrganization({
    required String organizationId,
    required String name,
    required String code,
  }) async {
    final reference = _firestore
        .collection('organizations')
        .doc(organizationId);
    final existing = await reference.get();
    await reference.set({
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'active': true,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> createLocation({
    required String organizationId,
    required String name,
    required String code,
  }) async {
    final reference = _firestore.collection('locations').doc();
    await reference.set({
      'organizationId': organizationId,
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> updateLocation({
    required String locationId,
    required String name,
    required String code,
  }) {
    return _firestore.collection('locations').doc(locationId).update({
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveLocation(String locationId) {
    return _firestore.collection('locations').doc(locationId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createUnit({
    required String organizationId,
    required String locationId,
    required String name,
    required String code,
  }) async {
    final reference = _firestore.collection('units').doc();
    await reference.set({
      'organizationId': organizationId,
      'locationId': locationId,
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> updateUnit({
    required String unitId,
    required String name,
    required String code,
  }) {
    return _firestore.collection('units').doc(unitId).update({
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveUnit(String unitId) {
    return _firestore.collection('units').doc(unitId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
