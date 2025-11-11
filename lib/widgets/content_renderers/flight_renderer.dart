import 'package:flutter/material.dart';
import '../../models/information_content.dart';

class FlightRenderer extends StatelessWidget {
  final InformationContent content;

  const FlightRenderer({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final flightData = content.data;

    return Container(
      key: const ValueKey('flight'),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flight header
            _buildHeader(),
            const SizedBox(height: 32),

            // Flight details
            _buildFlightInfo(flightData),
            const SizedBox(height: 32),

            // AI Predictions section - this is the Ambia magic
            if (content.predictions.isNotEmpty) ...[
              _buildPredictionsSection(content.predictions),
              const SizedBox(height: 24),
            ],

            // Additional contextual info based on priority
            _buildContextualInfo(content.priority, flightData),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.flight_takeoff, color: Colors.white, size: 32),
        const SizedBox(width: 16),
        Text(
          'Flight',
          style: TextStyle(
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildFlightInfo(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Flight Number', data['flightNumber'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow('From', data['from'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow('To', data['to'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow('Departure', data['departureTime'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow('Gate', data['gate'] ?? 'TBD'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsSection(List<String> predictions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ambia Insights',
          style: TextStyle(
            color: Colors.blue.withOpacity(0.8),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        ...predictions.map((prediction) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline,
                color: Colors.blue.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  prediction,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildContextualInfo(int priority, Map<String, dynamic> data) {
    // Higher priority = more contextual information
    // This is where Ambia shines - showing relevant info based on importance
    if (priority < 70) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Important',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This is a high-priority event. Ambia has gathered additional context.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
