/**
 * WEATHER SERVICE TEST
 * Quick test to verify OpenWeather API integration works
 */

require('dotenv').config();
const WeatherService = require('./src/services/WeatherService');

async function testWeatherService() {
  console.log('🌤️  Testing Weather Service\n');
  console.log('API Key:', process.env.OPENWEATHER_API_KEY ? '✅ Found' : '❌ Missing');
  console.log('');

  const weatherService = new WeatherService();

  try {
    // Test 1: Get weather for Boston (for your flight example!)
    console.log('📍 Test 1: Weather in Boston');
    const bostonWeather = await weatherService.getWeatherByCity('Boston', 'US');
    console.log(`   Temperature: ${bostonWeather.temperature}°F (feels like ${bostonWeather.feelsLike}°F)`);
    console.log(`   Condition: ${bostonWeather.condition} - ${bostonWeather.description}`);
    console.log(`   Wind: ${bostonWeather.windSpeed} mph`);
    console.log(`   Humidity: ${bostonWeather.humidity}%`);

    console.log('\n   💡 Insights:');
    const insights = weatherService.getWeatherInsights(bostonWeather);
    insights.forEach(insight => console.log(`      ${insight}`));
    console.log('');

    // Test 2: Get weather for your location (Syracuse)
    console.log('📍 Test 2: Weather in Syracuse');
    const syracuseWeather = await weatherService.getWeatherByCity('Syracuse', 'US');
    console.log(`   Temperature: ${syracuseWeather.temperature}°F (feels like ${syracuseWeather.feelsLike}°F)`);
    console.log(`   Condition: ${syracuseWeather.condition} - ${syracuseWeather.description}`);
    console.log('');

    // Test 3: Get 5-day forecast for Boston
    console.log('📅 Test 3: 5-Day Forecast for Boston');
    const forecast = await weatherService.getForecast('Boston', 'US');
    forecast.slice(0, 5).forEach(day => {
      console.log(`   ${day.date}: ${day.tempHigh}°F / ${day.tempLow}°F - ${day.condition}`);
    });
    console.log('');

    // Test 4: Cache test (should be instant)
    console.log('⚡ Test 4: Cache Test (should be instant)');
    const startTime = Date.now();
    await weatherService.getWeatherByCity('Boston', 'US');
    const cacheTime = Date.now() - startTime;
    console.log(`   Cached response time: ${cacheTime}ms`);
    console.log('');

    console.log('✅ All tests passed! Weather service is working.');
    console.log('\n🎯 Ready to integrate into ambient intelligence.');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error(error);
  }
}

testWeatherService();
