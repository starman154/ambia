import 'package:flutter/material.dart';

/// Renders Claude-generated Apple Weather-style layouts for Ambient Info pages
class AmbientLayoutRenderer extends StatelessWidget {
  final Map<String, dynamic> layoutData;

  const AmbientLayoutRenderer({
    super.key,
    required this.layoutData,
  });

  @override
  Widget build(BuildContext context) {
    final header = layoutData['header'] as Map<String, dynamic>?;
    final cards = (layoutData['cards'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, bottomPadding + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (header != null) _buildHeader(header),
          const SizedBox(height: 32),

          // Cards in staggered grid
          _buildCardGrid(cards),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> header) {
    final title = header['title'] as String? ?? '';
    final subtitle = header['subtitle'] as String?;
    final icon = header['icon'] as String?;
    final color = _parseColor(header['color'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _parseIconName(icon),
              color: color,
              size: 32,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 34,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardGrid(List<Map<String, dynamic>> cards) {
    final List<Widget> rows = [];
    int i = 0;

    while (i < cards.length) {
      final currentCard = cards[i];
      final currentType = currentCard['type'] as String? ?? 'standard';

      // Check if next card can sit side-by-side
      if (i + 1 < cards.length) {
        final nextCard = cards[i + 1];
        final nextType = nextCard['type'] as String? ?? 'standard';

        // If both are standard or compact, place them side-by-side
        if ((currentType == 'standard' && nextType == 'standard') ||
            (currentType == 'compact' && nextType == 'compact') ||
            (currentType == 'standard' && nextType == 'compact') ||
            (currentType == 'compact' && nextType == 'standard')) {

          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildCard(currentCard, currentType)),
                const SizedBox(width: 16),
                Expanded(child: _buildCard(nextCard, nextType)),
              ],
            ),
          );
          rows.add(const SizedBox(height: 16));
          i += 2; // Skip both cards
          continue;
        }
      }

      // Otherwise, full-width card
      rows.add(_buildCard(currentCard, currentType));
      rows.add(const SizedBox(height: 16));
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildCard(Map<String, dynamic> card, String type) {
    final title = card['title'] as String? ?? '';
    final content = card['content'] as Map<String, dynamic>? ?? {};
    final action = card['action'] as Map<String, dynamic>?;

    // Determine card height and styling based on type
    double? minHeight;
    double fontSize;
    double padding;

    if (type == 'hero') {
      minHeight = 240;
      fontSize = 22;
      padding = 24;
    } else if (type == 'standard') {
      minHeight = 180;
      fontSize = 17;
      padding = 20;
    } else {
      minHeight = 120;
      fontSize = 15;
      padding = 16;
    }

    return Container(
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight) : null,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card title
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: type == 'compact' ? 12 : 16),
          ],

          // Card content
          Flexible(child: _buildCardContent(content)),

          // Card action
          if (action != null) ...[
            const SizedBox(height: 16),
            _buildCardAction(action),
          ],
        ],
      ),
    );
  }

  Widget _buildCardContent(Map<String, dynamic> content) {
    final contentType = content['type'] as String? ?? 'text';

    switch (contentType) {
      case 'text':
        return _buildTextContent(content);
      case 'progress':
        return _buildProgressContent(content);
      case 'list':
        return _buildListContent(content);
      case 'countdown':
        return _buildCountdownContent(content);
      case 'chart':
        return _buildChartContent(content);
      default:
        return _buildTextContent(content);
    }
  }

  Widget _buildTextContent(Map<String, dynamic> content) {
    final text = content['text'] as String? ?? '';
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.75),
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildProgressContent(Map<String, dynamic> content) {
    final progress = (content['progress'] as num?)?.toDouble() ?? 0.0;
    final label = content['label'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(Map<String, dynamic> content) {
    final items = (content['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: items.map((item) {
        final label = item['label'] as String? ?? '';
        final value = item['value']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCountdownContent(Map<String, dynamic> content) {
    final targetTime = content['targetTime'] as String?;
    final message = content['message'] as String? ?? 'Time remaining';

    // TODO: Implement actual countdown timer
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '2h 15m',
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 48,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildChartContent(Map<String, dynamic> content) {
    // Placeholder for chart visualization
    return Center(
      child: Text(
        'Chart visualization',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCardAction(Map<String, dynamic> action) {
    final label = action['label'] as String? ?? 'Action';

    return ElevatedButton(
      onPressed: () {
        // TODO: Handle action types (navigate, call, etc.)
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEC4899),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(label),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null) return const Color(0xFFEC4899);

    // Remove # if present
    final cleanColor = colorString.replaceAll('#', '');

    // Parse hex color
    try {
      return Color(int.parse('FF$cleanColor', radix: 16));
    } catch (e) {
      return const Color(0xFFEC4899);
    }
  }

  IconData _parseIconName(String iconName) {
    // Map SF Symbols to Material Icons
    final iconMap = {
      'calendar': Icons.calendar_today,
      'star.fill': Icons.star,
      'star': Icons.star_border,
      'location.fill': Icons.location_on,
      'location': Icons.location_on_outlined,
      'clock.fill': Icons.access_time,
      'clock': Icons.access_time_outlined,
      'person.fill': Icons.person,
      'person': Icons.person_outline,
      'airplane': Icons.flight,
      'doc.fill': Icons.description,
      'doc': Icons.description_outlined,
      'envelope.fill': Icons.email,
      'envelope': Icons.email_outlined,
      'phone.fill': Icons.phone,
      'phone': Icons.phone_outlined,
      'cart.fill': Icons.shopping_cart,
      'cart': Icons.shopping_cart_outlined,
      'bell.fill': Icons.notifications,
      'bell': Icons.notifications_outlined,
      'checkmark.circle.fill': Icons.check_circle,
      'checkmark.circle': Icons.check_circle_outline,
    };

    return iconMap[iconName] ?? Icons.info;
  }
}
