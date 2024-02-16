import 'dart:io';

import 'package:checkmark/checkmark.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:jiffy/jiffy.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

enum _CacheSorting { size, listenCount, accessTime }

class StorageCacheManager {
  const StorageCacheManager();

  Future<void> trimExtraFiles() async {
    final trimmer = _Trimmer();
    await Future.wait([
      trimmer._trimExcessImageCache(),
      trimmer._trimExcessAudioCache(),
    ]);
  }

  String getDeleteSizeSubtitleText(int length, int totalSize) {
    return lang.DELETE_FILE_CACHE_SUBTITLE.replaceFirst('_FILES_COUNT_', length.formatDecimal()).replaceFirst('_TOTAL_SIZE_', totalSize.fileSizeFormatted);
  }

  void promptCacheDeleteDialog<T>({
    required List<T> allItems,
    required String Function(List<T> items) deleteStatsNote,
    required String chooseNote,
    required void Function() onChoosePrompt,
    required Future<void> Function() onDeleteAll,
  }) {
    /// First Dialog
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: "${deleteStatsNote(allItems)}\n$chooseNote",
        actions: [
          /// Pressing Choose
          NamidaButton(
            text: lang.CHOOSE,
            onPressed: () {
              NamidaNavigator.inst.closeDialog();
              onChoosePrompt();
            },
          ),
          const CancelButton(),
          NamidaButton(
            text: lang.DELETE.toUpperCase(),
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              await onDeleteAll();
            },
          ),
        ],
      ),
    );
  }

  void showChooseToDeleteDialog<T>({
    required List<T> allItems,
    required String Function(T item) itemToPath,
    required String? Function(T item) itemToYtId,
    required String Function(T item, int itemSize) itemToSubtitle,
    required String Function(int length, int totalSize) confirmDialogText,
    required Future<void> Function(List<T> itemsToDelete) onConfirm,
    bool includeLocalTracksListens = true,
  }) {
    final itemsToDelete = <T>[].obs;
    final itemsToDeleteSize = 0.obs;
    final allFiles = allItems.obs;

    final currentSort = _CacheSorting.size.obs;

    final localIdTrackMap = <String, Track>{};
    if (includeLocalTracksListens) {
      allTracksInLibrary.loop((tr, _) => localIdTrackMap[tr.youtubeID] = tr);
    }

    final sizesMap = <String, int>{};
    final accessTimeMap = <String, (int, String)>{};

    allFiles.loop((e, _) {
      final path = itemToPath(e);
      final stats = File(path).statSync();
      final accessed = stats.accessed.millisecondsSinceEpoch;
      final modified = stats.modified.millisecondsSinceEpoch;
      final finalMS = modified > accessed ? modified : accessed;
      sizesMap[path] = stats.size;
      accessTimeMap[path] = (finalMS, Jiffy.parseFromMillisecondsSinceEpoch(finalMS).fromNow());
    });

    int getTotalListensForIDLength(String? id) {
      if (id == null) return 0;
      final correspondingTrack = localIdTrackMap[id];
      final local = correspondingTrack == null ? [] : HistoryController.inst.topTracksMapListens[correspondingTrack] ?? [];
      final yt = YoutubeHistoryController.inst.topTracksMapListens[id] ?? [];
      return local.length + yt.length;
    }

    void sortBy(_CacheSorting type) {
      currentSort.value = type;
      switch (type) {
        case _CacheSorting.size:
          allFiles.sortByReverse((e) => sizesMap[itemToPath(e)] ?? 0);
        case _CacheSorting.accessTime:
          allFiles.sortBy((e) => accessTimeMap[itemToPath(e)]?.$1 ?? 0);
        case _CacheSorting.listenCount:
          allFiles.sortBy((e) => getTotalListensForIDLength(itemToYtId(e)));
        default:
          null;
      }
    }

    Widget getChipButton({
      required _CacheSorting sort,
      required String title,
      required IconData icon,
      required bool Function(_CacheSorting sort) enabled,
    }) {
      return NamidaInkWell(
        animationDurationMS: 100,
        borderRadius: 8.0,
        bgColor: Get.theme.cardTheme.color,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: enabled(sort) ? Border.all(color: Get.theme.colorScheme.primary) : null,
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        ),
        onTap: () => sortBy(sort),
        child: Row(
          children: [
            Icon(icon, size: 18.0),
            const SizedBox(width: 4.0),
            Text(
              title,
              style: Get.textTheme.displayMedium,
            ),
            const SizedBox(width: 4.0),
            const Icon(Broken.arrow_down_2, size: 14.0),
          ],
        ),
      );
    }

    sortBy(currentSort.value);

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        itemsToDelete.close();
        allFiles.close();
        currentSort.close();
      },
      dialog: CustomBlurryDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
        isWarning: true,
        normalTitleStyle: true,
        title: lang.CHOOSE,
        actions: [
          const CancelButton(),

          /// Clear after choosing
          Obx(
            () => NamidaButton(
              enabled: itemsToDelete.isNotEmpty,
              text: "${lang.DELETE.toUpperCase()} (${itemsToDeleteSize.value.fileSizeFormatted})",
              onPressed: () async {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    actions: [
                      const CancelButton(),

                      /// final clear confirm
                      NamidaButton(
                        text: lang.DELETE.toUpperCase(),
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog(2);
                          onConfirm(itemsToDelete);
                        },
                      ),
                    ],
                    bodyText: confirmDialogText(itemsToDelete.length, itemsToDeleteSize.value),
                  ),
                );
              },
            ),
          ),
        ],
        child: SizedBox(
          width: Get.width,
          height: Get.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 12.0),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(width: 24.0),
                      getChipButton(
                        sort: _CacheSorting.size,
                        title: lang.SIZE,
                        icon: Broken.size,
                        enabled: (sort) => sort == currentSort.value,
                      ),
                      const SizedBox(width: 12.0),
                      getChipButton(
                        sort: _CacheSorting.accessTime,
                        title: lang.OLDEST_WATCH,
                        icon: Broken.sort,
                        enabled: (sort) => sort == currentSort.value,
                      ),
                      const SizedBox(width: 12.0),
                      getChipButton(
                        sort: _CacheSorting.listenCount,
                        title: lang.TOTAL_LISTENS,
                        icon: Broken.math,
                        enabled: (sort) => sort == currentSort.value,
                      ),
                      const SizedBox(width: 24.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6.0),
              Expanded(
                child: NamidaScrollbar(
                  child: Obx(
                    () => ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: allFiles.length,
                      itemBuilder: (context, index) {
                        final item = allFiles[index];
                        final id = itemToYtId(item);
                        final title = id == null ? null : YoutubeController.inst.getVideoName(id);
                        final listens = getTotalListensForIDLength(id);
                        final itemSize = sizesMap[itemToPath(item)] ?? 0;
                        return NamidaInkWell(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          onTap: () {
                            final didRemove = itemsToDelete.remove(item);
                            if (didRemove) {
                              itemsToDeleteSize.value -= itemSize;
                            } else {
                              itemsToDelete.add(item);
                              itemsToDeleteSize.value += itemSize;
                            }
                          },
                          child: Row(
                            children: [
                              ArtworkWidget(
                                key: Key(id ?? ''),
                                thumbnailSize: 92.0,
                                iconSize: 24.0,
                                width: 92,
                                height: 92 * 9 / 16,
                                path: ThumbnailManager.getPathToYTImage(id),
                                forceSquared: true,
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title ?? id ?? '',
                                      style: context.textTheme.displayMedium,
                                    ),
                                    Text(
                                      itemToSubtitle(item, itemSize),
                                      style: context.textTheme.displaySmall,
                                    ),
                                    if (currentSort.value == _CacheSorting.accessTime)
                                      Text(
                                        accessTimeMap[itemToPath(item)]?.$2 ?? '',
                                        style: context.textTheme.displaySmall,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              if (listens > 0) ...[
                                Text(
                                  listens.toString(),
                                  style: context.textTheme.displaySmall,
                                ),
                                const SizedBox(width: 8.0),
                              ],
                              IgnorePointer(
                                child: SizedBox(
                                  height: 16.0,
                                  width: 16.0,
                                  child: Obx(
                                    () => CheckMark(
                                      strokeWidth: 2,
                                      activeColor: context.theme.listTileTheme.iconColor!,
                                      inactiveColor: context.theme.listTileTheme.iconColor!,
                                      duration: const Duration(milliseconds: 400),
                                      active: itemsToDelete.contains(item),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trimmer {
  int get _imagesMaxCacheInMB => settings.imagesMaxCacheInMB.value;
  int get _audiosMaxCacheInMB => settings.audiosMaxCacheInMB.value;

  /// Returns total deleted bytes.
  Future<int> _trimExcessImageCache() async {
    final totalMaxBytes = _imagesMaxCacheInMB * 1024 * 1024;
    final paramters = {
      'maxBytes': totalMaxBytes,
      'dirPath': AppDirs.YT_THUMBNAILS,
      'dirPathChannel': AppDirs.YT_THUMBNAILS_CHANNELS,
    };
    return await _trimExcessImageCacheIsolate.thready(paramters);
  }

  /// Returns total deleted bytes.
  Future<int> _trimExcessAudioCache() async {
    final totalMaxBytes = _audiosMaxCacheInMB * 1024 * 1024;
    final paramters = {
      'maxBytes': totalMaxBytes,
      'dirPath': AppDirs.AUDIOS_CACHE,
    };
    return await _trimExcessAudioCacheIsolate.thready(paramters);
  }

  static int _trimExcessImageCacheIsolate(Map map) {
    final maxBytes = map['maxBytes'] as int;
    final dirPath = map['dirPath'] as String;
    final dirPathChannel = map['dirPathChannel'] as String;

    final imagesVideos = Directory(dirPath).listSyncSafe();
    final imagesChannels = Directory(dirPathChannel).listSyncSafe();
    final images = [...imagesVideos, ...imagesChannels];

    images.sortBy((e) => e.statSync().accessed);
    return _trimExcessCache(images, maxBytes);
  }

  static int _trimExcessAudioCacheIsolate(Map map) {
    final maxBytes = map['maxBytes'] as int;
    final dirPath = map['dirPath'] as String;

    final audios = Directory(dirPath).listSyncSafe();
    audios.sortBy((e) => e.statSync().accessed);
    return _trimExcessCache(audios, maxBytes);
  }

  static int _trimExcessCache(List<FileSystemEntity> files, int maxBytes) {
    int totalDeletedBytes = 0;
    int totalBytes = 0;
    final sizesMap = <String, int>{};
    files.loop((f, _) {
      final size = f.statSync().size;
      sizesMap[f.path] = size;
      totalBytes += size;
    });
    for (final file in files) {
      if (totalBytes <= maxBytes) break; // better than checking with each loop
      final deletedSize = sizesMap[file.path] ?? file.statSync().size;
      try {
        file.deleteSync();
        totalBytes -= deletedSize;
        totalDeletedBytes += deletedSize;
      } catch (_) {}
    }

    return totalDeletedBytes;
  }
}
