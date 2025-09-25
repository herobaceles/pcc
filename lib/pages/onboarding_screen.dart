import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "description":
          "Your one-stop app to easily locate PCC branches anytime, anywhere.",
      "image": "assets/WELCOME.png",
      "button": "Next",
    },
    {
      "description":
          "Search and navigate to PCC branches instantly with real-time maps.",
      "image": "assets/location.png",
      "button": "Next",
    },
    {
      "description":
          "From branch details to navigation, PCC Locator is here to serve you better.",
      "image": "assets/branch.png",
      "button": "Get Started",
    },
  ];

  /// Save onboarding completion flag
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  /// Build dot indicators
  Widget _buildIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? const Color(0xFF0255C2) // PCC Blue
            : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔹 PageView for slides
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final isLastPage = index == onboardingData.length - 1;

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 🖼️ Image (slightly smaller so text can sit closer)
                      Expanded(
                        flex: 6, // less height for image
                        child: Image.asset(
                          onboardingData[index]["image"]!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10), // tighter gap
                      // 📄 Description (bigger text, closer to image)
                      Text(
                        onboardingData[index]["description"]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20, // bigger text
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          height: 1.4, // line spacing for readability
                        ),
                      ),
                      const SizedBox(height: 25),

                      // 👉 Action Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF0255C2), // PCC Blue
                        ),
                        onPressed: () async {
                          if (isLastPage) {
                            await _completeOnboarding();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SplashScreen(),
                              ),
                            );
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          }
                        },
                        child: Text(
                          onboardingData[index]["button"]!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Skip button (not on last page)
                      if (!isLastPage)
                        TextButton(
                          onPressed: () async {
                            await _completeOnboarding();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SplashScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Skip",
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 🔹 Dot Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              onboardingData.length,
              (index) => _buildIndicator(index),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
