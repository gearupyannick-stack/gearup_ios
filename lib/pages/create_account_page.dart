// lib/pages/create_account_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/lives_storage.dart';
import 'preload_page.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({Key? key}) : super(key: key);

  @override
  _CreateAccountPageState createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  String? _username;
  String? _favoriteBrand;
  String? _favoriteModel;
  String? _preferredCarStyle;
  String? _motorsportsInterest;
  List<String> _brandOptions = [];
  Map<String, List<String>> _brandToModels = {};
  bool _loadingCarData = true;

  final _carStyleOptions = [
    'Sedan', 'Coupe', 'SUV', 'Convertible', 'Sports Car', 'Other'
  ];
  final _motorsportsOptions = [
    'Formula 1', 'Rally', 'NASCAR', 'None', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadCarData();
  }

  Future<void> _loadCarData() async {
    try {
      final raw = await rootBundle.loadString('assets/cars.csv');
      final lines = const LineSplitter().convert(raw);
      final brands = <String>{};
      final map = <String, Set<String>>{};
      for (var line in lines) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          final b = parts[0].trim(), m = parts[1].trim();
          brands.add(b);
          map.putIfAbsent(b, () => <String>{}).add(m);
        }
      }
      setState(() {
        _brandOptions = brands.toList()..sort();
        _brandToModels = {
          for (var b in _brandOptions) b: (map[b]!.toList()..sort())
        };
        _loadingCarData = false;
      });
    } catch (e) {
      print("Error loading cars.csv: $e");
      setState(() => _loadingCarData = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasProfile', true);
    await prefs.setString('username', _username!);
    await prefs.setString('favoriteBrand', _favoriteBrand!);
    await prefs.setString('favoriteModel', _favoriteModel!);
    await prefs.setString('preferredCarStyle', _preferredCarStyle ?? '');
    await prefs.setString('motorsportsInterest', _motorsportsInterest ?? '');

    if (!prefs.containsKey('createdAt')) {
      final now = DateTime.now().toLocal();
      await prefs.setString('createdAt', now.toIso8601String().split('T').first);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PreloadPage(
          initialLives: 5,
          livesStorage: LivesStorage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(221, 6, 0, 56),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 5, 0, 48),
        iconTheme: const IconThemeData(color: Colors.white70),
        title: const Text("Create Account", style: TextStyle(color: Colors.white70)),
      ),
      body: ListView(
        children: [
          Image.asset(
            "assets/images/create_account.png",
            fit: BoxFit.cover,
            height: 200,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _loadingCarData
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Username",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Enter a username" : null,
                          onSaved: (v) => _username = v,
                        ),
                        const SizedBox(height: 12),
                        // Favorite Brand
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color.fromARGB(221, 6, 0, 56),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Favorite Car Brand",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                          items: _brandOptions
                              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _favoriteBrand = v;
                              _favoriteModel = null;
                            });
                          },
                          validator: (v) => v == null ? "Select a brand" : null,
                          onSaved: (v) => _favoriteBrand = v,
                        ),
                        const SizedBox(height: 12),
                        // Favorite Model
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color.fromARGB(221, 6, 0, 56),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Favorite Car Model",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                          items: _favoriteBrand == null
                              ? []
                              : _brandToModels[_favoriteBrand]!
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                          onChanged: (v) => setState(() => _favoriteModel = v),
                          validator: (v) => v == null ? "Select a model" : null,
                          onSaved: (v) => _favoriteModel = v,
                        ),
                        const SizedBox(height: 12),
                        // Preferred Style (opt)
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color.fromARGB(221, 6, 0, 56),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Preferred Car Style (optional)",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                          items: _carStyleOptions
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setState(() => _preferredCarStyle = v),
                          onSaved: (v) => _preferredCarStyle = v,
                        ),
                        const SizedBox(height: 12),
                        // Motorsports (opt)
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color.fromARGB(221, 6, 0, 56),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Motorsports Interest (optional)",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                          items: _motorsportsOptions
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) => setState(() => _motorsportsInterest = v),
                          onSaved: (v) => _motorsportsInterest = v,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text("Create Account"),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}