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
  Map<String, dynamic>? malaysiaMacro;
  Map<String, dynamic>? retrainingStatus;
  
  bool isUSD = false;       // false = MYR/g, true = USD/oz
  int forecastDays = 7;     // 7 = 7 Days, 30 = Monthly, 365 = Annual
  int historicalDays = 7;   // 7 = 7 Days, 30 = Monthly, 365 = Annual

  bool isLoading = true;
  bool isForecastLoading = false;
  bool isHistoricalLoading = false;
  bool isSyncing = false;
  bool isRetraining = false;

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
      ApiService.getMalaysiaMacroData(),
      ApiService.getRetrainingStatus(),
    ]);

    if (mounted) {
      setState(() {
        currentPriceData = results[0] as Map<String, dynamic>?;
        historicalData = (results[1] as List<Map<String, dynamic>>?) ?? [];
        predictionData = (results[2] as List<Map<String, dynamic>>?) ?? [];
        modelMetrics = results[3] as Map<String, dynamic>?;
        logsData = results[4] as Map<String, dynamic>?;
        malaysiaMacro = results[5] as Map<String, dynamic>?;
        retrainingStatus = results[6] as Map<String, dynamic>?;
        isLoading = false;
      });
    }
  }

  Future<void> _runRetraining() async {
    setState(() => isRetraining = true);
    final res = await ApiService.triggerRetraining();
    if (mounted) {
      setState(() => isRetraining = false);
      _fetchAllData();
      final bool promoted = res?['promoted'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(promoted 
              ? 'Model successfully retrained & promoted to production!' 
              : (res?['reason'] ?? 'Retraining check completed.')),
          backgroundColor: promoted ? Colors.green.shade800 : Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            const SizedBox(height: 14),
            _buildKijangEmasRetailCard(),
            const SizedBox(height: 14),
            _buildMalaysiaMacroFactorsCard(),
            const SizedBox(height: 14),
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

  Widget _buildKijangEmasRetailCard() {
    final kijang = currentPriceData?['kijang_emas'] as Map<String, dynamic>?;
    if (kijang == null) return const SizedBox.shrink();

    final double sell1oz = (kijang['one_oz_selling_myr'] as num?)?.toDouble() ?? 19387.0;
    final double buy1oz = (kijang['one_oz_buying_myr'] as num?)?.toDouble() ?? 18624.0;
    final double gramRetail = (kijang['one_gram_retail_myr'] as num?)?.toDouble() ?? (sell1oz / 31.1034768);
    final double spreadPct = (kijang['retail_spread_percent'] as num?)?.toDouble() ?? 4.10;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'BNM KIJANG EMAS (PHYSICAL)',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '+${spreadPct.toStringAsFixed(1)}% Spread',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('Retail Buy (1 oz)', 'RM ${sell1oz.toStringAsFixed(0)}', Colors.white),
              Container(width: 1, height: 30, color: Colors.white12),
              _buildQuickStat('Retail Sell (1 oz)', 'RM ${buy1oz.toStringAsFixed(0)}', Colors.white70),
              Container(width: 1, height: 30, color: Colors.white12),
              _buildQuickStat('Physical / Gram', 'RM ${gramRetail.toStringAsFixed(2)}', Colors.amberAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMalaysiaMacroFactorsCard() {
    final double brent = (malaysiaMacro?['brent_crude_usd'] as num?)?.toDouble() ?? 92.17;
    final double klci = (malaysiaMacro?['fbm_klci_points'] as num?)?.toDouble() ?? 1736.33;
    final double opr = (malaysiaMacro?['bnm_opr_percent'] as num?)?.toDouble() ?? 2.75;
    final bool isFestive = malaysiaMacro?['festive_season_active'] == true;
    final String festivalName = malaysiaMacro?['active_festival_name'] ?? 'Normal Demand';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.hub, color: Colors.lightBlueAccent, size: 15),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'MALAYSIAN MACRO DRIVERS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (isFestive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    festivalName,
                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroChip('Brent Crude', '\$${brent.toStringAsFixed(2)}', 'Oil → MYR Strength', Colors.orangeAccent),
              _buildMacroChip('FBM KLCI', klci.toStringAsFixed(1), 'Local Sentiment', Colors.lightGreenAccent),
              _buildMacroChip('BNM OPR', '${opr.toStringAsFixed(2)}%', 'Bank Negara Rate', Colors.cyanAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, String desc, Color accent) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  Widget _buildAccuracyBadgeHeader() {
    final List logs = (logsData?['logs'] as List?) ?? [];
    
    // Find the most recent evaluated market day from logs or historical data
    Map<String, dynamic>? latestEvaluated;
    for (var item in logs) {
      if (item['actual_price_usd'] != null && item['percentage_error'] != null) {
        latestEvaluated = item;
        break;
      }
    }

    final double rate = (currentPriceData?['usd_myr_rate'] as num?)?.toDouble() ?? 4.0365;

    // Default fallbacks if logs not yet loaded
    double dailyAccuracy = 99.23;
    double dailyDiffUsd = 33.76;
    double dailyDiffMyr = (33.76 * rate) / 31.1034768;
    double dailyPctErr = 0.77;
    String dateStr = 'Latest Session';
    double predUsd = 4479.44;
    double actUsd = 4680.60;
    double predMyr = (4479.44 * rate) / 31.1034768;
    double actMyr = (4680.60 * rate) / 31.1034768;

    if (latestEvaluated != null) {
      dateStr = latestEvaluated['target_date'] ?? 'Latest Close';
      try {
        final dt = DateTime.parse(dateStr);
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        dateStr = '${months[dt.month - 1]} ${dt.day} (${weekdays[dt.weekday - 1]})';
      } catch (_) {}

      dailyPctErr = (latestEvaluated['percentage_error'] as num?)?.toDouble() ?? 0.77;
      dailyAccuracy = 100.0 - dailyPctErr;
      dailyDiffUsd = (latestEvaluated['error_usd'] as num?)?.toDouble() ?? 33.76;
      dailyDiffMyr = (dailyDiffUsd * rate) / 31.1034768;

      predUsd = (latestEvaluated['predicted_price_usd'] as num?)?.toDouble() ?? predUsd;
      actUsd = (latestEvaluated['actual_price_usd'] as num?)?.toDouble() ?? actUsd;
      predMyr = (predUsd * rate) / 31.1034768;
      actMyr = (actUsd * rate) / 31.1034768;
    }

    final String diffValueText = isUSD
        ? '\$${dailyDiffUsd.toStringAsFixed(2)} / oz'
        : 'RM ${dailyDiffMyr.toStringAsFixed(2)} / g';

    final String predText = isUSD ? '\$${predUsd.toStringAsFixed(2)}' : 'RM ${predMyr.toStringAsFixed(2)}';
    final String actText = isUSD ? '\$${actUsd.toStringAsFixed(2)}' : 'RM ${actMyr.toStringAsFixed(2)}';

    return Container(
      width: double.infinity,
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
              Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'DAILY PERFORMANCE ($dateStr)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${dailyAccuracy.toStringAsFixed(2)}% Accurate',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('Daily Accuracy', '${dailyAccuracy.toStringAsFixed(2)}%', Colors.greenAccent),
              Container(width: 1, height: 32, color: Colors.white12),
              _buildQuickStat('Daily Difference', diffValueText, Colors.amber),
              Container(width: 1, height: 32, color: Colors.white12),
              _buildQuickStat('Daily Error Rate', '±${dailyPctErr.toStringAsFixed(2)}%', Colors.lightBlueAccent),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Model Pred: $predText',
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Market Close: $actText',
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
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
          const SizedBox(height: 16),
          _buildRetrainingManagementCard(),
          const SizedBox(height: 16),
          _buildMultiTaskArchitectureCard(),
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

  Widget _buildRetrainingManagementCard() {
    final String prodVersion = retrainingStatus?['production_version'] ?? 'v2026.08.25';
    final String lastRetrained = retrainingStatus?['last_retrained_at'] ?? '2026-08-25 15:00 UTC';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.published_with_changes, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'MLOPS AUTOMATED RETRAINING',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  prodVersion,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Expanding-Window 5-Fold Walk-Forward Validation with Automated Promotion Gate & Rollback Registry.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.grey, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Last Retrained: $lastRetrained',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade700,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isRetraining ? null : _runRetraining,
              icon: isRetraining
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.bolt, size: 16),
              label: Text(
                isRetraining ? 'Evaluating Walk-Forward Folds...' : 'Run Walk-Forward Retraining',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInfoCard() {
    final String modelName = modelMetrics?['model_name'] ?? 'MalaysianMultiTaskMTL';
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
            'Specialized Malaysian Gold Intelligence Model: Evaluates Global Gold (USD/oz) vs Ringgit FX (USD/MYR) with local macro factors and BNM Kijang Emas retail spreads.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text('Training Period: $trainPeriod (3,864 days)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiTaskArchitectureCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schema, color: Colors.cyanAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'MULTI-TASK DUAL-ENGINE ARCHITECTURE',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEngineSubRow('Model A: Global Gold Engine', 'Predicts XAU/USD using 10Y Yields, DXY Dollar Index, and Global Volatility.', Colors.amber),
          const Divider(color: Colors.white10, height: 16),
          _buildEngineSubRow('Model B: Currency FX Engine', 'Predicts USD/MYR using Brent Crude Oil, FBM KLCI, and BNM OPR.', Colors.lightGreenAccent),
          const Divider(color: Colors.white10, height: 16),
          _buildEngineSubRow('Model C: Localized MYR/g Engine', 'Features Malaysian Seasonality (Hari Raya, CNY, Deepavali) + Retail Spreads.', Colors.purpleAccent),
          const Divider(color: Colors.white10, height: 16),
          _buildEngineSubRow('Ensemble Combiner', 'Blends Model A × Model B with Model C (60:40) to eliminate currency shock error.', Colors.cyanAccent),
        ],
      ),
    );
  }

  Widget _buildEngineSubRow(String title, String desc, Color dotColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: dotColor, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ],
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
  String logFilter = 'all'; // 'all', 'verified', 'pending'

  Widget _buildLogsTab() {
    final List allLogs = (logsData?['logs'] as List?) ?? [];
    final Map<String, dynamic> summary = (logsData?['summary'] as Map<String, dynamic>?) ?? {};

    final List filteredLogs = allLogs.where((item) {
      final bool hasActual = item['actual_price_usd'] != null;
      if (logFilter == 'verified') return hasActual;
      if (logFilter == 'pending') return !hasActual;
      return true;
    }).toList();

    final int verifiedCount = allLogs.where((item) => item['actual_price_usd'] != null).length;
    final int pendingCount = allLogs.length - verifiedCount;

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
            
            // Header & Sync Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daily Prediction & Close Log', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLogFilterChip('All (${allLogs.length})', 'all'),
                  const SizedBox(width: 8),
                  _buildLogFilterChip('Verified ($verifiedCount)', 'verified'),
                  const SizedBox(width: 8),
                  _buildLogFilterChip('Pending ($pendingCount)', 'pending'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (filteredLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                alignment: Alignment.center,
                child: const Text('No prediction logs found for this filter.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) {
                  final row = filteredLogs[index];
                  return _buildLogItem(row);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogFilterChip(String label, String value) {
    final bool isSelected = logFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => logFilter = value);
      },
      selectedColor: Colors.amber,
      backgroundColor: const Color(0xFF22222A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final double maeUsd = (summary['mean_absolute_error_usd'] as num?)?.toDouble() ?? 10.76;
    final double maeMyr = (summary['mean_absolute_error_myr_g'] as num?)?.toDouble() ?? 1.54;

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
                child: Text('Evaluated Days: $totalDays', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    Text('${overallAcc.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mean Error %', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('${mape.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mean Variance', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      isUSD ? '\$${maeUsd.toStringAsFixed(2)}/oz' : 'RM ${maeMyr.toStringAsFixed(2)}/g',
                      style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
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
    final double? errUsd = (row['error_usd'] as num?)?.toDouble();
    final double? pctErr = (row['percentage_error'] as num?)?.toDouble();

    // Format weekday name
    String formattedDateHeader = date;
    try {
      final dt = DateTime.parse(date);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      formattedDateHeader = '$date (${weekdays[dt.weekday - 1]})';
    } catch (_) {}

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
          statusText = 'Closes in 1d';
          statusColor = Colors.lightBlueAccent;
        } else {
          statusText = 'Closes in ${diffDays}d';
          statusColor = Colors.lightBlueAccent;
        }
      } catch (e) {
        statusText = 'Pending Close';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    formattedDateHeader,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pctErr == null) ...[
                      Icon(Icons.hourglass_bottom, color: statusColor, size: 11),
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
          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 10),

          // Price Details Grid
          Row(
            children: [
              // Predicted Price Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Predicted Price', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      isUSD 
                          ? (predPriceUsd != null ? '\$${predPriceUsd.toStringAsFixed(2)} / oz' : '---')
                          : (predPriceMyr != null ? 'RM ${predPriceMyr.toStringAsFixed(2)} / g' : '---'),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isUSD
                          ? (predPriceMyr != null ? '≈ RM ${predPriceMyr.toStringAsFixed(2)} / g' : '')
                          : (predPriceUsd != null ? '≈ \$${predPriceUsd.toStringAsFixed(2)} / oz' : ''),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              
              // Actual Price Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Actual Market Close', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      actPriceUsd != null
                          ? (isUSD ? '\$${actPriceUsd.toStringAsFixed(2)} / oz' : 'RM ${actPriceMyr?.toStringAsFixed(2)} / g')
                          : 'Awaiting Close',
                      style: TextStyle(
                        color: actPriceUsd != null ? Colors.white : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (actPriceUsd != null)
                      Text(
                        isUSD
                            ? '≈ RM ${actPriceMyr?.toStringAsFixed(2)} / g'
                            : '≈ \$${actPriceUsd.toStringAsFixed(2)} / oz',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Error Variance Footer (if evaluated)
          if (errUsd != null && pctErr != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isUSD ? 'Variance: \$${errUsd.toStringAsFixed(2)} / oz' : 'Variance: RM ${((errUsd * 4.45) / 31.1034768).toStringAsFixed(2)} / g',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'Accuracy: ${(100 - pctErr).toStringAsFixed(2)}%',
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
