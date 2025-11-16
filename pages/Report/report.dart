import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_wheelchair_system/services/report_data_service.dart';

/// ReportPage displays comprehensive reports on user activity and health monitoring.
/// Data is currently mocked; replace with real data sources as needed.
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(d.inHours);
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  String formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget buildUsagePatternsCard(BuildContext context, Map usage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Patterns',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total operation time: ${formatDuration(usage['totalDuration'] ?? Duration.zero)}',
            ),
            Text('Number of sessions: ${usage['sessions']}'),
            Text('Last active: ${formatDateTime(usage['lastActive'])}'),
            const SizedBox(height: 4),
            const Text(
              'Data Source: Whole system',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAdjustmentHistoryCard(BuildContext context, List adjustments) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjustment History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ...adjustments.map(
              (adj) => Text(
                'Changed at ${formatDateTime(adj['timestamp'])}, duration: ${formatDuration(adj['duration'])}',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Data Source: AdjustableBackrestScreen',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAssistanceRequestsCard(BuildContext context, List requests) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assistance Requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ...requests.map(
              (req) => Text(
                'Called at ${formatDateTime(req['timestamp'])}, response time: ${formatDuration(req['responseTime'])}',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Data Source: SosAlertScreen',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInactivityAlertsCard(
    BuildContext context,
    List<DateTime> alerts,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inactivity Alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ...alerts.map((dt) => Text('Alert at ${formatDateTime(dt)}')),
            const SizedBox(height: 4),
            const Text(
              'Data Source: MobilityReminderScreen',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVitalSignsCard(
    BuildContext context,
    int min,
    int max,
    int avg,
    List<int> history,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vital Signs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pulse rate (min): $min bpm',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.blue),
            ),
            Text(
              'Pulse rate (max): $max bpm',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.blue),
            ),
            Text(
              'Pulse rate (avg): $avg bpm',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.blue),
            ),
            const SizedBox(height: 8),
            const Text('Pulse trend (last readings):'),
            Row(
              children:
                  history
                      .map(
                        (bpm) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            width: 12,
                            height: (bpm / 120 * 40).clamp(8, 40),
                            color: Theme.of(context).colorScheme.primary
                                .withAlpha((0.7 * 255).toInt()),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 4),
            const Text(
              'Data Source: MobilityReminderScreen',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPressureRiskCard(BuildContext context, List risks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pressure Risk Assessment',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ...risks.map(
              (risk) => Text(
                'Duration: ${formatDuration(risk['duration'])}, Risk: ${risk['risk']}',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Data Source: MobilityReminderScreen, AdjustableBackrestScreen',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportDataService>.value(
      value: ReportDataService(),
      child: Consumer<ReportDataService>(
        builder: (context, report, child) {
          final usagePatterns = {
            'totalDuration': report.totalUsage,
            'sessions': report.sessions.length,
            'lastActive': report.lastActive,
          };

          final bpmHistory = report.pulseReadings.map((e) => e.bpm).toList();
          final pressureRisk =
              report.pressureRisks
                  .map((e) => {'duration': e.duration, 'risk': e.riskLevel})
                  .toList();

          final bpmMin =
              bpmHistory.isNotEmpty
                  ? bpmHistory.reduce((a, b) => a < b ? a : b)
                  : 0;
          final bpmMax =
              bpmHistory.isNotEmpty
                  ? bpmHistory.reduce((a, b) => a > b ? a : b)
                  : 0;
          final bpmAvg =
              bpmHistory.isNotEmpty
                  ? (bpmHistory.reduce((a, b) => a + b) / bpmHistory.length)
                      .round()
                  : 0;

          return Scaffold(
            appBar: AppBar(
              title: const Text('User & Health Report'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- SUMMARY CARD ---
                Card(
                  color: Colors.blue.shade50,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(
                              Icons.timer,
                              color: Colors.blue,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDuration(
                                (usagePatterns['totalDuration'] as Duration?) ?? Duration.zero,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Text(
                              'Total Usage',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(
                              Icons.event_note,
                              color: Colors.green,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${usagePatterns['sessions']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Text(
                              'Sessions',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.orange,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDateTime(usagePatterns['lastActive'] as DateTime?),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const Text(
                              'Last Active',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Row(
                  children: const [
                    Icon(Icons.insights, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'User Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Divider(thickness: 1.3, color: Colors.blue.shade100),
                const SizedBox(height: 8),

                // --- USAGE PATTERNS ---
                buildUsagePatternsCard(context, usagePatterns),
                const SizedBox(height: 8),

                // --- SESSION HISTORY DATATABLE ---
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.history, color: Colors.deepPurple),
                            SizedBox(width: 6),
                            Text(
                              'Session History',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Start')),
                              DataColumn(label: Text('End')),
                              DataColumn(label: Text('Duration')),
                            ],
                            rows:
                                report.sessions
                                    .map(
                                      (s) => DataRow(
                                        cells: [
                                          DataCell(
                                            Text(formatDateTime(s.start)),
                                          ),
                                          DataCell(Text(formatDateTime(s.end))),
                                          DataCell(
                                            Text(formatDuration(s.duration)),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // --- ADJUSTMENT HISTORY DATATABLE ---
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.settings, color: Colors.teal),
                            SizedBox(width: 6),
                            Text(
                              'Adjustment Events',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Time')),
                              DataColumn(label: Text('Duration')),
                            ],
                            rows:
                                report.adjustments
                                    .map(
                                      (a) => DataRow(
                                        cells: [
                                          DataCell(
                                            Text(formatDateTime(a.timestamp)),
                                          ),
                                          DataCell(
                                            Text(formatDuration(a.duration)),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // --- ASSISTANCE REQUESTS TIMELINE ---
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.support_agent, color: Colors.redAccent),
                            SizedBox(width: 6),
                            Text(
                              'Assistance Requests',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...report.assistanceRequests.map(
                          (req) => ListTile(
                            leading: const Icon(
                              Icons.call,
                              color: Colors.redAccent,
                            ),
                            title: Text(
                              'Called at ${formatDateTime(req.timestamp)}',
                            ),
                            subtitle: Text(
                              'Response time: ${formatDuration(req.responseTime ?? Duration.zero)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: const [
                    Icon(Icons.health_and_safety, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Health Monitoring',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Divider(thickness: 1.3, color: Colors.green.shade100),
                const SizedBox(height: 8),

                // --- INACTIVITY ALERTS TIMELINE ---
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.notifications_active,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Inactivity Alerts',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...report.inactivityAlerts.map(
                          (alert) => ListTile(
                            leading: const Icon(
                              Icons.warning,
                              color: Colors.orange,
                            ),
                            title: Text(
                              'Alert at ${formatDateTime(alert.timestamp as DateTime?)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // --- VITAL SIGNS CHART PLACEHOLDER ---
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.favorite, color: Colors.red),
                            SizedBox(width: 6),
                            Text(
                              'Heart Rate (BPM)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Min: $bpmMin   Max: $bpmMax   Avg: $bpmAvg'),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children:
                                bpmHistory
                                    .map(
                                      (bpm) => Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          height: ((bpm / 120) * 50).clamp(
                                            8,
                                            50,
                                          ),
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // --- PRESSURE RISK CARD ---
                buildPressureRiskCard(context, pressureRisk),
              ],
            ),
          );
        },
      ),
    );
  }
}
