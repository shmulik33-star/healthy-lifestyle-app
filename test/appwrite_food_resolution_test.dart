import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_lifestyle_stage9/features/profile/cloud_gateway.dart';
import 'package:healthy_lifestyle_stage9/features/profile/cloud_sync_service.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

FoodItem food(String name) => FoodItem(
  id: 'custom_a',
  name: name,
  category: 'אחר',
  type: KosherFoodType.pareve,
  caloriesPer100g: 100,
  proteinPer100g: 10,
  carbsPer100g: 20,
  fatPer100g: 3,
  units: {'מנה': 100},
  userCreated: true,
);

final isFoodConflict = isA<CloudGatewayException>().having(
  (error) => error.code,
  'code',
  'food_conflict',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(CloudSyncService.stopAutomaticSync);

  test(
    'queued food sync cannot migrate to a different signed-in owner',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var owner = 'owner';
      var reads = 0;
      final state = AppState()..customFoods.add(food('מקומי'));
      final authError = isA<CloudGatewayException>().having(
        (error) => error.code,
        'code',
        'authentication_required',
      );
      await http.runWithClient(
        () async {
          await CloudGateway.signIn('test@example.test', 'fake-password');
          final first = expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(authError),
          );
          await started.future;
          final queued = expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(authError),
          );
          owner = 'other';
          await CloudGateway.signIn('other@example.test', 'fake-password');
          release.complete();
          await Future.wait([first, queued]);
          expect(
            reads,
            1,
            reason:
                'Queued old-account request must not even read new account rows',
          );
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('sign-in')) {
            return http.Response(
              jsonEncode({
                'user': {'id': owner},
              }),
              200,
            );
          }
          expect(request.method, 'GET');
          reads++;
          started.complete();
          await release.future;
          return http.Response('{"rows":[]}', 200);
        }),
      );
    },
    skip: !CloudGateway.useAppwrite,
  );

  test(
    'edit during remote read is retained without upload or download overwrite',
    () async {
      final state = AppState()..customFoods.add(food('לפני הקריאה'));
      await http.runWithClient(
        () async {
          await CloudGateway.signIn('test@example.test', 'fake-password');
          await expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(
              isA<CloudGatewayException>().having(
                (error) => error.code,
                'code',
                'food_conflict_changed',
              ),
            ),
          );
          expect(state.customFoods.single.name, 'עריכה בזמן הקריאה');
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('sign-in')) {
            return http.Response('{"user":{"id":"owner"}}', 200);
          }
          expect(request.method, 'GET', reason: 'No upload is authorized');
          state.customFoods[0] = food('עריכה בזמן הקריאה');
          return http.Response(
            jsonEncode({
              'rows': [
                {
                  'food_id': 'custom_a',
                  'payload': food('לפני הקריאה').toJson(),
                  'updated_at': '2026-10-08T08:00:00Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
    skip: !CloudGateway.useAppwrite,
  );

  test(
    'real sync path preserves cloud copy locally and uploads it before original',
    () async {
      var remote = <Map<String, dynamic>>[
        {
          'food_id': 'custom_a',
          'payload': food('ענן').toJson(),
          'updated_at': '2026-10-08T08:00:00Z',
        },
      ];
      final writes = <Map<String, dynamic>>[];
      final state = AppState()..customFoods.add(food('מקומי'));
      await http.runWithClient(
        () async {
          await CloudGateway.signIn('test@example.test', 'fake-password');
          await expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(isFoodConflict),
          );
          expect(writes, isEmpty);
          await CloudSyncService.keepBothFoodVersions(
            state,
            CloudSyncService.foodConflicts.value.single,
          );
          expect(
            (await AppState.load()).customFoods,
            hasLength(2),
            reason: 'Copy durable BEFORE any write',
          );
          await CloudSyncService.syncCustomFoods(state);
          expect(writes.map((row) => row['food_id']).last, 'custom_a');
          expect(writes.first['payload']['name'], contains('גרסת ענן'));
          expect(writes.last['expectedPayload']['name'], 'ענן');
          expect(remote, hasLength(2));
          expect(CloudSyncService.foodConflicts.value, isEmpty);
          final written = writes.length;
          await CloudSyncService.syncCustomFoods(state);
          expect(writes.length, written, reason: 'Repeated sync is idempotent');
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('sign-in'))
            return http.Response(
              jsonEncode({
                'user': {'id': 'owner'},
              }),
              200,
            );
          if (request.method == 'GET')
            return http.Response(
              jsonEncode({'rows': remote}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          final rows = List<Map<String, dynamic>>.from(
            jsonDecode(request.body)['rows'],
          );
          writes.addAll(rows);
          for (final row in rows) {
            remote.removeWhere((item) => item['food_id'] == row['food_id']);
            remote.add({
              'food_id': row['food_id'],
              'payload': row['payload'],
              'updated_at': '2026-10-08T09:00:00Z',
            });
          }
          return http.Response('{"ok":true}', 200);
        }),
      );
    },
    skip: !CloudGateway.useAppwrite,
  );

  test(
    'changed remote invalidates consent without writing; switched owner cannot resolve',
    () async {
      var cloud = food('ענן');
      var owner = 'owner';
      var writes = 0;
      final state = AppState()..customFoods.add(food('מקומי'));
      await http.runWithClient(
        () async {
          await CloudGateway.signIn('test@example.test', 'fake-password');
          await expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(isFoodConflict),
          );
          final reviewed = CloudSyncService.foodConflicts.value.single;
          await CloudSyncService.keepBothFoodVersions(state, reviewed);
          cloud = food('ענן השתנה שוב');
          await expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(isFoodConflict),
          );
          expect(writes, 0);
          expect(state.customFoods, hasLength(2));
          owner = 'other';
          await CloudGateway.signIn('other@example.test', 'fake-password');
          await expectLater(
            CloudSyncService.keepBothFoodVersions(state, reviewed),
            throwsA(isA<CloudGatewayException>()),
          );
          expect(state.customFoods, hasLength(2));
          expect(writes, 0);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('sign-in'))
            return http.Response(
              jsonEncode({
                'user': {'id': owner},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          if (request.method == 'GET')
            return http.Response(
              jsonEncode({
                'rows': [
                  {
                    'food_id': cloud.id,
                    'payload': cloud.toJson(),
                    'updated_at': '2026-10-08T08:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          writes++;
          return http.Response('{"ok":true}', 200);
        }),
      );
    },
    skip: !CloudGateway.useAppwrite,
  );

  test(
    'server CAS rejection keeps original and durable copy for retry',
    () async {
      final state = AppState()..customFoods.add(food('מקומי'));
      await http.runWithClient(
        () async {
          await CloudGateway.signIn('test@example.test', 'fake-password');
          await expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(isFoodConflict),
          );
          await CloudSyncService.keepBothFoodVersions(
            state,
            CloudSyncService.foodConflicts.value.single,
          );
          await expectLater(
            CloudSyncService.syncCustomFoods(state),
            throwsA(
              isA<CloudGatewayException>().having(
                (error) => error.code,
                'code',
                'conflict',
              ),
            ),
          );
          expect(state.customFoods.first.name, 'מקומי');
          expect((await AppState.load()).customFoods, hasLength(2));
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('sign-in'))
            return http.Response('{"user":{"id":"owner"}}', 200);
          if (request.method == 'GET')
            return http.Response(
              jsonEncode({
                'rows': [
                  {
                    'food_id': 'custom_a',
                    'payload': food('ענן').toJson(),
                    'updated_at': '2026-10-08T08:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          return http.Response('{"error":"conflict"}', 409);
        }),
      );
    },
    skip: !CloudGateway.useAppwrite,
  );
}
