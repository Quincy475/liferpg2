import 'package:hive_flutter/hive_flutter.dart';

late Box usersBox;
late Box tasksBox;
late Box shopBox;
late Box eventsBox;
late Box raidBox;
late Box completionsBox; // optioneel, history
late Box appBox;

Future<void> openAppBoxes() async {
  usersBox = await Hive.openBox('users');
  tasksBox = await Hive.openBox('tasks');
  shopBox = await Hive.openBox('shop');
  eventsBox = await Hive.openBox('events');
  raidBox = await Hive.openBox('raid');
  completionsBox = await Hive.openBox('completions');
  appBox = await Hive.openBox('app');
}
