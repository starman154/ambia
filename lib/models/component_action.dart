/// Component Action System
/// Defines all possible actions that components can trigger
class ComponentAction {
  final String type;
  final Map<String, dynamic> params;

  ComponentAction({
    required this.type,
    this.params = const {},
  });

  factory ComponentAction.fromJson(Map<String, dynamic> json) {
    return ComponentAction(
      type: json['type'] ?? json['action'] ?? 'none',
      params: Map<String, dynamic>.from(json['params'] ?? json),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'params': params,
  };
}

/// Action Types - Comprehensive list of all possible actions
class ActionType {
  // Navigation
  static const String openUrl = 'open_url';
  static const String openApp = 'open_app';
  static const String navigate = 'navigate';
  static const String back = 'back';

  // Communication
  static const String call = 'call';
  static const String message = 'message';
  static const String email = 'email';
  static const String share = 'share';

  // Calendar & Time
  static const String addToCalendar = 'add_to_calendar';
  static const String setReminder = 'set_reminder';
  static const String viewEvent = 'view_event';

  // Location
  static const String openMap = 'open_map';
  static const String getDirections = 'get_directions';
  static const String findNearby = 'find_nearby';

  // Data Actions
  static const String save = 'save';
  static const String delete = 'delete';
  static const String update = 'update';
  static const String refresh = 'refresh';

  // Interactive
  static const String toggle = 'toggle';
  static const String select = 'select';
  static const String input = 'input';
  static const String submit = 'submit';

  // Content
  static const String play = 'play';
  static const String pause = 'pause';
  static const String expand = 'expand';
  static const String collapse = 'collapse';

  // AI Actions
  static const String generateMore = 'generate_more';
  static const String explainThis = 'explain_this';
  static const String relatedInfo = 'related_info';

  // Custom
  static const String custom = 'custom';
  static const String none = 'none';
}

/// Action Handler - Executes component actions
class ComponentActionHandler {
  static Future<void> handle(ComponentAction action) async {
    switch (action.type) {
      case ActionType.openUrl:
        await _handleOpenUrl(action.params);
        break;
      case ActionType.call:
        await _handleCall(action.params);
        break;
      case ActionType.message:
        await _handleMessage(action.params);
        break;
      case ActionType.email:
        await _handleEmail(action.params);
        break;
      case ActionType.share:
        await _handleShare(action.params);
        break;
      case ActionType.refresh:
        await _handleRefresh(action.params);
        break;
      case ActionType.generateMore:
        await _handleGenerateMore(action.params);
        break;
      default:
        print('Unhandled action type: ${action.type}');
    }
  }

  static Future<void> _handleOpenUrl(Map<String, dynamic> params) async {
    // TODO: Implement with url_launcher
    print('Opening URL: ${params['url']}');
  }

  static Future<void> _handleCall(Map<String, dynamic> params) async {
    // TODO: Implement with url_launcher (tel:)
    print('Calling: ${params['phone']}');
  }

  static Future<void> _handleMessage(Map<String, dynamic> params) async {
    // TODO: Implement with url_launcher (sms:)
    print('Messaging: ${params['phone']}');
  }

  static Future<void> _handleEmail(Map<String, dynamic> params) async {
    // TODO: Implement with url_launcher (mailto:)
    print('Emailing: ${params['email']}');
  }

  static Future<void> _handleShare(Map<String, dynamic> params) async {
    // TODO: Implement with share_plus
    print('Sharing: ${params['content']}');
  }

  static Future<void> _handleRefresh(Map<String, dynamic> params) async {
    print('Refreshing component');
  }

  static Future<void> _handleGenerateMore(Map<String, dynamic> params) async {
    print('Generating more content: ${params['context']}');
  }
}
