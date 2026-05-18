import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ora/features/settings/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class GlobalFooter extends ConsumerWidget {
  const GlobalFooter({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSocialIcon(IconData icon, String? url, Color color) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _launchUrl(url),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;

    // We import locationProvider to get the address
    // Wait, locationProvider is not imported here. I will need to ensure it's imported.

    final storeName = settings?.storeName ?? 'ORA';
    final description =
        settings?.shortDescription ??
        'Your favorite food, delivered fast and fresh directly to your door.';
    final phone = settings?.phone;
    final email = settings?.email;
    final operatingDays = settings?.operatingDays ?? 'Monday - Sunday';

    String timingString = '9:00 AM - 10:00 PM';
    if (settings?.openingTime != null && settings?.closingTime != null) {
      try {
        final openParts = settings!.openingTime!.split(':');
        final closeParts = settings.closingTime!.split(':');

        final openHour = int.parse(openParts[0]);
        final openMin = int.parse(openParts[1]);
        final closeHour = int.parse(closeParts[0]);
        final closeMin = int.parse(closeParts[1]);

        String formatTime(int h, int m) {
          final period = h >= 12 ? 'PM' : 'AM';
          final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
          final displayM = m.toString().padLeft(2, '0');
          return '$displayH:$displayM $period';
        }

        timingString =
            '${formatTime(openHour, openMin)} - ${formatTime(closeHour, closeMin)}';
      } catch (_) {}
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 800;

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                _buildLogoColumn(storeName, description),
                const SizedBox(height: 32),
                _buildContactColumn(storeName, phone, email),
                const SizedBox(height: 32),
                _buildTimingsColumn(operatingDays, timingString, settings),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildLogoColumn(storeName, description),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 3,
                      child: _buildContactColumn(storeName, phone, email),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 3,
                      child: _buildTimingsColumn(
                        operatingDays,
                        timingString,
                        settings,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 48),
              Divider(color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '© 2026 $storeName. All rights reserved.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoColumn(String storeName, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          storeName.toUpperCase(),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildContactColumn(String storeName, String? phone, String? email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          storeName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (phone != null && phone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Text(
                  'Phone: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(phone, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        if (email != null && email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Text(
                  'Email: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(email, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimingsColumn(
    String operatingDays,
    String timingString,
    dynamic settings,
  ) {
    final bool hasSocial =
        (settings?.facebookUrl?.isNotEmpty == true) ||
        (settings?.instagramUrl?.isNotEmpty == true) ||
        (settings?.tiktokUrl?.isNotEmpty == true) ||
        (settings?.youtubeUrl?.isNotEmpty == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Our Timings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(operatingDays, style: const TextStyle(color: Colors.white70)),
            Text(timingString, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        if (hasSocial) ...[
          const SizedBox(height: 32),
          const Text(
            'Follow Us:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSocialIcon(
                Icons.facebook,
                settings?.facebookUrl,
                Colors.blue,
              ),
              _buildSocialIcon(
                Icons.camera_alt,
                settings?.instagramUrl,
                Colors.pink,
              ),
              _buildSocialIcon(
                Icons.music_note,
                settings?.tiktokUrl,
                Colors.white,
              ),
              _buildSocialIcon(
                Icons.play_circle_fill,
                settings?.youtubeUrl,
                Colors.red,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
