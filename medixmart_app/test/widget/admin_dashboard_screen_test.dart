import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medixmart_app/main.dart';

void main() {
  testWidgets('AdminDashboardScreen renders Figma 46:355 sections and data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MedixmartApp());
    await tester.pumpAndSettle();

    // Brand & User details
    expect(find.text('Medixmart Plus'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Ravindu Bandara'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);

    // KPI Cards
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('Rs. 48,750.00'), findsOneWidget);
    expect(find.text('08 Items'), findsOneWidget);
    expect(find.text('12 Batches'), findsOneWidget);
    expect(find.text('Rs. 19,400.00'), findsOneWidget);

    // 7-Day Sales & Alerts
    expect(find.text('Last 7 Days Sales'), findsOneWidget);
    expect(find.text('Rs. 284,600.00 total'), findsOneWidget);
    expect(find.text('Recent Alerts'), findsOneWidget);
    expect(find.text('View all (20)'), findsOneWidget);

    // Inventory Watchlist
    expect(find.text('Inventory Watchlist'), findsOneWidget);
    expect(find.text('Amoxicillin 250mg Cap'), findsNWidgets(2));
    expect(find.text('Paracetamol BP 500mg'), findsOneWidget);
    expect(find.text('Metformin HCl 500mg'), findsOneWidget);
  });
}
