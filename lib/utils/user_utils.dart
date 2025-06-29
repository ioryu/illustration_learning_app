import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _uuidKey = 'user_uuid';

Future<String> getOrCreateUUID() async {
  final prefs = await SharedPreferences.getInstance();
  String? existingUUID = prefs.getString(_uuidKey);

  if (existingUUID != null) {
    return existingUUID;
  } else {
    // 新しいUUIDを生成して保存
    final newUUID = const Uuid().v4();
    await prefs.setString(_uuidKey, newUUID);
    return newUUID;
  }
}
