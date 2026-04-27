import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:flutter/services.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  runApp(const SeshaApp());
}

class SeshaApp extends StatefulWidget {
  const SeshaApp({super.key});

  @override
  State<SeshaApp> createState() => _SeshaAppState();
}

class _SeshaAppState extends State<SeshaApp> {
  late final ApiService _apiService;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authProvider = AuthProvider(_apiService);
    _apiService.onUnauthorized = () => _authProvider.logout();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Sesha',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF094a25)),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ).copyWith(
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ).copyWith(
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ).copyWith(
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.isLoggedIn) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
