import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.init(); // detect emulator vs physical device
  runApp(const ToyShopApp());
}
