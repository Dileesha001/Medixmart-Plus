import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/api_exception.dart';
import '../../models/category_model.dart';
import '../../providers/medicine_provider.dart';
import '../../widgets/mm_button.dart';
import '../../widgets/mm_feedback_states.dart';
import '../../widgets/mm_input_field.dart';

/// Opens the Medicine Categories modal.
///
/// Both Admin and Pharmacist users can browse category names and descriptions.
/// Only Admin users (`canCreate == true`) see the inline Add Category form.
/// When [focusCreateForm] is true, the modal closes immediately upon creating
/// a category and returns the created [CategoryModel].
Future<CategoryModel?> showCategoryModal(
  BuildContext context, {
  required bool canCreate,
  bool focusCreateForm = false,
}) {
  return showDialog<CategoryModel>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _CategoryModalDialog(
        canCreate: canCreate,
        focusCreateForm: focusCreateForm,
      );
    },
  );
}

class _CategoryModalDialog extends StatefulWidget {
  final bool canCreate;
  final bool focusCreateForm;

  const _CategoryModalDialog({
    required this.canCreate,
    required this.focusCreateForm,
  });

  @override
  State<_CategoryModalDialog> createState() => _CategoryModalDialogState();
}

class _CategoryModalDialogState extends State<_CategoryModalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _nameFocusNode = FocusNode();

  bool _isSubmitting = false;
  String? _formError;
  String? _nameServerError;
  String? _successMessage;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.canCreate && widget.focusCreateForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nameFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_isSubmitting) return;
    setState(() {
      _formError = null;
      _nameServerError = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final created = await context.read<MedicineProvider>().createCategory(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );
      if (!mounted) return;

      if (widget.focusCreateForm) {
        Navigator.of(context).pop(created);
        return;
      }

      _nameController.clear();
      _descriptionController.clear();
      setState(() {
        _isSubmitting = false;
        _successMessage = "Category '${created.name}' added.";
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _nameServerError = e.fieldError('name');
        _formError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formError = 'Unable to create category. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final query = _filterQuery.trim().toLowerCase();
    final filteredCategories = query.isEmpty
        ? provider.categories
        : provider.categories.where((cat) {
            return cat.name.toLowerCase().contains(query) ||
                (cat.description?.toLowerCase().contains(query) ?? false);
          }).toList(growable: false);

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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MmSpacing.xxl),
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
                        Text('Medicine Categories', style: MmTypography.headingH3),
                        const SizedBox(height: MmSpacing.xxs),
                        Text(
                          widget.canCreate
                              ? 'Browse catalog categories or add a new category.'
                              : 'Browse catalog categories and descriptions.',
                          style: MmTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: MmColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MmSpacing.lg),

              // Admin-only Add Category form
              if (widget.canCreate) ...[
                Container(
                  padding: const EdgeInsets.all(MmSpacing.lg),
                  decoration: BoxDecoration(
                    color: MmColors.bgCanvas,
                    borderRadius: BorderRadius.circular(MmRadius.md),
                    border: Border.all(
                      color: MmColors.borderDefault,
                      width: MmElevation.strokeThin,
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Add Category', style: MmTypography.headingH4),
                        const SizedBox(height: MmSpacing.md),
                        if (_formError != null) ...[
                          _InlineStatusBanner(
                            message: _formError!,
                            isError: true,
                          ),
                          const SizedBox(height: MmSpacing.md),
                        ] else if (_successMessage != null) ...[
                          _InlineStatusBanner(
                            message: _successMessage!,
                            isError: false,
                          ),
                          const SizedBox(height: MmSpacing.md),
                        ],
                        MmInputField(
                          fieldKey: const Key('category_name_input'),
                          label: 'Category Name *',
                          hintText: 'e.g. Vitamins & Supplements',
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          enabled: !_isSubmitting,
                          errorText: _nameServerError,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_nameServerError != null || _formError != null) {
                              setState(() {
                                _nameServerError = null;
                                _formError = null;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Category name is required.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: MmSpacing.md),
                        MmInputField(
                          fieldKey: const Key('category_description_input'),
                          label: 'Description',
                          hintText: 'Optional category notes',
                          controller: _descriptionController,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleCreate(),
                        ),
                        const SizedBox(height: MmSpacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: MmButton(
                            key: const Key('category_submit_button'),
                            label: _isSubmitting ? 'Saving...' : 'Add Category',
                            variant: MmButtonVariant.primary,
                            size: MmButtonSize.medium,
                            onPressed: _isSubmitting ? null : _handleCreate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MmSpacing.lg),
              ],

              // Search existing categories
              MmInputField(
                fieldKey: const Key('category_search_input'),
                label: 'Existing Categories (${provider.categories.length})',
                hintText: 'Filter categories...',
                controller: _searchController,
                leadingIcon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: MmColors.textMuted,
                ),
                onChanged: (value) => setState(() => _filterQuery = value),
              ),
              const SizedBox(height: MmSpacing.md),

              // Category list / error / empty state
              if (provider.categoriesError != null &&
                  provider.categories.isEmpty)
                MmErrorState(
                  title: 'Could not load categories',
                  message: provider.categoriesError!,
                  onRetry: () => provider.loadCategories(),
                )
              else if (filteredCategories.isEmpty)
                MmEmptyState(
                  icon: Icons.category_outlined,
                  title: provider.categories.isEmpty
                      ? 'No categories yet'
                      : 'No matching categories',
                  message: provider.categories.isEmpty
                      ? 'Create a category to organize your medicine catalog.'
                      : 'Try a different category search term.',
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MmRadius.md),
                      border: Border.all(
                        color: MmColors.borderDefault,
                        width: MmElevation.strokeThin,
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredCategories.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: MmColors.borderDefault,
                      ),
                      itemBuilder: (context, index) {
                        final category = filteredCategories[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MmSpacing.md,
                            vertical: MmSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: MmTypography.labelLarge,
                              ),
                              const SizedBox(height: MmSpacing.xxs),
                              Text(
                                category.description ?? 'No description',
                                style: MmTypography.bodySmall.copyWith(
                                  color: category.description != null
                                      ? MmColors.textSecondary
                                      : MmColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _InlineStatusBanner({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.md,
        vertical: MmSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isError ? MmColors.bgDangerSubtle : MmColors.bgBrandSubtle,
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(
          color: isError ? MmColors.borderDanger : MmColors.borderBrand,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            size: 16,
            color: isError ? MmColors.textDanger : MmColors.textBrand,
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: MmTypography.bodySmall.copyWith(
                color: isError ? MmColors.textDanger : MmColors.textBrand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
