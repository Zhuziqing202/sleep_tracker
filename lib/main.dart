import 'package:flutter/cupertino.dart';
import 'screens/start_sleep_screen.dart';
import 'screens/sleep_record_screen.dart';
import 'screens/settings_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';  // 添加这行

void main() {
  runApp(const SleepTrackerApp());
}

class SleepTrackerApp extends StatelessWidget {
  const SleepTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '睡眠记录',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool isDarkMode = false;  // 添加深色模式状态

  static const List<Widget> _pages = <Widget>[
    StartSleepScreen(),
    SleepRecordScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: isDarkMode ? CupertinoColors.black : null,  // 根据模式设置背景色
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.bed),  // 睡眠图标
            label: '开始睡眠',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.chartLine),  // 图表图标
            label: '睡眠记录',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.gear),  // 设置图标
            label: '设置',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      tabBuilder: (context, index) => _pages[index],
    );
  }
} 