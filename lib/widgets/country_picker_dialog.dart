import 'package:flutter/material.dart';

/// Dialog for selecting a country
class CountryPickerDialog extends StatefulWidget {
  final String? initialCountry;

  const CountryPickerDialog({Key? key, this.initialCountry}) : super(key: key);

  @override
  State<CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<CountryPickerDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Popular countries for racing (top of list)
  static const List<CountryData> _popularCountries = [
    CountryData(code: 'US', name: 'United States'),
    CountryData(code: 'GB', name: 'United Kingdom'),
    CountryData(code: 'DE', name: 'Germany'),
    CountryData(code: 'FR', name: 'France'),
    CountryData(code: 'IT', name: 'Italy'),
    CountryData(code: 'JP', name: 'Japan'),
    CountryData(code: 'ES', name: 'Spain'),
    CountryData(code: 'BR', name: 'Brazil'),
    CountryData(code: 'CA', name: 'Canada'),
    CountryData(code: 'AU', name: 'Australia'),
  ];

  // All countries (ISO 3166-1 alpha-2)
  static const List<CountryData> _allCountries = [
    CountryData(code: 'AF', name: 'Afghanistan'),
    CountryData(code: 'AL', name: 'Albania'),
    CountryData(code: 'DZ', name: 'Algeria'),
    CountryData(code: 'AR', name: 'Argentina'),
    CountryData(code: 'AM', name: 'Armenia'),
    CountryData(code: 'AU', name: 'Australia'),
    CountryData(code: 'AT', name: 'Austria'),
    CountryData(code: 'AZ', name: 'Azerbaijan'),
    CountryData(code: 'BH', name: 'Bahrain'),
    CountryData(code: 'BD', name: 'Bangladesh'),
    CountryData(code: 'BY', name: 'Belarus'),
    CountryData(code: 'BE', name: 'Belgium'),
    CountryData(code: 'BR', name: 'Brazil'),
    CountryData(code: 'BG', name: 'Bulgaria'),
    CountryData(code: 'CA', name: 'Canada'),
    CountryData(code: 'CL', name: 'Chile'),
    CountryData(code: 'CN', name: 'China'),
    CountryData(code: 'CO', name: 'Colombia'),
    CountryData(code: 'CR', name: 'Costa Rica'),
    CountryData(code: 'HR', name: 'Croatia'),
    CountryData(code: 'CY', name: 'Cyprus'),
    CountryData(code: 'CZ', name: 'Czech Republic'),
    CountryData(code: 'DK', name: 'Denmark'),
    CountryData(code: 'EG', name: 'Egypt'),
    CountryData(code: 'EE', name: 'Estonia'),
    CountryData(code: 'FI', name: 'Finland'),
    CountryData(code: 'FR', name: 'France'),
    CountryData(code: 'GE', name: 'Georgia'),
    CountryData(code: 'DE', name: 'Germany'),
    CountryData(code: 'GR', name: 'Greece'),
    CountryData(code: 'HK', name: 'Hong Kong'),
    CountryData(code: 'HU', name: 'Hungary'),
    CountryData(code: 'IS', name: 'Iceland'),
    CountryData(code: 'IN', name: 'India'),
    CountryData(code: 'ID', name: 'Indonesia'),
    CountryData(code: 'IR', name: 'Iran'),
    CountryData(code: 'IQ', name: 'Iraq'),
    CountryData(code: 'IE', name: 'Ireland'),
    CountryData(code: 'IL', name: 'Israel'),
    CountryData(code: 'IT', name: 'Italy'),
    CountryData(code: 'JP', name: 'Japan'),
    CountryData(code: 'JO', name: 'Jordan'),
    CountryData(code: 'KZ', name: 'Kazakhstan'),
    CountryData(code: 'KE', name: 'Kenya'),
    CountryData(code: 'KW', name: 'Kuwait'),
    CountryData(code: 'LV', name: 'Latvia'),
    CountryData(code: 'LB', name: 'Lebanon'),
    CountryData(code: 'LT', name: 'Lithuania'),
    CountryData(code: 'LU', name: 'Luxembourg'),
    CountryData(code: 'MY', name: 'Malaysia'),
    CountryData(code: 'MT', name: 'Malta'),
    CountryData(code: 'MX', name: 'Mexico'),
    CountryData(code: 'MC', name: 'Monaco'),
    CountryData(code: 'MA', name: 'Morocco'),
    CountryData(code: 'NL', name: 'Netherlands'),
    CountryData(code: 'NZ', name: 'New Zealand'),
    CountryData(code: 'NG', name: 'Nigeria'),
    CountryData(code: 'NO', name: 'Norway'),
    CountryData(code: 'OM', name: 'Oman'),
    CountryData(code: 'PK', name: 'Pakistan'),
    CountryData(code: 'PE', name: 'Peru'),
    CountryData(code: 'PH', name: 'Philippines'),
    CountryData(code: 'PL', name: 'Poland'),
    CountryData(code: 'PT', name: 'Portugal'),
    CountryData(code: 'QA', name: 'Qatar'),
    CountryData(code: 'RO', name: 'Romania'),
    CountryData(code: 'RU', name: 'Russia'),
    CountryData(code: 'SA', name: 'Saudi Arabia'),
    CountryData(code: 'RS', name: 'Serbia'),
    CountryData(code: 'SG', name: 'Singapore'),
    CountryData(code: 'SK', name: 'Slovakia'),
    CountryData(code: 'SI', name: 'Slovenia'),
    CountryData(code: 'ZA', name: 'South Africa'),
    CountryData(code: 'KR', name: 'South Korea'),
    CountryData(code: 'ES', name: 'Spain'),
    CountryData(code: 'LK', name: 'Sri Lanka'),
    CountryData(code: 'SE', name: 'Sweden'),
    CountryData(code: 'CH', name: 'Switzerland'),
    CountryData(code: 'TW', name: 'Taiwan'),
    CountryData(code: 'TH', name: 'Thailand'),
    CountryData(code: 'TR', name: 'Turkey'),
    CountryData(code: 'UA', name: 'Ukraine'),
    CountryData(code: 'AE', name: 'United Arab Emirates'),
    CountryData(code: 'GB', name: 'United Kingdom'),
    CountryData(code: 'US', name: 'United States'),
    CountryData(code: 'UY', name: 'Uruguay'),
    CountryData(code: 'VE', name: 'Venezuela'),
    CountryData(code: 'VN', name: 'Vietnam'),
  ];

  List<CountryData> get _filteredCountries {
    if (_searchQuery.isEmpty) {
      // Show popular countries first, then all others
      final Set<String> popularCodes = _popularCountries.map((c) => c.code).toSet();
      final otherCountries = _allCountries
          .where((c) => !popularCodes.contains(c.code))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return [..._popularCountries, ...otherCountries];
    }

    final query = _searchQuery.toLowerCase();
    return _allCountries
        .where((country) =>
            country.name.toLowerCase().contains(query) ||
            country.code.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String _getCountryFlag(String countryCode) {
    if (countryCode.length != 2) return '🏁';

    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;

    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCountries = _filteredCountries;

    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Your Country',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search countries...',
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Popular countries label (only when not searching)
            if (_searchQuery.isEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Popular Countries',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Countries list
            Expanded(
              child: ListView.builder(
                itemCount: filteredCountries.length,
                itemBuilder: (context, index) {
                  final country = filteredCountries[index];
                  final isPopular = _searchQuery.isEmpty &&
                      _popularCountries.any((c) => c.code == country.code);
                  final showDivider = _searchQuery.isEmpty &&
                      index == _popularCountries.length - 1;

                  return Column(
                    children: [
                      if (showDivider) ...[
                        const SizedBox(height: 8),
                        Divider(color: Colors.white30),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'All Countries',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ListTile(
                        leading: Text(
                          _getCountryFlag(country.code),
                          style: TextStyle(fontSize: 32),
                        ),
                        title: Text(
                          country.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isPopular ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          country.code,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        selected: widget.initialCountry == country.code,
                        selectedTileColor: Colors.blue.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          Navigator.pop(context, country.code);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountryData {
  final String code;
  final String name;

  const CountryData({required this.code, required this.name});
}
