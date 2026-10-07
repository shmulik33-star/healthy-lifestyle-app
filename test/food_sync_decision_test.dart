import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/profile/food_sync_decision.dart';

void main() {
  test('equal copies establish a baseline, independent of clocks', () {
    expect(
      foodSyncDecision(local: 'a', remote: 'a', baseline: null),
      FoodSyncDecision.unchanged,
    );
  });
  test('new and remote-only foods form a union', () {
    expect(
      foodSyncDecision(local: 'a', remote: null, baseline: null),
      FoodSyncDecision.upload,
    );
    expect(
      foodSyncDecision(local: null, remote: 'a', baseline: null),
      FoodSyncDecision.download,
    );
  });
  test('one-sided edits use last synced content, not timestamps', () {
    expect(
      foodSyncDecision(local: 'b', remote: 'a', baseline: 'a'),
      FoodSyncDecision.upload,
    );
    expect(
      foodSyncDecision(local: 'a', remote: 'b', baseline: 'a'),
      FoodSyncDecision.download,
    );
  });
  test(
    'unknown and concurrent differing edits are never silently overwritten',
    () {
      expect(
        foodSyncDecision(local: 'a', remote: 'b', baseline: null),
        FoodSyncDecision.conflict,
      );
      expect(
        foodSyncDecision(local: 'b', remote: 'c', baseline: 'a'),
        FoodSyncDecision.conflict,
      );
    },
  );
}
