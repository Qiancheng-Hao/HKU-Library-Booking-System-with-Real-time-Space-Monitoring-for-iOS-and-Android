import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'booking_history_screen.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  Future<void> _handleAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      await authProvider.logout();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logged out')));
      }
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to get isLoggedIn state
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                  height: 100,
                  width: 350,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.deepPurple, width: 2.0),
                  ),
                  child: const Center(
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
                  margin: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                  height: 100,
                  width: 350,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.deepPurple, width: 2.0),
                  ),
                  child: const Center(
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
                  margin: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                  height: 100,
                  width: 350,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.deepPurple, width: 2.0),
                  ),
                  child: const Center(
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
                GestureDetector(
                  onTap: () async {
                    try {
                      final health = await ApiService.getHealth();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Backend Connected: ${health['status']}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connection Failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                    height: 100,
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.deepPurple, width: 2.0),
                    ),
                    child: const Center(
                      child: Text(
                        'Test Connection',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (authProvider.isLoggedIn)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookingHistoryScreen(),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
                      height: 100,
                      width: 350,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: Colors.deepPurple,
                          width: 2.0,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'My Reservations',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _handleAuth,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
                    height: 100,
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.deepPurple, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        authProvider.isLoggedIn ? 'Logout' : 'Login',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
