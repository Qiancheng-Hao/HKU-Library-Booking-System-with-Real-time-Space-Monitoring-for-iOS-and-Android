import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/reservations/presentation/screens/reservation_list_screen.dart';
import '../widgets/library_list_item.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/ui/widgets/empty_state.dart';
import '../../../../core/ui/widgets/loading_state.dart';
import '../../data/library_repository.dart';
import '../controllers/library_catalog_controller.dart';

class LibraryListScreen extends StatefulWidget {
  const LibraryListScreen({super.key});

  @override
  State<LibraryListScreen> createState() => _LibraryListScreenState();
}

class _LibraryListScreenState extends State<LibraryListScreen> {
  late final LibraryCatalogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LibraryCatalogController(
      libraryRepository: context.read<LibraryRepository>(),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ChangeNotifierProvider<LibraryCatalogController>.value(
      value: _controller,
      child: DefaultTabController(
        length: 2,
        child: Consumer<LibraryCatalogController>(
          builder: (context, controller, child) {
            return Column(
              children: [
                Container(
                  color: cs.surfaceContainerLow,
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Book'),
                      Tab(text: 'My Reservations'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              border: Border(
                                bottom: BorderSide(color: cs.outlineVariant),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'All Libraries',
                              style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child:
                                controller.isLoading &&
                                    controller.libraries.isEmpty
                                ? const LoadingState(
                                    message: 'Loading libraries...',
                                  )
                                : controller.hasError &&
                                      controller.libraries.isEmpty
                                ? EmptyState(
                                    icon: Icons.error_outline,
                                    title: 'Something went wrong',
                                    message: controller.errorMessage,
                                    action: ElevatedButton(
                                      onPressed: controller.refresh,
                                      child: const Text('Retry'),
                                    ),
                                  )
                                : controller.libraries.isEmpty
                                ? const EmptyState(
                                    icon: Icons.local_library_outlined,
                                    title: 'No libraries found',
                                    message: 'Pull down to refresh.',
                                  )
                                : RefreshIndicator(
                                    onRefresh: controller.refresh,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.sm,
                                      ),
                                      itemCount: controller.libraries.length,
                                      itemBuilder: (context, index) =>
                                          LibraryListItem(
                                            library:
                                                controller.libraries[index],
                                          ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const ReservationListScreen(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
