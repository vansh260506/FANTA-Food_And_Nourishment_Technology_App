// ═══════════════════════════════════════════════════════════════
//  FANTA APP — Food & Nutrition Transport
//  Complete, runnable main.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

// ═══════════════════════════════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FantaApp());
}

// ═══════════════════════════════════════════════════════════════
//  APP ROOT + THEME
// ═══════════════════════════════════════════════════════════════

class FantaApp extends StatelessWidget {
  const FantaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fanta App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════

void showFancySnackBar(BuildContext context, String message,
    {bool isError = false}) {
  final snackBar = SnackBar(
    content: Text(
      message,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    backgroundColor:
        isError ? Colors.redAccent.shade400 : Colors.green.shade600,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 4,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  FadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, page) {
            return FadeTransition(opacity: animation, child: page);
          },
        );
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

// ═══════════════════════════════════════════════════════════════
//  SERVICES
// ═══════════════════════════════════════════════════════════════

class UserProfile {
  final String uid;
  final String? name;
  final String? phone;
  final String? role;

  UserProfile({required this.uid, this.name, this.phone, this.role});
}

class UserService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _db.ref('users/${user.uid}').get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return UserProfile(
          uid: user.uid,
          name: data['name'],
          phone: data['phone'],
          role: data['role'],
        );
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    return null;
  }
}

class LocationService {
  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please enable GPS.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied. '
          'Please enable them in settings.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  double? distanceInKm(String? a, String? b) {
    if (a == null || b == null) return null;
    final pa = a.split(',');
    final pb = b.split(',');
    if (pa.length != 2 || pb.length != 2) return null;

    final lat1 = double.tryParse(pa[0]);
    final lon1 = double.tryParse(pa[1]);
    final lat2 = double.tryParse(pb[0]);
    final lon2 = double.tryParse(pb[1]);
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }
}

// ═══════════════════════════════════════════════════════════════
//  AUTH GATE
// ═══════════════════════════════════════════════════════════════

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) return const HomePage();
        return const WelcomePage();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WELCOME
// ═══════════════════════════════════════════════════════════════

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fanta App')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤝', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 8),
            const Text(
              'Fanta App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const Text('Share food, spread hope'),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      FadePageRoute(child: const LoginPage()),
                    ),
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      FadePageRoute(child: const RegisterChoice()),
                    ),
                    child: const Text('Register (Donor / Receiver)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  LOGIN
// ═══════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          FadePageRoute(child: const HomePage()),
          (r) => false,
        );
      }
    } on FirebaseAuthException {
      if (mounted) {
        showFancySnackBar(
          context,
          'Incorrect email or password. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Login failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  REGISTER
// ═══════════════════════════════════════════════════════════════

class RegisterChoice extends StatelessWidget {
  const RegisterChoice({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                FadePageRoute(child: const RegisterPage(role: 'donor')),
              ),
              child: const Text('Donor'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                FadePageRoute(child: const RegisterPage(role: 'receiver')),
              ),
              child: const Text('Receiver'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  final String role;
  const RegisterPage({required this.role, super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;

  Future<void> _register() async {
    if (_email.text.isEmpty ||
        _password.text.isEmpty ||
        _name.text.isEmpty ||
        _phone.text.isEmpty) {
      showFancySnackBar(context, 'Please fill all fields.', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      final uid = cred.user!.uid;
      await FirebaseDatabase.instance.ref('users/$uid').set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'role': widget.role,
      });
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          FadePageRoute(child: const HomePage()),
          (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Register failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register as ${widget.role.capitalize()}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HOME
// ═══════════════════════════════════════════════════════════════

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fanta App')),
      drawer: const AppDrawer(),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Welcome to Fanta App!\n\nOpen the menu to get started.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DRAWER
// ═══════════════════════════════════════════════════════════════

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<String?> _getUserRole() async {
    final profile = await UserService().getCurrentUserProfile();
    return profile?.role;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<String?>(
        future: _getUserRole(),
        builder: (context, snapshot) {
          final role = snapshot.data;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                child: const Center(
                  child: Text(
                    'Fanta Menu',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    FadePageRoute(child: const HomePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    FadePageRoute(child: const ProfilePage()),
                  );
                },
              ),
              if (role == 'donor' || role == 'receiver')
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('My Impact'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      FadePageRoute(child: const MyImpactPage()),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('My History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    FadePageRoute(child: const HistoryPage()),
                  );
                },
              ),
              if (role == 'donor')
                ListTile(
                  leading: const Icon(Icons.volunteer_activism),
                  title: const Text('Donor Form'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      FadePageRoute(child: const DonorForm()),
                    );
                  },
                ),
              if (role == 'receiver')
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Receiver Form'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      FadePageRoute(child: const ReceiverForm()),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('Driver Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    FadePageRoute(child: const DriverPage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      FadePageRoute(child: const WelcomePage()),
                      (r) => false,
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROFILE
// ═══════════════════════════════════════════════════════════════

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _userService = UserService();
  late final DatabaseReference _userRef;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = _userService.currentUser;
    if (user != null) {
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _loadUserData();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadUserData() async {
    final profile = await _userService.getCurrentUserProfile();
    if (profile != null) {
      _nameController.text = profile.name ?? '';
      _phoneController.text = profile.phone ?? '';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveUserData() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      showFancySnackBar(
        context,
        'Name and phone cannot be empty.',
        isError: true,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _userRef.update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      if (mounted) {
        showFancySnackBar(context, 'Profile updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Update failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveUserData,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DONOR FORM (with Geolocator)
// ═══════════════════════════════════════════════════════════════

class DonorForm extends StatefulWidget {
  const DonorForm({super.key});
  @override
  State<DonorForm> createState() => _DonorFormState();
}

class _DonorFormState extends State<DonorForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _quantity = TextEditingController();
  final _location = TextEditingController();
  bool _saving = false;
  bool _fetchingLocation = false;

  final _userService = UserService();
  final _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final profile = await _userService.getCurrentUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _name.text = profile.name ?? '';
        _phone.text = profile.phone ?? '';
      });
    }
  }

  Future<void> _getLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _location.text = '${pos.latitude.toStringAsFixed(6)},'
              '${pos.longitude.toStringAsFixed(6)}';
        });
        showFancySnackBar(
          context,
          'Location captured (±${pos.accuracy.toStringAsFixed(0)} m)',
        );
      }
    } on String catch (msg) {
      if (mounted) showFancySnackBar(context, msg, isError: true);
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Location error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _saveDonor() async {
    if (_name.text.isEmpty ||
        _phone.text.isEmpty ||
        _quantity.text.isEmpty ||
        _location.text.isEmpty) {
      showFancySnackBar(
        context,
        'Please fill all fields and fetch a location.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseDatabase.instance.ref('donors').push().set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'quantity': _quantity.text.trim(),
        'location': _location.text.trim(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        showFancySnackBar(context, 'Donation submitted! Thank you.');
        Navigator.pushAndRemoveUntil(
          context,
          FadePageRoute(child: const HomePage()),
          (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Save failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donor Form')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantity,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Quantity of Food',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location (lat,lng)',
                  suffixIcon: Icon(Icons.pin_drop, color: Colors.teal),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _fetchingLocation ? null : _getLocation,
                icon: _fetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _fetchingLocation ? 'Fetching...' : 'Fetch My Location',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _saveDonor,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Donor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  RECEIVER FORM (with Geolocator)
// ═══════════════════════════════════════════════════════════════

class ReceiverForm extends StatefulWidget {
  const ReceiverForm({super.key});
  @override
  State<ReceiverForm> createState() => _ReceiverFormState();
}

class _ReceiverFormState extends State<ReceiverForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _people = TextEditingController();
  final _location = TextEditingController();
  bool _saving = false;
  bool _fetchingLocation = false;

  final _userService = UserService();
  final _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final profile = await _userService.getCurrentUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _name.text = profile.name ?? '';
        _phone.text = profile.phone ?? '';
      });
    }
  }

  Future<void> _getLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _location.text = '${pos.latitude.toStringAsFixed(6)},'
              '${pos.longitude.toStringAsFixed(6)}';
        });
        showFancySnackBar(
          context,
          'Location captured (±${pos.accuracy.toStringAsFixed(0)} m)',
        );
      }
    } on String catch (msg) {
      if (mounted) showFancySnackBar(context, msg, isError: true);
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Location error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _saveReceiver() async {
    if (_name.text.isEmpty ||
        _phone.text.isEmpty ||
        _people.text.isEmpty ||
        _location.text.isEmpty) {
      showFancySnackBar(context, 'Please fill all fields.', isError: true);
      return;
    }
    final peopleCount = int.tryParse(_people.text);
    if (peopleCount == null || peopleCount <= 0) {
      showFancySnackBar(
        context,
        'Enter a valid positive number of people.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseDatabase.instance.ref('receivers').push().set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'people': peopleCount,
        'location': _location.text.trim(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        showFancySnackBar(context, 'Request submitted!');
        Navigator.pushAndRemoveUntil(
          context,
          FadePageRoute(child: const HomePage()),
          (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Save failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receiver Form')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _people,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of People',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location (lat,lng)',
                  suffixIcon: Icon(Icons.pin_drop, color: Colors.teal),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _fetchingLocation ? null : _getLocation,
                icon: _fetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _fetchingLocation ? 'Fetching...' : 'Fetch My Location',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _saveReceiver,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HISTORY
// ═══════════════════════════════════════════════════════════════

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _userService = UserService();
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    _userProfile = await _userService.getCurrentUserProfile();
    if (mounted) setState(() => _isLoading = false);
  }

  Query _getHistoryQuery() {
    if (_userProfile?.role == 'donor') {
      return FirebaseDatabase.instance
          .ref('donors')
          .orderByChild('phone')
          .equalTo(_userProfile!.phone);
    } else {
      return FirebaseDatabase.instance
          .ref('receivers')
          .orderByChild('phone')
          .equalTo(_userProfile!.phone);
    }
  }

  Future<void> _showUpdateStatusDialog(
      String itemKey, Map<String, dynamic> itemData) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Status'),
        content: const Text('What would you like to do with this item?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(itemKey, itemData, 'completed');
            },
            child: const Text('Mark as Delivered'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(itemKey, itemData, 'cancelled');
            },
            child: const Text(
              'Cancel Item',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      String itemKey, Map<String, dynamic> itemData, String newStatus) async {
    if (_userProfile == null) return;
    final db = FirebaseDatabase.instance;

    try {
      if (_userProfile!.role == 'donor') {
        final donorRef = db.ref('donors/$itemKey');
        final receiverKey = itemData['assignedReceiverKey'];
        await donorRef.update({
          'status': newStatus,
          if (newStatus != 'in_progress')
            ...{'driverUid': null, 'assignedReceiverKey': null},
        });
        if (receiverKey != null) {
          await db.ref('receivers/$receiverKey').update({
            'status': newStatus == 'cancelled' ? 'pending' : newStatus,
            'assignedDonorKey': null,
          });
        }
      } else {
        final receiverRef = db.ref('receivers/$itemKey');
        final donorKey = itemData['assignedDonorKey'];
        await receiverRef.update({
          'status': newStatus,
          if (newStatus != 'in_progress') 'assignedDonorKey': null,
        });
        if (donorKey != null) {
          await db.ref('donors/$donorKey').update({
            'status': newStatus == 'cancelled' ? 'pending' : newStatus,
            'driverUid': null,
            'assignedReceiverKey': null,
          });
        }
      }
      if (mounted) {
        showFancySnackBar(context, 'Status updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Update failed: $e', isError: true);
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'in_progress':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.grey.shade600;
        break;
      default:
        color = Colors.blue;
    }
    return Chip(
      label: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile?.phone == null || _userProfile?.role == null
              ? const Center(child: Text('Could not load user data.'))
              : StreamBuilder(
                  stream: _getHistoryQuery().onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return const Center(
                        child: Text(
                          'You have no submission history.',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }
                    final entries = Map<String, dynamic>.from(
                      snapshot.data!.snapshot.value as Map,
                    );
                    final sorted = entries.entries.toList()
                      ..sort(
                        (a, b) =>
                            (b.key ?? '').compareTo(a.key ?? ''),
                      );

                    return ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final key = sorted[index].key;
                        final data = Map<String, dynamic>.from(
                          sorted[index].value,
                        );
                        final status = data['status'] ?? 'pending';
                        final detail = _userProfile?.role == 'donor'
                            ? data['quantity']?.toString() ?? '—'
                            : '${data['people'] ?? '?'} people';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: InkWell(
                            onTap: status == 'in_progress'
                                ? () => _showUpdateStatusDialog(key, data)
                                : null,
                            child: ListTile(
                              title: Text(detail),
                              subtitle: Text(
                                data['location'] ?? 'No location',
                              ),
                              trailing: _buildStatusChip(status),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MY IMPACT
// ═══════════════════════════════════════════════════════════════

class MyImpactPage extends StatefulWidget {
  const MyImpactPage({super.key});
  @override
  State<MyImpactPage> createState() => _MyImpactPageState();
}

class _MyImpactPageState extends State<MyImpactPage> {
  final _userService = UserService();
  UserProfile? _userProfile;
  bool _isLoading = true;
  int _completed = 0;
  int _peopleServed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _userProfile = await _userService.getCurrentUserProfile();
      if (_userProfile == null) throw Exception('User data not found.');

      final ref = _userProfile!.role == 'donor'
          ? FirebaseDatabase.instance.ref('donors')
          : FirebaseDatabase.instance.ref('receivers');

      final snap =
          await ref.orderByChild('phone').equalTo(_userProfile!.phone).get();

      if (snap.exists && snap.value != null) {
        final records = Map<String, dynamic>.from(snap.value as Map);
        int c = 0, p = 0;
        records.forEach((_, v) {
          final item = Map<String, dynamic>.from(v);
          if (item['status'] == 'completed') {
            c++;
            if (_userProfile!.role == 'receiver') {
              p += (item['people'] as num?)?.toInt() ?? 0;
            }
          }
        });
        _completed = c;
        _peopleServed = p;
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Could not load stats: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My Impact')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? const Center(child: Text('Could not load your data.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your Contribution Summary',
                        style: textTheme.headlineSmall
                            ?.copyWith(color: Colors.teal),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_userProfile!.role == 'donor')
                        ImpactCard(
                          value: _completed.toString(),
                          label: 'Donations Completed',
                          icon: Icons.volunteer_activism,
                        ),
                      if (_userProfile!.role == 'receiver') ...[
                        ImpactCard(
                          value: _completed.toString(),
                          label: 'Requests Fulfilled',
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(height: 16),
                        ImpactCard(
                          value: _peopleServed.toString(),
                          label: 'Total People Served',
                          icon: Icons.groups_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class ImpactCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const ImpactCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.amber[700]),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DRIVER PAGE (Geolocator + Google Maps)
// ═══════════════════════════════════════════════════════════════

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});
  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  final donorsRef = FirebaseDatabase.instance.ref('donors');
  final receiversRef = FirebaseDatabase.instance.ref('receivers');
  final _userService = UserService();
  final _locationService = LocationService();

  bool isJobAccepted = false;
  bool _isResumingJob = true;
  bool _isFetchingLocation = false;
  bool _sortByDistance = false;

  String? acceptedDonorKey;
  String? acceptedReceiverKey;
  String? selectedDonorKey;
  String? selectedReceiverKey;

  Map<String, dynamic>? acceptedDonorData;
  Map<String, dynamic>? acceptedReceiverData;
  Position? _driverPosition;

  @override
  void initState() {
    super.initState();
    _resumeActiveJob();
  }

  // ─── Resume active job (if driver already has one) ─────────
  Future<void> _resumeActiveJob() async {
    final user = _userService.currentUser;
    if (user == null) {
      setState(() => _isResumingJob = false);
      return;
    }
    try {
      final snap =
          await donorsRef.orderByChild('driverUid').equalTo(user.uid).get();

      if (snap.exists && snap.value != null) {
        final jobs = Map<String, dynamic>.from(snap.value as Map);
        String? dKey;
        Map<String, dynamic>? dData;
        jobs.forEach((k, v) {
          final map = Map<String, dynamic>.from(v);
          if (map['status'] == 'in_progress') {
            dKey = k;
            dData = map;
          }
        });

        if (dKey != null && dData != null) {
          final rKey = dData!['assignedReceiverKey'];
          if (rKey != null) {
            final rSnap = await receiversRef.child(rKey).get();
            if (rSnap.exists) {
              setState(() {
                isJobAccepted = true;
                acceptedDonorKey = dKey;
                acceptedReceiverKey = rKey;
                acceptedDonorData = dData;
                acceptedReceiverData =
                    Map<String, dynamic>.from(rSnap.value as Map);
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Resume error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResumingJob = false);
    }
  }

  // ─── Fetch driver's live position ──────────────────────────
  Future<void> _getDriverLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      _driverPosition = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {});
        showFancySnackBar(context, 'Location updated');
      }
    } on String catch (msg) {
      if (mounted) showFancySnackBar(context, msg, isError: true);
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Location error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ─── Distance helpers ──────────────────────────────────────
  double _distanceMeters(String? location) {
    if (_driverPosition == null || location == null) {
      return double.infinity;
    }
    final parts = location.split(',');
    if (parts.length != 2) return double.infinity;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return double.infinity;
    return Geolocator.distanceBetween(
      _driverPosition!.latitude,
      _driverPosition!.longitude,
      lat,
      lon,
    );
  }

  String? _distanceLabel(String? location) {
    final m = _distanceMeters(location);
    if (m == double.infinity) return null;
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  // ─── Accept job (atomic transaction) ───────────────────────
  Future<void> _acceptJob() async {
    if (selectedDonorKey == null || selectedReceiverKey == null) return;

    final user = _userService.currentUser;
    if (user == null) {
      showFancySnackBar(context, 'You must be logged in.', isError: true);
      return;
    }

    setState(() => _isResumingJob = true);

    final donorRef = donorsRef.child(selectedDonorKey!);
    final receiverRef = receiversRef.child(selectedReceiverKey!);

    try {
      final txn = await donorRef.runTransaction((Object? raw) {
        if (raw == null) return Transaction.abort();
        final map = Map<String, dynamic>.from(raw as Map);
        if (map['status'] != 'pending') return Transaction.abort();

        map['status'] = 'in_progress';
        map['driverUid'] = user.uid;
        map['assignedReceiverKey'] = selectedReceiverKey;
        return Transaction.success(map);
      });

      if (txn.committed) {
        await receiverRef.update({
          'status': 'in_progress',
          'assignedDonorKey': selectedDonorKey,
        });
        if (mounted) showFancySnackBar(context, 'Job accepted!');
        await _resumeActiveJob();
      } else {
        if (mounted) {
          showFancySnackBar(
            context,
            'This donation is no longer available.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Accept failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResumingJob = false);
    }
  }

  // ─── Cancel active job ─────────────────────────────────────
  Future<void> _cancelJob() async {
    if (acceptedDonorKey == null || acceptedReceiverKey == null) return;
    await donorsRef.child(acceptedDonorKey!).update({
      'status': 'pending',
      'driverUid': null,
      'assignedReceiverKey': null,
    });
    await receiversRef.child(acceptedReceiverKey!).update({
      'status': 'pending',
      'assignedDonorKey': null,
    });
    _resetJobState();
    if (mounted) showFancySnackBar(context, 'Job cancelled.');
  }

  // ─── Complete active job ───────────────────────────────────
  Future<void> _completeJob() async {
    if (acceptedDonorKey == null || acceptedReceiverKey == null) return;
    await donorsRef.child(acceptedDonorKey!).update({'status': 'completed'});
    await receiversRef
        .child(acceptedReceiverKey!)
        .update({'status': 'completed'});
    await _notifyOnCompletion();
    _resetJobState();
    if (mounted) showFancySnackBar(context, 'Job marked as completed!');
  }

  void _resetJobState() {
    if (!mounted) return;
    setState(() {
      isJobAccepted = false;
      acceptedDonorKey = null;
      acceptedReceiverKey = null;
      acceptedDonorData = null;
      acceptedReceiverData = null;
      selectedDonorKey = null;
      selectedReceiverKey = null;
    });
  }

  // ─── Google Maps integration ───────────────────────────────
  Future<void> _launchMaps() async {
    final donorLoc = acceptedDonorData?['location']?.toString();
    final receiverLoc = acceptedReceiverData?['location']?.toString();

    if (donorLoc == null || receiverLoc == null) {
      if (mounted) {
        showFancySnackBar(
          context,
          'Missing donor or receiver location.',
          isError: true,
        );
      }
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$donorLoc'
      '&destination=$receiverLoc'
      '&travelmode=driving',
    );

    debugPrint('Maps URL → $uri');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showFancySnackBar(
            context,
            'Could not open Google Maps.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showFancySnackBar(context, 'Maps error: $e', isError: true);
      }
    }
  }

  // ─── Notify donor + receiver on completion ─────────────────
  Future<void> _notifyOnCompletion() async {
    final receiverPhone = acceptedReceiverData?['phone']?.toString();
    final donorPhone = acceptedDonorData?['phone']?.toString();

    if (receiverPhone != null) {
      await _pushMessage(
        receiverPhone,
        'Your food request has been successfully delivered!',
      );
    }
    if (donorPhone != null) {
      await _pushMessage(
        donorPhone,
        'Your donation has been successfully delivered. Thank you!',
      );
    }
    if (mounted) showFancySnackBar(context, 'Notified donor & receiver!');
  }

  Future<void> _pushMessage(String phone, String message) async {
    final cleanPhone = phone.replaceAll('+', '');
    await FirebaseDatabase.instance
        .ref('messages/$cleanPhone')
        .push()
        .set({
      'text': message,
      'time': DateTime.now().toIso8601String(),
    });
  }

  // ─── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Dashboard')),
      drawer: const AppDrawer(),
      body: _isResumingJob
          ? const Center(child: CircularProgressIndicator())
          : isJobAccepted
              ? _buildCurrentDeliveryCard()
              : _buildJobSelectionLists(),
    );
  }

  Widget _buildJobSelectionLists() {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed:
                    _isFetchingLocation ? null : _getDriverLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location, size: 16),
                label: const Text('My Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const Spacer(),
              if (_driverPosition != null)
                FilterChip(
                  label: const Text('Sort by Distance'),
                  selected: _sortByDistance,
                  onSelected: (v) =>
                      setState(() => _sortByDistance = v),
                  selectedColor: Colors.teal.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            '1. Select Available Donation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: _buildList(isDonorList: true)),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            '2. Select a Receiver',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: _buildList(isDonorList: false)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: (selectedDonorKey != null &&
                    selectedReceiverKey != null)
                ? _acceptJob
                : null,
            child: const Text('Accept Job'),
          ),
        ),
      ],
    );
  }

  Widget _buildList({required bool isDonorList}) {
    final query = isDonorList
        ? donorsRef.orderByChild('status').equalTo('pending')
        : receiversRef.orderByChild('status').equalTo('pending');

    return StreamBuilder(
      stream: query.onValue,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.snapshot.value == null) {
          return Center(
            child: Text(
              'No Available ${isDonorList ? "Donations" : "Receivers"}',
            ),
          );
        }

        var items =
            Map<dynamic, dynamic>.from(snap.data!.snapshot.value as Map)
                .entries
                .toList();

        if (_sortByDistance && _driverPosition != null) {
          items.sort((a, b) {
            final aLoc = Map.from(a.value)['location'];
            final bLoc = Map.from(b.value)['location'];
            return _distanceMeters(aLoc as String?)
                .compareTo(_distanceMeters(bLoc as String?));
          });
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final e = items[i];
            final data = Map<dynamic, dynamic>.from(e.value);
            final selectedKey =
                isDonorList ? selectedDonorKey : selectedReceiverKey;
            final title = data['name']?.toString() ?? '';
            final subtitle = isDonorList
                ? (data['quantity']?.toString() ?? 'No quantity')
                : '${data['people']} people';
            final distance = _distanceLabel(data['location']);

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: selectedKey == e.key
                  ? Colors.teal.withValues(alpha: 0.2)
                  : null,
              child: ListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: distance != null
                    ? Text(
                        distance,
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
                onTap: () => setState(() {
                  if (isDonorList) {
                    selectedDonorKey = e.key.toString();
                  } else {
                    selectedReceiverKey = e.key.toString();
                  }
                }),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentDeliveryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Current Delivery',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FROM:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(acceptedDonorData?['name'] ?? ''),
                  Text('Details: ${acceptedDonorData?['quantity'] ?? '—'}'),
                  const Divider(height: 24),
                  const Text(
                    'TO:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(acceptedReceiverData?['name'] ?? ''),
                  Text(
                    'People: ${acceptedReceiverData?['people'] ?? '—'}',
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _launchMaps,
            icon: const Icon(Icons.map),
            label: const Text('Open in Maps'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _completeJob,
            icon: const Icon(Icons.check),
            label: const Text('Mark as Completed'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _cancelJob,
            icon: const Icon(Icons.close),
            label: const Text('Cancel Job'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}