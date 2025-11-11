/**
 * WEATHER SERVICE
 *
 * Provides weather data and insights for ambient intelligence.
 * Uses OpenWeather API to fetch current conditions and forecasts.
 */

const https = require('https');

class WeatherService {
  constructor() {
    this.apiKey = process.env.OPENWEATHER_API_KEY;
    this.baseUrl = 'api.openweathermap.org';
    this.cache = new Map(); // Simple in-memory cache
    this.cacheDuration = 10 * 60 * 1000; // 10 minutes
  }

  /**
   * Get current weather for a city
   * @param {string} cityName - City name (e.g., "Boston", "New York")
   * @param {string} countryCode - Optional 2-letter country code (e.g., "US")
   * @returns {Promise<Object>} Weather data with insights
   */
  async getWeatherByCity(cityName, countryCode = 'US') {
    const cacheKey = `city:${cityName}:${countryCode}`;

    // Check cache first
    const cached = this.getFromCache(cacheKey);
    if (cached) {
      console.log(`[Weather] Cache hit for ${cityName}`);
      return cached;
    }

    const query = countryCode ? `${cityName},${countryCode}` : cityName;

    try {
      const data = await this.fetchWeather('/data/2.5/weather', {
        q: query,
        units: 'imperial', // Fahrenheit
        appid: this.apiKey
      });

      const weather = this.parseWeatherData(data);
      this.saveToCache(cacheKey, weather);

      console.log(`[Weather] Fetched weather for ${cityName}: ${weather.temperature}°F, ${weather.condition}`);
      return weather;
    } catch (error) {
      console.error(`[Weather] Error fetching weather for ${cityName}:`, error.message);
      throw new Error(`Failed to get weather for ${cityName}: ${error.message}`);
    }
  }

  /**
   * Get current weather by coordinates
   * @param {number} lat - Latitude
   * @param {number} lon - Longitude
   * @returns {Promise<Object>} Weather data with insights
   */
  async getWeatherByCoordinates(lat, lon) {
    const cacheKey = `coords:${lat}:${lon}`;

    const cached = this.getFromCache(cacheKey);
    if (cached) {
      console.log(`[Weather] Cache hit for coordinates ${lat},${lon}`);
      return cached;
    }

    try {
      const data = await this.fetchWeather('/data/2.5/weather', {
        lat: lat.toString(),
        lon: lon.toString(),
        units: 'imperial',
        appid: this.apiKey
      });

      const weather = this.parseWeatherData(data);
      this.saveToCache(cacheKey, weather);

      return weather;
    } catch (error) {
      console.error(`[Weather] Error fetching weather for coordinates:`, error.message);
      throw new Error(`Failed to get weather for coordinates: ${error.message}`);
    }
  }

  /**
   * Get 5-day forecast for a city
   * @param {string} cityName - City name
   * @param {string} countryCode - Optional country code
   * @returns {Promise<Array>} Array of daily forecasts
   */
  async getForecast(cityName, countryCode = 'US') {
    const query = countryCode ? `${cityName},${countryCode}` : cityName;

    try {
      const data = await this.fetchWeather('/data/2.5/forecast', {
        q: query,
        units: 'imperial',
        appid: this.apiKey
      });

      // OpenWeather returns 3-hour intervals, group by day
      const dailyForecasts = this.groupForecastByDay(data.list);

      console.log(`[Weather] Fetched ${dailyForecasts.length}-day forecast for ${cityName}`);
      return dailyForecasts;
    } catch (error) {
      console.error(`[Weather] Error fetching forecast:`, error.message);
      throw new Error(`Failed to get forecast: ${error.message}`);
    }
  }

  /**
   * Get weather insights for decision-making
   * @param {Object} weather - Parsed weather data
   * @returns {Array<string>} Array of actionable insights
   */
  getWeatherInsights(weather) {
    const insights = [];

    // Temperature insights
    if (weather.temperature < 40) {
      insights.push('🧥 Bring a heavy coat - it\'s freezing');
    } else if (weather.temperature < 60) {
      insights.push('🧥 Bring a jacket - it\'s chilly');
    } else if (weather.temperature > 85) {
      insights.push('☀️ Stay hydrated - it\'s hot');
    }

    // Precipitation insights
    if (weather.condition.toLowerCase().includes('rain')) {
      insights.push('☔ Bring an umbrella - rain expected');
    } else if (weather.condition.toLowerCase().includes('snow')) {
      insights.push('❄️ Winter weather - allow extra travel time');
    }

    // Wind insights
    if (weather.windSpeed > 20) {
      insights.push('💨 Windy conditions - secure loose items');
    }

    // Humidity insights
    if (weather.humidity > 80) {
      insights.push('💧 High humidity - may feel uncomfortable');
    }

    // General condition insights
    if (weather.condition.toLowerCase().includes('clear')) {
      insights.push('☀️ Clear skies - great day');
    } else if (weather.condition.toLowerCase().includes('cloud')) {
      insights.push('☁️ Cloudy conditions');
    }

    return insights;
  }

  /**
   * Parse raw OpenWeather API response
   * @private
   */
  parseWeatherData(data) {
    return {
      location: data.name,
      temperature: Math.round(data.main.temp),
      feelsLike: Math.round(data.main.feels_like),
      condition: data.weather[0].main,
      description: data.weather[0].description,
      icon: data.weather[0].icon,
      humidity: data.main.humidity,
      windSpeed: Math.round(data.wind.speed),
      windDirection: data.wind.deg,
      cloudiness: data.clouds.all,
      pressure: data.main.pressure,
      visibility: data.visibility,
      sunrise: new Date(data.sys.sunrise * 1000),
      sunset: new Date(data.sys.sunset * 1000),
      timestamp: new Date(data.dt * 1000)
    };
  }

  /**
   * Group forecast data by day
   * @private
   */
  groupForecastByDay(forecastList) {
    const dailyData = {};

    forecastList.forEach(item => {
      const date = new Date(item.dt * 1000);
      const dateKey = date.toISOString().split('T')[0]; // YYYY-MM-DD

      if (!dailyData[dateKey]) {
        dailyData[dateKey] = {
          date: dateKey,
          temps: [],
          conditions: [],
          humidity: [],
          windSpeed: []
        };
      }

      dailyData[dateKey].temps.push(item.main.temp);
      dailyData[dateKey].conditions.push(item.weather[0].main);
      dailyData[dateKey].humidity.push(item.main.humidity);
      dailyData[dateKey].windSpeed.push(item.wind.speed);
    });

    // Convert to array and calculate daily averages
    return Object.values(dailyData).map(day => ({
      date: day.date,
      tempHigh: Math.round(Math.max(...day.temps)),
      tempLow: Math.round(Math.min(...day.temps)),
      tempAvg: Math.round(day.temps.reduce((a, b) => a + b) / day.temps.length),
      condition: this.getMostFrequent(day.conditions),
      humidity: Math.round(day.humidity.reduce((a, b) => a + b) / day.humidity.length),
      windSpeed: Math.round(day.windSpeed.reduce((a, b) => a + b) / day.windSpeed.length)
    }));
  }

  /**
   * Get most frequent item in array
   * @private
   */
  getMostFrequent(arr) {
    const frequency = {};
    let maxCount = 0;
    let mostFrequent = arr[0];

    arr.forEach(item => {
      frequency[item] = (frequency[item] || 0) + 1;
      if (frequency[item] > maxCount) {
        maxCount = frequency[item];
        mostFrequent = item;
      }
    });

    return mostFrequent;
  }

  /**
   * Fetch weather data from OpenWeather API
   * @private
   */
  fetchWeather(path, params) {
    return new Promise((resolve, reject) => {
      const query = new URLSearchParams(params).toString();
      const url = `${path}?${query}`;

      const options = {
        hostname: this.baseUrl,
        path: url,
        method: 'GET',
        headers: {
          'User-Agent': 'Ambia/1.0'
        }
      };

      const req = https.request(options, (res) => {
        let data = '';

        res.on('data', (chunk) => {
          data += chunk;
        });

        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(JSON.parse(data));
            } catch (e) {
              reject(new Error('Failed to parse weather API response'));
            }
          } else {
            reject(new Error(`Weather API error: ${res.statusCode} - ${data}`));
          }
        });
      });

      req.on('error', (error) => {
        reject(new Error(`Network error: ${error.message}`));
      });

      req.end();
    });
  }

  /**
   * Cache management
   * @private
   */
  getFromCache(key) {
    const cached = this.cache.get(key);
    if (!cached) return null;

    const age = Date.now() - cached.timestamp;
    if (age > this.cacheDuration) {
      this.cache.delete(key);
      return null;
    }

    return cached.data;
  }

  saveToCache(key, data) {
    this.cache.set(key, {
      data,
      timestamp: Date.now()
    });
  }
}

module.exports = WeatherService;
