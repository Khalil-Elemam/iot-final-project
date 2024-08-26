import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 28, color: Colors.white),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Enable Notifications',
                    style: TextStyle(color: Colors.white)),
                value: true, // This would be dynamic based on user preference
                onChanged: (bool value) {
                  // Handle the change
                },
              ),
              SwitchListTile(
                title: const Text('Dark Mode',
                    style: TextStyle(color: Colors.white)),
                value: true, // This would be dynamic based on user preference
                onChanged: (bool value) {
                  // Handle the change
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
