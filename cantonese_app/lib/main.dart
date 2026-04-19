import 'package:flutter/material.dart';
import 'route_observer.dart';
import 'screens/translate_screen.dart';
import 'screens/annotate_screen.dart';
import 'screens/explain_screen.dart';
void main() {
  runApp(const CantoneseApp());
}

class CantoneseApp extends StatelessWidget {
  const CantoneseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '粤学通',
      navigatorObservers: [appRouteObserver],
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TranslateScreen(),
    AnnotateScreen(),
    ExplainScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 用 IndexedStack 保持页面状态，切换 Tab 不会销毁 State
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.translate),
            label: '翻译',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.subtitles),
            label: '注音',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: '解释',
          ),
        ],
      ),
    );
  }
}
