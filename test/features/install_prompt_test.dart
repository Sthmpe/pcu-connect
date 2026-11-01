import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/core/constants/app_sizes.dart';
import 'package:workflow/core/install/install_support.dart';
import 'package:workflow/presentation/common/install_prompt_card.dart';
import 'package:workflow/presentation/common/install_prompt_cubit.dart';

class FakeInstall implements InstallSupport {
  @override
  bool isWeb;
  @override
  bool isStandalone;
  @override
  bool canPrompt;
  @override
  InstallPlatform platform;
  bool accept;
  int prompts = 0;
  final installedEvents = StreamController<void>.broadcast();

  FakeInstall({
    this.isWeb = true,
    this.isStandalone = false,
    this.canPrompt = false,
    this.platform = InstallPlatform.iphone,
    this.accept = true,
  });

  @override
  Stream<void> get installed => installedEvents.stream;

  @override
  Future<bool> prompt() async {
    prompts++;
    canPrompt = false;
    return accept;
  }
}

Future<InstallPromptCubit> cubit(FakeInstall support, [Map<String, Object> stored = const {}]) async {
  SharedPreferences.setMockInitialValues(stored);
  return InstallPromptCubit(prefs: await SharedPreferences.getInstance(), support: support);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('hidden until the first successful save, then shown', () async {
    final c = await cubit(FakeInstall());
    expect(c.state.show, isFalse);
    await c.saved();
    expect(c.state.show, isTrue);
    expect(c.state.platform, InstallPlatform.iphone);
  });

  test('never on a phone app build, nor when opened from the Home Screen', () async {
    final notWeb = await cubit(FakeInstall(isWeb: false));
    await notWeb.saved();
    expect(notWeb.state.show, isFalse);
    final standalone = await cubit(FakeInstall(isStandalone: true));
    await standalone.saved();
    expect(standalone.state.show, isFalse);
  });

  test('once dismissed it never returns, even after more saves or a restart', () async {
    final c = await cubit(FakeInstall());
    await c.saved();
    await c.dismiss();
    expect(c.state.show, isFalse);
    await c.saved();
    expect(c.state.show, isFalse);
    final again = await cubit(FakeInstall(), {InstallPromptCubit.readyKey: true, InstallPromptCubit.doneKey: true});
    expect(again.state.show, isFalse);
  });

  test('a restart after the first save still shows it', () async {
    final c = await cubit(FakeInstall(), {InstallPromptCubit.readyKey: true});
    expect(c.state.show, isTrue);
  });

  test('the browser prompt: accepted means gone for good, declined keeps the card', () async {
    final declines = FakeInstall(canPrompt: true, platform: InstallPlatform.android, accept: false);
    final c = await cubit(declines);
    await c.saved();
    expect(c.state.canPrompt, isTrue);
    await c.install();
    expect(declines.prompts, 1);
    expect(c.state.show, isTrue);

    final accepts = FakeInstall(canPrompt: true, platform: InstallPlatform.android);
    final c2 = await cubit(accepts);
    await c2.saved();
    await c2.install();
    expect(c2.state.show, isFalse);
  });

  test('installing from the browser menu hides it for good', () async {
    final support = FakeInstall();
    final c = await cubit(support);
    await c.saved();
    support.installedEvents.add(null);
    await tick();
    await tick();
    expect(c.state.show, isFalse);
  });

  group('The card', () {
    Future<void> show(WidgetTester tester, InstallPromptCubit c) => tester.pumpWidget(ScreenUtilInit(
          designSize: AppSizes.designSize,
          builder: (_, __) => MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: BlocProvider.value(value: c, child: const InstallPromptCard()))),
          ),
        ));

    testWidgets('iPhone steps on an iPhone, and Got it dismisses', (tester) async {
      late InstallPromptCubit c;
      await tester.runAsync(() async {
        c = await cubit(FakeInstall());
        await c.saved();
      });
      await show(tester, c);
      expect(find.text('Add PCU Connect to your Home Screen'), findsOneWidget);
      expect(find.text('On iPhone'), findsOneWidget);
      expect(find.text('On Android'), findsNothing);
      expect(find.text('1. Tap the Share button at the bottom of Safari.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Got it'));
        await tick();
      });
      await tester.pump();
      expect(find.text('Add PCU Connect to your Home Screen'), findsNothing);
    });

    testWidgets('Android with the browser prompt shows one button, no steps', (tester) async {
      late InstallPromptCubit c;
      await tester.runAsync(() async {
        c = await cubit(FakeInstall(canPrompt: true, platform: InstallPlatform.android));
        await c.saved();
      });
      await show(tester, c);
      expect(find.text('Add to Home Screen'), findsOneWidget);
      expect(find.text('On Android'), findsNothing);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('a computer shows both sets of steps', (tester) async {
      late InstallPromptCubit c;
      await tester.runAsync(() async {
        c = await cubit(FakeInstall(platform: InstallPlatform.other));
        await c.saved();
      });
      await show(tester, c);
      expect(find.text('On iPhone'), findsOneWidget);
      expect(find.text('On Android'), findsOneWidget);
    });
  });
}
