import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '1. Introduction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'LuhaRide is a technology platform that connects passengers and drivers for shared rides '
              'in Uttarakhand and nearby regions. We do not own or operate any vehicles and we are '
              'not a transport company or taxi operator.',
            ),
            SizedBox(height: 16),
            Text(
              '2. Platform Role & Liability',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Drivers are independent third-party providers. They are solely responsible for complying '
              'with applicable traffic laws, permits, insurance, and safety requirements. LuhaRide is '
              'not responsible for accidents, delays, loss, theft, or personal injury during trips, '
              'except to the limited extent required by applicable law.',
            ),
            SizedBox(height: 16),
            Text(
              '3. User Responsibilities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '• Provide accurate information (name, phone, email, vehicle details).\n'
              '• Respect other users and do not engage in abuse, harassment, or illegal activities.\n'
              '• Do not use the app for commercial transport if local law does not permit it.',
            ),
            SizedBox(height: 16),
            Text(
              '4. Driver Responsibilities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '• Maintain valid driving licence, RC, insurance, and permits as required by law.\n'
              '• Do not exceed legal seat capacity of the vehicle (app seat layout is only a guide).\n'
              '• Drive safely and follow all traffic rules and speed limits.\n'
              '• Do not misrepresent vehicle model, seat count, or route.',
            ),
            SizedBox(height: 16),
            Text(
              '5. Bookings & Cancellations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Rides may be cancelled by drivers or passengers in unforeseen situations. LuhaRide will '
              'try to notify affected users through the app. Frequent no-shows, misuse, or fraudulent '
              'bookings may lead to account restrictions or suspension.',
            ),
            SizedBox(height: 16),
            Text(
              '6. Payments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Unless clearly mentioned otherwise, payments are settled directly between driver and '
              'passenger (for example cash or UPI at the end of the ride). LuhaRide is not responsible '
              'for payment disputes between users.',
            ),
            SizedBox(height: 16),
            Text(
              '7. Data & Privacy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We store limited personal data (such as name, phone, ride history) to operate the service. '
              'We do not sell personal data to third parties. A separate Privacy Policy may provide more '
              'details about how data is collected and used.',
            ),
            SizedBox(height: 16),
            Text(
              '8. Account Suspension',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We may suspend or terminate accounts at our discretion in case of misuse, fraud, safety '
              'concerns, or violation of these Terms.',
            ),
            SizedBox(height: 16),
            Text(
              '9. Changes to Terms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We may update these Terms & Conditions from time to time. Continued use of the app after '
              'changes means you accept the updated Terms.',
            ),
            SizedBox(height: 24),
            Text(
              'Note: This text is for general guidance only. For production use, please get your Terms & '
              'Conditions and Privacy Policy reviewed by a qualified legal professional.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

