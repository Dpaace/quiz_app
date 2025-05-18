import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth/login_screen.dart';

bool showPercentage = true;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<List<Map<String, dynamic>>> _getUserScores() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot =
        await FirebaseFirestore.instance
            .collection('user_scores')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<Map<String, double>> _getAverageScoresPerLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    final result = <String, List<int>>{};

    final snapshot =
        await FirebaseFirestore.instance
            .collection('user_scores')
            .where('userId', isEqualTo: user!.uid)
            .get();

    for (var doc in snapshot.docs) {
      final level = doc['level'] as String;
      final score = doc['score'] as int;
      final total = doc['total'] as int;

      result.putIfAbsent(level, () => []);
      result[level]!.add(((score / total) * 100).toInt());
    }

    return result.map((level, scores) {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      return MapEntry(level, avg);
    });
  }

  Future<void> _resetQuizAttempts(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Reset All Attempts?"),
            content: const Text(
              "This will permanently delete all your quiz scores.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm"),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();
      final snapshots =
          await FirebaseFirestore.instance
              .collection('user_scores')
              .where('userId', isEqualTo: user.uid)
              .get();

      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All quiz attempts deleted")),
      );

      // Force UI refresh
      (context as Element).markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      user?.email ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Chart Section
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getUserScores(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No quiz data yet.");
                }

                final scores = snapshot.data!;
                final spots = <FlSpot>[];

                for (int i = 0; i < scores.length; i++) {
                  final data = scores[i];
                  final double score = data['score'].toDouble();
                  final double total = data['total'].toDouble();
                  final double value =
                      showPercentage ? (score / total * 100) : score;
                  spots.add(FlSpot(i.toDouble(), value));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Performance Over Time",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Text("Raw"),
                            Switch(
                              value: showPercentage,
                              onChanged: (val) {
                                showPercentage = val;
                                (context as Element).markNeedsBuild();
                              },
                            ),
                            const Text("Percentage"),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.deepPurple.shade50,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              barWidth: 3,
                              color: Colors.deepPurple,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter:
                                    (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                          radius: 4,
                                          color: Colors.deepPurple,
                                          strokeWidth: 1.5,
                                          strokeColor: Colors.white,
                                        ),
                              ),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  if (value.toInt() < scores.length) {
                                    return Text((value.toInt() + 1).toString());
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipMargin: 8,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((e) {
                                  final raw = scores[e.x.toInt()];
                                  return LineTooltipItem(
                                    showPercentage
                                        ? "${e.y.toStringAsFixed(1)}%\n"
                                        : "Score: ${raw['score']}/${raw['total']}\n",
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          minY: 0,
                          maxY: showPercentage ? 100 : null,
                        ),
                        duration: const Duration(milliseconds: 800),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            const Text(
              "Quiz Attempts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // Attempts List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getUserScores(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text("No quiz attempts yet.");
                  }

                  return ListView.separated(
                    itemCount: snapshot.data!.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final score = snapshot.data![index];
                      final level = score['level'];
                      final result = "${score['score']}/${score['total']}";
                      final date = (score['timestamp'] as Timestamp?)?.toDate();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: Text(level[0].toUpperCase()),
                        ),
                        title: Text("Level: ${level.toUpperCase()}"),
                        subtitle: Text(
                          "Score: $result\n${date != null ? date.toString().split('.').first : ''}",
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _resetQuizAttempts(context),
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: const Text(
                "Reset All Attempts",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
