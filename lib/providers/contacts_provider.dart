import 'package:flutter/foundation.dart';
import '../models/emergency_contact.dart';
import '../services/storage_service.dart';
import '../core/constants.dart';
import 'package:uuid/uuid.dart';

class ContactsProvider extends ChangeNotifier {
  List<EmergencyContact> _contacts = [];
  final _uuid = const Uuid();

  List<EmergencyContact> get contacts => _contacts;
  int get count => _contacts.length;
  bool get hasContacts => _contacts.isNotEmpty;
  bool get canAddMore => _contacts.length < AppConstants.maxEmergencyContacts;

  ContactsProvider() {
    _loadContacts();
  }

  void _loadContacts() {
    _contacts = StorageService.getContacts();
    notifyListeners();
  }

  Future<bool> addContact(String name, String phoneNumber) async {
    if (!canAddMore) return false;
    if (name.trim().isEmpty || phoneNumber.trim().isEmpty) return false;

    final contact = EmergencyContact(
      id: _uuid.v4(),
      name: name.trim(),
      phoneNumber: phoneNumber.trim(),
    );

    await StorageService.addContact(contact);
    _contacts.add(contact);
    notifyListeners();
    return true;
  }

  Future<void> updateContact(String id, String name, String phoneNumber) async {
    final index = _contacts.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final updatedContact = _contacts[index].copyWith(
      name: name.trim(),
      phoneNumber: phoneNumber.trim(),
    );

    await StorageService.updateContact(updatedContact);
    _contacts[index] = updatedContact;
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    await StorageService.deleteContact(id);
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void refresh() {
    _loadContacts();
  }
}
