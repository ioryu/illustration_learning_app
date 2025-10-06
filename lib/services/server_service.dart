import 'package:http/http.dart' as http;

class ServerService {
  /// サーバがスリープ状態かどうか確認
  /// timeoutSeconds はタイムアウトの秒数（デフォルト3秒）
  static Future<bool> isServerCold({int timeoutSeconds = 3}) async {
    try {
      final stopwatch = Stopwatch()..start();

      final response = await http
          .get(Uri.parse('https://illustrationevaluation.onrender.com/ping'))
          .timeout(Duration(seconds: timeoutSeconds)); // 引数で指定可能

      stopwatch.stop();
      print('ping応答時間: ${stopwatch.elapsedMilliseconds}ms');

      // 応答が timeoutSeconds を超えたら cold と判定
      return stopwatch.elapsedMilliseconds > timeoutSeconds * 1000;
    } catch (e) {
      // タイムアウト or 通信失敗 → cold 扱い
      print('ping失敗: $e');
      return true;
    }
  }
}

