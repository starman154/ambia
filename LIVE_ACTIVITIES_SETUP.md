# Live Activities Setup Guide

## Overview
I've implemented the core infrastructure for Live Activities, Dynamic Island, and Push Notifications. However, due to Xcode project file complexity, you'll need to complete the final steps manually in Xcode.

## What I've Built

### Backend (✅ Complete)
- **API Endpoint**: `GET /api/ambient/events/:userId` - Fetches active ambient events
- **Device Registration**: `POST /api/ambient/devices/register` - Registers device tokens
- **Event Tracking**: `POST /api/ambient/events/:eventId/interact` - Tracks user interactions
- **Llama Intelligence**: Running every 5 minutes, generating proactive insights

### iOS Native Code (✅ Created)
- **AmbiaLiveActivityManager.swift**: Manages Live Activity lifecycle
- **AmbiaLiveActivityWidget.swift**: Beautiful, flexible UI for lock screen and Dynamic Island
- **AmbiaWidgetBundle.swift**: Widget bundle entry point
- **AppDelegate.swift**: Platform channel bridge between Flutter and native iOS
- **LiveActivityService.dart**: Flutter service to communicate with native code

### Features Implemented
✅ **Flexible Content System**: Supports progress bars, images, charts, and custom data fields
✅ **Dynamic Island**: Compact, minimal, and expanded states
✅ **Lock Screen UI**: Beautiful gradient cards with priority badges
✅ **Priority System**: High/Medium/Low priority visual indicators
✅ **Auto-sync**: Fetches ambient events every 5 minutes from backend
✅ **Push Notifications**: Device token registration and handling

## Manual Steps Required in Xcode

### Step 1: Open Xcode Project
```bash
open ios/Runner.xcworkspace
```

### Step 2: Create Widget Extension Target
1. **File → New → Target**
2. Select **Widget Extension**
3. Name it: `AmbiaWidget`
4. Product Name: `AmbiaWidget`
5. Uncheck "Include Configuration Intent"
6. Click **Finish**
7. When prompted "Activate AmbiaWidget scheme?", click **Activate**

### Step 3: Add Swift Files to Runner Target
1. In the Project Navigator, locate these files in the `Runner` folder:
   - `AmbiaLiveActivityManager.swift`
   - `AppDelegate.swift` (already in project, just updated)

2. Select both files, go to **File Inspector** (right panel)
3. Under **Target Membership**, ensure ☑️ **Runner** is checked

### Step 4: Add Swift Files to Widget Extension Target
1. In the Project Navigator, drag these files into the `AmbiaWidget` folder:
   - `AmbiaWidgetBundle.swift`
   - `AmbiaLiveActivityWidget.swift`
   - `Info.plist` (from AmbiaWidget folder)

2. Delete the default `AmbiaWidget.swift` file that Xcode created

3. Select the files you just added, go to **File Inspector**
4. Under **Target Membership**, ensure:
   - ☑️ **AmbiaWidget** is checked
   - ☐ **Runner** is unchecked

### Step 5: Share AmbiaActivityAttributes
The `AmbiaActivityAttributes` struct needs to be shared between both targets.

1. Open `AmbiaLiveActivityManager.swift`
2. In **File Inspector**, under **Target Membership**, check BOTH:
   - ☑️ **Runner**
   - ☑️ **AmbiaWidget**

### Step 6: Configure Widget Extension Settings
1. Select **AmbiaWidget** target in project settings
2. **General** tab:
   - iOS Deployment Target: **16.1**
   - Bundle Identifier: `com.ambia.app.AmbiaWidget` (or your app's bundle ID + `.AmbiaWidget`)

3. **Signing & Capabilities** tab:
   - Add your development team
   - Enable **App Groups**: `group.com.ambia.app`

4. **Info** tab:
   - Ensure `NSSupportsLiveActivities` = `YES`

### Step 7: Configure Runner Target for Live Activities
1. Select **Runner** target in project settings
2. **Signing & Capabilities** tab:
   - Click **+ Capability**
   - Add **App Groups**: `group.com.ambia.app`
   - Add **Push Notifications**

3. **Build Settings** tab:
   - Search for "Swift Bridging Header"
   - Ensure it's set to: `Runner/Runner-Bridging-Header.h`

### Step 8: Build and Run
1. Select **Runner** scheme
2. Select your physical iOS device (Live Activities require real device, not simulator)
3. **Product → Clean Build Folder** (⌘⇧K)
4. **Product → Build** (⌘B)
5. Fix any build errors (usually related to target membership)
6. **Product → Run** (⌘R)

## Testing the Live Activities

Once the app is running on your device:

1. **Enable Calendar Sync** in Settings
2. Wait for calendar events to sync (you should see console logs)
3. **Automatic Sync**: The app will check for ambient events every 5 minutes
4. **Live Activity Appears**: When Llama generates a high-priority insight, a Live Activity will appear on your lock screen and Dynamic Island

### Manual Test (Optional)
If you want to test immediately without waiting for Llama to generate events, you can:

1. Open **Flutter DevTools Console**
2. Look for logs like: `[LiveActivity] Starting Live Activity with data: ...`
3. Lock your device to see the Live Activity on the lock screen
4. If you have iPhone 14 Pro or newer, you'll see it in the Dynamic Island

## How It Works

### Architecture Flow
```
1. Backend (Llama) generates insight → Saves to ambient_events table
                    ↓
2. iOS app syncs every 5 minutes → Fetches GET /api/ambient/events/:userId
                    ↓
3. LiveActivityService.dart → Calls native Swift via platform channel
                    ↓
4. AmbiaLiveActivityManager → Starts ActivityKit Live Activity
                    ↓
5. AmbiaLiveActivityWidget → Renders UI on lock screen + Dynamic Island
```

### Flexible Content System
The Live Activity UI adapts based on the event data:

**Progress Bar Example** (e.g., "30 min until your flight"):
```json
{
  "title": "Flight Preparation",
  "subtitle": "SEA → LAX",
  "body": "Your flight departs in 2 hours",
  "icon": "airplane",
  "color": "#2196F3",
  "priority": "high",
  "data": {
    "progress": 0.7,  // Shows as progress bar
    "destination": "LAX"
  }
}
```

**Image Example** (e.g., "Morning class summary"):
```json
{
  "title": "Morning Summary",
  "subtitle": "IDS 302 - Data Science",
  "body": "Last class: Linear Regression review",
  "icon": "book.fill",
  "color": "#4CAF50",
  "priority": "medium",
  "data": {
    "imageUrl": "https://...",  // Shows as image
    "topics": ["Linear Regression", "R-squared"]
  }
}
```

**Chart Example** (e.g., "Weekly productivity"):
```json
{
  "title": "Productivity Trend",
  "body": "You're 20% more productive this week",
  "icon": "chart.bar.fill",
  "color": "#FF9800",
  "priority": "low",
  "data": {
    "chartData": [  // Shows as bar chart
      {"label": "Mon", "value": 0.6},
      {"label": "Tue", "value": 0.8},
      {"label": "Wed", "value": 0.9}
    ]
  }
}
```

## Dynamic Island States

### Compact (default)
- **Left**: Icon with event color
- **Right**: Progress percentage (if available)

### Minimal (when multiple activities)
- Just the icon

### Expanded (tap to expand)
- **Leading**: Icon + Title
- **Trailing**: Progress circle (if available)
- **Bottom**: Subtitle, body text, progress bar, images, charts

## Troubleshooting

### Build Errors
- **"Use of undeclared type 'AmbiaActivityAttributes'"**: Ensure `AmbiaLiveActivityManager.swift` has both Runner and AmbiaWidget checked in Target Membership
- **"Cannot find 'FlutterMethodChannel' in scope"**: Make sure you're importing Flutter in Runner target
- **Widget not appearing**: Check that `NSSupportsLiveActivities` is `true` in both Runner and Widget Info.plist

### Runtime Issues
- **No Live Activities showing**: Check console logs for `[LiveActivity]` messages
- **Permission denied**: Ensure notification permissions are granted in iOS Settings
- **Events not syncing**: Check that calendar sync is enabled in app settings
- **Backend errors**: Check backend logs with `eb logs` in the backend directory

## Next Steps

After completing the Xcode setup:

1. **Test on real device** (iPhone 14 Pro+ recommended for Dynamic Island)
2. **Check console logs** for sync activity
3. **Wait for Llama to generate insights** (every 5 minutes)
4. **Lock your device** to see Live Activities in action

The system is designed to be fully autonomous - Llama will analyze your calendar events and automatically create ambient intelligence insights that appear as Live Activities at the right time!

## Files Created

### iOS Native (Swift)
- `ios/Runner/AmbiaLiveActivityManager.swift` - Live Activity manager
- `ios/Runner/AppDelegate.swift` - Platform channel bridge (updated)
- `ios/AmbiaWidget/AmbiaWidgetBundle.swift` - Widget bundle
- `ios/AmbiaWidget/AmbiaLiveActivityWidget.swift` - Live Activity UI
- `ios/AmbiaWidget/Info.plist` - Widget extension Info.plist

### Flutter (Dart)
- `lib/services/live_activity_service.dart` - Flutter service
- `lib/main.dart` - Updated to initialize Live Activity service

### Configuration
- `ios/Podfile` - Updated to iOS 16.1+
- `ios/Runner/Info.plist` - Added Live Activities support

### Backend
- Already complete! Endpoints are running and Llama is analyzing your calendar events.
