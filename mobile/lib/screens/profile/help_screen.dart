import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Ride kaise book karein?'),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'From aur To location select karein, date choose karein, phir list me se ride select karke '
                  '\"Select Seats & Book\" pe tap karein. Seat select karke confirm karein.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Payment kaise hoga?'),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Abhi payment ride ke end me directly driver ko hota hai (cash / UPI). '
                  'LuhaRide sirf driver aur passenger ko connect karta hai.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Driver verification ka process kya hai?'),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Profile > Become a Driver se documents submit karein. Admin documents verify karke '
                  'status \"approved\" karega, tab aap rides create kar sakte hain.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Safety Tips',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Trip se pehle driver aur gaadi verify karein'),
            subtitle: Text('App me dikh rahe driver name, photo, vehicle number ko ground pe match karein.'),
          ),
          const ListTile(
            leading: Icon(Icons.warning_amber_outlined),
            title: Text('Emergency ke liye 112 / local police ka number save rakhein'),
            subtitle: Text('Koi bhi emergency ho to turant official helplines par contact karein.'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Contact & Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.email_outlined),
            title: Text('Email'),
            subtitle: Text('support@luharide.com'),
          ),
          const ListTile(
            leading: Icon(Icons.phone_outlined),
            title: Text('WhatsApp Support'),
            subtitle: Text('+91-00000-00000'),
          ),
        ],
      ),
    );
  }
}

