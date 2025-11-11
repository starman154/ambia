const mysql = require('mysql2/promise');

async function createVarietyEvents() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'admin',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'ambia'
  });

  try {
    const userId = '410b2520-e011-70d9-1ef0-10cead18dedd';
    const validUntil = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

    // Style 1: Countdown Timer (Meeting)
    const meetingEvent = {
      id: `meeting-${Date.now()}`,
      user_id: userId,
      event_type: 'live_activity',
      title: '📅 Team Standup',
      subtitle: 'Daily Sync Meeting',
      body: 'Your next meeting starts in 15 minutes',
      priority: 'high',
      icon: 'calendar',
      color: '#FF9500',
      status: 'active',
      data: JSON.stringify({
        countdown: 900, // 15 minutes in seconds
        location: 'Conference Room A',
        attendees: 5
      }),
      valid_until: validUntil
    };

    // Style 2: Weather Alert
    const weatherEvent = {
      id: `weather-${Date.now()}`,
      user_id: userId,
      event_type: 'live_activity',
      title: '☀️ Beautiful Day',
      subtitle: 'Perfect for outdoor activities',
      body: '72°F, Sunny with light breeze',
      priority: 'medium',
      icon: 'sun.max.fill',
      color: '#FFD60A',
      status: 'active',
      data: JSON.stringify({
        temperature: 72,
        condition: 'sunny',
        humidity: 45,
        windSpeed: 8
      }),
      valid_until: validUntil
    };

    // Style 3: Task Progress
    const taskEvent = {
      id: `task-${Date.now()}`,
      user_id: userId,
      event_type: 'live_activity',
      title: '✅ Project Milestone',
      subtitle: 'Q4 Feature Development',
      body: '8 of 12 tasks completed',
      priority: 'medium',
      icon: 'checkmark.circle.fill',
      color: '#34C759',
      status: 'active',
      data: JSON.stringify({
        progress: 0.67,
        completed: 8,
        total: 12,
        deadline: '2025-11-15'
      }),
      valid_until: validUntil
    };

    // Style 4: Package Delivery
    const deliveryEvent = {
      id: `delivery-${Date.now()}`,
      user_id: userId,
      event_type: 'live_activity',
      title: '📦 Package Arriving',
      subtitle: 'Amazon Delivery',
      body: '3 stops away - Estimated 2:30 PM',
      priority: 'high',
      icon: 'shippingbox.fill',
      color: '#FF9500',
      status: 'active',
      data: JSON.stringify({
        progress: 0.75,
        stopsAway: 3,
        estimatedTime: '2:30 PM',
        trackingNumber: 'TRK123456789'
      }),
      valid_until: validUntil
    };

    // Style 5: Workout Tracker
    const workoutEvent = {
      id: `workout-${Date.now()}`,
      user_id: userId,
      event_type: 'live_activity',
      title: '🏃 Active Workout',
      subtitle: 'Running - Mile 3 of 5',
      body: 'Keep it up! Heart rate: 145 bpm',
      priority: 'high',
      icon: 'figure.run',
      color: '#FF3B30',
      status: 'active',
      data: JSON.stringify({
        progress: 0.6,
        distance: 3.0,
        targetDistance: 5.0,
        heartRate: 145,
        pace: '8:30/mi'
      }),
      valid_until: validUntil
    };

    const events = [meetingEvent, weatherEvent, taskEvent, deliveryEvent, workoutEvent];

    for (const event of events) {
      await connection.execute(
        `INSERT INTO ambient_events
         (id, user_id, event_type, title, subtitle, body, priority, icon, color, status, data, valid_until, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
        [
          event.id,
          event.user_id,
          event.event_type,
          event.title,
          event.subtitle,
          event.body,
          event.priority,
          event.icon,
          event.color,
          event.status,
          event.data,
          event.valid_until
        ]
      );
      console.log(`✅ Created: ${event.title}`);
    }

    console.log('\n🎉 All test events created!');
    console.log('\nEvents created:');
    console.log('1. Team Standup (countdown timer)');
    console.log('2. Weather Alert (condition display)');
    console.log('3. Project Milestone (task progress)');
    console.log('4. Package Delivery (tracking)');
    console.log('5. Active Workout (fitness tracking)');
    console.log('\nRestart your app to see different Live Activity styles!');
    console.log('\nNote: Only the highest priority event will be shown at a time.');
    console.log('To clean up, run: node /Users/jacobkaplan/ambia/backend/cleanup-test-events.js');

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await connection.end();
  }
}

createVarietyEvents();
