import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';  // kReleaseMode用に追加

class BottomBannerAd extends StatefulWidget {
  const BottomBannerAd({super.key});

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // ✅ 環境＆プラットフォームで広告IDを切り替えるgetter
  // String get bannerAdUnitId {
  //   if (Platform.isIOS) {
  //     return kReleaseMode
  //         ? 'ca-app-pub-6370853535798245/9845846601'  // iOS本番IDに差し替え
  //         : 'ca-app-pub-3940256099942544/2934735716';  // iOSテストID
  //   } else if (Platform.isAndroid) {
  //     return kReleaseMode
  //         ? 'ca-app-pub-6370853535798245/9845846601'  // Android本番IDに差し替え
  //         : 'ca-app-pub-3940256099942544/6300978111';  // AndroidテストID
  //   } else {
  //     throw UnsupportedError("Unsupported platform");
  //   }
  // }
  String get bannerAdUnitId {
    // ✅ 強制的に本番モードとして扱う（テストIDは一切使用しない）
    if (Platform.isIOS) {
      return 'ca-app-pub-6370853535798245/9845846601';  // iOS本番ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-6370853535798245/9845846601';  // Android本番ID
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      _loadBannerAd(context);
    }
  }

  void _loadBannerAd(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final adSize = screenWidth >= 600 ? AdSize.fullBanner : AdSize.largeBanner;

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,  // ← ここが切り替わる
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Ad load failed: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoaded && _bannerAd != null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
