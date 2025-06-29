import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../widgets/bottom_banner_ad.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}
class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  String? _error;
  String _selectedMode = '日平均';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final url = Uri.parse('https://illustrationevaluation.onrender.com/history');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _historyData = List<Map<String, dynamic>>.from(data['history']);
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

  /// ⽇付からISO準拠の週番号を計算
  int weekNumber(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = monday.difference(firstDayOfYear).inDays;
    return (daysOffset / 7).floor() + 1;
  }

  List<FlSpot> _getChartData(List<String> xLabels, List<String> debugLabels) {
    Map<String, List<double>> grouped = {};

    for (final item in _historyData) {
      final createdAt = item['created_at'];
      final score = item['total_score']?.toDouble() ?? 0.0;
      if (createdAt == null) continue;

      final date = DateTime.tryParse(createdAt);
      if (date == null) continue;

      // グループ化のキーをモードに応じて変更
      String key;
      if (_selectedMode == '週平均') {
        key = '${date.year}-W${weekNumber(date)}'; // 年と週番号をキーにする
      } else if (_selectedMode == '月平均') {
        key = '${date.year}-${date.month.toString().padLeft(2, '0')}'; // 年と月をキーにする
      } else {
        key = DateFormat('yyyy-MM-dd').format(date); // 日付をキーにする
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(score);
    }

    // グループ化されたデータをソートして平均値を計算
    List<String> sortedKeys = grouped.keys.toList()..sort();
    List<FlSpot> spots = [];

    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final scores = grouped[key]!;
      final avg = scores.reduce((a, b) => a + b) / scores.length;

      xLabels.add(key); // x軸ラベルにキーを追加
      debugLabels.add('$key\n平均: ${avg.toStringAsFixed(1)}');
      spots.add(FlSpot(i.toDouble(), avg)); // グラフの点を追加
    }

    return spots;
  }

  Widget _buildScoreChart() {
    List<String> xLabels = [];
    List<String> debugLabels = [];
    final spots = _getChartData(xLabels, debugLabels);

    if (spots.isEmpty) {
      return const Center(child: Text('スコアデータがありません'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.black87,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    int index = spot.x.toInt();
                    String label = index >= 0 && index < debugLabels.length
                        ? debugLabels[index]
                        : '';
                    return LineTooltipItem(
                      '$label\nスコア: ${spot.y.toStringAsFixed(1)}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < xLabels.length) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          xLabels[index],
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            minX: 0,
            maxX: (spots.length - 1).toDouble().clamp(0, double.infinity),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.indigo,
                barWidth: 3,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.indigo.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    double average = _historyData.isEmpty
        ? 0
        : _historyData.fold(0.0, (sum, item) => sum + (item['total_score']?.toDouble() ?? 0.0)) /
            _historyData.length;

    double max = _historyData.fold(0.0, (max, item) {
      double score = item['total_score']?.toDouble() ?? 0.0;
      return score > max ? score : max;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButton<String>(
            value: _selectedMode,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedMode = newValue;
                });
              }
            },
            items: ['日平均', '週平均', '月平均']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.star, size: 28, color: Colors.orange),
                        const SizedBox(height: 8),
                        const Text('最高スコア', style: TextStyle(fontSize: 12)),
                        Text('${max.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.history, size: 28, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text('試行回数', style: TextStyle(fontSize: 12)),
                        Text('${_historyData.length}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                      child: Text('スコアの推移', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: _buildScoreChart()),
                    const SizedBox(height: 16),
                    const BottomBannerAd(),
                    const SizedBox(height: 10),
                  ],
                ),
    );
  }
}
