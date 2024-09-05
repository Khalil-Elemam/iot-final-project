import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView.builder(
        itemCount: 10, // Replace with actual notification count
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.notification_important),
            title: Text('Notification #$index'),
            subtitle: Text('Details of notification $index'),
            onTap: () {
              // Handle notification tap
            },
          );
        },
      ),
    );
  }
}
