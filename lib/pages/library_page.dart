import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:easy_localization/easy_localization.dart';
import 'package:csv/csv.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../services/audio_feedback.dart';
import '../services/language_service.dart';
import '../services/brand_info.dart';
import '../services/tutorial_service.dart';


class LibraryPage extends StatefulWidget {
  const LibraryPage({Key? key}) : super(key: key);

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Map<String, String>> cars = [];
  String? selectedBrand;
  bool _isBrandInfoExpanded = false;
  bool _isDataLoaded = false;
  bool _tabIntroShown = false;

  @override
  void initState() {
    super.initState();

    // audio: page open
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTabIntro());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      _loadData();
      _isDataLoaded = true;
    }
  }

  Future<void> _maybeShowTabIntro() async {
    if (_tabIntroShown) return;
    final tutorialService = TutorialService.instance;
    final stage = await tutorialService.getTutorialStage();
    if (stage != TutorialStage.tabsReady) return;
    if (await tutorialService.hasShownTabIntro('library')) return;
    await tutorialService.markTabIntroShown('library');
    _tabIntroShown = true;
    if (!mounted) return;
  }

  Future<void> _loadData() async {
    final String languageCode = context.locale.languageCode;
    await BrandInfoData.loadBrands(languageCode);
    await _loadCsvData();
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
                      setState(() {
                        selectedBrand = null;
                        _isBrandInfoExpanded = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text('common.back'.tr()),
                  ),
                ),
                _buildBrandInfoCard(selectedBrand!),
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

  Widget _buildBrandInfoCard(String brandKey) {
    final brandInfo = BrandInfoData.getBrandInfo(brandKey);
    if (brandInfo == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                try {
                  AudioFeedback.instance.playEvent(SoundEvent.tap);
                } catch (_) {}
                setState(() {
                  _isBrandInfoExpanded = !_isBrandInfoExpanded;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          brandInfo.countryFlag,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brandInfo.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${brandInfo.country} | ',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Est. ${brandInfo.foundedYear}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _isBrandInfoExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${brandInfo.tagline}"',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (_isBrandInfoExpanded) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.stars,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  brandInfo.specialty,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              brandInfo.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelDetails(BuildContext context, Map<String, String> model) {
    final brand = model['brand']!;
    final modelName = model['model']!;
    final fileBase = _formatFileName(brand, modelName);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero Image Header
                Stack(
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      child: Image.asset(
                        'assets/model/${fileBase}0.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child: Icon(Icons.directions_car, color: Colors.white54, size: 48),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 56,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brand,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            modelName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          try {
                            AudioFeedback.instance.playEvent(SoundEvent.tap);
                          } catch (_) {}
                          Navigator.of(ctx).pop();
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description
                        if (model['description']?.isNotEmpty ?? false) ...[
                          Text(
                            model['description']!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Specifications Title
                        const Text(
                          'Specifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Specs Grid
                        _buildSpecCard(Icons.settings, 'library.engineType'.tr(), model['engineType']!),
                        const SizedBox(height: 12),
                        _buildSpecCard(Icons.speed, 'library.topSpeed'.tr(), model['topSpeed']!),
                        const SizedBox(height: 12),
                        _buildSpecCard(Icons.rocket_launch, 'library.acceleration'.tr(), model['acceleration']!),
                        const SizedBox(height: 12),
                        _buildSpecCard(Icons.flash_on, 'library.horsepower'.tr(), model['horsepower']!),
                        const SizedBox(height: 12),
                        _buildSpecCard(Icons.attach_money, 'library.priceRange'.tr(), model['priceRange']!),
                        const SizedBox(height: 12),
                        _buildSpecCard(Icons.calendar_today, 'library.year'.tr(), model['year']!),
                        const SizedBox(height: 12),
                        _buildSpecCard(Icons.flag, 'library.origin'.tr(), model['origin']!),
                        const SizedBox(height: 12),
                        _buildSpecCard(Icons.star, 'library.notableFeature'.tr(), model['notableFeature']!),

                        const SizedBox(height: 24),

                        // Photo Gallery
                        Text(
                          'library.photos'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPhotoCarousel(fileBase, context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel(String fileBase, BuildContext context) {
    int currentIndex = 0;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Column(
          children: [
            CarouselSlider.builder(
              itemCount: 6,
              options: CarouselOptions(
                height: 200,
                viewportFraction: 0.85,
                enlargeCenterPage: true,
                enableInfiniteScroll: false,
                onPageChanged: (index, reason) {
                  setState(() {
                    currentIndex = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                final imageFileName = '$fileBase$index.webp';
                final assetPath = 'assets/model/$imageFileName';
                return GestureDetector(
                  onTap: () {
                    try {
                      AudioFeedback.instance.playEvent(SoundEvent.tap);
                    } catch (_) {}
                    _showFullScreenImage(context, fileBase, index);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child: Icon(Icons.directions_car, color: Colors.white54, size: 48),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: currentIndex == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: currentIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, String fileBase, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _FullScreenImageViewer(
          fileBase: fileBase,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final String fileBase;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.fileBase,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late int currentIndex;
  final CarouselSliderController _controller = CarouselSliderController();

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: CarouselSlider.builder(
              carouselController: _controller,
              itemCount: 6,
              options: CarouselOptions(
                height: MediaQuery.of(context).size.height,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                enableInfiniteScroll: false,
                initialPage: widget.initialIndex,
                onPageChanged: (index, reason) {
                  setState(() {
                    currentIndex = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                final imageFileName = '${widget.fileBase}$index.webp';
                final assetPath = 'assets/model/$imageFileName';
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(Icons.directions_car, color: Colors.white54, size: 48),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                try {
                  AudioFeedback.instance.playEvent(SoundEvent.tap);
                } catch (_) {}
                Navigator.of(context).pop();
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return GestureDetector(
                  onTap: () {
                    _controller.animateToPage(index);
                  },
                  child: Container(
                    width: currentIndex == index ? 32 : 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${currentIndex + 1} / 6',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
