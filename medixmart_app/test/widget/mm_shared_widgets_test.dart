import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medixmart_app/config/app_theme.dart';
import 'package:medixmart_app/widgets/mm_feedback_states.dart';
import 'package:medixmart_app/widgets/mm_input_field.dart';

void main() {
  group('MmInputField', () {
    testWidgets(
        'renders label, hint, helper text, and swaps to error message on Form validation failure',
        (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: formKey,
              child: MmInputField(
                fieldKey: const Key('medicine_name_input'),
                label: 'Medicine Name *',
                hintText: 'Amoxicillin 500mg',
                helperText: 'Enter generic or brand name',
                controller: controller,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Medicine name is required.'
                        : null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Medicine Name *'), findsOneWidget);
      expect(find.text('Enter generic or brand name'), findsOneWidget);

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      expect(find.text('Medicine name is required.'), findsOneWidget);
      expect(find.text('Enter generic or brand name'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('medicine_name_input')),
        'Panadol',
      );
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();

      expect(find.text('Medicine name is required.'), findsNothing);
      expect(find.text('Enter generic or brand name'), findsOneWidget);
    });

    testWidgets(
        'disables text input when enabled is false and applies Figma disabled surface',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Locked Value');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MmInputField(
              fieldKey: const Key('disabled_input'),
              label: 'Disabled Field',
              controller: controller,
              enabled: false,
              size: MmInputSize.large,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(
        find.byKey(const Key('disabled_input')),
      );
      expect(textField.enabled, isFalse);

      final boxContainer = tester.widget<AnimatedContainer>(
        find.byKey(const Key('mm_input_box')),
      );
      final decoration = boxContainer.decoration! as BoxDecoration;
      expect(decoration.color, MmColors.bgSubtle);
    });
  });

  group('MmFeedbackStates', () {
    testWidgets('MmErrorState renders error copy and triggers onRetry',
        (WidgetTester tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MmErrorState(
              title: 'Could not load medicines',
              message: 'Network connection lost.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Could not load medicines'), findsOneWidget);
      expect(find.text('Network connection lost.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('MmEmptyState renders title, message, and optional CTA button',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MmEmptyState(
              icon: Icons.medication_outlined,
              title: 'No medicines yet',
              message: 'Add your first catalog item.',
              actionLabel: 'Add Medicine',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No medicines yet'), findsOneWidget);
      expect(find.text('Add your first catalog item.'), findsOneWidget);

      await tester.tap(find.text('Add Medicine'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('showMmConfirmDialog returns true on Confirm and false on Cancel',
        (WidgetTester tester) async {
      bool? lastResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  lastResult = await showMmConfirmDialog(
                    context,
                    title: 'Deactivate Medicine',
                    message: 'Historical sales remain preserved.',
                    confirmLabel: 'Deactivate',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(lastResult, isFalse);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(lastResult, isTrue);
    });
  });
}
