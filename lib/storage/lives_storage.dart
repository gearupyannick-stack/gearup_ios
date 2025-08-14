import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class LivesStorage {
  // Get the directory for the profile folder in the app's documents directory.
  Future<Directory> get _profileDirectory async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final Directory profileDirectory = Directory('${documentsDirectory.path}/profile');
    if (!await profileDirectory.exists()) {
      await profileDirectory.create(recursive: true);
    }
    return profileDirectory;
  }

  // Get the File object for lives.csv inside the profile directory.
  Future<File> get _livesFile async {
    final dir = await _profileDirectory;
    return File('${dir.path}/lives.csv');
  }

  // Reads the lives count from the CSV file. If the file doesn't exist, it initializes it with a default value (e.g. 5).
  Future<int> readLives() async {
    try {
      final file = await _livesFile;
      if (!await file.exists()) {
        // File doesn't exist—initialize with default lives count.
        await writeLives(5);
        return 5;
      }
      final contents = await file.readAsString();
      final csvTable = const CsvToListConverter().convert(contents);
      if (csvTable.isNotEmpty && csvTable[0].isNotEmpty) {
        return csvTable[0][0] is int 
            ? csvTable[0][0] 
            : int.tryParse(csvTable[0][0].toString()) ?? 5;
      }
      return 5;
    } catch (e) {
      // In case of error, return default value.
      return 5;
    }
  }

  // Writes the given lives count into the CSV file.
  Future<File> writeLives(int lives) async {
    final file = await _livesFile;
    // Convert the lives count to CSV (one row with one cell).
    final csvData = const ListToCsvConverter().convert([[lives]]);
    return file.writeAsString(csvData);
  }
  
  // Increments lives by one if less than 5 and returns the updated lives count.
  Future<int> incrementLivesIfNeeded() async {
    int lives = await readLives();
    if (lives < 5) {
      lives++;
      await writeLives(lives);
    }
    return lives;
  }
}
