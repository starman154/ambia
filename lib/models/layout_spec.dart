import 'dart:convert';

/// Layout specification from Claude - defines how to render UI
class LayoutSpec {
  final String version;
  final bool experimental;
  final String? reasoning;
  final List<TimelineItem> timeline;

  LayoutSpec({
    required this.version,
    required this.experimental,
    this.reasoning,
    required this.timeline,
  });

  factory LayoutSpec.fromJson(Map<String, dynamic> json) {
    return LayoutSpec(
      version: json['layout_version'] ?? 'v_1',
      experimental: json['experimental'] ?? false,
      reasoning: json['reasoning'],
      timeline: (json['timeline'] as List)
          .map((item) => TimelineItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'layout_version': version,
      'experimental': experimental,
      'reasoning': reasoning,
      'timeline': timeline.map((item) => item.toJson()).toList(),
    };
  }
}

/// Individual timeline item (weather card, flight briefing, etc.)
class TimelineItem {
  final String id;
  final String type;
  final String template;
  final VisualStyle visual;
  final List<ContentBlock> contentBlocks;
  final int priority;

  TimelineItem({
    required this.id,
    required this.type,
    required this.template,
    required this.visual,
    required this.contentBlocks,
    this.priority = 50,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      id: json['id'],
      type: json['type'],
      template: json['template'] ?? 'standard',
      visual: VisualStyle.fromJson(json['visual_style'] ?? {}),
      contentBlocks: (json['content_blocks'] as List? ?? [])
          .map((block) => ContentBlock.fromJson(block))
          .toList(),
      priority: json['priority'] ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'template': template,
      'visual_style': visual.toJson(),
      'content_blocks': contentBlocks.map((block) => block.toJson()).toList(),
      'priority': priority,
    };
  }
}

/// Visual styling for cards
class VisualStyle {
  final String background;
  final List<String> colors;
  final double height;
  final String corners;
  final bool glassmorphism;
  final double? blur;
  final double? opacity;

  VisualStyle({
    this.background = 'solid',
    this.colors = const ['#1C1C1E'],
    this.height = 160,
    this.corners = 'rounded_24',
    this.glassmorphism = true,
    this.blur,
    this.opacity,
  });

  factory VisualStyle.fromJson(Map<String, dynamic> json) {
    return VisualStyle(
      background: json['background'] ?? 'solid',
      colors: (json['colors'] as List?)?.cast<String>() ?? ['#1C1C1E'],
      height: (json['height'] ?? 160).toDouble(),
      corners: json['corners'] ?? 'rounded_24',
      glassmorphism: json['glassmorphism'] ?? true,
      blur: json['blur']?.toDouble(),
      opacity: json['opacity']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'background': background,
      'colors': colors,
      'height': height,
      'corners': corners,
      'glassmorphism': glassmorphism,
      'blur': blur,
      'opacity': opacity,
    };
  }

  double get cornerRadius {
    switch (corners) {
      case 'rounded_8':
        return 8;
      case 'rounded_16':
        return 16;
      case 'rounded_24':
        return 24;
      case 'rounded_32':
        return 32;
      default:
        return 24;
    }
  }
}

/// Content blocks within a card
class ContentBlock {
  final String type;
  final String size;
  final String position;
  final String? animation;
  final String? layout;
  final Map<String, dynamic> data;

  ContentBlock({
    required this.type,
    this.size = 'medium',
    this.position = 'top',
    this.animation,
    this.layout,
    this.data = const {},
  });

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: json['type'],
      size: json['size'] ?? 'medium',
      position: json['position'] ?? 'top',
      animation: json['animation'],
      layout: json['layout'],
      data: json['data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'size': size,
      'position': position,
      'animation': animation,
      'layout': layout,
      'data': data,
    };
  }
}
