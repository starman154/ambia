/**
 * CALENDAR SERVICE
 *
 * Fetches and analyzes calendar events from Outlook/Microsoft Graph.
 * Provides event classification and context for ambient intelligence.
 */

const axios = require('axios');
const { getRefreshedToken } = require('../controllers/outlookOAuthController');

class CalendarService {
  constructor(db) {
    this.db = db;
    this.graphApiUrl = 'https://graph.microsoft.com/v1.0';
  }

  /**
   * Get upcoming calendar events for a user
   * @param {string} userId - User ID
   * @param {number} daysAhead - Number of days to look ahead (default: 7)
   * @returns {Promise<Array>} Array of calendar events
   */
  async getUpcomingEvents(userId, daysAhead = 7) {
    try {
      const accessToken = await getRefreshedToken(userId);

      const now = new Date();
      const endDate = new Date();
      endDate.setDate(endDate.getDate() + daysAhead);

      // Fetch events from Microsoft Graph
      const response = await axios.get(`${this.graphApiUrl}/me/calendarview`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Prefer': 'outlook.timezone="UTC"'
        },
        params: {
          startDateTime: now.toISOString(),
          endDateTime: endDate.toISOString(),
          $select: 'subject,body,bodyPreview,start,end,location,attendees,organizer,isAllDay,webLink,categories',
          $orderby: 'start/dateTime',
          $top: 50
        }
      });

      const events = response.data.value.map(event => this.parseEvent(event));

      console.log(`[Calendar] Fetched ${events.length} events for user ${userId}`);
      return events;
    } catch (error) {
      console.error('[Calendar] Error fetching events:', error.message);

      // If user hasn't granted calendar permissions, return empty array
      if (error.response?.status === 403) {
        console.log('[Calendar] User needs to grant calendar permissions');
        return [];
      }

      throw new Error(`Failed to fetch calendar events: ${error.message}`);
    }
  }

  /**
   * Parse raw Microsoft Graph event into simplified format
   * @private
   */
  parseEvent(event) {
    return {
      id: event.id,
      subject: event.subject,
      body: event.bodyPreview || '',
      fullBody: event.body?.content || '',
      startTime: new Date(event.start.dateTime + 'Z'),
      endTime: new Date(event.end.dateTime + 'Z'),
      location: this.parseLocation(event.location),
      attendees: event.attendees?.map(a => ({
        name: a.emailAddress.name,
        email: a.emailAddress.address,
        status: a.status.response
      })) || [],
      organizer: event.organizer?.emailAddress?.name || 'Unknown',
      isAllDay: event.isAllDay || false,
      categories: event.categories || [],
      webLink: event.webLink,
      rawEvent: event
    };
  }

  /**
   * Parse location from Microsoft Graph format
   * @private
   */
  parseLocation(location) {
    if (!location) return null;

    return {
      displayName: location.displayName || '',
      address: location.address?.street || '',
      city: location.address?.city || '',
      state: location.address?.state || '',
      country: location.address?.countryOrRegion || '',
      postalCode: location.address?.postalCode || '',
      coordinates: location.coordinates ? {
        latitude: location.coordinates.latitude,
        longitude: location.coordinates.longitude
      } : null
    };
  }

  /**
   * Classify an event into a type (flight, meeting, appointment, etc.)
   * @param {Object} event - Parsed calendar event
   * @returns {Object} Classification with type, confidence, and extracted data
   */
  classifyEvent(event) {
    const subject = event.subject.toLowerCase();
    const body = (event.body + ' ' + event.fullBody).toLowerCase();
    const location = event.location?.displayName?.toLowerCase() || '';

    // FLIGHT DETECTION
    const flightPatterns = [
      /\b(flight|plane|airplane|aircraft|airline)\b/i,
      /\b(depart|departure|arriving|boarding)\b/i,
      /\b[A-Z]{2,3}\s*\d{1,4}\b/, // Flight numbers (AA123, DL1234)
      /\b(gate|terminal|airport)\b/i,
      /\b(SFO|LAX|JFK|ORD|ATL|DFW|DEN|CLT|LAS|PHX|MIA|SEA|IAH|BOS|MCO|EWR|MSP|DTW|PHL|LGA|BWI|DCA|SAN|TPA|PDX|STL|HNL|BNA|AUS|MDW|RDU|SLC|IAD|SJC|MCI|CMH|CVG|PIT|IND|MKE|OAK|BUF|ONT|SNA|ABQ|BUR|SMF|RNO|SYR)/i, // Airport codes
      /\b(TSA|security|customs|immigration|baggage claim)\b/i
    ];

    let flightScore = 0;
    flightPatterns.forEach(pattern => {
      if (pattern.test(subject)) flightScore += 0.3;
      if (pattern.test(body)) flightScore += 0.15;
      if (pattern.test(location)) flightScore += 0.2;
    });

    if (flightScore >= 0.6) {
      return {
        type: 'flight',
        confidence: Math.min(flightScore, 1.0),
        extractedData: this.extractFlightData(event)
      };
    }

    // MEETING DETECTION
    const meetingPatterns = [
      /\b(meeting|call|sync|standup|1:1|one-on-one|discussion|review)\b/i,
      /\b(zoom|teams|meet|webex|skype|conference)\b/i
    ];

    let meetingScore = 0;
    meetingPatterns.forEach(pattern => {
      if (pattern.test(subject)) meetingScore += 0.25;
      if (pattern.test(body)) meetingScore += 0.1;
    });

    // Bonus for having attendees
    if (event.attendees && event.attendees.length > 0) {
      meetingScore += 0.3;
    }

    if (meetingScore >= 0.5) {
      return {
        type: 'meeting',
        confidence: Math.min(meetingScore, 1.0),
        extractedData: {
          attendeeCount: event.attendees?.length || 0,
          hasVirtualLink: /https?:\/\//.test(body),
          isRecurring: event.categories?.includes('Recurring')
        }
      };
    }

    // APPOINTMENT DETECTION (doctor, dentist, salon, etc.)
    const appointmentPatterns = [
      /\b(appointment|appt)\b/i,
      /\b(doctor|dentist|physician|checkup|physical|medical)\b/i,
      /\b(salon|haircut|spa|massage)\b/i,
      /\b(vet|veterinarian)\b/i,
      /\b(lawyer|attorney|legal)\b/i
    ];

    let appointmentScore = 0;
    appointmentPatterns.forEach(pattern => {
      if (pattern.test(subject)) appointmentScore += 0.3;
      if (pattern.test(body)) appointmentScore += 0.15;
      if (pattern.test(location)) appointmentScore += 0.2;
    });

    if (appointmentScore >= 0.5) {
      return {
        type: 'appointment',
        confidence: Math.min(appointmentScore, 1.0),
        extractedData: {
          hasLocation: !!event.location?.displayName,
          duration: (event.endTime - event.startTime) / (1000 * 60) // minutes
        }
      };
    }

    // DEADLINE DETECTION
    const deadlinePatterns = [
      /\b(due|deadline|submit|submission|turn in)\b/i,
      /\b(homework|assignment|project|paper|essay)\b/i
    ];

    let deadlineScore = 0;
    deadlinePatterns.forEach(pattern => {
      if (pattern.test(subject)) deadlineScore += 0.35;
      if (pattern.test(body)) deadlineScore += 0.2;
    });

    if (deadlineScore >= 0.5) {
      return {
        type: 'deadline',
        confidence: Math.min(deadlineScore, 1.0),
        extractedData: {
          isAllDay: event.isAllDay
        }
      };
    }

    // Default to generic event
    return {
      type: 'event',
      confidence: 0.5,
      extractedData: {}
    };
  }

  /**
   * Extract flight-specific data from event
   * @private
   */
  extractFlightData(event) {
    const text = `${event.subject} ${event.body} ${event.fullBody}`;

    // Try to extract flight number
    const flightNumberMatch = text.match(/\b([A-Z]{2,3})\s*(\d{1,4})\b/);
    const flightNumber = flightNumberMatch ? `${flightNumberMatch[1]}${flightNumberMatch[2]}` : null;

    // Try to extract airport codes
    const airportCodes = text.match(/\b([A-Z]{3})\b/g) || [];
    const uniqueCodes = [...new Set(airportCodes)].filter(code =>
      // Filter out common false positives
      !['AND', 'THE', 'FOR', 'YOU', 'ARE', 'NOT', 'BUT', 'CAN'].includes(code)
    );

    // Determine if departure or arrival
    const isDeparture = /\b(depart|departure|leaving|outbound)\b/i.test(text);
    const isArrival = /\b(arriv|arrival|landing|inbound)\b/i.test(text);

    return {
      flightNumber,
      airportCodes: uniqueCodes.slice(0, 2), // Usually origin and destination
      isDeparture: isDeparture && !isArrival,
      isArrival: isArrival && !isDeparture,
      destination: uniqueCodes.length > 1 ? uniqueCodes[1] : null,
      origin: uniqueCodes.length > 0 ? uniqueCodes[0] : null,
      location: event.location?.displayName
    };
  }

  /**
   * Get events happening today
   * @param {string} userId - User ID
   * @returns {Promise<Array>} Today's events
   */
  async getTodaysEvents(userId) {
    const allEvents = await this.getUpcomingEvents(userId, 1);

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    return allEvents.filter(event =>
      event.startTime >= today && event.startTime < tomorrow
    );
  }

  /**
   * Get next upcoming event
   * @param {string} userId - User ID
   * @returns {Promise<Object|null>} Next event or null
   */
  async getNextEvent(userId) {
    const events = await this.getUpcomingEvents(userId, 7);
    const now = new Date();

    const upcomingEvents = events.filter(event => event.startTime > now);
    return upcomingEvents.length > 0 ? upcomingEvents[0] : null;
  }

  /**
   * Calculate minutes until event
   * @param {Object} event - Calendar event
   * @returns {number} Minutes until event starts
   */
  getMinutesUntilEvent(event) {
    const now = new Date();
    const diff = event.startTime - now;
    return Math.floor(diff / (1000 * 60));
  }
}

module.exports = CalendarService;
