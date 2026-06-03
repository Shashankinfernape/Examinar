import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:isar/isar.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/question_repository.dart';
import '../../domain/models/question.dart';
import 'package:exam_command_center/core/theme/app_theme.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionRepositoryProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 900;
    final double hPad = isTablet ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: questionsAsync.when(
        data: (qRepo) => StreamBuilder<List<Question>>(
          stream: qRepo.isar.questions.where().watch(fireImmediately: true),
          builder: (context, snapshot) {
            final allQuestions = snapshot.data ?? [];
            
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 60, hPad, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Velocity', style: Theme.of(context).textTheme.displayLarge),
                        const SizedBox(height: 4),
                        const Text('Weekly task completion speed', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),

                if (allQuestions.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('Add tasks to track velocity.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: _buildVelocityChart(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.0)),
                    ),
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    sliver: _buildRecentActivityList(allQuestions),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildVelocityChart() {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 20,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const style = TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 10);
                  String text;
                  switch (value.toInt()) {
                    case 0: text = 'MON'; break;
                    case 1: text = 'TUE'; break;
                    case 2: text = 'WED'; break;
                    case 3: text = 'THU'; break;
                    case 4: text = 'FRI'; break;
                    case 5: text = 'SAT'; break;
                    case 6: text = 'SUN'; break;
                    default: text = ''; break;
                  }
                  return Padding(padding: const EdgeInsets.only(top: 10), child: Text(text, style: style));
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            _makeGroupData(0, 5),
            _makeGroupData(1, 8),
            _makeGroupData(2, 12),
            _makeGroupData(3, 10),
            _makeGroupData(4, 15),
            _makeGroupData(5, 7),
            _makeGroupData(6, 4, isToday: true),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, {bool isToday = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isToday ? AppTheme.premiumPurple : AppTheme.selectedTile,
          width: 16,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 20,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityList(List<Question> questions) {
    // Sort logic placeholder (showing mostly completed or recent ones)
    final recent = questions.take(8).toList();
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final q = recent[index];
          final isDone = q.status == QuestionStatus.completed;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isDone ? AppTheme.premiumPurple : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    q.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        childCount: recent.length,
      ),
    );
  }
}
