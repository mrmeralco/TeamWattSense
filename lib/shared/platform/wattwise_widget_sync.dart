import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../app/app_controller.dart';

class WattWiseWidgetSync {
  static const MethodChannel _channel =
      MethodChannel('com.example.wattwise/widget');

  static Future<void> update(AppController controller) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayAvailable = controller.hasUsageForDay(today);
    final yesterdayAvailable = controller.hasUsageForDay(yesterday);
    final todayKwh = controller.recordedKwhForDay(today);
    final yesterdayKwh = controller.recordedKwhForDay(yesterday);
    final difference = todayKwh - yesterdayKwh;
    final comparisonAvailable = todayAvailable && yesterdayAvailable;
    final amountFormat = NumberFormat('#,##0.0', 'en_PH');

    try {
      await _channel.invokeMethod<void>('updateWidget', {
        'todayDate': DateFormat('yyyy-MM-dd').format(today),
        'yesterdayDate': DateFormat('yyyy-MM-dd').format(yesterday),
        'todayAvailable': todayAvailable,
        'yesterdayAvailable': yesterdayAvailable,
        'todayTotal': todayAvailable ? '${amountFormat.format(todayKwh)} kWh' : '—',
        'yesterdayTotal':
            yesterdayAvailable ? '${amountFormat.format(yesterdayKwh)} kWh' : '—',
        'difference': comparisonAvailable
            ? '${difference.abs().toStringAsFixed(1)} kWh ${difference < 0 ? 'lower' : difference > 0 ? 'higher' : 'same'}'
            : 'Comparison unavailable',
        'differenceLower': comparisonAvailable && difference < 0,
        'todayProgress': comparisonAvailable && todayKwh + yesterdayKwh > 0
            ? (todayKwh / (todayKwh + yesterdayKwh) * 1000).round()
            : 500,
        'yesterdayProgress': comparisonAvailable && todayKwh + yesterdayKwh > 0
            ? (yesterdayKwh / (todayKwh + yesterdayKwh) * 1000).round()
            : 500,
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
