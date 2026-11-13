import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vibration_service.dart';
import '../core/theme/app_theme.dart';

class SosHoldButton extends StatefulWidget {
  final Future<void> Function() onSosTriggered;
  final bool isTestMode;
  final double size;

  const SosHoldButton({
    super.key,
    required this.onSosTriggered,
    this.isTestMode = false,
    this.size = 220,
  });

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton> with SingleTickerProviderStateMixin {
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  bool _isTriggering = false;
  static const int _holdDurationMs = 3000;
  static const int _stepMs = 40;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPressDown() {
    if (_isTriggering) return;
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    HapticFeedback.heavyImpact();

    const totalSteps = _holdDurationMs / _stepMs;
    int currentStep = 0;

    _holdTimer = Timer.periodic(const Duration(milliseconds: _stepMs), (timer) {
      currentStep++;
      final progress = (currentStep / totalSteps).clamp(0.0, 1.0);
      setState(() {
        _holdProgress = progress;
      });

      if (currentStep % 8 == 0) {
        HapticFeedback.selectionClick();
      }

      if (_holdProgress >= 1.0) {
        timer.cancel();
        _executeTrigger();
      }
    });
  }

  void _onPressUp() {
    if (_isTriggering) return;
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _executeTrigger() async {
    if (_isTriggering) return;
    setState(() {
      _isTriggering = true;
    });

    try {
      await VibrationService.vibratePattern();
    } catch (_) {}

    try {
      await widget.onSosTriggered();
    } finally {
      if (mounted) {
        setState(() {
          _isHolding = false;
          _holdProgress = 0.0;
          _isTriggering = false;
        });
      }
    }
  }

  String get _instructionText {
    if (_isTriggering) return 'ACTIVATING SOS...';
    if (!_isHolding) return 'HOLD 3 SECONDS';
    if (_holdProgress < 0.4) return 'KEEP HOLDING...';
    if (_holdProgress < 0.85) return 'RELEASING CANCELS';
    return 'ACTIVATING SOS...';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isTestMode ? const Color(0xFFF59E0B) : AppTheme.emergencyRed;
    final darkColor = widget.isTestMode ? const Color(0xFFD97706) : AppTheme.emergencyDarkRed;

    return Semantics(
      label: widget.isTestMode ? 'Test SOS Emergency Button. Press and hold 3 seconds to test.' : 'Emergency SOS Button. Press and hold 3 seconds to activate emergency alert.',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _onPressDown(),
        onTapUp: (_) => _onPressUp(),
        onTapCancel: () => _onPressUp(),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isHolding ? 0.96 : _pulseAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring
                  Container(
                    width: widget.size + 16,
                    height: widget.size + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: _isHolding ? 0.25 : 0.1),
                    ),
                  ),

                  // Circular Progress Indicator
                  SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CircularProgressIndicator(
                      value: _holdProgress,
                      strokeWidth: 8,
                      backgroundColor: primaryColor.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation<Color>(darkColor),
                    ),
                  ),

                  // Main Core SOS Button
                  Container(
                    width: widget.size - 28,
                    height: widget.size - 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryColor,
                          darkColor,
                        ],
                        center: const Alignment(-0.2, -0.2),
                        radius: 0.9,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: _isHolding ? 0.55 : 0.35),
                          blurRadius: _isHolding ? 28 : 16,
                          spreadRadius: _isHolding ? 6 : 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isTestMode ? Icons.science_outlined : Icons.emergency,
                          color: Colors.white,
                          size: widget.size * 0.22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isTestMode ? 'TEST SOS' : 'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.isTestMode ? 22 : 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: widget.isTestMode ? 1.5 : 3.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _instructionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
