import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/login_demo_widgets.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/view_state.dart';
import '../../data/models/category.dart';
import '../../data/services/browsing_api_service.dart';
import '../widgets/category_circle_tile.dart';

/// Lists all categories from `GET /api/categories`. Tapping a category opens
/// the stores-by-category screen using the category slug.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final BrowsingApiService _service = BrowsingApiService();

  ViewState _state = ViewState.initial;
  List<Category> _categories = const [];
  String _error = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;

    setState(() => _state = ViewState.loading);

    try {
      final categories = await _service.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _state = categories.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _state = ViewState.error;
      });
    } finally {
      _isLoading = false;
    }
  }

  void _openCategory(Category category) {
    Navigator.pushNamed(
      context,
      RouteNames.categoryStores,
      arguments: category,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: LoginDemoBackground(
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading categories...');
      case ViewState.error:
        return ErrorView(message: _error, onRetry: _load);
      case ViewState.empty:
        return EmptyView(
          title: 'No categories yet',
          message: 'Categories will appear here once they are available.',
          icon: Icons.category_outlined,
          onRetry: _load,
        );
      case ViewState.success:
        return RefreshIndicator(
          onRefresh: _load,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Roughly 92px per tile, clamped so it stays sensible on
              // phones and wide web windows alike.
              final columns = (constraints.maxWidth / 100).floor().clamp(3, 6);

              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                itemCount: _categories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return CategoryCircleTile(
                    category: category,
                    onTap: () => _openCategory(category),
                  );
                },
              );
            },
          ),
        );
    }
  }
}
