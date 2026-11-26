import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/workspace/saved_workspace.dart';
import 'package:qfli_studio_core/workspace/workspace_store.dart';

void main() {
  late Directory temporary;
  late Directory metadata;
  late WorkspaceStore store;
  late Project primary;
  late Project secondary;
  late List<WorkspaceStore> stores;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('qfli_saved_workspaces_');
    metadata = Directory(p.join(temporary.path, 'workspaces'));
    primary = Project.create(
      name: 'Primary',
      path: p.join(temporary.path, 'first'),
    );
    secondary = Project.create(
      name: 'Secondary',
      path: p.join(temporary.path, 'second'),
    );
    for (final project in [primary, secondary]) {
      await Directory(project.path).create();
      await File(
        p.join(project.path, 'source.txt'),
      ).writeAsString(project.name);
    }
    store = WorkspaceStore(root: metadata);
    stores = [store];
  });

  tearDown(() async {
    for (final instance in stores) {
      await instance.settle();
      instance.dispose();
    }
    await temporary.delete(recursive: true);
  });

  WorkspaceStore anotherStore({Directory? directory}) {
    final instance = WorkspaceStore(root: directory ?? metadata);
    stores.add(instance);
    return instance;
  }

  ProjectDocumentSession document(
    Project owner,
    String name, {
    bool active = false,
  }) => ProjectDocumentSession(
    projectPath: owner.path,
    relativePath: name,
    cursor: const FileCursor(
      baseIndex: 4,
      baseOffset: 2,
      extentIndex: 2,
      extentOffset: 1,
    ),
    isActive: active,
  );

  WorkspaceSessionSnapshot session(String name) => WorkspaceSessionSnapshot(
    primaryPath: primary.path,
    documents: [document(primary, name, active: true)],
    expandedDirs: {
      primary.path: ['src', 'src/nested'],
    },
    rootExpanded: {primary.path: false},
  );

  Future<SavedWorkspace> save({
    WorkspaceSessionSnapshot? initialSession,
  }) async {
    final result = await store.save(
      name: 'Workbench',
      members: [secondary, primary, secondary],
      primary: primary,
      session: initialSession,
    );
    expect(result.error, isNull);
    return result.workspace!;
  }

  File workspaceFile(SavedWorkspace workspace) =>
      File(p.join(metadata.path, '${workspace.id}.json'));

  test(
    'round-trips ordered members, tabs, physical cursors and expansion without source text',
    () async {
      final snapshot = WorkspaceSessionSnapshot(
        primaryPath: primary.path,
        documents: [
          document(secondary, 'second.cpp'),
          document(primary, 'first.dart', active: true),
          document(secondary, 'third.h'),
        ],
        expandedDirs: {
          primary.path: ['src'],
          secondary.path: ['include'],
        },
        rootExpanded: {primary.path: true, secondary.path: false},
      );
      final saved = await save(initialSession: snapshot);
      final reloaded = anotherStore();
      await reloaded.load();
      final actual = reloaded.byId(saved.id)!;
      expect(actual.name, 'Workbench');
      expect(actual.members.map((member) => member.projectId), [
        primary.id,
        secondary.id,
      ]);
      expect(actual.primaryMember!.projectId, primary.id);
      expect(actual.session.documents.map((tab) => tab.relativePath), [
        'second.cpp',
        'first.dart',
        'third.h',
      ]);
      expect(actual.session.documents.map((tab) => tab.isActive), [
        false,
        true,
        false,
      ]);
      expect(actual.session.documents.first.cursor.baseIndex, 4);
      expect(actual.session.documents.first.cursor.extentIndex, 2);
      expect(actual.session.rootExpanded[secondary.path], isFalse);
      expect(actual.session.expandedDirs[secondary.path], ['include']);
      final encoded = await workspaceFile(saved).readAsString();
      expect(encoded, isNot(contains('sourceText')));
      expect(
        await File(p.join(primary.path, 'source.txt')).readAsString(),
        'Primary',
      );
    },
  );

  test('duplicate names are rejected even for simultaneous creates', () async {
    final results = await Future.wait([
      store.save(name: ' Shared ', members: [primary], primary: primary),
      store.save(name: 'shared', members: [secondary], primary: secondary),
    ]);
    expect(results.where((result) => result.error == null), hasLength(1));
    expect(results.where((result) => result.error != null), hasLength(1));
    expect(store.workspaces, hasLength(1));
  });

  test(
    'duplicate names are checked against another store current disk state',
    () async {
      final other = anotherStore();
      await Future.wait([store.load(), other.load()]);
      final results = await Future.wait([
        store.save(name: 'Shared', members: [primary], primary: primary),
        other.save(name: 'SHARED', members: [secondary], primary: secondary),
      ]);
      expect(results.where((result) => result.error == null), hasLength(1));
      await store.load(force: true);
      expect(store.workspaces, hasLength(1));
    },
  );

  test(
    'metadata edits from an old dialog preserve the latest session',
    () async {
      final original = await save(initialSession: session('old.dart'));
      await store.saveSession(original, session('current.dart'));
      final result = await store.save(
        existing: original,
        name: 'Renamed',
        members: [primary],
        primary: primary,
      );
      expect(result.error, isNull);
      expect(
        result.workspace!.session.documents.single.relativePath,
        'current.dart',
      );
      expect(result.workspace!.members, hasLength(1));
      expect(result.workspace!.createdAt, original.createdAt);
    },
  );

  for (final sessionFirst in [true, false]) {
    test(
      'concurrent membership/session updates keep both fields, sessionFirst=$sessionFirst',
      () async {
        final original = await save();
        Future<void> membership() async {
          final result = await store.save(
            existing: original,
            name: 'Changed',
            members: [primary],
            primary: primary,
          );
          expect(result.error, isNull);
        }

        await Future.wait(
          sessionFirst
              ? [store.saveSession(original, session('new.dart')), membership()]
              : [
                  membership(),
                  store.saveSession(original, session('new.dart')),
                ],
        );
        await store.load(force: true);
        final current = store.byId(original.id)!;
        expect(current.name, 'Changed');
        expect(current.members.map((member) => member.projectId), [primary.id]);
        expect(current.session.documents.single.relativePath, 'new.dart');
      },
    );
  }

  test('session saves merge another store newer membership and name', () async {
    final original = await save();
    final other = anotherStore();
    await other.load();
    final renamed = await other.save(
      existing: original,
      name: 'Other name',
      members: [primary],
      primary: primary,
    );
    expect(renamed.error, isNull);
    await store.saveSession(original, session('latest.dart'));
    await other.load(force: true);
    final current = other.byId(original.id)!;
    expect(current.name, 'Other name');
    expect(current.members, hasLength(1));
    expect(current.session.documents.single.relativePath, 'latest.dart');
  });

  test(
    'deleting metadata wins over queued and later stale retained-editor saves',
    () async {
      final original = await save();
      final other = anotherStore();
      await other.load();
      final pendingSave = store.saveSession(
        original,
        session('before-delete.dart'),
      );
      final deletion = store.remove(original.id);
      final staleSave = store.saveSession(
        original,
        session('after-delete.dart'),
      );
      await Future.wait([pendingSave, deletion, staleSave]);
      await other.saveSession(original, session('other-retained-editor.dart'));
      final staleDialog = await other.save(
        existing: original,
        name: 'Revived',
        members: [primary],
        primary: primary,
      );
      expect(staleDialog.error, isNotNull);
      expect(await workspaceFile(original).exists(), isFalse);
      expect(store.byId(original.id), isNull);
      expect(other.byId(original.id), isNull);
      expect(
        await File(p.join(primary.path, 'source.txt')).readAsString(),
        'Primary',
      );
      expect(
        await File(p.join(secondary.path, 'source.txt')).readAsString(),
        'Secondary',
      );
      await store.load(force: true);
      expect(store.workspaces, isEmpty);
    },
  );

  test(
    'failed delete is observable and preserves the list entry for retry',
    () async {
      final original = await save();
      final file = workspaceFile(original);
      await file.delete();
      final obstruction = await Directory(file.path).create();
      await File(
        p.join(obstruction.path, 'keep.txt'),
      ).writeAsString('occupied');
      await expectLater(
        store.remove(original.id),
        throwsA(isA<FileSystemException>()),
      );
      expect(store.byId(original.id), isNotNull);
      expect(
        await File(p.join(obstruction.path, 'keep.txt')).readAsString(),
        'occupied',
      );
      await obstruction.delete(recursive: true);
      await file.writeAsString(jsonEncode(original.toJson()));
      await store.remove(original.id);
      expect(store.byId(original.id), isNull);
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'failed session write keeps current state and does not poison later operations',
    () async {
      final original = await save(initialSession: session('old.dart'));
      final file = workspaceFile(original);
      await file.delete();
      final obstruction = await Directory(file.path).create();
      await expectLater(
        store.saveSession(original, session('failed.dart')),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        store.byId(original.id)!.session.documents.single.relativePath,
        'old.dart',
      );
      await obstruction.delete();
      await file.writeAsString(jsonEncode(original.toJson()));
      await store.saveSession(original, session('retry.dart'));
      expect(
        store.byId(original.id)!.session.documents.single.relativePath,
        'retry.dart',
      );
    },
  );

  test(
    'save captures mutable project/list/session inputs before asynchronous work',
    () async {
      final documents = [document(primary, 'captured.dart', active: true)];
      final directories = ['captured'];
      final expanded = {primary.path: directories};
      final roots = {primary.path: false};
      final members = [secondary];
      final oldPath = secondary.path;
      final pending = store.save(
        name: 'Snapshot',
        members: members,
        primary: primary,
        session: WorkspaceSessionSnapshot(
          documents: documents,
          expandedDirs: expanded,
          rootExpanded: roots,
        ),
      );
      members.clear();
      secondary.path = p.join(temporary.path, 'changed');
      directories.add('later');
      expanded.clear();
      roots.clear();
      documents.clear();
      final result = await pending;
      expect(result.error, isNull);
      final saved = result.workspace!;
      expect(saved.members.last.path, oldPath);
      expect(saved.session.documents.single.relativePath, 'captured.dart');
      expect(saved.session.expandedDirs[primary.path], ['captured']);
      expect(saved.session.rootExpanded[primary.path], isFalse);
      expect(() => saved.session.documents.clear(), throwsUnsupportedError);
    },
  );

  test(
    'queued session calls snapshot collections and retain invocation order',
    () async {
      final original = await save();
      final pending = <Future<void>>[];
      for (var index = 0; index < 12; index++) {
        final documents = [document(primary, 'tab-$index.dart')];
        final directories = ['directory-$index'];
        pending.add(
          store.saveSession(
            original,
            WorkspaceSessionSnapshot(
              documents: documents,
              expandedDirs: {primary.path: directories},
            ),
          ),
        );
        documents.clear();
        directories.clear();
      }
      final read = store.load(force: true);
      await Future.wait([...pending, read]);
      final current = store.byId(original.id)!;
      expect(current.session.documents.single.relativePath, 'tab-11.dart');
      expect(current.session.expandedDirs[primary.path], ['directory-11']);
    },
  );

  test(
    'refresh started before a session update cannot publish stale state afterward',
    () async {
      final original = await save(initialSession: session('before.dart'));
      final controlledRoot = _ControlledDirectory(metadata);
      final controlledStore = anotherStore(directory: controlledRoot);
      await controlledStore.load();
      controlledRoot.gateRead = true;
      final refreshing = controlledStore.load(force: true);
      await controlledRoot.readStarted.future;
      final update = controlledStore.saveSession(
        original,
        session('after.dart'),
      );
      controlledRoot.releaseRead.complete();
      await Future.wait([refreshing, update]);
      expect(
        controlledStore
            .byId(original.id)!
            .session
            .documents
            .single
            .relativePath,
        'after.dart',
      );
      await store.load(force: true);
      expect(
        store.byId(original.id)!.session.documents.single.relativePath,
        'after.dart',
      );
    },
  );

  test(
    'directory refresh failure preserves the prior list and permits retry',
    () async {
      final original = await save();
      final controlledRoot = _ControlledDirectory(metadata);
      final controlledStore = anotherStore(directory: controlledRoot);
      await controlledStore.load();
      controlledRoot.failListing = true;
      await expectLater(
        controlledStore.load(force: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(controlledStore.byId(original.id), isNotNull);
      controlledRoot.failListing = false;
      await controlledStore.load(force: true);
      expect(controlledStore.byId(original.id), isNotNull);
    },
  );

  test(
    'malformed ids cannot escape the metadata directory or redirect a document',
    () async {
      final original = await save();
      final outside = File(p.join(temporary.path, 'outside.json'));
      await outside.writeAsString('keep outside');
      final malformed = SavedWorkspace(
        id: '../outside',
        name: original.name,
        createdAt: original.createdAt,
        updatedAt: original.updatedAt,
        members: original.members,
      );
      await File(
        p.join(metadata.path, 'damaged.json'),
      ).writeAsString(jsonEncode(malformed.toJson()));
      await File(p.join(metadata.path, 'broken.json')).writeAsString('{broken');
      await store.load(force: true);
      expect(store.workspaces.map((workspace) => workspace.id), [original.id]);
      await expectLater(
        store.remove(malformed.id),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        store.saveSession(malformed, session('escape.dart')),
        throwsA(isA<FileSystemException>()),
      );
      final result = await store.save(
        existing: malformed,
        name: 'Escape',
        members: [primary],
        primary: primary,
      );
      expect(result.error, isNotNull);
      expect(await outside.readAsString(), 'keep outside');
      expect(await workspaceFile(original).exists(), isTrue);
    },
  );

  test(
    'resolution reports a deleted secondary while preserving the valid primary',
    () async {
      final original = await save();
      final registry = _Projects([primary, secondary]);
      addTearDown(registry.dispose);
      await Directory(secondary.path).delete(recursive: true);
      final resolution = await store.resolve(original, registry);
      expect(resolution.projects, [primary]);
      expect(resolution.missing.map((member) => member.projectId), [
        secondary.id,
      ]);
      expect(resolution.primary, same(primary));
      expect(resolution.primaryMissing, isFalse);
    },
  );

  test(
    'resolution falls back when primary is unregistered and reports all-missing',
    () async {
      final original = await save();
      final registry = _Projects([secondary]);
      addTearDown(registry.dispose);
      var resolution = await store.resolve(original, registry);
      expect(resolution.projects, [secondary]);
      expect(resolution.primary, same(secondary));
      expect(resolution.primaryMissing, isTrue);
      await Directory(secondary.path).delete(recursive: true);
      resolution = await store.resolve(original, registry);
      expect(resolution.isEmpty, isTrue);
      expect(resolution.primary, isNull);
      expect(resolution.missing.map((member) => member.projectId), [
        primary.id,
        secondary.id,
      ]);
      expect(await Directory(primary.path).exists(), isTrue);
    },
  );

  test(
    'resolution accepts a re-registered local path and skips a cloud replacement',
    () async {
      final original = await save();
      final replacement = Project.create(
        name: 'Re-registered',
        path: secondary.path,
      );
      final cloud = Project.create(
        name: 'Cloud',
        path: primary.path,
        cloudId: 'remote',
      );
      final registry = _Projects([cloud, replacement]);
      addTearDown(registry.dispose);
      final resolution = await store.resolve(original, registry);
      expect(resolution.projects, [replacement]);
      expect(resolution.primary, same(replacement));
      expect(resolution.missing.single.projectId, primary.id);
    },
  );

  test('a deleted primary falls back to an existing secondary', () async {
    final original = await save();
    final registry = _Projects([primary, secondary]);
    addTearDown(registry.dispose);
    await Directory(primary.path).delete(recursive: true);
    final resolution = await store.resolve(original, registry);
    expect(resolution.projects, [secondary]);
    expect(resolution.primary, same(secondary));
    expect(resolution.primaryMissing, isTrue);
    expect(resolution.missing.single.projectId, primary.id);
  });

  test(
    'session autosaves preserve workspace list ordering timestamps',
    () async {
      await metadata.create();
      final older = SavedWorkspace(
        id: 'older',
        name: 'Older',
        createdAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
        members: [WorkspaceMember.fromProject(primary, primary: true)],
      );
      final newer = SavedWorkspace(
        id: 'newer',
        name: 'Newer',
        createdAt: DateTime.utc(2021),
        updatedAt: DateTime.utc(2021),
        members: older.members,
      );
      for (final workspace in [older, newer]) {
        await workspaceFile(
          workspace,
        ).writeAsString(jsonEncode(workspace.toJson()));
      }
      await store.load();
      await store.saveSession(older, session('autosaved.dart'));
      expect(store.workspaces.map((workspace) => workspace.id), [
        'newer',
        'older',
      ]);
      expect(store.byId(older.id)!.updatedAt, older.updatedAt);
      await store.load(force: true);
      expect(store.workspaces.map((workspace) => workspace.id), [
        'newer',
        'older',
      ]);
    },
  );
  test(
    'session updates publish the latest snapshot to Home listeners',
    () async {
      final original = await save(initialSession: session('before.dart'));
      final observed = <String>[];
      store.addListener(() {
        observed.add(
          store.byId(original.id)!.session.documents.single.relativePath,
        );
      });
      await store.saveSession(original, session('after.dart'));
      expect(observed, ['after.dart']);
    },
  );
}

class _Projects extends ProjectStore {
  _Projects(this.entries);
  final List<Project> entries;

  @override
  List<Project> get projects => [...entries];
}

/// Holds an actual file read after capturing its old bytes, so refresh/save
/// ordering is verified without timing assumptions or sleeps.
class _ControlledDirectory implements Directory {
  _ControlledDirectory(this.delegate);
  final Directory delegate;
  bool gateRead = false;
  bool failListing = false;
  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  String get path => delegate.path;

  @override
  Future<bool> exists() => delegate.exists();

  @override
  Future<Directory> create({bool recursive = false}) async {
    await delegate.create(recursive: recursive);
    return this;
  }

  @override
  String resolveSymbolicLinksSync() => delegate.resolveSymbolicLinksSync();

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) async* {
    if (failListing) {
      throw FileSystemException('Unreadable workspace directory', path);
    }
    await for (final entity in delegate.list(
      recursive: recursive,
      followLinks: followLinks,
    )) {
      if (gateRead && entity is File && entity.path.endsWith('.json')) {
        gateRead = false;
        yield _ControlledFile(entity, readStarted, releaseRead);
      } else {
        yield entity;
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledFile implements File {
  _ControlledFile(this.delegate, this.readStarted, this.releaseRead);
  final File delegate;
  final Completer<void> readStarted;
  final Completer<void> releaseRead;

  @override
  String get path => delegate.path;

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    final snapshot = await delegate.readAsString(encoding: encoding);
    readStarted.complete();
    await releaseRead.future;
    return snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
