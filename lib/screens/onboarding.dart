import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../data/constants.dart';

const _onboardingTextStyle = TextStyle(fontSize: 20);

class OnboardingPage extends StatelessWidget {
  final VoidCallback onDone;

  const OnboardingPage({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: IntroductionScreen(
        dotsDecorator: DotsDecorator(
          activeColor: primaryColor,
          size: const Size(6.0, 6.0),
          activeSize: const Size(8.0, 8.0),
          spacing: const EdgeInsets.symmetric(horizontal: 3.0),
        ),
        controlsPadding: const EdgeInsets.symmetric(horizontal: 4.0),
        bodyPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        pages: [
          PageViewModel(
            title: "Welcome to PandaVerse!",
            bodyWidget: const Text(
              "Learn Chinese through music 🎵\n\n"
              "View lyrics with pinyin and get instant English translations by tapping any word.\n\n"
              "You supply the name of the song and artist, and the app automatically searches for the lyrics.",
              textAlign: TextAlign.center,
              style: _onboardingTextStyle,
            ),
            image: Center(
              child: Icon(
                Icons.music_note,
                size: screenWidth / 2,
                color: primaryColor,
              ),
            ),
          ),
          PageViewModel(
            title: "Interactive Learning",
            bodyWidget: const Text(
              "You can also manually input lyrics or text you would like word-by-word translation for.\n\n"
              "Uses an offline dictionary so your data stays private.",
              textAlign: TextAlign.center,
              style: _onboardingTextStyle,
            ),
            image: Center(
              child: Icon(
                Icons.touch_app,
                size: screenWidth / 2,
                color: primaryColor,
              ),
            ),
          ),
        ],
        onDone: onDone,
        showSkipButton: false,
        showBackButton: false,
        next: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "Next",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
        done: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "Let's Go!",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
