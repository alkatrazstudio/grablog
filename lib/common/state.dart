// SPDX-License-Identifier: AGPL-3.0-only

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'state.freezed.dart';
part 'state.g.dart';

@freezed
abstract class SelectedState with _$SelectedState {
  const factory SelectedState({
    required int packageIndex,
    required Map<int, int> packageChangelogIndex,
  }) = _SelectedState;

  const SelectedState._();

  int get changelogIndex => packageChangelogIndex[packageIndex] ?? 0;
}

@riverpod
class Selected extends _$Selected {
  @override
  SelectedState build() => const SelectedState(
    packageIndex: -1,
    packageChangelogIndex: {}
  );

  void setPackageIndex(int packageIndex) => state = state.copyWith(packageIndex: packageIndex);

  void setChangelogIndex(int changelogIndex) {
    var map = Map<int, int>.from(state.packageChangelogIndex);
    map[state.packageIndex] = changelogIndex;
    state = state.copyWith(packageChangelogIndex: map);
  }

  void reset() {
    state = build();
  }
}
