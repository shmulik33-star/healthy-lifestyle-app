enum FoodSyncDecision { unchanged, upload, download, conflict }

/// A three-way comparison never uses the device clock to resolve edits.
/// Without a common baseline, differing copies require explicit resolution.
FoodSyncDecision foodSyncDecision({
  required String? local,
  required String? remote,
  required String? baseline,
}) {
  if (local == remote) return FoodSyncDecision.unchanged;
  if (remote == null) return FoodSyncDecision.upload;
  if (local == null) return FoodSyncDecision.download;
  if (baseline == null) return FoodSyncDecision.conflict;
  if (local == baseline) return FoodSyncDecision.download;
  if (remote == baseline) return FoodSyncDecision.upload;
  return FoodSyncDecision.conflict;
}
