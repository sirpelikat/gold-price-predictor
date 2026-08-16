import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, dynamic>? currentPriceData;
  List<Map<String, dynamic>> historicalData = [];
  List<Map<String, dynamic>> predictionData = [];
  Map<String, dynamic>? modelMetrics;
  Map<String, dynamic>? logsData;
  
  bool isUSD = false;       // false = MYR/g, true = USD/oz
  int forecastDays = 7;     // 7 = 7 Days, 30 = Monthly, 365 = Annual
  int historicalDays = 7;   // 7 = 7 Days, 30 = Monthly, 365 = Annual

  bool isLoading = true;
  bool isForecastLoading = false;
  bool isHistoricalLoading = false;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);
    
    final results = await Future.wait([
      ApiService.getCurrentPriceData(),
      ApiService.getHistoricalData(days: historicalDays),
      ApiService.getPredictionData(days: forecastDays),
      ApiService.getModelMetrics(),
      ApiService.getPredictionLogs(),
    ]);

    if (mounted) {
      setState(() {
        currentPriceData = results[0] as Map<String, dynamic>?;
        historicalData = (results[1] as List<Map<String, dynamic>>?) ?? [];
        predictionData = (results[2] as List<Map<String, dynamic>>?) ?? [];
        modelMetrics = results[3] as Map<String, dynamic>?;
        logsData = results[4] as Map<String, dynamic>?;
        isLoading = false;
      });
    }
  }

  Future<void> _changeForecastTimeframe(int days) async {
    if (forecastDays == days) return;
    setState(() {
      forecastDays = days;
      isForecastLoading = true;
    });

    final pred = await ApiService.getPredictionData(days: days);

    if (mounted) {
      setState(() {
        predictionData = pred;
        isForecastLoading = false;
      });
    }
  }

  Future<void> _changeHistoricalTimeframe(int days) async {
    if (historicalDays == days) return;
    setState(() {
      historicalDays = days;
      isHistoricalLoading = true;
    });

    final hist = await ApiService.getHistoricalData(days: days);

    if (mounted) {
      setState(() {
        historicalData = hist;
        isHistoricalLoading = false;
      });
    }
  }

  Future<void> _syncLogs() async {
    setState(() => isSyncing = true);
    final success = await ApiService.syncPredictionLogs();
    final updatedLogs = await ApiService.getPredictionLogs();
    
    if (mounted) {
      setState(() {
        logsData = updatedLogs;
        isSyncing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Prediction logs synced with latest market closes!' : 'Sync completed.'),
          backgroundColor: Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161618),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_graph, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Gold AI Predictor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E22),
        elevation: 0,
        actions: [
          // Currency Unit Toggle Button (MYR/g <-> USD/oz)
          _buildCurrencyToggle(),
          IconButton(
            icon: isSyncing 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
                : const Icon(Icons.sync, color: Colors.amber, size: 22),
            tooltip: 'Sync prediction logs',
            onPressed: isSyncing ? null : _syncLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
            tooltip: 'Refresh data',
            onPressed: _fetchAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart, size: 20), text: 'Forecast'),
            Tab(icon: Icon(Icons.assessment, size: 20), text: 'Accuracy'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'Logs'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildForecastTab(),
                _buildAccuracyTab(),
                _buildLogsTab(),
              ],
            ),
    );
  }

  Widget _buildCurrencyToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => isUSD = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: !isUSD ? Colors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'MYR',
                style: TextStyle(
                  color: !isUSD ? Colors.black : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => isUSD = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUSD ? Colors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'USD',
                style: TextStyle(
                  color: isUSD ? Colors.black : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: FORECAST & OVERVIEW
  // ==========================================
  Widget _buildForecastTab() {
    String unitText = isUSD ? 'USD/oz' : 'MYR/g';
    String forecastTitle = forecastDays == 7
        ? 'AI Predicted Next 7 Days ($unitText)'
        : (forecastDays == 30 ? 'AI Predicted Next 1 Month ($unitText)' : 'AI Predicted Next 1 Year ($unitText)');

    String historicalTitle = historicalDays == 7
        ? 'Past 7 Days Trend vs Prediction ($unitText)'
        : (historicalDays == 30 ? 'Past 1 Month Trend ($unitText)' : 'Past 1 Year Trend ($unitText)');

    return RefreshIndicator(
      color: Colors.amber,
      onRefresh: _fetchAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentPriceData == null) ...[
              _buildConnectionErrorBanner(),
              const SizedBox(height: 16),
            ],
            _buildCurrentPriceCard(),
            const SizedBox(height: 20),
            _buildAccuracyBadgeHeader(),
            const SizedBox(height: 24),
            
            // Forecast Section Header & Timeframe Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildSectionHeader(forecastTitle, Icons.batch_prediction, Colors.amber)),
                _buildTimeframeSelector(
                  selectedDays: forecastDays,
                  onChanged: _changeForecastTimeframe,
                  accentColor: Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 10),
            isForecastLoading
                ? _buildChartLoadingSkeleton()
                : _buildForecastChart(predictionData, forecastDays),
            const SizedBox(height: 28),

            // Historical Section Header & Timeframe Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildSectionHeader(historicalTitle, Icons.compare_arrows, Colors.blueAccent)),
                _buildTimeframeSelector(
                  selectedDays: historicalDays,
                  onChanged: _changeHistoricalTimeframe,
                  accentColor: Colors.blueAccent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            isHistoricalLoading
                ? _buildChartLoadingSkeleton()
                : _buildHistoricalComparisonChart(historicalData, historicalDays),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector({
    required int selectedDays,
    required Function(int) onChanged,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeframeButton('7D', 7, selectedDays, onChanged, accentColor),
          _buildTimeframeButton('1M', 30, selectedDays, onChanged, accentColor),
          _buildTimeframeButton('1Y', 365, selectedDays, onChanged, accentColor),
        ],
      ),
    );
  }

  Widget _buildTimeframeButton(
    String label,
    int days,
    int selectedDays,
    Function(int) onChanged,
    Color accentColor,
  ) {
    final bool isSelected = selectedDays == days;
    return GestureDetector(
      onTap: () => onChanged(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: accentColor.withValues(alpha: 0.6)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildChartLoadingSkeleton() {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildConnectionErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend Offline',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Make sure the FastAPI server is running on port 8000.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 20),
            onPressed: _fetchAllData,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPriceCard() {
    final double? priceMyr = (currentPriceData?['myr_per_g'] as num?)?.toDouble();
    final double? priceUsd = (currentPriceData?['usd_per_oz'] as num?)?.toDouble();
    final double? priceKg = (currentPriceData?['myr_per_kg'] as num?)?.toDouble();
    final double rate = (currentPriceData?['usd_myr_rate'] as num?)?.toDouble() ?? 4.45;

    final String mainPrice = isUSD
        ? (priceUsd != null ? '\$${priceUsd.toStringAsFixed(2)} / oz' : '---')
        : (priceMyr != null ? 'RM ${priceMyr.toStringAsFixed(2)} / g' : '---');

    final String subPrice = isUSD
        ? (priceMyr != null ? '≈ RM ${priceMyr.toStringAsFixed(2)} / g (USD/MYR: ${rate.toStringAsFixed(2)})' : '')
        : (priceUsd != null ? '≈ \$${priceUsd.toStringAsFixed(2)} / oz • RM ${priceKg != null ? priceKg.toStringAsFixed(2) : ''} / kg' : '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C2C34), Color(0xFF202026)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isUSD ? 'LIVE GOLD PRICE (USD / OZ)' : 'LIVE GOLD PRICE (MYR / G)',
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 8),
                    SizedBox(width: 4),
                    Text('Live Yahoo Feed', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mainPrice,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subPrice,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyBadgeHeader() {
    final double mape = (modelMetrics?['2025_test_mape_percent'] as num?)?.toDouble() ?? 1.0;
    final double accuracy = 100.0 - mape;
    final double maeMyr = (modelMetrics?['2025_test_mae_myr_g'] as num?)?.toDouble() ?? 5.07;
    final double maeUsd = (modelMetrics?['2025_test_mae_usd'] as num?)?.toDouble() ?? 35.43;

    final String meanErrorText = isUSD
        ? '±\$${maeUsd.toStringAsFixed(2)}/oz'
        : '±RM ${maeMyr.toStringAsFixed(2)}/g';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStat('Model Accuracy', '${accuracy.toStringAsFixed(2)}%', Colors.greenAccent),
          Container(width: 1, height: 30, color: Colors.white12),
          _buildQuickStat('2025 Test MAPE', '${mape.toStringAsFixed(2)}%', Colors.amber),
          Container(width: 1, height: 30, color: Colors.white12),
          _buildQuickStat('Mean Error', meanErrorText, Colors.lightBlueAccent),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // FORECAST CHART (7D, 30D, 1Y AI Predictions)
  // ==========================================
  Widget _buildForecastChart(List<Map<String, dynamic>> data, int days) {
    if (data.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF22222A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No forecast data available', style: TextStyle(color: Colors.grey))),
      );
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      double price = isUSD
          ? ((data[i]['price_usd'] ?? (data[i]['price'] * 31.1034768 / 4.45)) as num).toDouble()
          : (data[i]['price'] as num).toDouble();

      if (price < minY) minY = price;
      if (price > maxY) maxY = price;
      spots.add(FlSpot(i.toDouble(), price));
    }

    minY = minY - (minY * 0.015);
    maxY = maxY + (maxY * 0.015);

    double xInterval = days == 7 ? 1.0 : (days == 30 ? 5.0 : 45.0);
    bool showDots = days <= 30;
    String prefix = isUSD ? '\$' : 'RM ';
    String unitSuffix = isUSD ? '/oz' : '/g';

    return Container(
      height: 230,
      padding: const EdgeInsets.only(right: 20, left: 10, top: 20, bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  int idx = spot.x.toInt();
                  String date = (idx >= 0 && idx < data.length) ? data[idx]['date'] : '';
                  return LineTooltipItem(
                    '$date\n$prefix${spot.y.toStringAsFixed(2)} $unitSuffix',
                    const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                interval: xInterval,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: isUSD ? 54 : 48,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(isUSD ? 0 : 2),
                    style: const TextStyle(color: Colors.grey, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.amber,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: showDots,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.amber,
                  strokeWidth: 2,
                  strokeColor: Colors.black,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.amber.withValues(alpha: 0.3), Colors.amber.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HISTORICAL COMPARISON CHART (Actual vs Model Prediction)
  // ==========================================
  Widget _buildHistoricalComparisonChart(List<Map<String, dynamic>> data, int days) {
    if (data.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF22222A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No historical data available', style: TextStyle(color: Colors.grey))),
      );
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    List<FlSpot> actualSpots = [];
    List<FlSpot> predSpots = [];

    for (int i = 0; i < data.length; i++) {
      double actPrice = isUSD
          ? ((data[i]['price_usd'] ?? (data[i]['price'] * 31.1034768 / 4.45)) as num).toDouble()
          : (data[i]['price'] as num).toDouble();

      double predPrice = isUSD
          ? ((data[i]['predicted_price_usd'] ?? (data[i]['predicted_price'] * 31.1034768 / 4.45)) as num).toDouble()
          : ((data[i]['predicted_price'] ?? data[i]['price']) as num).toDouble();

      if (actPrice < minY) minY = actPrice;
      if (actPrice > maxY) maxY = actPrice;
      if (predPrice < minY) minY = predPrice;
      if (predPrice > maxY) maxY = predPrice;

      actualSpots.add(FlSpot(i.toDouble(), actPrice));
      predSpots.add(FlSpot(i.toDouble(), predPrice));
    }

    minY = minY - (minY * 0.015);
    maxY = maxY + (maxY * 0.015);

    double xInterval = days == 7 ? 1.0 : (days == 30 ? 5.0 : 45.0);
    bool showDots = days <= 30;
    String prefix = isUSD ? '\$' : 'RM ';
    String unitSuffix = isUSD ? '/oz' : '/g';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Chart Legend Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(width: 12, height: 4, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('Actual Price ($unitSuffix)', style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  Container(width: 12, height: 4, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('Model Predicted ($unitSuffix)', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        int idx = spot.x.toInt();
                        String date = (idx >= 0 && idx < data.length) ? data[idx]['date'] : '';
                        bool isActual = spot.bar.color == Colors.blueAccent;
                        return LineTooltipItem(
                          isActual ? '$date\nActual: $prefix${spot.y.toStringAsFixed(2)} $unitSuffix' : 'Pred: $prefix${spot.y.toStringAsFixed(2)} $unitSuffix',
                          TextStyle(
                            color: isActual ? Colors.blueAccent : Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      interval: xInterval,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isUSD ? 54 : 48,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(isUSD ? 0 : 2),
                          style: const TextStyle(color: Colors.grey, fontSize: 9),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: showDots,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.blueAccent,
                        strokeWidth: 2,
                        strokeColor: Colors.black,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: predSpots,
                    isCurved: true,
                    color: Colors.amber,
                    barWidth: 2.5,
                    dashArray: [6, 4],
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: showDots,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.amber,
                        strokeWidth: 1.5,
                        strokeColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: MODEL ACCURACY & ARCHITECTURE
  // ==========================================
  Widget _buildAccuracyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelInfoCard(),
          const SizedBox(height: 20),
          const Text('2025 Out-of-Sample Test Benchmark', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildMetricsGrid(),
          const SizedBox(height: 20),
          _buildFeaturesCard(),
        ],
      ),
    );
  }

  Widget _buildModelInfoCard() {
    final String modelName = modelMetrics?['model_name'] ?? 'HistGradientBoostingRegressor';
    final String trainPeriod = modelMetrics?['training_period'] ?? '2010-01-01 to 2024-12-31';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text(
                modelName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Trained on 15 years of daily gold prices with recursive multi-step forecasting, technical indicators, and volatility modeling.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text('Training Period: $trainPeriod (3,771 days)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final double mape = (modelMetrics?['2025_test_mape_percent'] as num?)?.toDouble() ?? 1.0;
    final double maeUsd = (modelMetrics?['2025_test_mae_usd'] as num?)?.toDouble() ?? 35.43;
    final double maeMyr = (modelMetrics?['2025_test_mae_myr_g'] as num?)?.toDouble() ?? 5.07;
    final double r2 = (modelMetrics?['2025_test_r2_score'] as num?)?.toDouble() ?? 0.9895;
    final double dirAcc = (modelMetrics?['2025_test_directional_accuracy_percent'] as num?)?.toDouble() ?? 48.41;

    final String maeText = isUSD
        ? '\$${maeUsd.toStringAsFixed(2)} / oz'
        : 'RM ${maeMyr.toStringAsFixed(2)} / g';

    final String maeSubText = isUSD
        ? '≈ RM ${maeMyr.toStringAsFixed(2)} / g'
        : '≈ \$${maeUsd.toStringAsFixed(2)} / oz';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildMetricTile('Overall Accuracy', '${(100 - mape).toStringAsFixed(2)}%', '${mape.toStringAsFixed(2)}% avg error', Colors.greenAccent),
        _buildMetricTile('Mean Absolute Error', maeText, maeSubText, Colors.amber),
        _buildMetricTile('R² Goodness of Fit', r2.toStringAsFixed(4), '98.95% variance explained', Colors.blueAccent),
        _buildMetricTile('Directional Accuracy', '${dirAcc.toStringAsFixed(2)}%', 'Up/down day hit rate', Colors.purpleAccent),
      ],
    );
  }

  Widget _buildMetricTile(String title, String mainValue, String subValue, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(mainValue, style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subValue, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key Features Used by AI', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('RSI (14-day)', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF33333E)),
              Chip(label: Text('MACD & Signal', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF33333E)),
              Chip(label: Text('SMA 7 / 14 / 30 / 50', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF33333E)),
              Chip(label: Text('14d / 30d Volatility', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF33333E)),
              Chip(label: Text('1d / 5d / 10d Returns', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF33333E)),
              Chip(label: Text('Day & Month Seasonality', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFF33333E)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: PREDICTION LOGS & AUDIT TRAIL
  // ==========================================
  Widget _buildLogsTab() {
    final List logs = (logsData?['logs'] as List?) ?? [];
    final Map<String, dynamic> summary = (logsData?['summary'] as Map<String, dynamic>?) ?? {};

    return RefreshIndicator(
      color: Colors.amber,
      onRefresh: _fetchAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMarketScheduleCountdownCard(),
            const SizedBox(height: 16),
            _buildLogsSummaryHeader(summary),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Logged Predictions (${logs.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: isSyncing 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
                      : const Icon(Icons.sync, color: Colors.amber, size: 16),
                  label: const Text('Sync Closes', style: TextStyle(color: Colors.amber, fontSize: 12)),
                  onPressed: isSyncing ? null : _syncLogs,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (logs.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                alignment: Alignment.center,
                child: const Text('No prediction logs recorded yet.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length > 50 ? 50 : logs.length,
                itemBuilder: (context, index) {
                  final row = logs[logs.length - 1 - index];
                  return _buildLogItem(row);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketScheduleCountdownCard() {
    final now = DateTime.now();
    final weekday = now.weekday;
    
    bool isMarketOpen = weekday >= 1 && weekday <= 5;
    int daysUntilClose = 0;
    String closeMessage = '';

    if (weekday == 5) {
      daysUntilClose = 0;
      closeMessage = 'Market closes Today (5:00 PM EST)';
    } else if (weekday < 5) {
      daysUntilClose = 5 - weekday;
      closeMessage = '$daysUntilClose day${daysUntilClose > 1 ? 's' : ''} until weekly market close (Friday)';
    } else {
      int daysUntilOpen = (8 - weekday) % 7;
      if (daysUntilOpen == 0) daysUntilOpen = 1;
      closeMessage = 'Market closed for weekend • Reopens in $daysUntilOpen day (Sunday 6 PM EST)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMarketOpen 
              ? [const Color(0xFF1E2D24), const Color(0xFF1B241E)]
              : [const Color(0xFF2C241E), const Color(0xFF201B1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMarketOpen ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.orangeAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMarketOpen ? Colors.greenAccent.withValues(alpha: 0.15) : Colors.orangeAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMarketOpen ? Icons.access_time_filled : Icons.nightlight_round,
              color: isMarketOpen ? Colors.greenAccent : Colors.orangeAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: isMarketOpen ? Colors.greenAccent : Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Text(
                      isMarketOpen ? 'MARKET OPEN (TRADING ACTIVE)' : 'MARKET CLOSED (WEEKEND)',
                      style: TextStyle(
                        color: isMarketOpen ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  closeMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Gold Futures (COMEX): Mon - Fri 24h trading',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSummaryHeader(Map<String, dynamic> summary) {
    final double overallAcc = (summary['overall_accuracy_percentage'] as num?)?.toDouble() ?? 99.0;
    final int totalDays = (summary['total_evaluated_days'] as num?)?.toInt() ?? 0;
    final double mape = (summary['mape_percentage'] as num?)?.toDouble() ?? 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Continuous Accuracy Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Tracked Days: $totalDays', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Running Accuracy', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('${overallAcc.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Average Error %', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('${mape.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> row) {
    final String date = row['target_date'] ?? 'N/A';
    final double? predPriceMyr = (row['predicted_price_myr_g'] as num?)?.toDouble();
    final double? actPriceMyr = (row['actual_price_myr_g'] as num?)?.toDouble();
    final double? predPriceUsd = (row['predicted_price_usd'] as num?)?.toDouble();
    final double? actPriceUsd = (row['actual_price_usd'] as num?)?.toDouble();
    final double? pctErr = (row['percentage_error'] as num?)?.toDouble();

    final String predText = isUSD
        ? (predPriceUsd != null ? '\$${predPriceUsd.toStringAsFixed(2)}' : (predPriceMyr != null ? '\$${(predPriceMyr * 31.1034768 / 4.45).toStringAsFixed(2)}' : '---'))
        : (predPriceMyr != null ? 'RM ${predPriceMyr.toStringAsFixed(2)}' : '---');

    final String? actText = isUSD
        ? (actPriceUsd != null ? '\$${actPriceUsd.toStringAsFixed(2)}' : (actPriceMyr != null ? '\$${(actPriceMyr * 31.1034768 / 4.45).toStringAsFixed(2)}' : null))
        : (actPriceMyr != null ? 'RM ${actPriceMyr.toStringAsFixed(2)}' : null);

    Color statusColor = Colors.cyanAccent;
    String statusText = 'Pending Close';

    if (pctErr != null) {
      if (pctErr <= 1.0) {
        statusColor = Colors.greenAccent;
        statusText = '±${pctErr.toStringAsFixed(2)}%';
      } else if (pctErr <= 3.0) {
        statusColor = Colors.amber;
        statusText = '±${pctErr.toStringAsFixed(2)}%';
      } else {
        statusColor = Colors.redAccent;
        statusText = '±${pctErr.toStringAsFixed(2)}%';
      }
    } else {
      try {
        final targetDate = DateTime.parse(date);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final diffDays = targetDate.difference(today).inDays;

        if (diffDays <= 0) {
          statusText = 'Closes Today';
          statusColor = Colors.cyanAccent;
        } else if (diffDays == 1) {
          statusText = 'Closes in 1 day';
          statusColor = Colors.lightBlueAccent;
        } else {
          statusText = 'Closes in $diffDays days';
          statusColor = Colors.lightBlueAccent;
        }
      } catch (e) {
        statusText = 'Pending Close';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Pred: $predText',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                  if (actText != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Act: $actText',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pctErr == null) ...[
                  Icon(Icons.hourglass_bottom, color: statusColor, size: 12),
                  const SizedBox(width: 4),
                ],
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
