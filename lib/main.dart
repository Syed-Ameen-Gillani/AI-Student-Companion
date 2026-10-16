import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdfrx/pdfrx.dart';
import 'core/database/app_database.dart';
import 'core/network/gemini_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/study_ui.dart';
import 'features/home/home_screen.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/library/library_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  runApp(const StudentCompanion());
}

class StudentCompanion extends StatefulWidget {
  const StudentCompanion({super.key});
  @override
  State<StudentCompanion> createState() => _StudentCompanionState();
}

class _StudentCompanionState extends State<StudentCompanion> {
  AppDatabase? store;
  GeminiService? gemini;
  String? error;
  String theme = 'system';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final database = await AppDatabase.open();
      final mode = await database.setting('theme') ?? 'system';
      if (mounted) {
        setState(() {
          store = database;
          gemini = GeminiService(const FlutterSecureStorage());
          theme = mode;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Student Companion',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: theme == 'light'
        ? ThemeMode.light
        : theme == 'dark'
        ? ThemeMode.dark
        : ThemeMode.system,
    home: store == null
        ? Scaffold(
            body: Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Text('Could not open local data: $error'),
            ),
          )
        : Shell(
            store: store!,
            gemini: gemini!,
            theme: theme,
            onTheme: (value) async {
              await store!.setSetting('theme', value);
              setState(() => theme = value);
            },
          ),
  );
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.store,
    required this.gemini,
    required this.theme,
    required this.onTheme,
  });
  final AppDatabase store;
  final GeminiService gemini;
  final String theme;
  final ValueChanged<String> onTheme;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  int revision = 0;
  bool setup = false;
  static const names = [
    'Home',
    'Assistant',
    'Notes',
    'Tasks',
    'Library',
    'Settings',
  ];
  static const icons = [
    Icons.home_outlined,
    Icons.auto_awesome_outlined,
    Icons.note_alt_outlined,
    Icons.checklist_outlined,
    Icons.folder_outlined,
    Icons.settings_outlined,
  ];
  @override
  void initState() {
    super.initState();
    checkSetup();
  }

  Future<void> checkSetup() async {
    if (await widget.store.setting('setup_done') != 'yes' && mounted) {
      setState(() => setup = true);
    }
  }

  void refresh() {
    if (mounted) setState(() => revision++);
  }

  void go(int index) => setState(() => tab = index);

  void openGeminiSettings(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Gemini')),
        body: SettingsScreen(
          store: widget.store,
          gemini: widget.gemini,
          theme: widget.theme,
          onTheme: widget.onTheme,
          onChange: refresh,
          geminiOnly: true,
        ),
      ),
    ),
  );

  Widget geminiAction(BuildContext context) => IconButton(
    tooltip: 'Gemini settings',
    onPressed: () => openGeminiSettings(context),
    icon: const Icon(Icons.auto_awesome_outlined),
  );

  @override
  Widget build(BuildContext context) {
    if (setup) {
      return SetupScreen(
        store: widget.store,
        gemini: widget.gemini,
        onDone: () => setState(() => setup = false),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final pages = [
      HomeScreen(store: widget.store, revision: revision, onGo: go),
      AssistantScreen(
        store: widget.store,
        gemini: widget.gemini,
        revision: revision,
        onChange: refresh,
      ),
      NotesScreen(
        store: widget.store,
        gemini: widget.gemini,
        revision: revision,
        onChange: refresh,
      ),
      TasksScreen(
        store: widget.store,
        gemini: widget.gemini,
        revision: revision,
        onChange: refresh,
      ),
      LibraryScreen(store: widget.store, revision: revision, onChange: refresh),
      SettingsScreen(
        store: widget.store,
        gemini: widget.gemini,
        theme: widget.theme,
        onTheme: widget.onTheme,
        onChange: refresh,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (tab == 0) ...[
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(tab == 0 ? 'Student Companion' : names[tab]),
          ],
        ),
        actions: [
          if (wide && tab == 5) geminiAction(context),
          if (!wide)
            IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Settings'),
                      actions: [geminiAction(context)],
                    ),
                    body: SettingsScreen(
                      store: widget.store,
                      gemini: widget.gemini,
                      theme: widget.theme,
                      onTheme: widget.onTheme,
                      onChange: refresh,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < names.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icons[i]),
                    label: Text(names[i]),
                  ),
              ],
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: pages[tab],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: go,
              destinations: [
                for (var i = 0; i < 5; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: names[i]),
              ],
            ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.store,
    required this.gemini,
    required this.onDone,
  });
  final AppDatabase store;
  final GeminiService gemini;
  final VoidCallback onDone;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final keyController = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    keyController.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    setState(() => busy = true);
    if (keyController.text.trim().isNotEmpty) {
      await widget.gemini.saveKey(keyController.text);
    }
    await widget.store.setSetting('setup_done', 'yes');
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'A calmer way to study',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome to Student Companion',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Keep your materials, ideas, and deadlines together.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: const [
                        ListTile(
                          leading: SoftIcon(Icons.lock_outline),
                          title: Text('Saved on this device'),
                          subtitle: Text(
                            'Your notes, tasks, chats, and files stay local.',
                          ),
                        ),
                        ListTile(
                          leading: SoftIcon(Icons.auto_awesome_outlined),
                          title: Text('AI when you choose'),
                          subtitle: Text(
                            'Selected text is sent to Google for AI requests.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API key (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : finish,
                    child: const Text('Continue'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You can add an API key later in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void showError(BuildContext context, Object error) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('FormatException: ', '')),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String detail) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
