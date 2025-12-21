import 'package:hive/hive.dart';

class LocalHistoryRepository {
  static const String _historyBoxName = 'evaluation_history';
  static const String _summaryBoxName = 'evaluation_summary';

  /// 履歴用Box
  Future<Box> _historyBox() async {
    return await Hive.openBox(_historyBoxName);
  }

  /// サマリー（総試行回数）用Box
  Future<Box> _summaryBox() async {
    return await Hive.openBox(_summaryBoxName);
  }

  // ---------------------------------------------------------------------------
  // 保存（LocalEvaluationService から呼ばれる）
  // ---------------------------------------------------------------------------

  Future<void> saveEvaluationResult({
    required String uuid,
    required double totalScore,
  }) async {
    final historyBox = await _historyBox();
    final summaryBox = await _summaryBox();

    final now = DateTime.now().toUtc();

    // ---- Python Result と互換な形 ----
    final Map<String, dynamic> record = {
      "uuid": uuid,
      "total_score": totalScore,
      "created_at": now.toIso8601String(), // Pythonと同じ
    };

    await historyBox.add(record);

    // ---- 総試行回数（削除しない）----
    final int currentCount = summaryBox.get(uuid, defaultValue: 0);
    await summaryBox.put(uuid, currentCount + 1);

    // ---- 古いデータ自動削除 ----
    await _deleteOldHistory(days: 90);
  }

  // ---------------------------------------------------------------------------
  // 履歴取得（HistoryScreen 用）
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> fetchHistory(String uuid) async {
    final historyBox = await _historyBox();
    final summaryBox = await _summaryBox();

    final List<Map<String, dynamic>> history = [];

    for (var value in historyBox.values) {
      if (value is Map && value['uuid'] == uuid) {
        history.add(Map<String, dynamic>.from(value));
      }
    }

    // 新しい順（Pythonの order_by desc 相当）
    history.sort((a, b) =>
        b['created_at'].compareTo(a['created_at']));

    final int totalCount = summaryBox.get(uuid, defaultValue: history.length);

    return {
      "history": history,
      "total_count": totalCount,
    };
  }

  // ---------------------------------------------------------------------------
  // 自動削除（90日）
  // ---------------------------------------------------------------------------

  Future<void> _deleteOldHistory({required int days}) async {
    final historyBox = await _historyBox();
    final threshold =
        DateTime.now().toUtc().subtract(Duration(days: days));

    final keysToDelete = <dynamic>[];

    for (var key in historyBox.keys) {
      final value = historyBox.get(key);
      if (value is Map && value['created_at'] != null) {
        final date = DateTime.tryParse(value['created_at']);
        if (date != null && date.isBefore(threshold)) {
          keysToDelete.add(key);
        }
      }
    }

    if (keysToDelete.isNotEmpty) {
      await historyBox.deleteAll(keysToDelete);
    }
  }
}
