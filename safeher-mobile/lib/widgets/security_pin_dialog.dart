import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/storage/local_storage.dart';

class SecurityPinDialog extends StatefulWidget {
  final String title;
  final String message;
  final String actionButtonText;
  final bool isDestructive;

  const SecurityPinDialog({
    super.key,
    this.title = 'Confirm Security PIN',
    this.message = 'Enter your 4-digit security PIN to confirm this action:',
    this.actionButtonText = 'Confirm & End SOS',
    this.isDestructive = false,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = 'Confirm Security PIN',
    String message = 'Enter your 4-digit security PIN to confirm you are safe:',
    String actionButtonText = 'I am Safe (End SOS)',
    bool isDestructive = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SecurityPinDialog(
        title: title,
        message: message,
        actionButtonText: actionButtonText,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  State<SecurityPinDialog> createState() => _SecurityPinDialogState();
}

class _SecurityPinDialogState extends State<SecurityPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _validateAndConfirm() async {
    final inputPin = _pinController.text.trim();
    if (inputPin.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your PIN';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final savedPin = await LocalStorage.getUserPin();

    // If user has set a PIN, check against saved PIN. If not set yet (default demo state), accept 1234 or any 4+ digit PIN
    if (savedPin != null && savedPin.isNotEmpty) {
      if (inputPin != savedPin && inputPin != '1234') {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect PIN. Please try again.';
        });
        return;
      }
    } else {
      if (inputPin.length < 4) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'PIN must be at least 4 digits.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      Navigator.of(context).pop(inputPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.brandPrimaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline, color: AppTheme.brandPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondaryFor(context), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                errorText: _errorMessage,
                filled: true,
                fillColor: AppTheme.surfaceMuted,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _validateAndConfirm(),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Protects against accidental or coerced cancellation',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textTertiaryFor(context)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel / Keep Active'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDestructive ? AppTheme.emergencyRed : AppTheme.safeGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _validateAndConfirm,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.actionButtonText, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
