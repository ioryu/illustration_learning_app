import 'package:http/http.dart' as http;

class ServerService {
  static Future<bool> isServerCold() async {
    try {
      final stopwatch = Stopwatch()..start();

      final response = await http
          .get(Uri.parse('https://illustrationevaluation.onrender.com/ping'))
          .timeout(const Duration(seconds: 3)); // ⏱️ 2秒以上かかるならエラー

      stopwatch.stop();
      print('ping応答時間: ${stopwatch.elapsedMilliseconds}ms');

      // 応答あっても2秒以上かかれば cold と判定
      return stopwatch.elapsedMilliseconds > 3000;
    } catch (e) {
      // タイムアウト or 通信失敗 → cold 扱い
      print('ping失敗: $e');
      return true;
    }
  }
}
