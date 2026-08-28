import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget destination;

  const SplashScreen({super.key, required this.destination});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color deepTeal = Color(0xFF245B57);
  static const Color coolTeal = Color(0xFF5FA89B);
  static const Color backgroundColor = Color(0xFFF7F8F4);

  @override
  void initState() {
    super.initState();
    _openMainScreen();
  }

  Future<void> _openMainScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => widget.destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6EFE3),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        size: 70,
                        color: deepTeal,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'HeatWay',
                style: TextStyle(
                  color: deepTeal,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Find the coolest way',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: coolTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
