import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _prefKey = 'jarvis_device_id';
  static const _uuid = Uuid();
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefKey);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_prefKey, id);
    }
    _cached = id;
    return id;
  }
}
