import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// ENTRY POINT
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register all dependencies via IoC container.
  dependencyInjector();

  // Initialise async dependencies (storage + load persisted tasks + read theme).
  await initDependencies();

  final Routes appRoutes = Routes();

  runApp(
    MyApp(
      appRoutes: appRoutes,
      settingController: locator<SettingController>(),
    ),
  );
}

// ---------------------------------------------------------------------------
// ROOT WIDGET
// ---------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  final Routes appRoutes;
  final SettingController settingController;

  const MyApp({
    super.key,
    required this.appRoutes,
    required this.settingController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingModel>(
      valueListenable: settingController,
      builder: (context, settingModel, child) {
        return MaterialApp(
          title: 'To-Do List',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settingModel.isDarkTheme
              ? ThemeMode.dark
              : ThemeMode.light,
          routes: appRoutes.routes,
          initialRoute: Routes.home,
        );
      },
    );
  }

  // Refined, cohesive theme with warm tones and custom typography.
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: const Color(0xFFE07A5F),
      onPrimary: Colors.white,
      secondary: const Color(0xFF3D405B),
      onSecondary: Colors.white,
      error: const Color(0xFFD62839),
      onError: Colors.white,
      surface: isDark ? const Color(0xFF1C1C2E) : const Color(0xFFFAF9F6),
      onSurface: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C2E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'Georgia',
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0EDE8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// IoC / DEPENDENCY INJECTION
// ---------------------------------------------------------------------------

final locator = GetIt.instance;

void dependencyInjector() {
  _startStorageService();
  _startTaskFeature();
  _startSettingFeature();
}

void _startStorageService() {
  locator.registerLazySingleton<StorageService>(() => StorageServiceImpl());
}

void _startTaskFeature() {
  locator.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(storageService: locator<StorageService>()),
  );
  locator.registerLazySingleton<TaskController>(
    () => TaskControllerImpl(taskRepository: locator<TaskRepository>()),
  );
}

void _startSettingFeature() {
  locator.registerLazySingleton<SettingRepository>(
    () => SettingRepositoryImpl(storageService: locator<StorageService>()),
  );
  locator.registerLazySingleton<SettingController>(
    () =>
        SettingControllerImpl(settingRepository: locator<SettingRepository>()),
  );
}

Future<void> initDependencies() async {
  await locator<StorageService>().initStorage();
  await Future.wait([
    locator<TaskController>().loadTasks(),
    locator<SettingController>().readTheme(),
  ]);
}

// ---------------------------------------------------------------------------
// ROUTES
// ---------------------------------------------------------------------------

class Routes {
  static String get home => TaskRoutes.taskList;

  final routes = <String, WidgetBuilder>{
    ...TaskRoutes().routes,
    ...SettingRoutes().routes,
  };
}

class TaskRoutes {
  static String get taskList => '/tasks';

  final routes = <String, WidgetBuilder>{
    taskList: (BuildContext context) {
      // View always receives its controller instance via routes.
      return TaskListView(taskController: locator<TaskController>());
    },
  };
}

class SettingRoutes {
  static String get setting => '/settings';

  final routes = <String, WidgetBuilder>{
    setting: (BuildContext context) {
      // View always receives its controller instance via routes.
      return SettingView(settingController: locator<SettingController>());
    },
  };
}

// ---------------------------------------------------------------------------
// CONSTANTS
// ---------------------------------------------------------------------------

class Constants {
  static const String tasksKey = 'tasks_list';
  static const String darkMode = 'DarkMode';
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

/// Represents a single to-do task with lifecycle timestamps.
class TaskModel {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy with selective field overrides.
  TaskModel copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serialises to JSON for persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Deserialises from JSON.
  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    isCompleted: json['isCompleted'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

/// Wraps the list of tasks and the active filter/search state.
class TaskListModel {
  final List<TaskModel> tasks;
  final TaskFilter filter;
  final String searchQuery;

  const TaskListModel({
    this.tasks = const [],
    this.filter = TaskFilter.all,
    this.searchQuery = '',
  });

  TaskListModel copyWith({
    List<TaskModel>? tasks,
    TaskFilter? filter,
    String? searchQuery,
  }) {
    return TaskListModel(
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Returns tasks matching the active filter and search query.
  List<TaskModel> get filteredTasks {
    var result = tasks;

    // Apply status filter.
    if (filter == TaskFilter.pending) {
      result = result.where((t) => !t.isCompleted).toList();
    } else if (filter == TaskFilter.completed) {
      result = result.where((t) => t.isCompleted).toList();
    }

    // Apply text search (case-insensitive).
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result
          .where(
            (t) =>
                t.title.toLowerCase().contains(query) ||
                t.description.toLowerCase().contains(query),
          )
          .toList();
    }

    return result;
  }

  int get totalCount => tasks.length;
  int get pendingCount => tasks.where((t) => !t.isCompleted).length;
  int get completedCount => tasks.where((t) => t.isCompleted).length;
}

enum TaskFilter { all, pending, completed }

// ---------------------------------------------------------------------------
// SERVICE LAYER – encapsulates external library (SharedPreferences)
// ---------------------------------------------------------------------------

// The service layer must only be used to encapsulate external libraries.
abstract interface class StorageService {
  Future<void> initStorage();
  Future<String?> getString({required String key});
  Future<void> setString({required String key, required String value});
  Future<void> remove({required String key});
  Future<bool> getBoolValue({required String key});
  Future<void> setBoolValue({required String key, required bool value});
}

class StorageServiceImpl implements StorageService {
  late final SharedPreferences _storage;

  @override
  Future<void> initStorage() async {
    try {
      _storage = await SharedPreferences.getInstance();
    } catch (error) {
      throw Exception('StorageService init failed: $error');
    }
  }

  @override
  Future<String?> getString({required String key}) async {
    try {
      return _storage.getString(key);
    } catch (error) {
      throw Exception('StorageService.getString: $error');
    }
  }

  @override
  Future<void> setString({required String key, required String value}) async {
    try {
      await _storage.setString(key, value);
    } catch (error) {
      throw Exception('StorageService.setString: $error');
    }
  }

  @override
  Future<void> remove({required String key}) async {
    try {
      await _storage.remove(key);
    } catch (error) {
      throw Exception('StorageService.remove: $error');
    }
  }

  @override
  Future<bool> getBoolValue({required String key}) async {
    try {
      return _storage.getBool(key) ?? false;
    } catch (error) {
      throw Exception('StorageService.getBoolValue: $error');
    }
  }

  @override
  Future<void> setBoolValue({required String key, required bool value}) async {
    try {
      await _storage.setBool(key, value);
    } catch (error) {
      throw Exception('StorageService.setBoolValue: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// REPOSITORY – data access layer for tasks
// ---------------------------------------------------------------------------

abstract interface class TaskRepository {
  Future<List<TaskModel>> readAll();
  Future<void> saveAll(List<TaskModel> tasks);
}

class TaskRepositoryImpl implements TaskRepository {
  final StorageService storageService;

  TaskRepositoryImpl({required this.storageService});

  @override
  Future<List<TaskModel>> readAll() async {
    try {
      final raw = await storageService.getString(key: Constants.tasksKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw Exception('TaskRepository.readAll: $error');
    }
  }

  @override
  Future<void> saveAll(List<TaskModel> tasks) async {
    try {
      final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
      await storageService.setString(key: Constants.tasksKey, value: encoded);
    } catch (error) {
      throw Exception('TaskRepository.saveAll: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// SETTING – MODEL
// ---------------------------------------------------------------------------

/// Holds user preference state (currently only dark theme toggle).
class SettingModel {
  final bool isDarkTheme;

  SettingModel({this.isDarkTheme = false});
}

// ---------------------------------------------------------------------------
// SETTING – REPOSITORY
// ---------------------------------------------------------------------------

abstract interface class SettingRepository {
  Future<SettingModel> readTheme();
  Future<void> updateTheme({required bool isDarkTheme});
}

class SettingRepositoryImpl implements SettingRepository {
  final StorageService storageService;

  SettingRepositoryImpl({required this.storageService});

  @override
  Future<SettingModel> readTheme() async {
    try {
      final isDarkMode = await storageService.getBoolValue(
        key: Constants.darkMode,
      );
      return SettingModel(isDarkTheme: isDarkMode);
    } catch (error) {
      throw Exception('SettingRepository.readTheme: $error');
    }
  }

  @override
  Future<void> updateTheme({required bool isDarkTheme}) async {
    try {
      await storageService.setBoolValue(
        key: Constants.darkMode,
        value: isDarkTheme,
      );
    } catch (error) {
      throw Exception('SettingRepository.updateTheme: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// SETTING – CONTROLLER
// ---------------------------------------------------------------------------

// Use of interfaces in controllers is mandatory.
abstract interface class SettingController extends ValueNotifier<SettingModel> {
  SettingController(super.initialState);

  Future<void> readTheme();
  Future<void> updateTheme({required bool isDarkTheme});
}

class SettingControllerImpl extends ValueNotifier<SettingModel>
    implements SettingController {
  final SettingRepository settingRepository;

  SettingControllerImpl({required this.settingRepository})
    : super(SettingModel());

  @override
  Future<void> readTheme() async {
    final settingModel = await settingRepository.readTheme();
    final model = SettingModel(isDarkTheme: settingModel.isDarkTheme);
    _emit(model);
  }

  @override
  Future<void> updateTheme({required bool isDarkTheme}) async {
    await settingRepository.updateTheme(isDarkTheme: isDarkTheme);
    final model = SettingModel(isDarkTheme: isDarkTheme);
    _emit(model);
  }

  // Internal _emit() usage is mandatory.
  void _emit(SettingModel newValue) {
    value = newValue;
    debugPrint('SettingController: isDarkTheme=${value.isDarkTheme}');
  }
}

// ---------------------------------------------------------------------------
// CONTROLLER – business logic and state management via ValueNotifier
// ---------------------------------------------------------------------------

abstract interface class TaskController extends ValueNotifier<TaskListModel> {
  TaskController(super.initialState);

  Future<void> loadTasks();
  Future<void> addTask({required String title, required String description});
  Future<void> updateTask({
    required String id,
    required String title,
    required String description,
  });
  Future<void> toggleTask({required String id});
  Future<void> deleteTask({required String id});
  void setFilter(TaskFilter filter);
  void setSearch(String query);
}

class TaskControllerImpl extends ValueNotifier<TaskListModel>
    implements TaskController {
  final TaskRepository taskRepository;

  TaskControllerImpl({required this.taskRepository})
    : super(const TaskListModel());

  @override
  Future<void> loadTasks() async {
    final tasks = await taskRepository.readAll();
    _emit(value.copyWith(tasks: tasks));
  }

  @override
  Future<void> addTask({
    required String title,
    required String description,
  }) async {
    final now = DateTime.now();
    final newTask = TaskModel(
      // Simple unique ID based on timestamp.
      id: now.millisecondsSinceEpoch.toString(),
      title: title.trim(),
      description: description.trim(),
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );

    final updated = [newTask, ...value.tasks];
    await _persist(updated);
  }

  @override
  Future<void> updateTask({
    required String id,
    required String title,
    required String description,
  }) async {
    final updated = value.tasks.map((task) {
      if (task.id != id) return task;
      return task.copyWith(
        title: title.trim(),
        description: description.trim(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    await _persist(updated);
  }

  @override
  Future<void> toggleTask({required String id}) async {
    final updated = value.tasks.map((task) {
      if (task.id != id) return task;
      return task.copyWith(
        isCompleted: !task.isCompleted,
        updatedAt: DateTime.now(),
      );
    }).toList();

    await _persist(updated);
  }

  @override
  Future<void> deleteTask({required String id}) async {
    final updated = value.tasks.where((t) => t.id != id).toList();
    await _persist(updated);
  }

  @override
  void setFilter(TaskFilter filter) {
    _emit(value.copyWith(filter: filter));
  }

  @override
  void setSearch(String query) {
    _emit(value.copyWith(searchQuery: query));
  }

  // Saves to repository and broadcasts state update.
  Future<void> _persist(List<TaskModel> tasks) async {
    await taskRepository.saveAll(tasks);
    _emit(value.copyWith(tasks: tasks));
  }

  // Internal emit – single place to update ValueNotifier value.
  void _emit(TaskListModel newValue) {
    value = newValue;
    debugPrint(
      'TaskController: total=${newValue.totalCount} '
      'pending=${newValue.pendingCount} '
      'completed=${newValue.completedCount}',
    );
  }
}

// ---------------------------------------------------------------------------
// VIEW – Task List
// ---------------------------------------------------------------------------

class TaskListView extends StatefulWidget {
  final TaskController taskController;

  const TaskListView({super.key, required this.taskController});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _openTaskForm({TaskModel? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFormSheet(
        taskController: widget.taskController,
        existingTask: task,
      ),
    );
  }

  void _confirmDelete(BuildContext context, TaskModel task) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete task?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('"${task.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.taskController.deleteTask(id: task.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<TaskListModel>(
        valueListenable: widget.taskController,
        builder: (context, model, _) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, model),
              _buildSearchBar(context),
              _buildFilterChips(context, model),
              _buildStatsRow(context, model),
              _buildTaskList(context, model),
            ],
          );
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimController,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton.extended(
          key: const Key('add_task_fab'),
          onPressed: () => _openTaskForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'New Task',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, TaskListModel model) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      expandedHeight: 120,
      actions: [
        IconButton(
          key: const Key('settings_navigation'),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.of(context).pushNamed(SettingRoutes.setting);
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Tasks',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          key: const Key('search_field'),
          controller: _searchController,
          onChanged: widget.taskController.setSearch,
          decoration: InputDecoration(
            hintText: 'Search tasks…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      widget.taskController.setSearch('');
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, TaskListModel model) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Wrap(
          spacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              count: model.totalCount,
              selected: model.filter == TaskFilter.all,
              onSelected: () => widget.taskController.setFilter(TaskFilter.all),
            ),
            _FilterChip(
              label: 'Pending',
              count: model.pendingCount,
              selected: model.filter == TaskFilter.pending,
              onSelected: () =>
                  widget.taskController.setFilter(TaskFilter.pending),
            ),
            _FilterChip(
              label: 'Done',
              count: model.completedCount,
              selected: model.filter == TaskFilter.completed,
              onSelected: () =>
                  widget.taskController.setFilter(TaskFilter.completed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, TaskListModel model) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = model.totalCount == 0
        ? 0.0
        : model.completedCount / model.totalCount;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${model.completedCount} of ${model.totalCount} completed',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colorScheme.primary.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, TaskListModel model) {
    final tasks = model.filteredTasks;

    if (tasks.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyState(
          filter: model.filter,
          hasSearch: model.searchQuery.isNotEmpty,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final task = tasks[index];
          return _TaskCard(
            key: ValueKey(task.id),
            task: task,
            onToggle: () => widget.taskController.toggleTask(id: task.id),
            onEdit: () => _openTaskForm(task: task),
            onDelete: () => _confirmDelete(context, task),
          );
        }, childCount: tasks.length),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REUSABLE WIDGETS
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? colorScheme.onPrimary : colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.onPrimary.withOpacity(0.25)
                    : colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? colorScheme.onPrimary : colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget representing a single task in the list.
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = task.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completion toggle button.
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? colorScheme.primary : Colors.transparent,
                      border: Border.all(
                        color: isDone
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                // Task content.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isDone
                              ? colorScheme.onSurface.withOpacity(0.4)
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDone
                                ? colorScheme.onSurface.withOpacity(0.3)
                                : colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Timestamp row.
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: colorScheme.onSurface.withOpacity(0.35),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(task.updatedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withOpacity(0.35),
                            ),
                          ),
                          if (isDone) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button.
                IconButton(
                  key: Key('delete_task_${task.id}'),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: colorScheme.error.withOpacity(0.6),
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Empty state widget with contextual message.
class _EmptyState extends StatelessWidget {
  final TaskFilter filter;
  final bool hasSearch;

  const _EmptyState({required this.filter, required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String emoji;
    String title;
    String subtitle;

    if (hasSearch) {
      emoji = '🔍';
      title = 'No results found';
      subtitle = 'Try a different search term.';
    } else if (filter == TaskFilter.completed) {
      emoji = '🎯';
      title = 'No completed tasks yet';
      subtitle = 'Finish some tasks and they\'ll appear here.';
    } else if (filter == TaskFilter.pending) {
      emoji = '✅';
      title = 'All caught up!';
      subtitle = 'No pending tasks remaining.';
    } else {
      emoji = '📋';
      title = 'No tasks yet';
      subtitle = 'Tap the button below to add your first task.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TASK FORM SHEET – used for both creating and editing tasks
// ---------------------------------------------------------------------------

class TaskFormSheet extends StatefulWidget {
  final TaskController taskController;
  final TaskModel? existingTask; // null = create mode

  const TaskFormSheet({
    super.key,
    required this.taskController,
    this.existingTask,
  });

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _isLoading = false;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingTask?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingTask?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await widget.taskController.updateTask(
          id: widget.existingTask!.id,
          title: _titleController.text,
          description: _descriptionController.text,
        );
      } else {
        await widget.taskController.addTask(
          title: _titleController.text,
          description: _descriptionController.text,
        );
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Sheet title.
            Text(
              _isEditing ? 'Edit Task' : 'New Task',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 4),
              Text(
                'Created ${_formatCreatedAt(widget.existingTask!.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Title field.
            TextFormField(
              key: const Key('task_title_field'),
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'What needs to be done?',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a title.';
                }
                if (v.trim().length > 100) {
                  return 'Title must be 100 characters or less.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Description field.
            TextFormField(
              key: const Key('task_description_field'),
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Add more details (optional)…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: Key(_isEditing ? 'update_task_btn' : 'save_task_btn'),
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Add Task',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCreatedAt(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// VIEW – Settings
// ---------------------------------------------------------------------------

class SettingView extends StatelessWidget {
  final SettingController settingController;

  const SettingView({super.key, required this.settingController});

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationIcon: const FlutterLogo(),
      applicationName: 'To-Do List',
      applicationVersion: 'Version 1.0.0',
      applicationLegalese: '\u{a9} 2026',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          // Dark theme toggle – mirrors the documentation pattern exactly.
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Dark theme'),
            trailing: ValueListenableBuilder<SettingModel>(
              valueListenable: settingController,
              builder: (context, settingModel, child) {
                return Switch(
                  value: settingModel.isDarkTheme,
                  onChanged: (bool isDarkTheme) {
                    settingController.updateTheme(isDarkTheme: isDarkTheme);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }
}
