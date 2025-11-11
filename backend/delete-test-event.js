const mysql = require('mysql2/promise');

async function deleteTestEvent() {
  const eventId = process.argv[2];

  if (!eventId) {
    console.error('❌ Please provide event ID');
    console.log('Usage: node delete-test-event.js <event-id>');
    process.exit(1);
  }

  const connection = await mysql.createConnection({
    host: 'ambia-production.cpkies6y2q57.us-east-2.rds.amazonaws.com',
    user: 'admin',
    password: 'wjWoYROnFnLZwOFfKs4Ec8iIjbWst8jf',
    database: 'ambia'
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
