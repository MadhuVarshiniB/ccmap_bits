import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/profile_page.dart';
import '../screens/past_rides_page.dart';
import '../screens/wallet_page.dart';
import '../screens/admin/admin_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _supabase = Supabase.instance.client;
  
  String _displayName = 'Guest';
  String _displayEmail = '';
  String _displayPhone = '';
  String _displayGender = '';
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final email = user.email ?? '';

      final data = await _supabase
          .from('profiles')
          .select('full_name, phone_number, gender, role')
          .eq('id', user.id)
          .single();
          
      setState(() {
        _displayName = (data['full_name']?.toString().isNotEmpty ?? false) ? data['full_name'] : 'User';
        _displayEmail = email;
        _displayPhone = data['phone_number']?.toString() ?? '';
        _displayGender = data['gender']?.toString() ?? '';
        _userRole = data['role']?.toString() ?? 'user';
      });
    } catch (e) {
      debugPrint('Error loading drawer profile: $e');
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await _supabase.auth.signOut();
      if (context.mounted) {
        // Pops to the root 'AuthGate' widget which reactively presents LoginPage
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(_displayEmail.isNotEmpty ? _displayEmail : (_displayPhone.isNotEmpty ? _displayPhone : 'No email')),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            decoration: const BoxDecoration(color: Colors.green),
          ),

          // Phone chip (if available)
          if (_displayPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(_displayPhone,
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),

          if (_displayGender.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(_displayGender,
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Personal Info'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Past Rides'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PastRidesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Wallet'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WalletPage()));
            },
          ),
          if (_userRole == 'admin') ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
              title: const Text('Admin Panel', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage()));
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _handleLogout(context), // <== ACTUALLY LOGS OUT TO SUPABASE
          ),
        ],
      ),
    );
  }
}
