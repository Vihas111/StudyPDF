import 'package:flutter/material.dart';
import 'package:studypdf/widgets/loading_phase_banner.dart';

enum DownloaderPhase {
  idle,
  setup,
  courses,
  units,
  download,
  import,
  done,
  error,
}

class DownloaderUiState {
  const DownloaderUiState({
    required this.phase,
    required this.title,
    required this.subtitle,
    required this.isBusy,
    this.lastError,
  });

  final DownloaderPhase phase;
  final String title;
  final String subtitle;
  final bool isBusy;
  final String? lastError;

  const DownloaderUiState.idle()
    : phase = DownloaderPhase.idle,
      title = 'Ready',
      subtitle = 'Choose an action to begin.',
      isBusy = false,
      lastError = null;
}

class PesuDownloaderPage extends StatefulWidget {
  const PesuDownloaderPage({
    super.key,
    required this.downloadsPath,
    required this.credentialsConfigured,
    required this.onSetupEnvironment,
    required this.onFetchCourses,
    required this.onFetchUnits,
    required this.onRunDownload,
    required this.onImportDownloads,
  });

  final String downloadsPath;
  final bool credentialsConfigured;
  final Future<void> Function() onSetupEnvironment;
  final Future<List<Map<String, dynamic>>> Function() onFetchCourses;
  final Future<List<Map<String, dynamic>>> Function({required String courseId})
  onFetchUnits;
  final Future<String> Function({
    required String courseId,
    required String courseName,
    required List<int> units,
    required List<String> resourceIds,
    required bool convert,
    required bool merge,
    required bool dedup,
    required bool cleanup,
  })
  onRunDownload;
  final Future<void> Function() onImportDownloads;

  @override
  State<PesuDownloaderPage> createState() => _PesuDownloaderPageState();
}

class _PesuDownloaderPageState extends State<PesuDownloaderPage> {
  final TextEditingController _courseSearch = TextEditingController();

  DownloaderUiState _uiState = const DownloaderUiState.idle();
  String _statusDetails = '';
  List<Map<String, dynamic>> _courses = const [];
  List<Map<String, dynamic>> _units = const [];
  String? _selectedCourseId;
  String _selectedCourseName = '';
  final Set<int> _selectedUnits = <int>{};
  final Set<String> _selectedResources = <String>{'2', '3'};
  bool _convert = true;
  bool _merge = true;
  bool _dedup = true;
  bool _cleanup = true;

  static const Map<String, String> _resources = {
    '2': 'Slides',
    '3': 'Notes',
    '4': 'QA',
    '5': 'Assignments',
    '6': 'QB',
    '7': 'MCQs',
    '8': 'References',
  };

  @override
  void dispose() {
    _courseSearch.dispose();
    super.dispose();
  }

  void _setBusy(
    DownloaderPhase phase, {
    required String title,
    required String subtitle,
  }) {
    setState(() {
      _uiState = DownloaderUiState(
        phase: phase,
        title: title,
        subtitle: subtitle,
        isBusy: true,
      );
      _statusDetails = '$title\n$subtitle';
    });
  }

  void _setDone({
    required String title,
    required String subtitle,
    String? details,
  }) {
    setState(() {
      _uiState = DownloaderUiState(
        phase: DownloaderPhase.done,
        title: title,
        subtitle: subtitle,
        isBusy: false,
      );
      _statusDetails = details ?? '$title\n$subtitle';
    });
  }

  void _setError(String message) {
    setState(() {
      _uiState = DownloaderUiState(
        phase: DownloaderPhase.error,
        title: 'Action failed',
        subtitle: message,
        isBusy: false,
        lastError: message,
      );
      _statusDetails = message;
    });
  }

  Future<void> _setup() async {
    _setBusy(
      DownloaderPhase.setup,
      title: 'Environment is being set up',
      subtitle: 'Creating virtual environment and installing dependencies...',
    );
    try {
      await widget.onSetupEnvironment();
      _setDone(
        title: 'Environment ready',
        subtitle: 'You can now load courses.',
      );
    } catch (e) {
      _setError('Setup failed: $e');
    }
  }

  Future<void> _loadCourses() async {
    if (!widget.credentialsConfigured) {
      _setError(
        'Set PESU username/password in Settings before loading courses.',
      );
      return;
    }
    _setBusy(
      DownloaderPhase.courses,
      title: 'Loading courses',
      subtitle: 'Fetching available courses from PESU...',
    );
    try {
      final courses = await widget.onFetchCourses();
      setState(() {
        _courses = courses;
        _selectedCourseId = null;
        _selectedCourseName = '';
        _courseSearch.clear();
        _units = const [];
        _selectedUnits.clear();
        _uiState = DownloaderUiState(
          phase: DownloaderPhase.done,
          title: 'Courses loaded',
          subtitle: 'Loaded ${courses.length} courses.',
          isBusy: false,
        );
        _statusDetails = 'Loaded ${courses.length} courses.';
      });
    } catch (e) {
      _setError('Failed to fetch courses: $e');
    }
  }

  Future<void> _loadUnits() async {
    if (_selectedCourseId == null) {
      _setError('Select a course first.');
      return;
    }
    _setBusy(
      DownloaderPhase.units,
      title: 'Loading units',
      subtitle: 'Fetching units for selected course...',
    );
    try {
      final units = await widget.onFetchUnits(courseId: _selectedCourseId!);
      setState(() {
        _units = units;
        _selectedUnits
          ..clear()
          ..addAll(List.generate(units.length, (i) => i + 1));
        final noUnits = units.isEmpty;
        _uiState = DownloaderUiState(
          phase: DownloaderPhase.done,
          title: noUnits ? 'No units found' : 'Units loaded',
          subtitle: noUnits
              ? 'No units were returned for the selected course.'
              : 'Loaded ${units.length} units.',
          isBusy: false,
        );
        _statusDetails = noUnits
            ? 'No units found for selected course.'
            : 'Loaded ${units.length} units.';
      });
    } catch (e) {
      _setError('Failed to fetch units: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredCourses {
    final q = _courseSearch.text.trim().toLowerCase();
    if (q.isEmpty) {
      return _courses;
    }
    return _courses
        .where((c) {
          final name = (c['subjectName'] ?? '').toString().toLowerCase();
          final code = (c['subjectCode'] ?? '').toString().toLowerCase();
          return name.contains(q) || code.contains(q);
        })
        .toList(growable: false);
  }

  Future<void> _runDownload() async {
    if (_selectedCourseId == null ||
        _selectedCourseName.isEmpty ||
        _selectedUnits.isEmpty ||
        _selectedResources.isEmpty) {
      _setError('Select course, units, and resource types before downloading.');
      return;
    }
    _setBusy(
      DownloaderPhase.download,
      title: 'Downloading resources',
      subtitle: 'Fetching files and running post-processing steps...',
    );
    try {
      final message = await widget.onRunDownload(
        courseId: _selectedCourseId!,
        courseName: _selectedCourseName,
        units: _selectedUnits.toList(growable: false)..sort(),
        resourceIds: _selectedResources.toList(growable: false),
        convert: _convert,
        merge: _merge,
        dedup: _dedup,
        cleanup: _cleanup,
      );
      _setDone(
        title: 'Download complete',
        subtitle: 'Resources are ready for import.',
        details: message,
      );
    } catch (e) {
      _setError('Download failed: $e');
    }
  }

  Future<void> _importDownloads() async {
    _setBusy(
      DownloaderPhase.import,
      title: 'Importing PDFs',
      subtitle: 'Adding downloaded PDFs into your StudyPDF library...',
    );
    try {
      await widget.onImportDownloads();
      _setDone(
        title: 'Import complete',
        subtitle: 'Downloaded PDFs were imported into your library.',
      );
    } catch (e) {
      _setError('Import failed: $e');
    }
  }

  LoadingBannerTone _phaseTone() {
    switch (_uiState.phase) {
      case DownloaderPhase.error:
        return LoadingBannerTone.error;
      case DownloaderPhase.done:
        return LoadingBannerTone.success;
      case DownloaderPhase.setup:
      case DownloaderPhase.courses:
      case DownloaderPhase.units:
      case DownloaderPhase.download:
      case DownloaderPhase.import:
        return LoadingBannerTone.busy;
      case DownloaderPhase.idle:
        return LoadingBannerTone.idle;
    }
  }

  IconData _phaseIcon() {
    return switch (_uiState.phase) {
      DownloaderPhase.setup => Icons.build_circle_outlined,
      DownloaderPhase.courses => Icons.menu_book_outlined,
      DownloaderPhase.units => Icons.topic_outlined,
      DownloaderPhase.download => Icons.download_for_offline_outlined,
      DownloaderPhase.import => Icons.library_add_check_outlined,
      DownloaderPhase.done => Icons.check_circle_outline,
      DownloaderPhase.error => Icons.error_outline,
      DownloaderPhase.idle => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PESU Downloader (Native Workflow)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  LoadingPhaseBanner(
                    title: _uiState.title,
                    subtitle: _uiState.subtitle,
                    tone: _phaseTone(),
                    leadingIcon: _phaseIcon(),
                    showBusyAnimation: _uiState.isBusy,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.credentialsConfigured
                        ? 'Credentials loaded from Settings.'
                        : 'Credentials are not set. Go to Settings to configure PESU login.',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _uiState.isBusy ? null : _setup,
                        icon: const Icon(Icons.build_outlined),
                        label: const Text('Setup Env'),
                      ),
                      FilledButton.icon(
                        onPressed: _uiState.isBusy ? null : _loadCourses,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Load Courses'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _courseSearch,
                    enabled: !_uiState.isBusy && _courses.isNotEmpty,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _courses.isEmpty
                          ? 'Course (click "Load Courses" first)'
                          : 'Search course by code or name',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_courses.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Card(
                        elevation: 0,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        child: _filteredCourses.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('No matching courses'),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredCourses.length > 30
                                    ? 30
                                    : _filteredCourses.length,
                                itemBuilder: (context, index) {
                                  final course = _filteredCourses[index];
                                  final id = course['id']?.toString() ?? '';
                                  final selected = _selectedCourseId == id;
                                  return ListTile(
                                    dense: true,
                                    selected: selected,
                                    title: Text(
                                      '${course['subjectCode'] ?? ''} - ${course['subjectName'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: _uiState.isBusy
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedCourseId = id;
                                              _selectedCourseName =
                                                  (course['subjectName'] ?? '')
                                                      .toString();
                                              _units = const [];
                                              _selectedUnits.clear();
                                            });
                                          },
                                  );
                                },
                              ),
                      ),
                    ),
                  if (_selectedCourseId != null) ...[
                    const SizedBox(height: 8),
                    Text('Selected: $_selectedCourseName'),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _uiState.isBusy || _selectedCourseId == null
                        ? null
                        : _loadUnits,
                    child: const Text('Load Units'),
                  ),
                  const SizedBox(height: 12),
                  if (_units.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_units.length, (i) {
                        final idx = i + 1;
                        final name = (_units[i]['name'] ?? '').toString();
                        final selected = _selectedUnits.contains(idx);
                        return FilterChip(
                          selected: selected,
                          label: Text('U$idx: $name'),
                          onSelected: _uiState.isBusy
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedUnits.add(idx);
                                    } else {
                                      _selectedUnits.remove(idx);
                                    }
                                  });
                                },
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resources',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _resources.entries
                        .map((entry) {
                          final selected = _selectedResources.contains(
                            entry.key,
                          );
                          return FilterChip(
                            selected: selected,
                            label: Text(entry.value),
                            onSelected: _uiState.isBusy
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value) {
                                        _selectedResources.add(entry.key);
                                      } else {
                                        _selectedResources.remove(entry.key);
                                      }
                                    });
                                  },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        selected: _convert,
                        label: const Text('Convert to PDF'),
                        onSelected: _uiState.isBusy
                            ? null
                            : (v) => setState(() => _convert = v),
                      ),
                      FilterChip(
                        selected: _dedup,
                        label: const Text('Deduplicate'),
                        onSelected: _uiState.isBusy
                            ? null
                            : (v) => setState(() => _dedup = v),
                      ),
                      FilterChip(
                        selected: _merge,
                        label: const Text('Merge PDFs'),
                        onSelected: _uiState.isBusy
                            ? null
                            : (v) => setState(() => _merge = v),
                      ),
                      FilterChip(
                        selected: _cleanup,
                        label: const Text('Cleanup'),
                        onSelected: _uiState.isBusy
                            ? null
                            : (v) => setState(() => _cleanup = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _uiState.isBusy ? null : _runDownload,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Start Download'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _uiState.isBusy ? null : _importDownloads,
                        icon: const Icon(Icons.download_done_outlined),
                        label: const Text('Import Downloaded PDFs'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Downloader output: ${widget.downloadsPath}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      if (_uiState.isBusy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _statusDetails.isEmpty ? 'No actions yet.' : _statusDetails,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
