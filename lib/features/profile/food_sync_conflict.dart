import 'dart:convert';

import '../../shared/models/food.dart';

String foodContentKey(FoodItem food) {
  dynamic canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return jsonEncode(canonical(food.toJson()));
}

/// A detached pair of versions shown to one account, not a timestamp guess.
class FoodSyncConflict {
  FoodSyncConflict({
    required this.ownerId,
    required FoodItem local,
    required FoodItem remote,
  }) : local = FoodItem.fromJson(jsonDecode(jsonEncode(local.toJson()))),
       remote = FoodItem.fromJson(jsonDecode(jsonEncode(remote.toJson()))),
       localKey = foodContentKey(local),
       remoteKey = foodContentKey(remote);

  final String ownerId;
  final FoodItem local;
  final FoodItem remote;
  final String localKey;
  final String remoteKey;

  bool matches(String owner, FoodItem? currentLocal, FoodItem? currentRemote) =>
      owner == ownerId &&
      currentLocal != null &&
      currentRemote != null &&
      foodContentKey(currentLocal) == localKey &&
      foodContentKey(currentRemote) == remoteKey;

  FoodItem remoteCopy(String id, Iterable<FoodItem> existing) {
    final names = existing
        .map((food) => food.name.trim().toLowerCase())
        .toSet();
    var suffix = 1;
    var name = '${remote.name} (גרסת ענן $suffix)';
    while (names.contains(name.trim().toLowerCase())) {
      name = '${remote.name} (גרסת ענן ${++suffix})';
    }
    return FoodItem.fromJson({...remote.toJson(), 'id': id, 'name': name});
  }
}

class FoodSyncConsent {
  FoodSyncConsent(this.conflict, this.copy) : copyKey = foodContentKey(copy);
  final FoodSyncConflict conflict;
  final FoodItem copy;
  final String copyKey;

  bool permits(
    String owner,
    FoodItem? local,
    FoodItem? remote,
    FoodItem? preservedCopy,
  ) =>
      conflict.matches(owner, local, remote) &&
      preservedCopy != null &&
      foodContentKey(preservedCopy) == copyKey;
}
