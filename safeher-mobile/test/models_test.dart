import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/core/models/contact_model.dart';
import 'package:safeher/core/models/emergency_event_model.dart';
import 'package:safeher/core/models/journey_model.dart';
import 'package:safeher/core/models/checkin_model.dart';
import 'package:safeher/core/models/incident_model.dart';

void main() {
  group('ContactModel Tests', () {
    test('fromJson and toJson should correctly serialize contact data', () {
      final json = {
        'id': 1,
        'contactName': 'Papa',
        'phone': '+919876543210',
        'relationship': 'Father',
        'priority': 1,
        'notifySms': true,
        'notifyPush': true,
        'isVerified': true,
      };

      final contact = ContactModel.fromJson(json);
      expect(contact.id, 1);
      expect(contact.contactName, 'Papa');
      expect(contact.priority, 1);
      expect(contact.isVerified, true);

      final exported = contact.toJson();
      expect(exported['contactName'], 'Papa');
      expect(exported['priority'], 1);
    });
  });

  group('JourneyModel Tests', () {
    test('Remaining duration and progress calculation should be accurate', () {
      final now = DateTime.now();
      final journey = JourneyModel(
        id: 10,
        destination: 'Metro Station',
        durationMinutes: 30,
        startedAt: now.subtract(const Duration(minutes: 15)),
        expectedArrival: now.add(const Duration(minutes: 15)),
        status: 'ACTIVE',
        checkpoints: ['Started at 10:00 AM'],
      );

      expect(journey.isActive, true);
      expect(journey.isCompleted, false);
      expect(journey.remainingDuration.inMinutes, inInclusiveRange(14, 15));
      expect(journey.progressPercentage, inInclusiveRange(0.48, 0.52));
    });
  });

  group('CheckInModel Tests', () {
    test('Status flags and remaining duration should reflect schedule', () {
      final now = DateTime.now();
      final checkin = CheckInModel(
        id: 20,
        intervalMinutes: 45,
        scheduledTime: now.add(const Duration(minutes: 30)),
        status: 'SCHEDULED',
        note: 'Study session',
        createdAt: now,
      );

      expect(checkin.isScheduled, true);
      expect(checkin.isConfirmedSafe, false);
      expect(checkin.remainingDuration.inMinutes, inInclusiveRange(29, 30));
    });
  });

  group('IncidentModel Tests', () {
    test('Incident model should maintain encryption flag and metadata', () {
      final incident = IncidentModel(
        id: 'inc_test_1',
        title: 'Suspicious vehicle',
        description: 'Dark blue car near gate',
        timestamp: DateTime.now(),
        latitude: 28.6139,
        longitude: 77.2090,
        isEncryptedLocally: true,
        isUploaded: false,
      );

      expect(incident.isEncryptedLocally, true);
      expect(incident.isUploaded, false);
      expect(incident.latitude, 28.6139);

      final json = incident.toJson();
      expect(json['id'], 'inc_test_1');
      expect(json['isEncryptedLocally'], true);
    });
  });
}
