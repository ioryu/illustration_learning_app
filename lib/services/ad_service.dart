import 'dart:io';
import 'package:flutter/foundation.dart'; // ← kReleaseMode 用
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;

  // ✅ 開発 or 本番を自動判定
  bool get _isDebug => !kReleaseMode;
  

  // ✅ ユニットIDの切り替え（プラットフォーム＆モード判定）
  String get _interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _isDebug
          ? 'ca-app-pub-3940256099942544/1033173712' // AndroidテストID
          : 'ca-app-pub-6370853535798245/6652691145'; // Android本番ID
    } else if (Platform.isIOS) {
      return _isDebug
          ? 'ca-app-pub-3940256099942544/4411468910' // iOSテストID
          : 'ca-app-pub-6370853535798245/6652691145'; // iOS本番ID
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  bool get isAdAvailable => _interstitialAd != null;

  Future<void> loadInterstitialAd(Function()? onLoaded, Function()? onFailed) async {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          print('インタースティシャル広告のロードに失敗: $error');
          _interstitialAd = null;
          onFailed?.call();
        },
      ),
    );
  }

  void showAd({
    required BuildContext context,
    required VoidCallback onFinish,
  }) {
    if (_interstitialAd == null) {
      onFinish();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        onFinish();
        loadInterstitialAd(null, null);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        onFinish();
        loadInterstitialAd(null, null);
      },
    );

    _interstitialAd!.show();
  }
}
