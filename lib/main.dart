import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:household_rpg/app.dart';
import 'package:household_rpg/data/local/hive_boxes.dart';
import 'package:household_rpg/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();

  await openAppBoxes(); // open alle Hive-boxen
  runApp(const ProviderScope(child: HouseholdRPGApp()));
}
