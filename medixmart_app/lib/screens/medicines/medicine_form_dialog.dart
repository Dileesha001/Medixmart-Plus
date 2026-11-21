import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/api_exception.dart';
import '../../models/medicine_model.dart';
import '../../providers/medicine_provider.dart';
import '../../widgets/mm_button.dart';
import '../../widgets/mm_input_field.dart';
import 'category_modal.dart';

/// Standard pharmacy dosage forms offered in the Add / Edit Medicine dialog.
const List<String> kDefaultDosageForms = [
  'Tablet',
  'Capsule',
  'Syrup',
  'Suspension',
  'Injection',
  'Cream',
  'Ointment',
  'Drops',
  'Inhaler',
  'Powder',
  'Other',
];

/// Opens the Add / Edit Medicine dialog and returns `true` if a change was saved.
Future<bool> showMedicineFormDialog(
  BuildContext context, {
  MedicineModel? initialMedicine,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _MedicineFormDialog(initialMedicine: initialMedicine);
    },
  );
  return saved ?? false;
}

class _MedicineFormDialog extends StatefulWidget {
  final MedicineModel? initialMedicine;

  const _MedicineFormDialog({this.initialMedicine});

  @override
  State<_MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<_MedicineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _categoryFieldKey = GlobalKey<FormFieldState<int>>();
  late final TextEditingController _nameController;
  late final TextEditingController _genericController;
  late final TextEditingController _brandController;
  late final TextEditingController _strengthController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _reorderLevelController;

  int? _selectedCategoryId;
  late String _selectedDosageForm;
  late List<String> _dosageOptions;

  bool _isSubmitting = false;
  String? _formError;
  Map<String, String> _serverFieldErrors = const {};

  bool get _isEditing => widget.initialMedicine != null;

  @override
  void initState() {
    super.initState();
    final med = widget.initialMedicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _genericController = TextEditingController(text: med?.genericName ?? '');
    _brandController = TextEditingController(text: med?.brand ?? '');
    _strengthController = TextEditingController(text: med?.strength ?? '');
    _sellingPriceController = TextEditingController(
      text: med != null ? med.sellingPrice.toStringAsFixed(2) : '',
    );
    _costPriceController = TextEditingController(
      text: med != null ? med.costPrice.toStringAsFixed(2) : '0.00',
    );
    _reorderLevelController = TextEditingController(
      text: med != null ? med.reorderLevel.toString() : '10',
    );

    _selectedCategoryId = med?.categoryId;

    final initialForm = (med?.dosageForm ?? 'Tablet').trim();
    _selectedDosageForm = initialForm.isEmpty ? 'Tablet' : initialForm;
    _dosageOptions = List<String>.from(kDefaultDosageForms);
    if (!_dosageOptions.contains(_selectedDosageForm)) {
      _dosageOptions.add(_selectedDosageForm);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericController.dispose();
    _brandController.dispose();
    _strengthController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  void _clearFieldError(String field) {
    if (_serverFieldErrors.containsKey(field) || _formError != null) {
      setState(() {
        final next = Map<String, String>.from(_serverFieldErrors)..remove(field);
        _serverFieldErrors = next;
        _formError = null;
      });
    }
  }

  Future<void> _handleInlineNewCategory() async {
    if (_isSubmitting) return;
    final created = await showCategoryModal(
      context,
      canCreate: true,
      focusCreateForm: true,
    );
    if (created != null && mounted) {
      setState(() {
        _selectedCategoryId = created.id;
        _clearFieldError('category_id');
      });
      _categoryFieldKey.currentState?.didChange(created.id);
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _formError = null;
      _serverFieldErrors = const {};
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      setState(() {
        _serverFieldErrors = {'category_id': 'Please select a category.'};
      });
      return;
    }

    final sellingPrice = double.parse(_sellingPriceController.text.trim());
    final rawCost = _costPriceController.text.trim();
    final costPrice = rawCost.isEmpty ? 0.0 : double.parse(rawCost);
    final rawReorder = _reorderLevelController.text.trim();
    final reorderLevel = rawReorder.isEmpty ? 10 : int.parse(rawReorder);

    final input = MedicineInput(
      categoryId: categoryId,
      name: _nameController.text.trim(),
      genericName: _genericController.text.trim(),
      brand: _brandController.text.trim(),
      dosageForm: _selectedDosageForm,
      strength: _strengthController.text.trim(),
      sellingPrice: sellingPrice,
      costPrice: costPrice,
      reorderLevel: reorderLevel,
    );

    setState(() => _isSubmitting = true);
    try {
      final provider = context.read<MedicineProvider>();
      if (_isEditing) {
        await provider.updateMedicine(widget.initialMedicine!.id, input);
      } else {
        await provider.createMedicine(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final fieldErrors = <String, String>{};
      for (final field in const [
        'name',
        'category_id',
        'selling_price',
        'cost_price',
        'reorder_level',
      ]) {
        final msg = e.fieldError(field);
        if (msg != null) {
          fieldErrors[field] = msg;
        }
      }
      setState(() {
        _isSubmitting = false;
        _serverFieldErrors = fieldErrors;
        _formError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formError = 'Unable to save medicine. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<MedicineProvider>().categories;
    final hasSelectedCategory = _selectedCategoryId != null &&
        categories.any((c) => c.id == _selectedCategoryId);
    final effectiveCategoryId = hasSelectedCategory ? _selectedCategoryId : null;

    return Dialog(
      backgroundColor: MmColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.lg),
        side: const BorderSide(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MmSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Medicine' : 'Add Medicine',
                            style: MmTypography.headingH3,
                          ),
                          const SizedBox(height: MmSpacing.xxs),
                          Text(
                            _isEditing
                                ? 'Update catalog pricing, category, or reorder threshold.'
                                : 'Create a new medicine entry in the pharmacy catalog.',
                            style: MmTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: MmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MmSpacing.lg),

                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MmSpacing.md,
                      vertical: MmSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: MmColors.bgDangerSubtle,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                      border: Border.all(
                        color: MmColors.borderDanger,
                        width: MmElevation.strokeThin,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: MmColors.textDanger,
                        ),
                        const SizedBox(width: MmSpacing.sm),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: MmTypography.bodySmall.copyWith(
                              color: MmColors.textDanger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MmSpacing.lg),
                ],

                // Medicine Name
                MmInputField(
                  fieldKey: const Key('medicine_form_name'),
                  label: 'Medicine Name *',
                  hintText: 'e.g. Panadol ActiFast',
                  controller: _nameController,
                  enabled: !_isSubmitting,
                  errorText: _serverFieldErrors['name'],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _clearFieldError('name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Medicine name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: MmSpacing.md),

                // Category dropdown + inline "+ New" shortcut
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Category *', style: MmTypography.labelMedium),
                        TextButton.icon(
                          key: const Key('medicine_form_new_category'),
                          onPressed:
                              _isSubmitting ? null : _handleInlineNewCategory,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('+ New Category'),
                          style: TextButton.styleFrom(
                            foregroundColor: MmColors.textBrand,
                            padding: const EdgeInsets.symmetric(
                              horizontal: MmSpacing.sm,
                              vertical: MmSpacing.xxs,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: MmTypography.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    KeyedSubtree(
                      key: const Key('medicine_form_category'),
                      child: DropdownButtonFormField<int>(
                        key: _categoryFieldKey,
                        initialValue: effectiveCategoryId,
                        isExpanded: true,
                        decoration: _dropdownDecoration(
                          hintText: categories.isEmpty
                              ? 'Create a category first'
                              : 'Select category',
                          errorText: _serverFieldErrors['category_id'],
                        ),
                        items: [
                          for (final cat in categories)
                            DropdownMenuItem<int>(
                              value: cat.id,
                              child: Text(
                                cat.name,
                                style: MmTypography.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedCategoryId = value;
                                  _clearFieldError('category_id');
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a category.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MmSpacing.md),

                // Generic & Brand row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 420;
                    final genericField = MmInputField(
                      fieldKey: const Key('medicine_form_generic'),
                      label: 'Generic Name',
                      hintText: 'e.g. Paracetamol',
                      controller: _genericController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                    );
                    final brandField = MmInputField(
                      fieldKey: const Key('medicine_form_brand'),
                      label: 'Brand / Manufacturer',
                      hintText: 'e.g. GSK',
                      controller: _brandController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          genericField,
                          const SizedBox(height: MmSpacing.md),
                          brandField,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: genericField),
                        const SizedBox(width: MmSpacing.md),
                        Expanded(child: brandField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: MmSpacing.md),

                // Dosage Form & Strength row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 420;
                    final dosageField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dosage Form', style: MmTypography.labelMedium),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: const Key('medicine_form_dosage_form'),
                          initialValue: _selectedDosageForm,
                          isExpanded: true,
                          decoration: _dropdownDecoration(),
                          items: [
                            for (final form in _dosageOptions)
                              DropdownMenuItem<String>(
                                value: form,
                                child: Text(
                                  form,
                                  style: MmTypography.bodyMedium,
                                ),
                              ),
                          ],
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _selectedDosageForm = value);
                                  }
                                },
                        ),
                      ],
                    );

                    final strengthField = MmInputField(
                      fieldKey: const Key('medicine_form_strength'),
                      label: 'Strength',
                      hintText: 'e.g. 500mg',
                      controller: _strengthController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          dosageField,
                          const SizedBox(height: MmSpacing.md),
                          strengthField,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: dosageField),
                        const SizedBox(width: MmSpacing.md),
                        Expanded(child: strengthField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: MmSpacing.md),

                // Pricing & Reorder Level row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 460;
                    final sellingField = MmInputField(
                      fieldKey: const Key('medicine_form_selling_price'),
                      label: 'Selling Price (LKR) *',
                      hintText: '0.00',
                      controller: _sellingPriceController,
                      enabled: !_isSubmitting,
                      errorText: _serverFieldErrors['selling_price'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearFieldError('selling_price'),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid non-negative price.';
                        }
                        return null;
                      },
                    );

                    final costField = MmInputField(
                      fieldKey: const Key('medicine_form_cost_price'),
                      label: 'Cost Price (LKR)',
                      hintText: '0.00',
                      controller: _costPriceController,
                      enabled: !_isSubmitting,
                      errorText: _serverFieldErrors['cost_price'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearFieldError('cost_price'),
                      validator: (value) {
                        final raw = value?.trim() ?? '';
                        if (raw.isEmpty) return null;
                        final parsed = double.tryParse(raw);
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid non-negative cost.';
                        }
                        return null;
                      },
                    );

                    final reorderField = MmInputField(
                      fieldKey: const Key('medicine_form_reorder_level'),
                      label: 'Reorder Level *',
                      hintText: '10',
                      controller: _reorderLevelController,
                      enabled: !_isSubmitting,
                      errorText: _serverFieldErrors['reorder_level'],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _clearFieldError('reorder_level'),
                      onFieldSubmitted: (_) => _handleSubmit(),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Enter a non-negative integer.';
                        }
                        return null;
                      },
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          sellingField,
                          const SizedBox(height: MmSpacing.md),
                          costField,
                          const SizedBox(height: MmSpacing.md),
                          reorderField,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: sellingField),
                        const SizedBox(width: MmSpacing.md),
                        Expanded(child: costField),
                        const SizedBox(width: MmSpacing.md),
                        Expanded(child: reorderField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: MmSpacing.xxl),

                // Footer actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MmButton(
                      label: 'Cancel',
                      variant: MmButtonVariant.secondary,
                      size: MmButtonSize.medium,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: MmSpacing.sm),
                    MmButton(
                      key: const Key('medicine_form_submit'),
                      label: _isSubmitting
                          ? 'Saving...'
                          : (_isEditing ? 'Save Changes' : 'Add Medicine'),
                      variant: MmButtonVariant.primary,
                      size: MmButtonSize.medium,
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration({
    String? hintText,
    String? errorText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: const BorderSide(
        color: MmColors.borderDefault,
        width: MmElevation.strokeThin,
      ),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: MmColors.bgSurface,
      hintText: hintText,
      hintStyle: MmTypography.bodyMedium.copyWith(color: MmColors.textMuted),
      errorText: errorText,
      errorStyle: MmTypography.bodySmall.copyWith(color: MmColors.textDanger),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.md,
        vertical: MmSpacing.sm,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MmRadius.md),
        borderSide: const BorderSide(
          color: MmColors.borderBrand,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MmRadius.md),
        borderSide: const BorderSide(
          color: MmColors.borderDanger,
          width: 1.5,
        ),
      ),
    );
  }
}
