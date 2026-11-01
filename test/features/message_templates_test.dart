import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/data/firestore/message_templates_repository.dart';
import 'package:workflow/domain/entities/guest_entity.dart';
import 'package:workflow/domain/message_templates.dart';
import 'package:workflow/presentation/common/whatsapp_sheet.dart';

GuestEntity guest({String gender = 'Female', String name = 'Ada Obi', String service = '2026-10-25'}) => GuestEntity(
      id: 'G1',
      name: name,
      phone: '0803 123 4567',
      gender: gender,
      status: 'New guest',
      daysSinceVisit: 0,
      serviceDate: service,
      callCount: 0,
      sundayAttendance: 0,
      wednesdayAttendance: 0,
      teamJoined: '',
      lastFeedback: '',
      lastFeedbackDate: '',
      followUpCount: 0,
      month: service.substring(0, 7),
    );

void main() {
  final clock = DateTime.utc(2026, 11, 1, 10);

  group('Default wording', () {
    test('the three defaults, word for word', () {
      expect(MessageTemplates.defaults['thanks'],
          "Dear {title} {name}, I'm reaching out to you from Pastor Ayo. He asked me to send you his love and to thank you for coming. How was the service, and how was your experience? We love and celebrate you. {worker}, COZA Ilorin");
      expect(MessageTemplates.defaults['missedCall'],
          'Dear {title} {name}, I tried calling you earlier but could not reach you, so I decided to message you. Pastor Ayo sends his love and thanks you for worshipping with us. How was the service, and how was your experience? We love and celebrate you. {worker}, COZA Ilorin');
      expect(MessageTemplates.defaults['checkIn'],
          'Dear {title} {name}, this is {worker} from COZA Ilorin. We have been thinking of you since {service}. How have you been, and can we expect you this Sunday? We love and celebrate you.');
    });

    test('a saved template replaces its default; a missing or blank one keeps it', () {
      final list = MessageTemplates.from({'thanks': 'Hello {name}', 'missedCall': '   '});
      expect(list.map((t) => t.id), ['thanks', 'missedCall', 'checkIn']);
      expect(list[0].text, 'Hello {name}');
      expect(list[1].text, MessageTemplates.defaults['missedCall']);
      expect(list[2].text, MessageTemplates.defaults['checkIn']);
    });
  });

  group('Placeholders', () {
    test('{title} is sis for a woman and bro for a man', () {
      final t = MessageTemplates.defaults['checkIn']!;
      expect(MessageTemplates.forGuest(t, guest(), workerName: 'David Olanite', clock: clock),
          'Dear sis Ada, this is David Olanite from COZA Ilorin. We have been thinking of you since Sunday 25 October. How have you been, and can we expect you this Sunday? We love and celebrate you.');
      expect(MessageTemplates.forGuest('Dear {title} {name},', guest(gender: 'Male', name: 'Tunde Bello'), workerName: 'D'),
          'Dear bro Tunde,');
    });

    test('{title} is left out cleanly when gender is missing', () {
      expect(MessageTemplates.forGuest('Dear {title} {name}, hi', guest(gender: ''), workerName: 'D'), 'Dear Ada, hi');
      expect(MessageTemplates.fill('{title} {name}', gender: 'unknown', name: 'Ada', worker: '', service: ''), 'Ada');
    });

    test('{worker} and {service} are filled', () {
      final out = MessageTemplates.forGuest(MessageTemplates.defaults['thanks']!, guest(), workerName: ' David Olanite ');
      expect(out, endsWith('We love and celebrate you. David Olanite, COZA Ilorin'));
      expect(out, isNot(contains('{')));
      expect(MessageTemplates.forGuest('{service}', guest(service: '2026-10-28'), workerName: '', clock: clock),
          'Wednesday 28 October');
    });
  });

  group('wa.me link', () {
    test('the text is URL-encoded, including apostrophes, commas, question marks and line breaks', () {
      final link = MessageTemplates.whatsAppLink(guest(), "I'm here, how are you?\nSee you & God bless");
      expect(link, startsWith('https://wa.me/2348031234567?text='));
      final text = link.substring(link.indexOf('?text=') + 6);
      expect(text, isNot(contains(' ')));
      expect(text, isNot(contains('&')));
      expect(text, isNot(contains('?')));
      expect(text, contains('%0A'));
      expect(Uri.decodeComponent(text), "I'm here, how are you?\nSee you & God bless");
      expect(Uri.parse(link).queryParameters['text'], "I'm here, how are you?\nSee you & God bless");
    });
  });

  group('API mode', () {
    test('defaults, not editable', () async {
      const repo = DefaultMessageTemplatesRepository();
      expect(repo.canEdit, isFalse);
      expect((await repo.watch().first).map((t) => t.text), MessageTemplates.defaults.values);
      expect((await repo.save({})).isFailure, isTrue);
    });
  });

  group('WhatsAppSheet', () {
    testWidgets('lists each template filled for the guest and sends the one tapped', (tester) async {
      final sent = <String?>[];
      final templates = StreamController<List<MessageTemplate>>();
      await tester.pumpWidget(ScreenUtilInit(
        designSize: AppSizes.designSize,
        builder: (_, __) => GetMaterialApp(
          home: Scaffold(
            body: WhatsAppSheet(guest: guest(), workerName: 'David Olanite', templates: templates.stream, onSend: sent.add),
          ),
        ),
      ));
      expect(find.text('Thank you for coming'), findsOneWidget);
      expect(find.text('After a missed call'), findsOneWidget);
      expect(find.text('Checking in'), findsOneWidget);
      expect(find.textContaining('Dear sis Ada, I tried calling you earlier'), findsOneWidget);

      // The HOD's wording arrives live.
      templates.add(MessageTemplates.from({'thanks': 'Hi {title} {name}, from {worker}.'}));
      await tester.pump();
      expect(find.text('Hi sis Ada, from David Olanite.'), findsOneWidget);

      await tester.tap(find.text('Hi sis Ada, from David Olanite.'));
      await tester.scrollUntilVisible(find.text('Open WhatsApp without a message'), 200);
      await tester.tap(find.text('Open WhatsApp without a message'));
      expect(sent, ['Hi sis Ada, from David Olanite.', null]);
      await templates.close();
    });
  });
}
