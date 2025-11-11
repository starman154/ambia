const mysql = require('mysql2/promise');

async function deleteTestEvent() {
  const eventId = process.argv[2];

  if (!eventId) {
    console.error('❌ Please provide event ID');
    console.log('Usage: node delete-test-event.js <event-id>');
    process.exit(1);
  }

  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'admin',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'ambia'
  });

  try {
    const [result] = await connection.execute(
      'DELETE FROM ambient_events WHERE id = ?',
      [eventId]
    );

    if (result.affectedRows > 0) {
      console.log('✅ Test event deleted!');
    } else {
      console.log('⚠️  Event not found');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await connection.end();
  }
}

deleteTestEvent();
