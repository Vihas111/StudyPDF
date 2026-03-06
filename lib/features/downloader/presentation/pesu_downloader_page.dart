import 'package:flutter/material.dart';

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

  bool _busy = false;
  String _status = '';
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

  Future<void> _setup() async {
    setState(() {
      _busy = true;
      _status = 'Setting up downloader environment...';
    });
    try {
      await widget.onSetupEnvironment();
      setState(() {
        _status = 'Environment ready.';
      });
    } catch (e) {
      setState(() {
        _status = 'Setup failed: $e';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _loadCourses() async {
    if (!widget.credentialsConfigured) {
      setState(() {
        _status =
            'Set PESU username/password in Settings before loading courses.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Fetching courses...';
    });
    try {
      final courses = await widget.onFetchCourses();
      setState(() {
        _courses = courses;
        _selectedCourseId = null;
        _selectedCourseName = '';
        _courseSearch.clear();
        _units = const [];
        _selectedUnits.clear();
        _status = 'Loaded ${courses.length} courses.';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to fetch courses: $e';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _loadUnits() async {
    if (_selectedCourseId == null) {
      setState(() {
        _status = 'Select a course first.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Fetching units...';
    });
    try {
      final units = await widget.onFetchUnits(courseId: _selectedCourseId!);
      setState(() {
        _units = units;
        _selectedUnits
          ..clear()
          ..addAll(List.generate(units.length, (i) => i + 1));
        _status = 'Loaded ${units.length} units.';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to fetch units: $e';
      });
    } finally {
      setState(() => _busy = false);
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
      setState(() {
        _status =
            'Select course, units, and resource types before downloading.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Downloading resources...';
    });
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
      setState(() {
        _status = message;
      });
    } catch (e) {
      setState(() {
        _status = 'Download failed: $e';
      });
    } finally {
      setState(() => _busy = false);
    }
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
                        onPressed: _busy ? null : _setup,
                        icon: const Icon(Icons.build_outlined),
                        label: const Text('Setup Env'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _loadCourses,
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
                    enabled: !_busy && _courses.isNotEmpty,
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
                                    onTap: _busy
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
                    onPressed: _busy || _selectedCourseId == null
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
                          onSelected: _busy
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
                            onSelected: _busy
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
                        onSelected: _busy
                            ? null
                            : (v) => setState(() => _convert = v),
                      ),
                      FilterChip(
                        selected: _dedup,
                        label: const Text('Deduplicate'),
                        onSelected: _busy
                            ? null
                            : (v) => setState(() => _dedup = v),
                      ),
                      FilterChip(
                        selected: _merge,
                        label: const Text('Merge PDFs'),
                        onSelected: _busy
                            ? null
                            : (v) => setState(() => _merge = v),
                      ),
                      FilterChip(
                        selected: _cleanup,
                        label: const Text('Cleanup'),
                        onSelected: _busy
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
                        onPressed: _busy ? null : _runDownload,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Start Download'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : widget.onImportDownloads,
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
                      if (_busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_status.isEmpty ? 'No actions yet.' : _status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
