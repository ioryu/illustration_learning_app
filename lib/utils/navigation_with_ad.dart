import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/ad_service.dart';
import '../services/server_service.dart';

// グローバルな状態管理
int _navigateCallCount = 0; // ✅ 呼び出し回数をカウント
bool _isNavigating = false; // ✅ 連打防止ロック
final AdService _adService = AdService();

void loadAd() {
  _adService.loadInterstitialAd(
    () => debugPrint("インタースティシャル広告ロード成功"),
    () => debugPrint("インタースティシャル広告ロード失敗"),
  );
}

/// ✅ 2回ごとに広告を表示する（サーバーCold状態には依存しない）
Future<void> navigateWithAdEvery3rdTime({
  required BuildContext context,
  required Future<Widget> Function() destinationBuilder,
}) async {
  if (_isNavigating) {
    debugPrint("すでに遷移中のためスキップ");
    return;
  }
  _isNavigating = true;

  try {
    _navigateCallCount++;
    debugPrint("navigateWithAdEvery3rdTime 呼び出し回数: $_navigateCallCount");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final connectivityResult = await Connectivity().checkConnectivity();
    final hasNetwork = connectivityResult != ConnectivityResult.none;

    if (!hasNetwork) {
      Navigator.pop(context);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('接続エラー'),
          content: const Text('ネットワークに接続されていません。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    Navigator.pop(context); // ローディング解除

    final adService = _adService;
    final shouldShowAd = adService.isAdAvailable && (_navigateCallCount % 2 == 0);

    if (shouldShowAd) {
      adService.showAd(
        context: context,
        onFinish: () async {
          final destination = await destinationBuilder();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
      );
    } else if (_navigateCallCount % 2 == 0) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('準備中'),
          content: const Text('準備中です。3分くらいしてから再度お試しください。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } else {
      final destination = await destinationBuilder();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    }
  } finally {
    _isNavigating = false;
  }
}

/// ✅ サーバーがColdなら遷移しない（広告なし）
Future<void> navigateIfServerWarm({
  required BuildContext context,
  required Widget destination,
}) async {
  if (_isNavigating) {
    debugPrint("すでに遷移中のためスキップ");
    return;
  }
  _isNavigating = true;

  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final connectivityResult = await Connectivity().checkConnectivity();
    final hasNetwork = connectivityResult != ConnectivityResult.none;

    if (!hasNetwork) {
      Navigator.pop(context);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('接続エラー'),
          content: const Text('ネットワークに接続されていません。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // final cold = await ServerService.isServerCold();
    final cold = false;
    Navigator.pop(context); // ローディング解除

    if (cold) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('通信エラー'),
          content: const Text('サーバーが起動中です。3分くらいしてから再度お試しください。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    }
  } finally {
    _isNavigating = false;
  }
}
