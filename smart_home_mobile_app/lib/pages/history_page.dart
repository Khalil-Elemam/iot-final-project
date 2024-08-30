import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
              // History Title
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // First History Item
              _buildHistoryItem(
                  'Motion detect at front door', '26/8/24, 4:26AM'),
              const SizedBox(height: 20),

              // Second History Item
              _buildHistoryItem('Fire Detect', '26/8/24, 4:20AM'),
              const SizedBox(height: 20),

              // Vertical Divider and Text
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vertical Line
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Container(
                        width: 4,
                        color: Colors.white,
                      ),
                    ),
                    // Vertical Text
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          'No Emergency Currently',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dot Icon
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: Icon(
            Icons.fiber_manual_record,
            color: Colors.white,
            size: 20,
          ),
        ),
        // Text Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
