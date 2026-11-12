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
        'todayKwh': todayKwh,
        'yesterdayKwh': yesterdayKwh,
        'todayAvailable': todayAvailable,
        'yesterdayAvailable': yesterdayAvailable,
        'todayValue': todayAvailable ? amountFormat.format(todayKwh) : '—',
        'yesterdayValue':
            yesterdayAvailable ? amountFormat.format(yesterdayKwh) : '—',
        'todayTotal': todayAvailable ? '${amountFormat.format(todayKwh)} kWh' : '—',
        'yesterdayTotal':
            yesterdayAvailable ? '${amountFormat.format(yesterdayKwh)} kWh' : '—',
        'differenceKwh': difference,
        'comparisonAvailable': comparisonAvailable,
        'differenceLower': comparisonAvailable && difference < 0,
        'todayProgress': comparisonAvailable && (todayKwh > yesterdayKwh ? todayKwh : yesterdayKwh) > 0
            ? (todayKwh / (todayKwh > yesterdayKwh ? todayKwh : yesterdayKwh) * 1000).round()
            : 0,
        'yesterdayProgress': comparisonAvailable && (todayKwh > yesterdayKwh ? todayKwh : yesterdayKwh) > 0
            ? (yesterdayKwh / (todayKwh > yesterdayKwh ? todayKwh : yesterdayKwh) * 1000).round()
            : 0,
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
