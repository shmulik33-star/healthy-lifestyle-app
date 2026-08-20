import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/shared/storage/app_local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('central storage reads, writes and removes string values', () async {
    const key = 'storage-test-key';

    expect(await AppLocalStorage.readString(key), isNull);
    expect(await AppLocalStorage.containsKey(key), isFalse);

    await AppLocalStorage.writeString(key, 'value');
    expect(await AppLocalStorage.readString(key), 'value');
    expect(await AppLocalStorage.containsKey(key), isTrue);

    await AppLocalStorage.remove(key);
    expect(await AppLocalStorage.readString(key), isNull);
    expect(await AppLocalStorage.containsKey(key), isFalse);
  });
}
