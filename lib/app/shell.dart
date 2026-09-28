import 'package:flutter/material.dart';

import '../features/connection/screens/home_screen.dart';
import '../features/files/screens/files_screen.dart';
import '../features/photos/screens/photos_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import 'theme.dart';

/// Persistent app shell providing bottom navigation between the 4 core sections:
/// HOME / FILES / PHOTOS / SETTINGS.
class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int _currentIndex;

  static const List<Widget> _pages = [
    HomeScreen(),
    FilesScreen(),
    PhotosScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  /// Switches active tab programmatically from descendant widgets.
  void setTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.background,
          border: Border(
            top: BorderSide(color: palette.border, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: setTab,
          backgroundColor: palette.background,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: palette.textPrimary,
          unselectedItemColor: palette.textMuted,
          selectedLabelStyle: AppTypography.mutedMetadata.copyWith(
            color: palette.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
          unselectedLabelStyle: AppTypography.mutedMetadata.copyWith(
            color: palette.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, key: ValueKey('nav_home')),
              activeIcon: Icon(Icons.home, key: ValueKey('nav_home')),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined, key: ValueKey('nav_files')),
              activeIcon: Icon(Icons.folder, key: ValueKey('nav_files')),
              label: 'FILES',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined, key: ValueKey('nav_photos')),
              activeIcon: Icon(Icons.photo_library, key: ValueKey('nav_photos')),
              label: 'PHOTOS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined, key: ValueKey('nav_settings')),
              activeIcon: Icon(Icons.settings, key: ValueKey('nav_settings')),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }
}
