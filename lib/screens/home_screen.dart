import 'package:flutter/material.dart';
import '../data/constants.dart';
import 'song_list_screen.dart';
import 'vocabulary_review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    SongListScreen(),
    VocabularyReviewScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Songs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Vocabulary',
          ),
        ],
      ),
    );
  }
}
