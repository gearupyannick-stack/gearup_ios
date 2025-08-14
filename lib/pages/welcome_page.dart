import 'dart:async';
import 'package:flutter/material.dart';
import 'create_account_page.dart';

class Slide {
  final String imagePath;
  Slide({required this.imagePath});
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);
  
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final List<Slide> slides = [
    Slide(imagePath: "assets/images/slide1.png"),
    Slide(imagePath: "assets/images/slide2.png"),
    Slide(imagePath: "assets/images/slide3.png"),
    Slide(imagePath: "assets/images/slide4.png"),
    Slide(imagePath: "assets/images/slide5.png"),
  ];

  final PageController _pageController = PageController();
  Timer? _timer;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Timer qui change la page toutes les 5 secondes
    _timer = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page?.round() ?? currentPage) + 1;
        if (nextPage >= slides.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView qui affiche les slides
          PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (int index) {
              setState(() {
                currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return SizedBox.expand(
                child: Image.asset(
                  slides[index].imagePath,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          // Titre en haut de l'écran
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Text(
              "Welcome to GearUp",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(blurRadius: 4, offset: Offset(2, 2), color: Colors.black54)
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Indicateur de slide (les 5 points) juste au-dessus du bouton
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (index) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == index ? 12 : 8,
                  height: currentPage == index ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentPage == index ? Colors.white : Colors.white54,
                  ),
                );
              }),
            ),
          ),
          // Bouton "Create an Account" positionné en bas
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateAccountPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Create an Account"),
            ),
          ),
        ],
      ),
    );
  }
}
