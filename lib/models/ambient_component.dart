import 'component_action.dart';

/// Base class for all Ambient Components
/// This is the foundation of Ambia's dynamic UI system
abstract class AmbientComponent {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final ComponentStyle? style;
  final List<ComponentAction>? actions;

  AmbientComponent({
    required this.id,
    required this.type,
    required this.data,
    this.style,
    this.actions,
  });

  factory AmbientComponent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    // Route to specific component types
    switch (type) {
      // Data Display
      case 'header':
        return HeaderComponent.fromJson(json);
      case 'text':
        return TextComponent.fromJson(json);
      case 'metric':
        return MetricComponent.fromJson(json);
      case 'stat':
        return StatComponent.fromJson(json);
      case 'progress':
        return ProgressComponent.fromJson(json);

      // Lists
      case 'list':
        return ListComponent.fromJson(json);
      case 'person_list':
        return PersonListComponent.fromJson(json);
      case 'timeline':
        return TimelineComponent.fromJson(json);

      // Actions
      case 'button':
        return ButtonComponent.fromJson(json);
      case 'action_row':
        return ActionRowComponent.fromJson(json);
      case 'chip_row':
        return ChipRowComponent.fromJson(json);

      // Media
      case 'image':
        return ImageComponent.fromJson(json);
      case 'gallery':
        return GalleryComponent.fromJson(json);
      case 'map':
        return MapComponent.fromJson(json);

      // Contextual
      case 'weather':
        return WeatherComponent.fromJson(json);
      case 'location':
        return LocationComponent.fromJson(json);
      case 'calendar_event':
        return CalendarEventComponent.fromJson(json);

      // Visual
      case 'chart':
        return ChartComponent.fromJson(json);
      case 'sparkline':
        return SparklineComponent.fromJson(json);

      // Container
      case 'card':
        return CardComponent.fromJson(json);
      case 'section':
        return SectionComponent.fromJson(json);

      default:
        return UnknownComponent.fromJson(json);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    if (style != null) 'style': style!.toJson(),
    if (actions != null) 'actions': actions!.map((a) => a.toJson()).toList(),
  };
}

/// Component Style - Visual customization
class ComponentStyle {
  final String? variant; // 'primary', 'secondary', 'urgent', 'subtle'
  final String? size; // 'small', 'medium', 'large'
  final String? theme; // 'light', 'dark', 'auto'
  final Map<String, dynamic>? custom;

  ComponentStyle({
    this.variant,
    this.size,
    this.theme,
    this.custom,
  });

  factory ComponentStyle.fromJson(Map<String, dynamic> json) {
    return ComponentStyle(
      variant: json['variant'],
      size: json['size'],
      theme: json['theme'],
      custom: json['custom'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (variant != null) 'variant': variant,
    if (size != null) 'size': size,
    if (theme != null) 'theme': theme,
    if (custom != null) 'custom': custom,
  };
}

// ==================== DATA DISPLAY COMPONENTS ====================

class HeaderComponent extends AmbientComponent {
  HeaderComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'header');

  factory HeaderComponent.fromJson(Map<String, dynamic> json) {
    return HeaderComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get title => data['title'] ?? '';
  String? get subtitle => data['subtitle'];
  String? get badge => data['badge'];
  String? get icon => data['icon'];
}

class TextComponent extends AmbientComponent {
  TextComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'text');

  factory TextComponent.fromJson(Map<String, dynamic> json) {
    return TextComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get content => data['content'] ?? data['text'] ?? '';
  bool get markdown => data['markdown'] ?? false;
}

class MetricComponent extends AmbientComponent {
  MetricComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'metric');

  factory MetricComponent.fromJson(Map<String, dynamic> json) {
    return MetricComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get label => data['label'] ?? '';
  String get value => data['value']?.toString() ?? '';
  String? get change => data['change'];
  String? get unit => data['unit'];
  String? get icon => data['icon'];
}

class StatComponent extends AmbientComponent {
  StatComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'stat');

  factory StatComponent.fromJson(Map<String, dynamic> json) {
    return StatComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<Map<String, dynamic>> get stats => List<Map<String, dynamic>>.from(data['stats'] ?? []);
}

class ProgressComponent extends AmbientComponent {
  ProgressComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'progress');

  factory ProgressComponent.fromJson(Map<String, dynamic> json) {
    return ProgressComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get label => data['label'] ?? '';
  double get value => (data['value'] ?? 0).toDouble();
  double get max => (data['max'] ?? 100).toDouble();
  String? get color => data['color'];
}

// ==================== LIST COMPONENTS ====================

class ListComponent extends AmbientComponent {
  ListComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'list');

  factory ListComponent.fromJson(Map<String, dynamic> json) {
    return ListComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<Map<String, dynamic>> get items => List<Map<String, dynamic>>.from(data['items'] ?? []);
  String? get title => data['title'];
}

class PersonListComponent extends AmbientComponent {
  PersonListComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'person_list');

  factory PersonListComponent.fromJson(Map<String, dynamic> json) {
    return PersonListComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<Map<String, dynamic>> get people => List<Map<String, dynamic>>.from(data['people'] ?? data['items'] ?? []);
  String? get title => data['title'];
}

class TimelineComponent extends AmbientComponent {
  TimelineComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'timeline');

  factory TimelineComponent.fromJson(Map<String, dynamic> json) {
    return TimelineComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<Map<String, dynamic>> get events => List<Map<String, dynamic>>.from(data['events'] ?? data['items'] ?? []);
  String? get title => data['title'];
}

// ==================== ACTION COMPONENTS ====================

class ButtonComponent extends AmbientComponent {
  ButtonComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'button');

  factory ButtonComponent.fromJson(Map<String, dynamic> json) {
    return ButtonComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : [ComponentAction.fromJson(json['action'] ?? {})],
    );
  }

  String get label => data['label'] ?? data['text'] ?? '';
  String? get icon => data['icon'];
}

class ActionRowComponent extends AmbientComponent {
  ActionRowComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'action_row');

  factory ActionRowComponent.fromJson(Map<String, dynamic> json) {
    return ActionRowComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<Map<String, dynamic>> get buttons => List<Map<String, dynamic>>.from(data['buttons'] ?? data['actions'] ?? []);
}

class ChipRowComponent extends AmbientComponent {
  ChipRowComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'chip_row');

  factory ChipRowComponent.fromJson(Map<String, dynamic> json) {
    return ChipRowComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<Map<String, dynamic>> get chips => List<Map<String, dynamic>>.from(data['chips'] ?? data['items'] ?? []);
}

// ==================== MEDIA COMPONENTS ====================

class ImageComponent extends AmbientComponent {
  ImageComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'image');

  factory ImageComponent.fromJson(Map<String, dynamic> json) {
    return ImageComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get url => data['url'] ?? data['src'] ?? '';
  String? get caption => data['caption'];
  double? get aspectRatio => data['aspect_ratio']?.toDouble();
}

class GalleryComponent extends AmbientComponent {
  GalleryComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'gallery');

  factory GalleryComponent.fromJson(Map<String, dynamic> json) {
    return GalleryComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<Map<String, dynamic>> get images => List<Map<String, dynamic>>.from(data['images'] ?? []);
}

class MapComponent extends AmbientComponent {
  MapComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'map');

  factory MapComponent.fromJson(Map<String, dynamic> json) {
    return MapComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  double get latitude => (data['latitude'] ?? data['lat'] ?? 0).toDouble();
  double get longitude => (data['longitude'] ?? data['lng'] ?? 0).toDouble();
  String? get title => data['title'];
  String? get address => data['address'];
}

// ==================== CONTEXTUAL COMPONENTS ====================

class WeatherComponent extends AmbientComponent {
  WeatherComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'weather');

  factory WeatherComponent.fromJson(Map<String, dynamic> json) {
    return WeatherComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get condition => data['condition'] ?? '';
  int get temperature => data['temperature'] ?? 0;
  String? get location => data['location'];
  String? get icon => data['icon'];
}

class LocationComponent extends AmbientComponent {
  LocationComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'location');

  factory LocationComponent.fromJson(Map<String, dynamic> json) {
    return LocationComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get name => data['name'] ?? '';
  String? get address => data['address'];
  String? get distance => data['distance'];
  String? get icon => data['icon'];
}

class CalendarEventComponent extends AmbientComponent {
  CalendarEventComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'calendar_event');

  factory CalendarEventComponent.fromJson(Map<String, dynamic> json) {
    return CalendarEventComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get title => data['title'] ?? '';
  String? get time => data['time'];
  String? get location => data['location'];
  List<Map<String, dynamic>>? get attendees => data['attendees'] != null
    ? List<Map<String, dynamic>>.from(data['attendees'])
    : null;
}

// ==================== VISUAL COMPONENTS ====================

class ChartComponent extends AmbientComponent {
  ChartComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'chart');

  factory ChartComponent.fromJson(Map<String, dynamic> json) {
    return ChartComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String get chartType => data['chartType'] ?? data['chart_type'] ?? 'line';
  List<Map<String, dynamic>> get dataPoints => List<Map<String, dynamic>>.from(data['dataPoints'] ?? data['data_points'] ?? data['data'] ?? []);
  String? get title => data['title'];
}

class SparklineComponent extends AmbientComponent {
  SparklineComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'sparkline');

  factory SparklineComponent.fromJson(Map<String, dynamic> json) {
    return SparklineComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<double> get values => List<double>.from((data['values'] as List).map((v) => v.toDouble()));
  String? get label => data['label'];
}

// ==================== CONTAINER COMPONENTS ====================

class CardComponent extends AmbientComponent {
  CardComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'card');

  factory CardComponent.fromJson(Map<String, dynamic> json) {
    return CardComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  List<AmbientComponent> get children => (data['children'] as List? ?? [])
    .map((c) => AmbientComponent.fromJson(c))
    .toList();
}

class SectionComponent extends AmbientComponent {
  SectionComponent({
    required super.id,
    required super.data,
    super.style,
    super.actions,
  }) : super(type: 'section');

  factory SectionComponent.fromJson(Map<String, dynamic> json) {
    return SectionComponent(
      id: json['id'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }

  String? get title => data['title'];
  List<AmbientComponent> get children => (data['children'] as List? ?? [])
    .map((c) => AmbientComponent.fromJson(c))
    .toList();
}

// ==================== FALLBACK ====================

class UnknownComponent extends AmbientComponent {
  UnknownComponent({
    required super.id,
    required super.type,
    required super.data,
    super.style,
    super.actions,
  });

  factory UnknownComponent.fromJson(Map<String, dynamic> json) {
    return UnknownComponent(
      id: json['id'] ?? '',
      type: json['type'] ?? 'unknown',
      data: Map<String, dynamic>.from(json['data'] ?? json),
      style: json['style'] != null ? ComponentStyle.fromJson(json['style']) : null,
      actions: json['actions'] != null
        ? (json['actions'] as List).map((a) => ComponentAction.fromJson(a)).toList()
        : null,
    );
  }
}
