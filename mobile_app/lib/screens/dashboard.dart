import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double? currentPrice;
  List<Map<String, dynamic>> historicalData = [];
  List<Map<String, dynamic>> predictionData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    
    final price = await ApiService.getCurrentPrice();
    final hist = await ApiService.getHistoricalData();
    final pred = await ApiService.getPredictionData();

    setState(() {
      currentPrice = price;
      historicalData = hist;
      predictionData = pred;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('My Gold Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: _fetchData,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentPriceCard(),
                  const SizedBox(height: 30),
                  const Text('Past 7 Days Trend', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildChart(historicalData, Colors.blueAccent),
                  const SizedBox(height: 30),
                  const Text('AI Predicted Next 7 Days', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildChart(predictionData, Colors.amber),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPriceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: Column(
        children: [
          const Text(
            'Live Gold Price (MYR/g)',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            currentPrice != null ? 'RM ${currentPrice!.toStringAsFixed(2)}' : '---',
            style: const TextStyle(
              color: Colors.amber, 
              fontSize: 36, 
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> data, Color lineColor) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data available', style: TextStyle(color: Colors.grey))),
      );
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      double price = (data[i]['price'] as num).toDouble();
      if (price < minY) minY = price;
      if (price > maxY) maxY = price;
      spots.add(FlSpot(i.toDouble(), price));
    }

    // Adjust Y bounds
    minY = minY - (minY * 0.01);
    maxY = maxY + (maxY * 0.01);

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 20, left: 5, top: 20, bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    String dateStr = data[index]['date'];
                    List<String> parts = dateStr.split('-');
                    if (parts.length == 3) {
                       return Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: Text('${parts[1]}/${parts[2]}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                       );
                    }
                  }
                  return const Text('');
                },
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
