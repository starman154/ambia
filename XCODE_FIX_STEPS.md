# Xcode Widget Extension - Fix Build Cycle

## Problem
Build is failing with: "Cycle inside Runner; building could produce unreliable results"

This is because of incorrect target dependencies between Runner and AmbiaWidgetExtension.

## Steps to Fix in Xcode

### 1. Open Xcode Workspace
```bash
cd /Users/jacobkaplan/ambia/ios
open Runner.xcworkspace
```

### 2. Fix Target Dependencies

1. **Select Runner target**:
   - Click on "Runner" project in the left sidebar (blue icon)
   - Select the "Runner" target from the TARGETS list

2. **Check Build Phases**:
   - Click on "Build Phases" tab
   - Look for "Embed Foundation Extensions" or "Embed App Extensions"
   - If you see "AmbiaWidgetExtension.appex" listed there, that's correct
   - Make sure it's NOT in "Copy Bundle Resources" - if it is, remove it

3. **Verify Target Dependencies**:
   - Still in "Build Phases" tab, find "Dependencies" section
   - Make sure "AmbiaWidgetExtension" is listed here
   - If not, click "+" and add it

### 3. Fix Widget Extension Settings

1. **Select AmbiaWidgetExtension target**:
   - In TARGETS list, select "AmbiaWidgetExtension"

2. **General Tab**:
   - Bundle Identifier: Should be `com.ambia.app.AmbiaWidget` or `com.example.ambia.AmbiaWidget`
   - iOS Deployment Target: **16.1** or higher

3. **Build Settings Tab**:
   - Search for "Skip Install"
   - Set "Skip Install" to **YES**

4. **Signing & Capabilities**:
   - Add your development team
   - Enable **App Groups**: `group.com.ambia.app` (or `group.com.example.ambia`)

### 4. Configure Runner App Groups

1. **Select Runner target**
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**: `group.com.ambia.app` (or `group.com.example.ambia`)
   - Must match the widget extension's app group
5. Add **Push Notifications** capability

### 5. Verify File Target Membership

1. **AmbiaLiveActivityManager.swift**:
   - Click the file in Project Navigator
   - In File Inspector (right panel), check Target Membership:
   - ☑️ Runner
   - ☑️ AmbiaWidgetExtension
   - Both should be checked!

2. **AmbiaWidgetBundle.swift**:
   - Target Membership:
   - ☐ Runner (unchecked)
   - ☑️ AmbiaWidgetExtension (checked)

3. **AmbiaLiveActivityWidget.swift**:
   - Target Membership:
   - ☐ Runner (unchecked)
   - ☑️ AmbiaWidgetExtension (checked)

### 6. Clean and Rebuild

1. **Product → Clean Build Folder** (⌘⇧K)
2. **Product → Build** (⌘B)
3. Watch for errors in the Issue Navigator

## Common Issues

### Issue: "Use of undeclared type 'AmbiaActivityAttributes'"
**Fix**: Make sure `AmbiaLiveActivityManager.swift` has both Runner and AmbiaWidgetExtension checked in Target Membership

### Issue: "Cannot find 'FlutterMethodChannel' in scope"
**Fix**: This is expected in the widget extension. Only Runner target should have Flutter imports.

### Issue: Build cycle still occurring
**Fix**:
1. Remove AmbiaWidgetExtension.appex from "Copy Bundle Resources" if it's there
2. Ensure it's only in "Embed Foundation Extensions"
3. Set "Skip Install" to YES in widget extension build settings

## Alternative: Create New Widget Extension

If the above steps don't work, you can delete the widget extension and recreate it:

1. **Delete AmbiaWidgetExtension target**:
   - Select it in TARGETS list
   - Press Delete key
   - Confirm deletion

2. **Create new Widget Extension**:
   - File → New → Target
   - Widget Extension
   - Name: `AmbiaWidget`
   - Uncheck "Include Configuration Intent"
   - Uncheck "Include Live Activity"
   - Activate scheme when prompted

3. **Delete default files**:
   - Delete the auto-generated `AmbiaWidget.swift` file

4. **Add our files to the new target**:
   - Drag `AmbiaWidgetBundle.swift` and `AmbiaLiveActivityWidget.swift` into AmbiaWidget folder
   - In Target Membership, check only AmbiaWidget

5. **Follow steps 3-6 above**

## Verify Success

Build should complete with:
```
Building com.example.ambia for device (ios-release)...
Xcode build done.                                           XX.Xs
```

No cycle errors!

## Next Steps After Build Succeeds

1. **Connect physical iOS device** (Live Activities don't work in simulator)
2. **Run the app**: `flutter run -d [device-id]`
3. **Check console for sync logs**: Look for `[LiveActivity]` messages
4. **Wait for Llama to generate insights** (every 5 minutes)
5. **Lock your device** to see Live Activities appear

The system will automatically:
- Fetch ambient events from backend
- Display highest priority event as Live Activity
- Show in Dynamic Island (iPhone 14 Pro+)
- Update the lock screen widget
