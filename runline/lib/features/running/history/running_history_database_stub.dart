import 'package:sembast/sembast.dart';

Future<Database> openDatabase() =>
    Future.error(UnsupportedError('Local running history is unavailable'));
