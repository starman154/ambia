INSERT INTO generation_queue (
  id,
  user_id,
  job_type,
  priority,
  predicted_need,
  context_data,
  scheduled_for,
  valid_until,
  status,
  attempts
) VALUES (
  UUID(),
  'test-user-123',
  'pattern_prediction',
  1,
  'User likely needs weather information for morning routine',
  '{"predicted_query": "morning weather", "confidence": 0.85, "pattern": "morning_routine"}',
  NOW(),
  DATE_ADD(NOW(), INTERVAL 30 MINUTE),
  'queued',
  0
);
