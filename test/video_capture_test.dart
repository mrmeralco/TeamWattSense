import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/app/wattwise_app.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';
import 'package:wattwise/features/dashboard/services/kload_service.dart';
import 'cloud_sync_test.dart' show device;
void main(){testWidgets('Capture actual KLoad screen for video', (tester) async {
 final store=(await tester.runAsync(device))!;
 final c=AppController(applianceRepository:MemoryApplianceRepository(),billRepository:MemoryBillRepository(),dailyUsageRepository:MemoryDailyUsageRepository(),database:store.db);
 await tester.runAsync(() async {await KLoadService(store.db).scheduleActivation(startingBalance:500,rate:12);await c.load();});
 tester.view.physicalSize=const Size(393,852);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
 final font=FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter.ttf'));await font.load();
 final icons=FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));await icons.load();
 final key=GlobalKey();await tester.pumpWidget(RepaintBoundary(key:key,child:WattWiseApp(controller:c)));await tester.pump();
 await tester.runAsync(() async {await Future<void>.delayed(const Duration(milliseconds:700));});await tester.pumpAndSettle();
 expect(find.text('WattWise · KLoad'),findsOneWidget);
 await tester.runAsync(() async {final image=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await File('build/previews/kload.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});
 await tester.pumpWidget(const SizedBox());c.dispose();await tester.runAsync(store.db.close);
 });}

