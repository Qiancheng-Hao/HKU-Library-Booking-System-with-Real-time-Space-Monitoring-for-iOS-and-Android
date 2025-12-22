import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
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
                      content: Text('Backend Connected: ${health['status']}'),
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
    );
  }
}
