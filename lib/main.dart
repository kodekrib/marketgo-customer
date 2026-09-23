import 'package:flutter/material.dart';
import 'app.dart';
import 'services/account_store.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CustomerApp.applyBranding(await SettingsService.fetchSettings());
  await AccountStore.instance.ensureLoaded();
  runApp(const CustomerApp());
}