import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
      ),
      home: const SettingsPage(),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        flexibleSpace: Container(
          margin: EdgeInsets.fromLTRB(80.0, 55.0, 80.0, 5.0),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/imgs/hku_logo.png'),
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(child: Text("Menu")),
            ListTile(title: Text('Logout')),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home, size: 40),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble, size: 40),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_rounded, size: 40),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_sharp, size: 40),
            label: 'Settings',
          ),
        ],
        selectedIndex: currentIndex,
        onDestinationSelected: (int value) {
          // Handle destination selection
          setState(() {
            currentIndex = value;
          });
        },
      ),
      body: currentIndex == 3
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                    height: 100,
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.deepPurple, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        'Setting',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                    height: 100,
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.deepPurple, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                    height: 100,
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.deepPurple, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        'Contact Us',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                    height: 100,
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.deepPurple, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        '...',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                    height: 100,
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.deepPurple, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        'logout',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(child: Text('Page ${currentIndex + 1}')),
    );
  }
}
