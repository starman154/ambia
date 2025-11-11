import 'package:flutter/material.dart';
import '../models/ambient_component.dart';
import '../models/component_action.dart';
import '../widgets/components/component_widgets.dart';

/// JSON Renderer - The Core Engine
/// Converts component JSON into Flutter widgets dynamically
/// This is what makes Ambia's interfaces generative, not hardcoded
class JSONRenderer {
  /// Render a single component
  static Widget renderComponent(AmbientComponent component) {
    try {
      switch (component.type) {
        // Data Display
        case 'header':
          return _renderHeader(component as HeaderComponent);
        case 'text':
          return _renderText(component as TextComponent);
        case 'metric':
          return _renderMetric(component as MetricComponent);
        case 'stat':
          return _renderStat(component as StatComponent);
        case 'progress':
          return _renderProgress(component as ProgressComponent);

        // Lists
        case 'list':
          return _renderList(component as ListComponent);
        case 'person_list':
          return _renderPersonList(component as PersonListComponent);
        case 'timeline':
          return _renderTimeline(component as TimelineComponent);

        // Actions
        case 'button':
          return _renderButton(component as ButtonComponent);
        case 'action_row':
          return _renderActionRow(component as ActionRowComponent);
        case 'chip_row':
          return _renderChipRow(component as ChipRowComponent);

        // Media
        case 'image':
          return _renderImage(component as ImageComponent);
        case 'gallery':
          return _renderGallery(component as GalleryComponent);
        case 'map':
          return _renderMap(component as MapComponent);

        // Contextual
        case 'weather':
          return _renderWeather(component as WeatherComponent);
        case 'location':
          return _renderLocation(component as LocationComponent);
        case 'calendar_event':
          return _renderCalendarEvent(component as CalendarEventComponent);

        // Visual
        case 'chart':
          return _renderChart(component as ChartComponent);
        case 'sparkline':
          return _renderSparkline(component as SparklineComponent);

        // Containers
        case 'card':
          return _renderCard(component as CardComponent);
        case 'section':
          return _renderSection(component as SectionComponent);

        default:
          return _renderUnknown(component as UnknownComponent);
      }
    } catch (e) {
      return _renderError(component.type, e);
    }
  }

  /// Render multiple components in a column
  static Widget renderComponents(List<AmbientComponent> components) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: components.map((c) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: renderComponent(c),
        )
      ).toList(),
    );
  }

  // ==================== RENDERERS ====================

  static Widget _renderHeader(HeaderComponent component) {
    return HeaderWidget(component: component);
  }

  static Widget _renderText(TextComponent component) {
    return TextWidget(component: component);
  }

  static Widget _renderMetric(MetricComponent component) {
    return MetricWidget(component: component);
  }

  static Widget _renderStat(StatComponent component) {
    return StatWidget(component: component);
  }

  static Widget _renderProgress(ProgressComponent component) {
    return ProgressWidget(component: component);
  }

  static Widget _renderList(ListComponent component) {
    return ListWidget(component: component);
  }

  static Widget _renderPersonList(PersonListComponent component) {
    return PersonListWidget(component: component);
  }

  static Widget _renderTimeline(TimelineComponent component) {
    return TimelineWidget(component: component);
  }

  static Widget _renderButton(ButtonComponent component) {
    return ButtonWidget(component: component);
  }

  static Widget _renderActionRow(ActionRowComponent component) {
    return ActionRowWidget(component: component);
  }

  static Widget _renderChipRow(ChipRowComponent component) {
    return ChipRowWidget(component: component);
  }

  static Widget _renderImage(ImageComponent component) {
    return ImageWidget(component: component);
  }

  static Widget _renderGallery(GalleryComponent component) {
    return GalleryWidget(component: component);
  }

  static Widget _renderMap(MapComponent component) {
    return MapWidget(component: component);
  }

  static Widget _renderWeather(WeatherComponent component) {
    return WeatherWidget(component: component);
  }

  static Widget _renderLocation(LocationComponent component) {
    return LocationWidget(component: component);
  }

  static Widget _renderCalendarEvent(CalendarEventComponent component) {
    return CalendarEventWidget(component: component);
  }

  static Widget _renderChart(ChartComponent component) {
    return ChartWidget(component: component);
  }

  static Widget _renderSparkline(SparklineComponent component) {
    return SparklineWidget(component: component);
  }

  static Widget _renderCard(CardComponent component) {
    return CardWidget(
      component: component,
      children: component.children.map((c) => renderComponent(c)).toList(),
    );
  }

  static Widget _renderSection(SectionComponent component) {
    return SectionWidget(
      component: component,
      children: component.children.map((c) => renderComponent(c)).toList(),
    );
  }

  static Widget _renderUnknown(UnknownComponent component) {
    return UnknownWidget(component: component);
  }

  static Widget _renderError(String type, dynamic error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Render Error: $type',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Style Utilities - Convert component styles to Flutter styles
class ComponentStyleUtils {
  static Color getVariantColor(String? variant) {
    switch (variant) {
      case 'primary':
        return const Color(0xFFFF6B35);
      case 'secondary':
        return const Color(0xFF8B5CF6);
      case 'urgent':
        return Colors.red.shade400;
      case 'subtle':
        return Colors.white.withOpacity(0.3);
      case 'success':
        return Colors.green.shade400;
      case 'warning':
        return Colors.orange.shade400;
      default:
        return Colors.white.withOpacity(0.8);
    }
  }

  static double getSize(String? size, {double defaultSize = 16}) {
    switch (size) {
      case 'small':
        return defaultSize * 0.85;
      case 'large':
        return defaultSize * 1.25;
      case 'xlarge':
        return defaultSize * 1.5;
      default:
        return defaultSize;
    }
  }

  static LinearGradient getGradient(String? variant) {
    switch (variant) {
      case 'primary':
        return const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFEC4899)],
        );
      case 'secondary':
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFC026D3)],
        );
      case 'urgent':
        return LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade500],
        );
      default:
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        );
    }
  }
}
