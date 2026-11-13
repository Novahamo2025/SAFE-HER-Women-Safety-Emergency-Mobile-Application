import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/providers/toolkit_provider.dart';
import '../../core/services/media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../widgets/safe_button.dart';

class VehiclePhotoSheet extends StatefulWidget {
  const VehiclePhotoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const VehiclePhotoSheet(),
    );
  }

  @override
  State<VehiclePhotoSheet> createState() => _VehiclePhotoSheetState();
}

class _VehiclePhotoSheetState extends State<VehiclePhotoSheet> {
  final _plateController = TextEditingController();
  final _notesController = TextEditingController();

  String? _encryptedPhotoPath;
  Uint8List? _previewBytes;
  bool _isLoading = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _plateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isLoading = true);

    try {
      final path = await MediaService.pickPhoto(source: source);
      if (path != null) {
        final bytes = await MediaService.decryptEvidenceBytes(path);
        final pos = await LocationService.getCurrentLocation();

        if (!mounted) return;
        setState(() {
          _encryptedPhotoPath = path;
          _previewBytes = bytes;
          _latitude = pos?.latitude;
          _longitude = pos?.longitude;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera or gallery.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    if (_encryptedPhotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or select a vehicle photo first.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final plateText = _plateController.text.trim();
    final notesText = _notesController.text.trim();

    final title = plateText.isNotEmpty
        ? 'Vehicle Evidence: $plateText'
        : 'Vehicle Photo Evidence';

    final description = notesText.isNotEmpty
        ? notesText
        : 'Vehicle photograph captured for security and transit documentation.';

    await context.read<ToolkitProvider>().addIncident(
          title: title,
          description: description,
          photoPath: _encryptedPhotoPath,
          latitude: _latitude,
          longitude: _longitude,
        );

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vehicle evidence securely encrypted and saved locally.'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF312E81) : AppTheme.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_car_filled_outlined,
                        color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Vehicle Photo Evidence',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Document cab, taxi, or suspicious vehicle license plates before boarding. Evidence is encrypted in app storage.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),

            // Image Preview or Action Picker
            if (_previewBytes != null) ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.safeGreen, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_previewBytes!, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Encrypted', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retake Camera'),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Select from Gallery'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDarkElevated : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Capture or Upload Vehicle Photograph',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SafeButton(
                            text: 'Use Camera',
                            icon: Icons.camera_alt,
                            isLoading: _isLoading,
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SafeButton(
                            text: 'From Gallery',
                            icon: Icons.photo_library,
                            type: SafeButtonType.outline,
                            isLoading: _isLoading,
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Number plate field
            Text(
              'License Plate or Vehicle Model',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. DL 1R A 1234, White Swift Dzire',
                prefixIcon: Icon(Icons.pin),
              ),
            ),
            const SizedBox(height: 14),

            // Observations & Notes
            Text(
              'Trip / Route Notes (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Uber trip from Metro Station to Apartment',
              ),
            ),
            const SizedBox(height: 20),

            SafeButton(
              text: 'Save to Encrypted Evidence Locker',
              icon: Icons.shield_rounded,
              isLoading: _isSaving,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
