// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'edge_detection_screen.dart';
import 'history_screen.dart';
import '../widgets/bottom_banner_ad.dart';
import '../services/ad_service.dart';
import '../services/server_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/navigation_with_ad.dart'; // ← 追加
import 'package:url_launcher/url_launcher.dart'; // ← 追加

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const String _privacyPolicyUrl = 'https://shard-peony-dcb.notion.site/21d3cf6526ec804d8e28e897b0fdce98?source=copy_link'; // ← あなたのNotionのURLに置き換えてください


class _HomeScreenState extends State<HomeScreen> {
  final AdService _adService = AdService();
  bool _isLoading = false;
  bool _isAdLoading = false;
  bool _isServerWarmingUp = true; // ★ サーバ起動待ちフラグ追加

  @override
  void initState() {
    super.initState();
    _loadAd();// ← 広告読み込み
    // サーバのウォームアップ（非同期で投げっぱなし）
    // サーバウォームアップ
    ServerService.isServerCold().then((cold) async {
      print('起動時のサーバ応答: ${cold ? "スリープ状態" : "起動済み"}');

      // ★ 起動済みでなければ15秒待機（Renderの起動待ち）
      if (cold) {
        await Future.delayed(const Duration(seconds: 15));
      }

      setState(() {
        _isServerWarmingUp = false; // 起動完了
      });
    }).catchError((e) {
      print('起動時ping失敗: $e');
      setState(() {
        _isServerWarmingUp = false; // 失敗しても一応解除
      });
    });
  }

  void _loadAd() {
    setState(() => _isAdLoading = true);
    _adService.loadInterstitialAd(
      () => setState(() => _isAdLoading = false),
      () => setState(() => _isAdLoading = false),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('絵の練習アプリ'),
        centerTitle: true,
        backgroundColor: Color(0xFFFFFBF0), // 👈 追加：背景色をベージュに統一
        elevation: 0, // 👈 オプション：影を消して一体感を出す場合
        foregroundColor: Colors.black87, // 👈 オプション：タイトル文字を読みやすく（必要に応じて）
      ),
      backgroundColor: const Color(0xFFFFFBF0), // 👈 ここを追加
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 説明とイラスト（またはロゴ）
            Column(
              children: const [
                Icon(Icons.brush, size: 80, color: Colors.blueAccent),
                SizedBox(height: 8),
                Text(
                  '模写で上達するイラスト学習アプリ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 機能ボタン（カード風）
            _buildMenuCard(
              icon: Icons.auto_fix_high,
              label: 'トレースと模写',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EdgeDetectionScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              icon: Icons.history,
              label: _isServerWarmingUp ? 'サーバ起動中...' : '評価履歴を見る',
              onTap: _isServerWarmingUp
                  ? null // ★ 起動中は無効
                  : () {
                      navigateIfServerWarm(
                        context: context,
                        destination: const HistoryScreen(),
                      );
                    },
            ),


            const Spacer(),
            TextButton(
              onPressed: () async {
                final uri = Uri.parse(_privacyPolicyUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('プライバシーポリシーを開けませんでした')),
                  );
                }
              },
              child: const Text(
                'プライバシーポリシー',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.blueAccent,
                ),
              ),
            ),

            const BottomBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
  required IconData icon,
  required String label,
  required VoidCallback? onTap, // ← nullableに
}) {
  final isDisabled = onTap == null;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Ink(
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade300 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isDisabled ? Colors.grey : Colors.blueAccent),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDisabled ? Colors.grey : Colors.black,
              ),
            ),
            const Spacer(),
            if (!isDisabled)
              const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    ),
  );
}
}
