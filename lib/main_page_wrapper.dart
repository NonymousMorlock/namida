import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/inner_drawer.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/youtube_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/selected_tracks_preview.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';

class MainPageWrapper extends StatelessWidget {
  const MainPageWrapper({super.key});

  void toggleDrawer() => NamidaNavigator.inst.toggleDrawer();

  @override
  Widget build(BuildContext context) {
    return InnerDrawer(
      key: NamidaNavigator.inst.innerDrawerKey,
      onTapClose: true,
      colorTransitionChild: Colors.black54,
      colorTransitionScaffold: Colors.black54,
      offset: const IDOffset.only(left: 0.0),
      proportionalChildArea: true,
      borderRadius: 32.0.multipliedRadius,
      leftAnimationType: InnerDrawerAnimation.quadratic,
      rightAnimationType: InnerDrawerAnimation.quadratic,
      backgroundDecoration: BoxDecoration(color: context.theme.scaffoldBackgroundColor),
      duration: const Duration(milliseconds: 400),
      tapScaffoldEnabled: false,
      velocity: 0.01,
      leftChild: Container(
        color: context.theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Expanded(
              child: Obx(
                () => ListView(
                  children: [
                    const NamidaLogoContainer(),
                    const NamidaContainerDivider(width: 42.0, margin: EdgeInsets.all(10.0)),
                    ...LibraryTab.values.map(
                      (e) => NamidaDrawerListTile(
                        enabled: SettingsController.inst.selectedLibraryTab.value == e,
                        title: e.toText(),
                        icon: e.toIcon(),
                        onTap: () async {
                          ScrollSearchController.inst.animatePageController(e);
                          await Future.delayed(const Duration(milliseconds: 100));
                          toggleDrawer();
                        },
                      ),
                    ),
                    NamidaDrawerListTile(
                      enabled: false,
                      title: Language.inst.QUEUES,
                      icon: Broken.driver,
                      onTap: () {
                        NamidaNavigator.inst.navigateTo(const QueuesPage());
                        toggleDrawer();
                      },
                    ),
                    NamidaDrawerListTile(
                      enabled: false,
                      title: Language.inst.YOUTUBE,
                      icon: Broken.video_square,
                      onTap: () {
                        YoutubeController.inst.prepareHomeFeed();
                        NamidaNavigator.inst.navigateTo(const YoutubePage());
                        toggleDrawer();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Material(
              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
              child: ToggleThemeModeContainer(
                width: Get.width / 2.3,
                blurRadius: 3.0,
              ),
            ),
            const SizedBox(height: 8.0),
            NamidaDrawerListTile(
              margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
              enabled: false,
              title: Language.inst.SLEEP_TIMER,
              icon: Broken.timer_1,
              onTap: () {
                toggleDrawer();
                final minutes = Player.inst.sleepAfterMin.obs;
                final tracks = Player.inst.sleepAfterTracks.obs;
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: Language.inst.SLEEP_AFTER,
                    icon: Broken.timer_1,
                    normalTitleStyle: true,
                    actions: [
                      const CancelButton(),
                      Obx(
                        () => Player.inst.enableSleepAfterMins || Player.inst.enableSleepAfterTracks
                            ? NamidaButton(
                                icon: Broken.timer_pause,
                                text: Language.inst.STOP,
                                onPressed: () {
                                  Player.inst.resetSleepAfterTimer();
                                  NamidaNavigator.inst.closeDialog();
                                },
                              )
                            : NamidaButton(
                                icon: Broken.timer_start,
                                text: Language.inst.START,
                                onPressed: () {
                                  if (minutes.value > 0 || tracks.value > 0) {
                                    Player.inst.updateSleepTimerValues(
                                      enableSleepAfterMins: minutes.value > 0,
                                      enableSleepAfterTracks: tracks.value > 0,
                                      sleepAfterMin: minutes.value,
                                      sleepAfterTracks: tracks.value,
                                    );
                                  }
                                  NamidaNavigator.inst.closeDialog();
                                },
                              ),
                      ),
                    ],
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 32.0,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // minutes
                            Obx(
                              () => NamidaWheelSlider(
                                totalCount: 180,
                                initValue: minutes.value,
                                itemSize: 6,
                                onValueChanged: (val) => minutes.value = val,
                                text: "${minutes.value}m",
                                topText: Language.inst.MINUTES.capitalizeFirst,
                                textPadding: 8.0,
                              ),
                            ),
                            Text(
                              Language.inst.OR,
                              style: context.textTheme.displayMedium,
                            ),
                            // tracks
                            Obx(
                              () => NamidaWheelSlider(
                                totalCount: kMaximumSleepTimerTracks,
                                initValue: tracks.value,
                                itemSize: 6,
                                onValueChanged: (val) => tracks.value = val,
                                text: "${tracks.value} ${Language.inst.TRACK}",
                                topText: Language.inst.TRACKS,
                                textPadding: 8.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: NamidaDrawerListTile(
                    margin: const EdgeInsets.symmetric(vertical: 5.0).add(const EdgeInsets.only(left: 12.0)),
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
                    enabled: false,
                    isCentered: true,
                    iconSize: 24.0,
                    title: '',
                    icon: Broken.brush_1,
                    onTap: () {
                      NamidaNavigator.inst.navigateTo(
                        SettingsSubPage(
                          title: Language.inst.CUSTOMIZATIONS,
                          child: const CustomizationSettings(),
                        ),
                      );

                      toggleDrawer();
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: NamidaDrawerListTile(
                    margin: const EdgeInsets.symmetric(vertical: 5.0).add(const EdgeInsets.only(right: 12.0)),
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
                    enabled: false,
                    isCentered: true,
                    iconSize: 24.0,
                    title: '',
                    icon: Broken.setting,
                    onTap: () {
                      NamidaNavigator.inst.navigateTo(const SettingsPage());
                      toggleDrawer();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
      scaffold: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const MainPage(),
          const MiniPlayerParent(),
          Obx(
            () {
              final miniHeight = MiniPlayerController.inst.miniplayerHP.value;
              final queueHeight = MiniPlayerController.inst.miniplayerQueueHP.value;
              if (miniHeight == 1.0 && queueHeight == 0.0) return const SizedBox();

              final navHeight = (SettingsController.inst.enableBottomNavBar.value ? kBottomNavigationBarHeight : -4.0) - 10.0;
              final isInQueue = queueHeight > 0.0;
              final initH = isInQueue ? kQueueBottomRowHeight : 12.0 + (miniHeight * 24.0);

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                bottom: initH + (navHeight * (1 - queueHeight)),
                child: Opacity(
                  opacity: isInQueue ? queueHeight : 1.0 - miniHeight,
                  child: const SelectedTracksPreviewContainer(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}