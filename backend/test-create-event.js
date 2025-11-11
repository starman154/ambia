const mysql = require('mysql2/promise');

async function createTestEvent() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'admin',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'ambia'
  });

  try {
    const testEvent = {
      id: `test-${Date.now()}`,
      user_id: '410b2520-e011-70d9-1ef0-10cead18dedd',
      event_type: 'live_activity',
      title: '🎯 Test Live Activity',
      subtitle: 'Testing Dynamic Island',
      body: 'This is a test event to verify Live Activities are working!',
      priority: 'high',
      icon: 'star.fill',
      color: '#FF6B6B',
      status: 'active',
      data: JSON.stringify({ progress: 0.75 }),
      valid_until: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours from now
    };

    await connection.execute(
      `INSERT INTO ambient_events
       (id, user_id, event_type, title, subtitle, body, priority, icon, color, status, data, valid_until, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        testEvent.id,
        testEvent.user_id,
        testEvent.event_type,
        testEvent.title,
        testEvent.subtitle,
        testEvent.body,
        testEvent.priority,
        testEvent.icon,
        testEvent.color,
        testEvent.status,
        testEvent.data,
        testEvent.valid_until
      ]
    );

    console.log('✅ Test event created!');
    console.log('Event ID:', testEvent.id);
    console.log('\nNow restart your app or wait for the next sync (in 5 min)');
    console.log('You should see a Live Activity appear!');
    console.log('\nTo delete this test event, run:');
    console.log(`  node delete-test-event.js ${testEvent.id}`);

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await connection.end();
  }
}

createTestEvent();
