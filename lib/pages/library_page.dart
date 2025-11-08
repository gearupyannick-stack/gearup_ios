import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:easy_localization/easy_localization.dart';
import 'package:csv/csv.dart';
import '../services/audio_feedback.dart';
import '../services/language_service.dart';


class LibraryPage extends StatefulWidget {
  const LibraryPage({Key? key}) : super(key: key);

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Map<String, String>> cars = [];
  String? selectedBrand;

  @override
  void initState() {
    super.initState();
    
    // audio: page open
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    _loadCsvData();
  }

  Future<void> _loadCsvData() async {
    final rawCsv = await rootBundle.loadString('assets/cars.csv');
    final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(rawCsv);
    final temp = <Map<String, String>>[];
    final descIndex = LanguageService.getDescriptionIndex(context);
    final featureIndex = LanguageService.getSpecialFeatureIndex(context);

    for (var values in rows) {
      if (values.length >= descIndex + 1 && values.length >= featureIndex + 1) {
        temp.add({
          'brand': values[0].toString().trim(),
          'model': values[1].toString().trim(),
          'description': values[descIndex].toString().trim(),
          'engineType': values[3].toString().trim(),
          'topSpeed': values[4].toString().trim(),
          'acceleration': values[5].toString().trim(),
          'horsepower': values[6].toString().trim(),
          'priceRange': values[7].toString().trim(),
          'year': values[8].toString().trim(),
          'origin': values[9].toString().trim(),
          'notableFeature': values[featureIndex].toString().trim(),
        });
      }
    }
    setState(() => cars = temp);
  }

  List<String> _getUniqueBrands() =>
      cars.map((c) => c['brand']!).toSet().toList();

  List<Map<String, String>> _getModelsForBrand(String brand) =>
      cars.where((c) => c['brand'] == brand).toList();

  String _formatFileName(String brand, String model) {
    final raw = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return raw
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join();
  }

  /// Build a single representative image from assets/model for the given brand/model.
  Widget _buildImage(String brand, String model) {
    final fileBase = _formatFileName(brand, model);
    final fileName = '${fileBase}4.webp';
    final assetPath = 'assets/model/$fileName';

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car, color: Colors.white54, size: 28),
                const SizedBox(height: 6),
                Text(
                  fileName,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cars.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: selectedBrand == null
          ? GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                // Brand tiles
                ..._getUniqueBrands().map((brand) {
                  final models = _getModelsForBrand(brand);
                  final firstModel = models.isNotEmpty ? models[0]['model']! : '';
                  return GestureDetector(
                    onTap: () {
                      try {
                        AudioFeedback.instance.playEvent(SoundEvent.tap);
                      } catch (_) {}
                      setState(() => selectedBrand = brand);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImage(brand, firstModel),
                          Container(
                            color: Colors.black26,
                            alignment: Alignment.center,
                            child: Text(
                              brand,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                // More brands coming soon
                GestureDetector(
                  onTap: () {
                    try {
                      AudioFeedback.instance.playEvent(SoundEvent.tap);
                    } catch (_) {}
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('categories.comingSoon'.tr()),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'categories.comingSoon'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      try {
                        AudioFeedback.instance.playEvent(SoundEvent.tap);
                      } catch (_) {}
                      setState(() => selectedBrand = null);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text('common.back'.tr()),
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    // ensure children is a List<Widget>
                    children: _getModelsForBrand(selectedBrand!).map((model) {
                      final modelName = model['model']!;
                      return GestureDetector(
                        onTap: () {
                          try {
                            AudioFeedback.instance.playEvent(SoundEvent.tap);
                          } catch (_) {}
                          _showModelDetails(context, model);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildImage(selectedBrand!, modelName),
                              Container(
                                color: Colors.black26,
                                alignment: Alignment.center,
                                child: Text(
                                  modelName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(), // <- important .toList()
                  ),
                ),
              ],
            ),
    );
  }

  void _showModelDetails(BuildContext context, Map<String, String> model) {
    final brand = model['brand']!;
    final modelName = model['model']!;
    final fileBase = _formatFileName(brand, modelName);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$brand – $modelName',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('${'library.description'.tr()}: ${model['description']}'),
              Text('${'library.engineType'.tr()}: ${model['engineType']}'),
              Text('${'library.topSpeed'.tr()}: ${model['topSpeed']}'),
              Text('${'library.acceleration'.tr()}: ${model['acceleration']}'),
              Text('${'library.horsepower'.tr()}: ${model['horsepower']}'),
              Text('${'library.priceRange'.tr()}: ${model['priceRange']}'),
              Text('${'library.year'.tr()}: ${model['year']}'),
              Text('${'library.origin'.tr()}: ${model['origin']}'),
              Text('${'library.notableFeature'.tr()}: ${model['notableFeature']}'),
              const SizedBox(height: 16),
              Text(
                'library.photos'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...List.generate(6, (index) {
                final imageFileName = '$fileBase$index.webp';
                final assetPath = 'assets/model/$imageFileName';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 160,
                          color: Colors.grey[900],
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car, color: Colors.white54, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  imageFileName,
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
