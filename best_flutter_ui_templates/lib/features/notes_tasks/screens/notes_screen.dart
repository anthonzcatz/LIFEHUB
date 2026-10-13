import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../providers/notes_tasks_providers.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  static const _maxVisibleNotes = 100;
  String _query = '';
  DateTimeRange? _dateRange;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
      helpText: 'Filter notes by updated date range',
    );
    if (picked == null) return;
    setState(() {
      _dateRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final query = _query.trim().toLowerCase();
    final filteredNotes = notes
        .where(
          (note) =>
              (query.isEmpty ||
                  '${note.title} ${note.content}'.toLowerCase().contains(
                    query,
                  )) &&
              (_dateRange == null ||
                  (!note.updatedAt.isBefore(_dateRange!.start) &&
                      note.updatedAt.isBefore(
                        _dateRange!.end.add(const Duration(days: 1)),
                      ))),
        )
        .toList();
    final visibleNotes = filteredNotes.take(_maxVisibleNotes).toList();
    final columns = MediaQuery.sizeOf(context).width >= 700 ? 3 : 2;

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Notes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LifeHubTheme.notes,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Note', style: TextStyle(color: Colors.white)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
        ),
      ),
      body: notes.isEmpty
          ? const EmptyState(
              message: 'No notes yet.\nJot down your first thought!',
              icon: Icons.note_alt_outlined,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search notes',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(
                          _dateRange == null
                              ? 'Updated range'
                              : '${Formatters.shortDate(_dateRange!.start)} – ${Formatters.shortDate(_dateRange!.end)}',
                        ),
                        selected: _dateRange != null,
                        onSelected: (selected) => selected
                            ? _pickDateRange()
                            : setState(() => _dateRange = null),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredNotes.length} matching note${filteredNotes.length == 1 ? '' : 's'}',
                      style: LifeHubTheme.caption,
                    ),
                  ),
                ),
                Expanded(
                  child: filteredNotes.isEmpty
                      ? const EmptyState(
                          message: 'No notes match these filters.',
                          icon: Icons.search_off,
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(
                            16,
                          ).copyWith(bottom: 90),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                          itemCount:
                              visibleNotes.length +
                              (filteredNotes.length > _maxVisibleNotes ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= visibleNotes.length) {
                              return const Center(
                                child: Text(
                                  'Showing the first 100 notes. Refine your search to view a smaller set.',
                                  textAlign: TextAlign.center,
                                  style: LifeHubTheme.caption,
                                ),
                              );
                            }
                            final note = visibleNotes[i];
                            return FadeSlideIn.item(
                              index: i,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        NoteEditorScreen(note: note),
                                  ),
                                ),
                                onLongPress: () =>
                                    _confirmDelete(context, ref, note.id),
                                child: Container(
                                  decoration: LifeHubTheme.cardDecoration,
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        note.title.isEmpty
                                            ? 'Untitled'
                                            : note.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: LifeHubTheme.subtitle.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Text(
                                          note.content,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: LifeHubTheme.caption,
                                        ),
                                      ),
                                      Text(
                                        Formatters.shortDate(note.updatedAt),
                                        style: LifeHubTheme.caption.copyWith(
                                          fontSize: 10,
                                          color: LifeHubTheme.deactivatedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(notesProvider.notifier).remove(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
