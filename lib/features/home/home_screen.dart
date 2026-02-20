import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:songrush_party/core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.background,
              Color(0xFF2A002A), 
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo placeholder
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.neonPink, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.neonPink.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.music_note, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 40),
              
              Text(
                'SONGRUSH',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: AppTheme.neonBlue, blurRadius: 10, offset: Offset(2, 2)),
                  ],
                ),
              ),
              Text(
                'PARTY',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: AppTheme.neonPink,
                ),
              ),
              
              const SizedBox(height: 60),

              // Buttons
              _MenuButton(
                label: 'PARTY ERSTELLEN',
                color: AppTheme.neonPink,
                onPressed: () => context.push('/create'),
              ),
              const SizedBox(height: 20),
              _MenuButton(
                label: 'PARTY BEITRETEN',
                color: AppTheme.neonBlue,
                onPressed: () => context.push('/join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final buttonWidth = (MediaQuery.sizeOf(context).width - 48).clamp(220.0, 300.0);
    return SizedBox(
      width: buttonWidth,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: color.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
