import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockBatch extends Mock implements WriteBatch {}

void main() {
  late _MockDoc doc;
  late _MockDoc ranking;
  late _MockBatch batch;
  late FirestoreUserProfileRepository repo;

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
    registerFallbackValue(_MockDoc());
  });

  setUp(() {
    final firestore = _MockFirestore();
    final users = _MockCollection();
    doc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('u1')).thenReturn(doc);
    when(() => doc.set(any(), any())).thenAnswer((_) async {});
    final rankings = _MockCollection();
    ranking = _MockDoc();
    batch = _MockBatch();
    when(() => firestore.collection('rankings')).thenReturn(rankings);
    when(() => rankings.doc('u1')).thenReturn(ranking);
    when(firestore.batch).thenReturn(batch);
    when(batch.commit).thenAnswer((_) async {});
    repo = FirestoreUserProfileRepository(firestore);
  });

  Map<String, dynamic> lastWrite() =>
      verify(() => doc.set(captureAny(), any())).captured.single
          as Map<String, dynamic>;

  test('createProfile writes the starting fields', () async {
    await repo.createProfile(uid: 'u1', nickname: 'cienista_ania');

    final data = lastWrite();
    expect(data['nickname'], 'cienista_ania');
    expect(data['points'], 0);
    expect(data['weekPoints'], 0);
    expect(data['badges'], isEmpty);
    expect(data['createdAt'], isA<FieldValue>());
    expect(data.keys, isNot(contains('consents')));
  });

  test('saveConsents writes the switches and a server timestamp', () async {
    await repo.saveConsents(
      'u1',
      const Consents(location: true, push: false, ranking: true),
    );

    final data =
        verify(
              () => batch.set<Map<String, dynamic>>(doc, captureAny(), any()),
            ).captured.single
            as Map<String, dynamic>;
    final consents = data['consents'] as Map<String, dynamic>;
    expect(consents['location'], isTrue);
    expect(consents['push'], isFalse);
    expect(consents['ranking'], isTrue);
    expect(consents['acceptedAt'], isA<FieldValue>());
    expect(data['fcmToken'], isA<FieldValue>()); // push off → token removed
    verifyNever(() => batch.delete(any()));
    verify(batch.commit).called(1);
  });

  test('saveConsents without the ranking deletes the public copy', () async {
    await repo.saveConsents(
      'u1',
      const Consents(location: true, push: true, ranking: false),
    );
    verify(() => batch.delete(ranking)).called(1);
    verify(batch.commit).called(1);
  });

  test('hasAcceptedConsents is true only when consents exist', () async {
    final snapshot = _MockSnapshot();
    when(() => doc.get()).thenAnswer((_) async => snapshot);

    when(snapshot.data).thenReturn(null);
    expect(await repo.hasAcceptedConsents('u1'), isFalse);

    when(snapshot.data).thenReturn({'nickname': 'ab', 'points': 0});
    expect(await repo.hasAcceptedConsents('u1'), isFalse);

    when(snapshot.data).thenReturn({
      'consents': {'location': true, 'push': true, 'ranking': false},
    });
    expect(await repo.hasAcceptedConsents('u1'), isTrue);
  });
}
