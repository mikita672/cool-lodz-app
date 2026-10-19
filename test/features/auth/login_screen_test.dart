import 'dart:async';

import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import 'fakes.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    const LoginScreen(),
    overrides: fakeAuthOverrides(auth: auth),
  );

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
  }

  group('AuthValidation', () {
    test('e-mail', () {
      expect(AuthValidation.isEmail('ania@example.pl'), isTrue);
      expect(AuthValidation.isEmail(' ania@example.pl '), isTrue);
      expect(AuthValidation.isEmail('ania@'), isFalse);
      expect(AuthValidation.isEmail('ania example.pl'), isFalse);
    });

    test('nickname is 2–24 characters', () {
      expect(AuthValidation.isNickname('a'), isFalse);
      expect(AuthValidation.isNickname(' a '), isFalse);
      expect(AuthValidation.isNickname('ab'), isTrue);
      expect(AuthValidation.isNickname('a' * 24), isTrue);
      expect(AuthValidation.isNickname('a' * 25), isFalse);
    });
  });

  testWidgets('validates empty and malformed fields', (tester) async {
    await pump(tester);
    await submit(tester);
    expect(find.text('Wpisz adres e-mail'), findsOneWidget);
    expect(find.text('Wpisz hasło'), findsOneWidget);

    await tester.enterText(field('E-mail'), 'ania@');
    await submit(tester);
    expect(find.text('Sprawdź adres e-mail'), findsOneWidget);
    expect(auth.signIns, isEmpty);
  });

  testWidgets('signs in and shows a loading state', (tester) async {
    auth.gate = Completer<void>();
    await pump(tester);
    await tester.enterText(field('E-mail'), 'ania@example.pl');
    await tester.enterText(field('Hasło'), 'secret');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.bySemanticsLabel('Chwileczkę…'), findsOneWidget);
    expect(auth.signIns.single, (email: 'ania@example.pl', password: 'secret'));

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Chwileczkę…'), findsNothing);
  });

  testWidgets('shows a wrong password under the password field', (
    tester,
  ) async {
    auth.failure = AuthFailure.wrongCredentials;
    await pump(tester);
    await tester.enterText(field('E-mail'), 'ania@example.pl');
    await tester.enterText(field('Hasło'), 'wrong');
    await submit(tester);
    expect(find.text('Nieprawidłowy e-mail lub hasło.'), findsOneWidget);

    // Editing the field hides the error.
    await tester.enterText(field('Hasło'), 'wrong2');
    await tester.pump();
    expect(find.text('Nieprawidłowy e-mail lub hasło.'), findsNothing);
  });

  testWidgets('shows "no network" as a message', (tester) async {
    auth.failure = AuthFailure.network;
    await pump(tester);
    await tester.enterText(field('E-mail'), 'ania@example.pl');
    await tester.enterText(field('Hasło'), 'secret');
    await submit(tester);
    expect(
      find.text('Brak połączenia z internetem. Spróbuj ponownie.'),
      findsOneWidget,
    );
  });

  testWidgets('password can be shown and hidden', (tester) async {
    await pump(tester);
    TextField passwordField() => tester.widget<TextField>(
      find.descendant(of: field('Hasło'), matching: find.byType(TextField)),
    );
    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Pokaż hasło'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Ukryj hasło'), findsOneWidget);
  });

  group('register tab', () {
    Future<void> openRegister(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('Załóż konto').first);
      await tester.pumpAndSettle();
    }

    testWidgets('validates nickname and password length', (tester) async {
      await openRegister(tester);
      expect(
        find.text(
          'Pseudonim widać w rankingu. Nie podawaj imienia i nazwiska.',
        ),
        findsOneWidget,
      );
      await tester.enterText(field('E-mail'), 'ania@example.pl');
      await tester.enterText(field('Hasło'), 'short');
      await tester.enterText(field('Pseudonim'), 'a');
      await submit(tester);
      expect(find.text('Hasło musi mieć co najmniej 8 znaków'), findsOneWidget);
      expect(
        find.text('Pseudonim musi mieć od 2 do 24 znaków'),
        findsOneWidget,
      );
      expect(auth.registrations, isEmpty);
    });

    testWidgets('sends the nickname to the repository', (tester) async {
      await openRegister(tester);
      await tester.enterText(field('E-mail'), 'ania@example.pl');
      await tester.enterText(field('Hasło'), 'secret123');
      await tester.enterText(field('Pseudonim'), 'cienista_ania');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();

      expect(auth.registrations.single, (
        email: 'ania@example.pl',
        password: 'secret123',
        nickname: 'cienista_ania',
      ));
    });

    testWidgets('shows a taken e-mail under the e-mail field', (tester) async {
      auth.failure = AuthFailure.emailInUse;
      await openRegister(tester);
      await tester.enterText(field('E-mail'), 'ania@example.pl');
      await tester.enterText(field('Hasło'), 'secret123');
      await tester.enterText(field('Pseudonim'), 'cienista_ania');
      await submit(tester);
      expect(
        find.text(
          'Ten adres e-mail jest już zajęty. Zaloguj się albo użyj innego.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Nie pamiętam hasła', () {
    testWidgets('uses the e-mail from the form', (tester) async {
      await pump(tester);
      await tester.enterText(field('E-mail'), 'ania@example.pl');
      await tester.tap(find.text('Nie pamiętam hasła'));
      await tester.pumpAndSettle();
      expect(auth.resets, ['ania@example.pl']);
      expect(find.textContaining('ania@example.pl'), findsWidgets);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('asks for the e-mail when the field is empty', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Nie pamiętam hasła'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Wyślij'));
      await tester.pumpAndSettle();
      expect(find.text('Wpisz adres e-mail'), findsOneWidget);
      expect(auth.resets, isEmpty);

      await tester.enterText(
        find.byKey(const Key('auth-reset-email')),
        'ania@example.pl',
      );
      await tester.tap(find.text('Wyślij'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.resets, ['ania@example.pl']);
    });
  });

  testWidgets('register tab with errors fits 360 dp in Senior text', (
    tester,
  ) async {
    await pumpSenior360(
      tester,
      const LoginScreen(),
      overrides: fakeAuthOverrides(auth: auth),
    );
    await tester.tap(find.text('Załóż konto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
