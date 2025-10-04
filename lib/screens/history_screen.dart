import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../widgets/bottom_banner_ad.dart';
import '../utils/user_utils.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyData = []; // 履歴データ格納
  bool _isLoading = true;
  String? _error;

  bool _showBarGraph = true; // true: 日付ごとの試行回数、false: 試行ごとの点数推移

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  /// サーバーから履歴データを取得
  Future<void> _fetchHistory() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });

      String uuid = await getOrCreateUUID(); // UUID取得
      final url = Uri.parse(
          'https://illustrationevaluation.onrender.com/history?uuid=$uuid');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _historyData =
              List<Map<String, dynamic>>.from(data['history'] ?? []);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'サーバーエラー: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '通信エラー: $e';
        _isLoading = false;
      });
    }
  }

  /// 日付ごとに履歴をまとめる
  Map<String, List<Map<String, dynamic>>> _groupByDate() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in _historyData) {
      print(item['created_at']);
      final createdAt = item['created_at'];
      if (createdAt == null) continue;

      // パース
      final date = DateTime.tryParse(createdAt);
      if (date == null) continue;

      // 単純に9時間足す
      final dateJst = date.add(const Duration(hours: 9));

      // 日付だけ整形
      final key = DateFormat('yyyy/MM/dd').format(dateJst);

      print('UTC: $createdAt -> JST: $date');


      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }
    return grouped;
  }

  /// 平均・最高スコア・総試行回数のカード
  Widget _buildStatsCards() {
    double average = _historyData.isEmpty
        ? 0
        : _historyData.fold(
                0.0, (sum, item) => sum + (item['total_score']?.toDouble() ?? 0)) /
            _historyData.length;

    double max = _historyData.fold(0.0, (max, item) {
      double score = item['total_score']?.toDouble() ?? 0;
      return score > max ? score : max;
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 平均スコアカード
          Expanded(
            child: Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.trending_up, size: 28, color: Colors.green),
                    const SizedBox(height: 8),
                    const Text('平均スコア', style: TextStyle(fontSize: 12)),
                    Text('${average.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 最高スコアカード
          Expanded(
            child: Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.star, size: 28, color: Colors.orange),
                    const SizedBox(height: 8),
                    const Text('最高スコア', style: TextStyle(fontSize: 12)),
                    Text('${max.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 総試行回数カード
          Expanded(
            child: Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.history, size: 28, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text('全試行回数', style: TextStyle(fontSize: 12)),
                    Text('${_historyData.length}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// グラフ切替ボタンとチャート描画
  Widget _buildChart() {
  final grouped = _groupByDate();
  final dates = grouped.keys.toList()..sort();
  if (dates.isEmpty) return const Center(child: Text('スコアデータがありません'));

  // 日付範囲表示
  final startDate = dates.first;
  final endDate = dates.last;

  // --- BarChart用データ（日付ごとの試行回数） ---
  List<BarChartGroupData> barGroups = [];
  for (int i = 0; i < dates.length; i++) {
    final dayData = grouped[dates[i]]!;
    barGroups.add(BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
            toY: dayData.length.toDouble(), width: 16, color: Colors.indigo)
      ],
    ));
  }

  // --- LineChart用データ（施行ごとの点数） ---
  List<FlSpot> lineSpots = [];
  for (int i = 0; i < _historyData.length; i++) {
    double score = _historyData[i]['total_score']?.toDouble() ?? 0.0;
    lineSpots.add(FlSpot(i.toDouble(), score)); // 横軸 = 施行番号
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- 棒グラフ / 折れ線グラフ切替ボタン ---
      Row(
        children: [
          TextButton(
            onPressed: () => setState(() => _showBarGraph = true),
            child: Text(
              '試行回数',
              style: TextStyle(
                  color: _showBarGraph ? Colors.blue : Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showBarGraph = false),
            child: Text(
              '点数推移',
              style: TextStyle(
                  color: !_showBarGraph ? Colors.blue : Colors.grey),
            ),
          ),
        ],
      ),

      // --- 期間表示 ---
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
        child: Text('表示データの期間: $startDate 〜 $endDate(定期的にデータは削除されます)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),

      // --- グラフ本体 ---
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _showBarGraph
              ? BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: (barGroups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b)) + 2,
                    barGroups: barGroups,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < dates.length) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(dates[index],
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    gridData: FlGridData(show: true),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: lineSpots,
                        isCurved: true,
                        barWidth: 2,
                        color: Colors.orange,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < _historyData.length) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text('${index + 1}', // 施行番号
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true),
                  ),
                ),
        ),
      ),
    ],
  );
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('スコア推移'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFBF0),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFFBF0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchHistory,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsCards(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('スコアの推移',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: _buildChart()), // グラフ切替機能
                    const SizedBox(height: 16),
                    const BottomBannerAd(),
                    const SizedBox(height: 10),
                  ],
                ),
    );
  }
}
