// Copyright © 2022-2024 IT ENGINEERING MANAGEMENT INC,
//                       <https://github.com/team113>
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU Affero General Public License v3.0 as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License v3.0 for
// more details.
//
// You should have received a copy of the GNU Affero General Public License v3.0
// along with this program. If not, see
// <https://www.gnu.org/licenses/agpl-3.0.html>.

import 'dart:async';

import 'package:get/get.dart';

import '/domain/model/chat_item.dart';
import '../domain/repository/paginated.dart';
import '/store/model/chat_item.dart';
import '/util/log.dart';
import '/util/obs/obs.dart';
import 'pagination.dart';

/// Implementation of a [Paginated].
class PaginatedImpl<K extends Comparable, T, V, C> extends Paginated<K, T> {
  PaginatedImpl({
    this.pagination,
    this.initial = const [],
    this.initialKey,
    this.initialCursor,
    super.onDispose,
  });

  /// Pagination fetching [items].
  final Pagination<V, C, K>? pagination;

  /// Initial [T] items to put inside the [items].
  final List<FutureOr<Map<K, T>>> initial;

  /// [ChatItemKey] to fetch [items] around.
  final K? initialKey;

  /// [ChatItemsCursor] to fetch [items] around.
  final C? initialCursor;

  /// [Future]s loading the initial [items].
  final List<Future> _futures = [];

  /// [StreamSubscription] to the [Pagination.changes].
  StreamSubscription? _paginationSubscription;

  @override
  RxBool get hasNext => pagination?.hasNext ?? RxBool(false);

  @override
  RxBool get hasPrevious => pagination?.hasPrevious ?? RxBool(false);

  @override
  RxBool get nextLoading => pagination?.nextLoading ?? RxBool(false);

  @override
  RxBool get previousLoading => pagination?.previousLoading ?? RxBool(false);

  @override
  Future<void> ensureInitialized() async {
    Log.debug('ensureInitialized()', '$runtimeType');
    if (_futures.isEmpty && !status.value.isSuccess) {
      for (var f in initial) {
        if (f is Future<Map<K, T>>) {
          _futures.add(f..then(items.addAll));
        } else {
          items.addAll(f);
        }
      }

      if (pagination != null) {
        _paginationSubscription = pagination!.changes.listen((event) {
          switch (event.op) {
            case OperationKind.added:
            case OperationKind.updated:
              items[event.key!] = event.value as T;
              break;

            case OperationKind.removed:
              items.remove(event.key);
              break;
          }
        });

        _futures.add(
          pagination!.around(key: initialKey, cursor: initialCursor),
        );
      }

      if (_futures.isEmpty) {
        status.value = RxStatus.success();
      } else {
        if (items.isNotEmpty) {
          status.value = RxStatus.loadingMore();
        } else {
          status.value = RxStatus.loading();
        }

        await Future.wait(_futures);
        status.value = RxStatus.success();
      }
    } else {
      await Future.wait(_futures);
    }
  }

  @override
  void dispose() {
    Log.debug('dispose()', '$runtimeType');

    _paginationSubscription?.cancel();
    pagination?.dispose();
    super.dispose();
  }

  @override
  Future<void> next() async {
    Log.debug('next()', '$runtimeType');

    if (pagination != null && nextLoading.isFalse) {
      if (status.value.isSuccess) {
        status.value = RxStatus.loadingMore();
      }

      // TODO: Probably shouldn't do that in the store.
      int length = items.length;
      for (int i = 0; i < 10 && hasNext.isTrue; i++) {
        await pagination!.next();

        if (length != items.length || hasNext.isFalse) {
          break;
        }
      }

      status.value = RxStatus.success();
    }
  }

  @override
  Future<void> previous() async {
    Log.debug('previous()', '$runtimeType');

    if (pagination != null && previousLoading.isFalse) {
      if (status.value.isSuccess) {
        status.value = RxStatus.loadingMore();
      }

      // TODO: Probably shouldn't do that in the store.
      int length = items.length;
      for (int i = 0; i < 10 && hasPrevious.isTrue; i++) {
        await pagination!.previous();

        if (length != items.length || hasPrevious.isFalse) {
          break;
        }
      }

      status.value = RxStatus.success();
    }
  }
}

/// Implementation of a [Paginated] transforming [V] from [Pagination] to [T]
/// value.
class RxPaginatedImpl<K extends Comparable, T, V, C>
    extends PaginatedImpl<K, T, V, C> {
  RxPaginatedImpl({
    required this.transform,
    required super.pagination,
    super.initialKey,
    super.initialCursor,
    super.onDispose,
  });

  /// Callback, called to transform the [V] to [T].
  final FutureOr<T> Function({T? previous, required V data}) transform;

  @override
  Future<void> ensureInitialized() async {
    Log.debug('ensureInitialized()', '$runtimeType');

    if (_futures.isEmpty) {
      _paginationSubscription = pagination!.changes.listen((event) async {
        switch (event.op) {
          case OperationKind.added:
          case OperationKind.updated:
            FutureOr<T> itemOrFuture = transform(
              previous: items[event.key!],
              data: event.value as V,
            );
            final T item;

            if (itemOrFuture is T) {
              item = itemOrFuture;
            } else {
              item = await itemOrFuture;
            }

            items[event.key!] = item;
            break;

          case OperationKind.removed:
            items.remove(event.key);
            break;
        }
      });

      _futures.add(pagination!.around(key: initialKey, cursor: initialCursor));

      await Future.wait(_futures);
      status.value = RxStatus.success();
    } else {
      await Future.wait(_futures);
    }
  }

  @override
  Future<void> next() async {
    Log.debug('next()', '$runtimeType');

    if (nextLoading.isFalse) {
      await pagination?.next();
    }
  }

  @override
  Future<void> previous() async {
    Log.debug('previous()', '$runtimeType');

    if (previousLoading.isFalse) {
      await pagination?.previous();
    }
  }
}
