import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart'; // ← あなたのホーム画面
import 'utils/user_utils.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 追加
import 'package:hive_flutter/hive_flutter.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 👇【追加】Hive 初期化　ローカルストレージ用
  await Hive.initFlutter();

  // Mobile Ads SDK 初期化
  await MobileAds.instance.initialize();

  // ユーザーIDの取得（初回なら生成）
  final uuid = await getOrCreateUUID();
  print("ユーザーID: $uuid");

  // 横画面固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await initializeDateFormatting('ja');
  Intl.defaultLocale = 'ja';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '絵の練習アプリ',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(), // ← 最初の画面
    );
  }
}
