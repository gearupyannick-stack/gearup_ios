
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

/// Simple CSV-backed lives storage: stores a single integer in profile/lives.csv
class LivesStorage {
  Future<Directory> get _profileDirectory async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final Directory profileDirectory = Directory('${documentsDirectory.path}/profile');
    if (!await profileDirectory.exists()) {
      await profileDirectory.create(recursive: true);
    }
    return profileDirectory;
  }

  Future<File> get _livesFile async {
    final dir = await _profileDirectory;
    final file = File('${dir.path}/lives.csv');
    if (!await file.exists()) {
      await file.writeAsString(const ListToCsvConverter().convert([[5]])); // default 5 lives
    }
    return file;
  }

  Future<int> readLives() async {
    final file = await _livesFile;
    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty || rows.first.isEmpty) return 5;
    final val = rows.first.first;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 5;
    return 5;
  }

  Future<void> writeLives(int lives) async {
    final file = await _livesFile;
    final csvData = const ListToCsvConverter().convert([[lives]]);
    await file.writeAsString(csvData);
  }

  Future<int> incrementLivesIfNeeded() async {
    int lives = await readLives();
    if (lives < 5) {
      lives++;
      await writeLives(lives);
    }
    return lives;
  }
}
