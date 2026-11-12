import '../features/mira/services/mira_suggestions.dart';
import 'package:flutter/material.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/scan_bill/screens/scan_bill_screen.dart';
import '../features/mira/screens/mira_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/mira/services/firebase_mira_service.dart';
import '../shared/theme/wattwise_theme.dart';
import '../shared/components/design_widgets.dart';
import 'app_controller.dart';

class WattWiseApp extends StatefulWidget {
  const WattWiseApp(
      {super.key,
      required this.controller,
      this.mira,
      this.miraError,
      this.accountEmail,
      this.onSignOut});
  final AppController controller;
  final FirebaseMiraService? mira;
  final String? miraError;
  final String? accountEmail;
  final Future<void> Function()? onSignOut;
  @override
  State<WattWiseApp> createState() => _WattWiseAppState();
}

class _WattWiseAppState extends State<WattWiseApp> {
  int index = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return MaterialApp(
            title: 'WattWise',
            debugShowCheckedModeBanner: false,
            theme: wattwiseTheme(false),
            darkTheme: wattwiseTheme(true),
            themeMode: c.dark ? ThemeMode.dark : ThemeMode.light,
            home: Builder(
                builder: (context) => Scaffold(
                      body: SafeArea(
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 720),
                                  child: IndexedStack(index: index, children: [
                                    DashboardScreen(
                                        controller: c,
                                        onSettings: () =>
                                            setState(() => index = 3)),
                                    ScanBillScreen(
                                        controller: c,
                                        onAskMira: () =>
                                            setState(() => index = 2)),
                                    MiraScreen(
                                        controller: c,
                                        suggestions: miraSuggestions(
                                            c.appliances,
                                            c.dailyUsages,
                                            c.bills,
                                            language: c.language),
                                        service: widget.mira,
                                        language: c.language,
                                        unavailableReason: widget.miraError,
                                        estimatedRate: c.rate,
                                        registeredPop: c.pop),
                                    SettingsScreen(
                                        controller: c,
                                        accountEmail: widget.accountEmail,
                                        onSignOut: widget.onSignOut),
                                  ])))),
                      bottomNavigationBar: SafeArea(
                          top: false,
                          child: Center(
                              heightFactor: 1,
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 720),
                                  child: Container(
                                    margin:
                                        const EdgeInsets.fromLTRB(10, 6, 10, 8),
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        border: Border.all(
                                            color:
                                                Theme.of(context).dividerColor),
                                        borderRadius:
                                            BorderRadius.circular(18)),
                                    child: Row(
                                        children: List.generate(4, (i) {
                                      const labels = [
                                        'Dashboard',
                                        'Scan Bill',
                                        'Mira',
                                        'Settings'
                                      ];
                                      const icons = [
                                        '14_6_imgDashboardIcon',
                                        '22_9_imgScanBillIcon',
                                        '17_8_imgMiraIcon',
                                        '33_21_imgSettingsIcon'
                                      ];
                                      return Expanded(
                                          child: Semantics(
                                              selected: index == i,
                                              button: true,
                                              excludeSemantics: true,
                                              onTap: () =>
                                                  setState(() => index = i),
                                              label: c.t(labels[i]),
                                              child: Material(
                                                  color: index == i
                                                      ? green
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: InkWell(
                                                      onTap: () => setState(
                                                          () => index = i),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 4),
                                                          child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                DesignIcon(
                                                                    icons[i],
                                                                    color: index ==
                                                                            i
                                                                        ? Colors
                                                                            .white
                                                                        : Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurfaceVariant),
                                                                const SizedBox(
                                                                    height: 1),
                                                                Text(
                                                                    c.t(labels[
                                                                        i]),
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600,
                                                                        color: index ==
                                                                                i
                                                                            ? Colors.white
                                                                            : Theme.of(context).colorScheme.onSurfaceVariant))
                                                              ]))))));
                                    })),
                                  )))),
                    )));
      });
}
