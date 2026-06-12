import 'package:flutter/material.dart';
import 'detai_page.dart';

void main() {
  runApp(const Carekids());
}

class Carekids extends StatelessWidget {
  const Carekids({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE0F2F1), // พื้นหลังสีเขียวมิ้นต์อ่อนๆ
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: โปรไฟล์และ Shared Access
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(radius: 25, backgroundImage: NetworkImage('https://via.placeholder.com/150')),
                      SizedBox(width: 12),
                      Text("NONG SAISON", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.people_outline, size: 20, color: Colors.blueGrey),
                    label: const Text("Shared Access", style: TextStyle(color: Colors.blueGrey)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Quick Summary Card
              const Text("Quick Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildSummaryItem("Weight: 10.5 kg (75th percentile)", null),
                    const Divider(height: 32),
                    _buildSummaryItem("Next Vaccine:\nin 15 days (February)", Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Menu Grid (ปุ่ม 4 ปุ่ม)
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // 1. ส่งชื่อ, 2. ส่งไอคอน, 3. ส่งหน้าปลายทาง (DetailPage)
                    _buildMenuCard(context, 'CALCULATE DOSE', Icons.vaccines, const DetailPage(title: "Calculate Dose")),
                    _buildMenuCard(context, 'LOG SYMPTOMS', Icons.assignment_outlined, const DetailPage(title: "Log Symptoms")),

                    // ตรงนี้แหละที่พี่สาวต้องลบ Colors.white, Colors.black ออก!
                    _buildMenuCard(context, 'VACCINE SCHEDULE', Icons.calendar_month, const DetailPage(title: "Vaccine Schedule")),
                    _buildMenuCard(context, 'LOG EXPENSES', Icons.attach_money, const DetailPage(title: "Log Expenses")),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // 4. Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Hospital Map'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  // Widget ช่วยสร้างบรรทัดใน Summary
  Widget _buildSummaryItem(String text, IconData? icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        if (icon != null) Icon(icon, color: Colors.grey),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Widget destinationPage) {
    return InkWell(
      onTap: () {
        // พอกดแล้วให้เด้งไปหน้าปลายทางทันที
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationPage),
        );
      },
      child: Ink( // ใช้ Ink แทน Container เพื่อให้สีตอนกด (Ripple) มันโชว์จึ้งๆ
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 30),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}