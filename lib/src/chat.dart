// ignore_for_file: unused_field, unused_element, avoid_print, deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_ack_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_performance_profile.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_game_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_service.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_admin_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_game_http.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_game_round_status.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_realtime_state.dart';
import 'package:tencent_cloud_chat_demo/src/services/sangong_admin_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_marquee_dismiss_service.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_my_config.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_game/sangong_manage_home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_game/sangong_my_config_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/agent_rebate_descendants_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/agent_rebate_current_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/agent_rebate_history_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game_prefs.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tips_operator_patch_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_game/group_game_floating_entry.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/agent_rebate_floating_entry.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_game/sangong_bet_preview_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_game/sangong_round_settle_flow.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_info_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/official_account_input_spacer.dart';
import 'package:tencent_cloud_chat_demo/src/services/c2c_friend_message_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_service.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/c2c_send_permission_controller.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_draft_controller.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_group_page_side_controller.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_header_state_controller.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_open_lifecycle.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_post_open_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_top_fix_state_controller.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';
import 'package:tencent_cloud_chat_demo/src/models/chat_entry_snapshot.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_viewport_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/wallet_card_outbound_sidecar.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_chat_state.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_store.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/group_live_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/c2c_blocked_outgoing_message_sync.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/c2c_friend_message_blocked_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/chat_top_fix_view.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_bubble_insert_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/call_lifecycle_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_deleted_bus.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_profile_pin_bar.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_draft_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_clear_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_peek_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_recovery_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/resume_foreground_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/external_chat_entry_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_diag_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_chat_notification_clear_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_recovery_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_media_metadata_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_focus_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/group_profile.dart';
import 'package:tencent_cloud_chat_demo/src/pages/c2c_chat_settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_chat_panel.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/dice/dice_face_bubble.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_face_bubble.dart'
    show StickerFaceBubble, stickerFaceShouldUseCustomBubble;
import 'package:tencent_cloud_chat_demo/utils/dice_asset_warmup.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_play_store.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/favorite_picker_sheet.dart';
import 'package:tencent_cloud_chat_demo/utils/favorite_message_from_im.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_message_prefetch.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_image_message_prefetch.dart';
import 'package:tencent_cloud_chat_demo/utils/avatar_image_warm.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_add_from_message.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_emoji_sticker_list.dart';
import 'package:tencent_cloud_chat_demo/src/repository/sticker_repository.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_mention_nav.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe_key.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_demo/src/pages/contact_card_user_picker_page.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/contact_card_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_message_element.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart'
    show LoadDirection, TUIChatSeparateViewModel;
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/official_account_message_item.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/chat_header_title.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/chat_host_app_bar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/services/archive_im_local_persist_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_demo/src/utils/web_chat_open_policy.dart';
import 'package:tencent_cloud_chat_demo/src/utils/chat_history_recovery_satisfaction.dart';
import 'package:tencent_cloud_chat_demo/src/utils/chat_warm_resume_catchup.dart'
    as warm_resume;
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_offline_push.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_model_tools.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/outgoing_visible_probe.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/regexp_probe.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_resource_sample.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_inbound_scroll_follow.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_record.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_open_layout_ready.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/unread_tongue_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_background_registry.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/tim_uikit_local_image_provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_at_mention.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_admin_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_bet_submit_cutoff.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_report_image_messages.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_quick_setup_banker_input.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_member_feedback_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_kick_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/agent_rebate_date_range_picker.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_order_events.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_dispatch_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_im_payload.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_replay_guard.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_send_failure.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_send_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_screen.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/transfer_party_name_resolver.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_pay_pin_guard.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_transfer_screen.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/orphan_overlay_guard.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/route_visibility.dart';
import 'package:tencent_cloud_chat_demo/utils/app_material_theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';

bool _skipChatMessageEnterAnimation(V2TimMessage message) {
  if (CustomMessageElem.isWalletCardMessage(message)) {
    return true;
  }
  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS) {
    return true;
  }
  // Android 全档跳过气泡入场动画，减轻连发/进页时的 layout 叠峰。
  if (AndroidPerformanceProfile.instance.reduceHeavyVisualEffects) {
    return true;
  }
  // 滑动中 / 松手短窗口：跳过入场动画，避免与列表 layout 叠峰。
  try {
    if (serviceLocator<TUIChatGlobalModel>()
        .shouldSkipHeavyChatListPresentation) {
      return true;
    }
  } catch (_) {
    // serviceLocator 未就绪时忽略。
  }
  return false;
}

class Chat extends StatefulWidget {
  final V2TimConversation selectedConversation;
  final int? entryUnreadCount;
  final V2TimMessage? initFindingMsg;
  final MessageAnchor? searchJumpAnchor;

  /// Short-lived permission hint from a trusted entry such as the friend
  /// profile "Send Message" button. The backend relation is still refreshed
  /// after the first frame; this only keeps the input stable on entry.
  final bool? initialC2cCanMessage;
  final String? c2cPermissionHintSource;
  final VoidCallback? showGroupProfile;
  final ValueChanged<V2TimConversation>? directToChat;

  const Chat({
    Key? key,
    required this.selectedConversation,
    this.entryUnreadCount,
    this.initFindingMsg,
    this.searchJumpAnchor,
    this.initialC2cCanMessage,
    this.c2cPermissionHintSource,
    this.showGroupProfile,
    this.directToChat,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ChatState();
}

class _LocalCallBubbleMarker {
  const _LocalCallBubbleMarker({
    required this.callId,
    required this.conversationId,
  });

  final String callId;
  final String conversationId;
}

class _ChatState extends State<Chat> {
  final TIMUIKitChatController _chatController = TIMUIKitChatController();
  final TUIConversationViewModel _conversationViewModel =
      serviceLocator<TUIConversationViewModel>();
  late V2TimConversation _conversation;
  String? _cachedHeaderFaceUrl;
  String? _cachedHeaderShowName;
  String? _resolvedPeerFaceUrl;
  String? _resolvedPeerFaceUrlForId;
  UserProfileRecord? _peerLocalProfile;
  final C2cSendPermissionController _c2cPermission =
      C2cSendPermissionController();
  final ChatDraftController _draft = ChatDraftController();
  Future<void> _draftWriteTail = Future<void>.value();
  final ChatGroupPageSideController _groupSide = ChatGroupPageSideController();
  final GroupLiveChatState _groupLiveState = GroupLiveChatState();
  bool _watchingGroupLive = false;

  /// 群聊打开期间兜底拉 `/live/current`：主播 CSS 确认推流后若 TCP 丢失，
  /// 群 Tab 轮询已停，不靠杀进程重进也能看到 LIVE / 可播。
  Timer? _groupLiveCurrentPollTimer;
  static const Duration _groupLiveCurrentPollInterval = Duration(seconds: 12);
  String? _groupLiveIndexFingerprint;
  final ChatHeaderStateController _headerState = ChatHeaderStateController();
  final ChatTopFixStateController _topFixState = ChatTopFixStateController();
  final ChatOpenLifecycle _openLifecycle = ChatOpenLifecycle();
  final ChatPostOpenScheduler _postOpenScheduler = ChatPostOpenScheduler();

  /// 转场期间只画轻壳；动画结束后再挂 TIMUIKitChat + 开 history gate。
  bool _heavyChatBodyMounted = false;
  final Map<Animation<double>, Set<AnimationStatusListener>>
      _routeTransitionListeners =
      <Animation<double>, Set<AnimationStatusListener>>{};
  final Map<String, Future<void>> _groupMemberCountLoads =
      <String, Future<void>>{};
  Timer? _peerPermissionSyncDebounce;
  String? backRemark;
  final V2TIMManager sdkInstance = TIMUIKitCore.getSDKInstance();
  String? conversationName;
  int? _groupMemberCount;
  int _groupMemberCountGeneration = 0;
  DateTime? _lastGroupMetadataRefreshAt;
  SangongAdminRound? _sangongAdminRound;
  StreamSubscription<SangongAdminRealtimeState>? _sangongRealtimeSub;
  final WalletCardSendService _walletCardSendSvc = WalletCardSendService();
  final WalletCardOutboundSidecar _walletOutbound =
      WalletCardOutboundSidecar.instance;
  static const Set<String> _foregroundRecoveryReasons = <String>{
    'app_resumed',
    'sync_server_finish',
    'connect_success',
    'im_reconnected',
    ConversationPreviewHistorySync.previewAheadOnOpenReason,
  };
  String? _chatBackgroundPath;
  MessageItemBuilder? _messageItemBuilder;
  String? _messageItemBuilderConvKey;
  late final ChatLifeCycle _chatLifeCycle;
  Timer? _callBubbleRefreshTimer;
  Timer? _reconnectRecoveryTimer;
  LocalSetting? _localSetting;
  ConnectStatus? _lastConnectStatus;
  String? _lastPublishedExternalEntryState;
  bool _externalEntryPublishScheduled = false;
  bool? _pendingExternalEntryRouteVisible;
  final _historyListConfig = TIMUIKitHistoryMessageListConfig(
    cacheExtent: AndroidPerformanceProfile.instance.chatHistoryCacheExtent,
    scrollingCacheExtent:
        AndroidPerformanceProfile.instance.chatHistoryActiveScrollCacheExtent,
    shrinkWrap: false,
    // Message rows add their own selective repaint boundaries in UIKit.
    // Keep the delegate wrapper off to avoid double layer allocation.
    addRepaintBoundaries: false,
    physics: switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      _ => const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    },
    skipRepaintBoundaryForMessage: CustomMessageElem.isWalletCardMessage,
    skipMessageEnterAnimationForMessage: _skipChatMessageEnterAnimation,
  );
  List<V2TimMessage>? _mountedDisplayListCache;
  int _mountedDisplayListLen = 0;
  TUIChatGlobalModel? _chatGlobalModel;
  int _trackedGlobalMessageCount = 0;
  int _trackedGlobalMessageRevision = 0;
  String _trackedGlobalLastMsgId = '';
  TIMUIKitChatConfig? _cachedChatConfig;
  String? _cachedConfigKey;
  ToolTipsConfig? _cachedToolTipsConfig;
  MorePanelConfig? _cachedMorePanelConfig;
  Timer? _groupMemberAvatarRefreshDebounce;

  String _configCacheKey({
    required bool showReadingStatus,
    required int stickerPackCount,
    required bool isDarkTheme,
  }) {
    return '${_resolvedConversationID()}_'
        '${showReadingStatus}_${stickerPackCount}_$isDarkTheme';
  }

  String _searchJumpMessageKey(V2TimMessage? message) {
    if (message == null) {
      return '';
    }
    final msgID = TencentUtils.checkString(message.msgID);
    if (msgID != null) return msgID;
    final id = TencentUtils.checkString(message.id);
    if (id != null) return id;
    final seq = TencentUtils.checkString(message.seq);
    if (seq != null) return 'seq_$seq';
    return '${message.sender ?? message.userID ?? ''}_'
        '${message.timestamp ?? ''}_${message.random ?? ''}';
  }

  void _invalidateChatConfigCache() {
    _cachedChatConfig = null;
    _cachedConfigKey = null;
    _cachedToolTipsConfig = null;
    _cachedMorePanelConfig = null;
  }

  void _ensureChatBuildConfigs({
    required BuildContext context,
    required TUITheme theme,
    required bool showReadingStatus,
    required StickerPanelConfig stickerPanelConfig,
    required String configKey,
  }) {
    if (_cachedChatConfig != null && _cachedConfigKey == configKey) {
      return;
    }
    _cachedConfigKey = configKey;
    _cachedChatConfig = _buildTimUIKitChatConfig(
      context: context,
      showReadingStatus: showReadingStatus,
      stickerPanelConfig: stickerPanelConfig,
    );
    _cachedToolTipsConfig = _buildToolTipsConfig(context);
    _cachedMorePanelConfig = _buildMorePanelConfig(theme);
  }

  String _getTitle() {
    if (backRemark != null && backRemark!.isNotEmpty) {
      return backRemark!;
    }
    if (_getConvType() == ConvType.group) {
      // 与会话列表一致：优先群资料库，避免把群 ID / 展示别名当头部昵称。
      final groupId = _conversation.groupID?.trim() ?? '';
      final localGroupName = groupId.isEmpty
          ? null
          : GroupLocalStore.instance.readCached(groupId: groupId)?.groupName;
      final resolved = GroupDisplayResolver.resolveShowName(
        conversation: _conversation,
        groupList: serviceLocator<TUIFriendShipViewModel>().groupList,
        localGroupName: localGroupName,
      );
      if (resolved.trim().isNotEmpty &&
          !GroupDisplayResolver.looksLikeGroupIdLabel(
            resolved,
            groupId: _conversation.groupID,
          )) {
        return resolved;
      }
      final cached = _conversation.showName?.trim() ?? '';
      if (cached.isNotEmpty &&
          !GroupDisplayResolver.looksLikeGroupIdLabel(
            cached,
            groupId: _conversation.groupID,
          )) {
        return cached;
      }
      return 'Chat';
    }
    final userId = widget.selectedConversation.userID;
    if (_getConvType() == ConvType.c2c &&
        PlatformOfficialAccountService.prefersImProfileDisplayName(userId)) {
      final official = PlatformOfficialAccountService.resolveShowName(
        userId: userId,
        conversationShowName: _conversation.showName,
      );
      if (official.trim().isNotEmpty) {
        return official;
      }
    }
    if (_getConvType() == ConvType.c2c) {
      final resolved = FriendDisplayName.resolveLocalFirst(
        localProfile: _peerLocalProfile,
        userId: userId,
        conversationShowName: _conversation.showName,
      );
      if (resolved.trim().isNotEmpty) {
        return resolved;
      }
    }
    return _conversation.showName ?? "Chat";
  }

  /// 群聊头部超级大群判定：会话 groupType，缺则本地群资料库。
  String? _headerGroupType() {
    if (_getConvType() != ConvType.group) {
      return null;
    }
    final fromConv =
        (_conversation.groupType ?? widget.selectedConversation.groupType ?? '')
            .trim();
    if (fromConv.isNotEmpty) {
      return fromConv;
    }
    final groupId = _conversation.groupID?.trim() ??
        widget.selectedConversation.groupID?.trim() ??
        '';
    if (groupId.isEmpty) {
      return null;
    }
    final local = GroupLocalStore.instance.readCached(groupId: groupId);
    final type = local?.groupType.trim() ?? '';
    return type.isEmpty ? null : type;
  }

  String? _getConvID() {
    return ConversationPreviewHistorySync.conversationMessageCacheKey(
      widget.selectedConversation,
    );
  }

  String? _c2cPeerUserId() {
    if (_getConvType() != ConvType.c2c) {
      return null;
    }
    final fromUser = ChatIdFormat.canonicalC2cUserId(
      widget.selectedConversation.userID,
    );
    if (fromUser.isNotEmpty) {
      return fromUser;
    }
    final fromConv = ChatIdFormat.canonicalC2cUserId(
      widget.selectedConversation.conversationID,
    );
    return fromConv.isEmpty ? null : fromConv;
  }

  bool _isC2cMessageBlocked() {
    return _getConvType() == ConvType.c2c && _c2cPermission.canMessage == false;
  }

  bool _isC2cMessagePermissionChecking() {
    return _getConvType() == ConvType.c2c &&
        _c2cPeerUserId() != null &&
        _c2cPermission.canMessage == null;
  }

  void _applyInitialC2cPermissionHint({bool resetIfMissing = false}) {
    final peer = _c2cPeerUserId();
    if (peer == null) {
      _c2cPermission.trustedInitialCanMessage = false;
      if (resetIfMissing) {
        _c2cPermission.canMessage = null;
      }
      return;
    }

    final trusted = widget.initialC2cCanMessage == true ||
        C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer);
    if (trusted) {
      _c2cPermission.trustedInitialCanMessage = true;
      _c2cPermission.canMessage = true;
      C2cFriendMessageGuard.trustCanSendHint(
        peer,
        source: widget.c2cPermissionHintSource ?? 'trusted_chat_entry',
      );
      return;
    }

    _c2cPermission.trustedInitialCanMessage = false;
    if (resetIfMissing) {
      _c2cPermission.canMessage = null;
    }
  }

  void _schedulePeerMessagePermissionSync({
    bool forceNetwork = false,
    Duration delay = const Duration(milliseconds: 160),
  }) {
    if (!mounted || _getConvType() != ConvType.c2c) {
      return;
    }
    _peerPermissionSyncDebounce?.cancel();
    _peerPermissionSyncDebounce = Timer(delay, () {
      if (!mounted) {
        return;
      }
      unawaited(_syncPeerMessagePermission(forceNetwork: forceNetwork));
    });
  }

  void _syncInFlightOutgoingOnC2cBlocked() {
    if (!mounted || _getConvType() != ConvType.c2c) {
      return;
    }
    final convKey = _getConvID()?.trim();
    if (convKey == null || convKey.isEmpty) {
      return;
    }
    C2cBlockedOutgoingMessageSync.markInFlightAsFriendBlocked(
      conversationID: convKey,
      globalModel: serviceLocator<TUIChatGlobalModel>(),
      reason: C2cBlockedOutgoingMessageSync.relationBlockedReason,
    );
  }

  Future<void> _syncPeerMessagePermission({bool forceNetwork = false}) async {
    final peer = _c2cPeerUserId();
    final requestSeq = _c2cPermission.nextRequestSeq();
    if (peer == null) {
      if (_c2cPermission.canMessage != null) {
        _c2cPermission.canMessage = null;
      }
      return;
    }

    final cachedSnapshot =
        !forceNetwork ? C2cFriendMessageGuard.cachedUiSnapshot(peer) : null;
    final snapshot = cachedSnapshot ??
        await C2cFriendMessageGuard.refreshUiSnapshot(
          peer,
          forceNetwork: forceNetwork,
        );
    if (!mounted || requestSeq != _c2cPermission.requestSeq) {
      return;
    }
    if (_c2cPeerUserId() != peer) {
      return;
    }
    if (snapshot.decision == C2cSendPermissionDecision.allowed) {
      if (_c2cPermission.canMessage != true) {
        _c2cPermission.canMessage = true;
      }
      return;
    }
    if (snapshot.decision == C2cSendPermissionDecision.blocked &&
        snapshot.relationConfirmed) {
      _c2cPermission.applyRelationBlocked();
      return;
    }
  }

  /// Fresh became-friends trust must not be overridden by a lagging false.
  bool _resolveC2cUiCanMessage(String peer, bool canSend) {
    if (canSend) {
      return true;
    }
    if (C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peer)) {
      return true;
    }
    return false;
  }

  void _onFriendshipModelChanged() {
    if (!mounted || _getConvType() != ConvType.c2c) {
      return;
    }
    // Do not unlock C2C input from Tencent IM SDK friendship state. During
    // migration it can say "both friend" while 99chat-server relation still
    // returns canMessage=false. Schedule one backend-authoritative check only.
    _schedulePeerMessagePermissionSync(
      delay: const Duration(milliseconds: 320),
    );
  }

  Widget Function(BuildContext context)? _resolveChatTextFieldBuilder(
    TUITheme theme,
  ) {
    if (PlatformOfficialAccountService.showsVerifiedBadge(
      widget.selectedConversation.userID,
    )) {
      return (_) => OfficialAccountInputSpacer(
            backgroundColor: theme.weakBackgroundColor ??
                theme.conversationItemBgColor ??
                const Color(0xFFF5F5F6),
          );
    }

    return null;
  }

  Widget Function(BuildContext context, Widget child)?
      _resolveChatTextFieldWrapperBuilder(TUITheme theme) {
    if (_getConvType() != ConvType.c2c ||
        PlatformOfficialAccountService.showsVerifiedBadge(
          widget.selectedConversation.userID,
        )) {
      return null;
    }
    final peerId = _c2cPeerUserId();
    if (peerId == null) {
      return null;
    }
    return (context, child) {
      return AnimatedBuilder(
        animation: _c2cPermission,
        child: child,
        builder: (context, child) {
          if (_isC2cMessageBlocked()) {
            return C2cFriendMessageBlockedBar(
              peerUserId: peerId,
              theme: theme,
            );
          }
          return child ?? const SizedBox.shrink();
        },
      );
    };
  }

  Widget? _resolveChatInputTopBuilder(TUITheme theme) {
    if (_getConvType() != ConvType.c2c) {
      return null;
    }
    // No visible checking banner. Relation refresh is silent; blocked state is
    // rendered by textFieldWrapperBuilder as the single product warning bar.
    return null;
  }

  String _resolvedConversationID([V2TimConversation? conversation]) {
    final target = conversation ?? widget.selectedConversation;
    return ExternalChatEntryService.instance.resolveConversationId(
          conversationID: target.conversationID,
          groupID: target.groupID,
          userID: target.userID,
        ) ??
        '';
  }

  bool _matchesRefreshConversationId(String? target) {
    final id = target?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    return MessageConversationId.sameConversation(
      id,
      _resolvedConversationID(),
    );
  }

  void _onConversationDeletedBus() {
    if (!mounted) {
      return;
    }
    // Wide-screen embedded Chat is closed by clearing currentConversation;
    // only pop when this Chat was pushed as its own route (mobile).
    if (widget.showGroupProfile != null) {
      return;
    }
    final ownId = _resolvedConversationID();
    if (ownId.isEmpty) {
      return;
    }
    final hit = ConversationDeletedBus.instance.lastDeletedIds.any(
      (id) => MessageConversationId.sameConversation(id, ownId),
    );
    if (!hit) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _attachLocalSettingListener() {
    final setting = Provider.of<LocalSetting>(context, listen: false);
    if (_localSetting == setting) {
      return;
    }
    _localSetting?.removeListener(_onLocalSettingChanged);
    _localSetting = setting;
    _lastConnectStatus = setting.connectStatusForUi;
    setting.addListener(_onLocalSettingChanged);
  }

  void _onLocalSettingChanged() {
    if (!mounted) {
      return;
    }
    // 用 ForUi：connecting 在 debounce 写入 applied 前也能感知断线，
    // 避免「断线→秒连」时 applied 一直是 success，漏掉 im_reconnected 补拉。
    final next = _localSetting?.connectStatusForUi;
    final previous = _lastConnectStatus;
    _lastConnectStatus = next;
    if (previous != ConnectStatus.success && next == ConnectStatus.success) {
      _scheduleReconnectHistoryRecovery();
    }
  }

  void _scheduleReconnectHistoryRecovery() {
    _reconnectRecoveryTimer?.cancel();
    _reconnectRecoveryTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final conversationId = _resolvedConversationID();
      if (conversationId.isEmpty) {
        return;
      }
      ChatHistoryRefreshBus.instance.requestRefresh(
        conversationId: conversationId,
        reason: 'im_reconnected',
      );
    });
  }

  /// 打开群聊后异步纠偏：本地群资料里的真实 `@TGS#_mc…` 覆盖错误加成 ID。
  Future<void> _resolveImGroupIdAfterOpen() async {
    if (_getConvType() != ConvType.group) {
      return;
    }
    final raw = _conversation.groupID?.trim() ?? '';
    if (raw.isEmpty) {
      return;
    }
    final resolved = await GroupLocalStore.instance.resolveImGroupId(raw);
    if (!mounted || resolved.isEmpty) {
      return;
    }
    final current = ChatIdFormat.normalizeGroupId(raw);
    if (resolved == current) {
      return;
    }
    // 仅当解析出不同真源（常见：m2 短码 → @TGS#_mc…）时改写。
    debugPrint('Chat: resolve im groupId $current -> $resolved');
    setState(() {
      _conversation.groupID = resolved;
      _conversation.conversationID = 'group_$resolved';
    });
  }

  V2TimConversation _normalizedConversationForChat(
    V2TimConversation conversation,
  ) {
    final resolvedConversationID = _resolvedConversationID(conversation);
    if (resolvedConversationID.isNotEmpty &&
        conversation.conversationID.trim().isEmpty) {
      conversation.conversationID = resolvedConversationID;
    }
    final rawGroupId = conversation.groupID?.trim() ?? '';
    if (rawGroupId.isNotEmpty &&
        (conversation.type == 2 ||
            rawGroupId.toUpperCase().contains('TGS#') ||
            ChatIdFormat.isIMGroupOrCommunityId(rawGroupId))) {
      // 优先本地群资料真源（@TGS#_mc…），避免 displayAlias 短码加成成不存在的
      // @TGS#_@TGS#m2…（rizhi：10010 / 6017）。
      final cached = GroupLocalStore.instance.readCached(groupId: rawGroupId);
      final fromStore = cached == null
          ? ''
          : ChatIdFormat.imGroupIdFromRecord(
              groupId: cached.groupId,
              displayAlias: cached.displayAlias,
            );
      final normalizedGroupId = fromStore.isNotEmpty
          ? fromStore
          : ChatIdFormat.canonicalGroupStorageId(rawGroupId);
      if (normalizedGroupId.isNotEmpty && normalizedGroupId != rawGroupId) {
        conversation.groupID = normalizedGroupId;
      }
      final gid = conversation.groupID?.trim() ?? '';
      if (gid.isNotEmpty) {
        final wantConvId = 'group_$gid';
        final curConvId = conversation.conversationID.trim();
        if (curConvId.isEmpty ||
            (curConvId.toLowerCase().startsWith('group_') &&
                curConvId != wantConvId &&
                !ChatIdFormat.groupIdsEquivalent(curConvId, wantConvId))) {
          // 仅在会话 ID 仍是错误加成形态时改写，避免无谓抖动。
          final bare = curConvId.toLowerCase().startsWith('group_')
              ? curConvId.substring(6)
              : curConvId;
          if (bare.isEmpty ||
              ChatIdFormat.apiGroupId(bare) == ChatIdFormat.apiGroupId(gid) ||
              ChatIdFormat.looksLikeCommunityGroupId(bare)) {
            conversation.conversationID = wantConvId;
          }
        }
      }
    } else if (rawGroupId.isEmpty &&
        conversation.conversationID.trim().toLowerCase().startsWith('group_')) {
      final fromConv = ChatIdFormat.canonicalGroupStorageId(
        conversation.conversationID,
      );
      final cached = fromConv.isEmpty
          ? null
          : GroupLocalStore.instance.readCached(groupId: fromConv);
      final fromStore = cached == null
          ? ''
          : ChatIdFormat.imGroupIdFromRecord(
              groupId: cached.groupId,
              displayAlias: cached.displayAlias,
            );
      final resolved = fromStore.isNotEmpty ? fromStore : fromConv;
      if (resolved.isNotEmpty) {
        conversation.groupID = resolved;
        conversation.conversationID = 'group_$resolved';
      }
    }
    return conversation;
  }

  List<MorePanelItem> _buildWalletMorePanelItems(TUITheme theme) {
    if (PlatformOfficialAccountService.isPlatformOfficialAccount(
      widget.selectedConversation.userID,
    )) {
      return [];
    }
    return [
      MorePanelItem(
        id: 'wallet_red_packet',
        title: AppI18n.of(
          context,
        ).t(zhHans: '红包', zhHant: '紅包', en: 'Red Packet', ja: 'お年玉', ko: '홍바오'),
        icon: MorePanelStyles.pngIcon(theme, 'assets/chat_more/red_packet.png'),
        onTap: (_) => _openRedPacket(),
      ),
      MorePanelItem(
        id: 'wallet_transfer',
        title: AppI18n.of(context).t(
          zhHans: _getConvType() == ConvType.group ? '群转账' : '转账',
          zhHant: _getConvType() == ConvType.group ? '群轉帳' : '轉帳',
          en: _getConvType() == ConvType.group ? 'Group Transfer' : 'Transfer',
          ja: _getConvType() == ConvType.group ? 'グループ送金' : '送金',
          ko: _getConvType() == ConvType.group ? '그룹 이체' : '이체',
        ),
        icon: MorePanelStyles.pngIcon(theme, 'assets/chat_more/transfer.png'),
        onTap: (_) => _openWalletTransfer(),
      ),
    ];
  }

  Future<void> _openAgentRebateCurrent() async {
    _dismissChatInput();
    await AgentRebateCurrentPage.open(context);
    if (mounted) {
      _restoreActiveChatRegistry();
      await _loadAgentRebateIdentity();
    }
  }

  Future<void> _openAgentRebateDescendants() async {
    _dismissChatInput();
    await AgentRebateDescendantsPage.open(context);
    if (mounted) {
      _restoreActiveChatRegistry();
      await _loadAgentRebateIdentity();
    }
  }

  Future<void> _openAgentRebateHistory() async {
    _dismissChatInput();
    final selected = await showAgentRebateDateRangePicker(
      context,
      initialRange: AgentRebateDateRange.today(),
    );
    if (!mounted || selected == null) return;
    await AgentRebateHistoryPage.open(context, initialRange: selected);
    if (mounted) {
      _restoreActiveChatRegistry();
      await _loadAgentRebateIdentity();
    }
  }

  Future<String?> _resolveBusinessReceiverId(String? raw) async {
    final id = ChatIdFormat.rawUserUid(raw);
    if (id.isNotEmpty) {
      return id;
    }
    if (mounted) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '无法识别对方账号',
        zhHant: '無法識別對方帳號',
        en: 'Cannot resolve peer account',
        ja: '相手アカウントを特定できません',
        ko: '상대 계정을 확인할 수 없음',
      ));
    }
    return null;
  }

  Future<void> _openRedPacket({
    RpType? initialType,
    String? exclusiveReceiverId,
    String? exclusiveReceiverName,
    String? exclusiveReceiverAvatar,
  }) async {
    final convId = _getConvID() ?? '';
    if (convId.isEmpty) return;
    final isGroup = _getConvType() == ConvType.group;

    final pinReady = await WalletPayPinGuard.ensureSet(context);
    if (!pinReady || !mounted) return;

    _dismissChatInput();
    String receiverIdForScreen = '';
    if (!isGroup) {
      final biz = await _resolveBusinessReceiverId(
        widget.selectedConversation.userID,
      );
      if (biz == null) return;
      receiverIdForScreen = biz;
    } else {
      final preset = exclusiveReceiverId?.trim() ?? '';
      if (preset.isNotEmpty) {
        final biz = await _resolveBusinessReceiverId(preset);
        if (biz == null) return;
        receiverIdForScreen = biz;
      }
    }
    final ret = await _pushWalletPayRoute<bool>(
      RedPacketScreen(
        conversationId: convId,
        receiverId: receiverIdForScreen,
        receiverName: isGroup
            ? (exclusiveReceiverName?.trim() ?? '')
            : (widget.selectedConversation.showName ?? _getTitle()),
        groupNum: isGroup ? (_groupMemberCount?.toString() ?? '') : '',
        isGroup: isGroup,
        initialType: initialType,
        exclusiveReceiverAvatar: exclusiveReceiverAvatar?.trim() ?? '',
      ),
    );

    if (ret == true) {
      await _retryWalletCardsForConversation();
    }
  }

  V2TimGroupMemberFullInfo? _findGroupMemberByUserId(String userId) {
    final key = userId.trim();
    if (key.isEmpty) return null;
    for (final member in _chatController.getGroupMemberList()) {
      if (member.userID.trim() == key) {
        return member;
      }
    }
    return null;
  }

  String _resolveGroupMemberDisplayName({
    required String userId,
    String? nickName,
  }) {
    final member = _findGroupMemberByUserId(userId);
    if (member != null) {
      return UserDisplayProfile.nameOfMember(member);
    }
    return UserDisplayProfile.name(
      userId: userId,
      imNickName: nickName,
    );
  }

  /// 专属红包收款人：只用用户昵称，不用好友备注。
  String _resolveGroupMemberNickname({
    required String userId,
    String? nickName,
  }) {
    final member = _findGroupMemberByUserId(userId);
    final memberNick = member?.nickName?.trim() ?? '';
    final nick = TransferPartyNameResolver.nicknameOf(
      userId: userId,
      nickHint: memberNick.isNotEmpty ? memberNick : nickName,
    );
    if (nick.isNotEmpty) {
      return nick;
    }
    return userId.trim();
  }

  void _dismissChatInput() {
    _chatController.hideAllBottomPanelOnMobile();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<T?> _pushWalletPayRoute<T>(Widget page) async {
    final convId = _resolvedConversationID();
    final globalModel =
        _chatGlobalModel ?? serviceLocator<TUIChatGlobalModel>();
    globalModel.beginWalletOverlay(conversationID: convId);
    try {
      return await Navigator.of(context).push<T>(
        AppMaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.walletOverlay),
          builder: (_) => page,
        ),
      );
    } finally {
      globalModel.endWalletOverlay(conversationID: convId);
    }
  }

  Future<void> _loadChatLocalDraft() async {
    final conversationId = _resolvedConversationID();
    if (conversationId.isEmpty) {
      return;
    }
    final text = await ConversationDraftService.instance.loadDraftText(
      conversationID: conversationId,
    );
    print('[ChatInputDiag] host=load_draft conv=$conversationId '
        'len=${text?.length ?? 0}');
    if (!mounted) {
      return;
    }
    _draft.text = text;
    final loaded = text?.trim() ?? '';
    final inputController = _chatController.textFieldController;
    final editingController = inputController?.textEditingController;
    if (inputController != null && editingController != null) {
      final current = editingController.text;
      if (loaded.isNotEmpty && current.trim().isEmpty) {
        inputController.setTextField(text!);
      }
      return;
    }
    if (loaded.isNotEmpty && mounted) {
      setState(() {});
    }
  }

  Future<void> _persistChatLocalDraftText(String text, int generation) async {
    final conversationId = _resolvedConversationID();
    if (conversationId.isEmpty) {
      return;
    }
    _draftWriteTail = _draftWriteTail.then((_) async {
      if (generation != _draft.writeGeneration) {
        print(
            '[ChatInputDiag] draft=queued_write_stale_drop conv=$conversationId '
            'generation=$generation current=${_draft.writeGeneration}');
        return;
      }
      _draft.text = text.trim().isEmpty ? null : text;
      print(
          '[ChatInputDiag] draft=persist_start conv=$conversationId len=${text.length}');
      await ConversationDraftService.instance.persistDraft(
        conversationID: conversationId,
        rawInputText: text,
      );
      print(
          '[ChatInputDiag] draft=persist_done conv=$conversationId len=${text.length}');
    });
    await _draftWriteTail;
  }

  void _onChatDraftTextChanged(String text) {
    final clipped = text.length > 120 ? '${text.substring(0, 120)}…' : text;
    final codes = clipped.runes
        .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
        .join(',');
    print('[ChatInputDiag] host=on_changed conv=${_resolvedConversationID()} '
        'len=${text.length} text="${clipped.replaceAll('\n', '\\n')}" codes=[$codes]');
    _draft.onChanged(
      text,
      persist: (raw, generation) =>
          unawaited(_persistChatLocalDraftText(raw, generation)),
    );
  }

  Future<void> _persistChatLocalDraft() async {
    _draft.cancelDebounce();
    final text =
        _chatController.textFieldController?.textEditingController?.text ?? '';
    await _persistChatLocalDraftText(text, _draft.writeGeneration);
  }

  Future<void> _clearChatLocalDraftAfterSend(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    // 发送成功后使发送前排队的 debounce 保存失效，否则旧草稿可能在清理后
    // 又被异步写回本地库，表现为“消息已发出但草稿仍出现”。
    _draft.clear();
    print('[ChatInputDiag] host=clear_after_send conv=$id');
    if (mounted) {
      _draft.text = null;
    }
    _draftWriteTail = _draftWriteTail.then((_) async {
      print('[ChatInputDiag] draft=clear_start conv=$id');
      await ConversationDraftService.instance.clearDraft(conversationID: id);
      print('[ChatInputDiag] draft=clear_done conv=$id');
    });
    await _draftWriteTail;
  }

  void _mentionMemberInGroup({required String userId, String? nickName}) {
    final showName = _resolveGroupMemberDisplayName(
      userId: userId,
      nickName: nickName,
    );
    _chatController.mentionOtherMemberInGroup(
      showNameInMessage: showName,
      userID: userId,
    );
  }

  V2TimGroupInfo? _currentGroupInfo() => _chatController.model?.groupInfo;

  bool _canKickTargetGroupMember(
    V2TimGroupInfo groupInfo,
    V2TimGroupMemberFullInfo target,
  ) {
    if (!GroupRolePolicy.canKickMemberEntry(
      selfRole: groupInfo.role,
      groupType: groupInfo.groupType,
    )) {
      return false;
    }
    return GroupRolePolicy.canKickTargetMember(
      selfRole: groupInfo.role,
      targetRole: target.role,
    );
  }

  bool _canMuteTargetGroupMember(
    V2TimGroupInfo groupInfo,
    V2TimGroupMemberFullInfo target,
  ) {
    return GroupRolePolicy.canMuteTargetMember(
      selfRole: groupInfo.role,
      targetRole: target.role,
      groupType: groupInfo.groupType,
      isAllMuted: groupInfo.isAllMuted == true,
    );
  }

  bool _isGroupMemberCurrentlyMuted(
    V2TimGroupMemberFullInfo member, {
    int? serverTime,
  }) {
    final now = serverTime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    return (member.muteUntil ?? 0) > now;
  }

  /// 与输入栏禁言逻辑一致：群主/管理员始终可发言；全员禁言或个人禁言则不可发言。
  bool _canCurrentUserSpeakInGroup({int? serverTime}) {
    final model = _chatController.model;
    final selfInfo = model?.selfMemberInfo;
    final role = selfInfo?.role ??
        model?.groupInfo?.role ??
        GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    final now = serverTime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    return GroupRolePolicy.canSpeakInGroup(
      role: role,
      isAllMuted: model?.groupInfo?.isAllMuted == true,
      muteUntilSeconds: selfInfo?.muteUntil ?? 0,
      nowSeconds: now,
    );
  }

  Future<int> _fetchImServerTime() async {
    final res = await TencentImSDKPlugin.v2TIMManager.getServerTime();
    final value = res.data;
    if (value != null && value > 0) {
      return value;
    }
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  Future<void> _refreshChatGroupMuteState() async {
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    final model = _chatController.model;
    if (groupId.isEmpty || model == null) {
      return;
    }
    // 先应用后端/TCP 权威禁言状态，避免先渲染旧 SDK 状态导致输入栏闪回禁言。
    await _fetchAndStoreBackendMuteStatus(groupId);
  }

  /// 获取并存储后端禁言状态到 GroupMemberStore
  Future<void> _fetchAndStoreBackendMuteStatus(String groupId) async {
    if (_openLifecycle.muteStatusFetchStarted) {
      return;
    }
    _openLifecycle.muteStatusFetchStarted = true;
    final muteGeneration = _openLifecycle.muteFetchGeneration;
    final muteSw = Stopwatch()..start();
    try {
      final muteStatus = await MeGroupApi.instance.fetchMyMuteStatus(groupId);
      if (!mounted || muteGeneration != _openLifecycle.muteFetchGeneration) {
        return;
      }
      ChatOpenPerfLog.mark(
        'mute_network_fetch_done',
        extras: <String, Object?>{
          'muteMs': muteSw.elapsedMilliseconds,
          'hasStatus': muteStatus != null,
          'isAllMuted': muteStatus?.isAllMuted,
        },
      );
      if (muteStatus == null) {
        return;
      }
      if (false)
        debugPrint(
          '[MUTE_DEBUG] _fetchAndStoreBackendMuteStatus: Backend API muteUntil=${muteStatus.muteUntil}, isAllMuted=${muteStatus.isAllMuted}',
        );
      await GroupLocalStore.instance.patch(
        ownerUserId: GroupLocalStore.instance.currentOwnerUserId(),
        groupId: groupId,
        transform: (current) =>
            current.copyWith(isAllMuted: muteStatus.isAllMuted),
      );

      Future<bool> applyToModel() async {
        final model = _chatController.model;
        if (model == null || !mounted) {
          return false;
        }
        await model.updateSelfMuteStatus(
          groupID: groupId,
          muteUntil: muteStatus.muteUntil,
          isAllMuted: muteStatus.isAllMuted,
        );
        return true;
      }

      if (await applyToModel()) {
        return;
      }
      // 进群极早请求时 model 可能尚未就绪，短暂重试避免输入栏一直可发。
      for (final delay in const <Duration>[
        Duration(milliseconds: 80),
        Duration(milliseconds: 200),
        Duration(milliseconds: 500),
      ]) {
        await Future<void>.delayed(delay);
        if (!mounted || muteGeneration != _openLifecycle.muteFetchGeneration) {
          return;
        }
        if (await applyToModel()) {
          return;
        }
      }
    } catch (e) {
      if (false)
        debugPrint(
          '[MUTE_DEBUG] _fetchAndStoreBackendMuteStatus: Failed to fetch mute status from backend: $e',
        );
      if (muteGeneration == _openLifecycle.muteFetchGeneration) {
        _openLifecycle.muteStatusFetchStarted = false;
      }
    }
  }

  void _cancelChatOpenSideEffects({
    required String reason,
    bool resumeWarm = true,
  }) {
    _openLifecycle.cancelPendingMuteFetch();
    _chatController.model?.cancelOpenSideMemberLoads();
    if (!resumeWarm) {
      return;
    }
    if (ConversationPerfFlags.historyWarmDeferResumeAfterChatLeave) {
      ConversationHistoryWarmScheduler.instance.resumeAfterActiveChat(
        reason: reason,
        deferIncompleteWarm: true,
      );
      return;
    }
    ConversationHistoryWarmScheduler.instance.resumeAfterActiveChat(
      reason: reason,
    );
  }

  /// 栈内仍开着 Chat 时登记/恢复 ActiveChat。被资料页盖住时只改 routeVisible，不 leave。
  void _restoreActiveChatRegistry({bool routeVisible = true}) {
    final id = _resolvedConversationID();
    if (id.isEmpty) {
      return;
    }
    final current = ActiveChatRegistry.instance.activeConversationId;
    if (current == null ||
        !MessageConversationId.sameConversation(current, id)) {
      ActiveChatRegistry.instance.enter(
        id,
        routeVisible: routeVisible,
        conversationType: _getConvType(),
      );
      return;
    }
    ActiveChatRegistry.instance.updateRouteVisible(routeVisible);
  }

  /// 离开 Chat 后交还列表：默认只 patch 刚离开会话，并 flush 进聊期间挂起的 Feed notify。
  void _flushConversationListUiAfterChatLeave({
    required String reason,
    String? leftConversationId,
  }) {
    final leftId = (leftConversationId ?? '').trim();
    if (ConversationPerfFlags.chatLeavePatchLeftOnlyEnabled) {
      unawaited(
        ConversationListNotifier.instance.patchConversationAfterChatLeave(
          leftId,
          reason: reason,
        ),
      );
      return;
    }
    ConversationListNotifier.instance.flushDeferredUiNotifyIfNeeded(
      reason: reason,
    );
  }

  Future<void> _warmAvatarsOnChatOpen() async {
    if (!mounted) {
      return;
    }
    final faces = <String?>[
      _conversation.faceUrl,
      widget.selectedConversation.faceUrl,
      _cachedHeaderFaceUrl,
    ];
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isNotEmpty) {
      final messages =
          serviceLocator<TUIChatGlobalModel>().messageListMap[convKey];
      if (messages != null) {
        final limit = messages.length < 30 ? messages.length : 30;
        for (var i = 0; i < limit; i++) {
          final message = messages[i];
          faces.add(message.faceUrl);
          if (_getConvType() == ConvType.group) {
            final groupId = widget.selectedConversation.groupID?.trim() ?? '';
            final sender = (message.sender ?? message.userID ?? '').trim();
            if (groupId.isNotEmpty && sender.isNotEmpty) {
              faces.add(
                GroupMemberStore.instance.memberOf(groupId, sender)?.faceUrl,
              );
            }
          }
        }
      }
    }
    await AvatarImageWarm.warmUrls(faces, context: context, logicalSize: 40);
  }

  void _releaseBubbleCacheAndWarmListAvatar() {
    final convKey = _getConvID()?.trim() ?? '';
    final messages = convKey.isEmpty
        ? const <V2TimMessage>[]
        : (serviceLocator<TUIChatGlobalModel>().messageListMap[convKey] ??
            const <V2TimMessage>[]);
    // 路由 pop 中同步驱逐 ImageCache 会抢占主线程，列表首帧后再按批释放。
    ChatImageMessagePrefetch.evictBubbleCacheForMessagesAfterFrame(messages);
    ChatJitterDiag.logImageCache(
      'chat_leave_bubble_evict_scheduled',
      extras: <String, Object?>{
        'rawMessageCount': messages.length,
      },
    );
    ChatResourceSample.onLeave(rawMessageCount: messages.length);
    // 会话列表在 Navigator.pop 返回后用自身仍有效的 context 预热头像；
    // 此处的 Chat context 已进入 dispose，不再启动跨帧图片任务。
  }

  Future<void> _refreshChatGroupMembers(
    String groupId, {
    List<String> userIds = const <String>[],
  }) async {
    final model = _chatController.model;
    if (model == null || groupId.trim().isEmpty) {
      return;
    }
    final gid = groupId.trim();
    final ids = userIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (ids.isNotEmpty) {
      await model.refreshGroupMembersByUserIds(groupID: gid, userIds: ids);
      return;
    }
    // 无定点 uid 时只重跑 open-shell，禁止整表 loadGroupMemberList。
    await model.loadGroupMembersForOpenShell(groupID: gid);
  }

  Future<void> _muteGroupMemberFromChat({
    required String groupId,
    required String targetId,
    required String displayName,
    required bool mute,
  }) async {
    final confirmed = await AppDialog.confirm(
      title: AppI18n.of(context).t(
        zhHans: mute ? '禁言成员' : '解除禁言',
        zhHant: mute ? '禁言成員' : '解除禁言',
        en: mute ? 'Mute Member' : 'Unmute Member',
        ja: mute ? 'メンバーをミュート' : 'ミュート解除',
        ko: mute ? '멤버 채팅 금지' : '채팅 금지 해제',
      ),
      message: AppI18n.of(context).t(
        zhHans: mute ? '确定禁言「$displayName」吗？' : '确定解除「$displayName」的禁言吗？',
        zhHant: mute ? '確定禁言「$displayName」嗎？' : '確定解除「$displayName」的禁言嗎？',
        en: mute ? 'Mute "$displayName"?' : 'Unmute "$displayName"?',
        ja: mute ? '「$displayName」をミュートしますか？' : '「$displayName」のミュートを解除しますか？',
        ko: mute
            ? '"$displayName" 님을 채팅 금지하시겠습니까?'
            : '"$displayName" 님의 채팅 금지를 해제하시겠습니까?',
      ),
      destructive: mute,
    );
    if (!confirmed || !mounted) {
      return;
    }

    const muteTime = 315360000;
    final groupServices = serviceLocator<GroupServices>();
    final res = await groupServices.muteGroupMember(
      groupID: groupId,
      userID: targetId,
      seconds: mute ? muteTime : 0,
    );
    if (!mounted) {
      return;
    }
    if (res.code != 0) {
      final desc = res.desc.trim();
      ToastUtils.toast(
        desc.isNotEmpty
            ? desc
            : AppI18n.of(context).t(
                zhHans: '操作失败',
                zhHant: '操作失敗',
                en: 'Operation failed',
                ja: '操作に失敗しました',
                ko: '작업에 실패했습니다',
              ),
      );
      return;
    }

    await _refreshChatGroupMembers(groupId, userIds: <String>[targetId]);
    if (!mounted) {
      return;
    }
    ToastUtils.toast(
      AppI18n.of(context).t(
        zhHans: mute ? '已禁言' : '已解除禁言',
        zhHant: mute ? '已禁言' : '已解除禁言',
        en: mute ? 'Member muted' : 'Member unmuted',
        ja: mute ? 'ミュートしました' : 'ミュートを解除しました',
        ko: mute ? '채팅 금지되었습니다' : '채팅 금지가 해제되었습니다',
      ),
    );
  }

  Future<void> _kickGroupMemberFromChat({
    required String groupId,
    required String targetId,
    required String displayName,
  }) async {
    final confirmed = await AppDialog.confirm(
      title: AppI18n.of(context).t(
        zhHans: '移出群聊',
        zhHant: '移出群聊',
        en: 'Remove from Group',
        ja: 'グループから削除',
        ko: '그룹에서보내기',
      ),
      message: AppI18n.of(context).t(
        zhHans: '确定将「$displayName」移出群聊吗？',
        zhHant: '確定將「$displayName」移出群聊嗎？',
        en: 'Remove "$displayName" from this group?',
        ja: '「$displayName」をグループから削除しますか？',
        ko: '"$displayName" 님을 그룹에서보내시겠습니까?',
      ),
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final groupServices = serviceLocator<GroupServices>();
    final res = await groupServices.kickGroupMember(
      groupID: groupId,
      memberList: [targetId],
    );
    if (!mounted) {
      return;
    }
    if (res.code != 0) {
      GroupMemberFeedbackBridge.show(
        SelfHostedGroupKickBridge.formatMessage(
          success: false,
          code: res.code,
          desc: res.desc,
        ),
      );
      return;
    }

    await _refreshChatGroupMembers(groupId, userIds: <String>[targetId]);
    if (!mounted) {
      return;
    }
    GroupMemberFeedbackBridge.show(
      SelfHostedGroupKickBridge.formatMessage(success: true),
    );
  }

  Future<void> _onLongPressOthersAvatar(
    String? userId,
    String? nickName,
  ) async {
    if (_getConvType() != ConvType.group) return;
    final targetId = userId?.trim() ?? '';
    if (targetId.isEmpty) {
      _chatController.mentionOtherMemberInGroup(
        showNameInMessage: '',
        userID: '',
      );
      return;
    }

    final loginUserId =
        TIMUIKitCore.getInstance().loginUserInfo?.userID?.trim() ?? '';
    if (targetId == loginUserId) return;

    if (PlatformOfficialAccountService.isPlatformOfficialAccount(targetId) ||
        PlatformOfficialAccountService.isOfficialAccountUserId(targetId)) {
      return;
    }

    final groupId = _getConvID()?.trim() ?? '';
    var member = _findGroupMemberByUserId(targetId);
    if (member == null && groupId.isNotEmpty) {
      await _refreshChatGroupMembers(groupId, userIds: <String>[targetId]);
      if (!mounted) {
        return;
      }
      member = _findGroupMemberByUserId(targetId);
    }
    if (member == null) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '该用户已退出群聊',
          zhHant: '該用戶已退出群聊',
          en: 'This user has left the group',
          ja: 'このユーザーはグループを退会しました',
          ko: '해당 사용자가 그룹을 나갔습니다',
        ),
      );
      return;
    }

    final displayName = _resolveGroupMemberDisplayName(
      userId: targetId,
      nickName: nickName,
    );
    final avatar = UserAvatarHelper.pickBest(imFaceUrl: member.faceUrl);
    final groupInfo = _currentGroupInfo();
    final serverTime = await _fetchImServerTime();
    if (!mounted) {
      return;
    }

    // 无发言权限（被禁言的普通成员）：长按头像不可操作。
    // 群主/管理员不受禁言影响，仍可弹出菜单。
    if (!_canCurrentUserSpeakInGroup(serverTime: serverTime)) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '禁言状态下无法操作',
          zhHant: '禁言狀態下無法操作',
          en: 'Unavailable while muted',
          ja: 'ミュート中は操作できません',
          ko: '채팅 금지 상태에서는 사용할 수 없습니다',
        ),
      );
      return;
    }

    final canMute = groupInfo != null &&
        groupId.isNotEmpty &&
        _canMuteTargetGroupMember(groupInfo, member);
    final canKick = groupInfo != null &&
        groupId.isNotEmpty &&
        _canKickTargetGroupMember(groupInfo, member);
    final isMuted = canMute
        ? _isGroupMemberCurrentlyMuted(member, serverTime: serverTime)
        : false;

    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) {
        final sheetActions = <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 'at'),
            child: Text(
              AppI18n.of(context).t(
                zhHans: '@他',
                zhHant: '@他',
                en: '@ Them',
                ja: '@する',
                ko: '@멘션',
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(sheetContext, 'exclusive_red_packet'),
            child: Text(
              AppI18n.of(context).t(
                zhHans: '专属红包',
                zhHant: '專屬紅包',
                en: 'Exclusive Red Packet',
                ja: '専用お年玉',
                ko: '전용 홍바오',
              ),
            ),
          ),
        ];

        if (canMute) {
          sheetActions.add(
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(sheetContext, isMuted ? 'unmute' : 'mute'),
              child: Text(
                AppI18n.of(context).t(
                  zhHans: isMuted ? '解除禁言' : '禁言',
                  zhHant: isMuted ? '解除禁言' : '禁言',
                  en: isMuted ? 'Unmute' : 'Mute',
                  ja: isMuted ? 'ミュート解除' : 'ミュート',
                  ko: isMuted ? '채팅 금지 해제' : '채팅 금지',
                ),
              ),
            ),
          );
        }
        if (canKick) {
          sheetActions.add(
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheetContext, 'kick'),
              child: Text(
                AppI18n.of(context).t(
                  zhHans: '移出群聊',
                  zhHant: '移出群聊',
                  en: 'Remove from Group',
                  ja: 'グループから削除',
                  ko: '그룹에서보내기',
                ),
              ),
            ),
          );
        }

        return CupertinoActionSheet(
          actions: sheetActions,
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(
              AppI18n.of(context).t(
                zhHans: '取消',
                zhHant: '取消',
                en: 'Cancel',
                ja: 'キャンセル',
                ko: '취소',
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'at':
        _mentionMemberInGroup(userId: targetId, nickName: nickName);
        break;
      case 'exclusive_red_packet':
        if (!_canCurrentUserSpeakInGroup()) {
          break;
        }
        _dismissChatInput();
        await _openRedPacket(
          initialType: RpType.exclusive,
          exclusiveReceiverId: targetId,
          exclusiveReceiverName: _resolveGroupMemberNickname(
            userId: targetId,
            nickName: nickName,
          ),
          exclusiveReceiverAvatar: avatar,
        );
        break;
      case 'mute':
      case 'unmute':
        _dismissChatInput();
        await _muteGroupMemberFromChat(
          groupId: groupId,
          targetId: targetId,
          displayName: displayName,
          mute: action == 'mute',
        );
        break;
      case 'kick':
        _dismissChatInput();
        await _kickGroupMemberFromChat(
          groupId: groupId,
          targetId: targetId,
          displayName: displayName,
        );
        break;
    }
  }

  Future<void> _openWalletTransfer() async {
    final convId = _getConvID() ?? '';
    if (convId.isEmpty) return;
    final isGroup = _getConvType() == ConvType.group;

    final pinReady = await WalletPayPinGuard.ensureSet(context);
    if (!pinReady || !mounted) return;

    _dismissChatInput();
    var transferReceiverId = '';
    if (!isGroup) {
      final biz = await _resolveBusinessReceiverId(
        widget.selectedConversation.userID,
      );
      if (biz == null) return;
      transferReceiverId = biz;
    }
    final ret = await _pushWalletPayRoute<bool>(
      WalletTransferScreen(
        conversationId: convId,
        receiverId: transferReceiverId,
        name: isGroup
            ? ''
            : (widget.selectedConversation.showName ?? _getTitle()),
        avatar: isGroup ? null : widget.selectedConversation.faceUrl,
        isGroup: isGroup,
      ),
    );

    if (ret == true) {
      await _retryWalletCardsForConversation();
    }
  }

  void _onWalletChatCard() {
    final data = WalletOrderEvents.chatCardPayload.value;
    if (data == null || data.isEmpty) return;

    // 按订单目标会话发送，不再要求当前前台仍停在同一聊天页。
    unawaited(
      _sendWalletCardWithStatus(data, source: WalletCardSendSource.payment),
    );
  }

  void _onWalletChatCardSendFailed() {
    final data = WalletOrderEvents.chatCardSendFailedPayload.value;
    if (data == null || data.isEmpty) return;
    if (data['manualRequired'] != true) return;
    if (!mounted) return;
    if (!WalletOrderEvents.claimChatCardFailNotice(data)) return;

    final retryCount = data['retryCount']?.toString() ?? '';
    final tip = retryCount.isEmpty
        ? AppI18n.of(context).t(
            zhHans: '钱包消息发送失败，可重新发送',
            zhHant: '錢包訊息傳送失敗，可重新傳送',
            en: 'Wallet message failed to send. Tap to resend.',
            ja: 'ウォレットメッセージの送信に失敗しました。再送信できます。',
            ko: '지갑 메시지 전송 실패. 다시 보낼 수 있습니다.',
          )
        : AppI18n.of(context).format(
            zhHans: '钱包消息发送失败，已重试{option1}次',
            zhHant: '錢包訊息傳送失敗，已重試{option1}次',
            en: 'Wallet message failed after {option1} retries',
            ja: 'ウォレットメッセージの送信に失敗（{option1}回再試行）',
            ko: '지갑 메시지 전송 실패 ({option1}회 재시도)',
            vars: {'option1': retryCount.toString()},
          );

    AppDialog.showNotice(
      title: AppI18n.of(context).t(
        zhHans: '钱包消息',
        zhHant: '錢包訊息',
        en: 'Wallet message',
        ja: 'ウォレットメッセージ',
        ko: '지갑 메시지',
      ),
      message: tip,
      actionText: AppI18n.of(context).t(
        zhHans: '重新发送',
        zhHant: '重新傳送',
        en: 'Resend',
        ja: '再送信',
        ko: '다시 보내기',
      ),
      duration: const Duration(seconds: 6),
      onTap: () => _retryManualWalletCard(data),
    );
  }

  Future<void> _retryManualWalletCard(Map<String, dynamic> data) async {
    final payload = await _walletCardSendSvc.resetForManualSend(data);
    if (payload == null) return;
    await _sendWalletCardWithStatus(payload,
        source: WalletCardSendSource.manual);
  }

  Future<void> _retryWalletCardsForConversation({
    WalletCardSendSource source = WalletCardSendSource.payment,
  }) async {
    final convId = _getConvID() ?? '';
    if (convId.isEmpty || !_walletOutbound.beginRetry(convId)) return;

    try {
      final dispatched = WalletCardDispatchService.instance.takeForConversation(
        convId,
        limit: 5,
      );
      for (var i = 0; i < dispatched.length; i++) {
        if (!mounted) {
          for (var j = i; j < dispatched.length; j++) {
            WalletCardDispatchService.instance.enqueue(dispatched[j]);
          }
          return;
        }
        await _sendWalletCardWithStatus(
          dispatched[i],
          source: _walletCardSendSourceOf(dispatched[i], fallback: source),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (source == WalletCardSendSource.autoRetry) {
        return;
      }

      final payloads = await _walletCardSendSvc.retryPayloadsForConversation(
        convId,
        limit: 5,
      );
      for (final payload in payloads) {
        if (!mounted) return;
        await _sendWalletCardWithStatus(payload, source: source);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _walletOutbound.endRetry(convId);
    }
  }

  @Deprecated(
    'Use ChatHistoryRecoveryCoordinator.schedulePostOpenRetry instead',
  )
  void _retryLoadedFailedChatMessages() {
    final convId = _resolvedConversationID();
    final convKey = _conversationRecoveryKey();
    if (convId.isEmpty || convKey.isEmpty) return;
    ChatHistoryRecoveryCoordinator.instance.schedulePostOpenRetry(
      conversationKey: convKey,
      conversationID: convId,
      conversationType: _getConvType(),
      retry: ImRecoveryService.instance.afterChatOpened,
    );
  }

  Future<void> _sendWalletCardWithStatus(
    Map<String, dynamic> data, {
    WalletCardSendSource source = WalletCardSendSource.payment,
  }) async {
    final mark = _walletCardMark(data);
    if (mark.isEmpty) {
      debugPrint('wallet-card skip empty-mark source=${source.name}');
      return;
    }
    final payloadConvId = data['conversationId']?.toString().trim() ?? '';
    final convId =
        payloadConvId.isNotEmpty ? payloadConvId : (_getConvID() ?? '');
    if (convId.isEmpty) {
      debugPrint('wallet-card skip empty-target-conv source=${source.name}');
      WalletCardDispatchService.instance.enqueue(data);
      return;
    }
    final orderId = data['orderId']?.toString() ?? '';
    final clientOrderId = data['clientOrderId']?.toString() ?? '';
    final allowed = await WalletCardReplayGuard.instance.allowSend(
      orderId: orderId,
      clientOrderId: clientOrderId,
      source: source,
    );
    if (!allowed) {
      debugPrint(
        'wallet-card skip replay-guard clientOrderId=$clientOrderId '
        'source=${source.name}',
      );
      WalletCardDispatchService.instance.removeMatching(data);
      if (await WalletCardReplayGuard.instance.alreadySent(
        orderId: orderId,
        clientOrderId: clientOrderId,
      )) {
        await _walletCardSendSvc.markSent(data);
      }
      return;
    }
    final sentMarks = _walletOutbound.sentMarksFor(convId);
    if (sentMarks.contains(mark)) {
      debugPrint('wallet-card skip sent-mark clientOrderId=$clientOrderId');
      return;
    }
    final sendingMarks = _walletOutbound.sendingMarksFor(convId);
    if (!sendingMarks.add(mark)) {
      debugPrint('wallet-card skip sending-mark clientOrderId=$clientOrderId');
      WalletCardDispatchService.instance.enqueue(data);
      return;
    }
    if (!WalletCardReplayGuard.instance.tryBeginSend(
      orderId: orderId,
      clientOrderId: clientOrderId,
    )) {
      debugPrint('wallet-card skip inflight clientOrderId=$clientOrderId');
      sendingMarks.remove(mark);
      WalletCardDispatchService.instance.enqueue(data);
      return;
    }

    try {
      final canSend = await _walletCardSendSvc.markSending(
        data,
        requireCanRetry: source != WalletCardSendSource.payment,
      );
      if (!canSend) {
        debugPrint(
          'wallet-card skip markSending clientOrderId=$clientOrderId '
          'source=${source.name}',
        );
        WalletCardDispatchService.instance.enqueue(data);
        return;
      }

      final outcome = await _sendWalletCustomMessage(data);
      if (outcome.delivered) {
        sentMarks.add(mark);
        WalletCardDispatchService.instance.removeMatching(data);
        await WalletCardReplayGuard.instance.rememberImSent(
          orderId: orderId,
          clientOrderId: clientOrderId,
        );
        await _walletCardSendSvc.markSent(data);
        if (outcome.reject == WalletCardImReject.duplicate && mounted) {
          ToastUtils.toast(
            AppI18n.of(context).t(
              zhHans: '该红包/转账卡片已发送过',
              zhHant: '該紅包/轉帳卡片已發送過',
              en: 'This wallet card was already sent.',
              ja: 'このウォレットカードは送信済みです。',
              ko: '이 지갑 카드는 이미 전송되었습니다.',
            ),
          );
        }
      } else if (outcome.reject == WalletCardImReject.invalid) {
        sentMarks.add(mark);
        WalletCardDispatchService.instance.removeMatching(data);
        await _walletCardSendSvc.ignoreCardFail(clientOrderId);
        if (mounted) {
          ToastUtils.toast(
            AppI18n.of(context).t(
              zhHans: '无效钱包消息',
              zhHant: '無效錢包訊息',
              en: 'Invalid wallet message',
              ja: '無効なウォレットメッセージ',
              ko: '유효하지 않은 지갑 메시지',
            ),
          );
        }
      } else {
        sentMarks.remove(mark);
        final failed = await _walletCardSendSvc.markFailed(data);
        WalletOrderEvents.notifyChatCardSendFailed(
          failed.toPayload(),
          source: source.name,
        );
      }
    } finally {
      sendingMarks.remove(mark);
      WalletCardReplayGuard.instance.endSend(
        orderId: orderId,
        clientOrderId: clientOrderId,
      );
    }
  }

  String _walletCardMark(Map<String, dynamic> data) {
    final clientOrderId = data['clientOrderId']?.toString() ?? '';
    final orderId = data['orderId']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    final raw = '${clientOrderId}_${orderId}_$type';
    return raw.replaceAll(RegExp(r'_+$'), '');
  }

  WalletCardSendSource _walletCardSendSourceOf(
    Map<String, dynamic> data, {
    required WalletCardSendSource fallback,
  }) {
    switch (data['sendSource']?.toString()) {
      case 'payment':
        return WalletCardSendSource.payment;
      case 'manual':
        return WalletCardSendSource.manual;
      case 'recovery':
        return WalletCardSendSource.recovery;
      case 'autoRetry':
        return WalletCardSendSource.autoRetry;
      default:
        return fallback;
    }
  }

  Future<WalletCardImSendOutcome> _sendWalletCustomMessage(
    Map<String, dynamic> payload,
  ) async {
    final target = WalletCardImPayload.resolveTarget(payload);
    if (!target.isValid) {
      return const WalletCardImSendOutcome.failed();
    }

    final convId = target.isGroup ? target.groupId : target.receiverUserId;
    if (target.receiverUserId.isNotEmpty) {
      C2cFriendMessageGuard.trustCanSendHint(
        target.receiverUserId,
        source: 'wallet_card_outbound',
      );
    }

    try {
      final data = WalletCardImPayload.buildCustomData(
        payload,
        conversationId: convId,
      );

      final created = await sdkInstance.getMessageManager().createCustomMessage(
            data: jsonEncode(data),
          );
      final msg = created.data?.messageInfo;
      if (created.code != 0 || msg == null) {
        return WalletCardSendFailure.outcomeOf(
          code: created.code,
          desc: created.desc,
        );
      }

      final ok = await ChatExternalMessageSender.sendCreatedMessage(
        messageInfo: msg,
        receiverUserId: target.receiverUserId,
        groupId: target.groupId,
        reason: 'wallet_message_sent',
      );
      if (!ok) {
        debugPrint(
          'send wallet custom message failed: peer=${target.receiverUserId} '
          'group=${target.groupId}',
        );
        return const WalletCardImSendOutcome.failed();
      }
      ConversationRefreshBus.instance.requestRefresh(
        reason: 'wallet_message_sent',
      );
      return const WalletCardImSendOutcome.success();
    } catch (e) {
      debugPrint('send wallet custom message failed: $e');
      return WalletCardSendFailure.outcomeOf(desc: e.toString());
    }
  }

  List<MorePanelItem> _buildFavoriteMorePanelItems(TUITheme theme) {
    if (PlatformOfficialAccountService.isPlatformOfficialAccount(
      widget.selectedConversation.userID,
    )) {
      return [];
    }
    if (kIsWeb) {
      return [];
    }
    return [
      MorePanelItem(
        id: 'chat_favorites',
        title: AppI18n.of(context).t(
          zhHans: '收藏',
          zhHant: '收藏',
          en: 'Favorites',
          ja: 'お気に入り',
          ko: '즐겨찾기',
        ),
        icon: MorePanelStyles.pngIcon(theme, 'assets/chat_more/favorites.png'),
        onTap: (_) => _openFavoritePicker(),
      ),
    ];
  }

  void _openFavoritePicker() {
    final convId = _getConvID() ?? '';
    if (convId.isEmpty) {
      return;
    }
    FavoritePickerSheet.show(
      context,
      chatController: _chatController,
      convId: convId,
      convType: _getConvType(),
    );
  }

  String? _favoriteSourceSenderName(V2TimMessage message) {
    if (message.isSelf == true) {
      return AppI18n.of(
        context,
      ).t(zhHans: '我', zhHant: '我', en: 'Me', ja: '自分', ko: '나');
    }
    final name = _messageDisplayName(message).trim();
    if (name.isNotEmpty) {
      return name;
    }
    return message.sender?.trim();
  }

  String _messageDisplayName(V2TimMessage message) {
    if (_getConvType() == ConvType.group) {
      final userID = (message.sender ?? message.userID ?? '').trim();
      if (userID.isNotEmpty) {
        final groupId = widget.selectedConversation.groupID?.trim() ?? '';
        final liveMember = groupId.isEmpty
            ? null
            : GroupMemberStore.instance.memberOf(groupId, userID);
        final member = _findGroupMemberByUserId(userID);
        return UserDisplayProfile.name(
          userId: userID,
          nameCard:
              member?.nameCard ?? liveMember?.nameCard ?? message.nameCard,
          imRemark: member?.friendRemark ??
              liveMember?.friendRemark ??
              message.friendRemark,
          imNickName:
              liveMember?.nickName ?? member?.nickName ?? message.nickName,
        );
      }
    }
    if (_getConvType() == ConvType.c2c && message.isSelf != true) {
      return UserDisplayProfile.name(
        userId: widget.selectedConversation.userID ?? '',
        conversationShowName: _conversation.showName,
      );
    }
    if (message.isSelf == true) {
      final selfId =
          serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ??
              '';
      return UserDisplayProfile.name(
        userId: selfId,
        imNickName: serviceLocator<TUISelfInfoViewModel>().loginInfo?.nickName,
        fallbackName: MessageUtils.getDisplayName(message),
      );
    }
    return MessageUtils.getDisplayName(message);
  }

  String? _favoriteSourceConvLabel() {
    final name = widget.selectedConversation.showName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return _getTitle();
  }

  List<MorePanelItem> _buildContactCardMorePanelItems(TUITheme theme) {
    if (PlatformOfficialAccountService.isPlatformOfficialAccount(
      widget.selectedConversation.userID,
    )) {
      return [];
    }
    return [
      MorePanelItem(
        id: 'contact_card',
        title: AppI18n.of(context).t(
          zhHans: '个人名片',
          zhHant: '個人名片',
          en: 'Contact Card',
          ja: '名刺',
          ko: '연락처 카드',
        ),
        onTap: (context) => _pickAndSendContactCard(context),
        icon: MorePanelStyles.svgIcon(
          theme,
          'images/card.svg',
          package: 'tencent_cloud_chat_uikit',
        ),
      ),
    ];
  }

  Future<bool> _showSendContactCardConfirm(ContactCardMessage card) async {
    if (!mounted) {
      return false;
    }
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final targetName =
        card.nickName.trim().isNotEmpty ? card.nickName.trim() : card.userID;
    final rawConvName = (_favoriteSourceConvLabel() ?? '').trim();
    final convName = rawConvName.isNotEmpty ? rawConvName : _getTitle();
    final cardFaceUrl = UserAvatarHelper.pickBest(imFaceUrl: card.faceUrl);
    final convFaceUrl = PlatformOfficialAccountService.resolveFaceUrl(
      userId: widget.selectedConversation.userID,
      conversationFaceUrl: widget.selectedConversation.faceUrl,
    );
    final isDark =
        (theme.weakBackgroundColor ?? Colors.white).computeLuminance() < 0.5;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark ? Colors.white60 : const Color(0xFF999999);
    final cardColor = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final cancelBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F1F5);
    final primary = theme.primaryColor ?? const Color(0xFF2196F3);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final mq = MediaQuery.of(dialogContext);
        final screenWidth = mq.size.width;
        final screenHeight = mq.size.height;
        final horizontalInset = (screenWidth * 0.1).clamp(20.0, 48.0);
        final maxWidth = (screenWidth - horizontalInset * 2).clamp(
          260.0,
          300.0,
        );
        const contentPadding = EdgeInsets.fromLTRB(16, 16, 16, 14);
        final avatarSize = ((maxWidth - 56) / 2).clamp(36.0, 46.0);
        final arrowSize = (avatarSize * 0.5).clamp(18.0, 24.0);
        final avatarGap = (maxWidth * 0.04).clamp(6.0, 12.0);
        const buttonHeight = 38.0;
        const buttonGap = 10.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: screenHeight * 0.85,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  padding: contentPadding,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        i18n.t(
                          zhHans: '发送名片',
                          zhHant: '傳送名片',
                          en: 'Send Contact Card',
                          ja: '名刺を送信',
                          ko: '명함 보내기',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        i18n.t(
                          zhHans: '推荐$targetName给$convName',
                          zhHant: '推薦$targetName給$convName',
                          en: 'Recommend $targetName to $convName',
                          ja: '$targetNameを$convNameにおすすめします',
                          ko: '$targetName님을 $convName에게 추천',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppUserAvatar(
                              faceUrl: cardFaceUrl,
                              showName: targetName,
                              size: avatarSize,
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: avatarGap,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: arrowSize,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            AppUserAvatar(
                              faceUrl: convFaceUrl,
                              showName: convName,
                              size: avatarSize,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: buttonHeight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: cancelBg,
                                  foregroundColor: titleColor,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: Text(
                                  i18n.t(
                                    zhHans: '取消',
                                    zhHant: '取消',
                                    en: 'Cancel',
                                    ja: 'キャンセル',
                                    ko: '취소',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: buttonGap),
                          Expanded(
                            child: SizedBox(
                              height: buttonHeight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: Text(
                                  i18n.t(
                                    zhHans: '确定',
                                    zhHant: '確定',
                                    en: 'OK',
                                    ja: '確認',
                                    ko: '확인',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Future<void> _pickAndSendContactCard(BuildContext context) async {
    final convType = _getConvType();
    final receiverUserId =
        convType == ConvType.c2c ? (_c2cPeerUserId()?.trim() ?? '') : '';
    final groupId = convType == ConvType.group
        ? ChatIdFormat.canonicalGroupStorageId(
            (widget.selectedConversation.groupID?.trim().isNotEmpty ?? false)
                ? widget.selectedConversation.groupID
                : _getConvID(),
          )
        : '';
    if (receiverUserId.isEmpty && groupId.isEmpty) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '发送失败，请稍后重试',
          zhHant: '傳送失敗，請稍後重試',
          en: 'Send failed. Please try again later.',
          ja: '送信に失敗しました。しばらくしてから再試行してください。',
          ko: '전송 실패. 잠시 후 다시 시도해 주세요.',
        ),
      );
      return;
    }

    final globalModel = serviceLocator<TUIChatGlobalModel>();
    globalModel.beginMediaPickerOverlay();
    try {
      final pickedUserId = await pickContactCardUser(context);
      if (pickedUserId == null || pickedUserId.trim().isEmpty) {
        return;
      }

      final card = await buildContactCardMessageForUser(pickedUserId.trim());
      final confirmed = await _showSendContactCardConfirm(card);
      if (!confirmed) {
        return;
      }
      final messageData = jsonEncode(card.toJson());
      final created = await sdkInstance.getMessageManager().createCustomMessage(
            data: messageData,
          );
      final msg = created.data?.messageInfo;
      if (created.code != 0 || msg == null) {
        if (mounted) {
          ToastUtils.toast(
            AppI18n.of(context).t(
              zhHans: '发送失败，请稍后重试',
              zhHant: '傳送失敗，請稍後重試',
              en: 'Send failed. Please try again later.',
              ja: '送信に失敗しました。しばらくしてから再試行してください。',
              ko: '전송 실패. 잠시 후 다시 시도해 주세요.',
            ),
          );
        }
        return;
      }
      // 按打开名片入口时捕获的会话发送，离开当前页也不改目标。
      final sent = await ChatExternalMessageSender.sendCreatedMessage(
        messageInfo: msg,
        receiverUserId: receiverUserId,
        groupId: groupId,
        reason: 'contact_card_sent',
      );
      if (!mounted) {
        return;
      }
      ToastUtils.toast(
        sent
            ? AppI18n.of(context).t(
                zhHans: '名片已发送',
                zhHant: '名片已傳送',
                en: 'Contact card sent',
                ja: '名刺を送信しました',
                ko: '연락처 카드 전송됨',
              )
            : AppI18n.of(context).t(
                zhHans: '发送失败，请稍后重试',
                zhHant: '傳送失敗，請稍後重試',
                en: 'Send failed. Please try again later.',
                ja: '送信に失敗しました。しばらくしてから再試行してください。',
                ko: '전송 실패. 잠시 후 다시 시도해 주세요.',
              ),
      );
    } catch (_) {
      if (mounted) {
        ToastUtils.toast(
          AppI18n.of(context).t(
            zhHans: '发送失败，请稍后重试',
            zhHant: '傳送失敗，請稍後重試',
            en: 'Send failed. Please try again later.',
            ja: '送信に失敗しました。しばらくしてから再試行してください。',
            ko: '전송 실패. 잠시 후 다시 시도해 주세요.',
          ),
        );
      }
    } finally {
      globalModel.endMediaPickerOverlay();
    }
  }

  void _resetWalletCardState() {
    final convId = _getConvID() ?? '';
    if (convId.isEmpty) return;
    _walletOutbound.resetForConversation(convId);
  }

  String _messageItemBuilderCacheKey() {
    return _resolvedConversationID().isNotEmpty
        ? _resolvedConversationID()
        : widget.selectedConversation.conversationID;
  }

  void _ensureMessageItemBuilder() {
    final key = _messageItemBuilderCacheKey();
    if (_messageItemBuilder != null && _messageItemBuilderConvKey == key) {
      return;
    }
    _messageItemBuilderConvKey = key;
    _messageItemBuilder = MessageItemBuilder(
      faceMessageItemBuilder: (message, isShowJump, clearJump) {
        final data = message.faceElem?.data ?? '';
        if (data.trim().isEmpty) {
          return null;
        }
        final diceValue = DiceConstants.parseValue(data);
        if (diceValue != null) {
          final localId = message.id?.toString().trim() ?? '';
          final msgId = message.msgID?.trim() ?? '';
          // Widget key 必须优先钉死本地 id：发送成功补上 msgID 时不能拆掉 State，否则 webp 会被重建切掉。
          Key? diceKey;
          if (localId.isNotEmpty) {
            diceKey = ValueKey<String>('dice_local_$localId');
          } else if (msgId.isNotEmpty) {
            diceKey = ValueKey<String>('dice_msg_$msgId');
          }
          return DiceFaceBubble(
            key: diceKey,
            value: diceValue,
            playKey: DicePlayStore.playKeyForMessage(
              msgID: message.msgID,
              localId: message.id,
            ),
          );
        }
        // 仅 99chat 动态表情走自定义气泡；内置 yz/ys/gcs/tcc 等交给 TIMUIKitFaceElem。
        if (!StickerRepository.instance.isDynamicFaceData(data)) {
          return null;
        }
        return StickerFaceBubble(data: data);
      },
      textMessageItemBuilder: (message, isShowJump, clearJump) {
        if (!PlatformOfficialAccountService.isPlatformOfficialAccount(
          widget.selectedConversation.userID,
        )) {
          return null;
        }
        return tryBuildOfficialAccountMessageItem(
          message,
          isShowJump: isShowJump,
        );
      },
      messageRowBuilder: (
        message,
        messageWidget,
        onScrollToIndex,
        isNeedShowJumpStatus,
        clearJumpStatus,
        onScrollToIndexBegin,
      ) {
        // 通话中间态：气泡层会 shrink，但默认行仍带 bottom:20；整行直接收掉，避免大块空白。
        if (CallingMessageDataProvider.looksLikeCallMessage(message) &&
            !_shouldDisplayCallMessageInHistory(message)) {
          return const SizedBox.shrink();
        }
        if (MessageUtils.isGroupCallingMessage(message)) {
          return messageWidget;
        }
        if (MessageUtils.getCustomGroupCreatedOrDismissedString(
          message,
        ).isNotEmpty) {
          return messageWidget;
        }
        if (isGroupTipCustomMessage(message)) {
          return messageWidget;
        }
        if (getFriendBecameFriendsDisplayText(
          message.customElem,
        ).isNotEmpty) {
          return messageWidget;
        }
        if (isRedPacketClaimNoticeMessage(message)) {
          return messageWidget;
        }
        return null;
      },
      customMessageItemBuilder: (message, isShowJump, clearJump) {
        final isWallet = CustomMessageElem.isWalletCardMessage(message);
        return CustomMessageElem(
          key: isWallet
              ? ValueKey(CustomMessageElem.walletMessageWidgetKey(message))
              : null,
          message: message,
          isShowJump: isShowJump,
          clearJump: clearJump,
          chatController: _chatController,
        );
      },
      renderingDirectionCallback: (message) {
        final isCallOutgoing = CustomMessageElem.isC2CCallOutgoing(message);
        if (isCallOutgoing != null) {
          V2TimUserFullInfo? userFullInfo;
          if (isCallOutgoing) {
            userFullInfo = TIMUIKitCore.getInstance().loginUserInfo;
          } else {
            final peerId = widget.selectedConversation.userID;
            final peerFace = _c2cCallPeerFaceUrl(peerId);
            userFullInfo = V2TimUserFullInfo(
              userID: peerId,
              faceUrl: peerFace,
              nickName: widget.selectedConversation.showName,
            );
          }

          return RenderingDirectionResult(
            isSelf: isCallOutgoing,
            userInfo: userFullInfo,
          );
        }
        return null;
      },
    );
  }

  /// C2C 通话左侧头像：永远会话对端，不用 IM 发送者 faceUrl。
  String _c2cCallPeerFaceUrl(String? peerUserId) {
    final peerId = peerUserId?.trim() ?? '';
    if (peerId.isNotEmpty &&
        _resolvedPeerFaceUrlForId == peerId &&
        (_resolvedPeerFaceUrl?.trim().isNotEmpty ?? false)) {
      return _resolvedPeerFaceUrl!;
    }
    final conversationFace =
        widget.selectedConversation.faceUrl ?? _conversation.faceUrl;
    return UserDisplayProfile.avatar(
      userId: peerId,
      fallbackIm: conversationFace,
    );
  }

  Widget _buildMessageAvatar(V2TimMessage message) {
    final avatarKey = ValueKey<String>(
      'msg_avatar_${message.msgID ?? message.id ?? message.timestamp}',
    );
    // C2C 通话：左右跟 provider.direction；左侧头像永远 peer，禁用 message.faceUrl。
    final callOutgoing = CustomMessageElem.isC2CCallOutgoing(message);
    if (callOutgoing == true) {
      return AppUserAvatar(
        key: avatarKey,
        faceUrl: UserDisplayProfile.avatar(
          userId:
              serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID ?? '',
          fallbackIm: UserAvatarHelper.currentSelfFaceUrl(),
          isSelf: true,
        ),
        showName: _messageDisplayName(message),
        size: 40,
      );
    }
    if (callOutgoing == false) {
      final peerUserId = widget.selectedConversation.userID;
      return AppUserAvatar(
        key: avatarKey,
        faceUrl: _c2cCallPeerFaceUrl(peerUserId),
        showName: _messageDisplayName(message),
        size: 40,
      );
    }
    if (_getConvType() == ConvType.group) {
      final sender = (message.sender ?? message.userID ?? '').trim();
      final groupId = widget.selectedConversation.groupID?.trim() ?? '';
      // 每个头像只监听 groupID + sender 对应的 revision；成员分页回填时，
      // 仅真实变化的用户头像重建，不广播刷新群内全部可见头像。
      return AnimatedBuilder(
        key: avatarKey,
        animation: GroupMemberStore.instance.avatarListenable(groupId, sender),
        builder: (context, _) {
          final storeMember = groupId.isNotEmpty && sender.isNotEmpty
              ? GroupMemberStore.instance.memberOf(groupId, sender)
              : null;
          final member = sender.isNotEmpty
              ? GroupAtMention.resolveMember(
                  _chatController.getGroupMemberList(),
                  sender,
                )
              : null;
          final faceCandidate = <String?>[
            storeMember?.faceUrl,
            member?.faceUrl,
            message.faceUrl,
          ].firstWhere(
            (e) => (e?.trim().isNotEmpty ?? false),
            orElse: () => message.faceUrl,
          );
          final isSelf = message.isSelf == true;
          final faceUrl = UserDisplayProfile.avatar(
            userId: sender,
            fallbackIm: faceCandidate,
            isSelf: isSelf,
          );
          ChatJitterDiag.logAvatar(
            sender: sender,
            faceUrl: faceUrl,
            source: 'buildMessageAvatar',
            cacheKey: '$groupId|$sender',
          );
          return AppUserAvatar(
            faceUrl: faceUrl,
            showName: _messageDisplayName(message),
            size: 40,
          );
        },
      );
    }
    final peerUserId = widget.selectedConversation.userID;
    final livePeerReady = _resolvedPeerFaceUrl?.trim().isNotEmpty == true &&
        _resolvedPeerFaceUrlForId == peerUserId?.trim();
    final localPeerFace =
        UserAvatarHelper.usableAvatarOrEmpty(_peerLocalProfile?.avatarUrl);
    final faceUrl =
        PlatformOfficialAccountService.isPlatformOfficialAccount(peerUserId)
            ? PlatformOfficialAccountService.resolveFaceUrl(
                userId: peerUserId,
                conversationFaceUrl: message.faceUrl,
              )
            : UserDisplayProfile.avatar(
                userId: peerUserId ?? '',
                fallbackIm: livePeerReady
                    ? _resolvedPeerFaceUrl
                    : (localPeerFace.isNotEmpty
                        ? localPeerFace
                        : message.faceUrl),
              );
    return AppUserAvatar(
      key: avatarKey,
      faceUrl: faceUrl,
      showName: _messageDisplayName(message),
      size: 40,
    );
  }

  String? _headerConversationFaceUrl() {
    if (_getConvType() == ConvType.c2c) {
      final peerId = widget.selectedConversation.userID?.trim() ?? '';
      if (peerId.isNotEmpty &&
          _resolvedPeerFaceUrlForId == peerId &&
          (_resolvedPeerFaceUrl?.trim().isNotEmpty ?? false)) {
        return _resolvedPeerFaceUrl;
      }
      final localFace =
          UserAvatarHelper.usableAvatarOrEmpty(_peerLocalProfile?.avatarUrl);
      if (localFace.isNotEmpty) {
        return localFace;
      }
      return _conversation.faceUrl;
    }
    if (_getConvType() == ConvType.group) {
      return ConversationFaceUrl.resolve(
        userId: _conversation.userID,
        conversationFaceUrl: _conversation.faceUrl,
        isGroup: true,
        groupList: serviceLocator<TUIFriendShipViewModel>().groupList,
        groupId: _conversation.groupID,
      );
    }
    return _conversation.faceUrl;
  }

  void _syncChatHeaderState({bool notify = true}) {
    _headerState.setSnapshot(
      conversationFaceUrl: _headerConversationFaceUrl(),
      titleText: _getHeaderTitleText(),
      notify: notify,
    );
  }

  void _syncChatTopFixState({bool notify = true}) {
    final session =
        _groupLiveState.hasActiveSlot ? _groupLiveState.activeSession : null;
    if (session == null || !session.status.isActiveSlot) {
      _watchingGroupLive = false;
    }
    _topFixState.setSnapshot(
      noticeText:
          _getConvType() == ConvType.group ? _groupSide.groupNoticeBanner : '',
      showGroupGameBanner: _shouldShowGroupGameBanner(),
      doorCount: _groupSide.sangongDoorCount ?? 6,
      roundStatus: _groupSide.groupGameRoundStatus,
      groupLiveSession: session,
      watchingGroupLive: _watchingGroupLive,
      notify: notify,
    );
  }

  void _applyConversationRemarkUpdate(String newRemark) {
    conversationName = newRemark;
    backRemark = newRemark;
    _syncChatHeaderState();
  }

  Future<void> _loadPeerFaceUrl() async {
    if (_getConvType() != ConvType.c2c) {
      return;
    }
    final peerId = widget.selectedConversation.userID?.trim() ?? '';
    if (peerId.isEmpty ||
        PlatformOfficialAccountService.isPlatformOfficialAccount(peerId)) {
      return;
    }
    final resolved = await UserAvatarHelper.resolveChatPeerFaceUrl(
      peerUserId: peerId,
      conversationFaceUrl: _conversation.faceUrl,
      preferLiveProfile: true,
    );
    if (!mounted) {
      return;
    }
    if (_getConvType() != ConvType.c2c ||
        widget.selectedConversation.userID?.trim() != peerId) {
      return;
    }
    if (_resolvedPeerFaceUrlForId == peerId &&
        _resolvedPeerFaceUrl == resolved) {
      return;
    }
    _resolvedPeerFaceUrl = resolved;
    _resolvedPeerFaceUrlForId = peerId;
    if (resolved.isNotEmpty) {
      _conversation.faceUrl = resolved;
      widget.selectedConversation.faceUrl = resolved;
      _cachedHeaderFaceUrl = resolved;
    }
    _syncChatHeaderState();
    _refreshPeerMessageAvatars(resolved);
  }

  Future<void> _loadPeerLocalProfile() async {
    if (_getConvType() != ConvType.c2c) {
      return;
    }
    final peerId = widget.selectedConversation.userID?.trim() ?? '';
    if (peerId.isEmpty) {
      return;
    }
    final record = await UserProfileLocalService.instance.read(peerId);
    if (!mounted) {
      return;
    }
    if (_getConvType() != ConvType.c2c ||
        widget.selectedConversation.userID?.trim() != peerId) {
      return;
    }
    final sameRecord = _peerLocalProfile?.userId == record?.userId &&
        _peerLocalProfile?.friendRemark == record?.friendRemark &&
        _peerLocalProfile?.nickname == record?.nickname &&
        _peerLocalProfile?.avatarUrl == record?.avatarUrl &&
        _peerLocalProfile?.updatedAt == record?.updatedAt;
    if (sameRecord) {
      return;
    }
    _peerLocalProfile = record;
    final localFace = UserAvatarHelper.usableAvatarOrEmpty(record?.avatarUrl);
    if (localFace.isNotEmpty) {
      _resolvedPeerFaceUrl = localFace;
      _resolvedPeerFaceUrlForId = peerId;
      _conversation.faceUrl = localFace;
      widget.selectedConversation.faceUrl = localFace;
      _refreshPeerMessageAvatars(localFace);
    }
    final localName = record == null
        ? ''
        : (record.friendRemark.trim().isNotEmpty
            ? record.friendRemark.trim()
            : record.nickname.trim());
    if (localName.isNotEmpty) {
      _conversation.showName = localName;
      widget.selectedConversation.showName = localName;
    }
    _syncChatHeaderState();
    setState(() {});
  }

  void _onPeerProfileRefresh() {
    if (_getConvType() == ConvType.c2c) {
      final peerId = widget.selectedConversation.userID?.trim() ?? '';
      if (peerId.isEmpty || !PeerProfileRefreshBus.instance.matches(peerId)) {
        return;
      }
      unawaited(_loadPeerFaceUrl());
      unawaited(_loadPeerLocalProfile());
      C2cFriendMessageGuard.invalidate(peerId);
      // 成友 trust 已在乐观入库时写入；同拍先解锁输入栏，再后台 forceNetwork 对账。
      if (C2cFriendMessageGuard.hasFreshTrustedCanSendHint(peerId) &&
          _c2cPermission.canMessage != true) {
        _c2cPermission.canMessage = true;
      }
      _schedulePeerMessagePermissionSync(
        forceNetwork: true,
        delay: const Duration(milliseconds: 220),
      );
      return;
    }
    if (_getConvType() == ConvType.group) {
      _refreshGroupAvatarsFromProfileBus();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onGroupMemberStoreChanged() {
    // 常规群头像走成员级 revision，不触发整表刷新。资料页发布的全局成员
    // 变更 groupID 为空，需重建一次昵称行；该路径低频且只发生在资料更新后。
    final change = GroupMemberStore.instance.lastChange;
    if (!mounted ||
        _getConvType() != ConvType.group ||
        change == null ||
        change.groupID.isNotEmpty) {
      return;
    }
    setState(() {});
  }

  Set<String> _applyGroupMemberAvatarsToMessagesBatch() {
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    final convKey = _getConvID()?.trim() ?? '';
    if (groupId.isEmpty || convKey.isEmpty) {
      return const <String>{};
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final messages = globalModel.messageListMap[convKey];
    if (messages == null || messages.isEmpty) {
      return const <String>{};
    }
    final changedSenderIDs = <String>{};
    for (final message in messages) {
      if (message.isSelf == true) {
        continue;
      }
      final sender = (message.sender ?? message.userID ?? '').trim();
      if (sender.isEmpty) {
        continue;
      }
      final member = GroupMemberStore.instance.memberOf(groupId, sender);
      final face = UserAvatarHelper.pickBest(imFaceUrl: member?.faceUrl);
      if (face.isEmpty) {
        continue;
      }
      if ((message.faceUrl ?? '').trim() == face) {
        continue;
      }
      // 就地补 faceUrl 快照供预览头/转发等消费；显示层的群头像走
      // GroupMemberStore 响应式重建，不再 setMessageList 触发整表刷新。
      message.faceUrl = face;
      changedSenderIDs.add(sender);
    }
    return changedSenderIDs;
  }

  void _refreshGroupAvatarsFromProfileBus() {
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    unawaited(_refreshGroupAvatarsFromProfileBusAsync(groupId));
  }

  Future<void> _refreshGroupAvatarsFromProfileBusAsync(String groupId) async {
    if (!mounted || _getConvType() != ConvType.group) {
      return;
    }
    if (widget.selectedConversation.groupID?.trim() != groupId) {
      return;
    }
    // 补漏：FriendSync 已 putFaceUrlForUser 时多为 no-op；若仅 bus 到达则从本地资料灌 store。
    for (final rawId in PeerProfileRefreshBus.instance.changedUserIds) {
      final uid = ChatIdFormat.rawUserUid(rawId);
      if (uid.isEmpty) {
        continue;
      }
      final storeMember = GroupMemberStore.instance.memberOf(groupId, uid) ??
          GroupMemberStore.instance.memberOf(groupId, rawId);
      if (storeMember == null) {
        continue;
      }
      final record = await UserProfileLocalService.instance.read(uid);
      if (!mounted || _getConvType() != ConvType.group) {
        return;
      }
      GroupMemberStore.instance.putProfileForUser(
        userID: uid,
        nickName: record?.nickname,
        faceUrl: record?.avatarUrl,
      );
      GroupMemberStore.instance.putFriendRemarkForUser(
        uid,
        record?.friendRemark ?? '',
      );
    }
    if (!mounted || _getConvType() != ConvType.group) {
      return;
    }
    // 补 faceUrl 快照后只通知真实发生变化的发送者头像。
    final changedSenderIDs = _applyGroupMemberAvatarsToMessagesBatch();
    GroupMemberStore.instance.notifyChatAvatarRefreshForUsers(
      groupId,
      changedSenderIDs,
    );
  }

  void _refreshPeerMessageAvatars(String resolvedFace) {
    final trimmed = resolvedFace.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final convKey = _getConvID();
    if (convKey == null || convKey.isEmpty) {
      return;
    }
    final messages =
        serviceLocator<TUIChatGlobalModel>().messageListMap[convKey];
    if (messages == null || messages.isEmpty) {
      return;
    }
    for (final message in messages) {
      if (message.isSelf == true) {
        continue;
      }
      if ((message.faceUrl ?? '').trim() == trimmed) {
        continue;
      }
      // 就地补 faceUrl 快照供预览头等消费；不再 setMessageList 触发整表重建。
      // C2C 头像本身走 _resolvedPeerFaceUrl + header controller，
      // 这里再刷一遍会造成头像闪动。
      message.faceUrl = trimmed;
    }
  }

  TIMUIKitChatConfig _buildTimUIKitChatConfig({
    required BuildContext context,
    required bool showReadingStatus,
    required StickerPanelConfig stickerPanelConfig,
  }) {
    final androidLightUi =
        AndroidPerformanceProfile.instance.reduceHeavyVisualEffects;
    return TIMUIKitChatConfig(
      stickerPanelConfig: stickerPanelConfig,
      onTapLink: PlatformUtils().isWeb
          ? (link) {
              LinkUtils.launchURL(
                context,
                'https://comm.qq.com/link_page/index.html?target=$link',
              );
            }
          : null,
      onTapChatIdMention: (id) {
        _dismissChatInput();
        GroupAtMentionTarget? groupMember;
        if (_getConvType() == ConvType.group) {
          groupMember = GroupAtMention.resolveInGroup(
            groupId: widget.selectedConversation.groupID ?? '',
            chatMembers: _chatController.getGroupMemberList(),
            mentionToken: id,
          );
        }
        ChatIdMentionNavigator.open(
          context,
          id,
          groupMemberUserId: groupMember?.userID,
          groupMemberNickname: groupMember?.displayName,
          groupMemberAvatarUrl: groupMember?.faceUrl,
          groupId: _getConvType() == ConvType.group
              ? widget.selectedConversation.groupID
              : null,
          directToChat: widget.directToChat,
        );
      },
      showC2cMessageEditStatus: true,
      isAllowClickAvatar: true,
      isMemberCanAtAll: false,
      isAtWhenReply: false,
      isAtWhenReplyDynamic: (V2TimMessage message) => false,
      isAllowLongPressMessage: true,
      // 群主/管理员可在长按菜单中撤回群成员消息。UIKit 会先校验当前
      // 成员角色，再通过消息变更同步撤回状态；普通成员仍只能撤回自己消息。
      isGroupAdminRecallEnabled: true,
      isShowReadingStatus: showReadingStatus &&
          !PlatformOfficialAccountService.isOfficialAccountUserId(
            widget.selectedConversation.userID,
          ),
      isAutoReportRead: true,
      isShowGroupReadingStatus: true,
      notificationTitle: IMDemoConfig.appName,
      offlinePushInfo: (message, convID, convType) => MessageOfflinePush.build(
        message: message,
        convID: convID,
        convType: convType,
      ),
      isSupportMarkdownForTextMessage: false,
      urlPreviewType: UrlPreviewType.onlyHyperlink,
      isUseMessageReaction: false,
      messageEnterAnimationStyle: MessageEnterAnimationStyle.wechat,
      messageEnterAnimationThrottleMs: androidLightUi ? 480 : 320,
      messageEnterAnimationListPushEnabled: !androidLightUi,
      inboundChunkRevealEnabled: true,
      // Android 更快揭示，减少队列积压导致的连续 rebuild。
      inboundChunkRevealIntervalMs: androidLightUi ? 60 : 160,
      inboundChunkRevealMaxChunk: androidLightUi ? 4 : 1,
      inboundScrollFollowEnabled: false,
      inboundScrollFollowMode: InboundScrollFollowMode.instant,
      inboundScrollFollowDurationMs: 240,
      sendFlyOverlayEnabled: false,
      keyboardInsetAnimationEnabled: false,
      skipMessageEnterAnimationForMessage: _skipChatMessageEnterAnimation,
      groupReadReceiptPermissionList: [
        GroupReceiptAllowType.work,
        GroupReceiptAllowType.meeting,
        GroupReceiptAllowType.public,
      ],
      faceReplyPreviewBuilder: (message) {
        final data = message.faceElem?.data ?? '';
        final diceValue = DiceConstants.parseValue(data);
        if (diceValue != null) {
          // 回复预览永远静帧（不传 playKey）。
          return DiceFaceBubble(value: diceValue, maxWidthFactor: 0.22);
        }
        if (!stickerFaceShouldUseCustomBubble(data)) {
          return null;
        }
        return StickerFaceBubble(data: data, maxWidthFactor: 0.22);
      },
      faceURIPrefix: (String path) {
        if (path.startsWith('http') ||
            path.startsWith(StickerConstants.stickerDataScheme)) {
          return '';
        }
        if (path.contains('assets/custom_face_resource/')) {
          return '';
        }
        var name = path;
        if (name.startsWith('[') && name.endsWith(']')) {
          name = name.substring(1, name.length - 1);
        }
        if (name.startsWith('TUIEmoji_')) {
          return 'assets/custom_face_resource/tcc1/';
        }
        int? dirNumber;
        if (path.contains('yz')) {
          dirNumber = 4350;
        }
        if (path.contains('ys')) {
          dirNumber = 4351;
        }
        if (path.contains('gcs')) {
          dirNumber = 4352;
        }
        if (dirNumber != null) {
          return 'assets/custom_face_resource/$dirNumber/';
        }
        return '';
      },
      faceURISuffix: (String path) {
        if (path.startsWith('http') ||
            path.startsWith(StickerConstants.stickerDataScheme)) {
          return '';
        }
        var name = path;
        if (name.startsWith('[') && name.endsWith(']')) {
          name = name.substring(1, name.length - 1);
        }
        if (name.startsWith('TUIEmoji_')) {
          return name.endsWith('.png') ? '' : '.png';
        }
        if (!path.contains('@2x.png')) {
          return '@2x.png';
        }
        return '';
      },
      // Web 端暂未接入可用 CallKit，不在输入栏功能区放音视频入口。
      additionalDesktopControlBarItems: const [],
      isUseDraft: false,
    );
  }

  ToolTipsConfig _buildToolTipsConfig(BuildContext context) {
    return ToolTipsConfig(
      showTranslation: false,
      additionalMessageToolTips: (message, closeTooltip) {
        final tips = <MessageToolTipItem>[];
        if (canFavoriteMessage(message)) {
          tips.add(
            MessageToolTipItem(
              label: '收藏',
              id: 'favorite_message',
              icon: Icons.bookmark_border_rounded,
              onClick: () async {
                closeTooltip();
                try {
                  final result = await addMessageToFavorites(
                    message,
                    sourceSenderName: _favoriteSourceSenderName(message),
                    sourceConvLabel: _favoriteSourceConvLabel(),
                    sourceConvId: _getConvID(),
                  );
                  switch (result.outcome) {
                    case FavoriteFromMessageOutcome.added:
                      ToastUtils.toast(
                        AppI18n.of(context).t(
                          zhHans: '已收藏',
                          zhHant: '已收藏',
                          en: 'Saved to favorites',
                          ja: 'お気に入りに追加しました',
                          ko: '즐겨찾기에 저장됨',
                        ),
                      );
                      break;
                    case FavoriteFromMessageOutcome.alreadyExists:
                      ToastUtils.toast(
                        AppI18n.of(context).t(
                          zhHans: '已在收藏中',
                          zhHant: '已在收藏中',
                          en: 'Already in favorites',
                          ja: 'すでにお気に入りにあります',
                          ko: '이미 즐겨찾기에 있음',
                        ),
                      );
                      break;
                    case FavoriteFromMessageOutcome.unsupported:
                      ToastUtils.toast(
                        AppI18n.of(context).t(
                          zhHans: '暂不支持收藏该消息',
                          zhHant: '暫不支援收藏該訊息',
                          en: 'This message cannot be favorited',
                          ja: 'このメッセージはお気に入りにできません',
                          ko: '이 메시지는 즐겨찾기할 수 없습니다',
                        ),
                      );
                      break;
                    case FavoriteFromMessageOutcome.failed:
                      final err = result.errorMessage?.trim() ?? '';
                      ToastUtils.toast(
                        err.isNotEmpty
                            ? err
                            : AppI18n.of(context).t(
                                zhHans: '收藏失败',
                                zhHant: '收藏失敗',
                                en: 'Failed to save',
                                ja: 'お気に入りに失敗しました',
                                ko: '즐겨찾기 실패',
                              ),
                      );
                      break;
                  }
                } catch (_) {
                  ToastUtils.toast(
                    AppI18n.of(context).t(
                      zhHans: '收藏失败',
                      zhHant: '收藏失敗',
                      en: 'Failed to save',
                      ja: 'お気に入りに失敗しました',
                      ko: '즐겨찾기 실패',
                    ),
                  );
                }
              },
            ),
          );
        }
        if (canAddMessageToStickers(message)) {
          tips.add(
            MessageToolTipItem(
              label: '表情',
              id: 'add_sticker',
              icon: Icons.emoji_emotions_outlined,
              onClick: () async {
                closeTooltip();
                try {
                  final outcome = await addMessageToStickers(message);
                  switch (outcome) {
                    case StickerAddFromMessageOutcome.added:
                      ToastUtils.toast(
                        AppI18n.of(context).t(
                          zhHans: '已添加到表情',
                          zhHant: '已新增到表情',
                          en: 'Added to stickers',
                          ja: 'スタンプに追加しました',
                          ko: '스티커에 추가됨',
                        ),
                      );
                      break;
                    case StickerAddFromMessageOutcome.alreadyExists:
                      ToastUtils.toast(
                        AppI18n.of(context).t(
                          zhHans: '已在表情中',
                          zhHant: '已在表情中',
                          en: 'Already in stickers',
                          ja: 'すでにスタンプにあります',
                          ko: '이미 스티커에 있음',
                        ),
                      );
                      break;
                    case StickerAddFromMessageOutcome.unsupported:
                      ToastUtils.toast(
                        AppI18n.of(context).t(
                          zhHans: '暂不支持添加该消息',
                          zhHant: '暫不支援新增該訊息',
                          en: 'Cannot add this message',
                          ja: 'このメッセージは追加できません',
                          ko: '이 메시지는 추가할 수 없습니다',
                        ),
                      );
                      break;
                    case StickerAddFromMessageOutcome.failed:
                      ToastUtils.toast(
                        AppI18n.of(context).t(
                          zhHans: '添加失败',
                          zhHant: '新增失敗',
                          en: 'Add failed',
                          ja: '追加に失敗しました',
                          ko: '추가 실패',
                        ),
                      );
                      break;
                  }
                } catch (_) {
                  ToastUtils.toast(
                    AppI18n.of(context).t(
                      zhHans: '添加失败',
                      zhHant: '新增失敗',
                      en: 'Add failed',
                      ja: '追加に失敗しました',
                      ko: '추가 실패',
                    ),
                  );
                }
              },
            ),
          );
        }
        if (_shouldShowSangongGameMessageMenu()) {
          tips.add(
            MessageToolTipItem(
              label: '统计',
              id: 'sangong_stats',
              icon: Icons.bar_chart_rounded,
              onClick: () {
                closeTooltip();
                unawaited(_onSangongGameStats(message));
              },
            ),
          );
          if (SangongBetSubmitCutoff.canExcludeMessage(message)) {
            tips.add(
              MessageToolTipItem(
                label: '不计入',
                id: 'sangong_exclude_bet',
                icon: Icons.block_rounded,
                onClick: () {
                  closeTooltip();
                  unawaited(_onSangongExcludeBet(message));
                },
              ),
            );
          }
          if (SangongQuickSetupBankerInput.canUseMessage(message)) {
            tips.add(
              MessageToolTipItem(
                label: '定庄',
                id: 'sangong_quick_setup_banker',
                icon: Icons.emoji_events_rounded,
                onClick: () {
                  closeTooltip();
                  unawaited(_onSangongQuickSetupBanker(message));
                },
              ),
            );
          }
        }
        return tips;
      },
    );
  }

  MorePanelConfig _buildMorePanelConfig(TUITheme theme) {
    final enableCall = _getConvType() == ConvType.c2c &&
        !PlatformOfficialAccountService.isPlatformOfficialAccount(
          widget.selectedConversation.userID,
        );
    final groupLiveItems = _buildGroupLiveMorePanelItems(theme);
    return MorePanelConfig(
      showVideoCall: enableCall,
      showVoiceCall: enableCall,
      extraAction: [
        ..._buildContactCardMorePanelItems(theme),
        ..._buildFavoriteMorePanelItems(theme),
        ..._buildWalletMorePanelItems(theme),
        // 群聊完整菜单中固定排在第 8 位（红包、转账之后）。
        ...groupLiveItems,
      ],
    );
  }

  List<MorePanelItem> _buildGroupLiveMorePanelItems(TUITheme theme) {
    if (_getConvType() != ConvType.group) {
      return const [];
    }
    return [
      MorePanelItem(
        id: 'group_live_schedule',
        title: AppI18n.of(context).t(
          zhHans: '群直播',
          zhHant: '群直播',
          en: 'Group Live',
          ja: 'グループ配信',
          ko: '그룹 라이브',
        ),
        icon: MorePanelStyles.pngIcon(theme, 'assets/chat_more/group_live.png'),
        onTap: (_) => unawaited(_openGroupLiveSchedule()),
      ),
    ];
  }

  Future<void> _openGroupLiveSchedule() async {
    _dismissChatInput();
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty || !mounted) {
      return;
    }
    await GroupLiveNavigator.openOwnerSchedule(context, groupId);
    if (!mounted) {
      return;
    }
    await _recoverChatHistoryAfterOverlayReturn(
      reason: 'return_from_group_live_settings',
    );
    unawaited(_loadGroupLiveCurrent());
  }

  void _seedGroupLiveFromIndex() {
    if (_getConvType() != ConvType.group) {
      _watchingGroupLive = false;
      _groupLiveState.seedFromIndex('');
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(
      widget.selectedConversation.groupID,
    );
    _groupLiveState.seedFromIndex(groupId);
  }

  void _startGroupLiveCurrentPoll() {
    _groupLiveCurrentPollTimer?.cancel();
    if (_getConvType() != ConvType.group) {
      return;
    }
    _groupLiveCurrentPollTimer = Timer.periodic(
      _groupLiveCurrentPollInterval,
      (_) {
        if (!mounted || _getConvType() != ConvType.group) {
          return;
        }
        unawaited(_loadGroupLiveCurrent());
      },
    );
  }

  void _stopGroupLiveCurrentPoll() {
    _groupLiveCurrentPollTimer?.cancel();
    _groupLiveCurrentPollTimer = null;
  }

  /// live-index 被 TCP / 列表侧 patch 后，同步当前群聊天顶栏（不等下次进页）。
  void _onGroupLiveIndexStoreChanged() {
    if (!mounted || _getConvType() != ConvType.group) {
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(
      widget.selectedConversation.groupID,
    );
    if (groupId.isEmpty) {
      return;
    }
    final item = GroupLiveIndexStore.instance.itemForGroup(groupId);
    final fingerprint = item == null
        ? ''
        : '${item.liveSessionId}|${item.status}|${item.version}';
    if (fingerprint == _groupLiveIndexFingerprint) {
      return;
    }
    _groupLiveIndexFingerprint = fingerprint;
    _groupLiveState.seedFromIndex(groupId, notify: true);
    // REST 校对 play-info / 权威 status（index 可能只有摘要）。
    unawaited(_loadGroupLiveCurrent());
  }

  Future<void> _loadGroupLiveCurrent() async {
    if (_getConvType() != ConvType.group) {
      _watchingGroupLive = false;
      _groupLiveState.clear();
      _syncChatTopFixState();
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(
      widget.selectedConversation.groupID,
    );
    if (groupId.isEmpty) {
      return;
    }
    await _groupLiveState.refresh(groupId);
    if (!mounted) {
      return;
    }
    _syncChatTopFixState();
    // Parent must rebuild so topFixWidget keeps a non-stale onTap closure.
    setState(() {});
  }

  void _onGroupLiveStateChanged() {
    if (!mounted) {
      return;
    }
    _syncChatTopFixState();
    setState(() {});
  }

  Future<void> _onGroupLiveBannerTap() async {
    final session = _groupLiveState.activeSession;
    if (session == null || !mounted) {
      return;
    }
    _dismissChatInput();
    // 有活跃场次即进入聊天顶栏直播画面（未推流也展示等待页）。
    if (_watchingGroupLive) {
      return;
    }
    setState(() => _watchingGroupLive = true);
    _syncChatTopFixState();
  }

  void _closeGroupLiveWatch() {
    if (!_watchingGroupLive) {
      return;
    }
    setState(() => _watchingGroupLive = false);
    _syncChatTopFixState();
  }

  void _handleGroupLiveIncomingMessage(V2TimMessage message) {
    if (_getConvType() != ConvType.group) {
      return;
    }
    final payload = parseGroupLivePayload(message);
    if (payload == null || !payload.isCard) {
      return;
    }
    _groupLiveState.applyImPayload(payload);
    unawaited(_loadGroupLiveCurrent());
  }

  ConvType _getConvType() {
    final id = widget.selectedConversation.conversationID.trim().toLowerCase();
    // 与腾讯云约定 / HistoryPeer 对齐：前缀硬覆盖误填 type。
    if (id.startsWith('c2c_')) {
      return ConvType.c2c;
    }
    if (id.startsWith('group_')) {
      return ConvType.group;
    }
    return widget.selectedConversation.type == 1
        ? ConvType.c2c
        : ConvType.group;
  }

  Future<void> _prepareOfficialAccountChat() async {
    if (!PlatformOfficialAccountService.isPlatformOfficialAccount(
      widget.selectedConversation.userID,
    )) {
      return;
    }
    await PlatformOfficialAccountService.ensureReadyForChat(
      userId: widget.selectedConversation.userID,
    );
    if (!mounted) {
      return;
    }
    final resolvedFace = PlatformOfficialAccountService.resolveFaceUrl(
      userId: widget.selectedConversation.userID,
      conversationFaceUrl: _conversation.faceUrl,
    );
    if (resolvedFace.isNotEmpty) {
      _conversation.faceUrl = resolvedFace;
      _cachedHeaderFaceUrl = resolvedFace;
      _syncChatHeaderState();
    }
    await _hydrateOfficialAccountMessageList();
  }

  Future<void> _hydrateOfficialAccountMessageList() async {
    final userId = widget.selectedConversation.userID;
    if (userId == null || userId.isEmpty) {
      return;
    }
    var messages =
        await PlatformOfficialAccountService.fetchChatHistoryMessages(
      userId: userId,
    );
    final last = widget.selectedConversation.lastMessage;
    if (messages.isEmpty && last != null) {
      messages = [last];
    }
    if (messages.isEmpty) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final existing = globalModel.messageListMap[userId];
    if (existing != null && existing.isNotEmpty) {
      _normalizeOfficialAccountMessageAvatars(userId, existing);
      _normalizeSelfMessageAvatars(existing);
      globalModel.setMessageList(
        userId,
        existing,
        needResetNewMessageCount: false,
      );
      return;
    }
    _normalizeOfficialAccountMessageAvatars(userId, messages);
    _normalizeSelfMessageAvatars(messages);
    globalModel.setMessageList(
      userId,
      messages,
      needResetNewMessageCount: false,
    );
    globalModel.setMessageListPosition(userId, HistoryMessagePosition.bottom);
  }

  bool _normalizeSelfMessageAvatars(List<V2TimMessage> messages) {
    final resolvedFace = UserAvatarHelper.currentSelfFaceUrl();
    if (resolvedFace.isEmpty) {
      return false;
    }
    var changed = false;
    for (final message in messages) {
      if (message.isSelf != true) {
        continue;
      }
      if ((message.faceUrl ?? '').trim() == resolvedFace) {
        continue;
      }
      message.faceUrl = resolvedFace;
      changed = true;
    }
    return changed;
  }

  void _seedCachedHistoryOnOpen(String convKey) {
    if (convKey.isEmpty) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    globalModel.setMessageListPosition(
      convKey,
      HistoryMessagePosition.bottom,
      notify: false,
    );

    final rawCount = globalModel.rawMessageCount(convKey);
    if (rawCount > 0) {
      final list = globalModel.getMessageList(convKey);
      if (list != null) {
        _normalizeSelfMessageAvatars(list);
      }
      if (globalModel.hasInitialHistoryLoaded(convKey)) {
        return;
      }
      if (rawCount >= HistoryMessageDartConstant.initialOpenFetchCount) {
        globalModel.markInitialHistoryLoaded(convKey);
      }
    }
  }

  bool _isOpenHistoryWarm(String convKey) {
    if (convKey.isEmpty) {
      return false;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    if (!globalModel.hasInitialHistoryLoaded(convKey)) {
      return false;
    }
    // removeMessageList 会删掉 map 条目；若只剩残留 loaded 别名，不能当暖窗，
    // 否则跳过 gate 又无消息 → 整页空灰。
    final raw = globalModel.rawMessageList(convKey);
    if (raw == null) {
      return false;
    }
    if (raw.isNotEmpty) {
      return true;
    }
    // 空 list：仅在「会话确实像空」且没有并行 peek 时算 warm。
    // 冷开并行期间禁止把空占位当成暖窗，否则会跳过 gate + hydrate_keep_empty。
    if (globalModel.hasOpenHydrateInFlight(convKey)) {
      return false;
    }
    return _conversationLooksEmptyForOpen(convKey);
  }

  /// 列表侧已无真实历史证据时，进页应直接空态，而不是先转圈拉历史。
  bool _conversationLooksEmptyForOpen(String convKey) {
    if (convKey.isEmpty) {
      return false;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    if (globalModel.rawMessageCount(convKey) > 0) {
      return false;
    }
    final conv = widget.selectedConversation;
    if ((conv.unreadCount ?? 0) > 0) {
      return false;
    }
    final last = conv.lastMessage;
    // 仅 lastMessage 缺失才预判空。最新一条是 tip/灰字不代表 SDK 无历史；
    // 冷开并行 peek 前误标 empty-loaded 会 hydrate_keep_empty → 灰屏。
    //
    // 社群：列表预览因 ID/落库失败暂时为 null 时，禁止预判空——否则再进页
    // 会 clearLocalHistoryAsEmptyLoaded，跳过云端拉历史，聊天记录整页空白。
    if (last == null && _getConvType() == ConvType.group) {
      return false;
    }
    return last == null;
  }

  void _ensureEmptyConversationReadyForOpen(String convKey) {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    // 冷开并行 peek 未完成：禁止预判 empty-loaded。
    if (globalModel.hasOpenHydrateInFlight(convKey)) {
      return;
    }
    if (!_conversationLooksEmptyForOpen(convKey)) {
      return;
    }
    if (globalModel.hasInitialHistoryLoaded(convKey) &&
        globalModel.rawMessageCount(convKey) == 0) {
      return;
    }
    globalModel.clearLocalHistoryAsEmptyLoaded(convKey);
  }

  void _startOpenHistoryGate(String convKey) {
    _openLifecycle.openHistoryGateConvKey = convKey;
    _openLifecycle.openHistoryPreparationGate = null;
    if (convKey.isEmpty ||
        widget.initFindingMsg != null ||
        widget.searchJumpAnchor != null ||
        UnreadTonguePolicy.isEntryUnreadEnabledForConvType(
          _getConvType(),
          widget.entryUnreadCount ?? 0,
        )) {
      _openLifecycle.openHistoryGate = null;
      if (convKey.isNotEmpty) {
        ChatHistoryOpenLayoutReady.cancel(convKey);
      }
      return;
    }
    // 先同步灌入缓存；只有完整首屏（或确认空）才跳过 gate。
    // 列表 LOCAL 预热常常只有几条：立刻上屏会在反转列表底部露出大片空白。
    _seedCachedHistoryOnOpen(convKey);
    _ensureEmptyConversationReadyForOpen(convKey);
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final rawCount = globalModel.rawMessageCount(convKey);
    final emptyConfirmed =
        globalModel.hasInitialHistoryLoaded(convKey) && rawCount == 0;
    final completeWindow =
        ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
      globalModel: globalModel,
      conversationKey: convKey,
    );
    // 完整首屏或确认空：无需等待可交互 gate。
    if (completeWindow || emptyConfirmed) {
      ChatHistoryOpenLayoutReady.cancel(convKey);
      ChatOpenPerfLog.mark(
        'history_gate_content_ready_skip',
        conversationID: convKey,
        extras: <String, Object?>{
          'rawCount': rawCount,
          'emptyConfirmed': emptyConfirmed,
          'completeWindow': completeWindow,
          'initialLoaded': globalModel.hasInitialHistoryLoaded(convKey),
        },
      );
      _openLifecycle.openHistoryGate = null;
      final preparation = _prepareOpenHistoryGate(
        convKey,
        cachedHistorySeeded: true,
      );
      _openLifecycle.openHistoryPreparationGate = preparation;
      unawaited(preparation);
      if (_getConvType() == ConvType.group) {
        unawaited(_ensureGroupLocalTipsMergedOnOpen(convKey));
      }
      return;
    }
    ChatHistoryOpenLayoutReady.begin(convKey);
    // 未灌满的预热窗也走 prepare + layout，避免先亮底部几条。
    // 真冷零消息仍串行；事件名保留 cold_shell，兼容既有性能日志。
    final thinWindow = rawCount > 0;
    ChatOpenPerfLog.mark(
      thinWindow ? 'history_gate_thin_window' : 'history_gate_cold_shell',
      conversationID: convKey,
      extras: <String, Object?>{'rawCount': rawCount},
    );
    final preparation = _prepareOpenHistoryGate(
      convKey,
      cachedHistorySeeded: true,
      coldOpen: !thinWindow,
    );
    _openLifecycle.openHistoryPreparationGate = preparation;
    _openLifecycle.openHistoryGate = _runOpenHistoryGateWithTipsMerge(
      convKey,
      coldOpen: !thinWindow,
      preparation: preparation,
    );
  }

  /// 先权威历史（冷开 / 薄窗均可 soft-timeout），再合本地 tip，
  /// 再等几何 ready。preparation 绝不能无限挂起，否则 AbsorbPointer 锁死滚动。
  Future<void> _runOpenHistoryGateWithTipsMerge(
    String convKey, {
    required bool coldOpen,
    required Future<void> preparation,
  }) async {
    if (convKey.isEmpty) {
      return;
    }
    // 薄窗与真冷共用硬超时：薄窗原先无超时，云端慢时门永不关 → 能返回不能滑。
    await preparation.timeout(
      const Duration(milliseconds: 1200),
      onTimeout: () {
        ChatOpenPerfLog.mark(
          coldOpen
              ? 'history_gate_timeout_1_2s'
              : 'history_gate_thin_timeout_1_2s',
          conversationID: convKey,
        );
      },
    );
    if (!mounted) {
      return;
    }
    try {
      await _ensureGroupLocalTipsMergedOnOpen(convKey).timeout(
        const Duration(milliseconds: 400),
      );
    } on TimeoutException {
      ChatOpenPerfLog.mark(
        'history_gate_tips_merge_timeout',
        conversationID: convKey,
      );
    } catch (_) {
      // tip 合并失败不挡揭开门。
    }
    if (!mounted) {
      return;
    }
    // 列表已经揭开并 signal 过：不要二次 begin 抬 epoch，否则会把已亮的历史闪没。
    if (ChatHistoryOpenLayoutReady.isReady(convKey)) {
      CallBubbleDedupe.endOpenHold(convKey);
      return;
    }
    // 作废 prepare/tip 期间可能发出的假 signal，再等几何 ready。
    ChatHistoryOpenLayoutReady.begin(convKey);
    await _waitOpenHistoryLayoutReady(convKey);
  }

  Future<void> _waitOpenHistoryLayoutReady(String convKey) async {
    // History preparation already has a 1.2s soft timeout. Do not add another
    // full second of shell time when hidden-list geometry cannot settle yet.
    final ready = await ChatHistoryOpenLayoutReady.wait(
      convKey,
      timeout: const Duration(milliseconds: 300),
    );
    CallBubbleDedupe.endOpenHold(convKey);
    if (!ready) {
      ChatOpenPerfLog.mark(
        'history_open_ready_timeout',
        conversationID: convKey,
      );
    }
  }

  Future<void> _prepareOpenHistoryGate(
    String convKey, {
    bool cachedHistorySeeded = false,
    bool coldOpen = false,
  }) async {
    if (convKey.isEmpty) {
      return;
    }
    if (!cachedHistorySeeded) {
      _seedCachedHistoryOnOpen(convKey);
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    // 冷启动别为别处的预载 hydrate 干等——直接自己拉首屏窗口
    //（bootstrap 内部有 in-flight 去重，不会重复请求）。
    ChatOpenPerfLog.mark(
      'prepare_gate_start',
      conversationID: convKey,
      extras: <String, Object?>{'coldOpen': coldOpen},
    );
    // 冷开并行 peek 也挂在 in-flight 上：给足时间等 inject，避免空窗误开二次拉。
    await globalModel.awaitOpenHydrateInFlight(
      convKey,
      timeout: const Duration(milliseconds: 900),
    );
    ChatOpenPerfLog.mark('prepare_gate_after_inflight_wait');
    if (!mounted) {
      return;
    }
    final bool loaded;
    OutgoingVisibleProbe.log(
      'enter_bootstrap_decision',
      conversationID: convKey,
      extras: <String, Object?>{
        'lastMessage': _conversation.lastMessage == null
            ? ''
            : OutgoingVisibleProbe.brief(_conversation.lastMessage!),
        'warmCount': globalModel.rawMessageCount(convKey),
        'warmLoaded': globalModel.hasInitialHistoryLoaded(convKey),
        ...OutgoingVisibleProbe.trackedInList(
          globalModel.rawMessageList(convKey),
        ),
      },
    );
    if (ConversationPreviewHistorySync.canSkipOpenRebootstrap(
      globalModel: globalModel,
      conversationKey: convKey,
      preview: _conversation.lastMessage,
    )) {
      // 预开 / 暖窗已灌且 tip 对齐：跳过二次 bootstrap，消掉首帧后顿挫。
      ChatOpenPerfLog.mark(
        'prepare_gate_bootstrap_skip',
        conversationID: convKey,
        extras: <String, Object?>{
          'rawCount': globalModel.rawMessageCount(convKey),
          'coldOpen': coldOpen,
        },
      );
      loaded = true;
      _chatController.model?.scheduleWarmOpenHistoryReconcile();
    } else {
      final firstWindow = Completer<void>();
      void signalFirstWindow() {
        if (!firstWindow.isCompleted) {
          firstWindow.complete();
        }
      }

      final task = ChatHistoryPeekBootstrap.apply(
        conversation: _conversation,
        globalModel: globalModel,
        lifeCycle: _chatLifeCycle,
        retryDelays: const <Duration>[
          Duration.zero,
          Duration(milliseconds: 120),
          Duration(milliseconds: 350),
        ],
        onFirstWindowCommitted: () {
          ChatOpenPerfLog.mark(
            'prepare_gate_local_window_ready',
            conversationID: convKey,
            extras: <String, Object?>{
              'rawCount': globalModel.rawMessageCount(convKey),
            },
          );
          signalFirstWindow();
        },
      );
      globalModel.registerOpenHydrateInFlight(convKey, task);
      unawaited(
        task.then(
          (_) => signalFirstWindow(),
          onError: (_) => signalFirstWindow(),
        ),
      );
      await firstWindow.future;
      loaded = globalModel.rawMessageCount(convKey) > 0 ||
          globalModel.hasInitialHistoryLoaded(convKey);
    }
    // 进页清归档误 insert 的 LOCAL_IMPORTED（只删本地），避免 tip 假消息与归档双开。
    unawaited(
      ArchiveImLocalPersistService.instance.purgeSpuriousLocalImported(
        isGroup: _getConvType() == ConvType.group,
        conversationID: convKey,
      ),
    );
    ChatOpenPerfLog.mark(
      'prepare_gate_bootstrap_done',
      conversationID: convKey,
      extras: <String, Object?>{
        'loaded': loaded,
        'rawCount': globalModel.rawMessageCount(convKey),
      },
    );
    if (!mounted) {
      return;
    }
    if (loaded) {
      final messages = globalModel.getMessageList(convKey);
      if (messages != null && messages.isNotEmpty) {
        ChatImageMessagePrefetch.fromMessages(messages);
        // 与历史上屏并行补 URL 并预热，气泡首帧即可挂网图。
        unawaited(
          ChatImageMessagePrefetch.resolveOnlineUrlsForMessages(messages).then(
            (_) {
              ChatImageMessagePrefetch.fromMessages(messages);
            },
          ),
        );
      }
      _clearMountedDisplayListCache();
    }
    final seedSw = Stopwatch()..start();
    await _seedSelfMemberFromLocalStore();
    ChatOpenPerfLog.mark(
      'prepare_gate_self_member_seeded',
      conversationID: convKey,
      extras: <String, Object?>{
        'selfMemberMs': seedSw.elapsedMilliseconds,
        'isGroup': _getConvType() == ConvType.group,
      },
    );
    // 群头像本地灌入不挡首屏；完成后 store notify 会补齐气泡脸。
    if (_getConvType() == ConvType.group) {
      unawaited(
        _hydrateGroupMessageAvatarsFromLocal().then((_) {
          ChatOpenPerfLog.mark(
            'group_avatar_hydrate_done',
            conversationID: convKey,
          );
        }),
      );
    }
    unawaited(
      _warmAvatarsOnChatOpen().then((_) {
        ChatOpenPerfLog.mark('avatar_warm_done', conversationID: convKey);
      }),
    );
    await _runPostOpenHistorySideEffects(convKey);
    ChatOpenPerfLog.mark('prepare_gate_complete', conversationID: convKey);
  }

  /// 进聊首屏前合并本地群灰字并过滤占位 IM tip（设/取消管理员等）。
  Future<void> _ensureGroupLocalTipsMergedOnOpen(String convKey) async {
    if (!mounted || convKey.isEmpty) {
      return;
    }
    if (_getConvType() != ConvType.group || !SelfHostedGroupBridge.enabled) {
      return;
    }
    final groupId =
        widget.selectedConversation.groupID?.trim().isNotEmpty == true
            ? widget.selectedConversation.groupID!.trim()
            : convKey;
    if (groupId.isEmpty) {
      return;
    }
    await GroupTipsOperatorPatchService.instance.applyPatchesForVisibleGroup(
      groupId,
    );
  }

  Future<void> _runPostOpenHistorySideEffects(String convKey) async {
    if (!mounted || convKey.isEmpty) {
      return;
    }
    final cachedMessages = serviceLocator<TUIChatGlobalModel>().getMessageList(
      convKey,
    );
    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      unawaited(_refreshHistoryIfPreviewAheadOnOpen(convKey, cachedMessages));
    }
    if (_getConvType() == ConvType.group) {
      unawaited(_scheduleDeferredGroupChangeSync(convKey));
    }
  }

  Widget _wrapChatWithOpenHistoryGate(Widget chatWidget) {
    final convKey = _getConvID()?.trim() ?? '';
    // 暖开若已挂 tip-merge gate（群自托管），仍须等 FutureBuilder，不能因 warm 短路。
    if (convKey.isEmpty ||
        _openLifecycle.openHistoryGate == null ||
        _openLifecycle.openHistoryGateConvKey != convKey) {
      return chatWidget;
    }
    return FutureBuilder<void>(
      future: _openLifecycle.openHistoryGate,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        // 始终显示同一棵真实聊天树，只在历史准备期间锁住交互。
        // 避免骨架 Scaffold 揭开时整页视觉替换造成首次进入闪烁。
        return AbsorbPointer(absorbing: !ready, child: chatWidget);
      },
    );
  }

  Future<void> _seedSelfMemberFromLocalStore() async {
    if (_getConvType() != ConvType.group) {
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(
      widget.selectedConversation.groupID,
    );
    final selfId = ContactSocialCacheStore.safeLoginUserId().trim();
    if (groupId.isEmpty || selfId.isEmpty) {
      return;
    }

    final localGroup = await GroupLocalStore.instance.read(groupId: groupId);
    final members = await GroupMemberLocalStore.instance.readByUserIds(
      groupId: groupId,
      userIds: <String>[selfId],
    );
    if (!mounted) {
      return;
    }

    V2TimGroupMemberFullInfo? localSelf =
        members.isEmpty ? null : members.first;
    final existing = GroupMemberStore.instance.memberOf(groupId, selfId);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final localMute = localSelf?.muteUntil ?? 0;
    final existingMute = existing?.muteUntil ?? 0;
    final isAllMuted = localGroup?.isAllMuted == true;
    final role = localSelf?.role ??
        existing?.role ??
        localGroup?.myRole ??
        GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    final exempt = GroupRolePolicy.isMuteExemptRole(role);

    int effectiveMute = existingMute > localMute ? existingMute : localMute;
    if (isAllMuted && !exempt) {
      // JS-safe permanent mute sentinel (Number.MAX_SAFE_INTEGER).
      effectiveMute = 0x1FFFFFFFFFFFFF;
    }

    if (localSelf == null && existing == null && effectiveMute <= 0) {
      return;
    }

    final seeded = V2TimGroupMemberFullInfo(
      userID: selfId,
      role: role,
      nickName: localSelf?.nickName ?? existing?.nickName,
      nameCard: localSelf?.nameCard ?? existing?.nameCard,
      friendRemark: localSelf?.friendRemark ?? existing?.friendRemark,
      faceUrl: localSelf?.faceUrl ?? existing?.faceUrl,
      joinTime: localSelf?.joinTime ?? existing?.joinTime,
      muteUntil: effectiveMute > 0 ? effectiveMute : null,
    );
    GroupMemberStore.instance.putMember(groupId, seeded, notify: false);

    Future<void> applyToModel() async {
      final model = _chatController.model;
      if (model == null || !mounted) {
        return;
      }
      if (isAllMuted || effectiveMute > nowSec) {
        await model.updateSelfMuteStatus(
          groupID: groupId,
          muteUntil:
              isAllMuted ? 0 : (effectiveMute > nowSec ? effectiveMute : 0),
          isAllMuted: isAllMuted,
        );
        return;
      }
      if (model.selfMemberInfo == null) {
        model.updateSelfMemberInfo(seeded, groupID: groupId);
      }
    }

    await applyToModel();
    if (_chatController.model == null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await applyToModel();
    }
  }

  Future<void> _hydrateGroupMessageAvatarsFromLocal() async {
    if (_getConvType() != ConvType.group) {
      return;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    final convKey = _getConvID()?.trim() ?? '';
    if (groupId.isEmpty || convKey.isEmpty) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final messages = globalModel.messageListMap[convKey];
    if (messages == null || messages.isEmpty) {
      return;
    }
    final senderIds = <String>{};
    for (final message in messages) {
      if (message.isSelf == true) {
        continue;
      }
      final sender = (message.sender ?? message.userID ?? '').trim();
      if (sender.isNotEmpty) {
        senderIds.add(sender);
      }
    }
    if (senderIds.isEmpty) {
      return;
    }
    final members = await GroupMemberLocalStore.instance.readByUserIds(
      groupId: groupId,
      userIds: senderIds.toList(growable: false),
    );
    if (!mounted || members.isEmpty) {
      return;
    }
    ChatJitterDiag.logGroupMemberStore(
      action: 'hydrateGroupMessageAvatarsFromLocal',
      groupId: groupId,
      memberCount: members.length,
      notify: false,
    );
    // 仅在既有成员 faceUrl 真正变化时通知头像刷新，避免首次灌入/昵称变化误触发闪动。
    final faceUrlChangedUserIDs = <String>{};
    for (final member in members) {
      final userID = member.userID.trim();
      if (userID.isEmpty) {
        continue;
      }
      final prev = GroupMemberStore.instance.memberOf(groupId, userID);
      if (prev == null) {
        continue;
      }
      final prevUrl = prev.faceUrl?.trim() ?? '';
      final nextUrl = member.faceUrl?.trim() ?? '';
      if (prevUrl != nextUrl) {
        faceUrlChangedUserIDs.add(userID);
      }
    }
    GroupMemberStore.instance.putMembers(groupId, members, notify: false);
    if (faceUrlChangedUserIDs.isEmpty) {
      ChatJitterDiag.logGroupMemberStore(
        action: 'hydrateGroupMessageAvatarsFromLocal_skip_notify',
        groupId: groupId,
        memberCount: members.length,
        notify: false,
      );
      return;
    }
    // 转场结束后再通知；再延后一帧，避开 post_open 同帧 setState 叠加重绘。
    _scheduleAfterRouteTransition(() {
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ChatJitterDiag.logGroupMemberStore(
          action: 'hydrateGroupMessageAvatarsFromLocal_notify',
          groupId: groupId,
          memberCount: members.length,
          notify: true,
        );
        GroupMemberStore.instance.notifyChatAvatarRefreshForUsers(
          groupId,
          faceUrlChangedUserIDs,
        );
      });
    });
  }

  /// 等当前路由 push 转场 [AnimationStatus.completed] 后再执行，避免进场中途刷 UI。
  void _scheduleAfterRouteTransition(VoidCallback task) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final animation = ModalRoute.of(context)?.animation;
      if (animation != null && !animation.isCompleted) {
        void listener(AnimationStatus status) {
          if (status != AnimationStatus.completed &&
              status != AnimationStatus.dismissed) {
            return;
          }
          _removeRouteTransitionListener(animation, listener);
          if (status != AnimationStatus.completed) {
            return;
          }
          if (!mounted) {
            return;
          }
          ChatJitterDiag.log(
            'after_route_transition',
            extras: const <String, Object?>{'source': 'animation_completed'},
          );
          task();
        }

        _addRouteTransitionListener(animation, listener);
        return;
      }
      ChatJitterDiag.log(
        'after_route_transition',
        extras: const <String, Object?>{'source': 'already_completed'},
      );
      task();
    });
  }

  void _scheduleHeavyChatBodyMount(String openConvKey) {
    // 仅冷开 / 超时 miss：转场后再挂，避免空列表跟手 relayout。
    // Ready 路径走 [_mountHeavyChatBodyOrReady]，首帧就是完整记录。
    _scheduleAfterRouteTransition(() {
      _mountHeavyChatBody(
        openConvKey: openConvKey,
        reason: 'route_settled',
      );
    });
    // 转场异常/无 animation 时兜底，避免永久轻壳。
    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (!mounted || _heavyChatBodyMounted) {
        return;
      }
      _mountHeavyChatBody(
        openConvKey: openConvKey,
        reason: 'transition_timeout',
      );
    });
  }

  bool _liveOpenViewportIsReady(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return false;
    }
    final snap = ChatEntrySnapshot.capture(
      globalModel: serviceLocator<TUIChatGlobalModel>(),
      conversationKey: key,
      conversationID: _resolvedConversationID(),
      requestId: 0,
      tip: widget.selectedConversation.lastMessage,
    );
    return snap.isViewportReady;
  }

  void _mountHeavyChatBodyOrReady({required String openConvKey}) {
    final key = openConvKey.trim();
    final coordinatorReady = key.isNotEmpty &&
        ChatOpenViewportCoordinator.instance.takeOpenWasViewportReady(key);
    final liveReady = key.isNotEmpty && _liveOpenViewportIsReady(key);
    final ready = coordinatorReady || liveReady;
    if (ready) {
      // initState 内不能 setState；直接标记，首帧 build 即走 TIMUIKitChat。
      _heavyChatBodyMounted = true;
      if (key.isNotEmpty) {
        _startOpenHistoryGate(key);
      }
      ChatOpenPerfLog.mark(
        'heavy_chat_body_mounted',
        conversationID: key,
        extras: <String, Object?>{
          'reason': coordinatorReady ? 'viewport_ready' : 'live_viewport_ready',
        },
      );
      ChatOpenViewportCoordinator.instance.markVisible(key);
      return;
    }
    _scheduleHeavyChatBodyMount(key);
  }

  void _mountHeavyChatBody({
    required String openConvKey,
    required String reason,
  }) {
    if (!mounted || _heavyChatBodyMounted) {
      return;
    }
    setState(() {
      _heavyChatBodyMounted = true;
    });
    final key = openConvKey.trim().isNotEmpty
        ? openConvKey.trim()
        : (_getConvID()?.trim() ?? '');
    if (key.isNotEmpty) {
      _startOpenHistoryGate(key);
    }
    ChatOpenPerfLog.mark(
      'heavy_chat_body_mounted',
      conversationID: key,
      extras: <String, Object?>{'reason': reason},
    );
  }

  final GlobalKey _chatHeaderTitleKey =
      GlobalKey(debugLabel: 'chat_header_title');

  void _exitChatMultiSelect() {
    final model = _chatController.model;
    if (model != null) {
      model.updateMultiSelectStatus(false);
      return;
    }
    final convId = _getConvID() ?? widget.selectedConversation.conversationID;
    if (convId.isEmpty) {
      return;
    }
    serviceLocator<ChatUiStateStore>().setMultiSelect(convId, false);
  }

  PreferredSizeWidget _buildChatAppBar(
    TUITheme theme, {
    required bool headerInteractive,
  }) {
    // 手机聊天页外层 Scaffold 盖住了 UIKit AppBar；多选时必须在这里出「取消」。
    return ChatHostAppBar(
      theme: theme,
      uiStateStore: serviceLocator<ChatUiStateStore>(),
      conversationID: _getConvID() ?? '',
      observeMultiSelect: headerInteractive,
      title: ChatHeaderTitle(
        key: _chatHeaderTitleKey,
        peerUserId: widget.selectedConversation.userID,
        conversationID: _getConvID() ?? '',
        conversationFaceUrl: _headerConversationFaceUrl(),
        title: _getHeaderTitleText(),
        headerState: _headerState,
        convType: _getConvType(),
        groupType: _headerGroupType(),
        onTap: headerInteractive ? _chatHeaderProfileTap : null,
        theme: theme,
      ),
      actions: _buildChatHeaderActions(theme),
      onCancelMultiSelect: _exitChatMultiSelect,
      bottom: _chatChromeDividerBar(
        theme.weakDividerColor ?? AppTokens.chatChromeDivider,
      ),
    );
  }

  Widget _buildChatTransitionShell(TUITheme theme) {
    // 与真实页共用 [_buildChatAppBar] / 消息区背景 / 窄屏输入栏，避免转场换皮。
    final inputBarColor = theme.weakBackgroundColor ?? hexToColor('f5f5f6');
    final inputFillColor = theme.inputFillColor ?? Colors.white;
    final inputIconColor =
        theme.darkTextColor ?? const Color.fromRGBO(68, 68, 68, 1);
    final hintColor = theme.weakTextColor ?? const Color(0xffAEA4A3);
    final draftText = _draft.text?.trim() ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.chatBgColor,
      appBar: _buildChatAppBar(theme, headerInteractive: false),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: _shellMessageAreaDecoration(theme),
              child: const SizedBox.expand(),
            ),
          ),
          IgnorePointer(
            child: _isC2cMessageBlocked()
                ? C2cFriendMessageBlockedBar(
                    peerUserId: _c2cPeerUserId() ?? '',
                    theme: theme,
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: inputBarColor,
                      border: Border(
                        top: BorderSide(
                          color:
                              theme.weakDividerColor ?? const Color(0xFFEAEAEA),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: TIMUIKitTextFieldLayoutNarrow
                              .inputBarVerticalPadding,
                          horizontal: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: TIMUIKitTextFieldLayoutNarrow
                                  .singleLineInputHeight,
                              child: Center(
                                child: SvgPicture.asset(
                                  'images/voice.svg',
                                  package: 'tencent_cloud_chat_uikit',
                                  colorFilter: ColorFilter.mode(
                                    inputIconColor,
                                    BlendMode.srcIn,
                                  ),
                                  height: 26,
                                  width: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: TIMUIKitTextFieldLayoutNarrow
                                    .singleLineInputHeight,
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: inputFillColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  draftText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    inherit: false,
                                    fontSize: 16,
                                    height: 1.2,
                                    color: draftText.isEmpty
                                        ? hintColor
                                        : (theme.darkTextColor ?? Colors.black),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: TIMUIKitTextFieldLayoutNarrow
                                  .singleLineInputHeight,
                              child: Center(
                                child: SvgPicture.asset(
                                  'images/face.svg',
                                  package: 'tencent_cloud_chat_uikit',
                                  colorFilter: ColorFilter.mode(
                                    inputIconColor,
                                    BlendMode.srcIn,
                                  ),
                                  height: 26,
                                  width: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: TIMUIKitTextFieldLayoutNarrow
                                  .singleLineInputHeight,
                              child: Center(
                                child: SvgPicture.asset(
                                  'images/add.svg',
                                  package: 'tencent_cloud_chat_uikit',
                                  colorFilter: ColorFilter.mode(
                                    inputIconColor,
                                    BlendMode.srcIn,
                                  ),
                                  height: 26,
                                  width: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _shellMessageAreaDecoration(TUITheme theme) {
    final conversationId = _resolvedConversationID();
    final isOfficial = PlatformOfficialAccountService.isPlatformOfficialAccount(
          widget.selectedConversation.userID,
        ) ||
        ChatBackgroundService.isOfficialAccountConversationId(conversationId);
    final backgroundImagePath = isOfficial || conversationId.isEmpty
        ? null
        : TIMUIKitChatBackgroundRegistry.getPath(conversationId);
    final isColorBackground =
        backgroundImagePath?.startsWith(ChatBackgroundService.colorPrefix) ??
            false;
    final isAssetBackground =
        backgroundImagePath?.startsWith(ChatBackgroundService.assetPrefix) ??
            false;
    final isFileBackground =
        backgroundImagePath?.startsWith(ChatBackgroundService.filePrefix) ??
            false;
    final backgroundImageProvider =
        backgroundImagePath == null || isColorBackground
            ? null
            : isAssetBackground
                ? AssetImage(
                    backgroundImagePath.substring(
                      ChatBackgroundService.assetPrefix.length,
                    ),
                  )
                : timUIKitLocalImageProvider(
                    isFileBackground
                        ? backgroundImagePath.substring(
                            ChatBackgroundService.filePrefix.length,
                          )
                        : backgroundImagePath,
                  );
    final backgroundColor = isColorBackground
        ? Color(
            int.tryParse(
                  backgroundImagePath!.substring(
                    ChatBackgroundService.colorPrefix.length,
                  ),
                  radix: 16,
                ) ??
                0xFFF3F5F8,
          )
        : null;
    final hasCustomBackground =
        backgroundImageProvider != null || isColorBackground;
    if (hasCustomBackground) {
      return BoxDecoration(
        color: backgroundColor,
        image: backgroundImageProvider == null
            ? null
            : DecorationImage(
                image: backgroundImageProvider,
                fit: BoxFit.cover,
              ),
      );
    }
    return BoxDecoration(color: theme.chatBgColor);
  }

  Future<void> _prefetchShellBackground() async {
    await _loadChatBackground();
    if (!mounted || _heavyChatBodyMounted) {
      return;
    }
    setState(() {});
  }

  void _addRouteTransitionListener(
    Animation<double> animation,
    AnimationStatusListener listener,
  ) {
    (_routeTransitionListeners[animation] ??= <AnimationStatusListener>{})
        .add(listener);
    animation.addStatusListener(listener);
  }

  void _removeRouteTransitionListener(
    Animation<double> animation,
    AnimationStatusListener listener,
  ) {
    animation.removeStatusListener(listener);
    final listeners = _routeTransitionListeners[animation];
    listeners?.remove(listener);
    if (listeners?.isEmpty ?? false) {
      _routeTransitionListeners.remove(animation);
    }
  }

  void _clearRouteTransitionListeners() {
    for (final entry in _routeTransitionListeners.entries) {
      for (final listener in entry.value) {
        entry.key.removeStatusListener(listener);
      }
    }
    _routeTransitionListeners.clear();
  }

  void _refreshSelfMessageAvatars() {
    final convKey = _getConvID();
    if (convKey == null || convKey.isEmpty) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final messages = globalModel.messageListMap[convKey];
    if (messages == null || messages.isEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    // 无变化时不回写不重建，避免进入页面后的无效整表刷新。
    // 有变化时就地补 faceUrl 快照即可；自己消息的头像走
    // currentSelfFaceUrl() 实时取值，单次 setState 就能刷新，
    // 不需要 setMessageList 触发整表 revision 变更。
    if (!_normalizeSelfMessageAvatars(messages)) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _normalizeOfficialAccountMessageAvatars(
    String userId,
    List<V2TimMessage> messages,
  ) {
    if (!PlatformOfficialAccountService.showsVerifiedBadge(userId)) {
      return;
    }
    final resolvedFace = PlatformOfficialAccountService.resolveFaceUrl(
      userId: userId,
      conversationFaceUrl:
          _conversation.faceUrl ?? widget.selectedConversation.faceUrl,
    );
    if (resolvedFace.isEmpty) {
      return;
    }
    for (final message in messages) {
      if (message.isSelf == true) {
        continue;
      }
      if ((message.faceUrl ?? '').trim() == resolvedFace) {
        continue;
      }
      message.faceUrl = resolvedFace;
    }
  }

  /// 其他设备退群后，本端 IM 会话可能残留；进入时校验群成员资格并剔除幽灵会话。
  Future<void> _verifyGroupMembershipOnOpen() async {
    if (_getConvType() != ConvType.group ||
        !SelfHostedGroupBridge.governanceEnabled) {
      return;
    }
    final groupId = _getConvID()?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    if (await GroupLocalStore.instance.read(groupId: groupId) != null) {
      return;
    }

    // 削峰：禁止 /me/groups?refresh=true；先普通对账，仍缺失再用单群详情判定。
    try {
      await GroupMembershipSyncService.instance.syncFull(
        reason: 'chat_open_verify',
      );
    } catch (_) {}

    if (!mounted) {
      return;
    }
    if (await GroupLocalStore.instance.read(groupId: groupId) != null) {
      return;
    }

    try {
      final detail = await MeGroupApi.instance.fetchGroupDetail(groupId);
      if (detail != null) {
        await GroupLocalStore.instance.upsert(
          ownerUserId: GroupLocalStore.instance.currentOwnerUserId(),
          record: detail,
        );
        return;
      }
    } catch (_) {}

    if (!mounted) {
      return;
    }
    if (await GroupLocalStore.instance.read(groupId: groupId) != null) {
      return;
    }

    await GroupMembershipSyncService.instance.onSelfRemovedFromGroup(groupId);
    if (!mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  String _headerAvatarUrlHash(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'empty';
    }
    return normalized.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  void _logGroupHeaderAvatarSource({
    required String source,
    required String currentFaceUrl,
    required String candidateFaceUrl,
    required bool applied,
  }) {
    // 头像源追溯默认关闭。
  }

  /// 进入群聊首帧：同步灌入本地群资料缓存，避免标题和头像二次变化。
  void _seedGroupDisplayFromMemory() {
    if (_getConvType() != ConvType.group) {
      return;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    final groupList = serviceLocator<TUIFriendShipViewModel>().groupList;
    final count = GroupDisplayResolver.resolveMemberCount(
      groupId: groupId,
      groupList: groupList,
    );
    if (count != null) {
      _groupMemberCount = count;
    }
    final notice = GroupDisplayResolver.resolveNotice(
      groupId: groupId,
      groupList: groupList,
    );
    if (notice.isNotEmpty) {
      _groupSide.groupNoticeBanner = notice;
    }
    final cachedAvatar = GroupLocalStore.instance
            .readCached(groupId: groupId)
            ?.avatarUrl
            .trim() ??
        '';
    final hasCachedAvatar = cachedAvatar.isNotEmpty &&
        !UserAvatarHelper.isDefaultPlaceholder(cachedAvatar);
    final currentFace = (_conversation.faceUrl ?? '').trim();
    // 展示信群资料库：本地可用且不同时优先群库，避免开场旧头像锁死。
    final faceUrl = hasCachedAvatar
        ? cachedAvatar
        : GroupDisplayResolver.resolveFaceUrl(
            conversation: _conversation,
            groupList: groupList,
          );
    final shouldApply = faceUrl.isNotEmpty && faceUrl != currentFace;
    _logGroupHeaderAvatarSource(
      source: hasCachedAvatar ? 'memory_local_cache' : 'memory_conversation',
      currentFaceUrl: currentFace,
      candidateFaceUrl: faceUrl,
      applied: shouldApply,
    );
    if (shouldApply) {
      _conversation.faceUrl = faceUrl;
      widget.selectedConversation.faceUrl = faceUrl;
      _cachedHeaderFaceUrl = faceUrl;
    }
  }

  /// 进入群聊后立即读本地 SQLite，补齐人数/公告/头像；后台网络刷新仅在值变化时更新 UI。
  Future<void> _hydrateGroupDisplayFromLocal() async {
    if (_getConvType() != ConvType.group) {
      return;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    final record = await GroupInfoResolver.instance.readGroup(groupId);
    if (!mounted) {
      return;
    }
    if (_getConvType() != ConvType.group ||
        !ChatIdFormat.groupIdsEquivalent(
          widget.selectedConversation.groupID,
          groupId,
        )) {
      return;
    }
    final prevCount = _groupMemberCount;
    final prevNotice = _groupSide.groupNoticeBanner;
    final prevFace = _conversation.faceUrl ?? '';
    final prevShowName = _conversation.showName ?? '';

    if (record != null) {
      // Local data is a first-paint fallback only. Once a value is already
      // present, do not re-apply the stale SQLite snapshot and make the header
      // jump while the authoritative request is in flight.
      if (_groupMemberCount == null && record.memberCount > 0) {
        _groupMemberCount = record.memberCount;
      }
      final groupName = record.groupName.trim();
      final currentShowName = (_conversation.showName ?? '').trim();
      final shouldApplyName = groupName.isNotEmpty &&
          (currentShowName.isEmpty ||
              currentShowName != groupName ||
              GroupDisplayResolver.looksLikeGroupIdLabel(
                currentShowName,
                groupId: groupId,
              ));
      if (shouldApplyName) {
        _conversation.showName = groupName;
        widget.selectedConversation.showName = groupName;
        conversationName = groupName;
        _cachedHeaderShowName = groupName;
      }
      final avatar = record.avatarUrl.trim();
      final currentFace = (_conversation.faceUrl ?? '').trim();
      final shouldApply = avatar.isNotEmpty &&
          !UserAvatarHelper.isDefaultPlaceholder(avatar) &&
          avatar != currentFace;
      _logGroupHeaderAvatarSource(
        source: 'sqlite_local_hydrate',
        currentFaceUrl: currentFace,
        candidateFaceUrl: avatar,
        applied: shouldApply,
      );
      if (shouldApply) {
        _conversation.faceUrl = avatar;
        widget.selectedConversation.faceUrl = avatar;
        _cachedHeaderFaceUrl = avatar;
      }
    }

    var notice = record?.notice.trim() ??
        GroupDisplayResolver.resolveNotice(
          groupId: groupId,
          groupList: serviceLocator<TUIFriendShipViewModel>().groupList,
        );
    if (notice.isNotEmpty &&
        await GroupNoticeMarqueeDismissService.instance.isDismissed(
          groupId: groupId,
          notice: notice,
        )) {
      notice = '';
    }
    if (!mounted ||
        _getConvType() != ConvType.group ||
        !ChatIdFormat.groupIdsEquivalent(
          widget.selectedConversation.groupID,
          groupId,
        )) {
      return;
    }
      if (_groupSide.groupNoticeBanner.isEmpty) {
        _groupSide.groupNoticeBanner = notice;
      }

    final headerChanged = _groupMemberCount != prevCount ||
        (_conversation.faceUrl ?? '') != prevFace ||
        (_conversation.showName ?? '') != prevShowName;
    final noticeChanged = _groupSide.groupNoticeBanner != prevNotice;
    if (headerChanged) {
      _syncChatHeaderState();
    }
    if (noticeChanged) {
      _syncChatTopFixState();
    }
  }

  bool _isCurrentConversation(String conversationId) {
    return mounted &&
        MessageConversationId.sameConversation(
          _resolvedConversationID(),
          conversationId,
        );
  }

  void _applyGroupMemberCountIfChanged(int? count) {
    if (!mounted || _groupMemberCount == count) {
      return;
    }
    _groupMemberCount = count;
    _syncChatHeaderState();
  }

  Future<void> _applyResolvedGroupNoticeBanner({
    required String groupId,
    required String notice,
  }) async {
    var body = notice.trim();
    if (body.isNotEmpty &&
        await GroupNoticeMarqueeDismissService.instance.isDismissed(
          groupId: groupId,
          notice: body,
        )) {
      body = '';
    }
    if (!_isCurrentConversation(groupId) ||
        body == _groupSide.groupNoticeBanner) {
      return;
    }
    _groupSide.groupNoticeBanner = body;
    _syncChatTopFixState();
  }

  Future<void> _loadGroupMemberCount() async {
    if (_getConvType() != ConvType.group) {
      if (_groupMemberCount != null && mounted) {
        _groupMemberCount = null;
        _syncChatHeaderState();
      }
      return;
    }
    final groupID = widget.selectedConversation.groupID ?? "";
    if (groupID.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final last = _lastGroupMetadataRefreshAt;
    if (last != null && now.difference(last) < const Duration(seconds: 60)) {
      return;
    }
    _lastGroupMetadataRefreshAt = now;
    final conversationId = _resolvedConversationID();
    final loadKey = '${ContactSocialCacheStore.safeLoginUserId()}|$groupID';
    final existing = _groupMemberCountLoads[loadKey];
    if (existing != null) {
      await existing;
      return;
    }
    final task = _loadGroupMemberCountOnce(
      groupID: groupID,
      conversationId: conversationId,
    );
    _groupMemberCountLoads[loadKey] = task;
    try {
      await task;
    } finally {
      if (_groupMemberCountLoads[loadKey] == task) {
        _groupMemberCountLoads.remove(loadKey);
      }
    }
  }

  Future<void> _loadGroupMemberCountOnce({
    required String groupID,
    required String conversationId,
  }) async {
    final generation = _groupMemberCountGeneration;
    var count = GroupDisplayResolver.resolveMemberCount(
      groupId: groupID,
      groupList: serviceLocator<TUIFriendShipViewModel>().groupList,
    );
    count ??= await GroupInfoResolver.instance.memberCount(groupID);
    if (count == null) {
      await GroupMembershipSyncService.instance.refreshGroupDetail(groupID);
      count = await GroupInfoResolver.instance.memberCount(groupID);
    }
    if (!_isCurrentConversation(conversationId) ||
        generation != _groupMemberCountGeneration ||
        count == null) {
      return;
    }
    _applyGroupMemberCountIfChanged(count);
  }

  Future<void> _loadGroupGameStatus() async {
    if (_getConvType() != ConvType.group) {
      if (_groupSide.groupFeatureEnabled ||
          _groupSide.groupGameEnabled ||
          _groupSide.sangongConfigured ||
          _groupSide.sangongNeedsSetup ||
          !_groupSide.groupGameFloatVisible) {
        if (mounted) {
          setState(() {
            _groupSide.groupFeatureEnabled = false;
            _groupSide.groupGameEnabled = false;
            _groupSide.groupGameFloatVisible = true;
            _groupSide.clearSangongAccess();
          });
          _syncChatTopFixState();
          _invalidateChatConfigCache();
          _updateSangongRealtimeSubscription();
        }
      }
      return;
    }
    final groupId = _getConvID()?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    final conversationId = _resolvedConversationID();
    final tenantGroupId = ChatIdFormat.normalizeGroupId(groupId);
    unawaited(SangongGameHttp.hydrateTenant());
    await SangongMyConfigService.instance.ensureHydrated();
    if (!_isCurrentConversation(conversationId)) {
      return;
    }
    final cachedGroupEnabled =
        GroupLocalStore.instance.readCached(groupId: groupId)?.gameEnabled ??
            false;
    final cachedUserEnabled = PrivilegedGameUserService.instance.isPrivileged;
    // 先用本地 my-config 秒开入口，避免等网络闪一下。
    final cachedSangongAccess = SangongMyConfigService.resolveGroupAccess(
      config: SangongMyConfigService.instance.hasCachedConfig
          ? SangongMyConfigService.instance.config
          : null,
      groupId: tenantGroupId,
      userPrivileged: cachedUserEnabled,
    );
    if (cachedSangongAccess.tenantId.isNotEmpty) {
      SangongGameHttp.setTenantId(cachedSangongAccess.tenantId);
    } else if (cachedUserEnabled && tenantGroupId.isNotEmpty) {
      SangongGameHttp.setTenantId(tenantGroupId);
    }
    if (mounted) {
      final changed = cachedGroupEnabled != _groupSide.groupFeatureEnabled ||
          cachedUserEnabled != _groupSide.groupGameEnabled ||
          !_sangongAccessMatches(_groupSide, cachedSangongAccess);
      if (changed) {
        setState(() {
          _groupSide.groupFeatureEnabled = cachedGroupEnabled;
          _groupSide.groupGameEnabled = cachedUserEnabled;
          _applySangongAccessToSide(cachedSangongAccess);
        });
        _syncChatTopFixState();
        _invalidateChatConfigCache();
        _updateSangongRealtimeSubscription();
      }
    }
    try {
      final currentGroup = await GroupLocalStore.instance.read(
        groupId: groupId,
      );
      final results = await Future.wait([
        GroupGamePrefs.instance.isFloatVisible(groupId),
        PrivilegedGameUserService.instance.refreshFromNetwork(),
        SangongMyConfigService.instance
            .refreshFromNetwork()
            .then<SangongMyConfig?>((config) => config)
            .onError(
              (_, __) => SangongMyConfigService.instance.configListenable.value,
            ),
        MeGroupApi.instance
            .fetchGroupDetail(
              groupId,
              refresh: true,
              preserveIsAllMutedFrom: currentGroup,
            )
            .onError((_, __) => currentGroup),
      ]);
      if (!_isCurrentConversation(conversationId)) {
        return;
      }
      final refreshedGroup = results[3] as MeGroupRecord?;
      if (refreshedGroup != null) {
        await GroupLocalStore.instance.upsert(
          ownerUserId: GroupLocalStore.instance.currentOwnerUserId(),
          record: refreshedGroup,
        );
      }
      if (!_isCurrentConversation(conversationId)) return;
      final groupEnabled = refreshedGroup?.gameEnabled ?? false;
      final userEnabled = (results[1] as GroupGameStatus).gameEnabled;
      final floatVisible = results[0] as bool;
      final myConfig = results[2] as SangongMyConfig?;
      final sangongAccess = SangongMyConfigService.resolveGroupAccess(
        config: myConfig,
        groupId: tenantGroupId,
        userPrivileged: userEnabled,
      );
      if (sangongAccess.tenantId.isNotEmpty) {
        SangongGameHttp.setTenantId(sangongAccess.tenantId);
      }

      final sideChanged = groupEnabled != _groupSide.groupFeatureEnabled ||
          userEnabled != _groupSide.groupGameEnabled ||
          floatVisible != _groupSide.groupGameFloatVisible ||
          !_sangongAccessMatches(_groupSide, sangongAccess);
      if (sideChanged) {
        setState(() {
          _groupSide.groupGameFloatVisible = floatVisible;
          // MeGroup.gameEnabled 仍给代理反水等群特性用。
          _groupSide.groupFeatureEnabled = groupEnabled;
          _groupSide.groupGameEnabled = userEnabled;
          _applySangongAccessToSide(sangongAccess);
        });
        _syncChatTopFixState();
        _invalidateChatConfigCache();
        _updateSangongRealtimeSubscription();
      }
      if (_shouldRefreshSangongAdminRound() &&
          !SangongAdminRealtimeService.instance.isActive) {
        unawaited(_refreshSangongAdminRound(silent: true));
      }
      if (_shouldShowGroupGameBanner()) {
        if (!SangongAdminRealtimeService.instance.isActive) {
          unawaited(_loadSangongBannerSettings());
        }
        unawaited(_refreshGroupGameRoundStatus());
      }
    } catch (_) {
      if (_isCurrentConversation(conversationId)) {
        setState(() {
          _groupSide.groupFeatureEnabled = false;
          _groupSide.groupGameEnabled = false;
          _groupSide.clearSangongAccess();
        });
        _syncChatTopFixState();
        _invalidateChatConfigCache();
        _updateSangongRealtimeSubscription();
      }
    }
  }

  void _applySangongAccessToSide(SangongMyConfigGroupAccess access) {
    _groupSide.sangongConfigured = access.configured;
    _groupSide.sangongNeedsSetup = access.needsSetup;
    _groupSide.sangongCanEditConfig = access.canEditConfig;
    _groupSide.sangongCanManageMembers = access.canManageMembers;
    _groupSide.sangongMyRole = access.myRole;
    _groupSide.sangongTenantId = access.tenantId;
  }

  bool _sangongAccessMatches(
    ChatGroupPageSideController side,
    SangongMyConfigGroupAccess access,
  ) {
    return side.sangongConfigured == access.configured &&
        side.sangongNeedsSetup == access.needsSetup &&
        side.sangongCanEditConfig == access.canEditConfig &&
        side.sangongCanManageMembers == access.canManageMembers &&
        side.sangongMyRole == access.myRole &&
        side.sangongTenantId == access.tenantId;
  }

  Future<void> _loadAgentRebateIdentity() async {
    if (_getConvType() != ConvType.group) {
      if (_groupSide.agentRebateIdentityEnabled ||
          _groupSide.agentRebateGroupBound ||
          _groupSide.agentRebateGroupEnabled) {
        if (mounted) {
          setState(() {
            _groupSide.agentRebateGroupBound = false;
            _groupSide.agentRebateGroupEnabled = false;
            _groupSide.agentRebateIdentityEnabled = false;
            _invalidateChatConfigCache();
          });
        }
      }
      return;
    }
    final groupId = _getConvID()?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    final conversationId = _resolvedConversationID();
    final cached = AgentIdentityService.instance.cachedEntry(groupId);
    if (cached != null && mounted) {
      final changed = cached.bound != _groupSide.agentRebateGroupBound ||
          cached.enabled != _groupSide.agentRebateGroupEnabled ||
          cached.isAgent != _groupSide.agentRebateIdentityEnabled;
      if (changed) {
        setState(() {
          _groupSide.agentRebateGroupBound = cached.bound;
          _groupSide.agentRebateGroupEnabled = cached.enabled;
          _groupSide.agentRebateIdentityEnabled = cached.isAgent;
          _invalidateChatConfigCache();
        });
      }
    }
    final entry = await AgentIdentityService.instance.refreshForGroup(groupId);
    if (!_isCurrentConversation(conversationId)) {
      return;
    }
    final changed = entry.bound != _groupSide.agentRebateGroupBound ||
        entry.enabled != _groupSide.agentRebateGroupEnabled ||
        entry.isAgent != _groupSide.agentRebateIdentityEnabled;
    if (!changed) {
      return;
    }
    setState(() {
      _groupSide.agentRebateGroupBound = entry.bound;
      _groupSide.agentRebateGroupEnabled = entry.enabled;
      _groupSide.agentRebateIdentityEnabled = entry.isAgent;
      _invalidateChatConfigCache();
    });
  }

  /// 聊天页三公浮窗露出：特权用户 +（待首次配置 或 当前群==绑定下注群）。
  bool _hasGroupGamePrivilegeAccess() {
    if (_getConvType() != ConvType.group || !_groupSide.groupGameEnabled) {
      return false;
    }
    return _groupSide.sangongNeedsSetup || _hasGroupGameOpsAccess();
  }

  /// 已绑定当前下注群，可跑局 / Banner / 长按菜单。
  bool _hasGroupGameOpsAccess() {
    return _getConvType() == ConvType.group &&
        _groupSide.groupGameEnabled &&
        _groupSide.sangongConfigured &&
        !_groupSide.sangongNeedsSetup;
  }

  bool _shouldShowGroupGameBanner() {
    return _hasGroupGameOpsAccess() && _groupSide.groupGameFloatVisible;
  }

  bool _shouldShowSangongGameMessageMenu() {
    return _hasGroupGameOpsAccess();
  }

  bool _shouldShowAgentRebateFloat() {
    return _getConvType() == ConvType.group &&
        AgentIdentityService.canShowEntries(
          groupBound: _groupSide.agentRebateGroupBound,
          groupEnabled: _groupSide.agentRebateGroupEnabled,
          isAgent: _groupSide.agentRebateIdentityEnabled,
        );
  }

  bool _shouldRefreshSangongAdminRound() {
    return _shouldShowSangongGameMessageMenu() || _shouldShowGroupGameBanner();
  }

  bool _sangongFloatingSettleLabelChanged(SangongAdminRound? previousRound) {
    return (previousRound?.canVoidResettle == true) !=
        (_sangongAdminRound?.canVoidResettle == true);
  }

  void _rebuildSangongFloatingEntryIfNeeded(SangongAdminRound? previousRound) {
    if (mounted && _sangongFloatingSettleLabelChanged(previousRound)) {
      setState(() {});
    }
  }

  Future<void> _refreshSangongAdminRound({bool silent = false}) async {
    if (!_shouldRefreshSangongAdminRound()) {
      return;
    }
    if (!SangongGameHttp.canCallAdmin) {
      return;
    }
    if (SangongAdminRealtimeService.instance.isActive) {
      await SangongAdminRealtimeService.instance.refreshSnapshot();
      return;
    }
    try {
      final session = await SangongAdminApi.instance.fetchSession();
      if (!mounted) {
        return;
      }
      final round = session.round;
      final previousRound = _sangongAdminRound;
      _sangongAdminRound = round;
      if (round != null) {
        _groupSide.groupGameRoundStatus =
            _groupSide.groupGameRoundStatus.copyWith(
          bankerName: round.bankerNickname,
          bankerDoor: round.bankerDoor,
          bankerLimit: round.bankerLimit,
        );
      }
      _syncChatTopFixState();
      _rebuildSangongFloatingEntryIfNeeded(previousRound);
      _invalidateChatConfigCache();
    } catch (_) {
      if (!silent && mounted) {
        // 静默失败，避免干扰聊天；操作时再提示。
      }
    }
  }

  Future<void> _onSangongQuickSetupBanker(V2TimMessage message) async {
    if (!_ensureSangongAdminReady()) {
      return;
    }
    final input = SangongQuickSetupBankerInput.fromMessage(message);
    if (input == null) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '仅支持对文本消息快速定庄',
          zhHant: '僅支援對文字訊息快速定莊',
          en: 'Quick setup only works on text messages',
        ),
      );
      return;
    }
    try {
      final result = await _runSangongRemoteAction(
        loadingText: AppI18n.of(
          context,
        ).t(zhHans: '正在定庄…', zhHant: '正在定莊…', en: 'Setting banker…'),
        action: () => SangongAdminApi.instance.quickSetupBanker(
          text: input.text,
          imUserId: input.imUserId,
          nickname: input.nickname,
        ),
      );
      if (!mounted || result == null) return;
      if (result.round != null) {
        final previousRound = _sangongAdminRound;
        _sangongAdminRound = result.round;
        _groupSide.groupGameRoundStatus =
            _groupSide.groupGameRoundStatus.copyWith(
          bankerName: result.round!.bankerNickname,
          bankerDoor: result.round!.bankerDoor,
          bankerLimit: result.round!.bankerLimit,
        );
        _syncChatTopFixState();
        _rebuildSangongFloatingEntryIfNeeded(previousRound);
      }
      _invalidateChatConfigCache();
      final parsed = result.parsed;
      final doorLabel = parsed.door > 0 ? '${parsed.door}门' : '';
      final limitLabel = parsed.limited && parsed.limit > 0
          ? AppI18n.of(context).t(
              zhHans: '限额${parsed.limit}',
              zhHant: '限額${parsed.limit}',
              en: 'limit ${parsed.limit}',
            )
          : '';
      final base = doorLabel.isEmpty
          ? AppI18n.of(
              context,
            ).t(zhHans: '定庄成功', zhHant: '定莊成功', en: 'Banker assigned')
          : AppI18n.of(context).t(
              zhHans:
                  '定庄成功：$doorLabel${limitLabel.isNotEmpty ? ' $limitLabel' : ''}',
              zhHant:
                  '定莊成功：$doorLabel${limitLabel.isNotEmpty ? ' $limitLabel' : ''}',
              en: 'Banker assigned: $doorLabel${limitLabel.isNotEmpty ? ' ($limitLabel)' : ''}',
            );
      final suffix = result.restarted
          ? AppI18n.of(
              context,
            ).t(zhHans: '（已重开新局）', zhHant: '（已重開新局）', en: ' (round restarted)')
          : result.sent
              ? ''
              : AppI18n.of(
                  context,
                ).t(
                  zhHans: '（通知未发送）',
                  zhHant: '（通知未發送）',
                  en: ' (notice not sent)');
      ToastUtils.toast('$base$suffix');
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(DioErrorMessage.forApp(error));
    }
  }

  Future<SangongAdminRound?> _loadRoundForBetCutoff() async {
    if (_sangongAdminRound == null) {
      await _refreshSangongAdminRound();
    }
    final round = _sangongAdminRound;
    if (round == null || round.id <= 0) {
      ToastUtils.toast(
        AppI18n.of(
          context,
        ).t(zhHans: '当前无有效局', zhHant: '當前無有效局', en: 'No active round'),
      );
      return null;
    }
    if (!round.hasBetWindowOpen) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '请先发送定庄通知',
          zhHant: '請先發送定莊通知',
          en: 'Send banker notice first',
        ),
      );
      return null;
    }
    if (!round.canCutoffBets) {
      ToastUtils.toast(
        AppI18n.of(
          context,
        ).t(zhHans: '本局已结算', zhHant: '本局已結算', en: 'Round already settled'),
      );
      return null;
    }
    return round;
  }

  /// 外部报表/管理接口等待期间显示转圈；[action] 返回后自动关闭。
  Future<T?> _runSangongRemoteAction<T>({
    required String loadingText,
    required Future<T> Function() action,
  }) async {
    if (_groupSide.sangongRemoteBusy) {
      return null;
    }
    _groupSide.sangongRemoteBusy = true;
    // showLoading 会一直 await 到 hideLoading，不能直接 await。
    unawaited(AppDialog.showLoading(text: loadingText));
    // 给弹窗一帧时间挂上，避免接口极快返回时闪一下都看不到。
    await Future<void>.delayed(const Duration(milliseconds: 16));
    try {
      return await action();
    } finally {
      AppDialog.hideLoading();
      _groupSide.sangongRemoteBusy = false;
    }
  }

  Future<void> _onSangongExcludeBet(V2TimMessage message) async {
    if (!_ensureSangongAdminReady()) {
      return;
    }
    final cutoff = SangongBetSubmitCutoff.excludingMessage(message);
    if (cutoff == null) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '无法识别该消息 id，暂不可排除',
          zhHant: '無法識別該訊息 id，暫不可排除',
          en: 'Cannot read message id for exclusion',
        ),
      );
      return;
    }
    await _runSangongBetCutoffPreview(
      cutoff: cutoff,
      selectedMessagePreview: SangongBetSubmitCutoff.readMessagePreviewText(
        message,
      ),
      selectedSenderLabel: SangongBetSubmitCutoff.readSenderLabel(message),
      excludeMode: true,
    );
  }

  Future<void> _onSangongGameStats(V2TimMessage message) async {
    if (!_ensureSangongAdminReady()) {
      return;
    }
    final cutoff = SangongBetSubmitCutoff.fromLongPressedMessage(message);
    if (cutoff == null) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '无法识别该消息作为截止点，请换一条下注消息重试',
          zhHant: '無法識別該訊息作為截止點，請換一條下注訊息重試',
          en: 'Cannot use this message as cutoff. Try another bet message',
        ),
      );
      return;
    }
    await _runSangongBetCutoffPreview(
      cutoff: cutoff,
      selectedMessagePreview: SangongBetSubmitCutoff.readMessagePreviewText(
        message,
      ),
      selectedSenderLabel: SangongBetSubmitCutoff.readSenderLabel(message),
    );
  }

  Future<void> _openGroupGameCutoff() async {
    _dismissChatInput();
    if (!await _ensureUserGameEnabled()) {
      return;
    }
    if (!_ensureSangongAdminReady()) {
      return;
    }
    await _runSangongBetCutoffPreview(cutoff: const SangongBetSubmitCutoff());
  }

  Future<void> _runSangongBetCutoffPreview({
    required SangongBetSubmitCutoff cutoff,
    String? selectedMessagePreview,
    String? selectedSenderLabel,
    bool excludeMode = false,
  }) async {
    try {
      final round = await _loadRoundForBetCutoff();
      if (round == null) {
        return;
      }
      final result = await _runSangongRemoteAction(
        loadingText: AppI18n.of(
          context,
        ).t(zhHans: '正在生成预览…', zhHant: '正在生成預覽…', en: 'Loading preview…'),
        action: () => SangongAdminApi.instance.previewBets(
          cutoff: cutoff,
          roundId: round.id,
        ),
      );
      if (!mounted || result == null) return;
      final submitResult = await SangongBetPreviewSheet.show(
        context,
        preview: result.preview,
        cutoff: cutoff,
        roundId: round.id,
        doorCount: _groupSide.sangongDoorCount ?? 6,
        bankerName: round.bankerNickname,
        bankerDoor: round.bankerDoor,
        selectedMessagePreview: selectedMessagePreview,
        selectedSenderLabel: selectedSenderLabel,
        excludeMode: excludeMode,
      );
      if (!mounted || submitResult == null) return;
      if (submitResult.round != null) {
        final previousRound = _sangongAdminRound;
        _sangongAdminRound = submitResult.round;
        _rebuildSangongFloatingEntryIfNeeded(previousRound);
      }
      _invalidateChatConfigCache();
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(SangongAdminErrorMessage.fromBetting(error));
    }
  }

  Future<void> _onSangongSendSettleReportImage() async {
    _dismissChatInput();
    if (!await _ensureUserGameEnabled()) {
      return;
    }
    if (!_ensureSangongAdminReady()) {
      return;
    }
    try {
      final result = await _runSangongRemoteAction(
        loadingText: AppI18n.of(context).t(
          zhHans: '正在生成并发送结算图…',
          zhHant: '正在生成並發送結算圖…',
          en: 'Sending settle image…',
        ),
        action: () => SangongAdminApi.instance.sendSettleReportImage(),
      );
      if (!mounted || result == null) return;
      ToastUtils.toast(
        sangongReportImageSuccessToast(
          AppI18n.of(context),
          result,
          fallbackZhHans: '结算明细已发送到游戏群',
          fallbackZhHant: '結算明細已發送到遊戲群',
          fallbackEn: 'Settle detail sent to game group',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(DioErrorMessage.forApp(error));
    }
  }

  Future<void> _onSangongSendSettleBillImage() async {
    _dismissChatInput();
    if (!await _ensureUserGameEnabled()) {
      return;
    }
    if (!_ensureSangongAdminReady()) {
      return;
    }
    try {
      final result = await _runSangongRemoteAction(
        loadingText: AppI18n.of(context).t(
          zhHans: '正在生成并发送账单…',
          zhHant: '正在生成並發送賬單…',
          en: 'Sending settle bill…',
        ),
        action: () => SangongAdminApi.instance.sendSettleBillImage(),
      );
      if (!mounted || result == null) return;
      ToastUtils.toast(
        sangongReportImageSuccessToast(
          AppI18n.of(context),
          result,
          fallbackZhHans: '流水/抽水账单已发送到管理统计群',
          fallbackZhHant: '流水/抽水賬單已發送到管理統計群',
          fallbackEn: 'Settle bill sent to admin group',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(DioErrorMessage.forApp(error));
    }
  }

  Future<void> _onSangongSendPointsReportImage() async {
    _dismissChatInput();
    if (!await _ensureUserGameEnabled()) {
      return;
    }
    if (!_ensureSangongAdminReady()) {
      return;
    }
    final imGroupId = ChatIdFormat.normalizeGroupId(
      widget.selectedConversation.groupID,
    );
    if (imGroupId.isEmpty) {
      if (!mounted) return;
      ToastUtils.toast(
        AppI18n.of(
          context,
        ).t(zhHans: '无法获取当前群 ID', zhHant: '無法獲取當前群 ID', en: 'Missing group ID'),
      );
      return;
    }
    try {
      final result = await _runSangongRemoteAction(
        loadingText: AppI18n.of(context).t(
          zhHans: '正在生成并发送积分图…',
          zhHant: '正在生成並發送積分圖…',
          en: 'Sending points image…',
        ),
        action: () => SangongAdminApi.instance.sendPointsReportImage(
          imGroupId: imGroupId,
        ),
      );
      if (!mounted || result == null) return;
      ToastUtils.toast(
        sangongReportImageSuccessToast(
          AppI18n.of(context),
          result,
          fallbackZhHans: '用户积分图已发送',
          fallbackZhHant: '用戶積分圖已發送',
          fallbackEn: 'User points image sent',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(DioErrorMessage.forApp(error));
    }
  }

  Future<void> _onSangongSendTrendReportImage() async {
    _dismissChatInput();
    if (!await _ensureUserGameEnabled()) {
      return;
    }
    if (!_ensureSangongAdminReady()) {
      return;
    }
    try {
      final result = await _runSangongRemoteAction(
        loadingText: AppI18n.of(context).t(
          zhHans: '正在生成并发送走势图…',
          zhHant: '正在生成並發送走勢圖…',
          en: 'Sending trend chart…',
        ),
        action: SangongAdminApi.instance.sendTrendReportImage,
      );
      if (!mounted || result == null) return;
      ToastUtils.toast(
        sangongReportImageSuccessToast(
          AppI18n.of(context),
          result,
          fallbackZhHans: '走势图已发送到游戏群',
          fallbackZhHant: '走勢圖已發送到遊戲群',
          fallbackEn: 'Trend chart sent to game group',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ToastUtils.toast(DioErrorMessage.forApp(error));
    }
  }

  Future<void> _loadSangongBannerSettings() async {
    if (!_shouldShowGroupGameBanner()) {
      return;
    }
    try {
      final settings = await SangongSettingsApi.instance.fetch();
      if (!mounted || !_shouldShowGroupGameBanner()) {
        return;
      }
      final doorCount = settings.doorCount.clamp(2, 10);
      _groupSide.sangongDoorCount = doorCount;
      _groupSide.groupGameRoundStatus = _groupSide.groupGameRoundStatus
          .copyWith(doorBetTotals: List<int>.filled(doorCount, 0));
      _syncChatTopFixState();
    } catch (_) {}
  }

  void _applySangongRealtimeState(SangongAdminRealtimeState state) {
    if (!mounted) {
      return;
    }
    final previousRound = _sangongAdminRound;
    _sangongAdminRound = state.round;
    _groupSide.sangongDoorCount = state.doorCount;
    _groupSide.groupGameRoundStatus = state.toGroupGameRoundStatus();
    _syncChatTopFixState();
    _rebuildSangongFloatingEntryIfNeeded(previousRound);
    _invalidateChatConfigCache();
  }

  void _updateSangongRealtimeSubscription() {
    final shouldSubscribe =
        _shouldRefreshSangongAdminRound() && SangongGameHttp.canCallAdmin;
    if (shouldSubscribe) {
      if (_sangongRealtimeSub == null) {
        final service = SangongAdminRealtimeService.instance;
        service.acquire();
        _sangongRealtimeSub = service.states.listen(_applySangongRealtimeState);
        final latest = service.latestState;
        if (latest != null) {
          _applySangongRealtimeState(latest);
        }
      }
      return;
    }
    _sangongRealtimeSub?.cancel();
    _sangongRealtimeSub = null;
    SangongAdminRealtimeService.instance.release();
  }

  /// 拉取当前局庄家、庄门、下注窗口等实时数据。
  Future<void> _refreshGroupGameRoundStatus() async {
    await _refreshSangongAdminRound(silent: true);
  }

  /// 头部导航下方的固定区：公告跑马灯 + 三公状态条。
  Widget _buildChatTopFixWidget() {
    return ChatTopFixView(
      controller: _topFixState,
      onShowNotice: (notice) => unawaited(_showGroupNoticeFull(notice)),
      onDismissNotice: (notice) => unawaited(
        _dismissGroupNoticeBanner(notice),
      ),
      onGroupLiveTap: _onGroupLiveBannerTap,
      onCloseGroupLiveWatch: _closeGroupLiveWatch,
    );
  }

  /// 读取当前群公告并刷新跑马灯（[forcedText] 优先，用于实时事件）。
  Future<void> _loadGroupNoticeBanner({String? forcedText}) async {
    if (_getConvType() != ConvType.group) {
      if (_groupSide.groupNoticeBanner.isNotEmpty) {
        _groupSide.groupNoticeBanner = '';
        _syncChatTopFixState();
      }
      return;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    var notice = forcedText?.trim() ?? '';
    if (notice.isEmpty) {
      final record = await GroupInfoResolver.instance.readGroup(groupId);
      notice = record?.notice.trim() ??
          GroupDisplayResolver.resolveNotice(
            groupId: groupId,
            groupList: serviceLocator<TUIFriendShipViewModel>().groupList,
          );
    }
    await _applyResolvedGroupNoticeBanner(groupId: groupId, notice: notice);
  }

  Future<void> _dismissGroupNoticeBanner(String notice) async {
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    final body = notice.trim();
    if (groupId.isEmpty || body.isEmpty) {
      return;
    }
    await GroupNoticeMarqueeDismissService.instance.saveDismissedNotice(
      groupId,
      body,
    );
    if (mounted) {
      _groupSide.groupNoticeBanner = '';
      _syncChatTopFixState();
    }
  }

  Future<void> _presentGroupNoticeOverlay({
    required String notice,
    int? lastInfoTime,
    required Future<void> Function(BuildContext overlayContext) onGotIt,
    bool barrierDismissible = true,
    bool enableDrag = true,
  }) async {
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget buildPanel(BuildContext overlayContext) {
      final bottomSafePadding = MediaQuery.of(overlayContext).padding.bottom;
      final scrollMaxHeight =
          (MediaQuery.sizeOf(overlayContext).height * (kIsWeb ? 0.45 : 0.55))
              .clamp(120.0, 400.0);

      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          kIsWeb ? 24 : bottomSafePadding + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppI18n.of(context).t(
                zhHans: '群公告',
                zhHant: '群公告',
                en: 'Group Notice',
                ja: 'グループのお知らせ',
                ko: '그룹 공지',
              ),
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (lastInfoTime != null && lastInfoTime > 0) ...[
              const SizedBox(height: 14),
              Text(
                _formatGroupNoticeTime(lastInfoTime),
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: scrollMaxHeight),
              child: SingleChildScrollView(
                child: Text(
                  notice,
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await onGotIt(overlayContext);
                  if (overlayContext.mounted) {
                    Navigator.of(overlayContext).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ED1B3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  AppI18n.of(context).t(
                    zhHans: '我知道了',
                    zhHant: '我知道了',
                    en: 'Got it',
                    ja: '確認しました',
                    ko: '확인했습니다',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (kIsWeb) {
      await showDialog<void>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        builder: (dialogContext) {
          final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.72;
          return Dialog(
            backgroundColor: AppColors.card(dark: dark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
              child: buildPanel(dialogContext),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: barrierDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card(dark: dark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: buildPanel(sheetContext),
        );
      },
    );
  }

  Future<void> _showGroupNoticeFull(String notice) async {
    final text = notice.trim();
    if (text.isEmpty) {
      return;
    }
    await _presentGroupNoticeOverlay(notice: text, onGotIt: (_) async {});
  }

  Future<void> _onGroupGameFloatVisibleChanged(bool visible) async {
    final groupId = _getConvID()?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    if (mounted && _groupSide.groupGameFloatVisible != visible) {
      setState(() {
        _groupSide.groupGameFloatVisible = visible;
        if (!visible) {
          _groupSide.sangongDoorCount = null;
          _groupSide.groupGameRoundStatus = const GroupGameRoundStatus();
        }
      });
      _syncChatTopFixState();
    }
    await GroupGamePrefs.instance.setFloatVisible(groupId, visible);
    _updateSangongRealtimeSubscription();
    if (visible && mounted && _shouldShowGroupGameBanner()) {
      if (!SangongAdminRealtimeService.instance.isActive) {
        unawaited(_loadSangongBannerSettings());
      }
      unawaited(_refreshGroupGameRoundStatus());
    }
  }

  Future<bool> _ensureUserGameEnabled() async {
    try {
      final status =
          await PrivilegedGameUserService.instance.refreshFromNetwork();
      if (!mounted) {
        return false;
      }
      if (!status.gameEnabled) {
        setState(() => _groupSide.groupGameEnabled = false);
        _syncChatTopFixState();
        return false;
      }
      if (!_groupSide.groupGameEnabled) {
        setState(() => _groupSide.groupGameEnabled = true);
        _syncChatTopFixState();
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _groupSide.groupGameEnabled = false);
        _syncChatTopFixState();
      }
      return false;
    }
  }

  /// 管理写接口本地前置：主服务 JWT + 当前游戏群租户。
  bool _ensureSangongAdminReady() {
    if (SangongGameHttp.canCallAdmin) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    ToastUtils.toast(
      AppI18n.of(context).t(
        zhHans: SangongGameHttp.hasAuth ? '请先进入游戏群' : '请先登录',
        zhHant: SangongGameHttp.hasAuth ? '請先進入遊戲群' : '請先登入',
        en: SangongGameHttp.hasAuth
            ? 'Open a game group first'
            : 'Please sign in first',
      ),
    );
    return false;
  }

  void _openGroupGameSettle() {
    _dismissChatInput();
    unawaited(() async {
      if (!await _ensureUserGameEnabled()) {
        return;
      }
      if (!mounted) {
        return;
      }
      final settled = await SangongRoundSettleFlow.run(context);
      if (!mounted || !settled) {
        return;
      }
      unawaited(_refreshSangongAdminRound(silent: true));
    }());
  }

  Future<void> _openGroupGameRulesSettings() async {
    if (!await _ensureUserGameEnabled()) {
      return;
    }
    _dismissChatInput();
    final groupId = _getConvID()?.trim() ?? '';
    await SangongManageHomePage.open(
      context,
      gameGroupId: groupId,
      tenantId: _groupSide.sangongTenantId,
      canEditConfig: _groupSide.sangongCanEditConfig,
      canManageMembers: _groupSide.sangongCanManageMembers,
      needsSetup: _groupSide.sangongNeedsSetup,
      floatVisible: _groupSide.groupGameFloatVisible,
      onFloatVisibleChanged: (visible) {
        unawaited(_onGroupGameFloatVisibleChanged(visible));
      },
      onConfigSaved: (_) {
        unawaited(_loadGroupGameStatus());
      },
    );
    if (!mounted) {
      return;
    }
    unawaited(_loadGroupGameStatus());
    if (_shouldShowGroupGameBanner()) {
      unawaited(_loadSangongBannerSettings());
      unawaited(_refreshGroupGameRoundStatus());
    }
  }

  Future<void> _openSangongMyConfigSetup() async {
    if (!await _ensureUserGameEnabled()) {
      return;
    }
    _dismissChatInput();
    final groupId = _getConvID()?.trim() ?? '';
    await SangongMyConfigPage.open(
      context,
      initialGameGroupId: groupId,
      onSaved: (_) {
        unawaited(_loadGroupGameStatus());
      },
    );
    if (!mounted) {
      return;
    }
    unawaited(_loadGroupGameStatus());
  }

  Widget? _buildGroupGameFloatingEntry(TUITheme theme) {
    if (!_hasGroupGamePrivilegeAccess()) {
      return null;
    }
    final i18n = AppI18n.of(context);
    final setupOnly = _groupSide.sangongNeedsSetup;
    final settleLabel =
        !setupOnly && _sangongAdminRound?.canVoidResettle == true
            ? i18n.t(zhHans: '冲正重结', zhHant: '沖正重結', en: 'Resettle')
            : null;
    return GroupGameFloatingEntry(
      theme: theme,
      setupOnly: setupOnly,
      settleActionLabel: settleLabel,
      onOpenCutoff: _openGroupGameCutoff,
      onOpenSettle: _openGroupGameSettle,
      onSendSettleImage: () {
        unawaited(_onSangongSendSettleReportImage());
      },
      onSendSettleBill: () {
        unawaited(_onSangongSendSettleBillImage());
      },
      onSendPointsImage: () {
        unawaited(_onSangongSendPointsReportImage());
      },
      onSendTrendImage: () {
        unawaited(_onSangongSendTrendReportImage());
      },
      onOpenRulesSettings: _openGroupGameRulesSettings,
      onOpenSetup: () {
        unawaited(_openSangongMyConfigSetup());
      },
    );
  }

  Widget? _buildAgentRebateFloatingEntry(TUITheme theme) {
    if (!_shouldShowAgentRebateFloat()) {
      return null;
    }
    return AgentRebateFloatingEntry(
      theme: theme,
      onOpenDescendants: () {
        unawaited(_openAgentRebateDescendants());
      },
      onOpenRebate: () {
        unawaited(_openAgentRebateCurrent());
      },
      onOpenHistory: () {
        unawaited(_openAgentRebateHistory());
      },
    );
  }

  String _groupNoticeSignature({
    required String groupId,
    required String notice,
    required String owner,
    required int lastInfoTime,
  }) {
    return '$groupId|$owner|$lastInfoTime|$notice';
  }

  String _groupNoticePushSignature({
    required String groupId,
    required String notice,
    required int pushTs,
  }) {
    return '$groupId|push|$pushTs|$notice';
  }

  void _scheduleGroupNoticeRecheck({
    Duration delay = const Duration(milliseconds: 350),
    bool forceRetry = false,
  }) {
    if (_getConvType() != ConvType.group) {
      return;
    }
    Future<void>.delayed(delay, () {
      if (!mounted) {
        return;
      }
      if (!_canShowGroupNoticePopup()) {
        _groupSide.pendingGroupNoticeRecheck = true;
        return;
      }
      if (forceRetry || _groupSide.pendingGroupNoticeRecheck) {
        _groupSide.pendingGroupNoticeRecheck = false;
        unawaited(_recheckGroupNoticeUntilShown());
        return;
      }
      unawaited(_checkAndShowGroupNoticeIfNeeded());
    });
  }

  Future<void> _recheckGroupNoticeUntilShown({
    int maxAttempts = 8,
    Duration firstDelay = const Duration(milliseconds: 220),
    Duration retryDelay = const Duration(milliseconds: 450),
    String? forcedNoticeText,
    int? pushTs,
  }) async {
    if (_getConvType() != ConvType.group) {
      return;
    }
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) {
        return;
      }
      if (attempt > 0) {
        await Future<void>.delayed(retryDelay);
      } else if (firstDelay > Duration.zero) {
        await Future<void>.delayed(firstDelay);
      }
      if (!mounted || !_canShowGroupNoticePopup()) {
        continue;
      }
      if (!_isForegroundGroupChat()) {
        continue;
      }
      final shown = await _checkAndShowGroupNoticeIfNeeded(
        forcedNoticeText: forcedNoticeText,
        pushTs: pushTs,
      );
      if (shown) {
        _groupSide.pendingGroupNoticeRecheck = false;
        return;
      }
    }
  }

  bool _canShowGroupNoticePopup() {
    if (GroupNoticeRefreshBus.instance.isSideProfilePanelOpen) {
      return false;
    }
    return RouteVisibility.isRouteVisible(context);
  }

  bool _isForegroundGroupChat() {
    if (_getConvType() != ConvType.group) {
      return false;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return false;
    }
    final active = ExternalChatEntryService.instance;
    final resolvedId = _resolvedConversationID();
    if (resolvedId.isNotEmpty && active.isVisibleChat(resolvedId)) {
      return true;
    }
    if (active.isVisibleChat('group_$groupId')) {
      return true;
    }
    if (active.isVisibleChat(groupId)) {
      return true;
    }
    if (!_canShowGroupNoticePopup()) {
      return false;
    }
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _handleIncomingGroupNoticePush({
    String? forcedNoticeText,
    int? pushTs,
  }) async {
    if (!_isForegroundGroupChat()) {
      _groupSide.pendingGroupNoticeRecheck = true;
      return;
    }
    final shown = await _checkAndShowGroupNoticeIfNeeded(
      forcedNoticeText: forcedNoticeText,
      pushTs: pushTs,
    );
    if (shown) {
      _groupSide.pendingGroupNoticeRecheck = false;
      return;
    }
    await _recheckGroupNoticeUntilShown(
      maxAttempts: 8,
      firstDelay: Duration.zero,
      retryDelay: const Duration(milliseconds: 300),
      forcedNoticeText: forcedNoticeText,
      pushTs: pushTs,
    );
  }

  void _onGroupNoticeRefreshRequested() {
    final event = GroupNoticeRefreshBus.instance.lastRefresh.value;
    if (event == null) {
      return;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty || event.groupId != groupId) {
      return;
    }
    unawaited(_loadGroupNoticeBanner(forcedText: event.notification));
    if (_isForegroundGroupChat()) {
      unawaited(
        _handleIncomingGroupNoticePush(
          forcedNoticeText: event.notification,
          pushTs: event.pushTs,
        ),
      );
      return;
    }
    _scheduleGroupNoticeRecheck(forceRetry: true);
  }

  void _onGroupRealtimeChanged() {
    final notice = GroupSyncService.instance.lastChanged.value;
    if (notice == null) {
      return;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty ||
        !ChatIdFormat.groupIdsEquivalent(notice.groupId, groupId)) {
      return;
    }
    if (GroupSyncService.memberCountRefreshActions.contains(notice.action)) {
      unawaited(_loadGroupMemberCount());
      _clearMountedDisplayListCache();
      unawaited(
        GroupChangeEventSyncService.instance.syncForGroup(
          groupId,
          reason: 'realtime_${notice.action}',
        ),
      );
      unawaited(_applyGroupTipsOperatorPatches());
      if (!_hasVisibleHistoryMessages()) {
        unawaited(_reloadChatHistoryIfEmpty(reason: 'group_realtime'));
      }
      return;
    }
    if (notice.action == 'group_live_changed') {
      final detail = notice.detail;
      if (detail != null && detail.isNotEmpty) {
        _groupLiveState.applyTcpDetail(
          Map<String, dynamic>.from(detail),
          groupId: groupId,
        );
        final session = _groupLiveState.activeSession;
        if (session == null || !session.status.isActiveSlot) {
          _watchingGroupLive = false;
        }
      }
      // TCP 详情可能缺 liveSessionId / 字段不全：始终用 REST current 校对，
      // 否则主播开推后顶栏会一直停在「有直播」直到杀进程重进。
      unawaited(_loadGroupLiveCurrent());
      _syncChatTopFixState();
      setState(() {});
      return;
    }
    if (notice.action == 'group_mute_all_changed' ||
        notice.action == 'member_muted') {
      unawaited(_refreshChatGroupMuteState());
      return;
    }
    if (notice.action != 'group_notice_changed') {
      return;
    }
    unawaited(_loadGroupNoticeBanner(forcedText: notice.notification));
    unawaited(
      _handleIncomingGroupNoticePush(
        forcedNoticeText: notice.notification,
        pushTs: notice.pushTs,
      ),
    );
  }

  Future<bool> _checkAndShowGroupNoticeIfNeeded({
    String? forcedNoticeText,
    int? pushTs,
  }) async {
    if (_groupSide.checkingGroupNotice || _getConvType() != ConvType.group) {
      return false;
    }
    if (!_canShowGroupNoticePopup()) {
      _groupSide.pendingGroupNoticeRecheck = true;
      return false;
    }
    _groupSide.pendingGroupNoticeRecheck = false;
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return false;
    }
    _groupSide.checkingGroupNotice = true;
    try {
      final record = await GroupInfoResolver.instance.readGroup(groupId);
      final notice = (forcedNoticeText?.trim().isNotEmpty == true
          ? forcedNoticeText!.trim()
          : (record?.notice.trim() ?? ''));
      if (!mounted || notice.isEmpty) {
        return false;
      }

      final owner = (record?.ownerUserId ?? '').trim();
      final lastInfoTime = (record?.noticeUpdatedAt ?? 0) > 0
          ? (record!.noticeUpdatedAt ~/ 1000)
          : 0;
      final signature = pushTs != null
          ? _groupNoticePushSignature(
              groupId: groupId,
              notice: notice,
              pushTs: pushTs,
            )
          : _groupNoticeSignature(
              groupId: groupId,
              notice: notice,
              owner: owner,
              lastInfoTime: lastInfoTime,
            );
      final acked = await GroupNoticeAckService.instance.getAckSignature(
        groupId,
      );
      if (!mounted ||
          GroupNoticeAckService.isAcknowledged(
            ackedSignature: acked,
            currentSignature: signature,
            groupId: groupId,
            notice: notice,
          )) {
        return false;
      }

      await _presentGroupNoticeOverlay(
        notice: notice,
        lastInfoTime: lastInfoTime > 0 ? lastInfoTime : null,
        barrierDismissible: false,
        enableDrag: false,
        onGotIt: (_) async {
          await GroupNoticeAckService.instance.saveAckSignature(
            groupId,
            signature,
          );
        },
      );
      return mounted;
    } finally {
      _groupSide.checkingGroupNotice = false;
    }
  }

  String _formatGroupNoticeTime(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '';
    }
    final ms = timestamp >= 1000000000000 ? timestamp : timestamp * 1000;
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final locale = AppI18n.current.locale.languageTag;
    final lang = locale.startsWith('zh')
        ? 'zh_CN'
        : locale == 'ja'
            ? 'ja'
            : locale == 'ko'
                ? 'ko'
                : 'en';
    final pattern = locale.startsWith('en')
        ? 'MMM d, yyyy HH:mm'
        : locale == 'ja'
            ? 'yyyy/MM/dd HH:mm'
            : locale == 'ko'
                ? 'yyyy.MM.dd HH:mm'
                : 'yyyy年MM月dd日 HH:mm';
    return DateFormat(pattern, lang).format(date);
  }

  String _getHeaderTitleText() {
    final showName = _getTitle();
    if (_getConvType() != ConvType.group || _groupMemberCount == null) {
      return showName;
    }
    return "$showName (${_groupMemberCount!})";
  }

  bool _canShowCallActions() {
    if (_getConvType() != ConvType.c2c) {
      return false;
    }
    return !PlatformOfficialAccountService.showsVerifiedBadge(
      widget.selectedConversation.userID,
    );
  }

  /// 认证号 / 平台公众号：头部头像不可点进聊天设置。
  bool _canOpenChatSettingsFromHeader() {
    if (_getConvType() != ConvType.c2c) {
      return true;
    }
    return !PlatformOfficialAccountService.showsVerifiedBadge(
      widget.selectedConversation.userID,
    );
  }

  VoidCallback? get _chatHeaderProfileTap =>
      _canOpenChatSettingsFromHeader() ? _openConversationProfile : null;

  Future<void> _startHeaderCall({required bool video}) async {
    if (_getConvType() != ConvType.c2c) {
      return;
    }
    _dismissChatInput();
    await CallLauncher.startC2C(
      context,
      userId: widget.selectedConversation.userID ?? '',
      video: video,
      conversationId: _resolvedConversationID(),
    );
  }

  PreferredSizeWidget _chatChromeDividerBar([Color? color]) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(AppTokens.chatChromeDividerWidth),
      child: ColoredBox(
        color: color ?? AppTokens.chatChromeDivider,
        child: const SizedBox(
          height: AppTokens.chatChromeDividerWidth,
          width: double.infinity,
        ),
      ),
    );
  }

  List<Widget> _buildChatHeaderActions(TUITheme theme) {
    if (!_canShowCallActions()) {
      return const [];
    }
    return [
      IconButton(
        tooltip: AppI18n.of(context).t(
          zhHans: '语音通话',
          zhHant: '語音通話',
          en: 'Voice Call',
          ja: '音声通話',
          ko: '음성 통화',
        ),
        onPressed: () => _startHeaderCall(video: false),
        icon: Image.asset(
          'assets/img/call.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          color: const Color(0xFF2D8CFF),
          colorBlendMode: BlendMode.srcIn,
          gaplessPlayback: true,
        ),
      ),
      IconButton(
        tooltip: AppI18n.of(context).t(
          zhHans: '视频通话',
          zhHant: '視訊通話',
          en: 'Video Call',
          ja: 'ビデオ通話',
          ko: '영상 통화',
        ),
        onPressed: () => _startHeaderCall(video: true),
        icon: Image.asset(
          'assets/img/video.webp',
          width: 23,
          height: 23,
          fit: BoxFit.contain,
          color: const Color(0xFF2D8CFF),
          colorBlendMode: BlendMode.srcIn,
          gaplessPlayback: true,
        ),
      ),
    ];
  }

  Future<void> _openConversationProfile() async {
    _dismissChatInput();
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    // 宽屏：单聊 / 群聊统一右侧「设置」边栏。
    if (isWideScreen && widget.showGroupProfile != null) {
      if (_getConvType() == ConvType.c2c) {
        final userID = widget.selectedConversation.userID;
        if (userID == null || userID.isEmpty) {
          return;
        }
        if (PlatformOfficialAccountService.showsVerifiedBadge(userID)) {
          if (PlatformOfficialAccountService.isPlatformOfficialAccount(
            userID,
          )) {
            final intro =
                PlatformOfficialAccountService.introductionFor(userID) ??
                    PlatformOfficialAccountService.resolveShowName(
                      userId: userID,
                      conversationShowName: _getTitle(),
                    );
            if (!mounted) {
              return;
            }
            AppDialog.alert(
              title: _getTitle(),
              message: intro.isNotEmpty
                  ? intro
                  : AppI18n.of(context).t(
                      zhHans: '平台官方通知账号',
                      zhHant: '平台官方通知帳號',
                      en: 'Official platform notice account',
                      ja: '公式プラットフォーム通知アカウント',
                      ko: '플랫폼 공식 알림 계정',
                    ),
              buttonText: AppI18n.of(context).t(
                zhHans: '知道了',
                zhHant: '知道了',
                en: 'Got it',
                ja: '了解',
                ko: '확인',
              ),
            );
          }
          return;
        }
      }
      widget.showGroupProfile!();
      return;
    }
    final conversationType = widget.selectedConversation.type;
    if (conversationType == 1) {
      final userID = widget.selectedConversation.userID;
      if (userID == null || userID.isEmpty) {
        return;
      }
      // 认证号不可进入聊天设置（含 99Messenger / 支付助手等）。
      if (PlatformOfficialAccountService.showsVerifiedBadge(userID)) {
        if (PlatformOfficialAccountService.isPlatformOfficialAccount(userID)) {
          final intro =
              PlatformOfficialAccountService.introductionFor(userID) ??
                  PlatformOfficialAccountService.resolveShowName(
                    userId: userID,
                    conversationShowName: _getTitle(),
                  );
          if (!mounted) {
            return;
          }
          AppDialog.alert(
            title: _getTitle(),
            message: intro.isNotEmpty
                ? intro
                : AppI18n.of(context).t(
                    zhHans: '平台官方通知账号',
                    zhHant: '平台官方通知帳號',
                    en: 'Official platform notice account',
                    ja: '公式プラットフォーム通知アカウント',
                    ko: '플랫폼 공식 알림 계정',
                  ),
            buttonText: AppI18n.of(
              context,
            ).t(zhHans: '知道了', zhHant: '知道了', en: 'Got it', ja: '了解', ko: '확인'),
          );
        }
        return;
      }
      // 单聊头部进入「聊天设置」，不再直达用户资料页。
      await Navigator.push(
        context,
        AppMaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.c2cChatSettings),
          builder: (context) => C2cChatSettingsPage(
            conversation: widget.selectedConversation,
            directToChat: widget.directToChat,
            onRemarkUpdate: (String newRemark) {
              _applyConversationRemarkUpdate(newRemark);
            },
          ),
        ),
      );
      await _loadChatBackground();
      await _recoverChatHistoryAfterOverlayReturn(
        reason: 'return_from_settings',
      );
      return;
    }

    final groupID = widget.selectedConversation.groupID;
    if (groupID == null || groupID.isEmpty) {
      return;
    }
    await Navigator.push(
      context,
      AppMaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.groupProfile),
        builder: (context) => GroupProfilePage(groupID: groupID),
      ),
    );
    _syncConversationMetaFromViewModel();
    await _loadGroupMemberCount();
    await _loadChatBackground();
    await _recoverChatHistoryAfterOverlayReturn(
      reason: 'return_from_profile',
    );
    _scheduleGroupNoticeRecheck(forceRetry: true);
  }

  /// 从盖在 Chat 上的二级页返回后，恢复 registry、解除可能卡住的 open gate，
  /// 列表空则重拉历史；有消息时强制贴底并刷新，避免 Opacity/滚动态导致整页空白。
  ///
  /// 媒体预览/滚动恢复期间的 `route_reactivated` 禁止贴底 + setState：
  /// 列表仍由 preview 路由 maintainState 保活，滚动由 Plan 021
  /// `restoreScrollAfterMediaPreview` 负责；强刷会在下滑关闭时闪一下。
  Future<void> _recoverChatHistoryAfterOverlayReturn({
    required String reason,
  }) async {
    if (!mounted) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final mediaOwnsRestore = reason == 'route_reactivated' &&
        (globalModel.isMediaPreviewOverlayOpen ||
            globalModel.isRestoringScrollAfterMediaPreview);
    if (mediaOwnsRestore) {
      _restoreActiveChatRegistry();
      if (!_hasVisibleHistoryMessages()) {
        await _reloadChatHistoryIfEmpty(reason: reason);
      } else {
        ChatDiagLog.log(
          'ChatHistory',
          'overlay_return_skip_aggressive',
          conversationID: _resolvedConversationID(),
          extras: <String, Object?>{
            'reason': reason,
            'mediaPreviewOpen': globalModel.isMediaPreviewOverlayOpen,
            'restoringScroll': globalModel.isRestoringScrollAfterMediaPreview,
          },
        );
      }
      return;
    }
    _restoreActiveChatRegistry();
    _clearMountedDisplayListCache();
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isNotEmpty &&
        _openLifecycle.openHistoryGate != null &&
        _openLifecycle.openHistoryGateConvKey == convKey) {
      _openLifecycle.openHistoryGate = null;
      ChatHistoryOpenLayoutReady.cancel(convKey);
    }
    if (!_hasVisibleHistoryMessages()) {
      await _reloadChatHistoryIfEmpty(reason: reason);
    } else {
      // 有缓存消息仍空白时：贴底 + 轻量刷新驱动列表重绘。
      try {
        final scroll = _chatController.scrollController;
        if (scroll != null && scroll.hasClients) {
          scroll.jumpTo(scroll.position.minScrollExtent);
        }
      } catch (_) {}
      ChatDiagLog.log(
        'ChatHistory',
        'overlay_return_refresh_ui',
        conversationID: _resolvedConversationID(),
        extras: <String, Object?>{
          'reason': reason,
          'rawCount':
              convKey.isEmpty ? 0 : globalModel.rawMessageCount(convKey),
        },
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reloadChatHistoryIfEmpty({required String reason}) async {
    if (!mounted) {
      return;
    }
    if (_hasVisibleHistoryMessages()) {
      return;
    }
    final convId = _resolvedConversationID();
    final convKey = _getConvID()?.trim() ?? '';
    if (convId.isEmpty ||
        !MessageConversationId.sameConversation(
          ActiveChatRegistry.instance.activeConversationId,
          convId,
        )) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final initialLoaded = globalModel.hasInitialHistoryLoaded(convKey);
    final model = _chatController.model;
    // 冷启动首屏由 UIKit hydrate 独占；post_open 不要抢先塞预览消息造成 1→30 抖动。
    if (!initialLoaded) {
      if (model?.isLoadingChatHistory == true) {
        ChatDiagLog.log(
          'ChatHistory',
          'reload_if_empty_skip_hydrating',
          conversationID: convId,
          extras: <String, Object?>{'reason': reason},
        );
        return;
      }
      if (reason == 'post_open') {
        ChatDiagLog.log(
          'ChatHistory',
          'reload_if_empty_skip_post_open_cold',
          conversationID: convId,
        );
        return;
      }
    }
    final preview = await _fetchConversationPreviewLastMessage();
    final previewMsgId = preview?.msgID?.trim() ?? '';
    // 已确认空会话（清空记录后标了 empty-loaded、且不再可能有更早历史）
    // 且预览也无消息：没有任何可补拉的内容，跳过 local/cloud 双拉，
    // 避免清空后进页对同一空会话反复 setMessageList 的加载风暴。
    if (preview == null &&
        globalModel.hasInitialHistoryLoaded(convKey) &&
        globalModel.rawMessageCount(convKey) == 0 &&
        !globalModel.mayHaveOlderHistory(convKey)) {
      ChatDiagLog.log(
        'ChatHistory',
        'reload_if_empty_skip_confirmed_empty',
        conversationID: convId,
        extras: <String, Object?>{'reason': reason},
      );
      return;
    }
    ChatDiagLog.log(
      'ChatHistory',
      'reload_if_empty_start',
      conversationID: convId,
      extras: <String, Object?>{
        'reason': reason,
        'convKey': convKey,
        'type': _getConvType().name,
        'hasPreviewLastMessage': preview != null,
        'previewMsgId': previewMsgId,
        'entryUnread': widget.entryUnreadCount ?? 0,
        'cachedRaw': serviceLocator<TUIChatGlobalModel>().rawMessageCount(
          convKey,
        ),
        'initialLoaded': serviceLocator<TUIChatGlobalModel>()
            .hasInitialHistoryLoaded(convKey),
      },
    );
    try {
      if (model == null) {
        ChatDiagLog.log(
          'ChatHistory',
          'reload_if_empty_no_model',
          conversationID: convId,
          extras: <String, Object?>{'reason': reason},
        );
        await _chatController.refreshCurrentHistoryList();
        return;
      }
      // 仅在首屏已加载完成时补预览，避免冷启动先显示 1 条再 hydrate 整页抖动。
      if (preview != null && initialLoaded) {
        final merged = await _mergePreviewMessageIfMissing();
        ChatDiagLog.log(
          'ChatHistory',
          'reload_if_empty_preview_merge',
          conversationID: convId,
          extras: <String, Object?>{
            'merged': merged,
            'hasMessages': _hasVisibleHistoryMessages(),
          },
        );
      }
      await model.loadChatRecord(
        count: 20,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
      );
      var hasMessages = _hasVisibleHistoryMessages();
      ChatDiagLog.log(
        'ChatHistory',
        'reload_if_empty_local_done',
        conversationID: convId,
        extras: <String, Object?>{
          'hasMessages': hasMessages,
          'listLen': model.globalModel.rawMessageCount(convKey),
        },
      );
      if (!hasMessages) {
        await model.loadChatRecord(
          count: 20,
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
        );
        hasMessages = _hasVisibleHistoryMessages();
        ChatDiagLog.log(
          'ChatHistory',
          'reload_if_empty_cloud_done',
          conversationID: convId,
          extras: <String, Object?>{
            'hasMessages': hasMessages,
            'listLen': model.globalModel.rawMessageCount(convKey),
          },
        );
      }
      if (hasMessages) {
        serviceLocator<TUIChatGlobalModel>().markInitialHistoryLoaded(convKey);
      } else if (preview != null) {
        // 云端仍空：再 hydrate（含后端归档）。与移动端一致，仅在有预览锚点时补拉。
        final hydrated = await model.hydrateInitialHistoryPeekStyle(
          count: HistoryMessageDartConstant.initialOpenFetchCount,
          plainOpen: true,
        );
        if (!hydrated) {
          await _mergePreviewMessageIfMissing();
        }
        hasMessages = _hasVisibleHistoryMessages();
        ChatDiagLog.log(
          'ChatHistory',
          'reload_if_empty_hydrate_fallback',
          conversationID: convId,
          extras: <String, Object?>{
            'hydrated': hydrated,
            'hasMessages': hasMessages,
            'forcedWebHydrate': false,
          },
        );
        if (hasMessages) {
          serviceLocator<TUIChatGlobalModel>().markInitialHistoryLoaded(
            convKey,
          );
        }
      }
      // 清空后确实无消息：标记 empty-loaded，避免一直 bootstrapping 转圈。
      if (!hasMessages && !globalModel.hasInitialHistoryLoaded(convKey)) {
        final clearedAt =
            await ConversationLocalStore.instance.historyClearedAtMs(convKey);
        final inGrace = ArchiveHistoryProvider.isInHistoryClearGrace(convKey);
        if (clearedAt > 0 ||
            inGrace ||
            reason == 'return_from_profile' ||
            reason == 'return_from_settings') {
          globalModel.clearLocalHistoryAsEmptyLoaded(convKey);
          if (convId.isNotEmpty && convId != convKey) {
            globalModel.clearLocalHistoryAsEmptyLoaded(convId);
          }
          ChatDiagLog.log(
            'ChatHistory',
            'reload_if_empty_mark_empty_loaded',
            conversationID: convId,
            extras: <String, Object?>{
              'reason': reason,
              'clearedAt': clearedAt,
              'inGrace': inGrace,
            },
          );
        }
      }
    } catch (e) {
      ChatDiagLog.log(
        'ChatHistory',
        'reload_if_empty_error',
        conversationID: convId,
        extras: <String, Object?>{'reason': reason, 'error': e.toString()},
      );
      try {
        await _chatController.refreshCurrentHistoryList();
      } catch (_) {}
    }
    ChatDiagLog.log(
      'ChatHistory',
      'reload_if_empty_end',
      conversationID: convId,
      extras: <String, Object?>{
        'reason': reason,
        'hasMessages': _hasVisibleHistoryMessages(),
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _syncConversationMetaFromViewModel() {
    if (!mounted) return;
    final conversationID = _conversation.conversationID;
    var changed = false;
    final isGroup = _getConvType() == ConvType.group;
    final isC2c = _getConvType() == ConvType.c2c;
    final groupId = _conversation.groupID?.trim() ?? '';
    final localRecord = isGroup && groupId.isNotEmpty
        ? GroupLocalStore.instance.readCached(groupId: groupId)
        : null;
    final localFace = localRecord?.avatarUrl.trim() ?? '';
    final localName = localRecord?.groupName.trim() ?? '';
    final hasLocalFace = localFace.isNotEmpty &&
        !UserAvatarHelper.isDefaultPlaceholder(localFace);
    final hasLocalName = localName.isNotEmpty &&
        !GroupDisplayResolver.looksLikeGroupIdLabel(
          localName,
          groupId: groupId,
        );
    final peerId = isC2c ? (_conversation.userID?.trim() ?? '') : '';
    final peerLocal = isC2c && peerId.isNotEmpty
        ? (_peerLocalProfile ??
            UserProfileLocalService.instance.readCached(peerId))
        : null;
    final localPeerFace =
        UserAvatarHelper.usableAvatarOrEmpty(peerLocal?.avatarUrl);
    final localPeerName = peerLocal == null
        ? ''
        : (peerLocal.friendRemark.trim().isNotEmpty
            ? peerLocal.friendRemark.trim()
            : peerLocal.nickname.trim());
    if (conversationID.isNotEmpty) {
      for (final conv in _conversationViewModel.conversationList) {
        if (conv?.conversationID == conversationID) {
          final latestUrl = conv?.faceUrl ?? '';
          if (latestUrl.isNotEmpty &&
              latestUrl != (_conversation.faceUrl ?? '')) {
            final shouldApplyFace = isGroup
                ? (!hasLocalFace || latestUrl == localFace)
                : (!isC2c ||
                    localPeerFace.isEmpty ||
                    latestUrl == localPeerFace);
            if (shouldApplyFace) {
              if (isGroup) {
                _logGroupHeaderAvatarSource(
                  source: 'conversation_model_update',
                  currentFaceUrl: _conversation.faceUrl ?? '',
                  candidateFaceUrl: latestUrl,
                  applied: true,
                );
              }
              _conversation.faceUrl = latestUrl;
              widget.selectedConversation.faceUrl = latestUrl;
              changed = true;
            } else if (isGroup) {
              // Local avatar wins; skip path must not mark changed / rebuild.
              // Profile-only log — no further work.
              if (kProfileMode) {
                _logGroupHeaderAvatarSource(
                  source: 'conversation_model_update_skipped_local_newer',
                  currentFaceUrl: _conversation.faceUrl ?? '',
                  candidateFaceUrl: latestUrl,
                  applied: false,
                );
              }
            }
          }
          final latestShowName = conv?.showName?.trim() ?? '';
          if (latestShowName.isNotEmpty &&
              latestShowName != (_conversation.showName?.trim() ?? '')) {
            final shouldApplyName = isGroup
                ? (!hasLocalName || latestShowName == localName)
                : (!isC2c ||
                    localPeerName.isEmpty ||
                    latestShowName == localPeerName);
            if (shouldApplyName) {
              _conversation.showName = latestShowName;
              widget.selectedConversation.showName = latestShowName;
              changed = true;
            }
          }
          break;
        }
      }
    }
    if (isGroup && hasLocalFace) {
      final currentFace = (_conversation.faceUrl ?? '').trim();
      if (localFace != currentFace) {
        _conversation.faceUrl = localFace;
        widget.selectedConversation.faceUrl = localFace;
        changed = true;
      }
    }
    if (isGroup && hasLocalName) {
      final currentName = (_conversation.showName ?? '').trim();
      if (localName != currentName) {
        _conversation.showName = localName;
        widget.selectedConversation.showName = localName;
        changed = true;
      }
    }
    if (isC2c && localPeerFace.isNotEmpty) {
      final currentFace = (_conversation.faceUrl ?? '').trim();
      if (localPeerFace != currentFace) {
        _conversation.faceUrl = localPeerFace;
        widget.selectedConversation.faceUrl = localPeerFace;
        _resolvedPeerFaceUrl = localPeerFace;
        _resolvedPeerFaceUrlForId = peerId;
        changed = true;
      }
    }
    if (isC2c && localPeerName.isNotEmpty) {
      final currentName = (_conversation.showName ?? '').trim();
      if (localPeerName != currentName) {
        _conversation.showName = localPeerName;
        widget.selectedConversation.showName = localPeerName;
        changed = true;
      }
    }
    if (PlatformOfficialAccountService.isPlatformOfficialAccount(
      _conversation.userID,
    )) {
      final resolved = PlatformOfficialAccountService.resolveFaceUrl(
        userId: _conversation.userID,
        conversationFaceUrl: _conversation.faceUrl,
      );
      if (resolved.isNotEmpty && resolved != (_conversation.faceUrl ?? '')) {
        _conversation.faceUrl = resolved;
        widget.selectedConversation.faceUrl = resolved;
        changed = true;
      }
    }
    final faceUrl = _conversation.faceUrl ?? '';
    final showName = _conversation.showName ?? '';
    if (!changed &&
        faceUrl == (_cachedHeaderFaceUrl ?? '') &&
        showName == (_cachedHeaderShowName ?? '')) {
      return;
    }
    _cachedHeaderFaceUrl = faceUrl;
    _cachedHeaderShowName = showName;
    _syncChatHeaderState();
  }

  void _onConversationViewModelChanged() {
    _syncConversationMetaFromViewModel();
  }

  Future<void> _onTapAvatar(
    String userID,
    TapDownDetails tapDetails,
    TUITheme theme,
  ) async {
    final id = userID.trim();
    if (id.isEmpty) {
      return;
    }
    _dismissChatInput();
    if (ProfilePageNav.isSelfUser(id)) {
      await ProfilePageNav.openMyProfileDetail(context);
      if (!mounted) {
        return;
      }
      _refreshSelfMessageAvatars();
      await _recoverChatHistoryAfterOverlayReturn(
        reason: 'return_from_my_profile',
      );
      return;
    }
    // 认证号气泡头像不可点进资料/设置。
    if (PlatformOfficialAccountService.showsVerifiedBadge(id)) {
      if (PlatformOfficialAccountService.isPlatformOfficialAccount(id)) {
        final intro = PlatformOfficialAccountService.introductionFor(id) ??
            PlatformOfficialAccountService.resolveShowName(
              userId: id,
              conversationShowName: _getTitle(),
            );
        if (!mounted) {
          return;
        }
        await AppDialog.alert(
          title: _getTitle(),
          message: intro.isNotEmpty
              ? intro
              : AppI18n.of(context).t(
                  zhHans: '平台官方通知账号',
                  zhHant: '平台官方通知帳號',
                  en: 'Official platform notice account',
                  ja: '公式プラットフォーム通知アカウント',
                  ko: '플랫폼 공식 알림 계정',
                ),
          buttonText: AppI18n.of(
            context,
          ).t(zhHans: '知道了', zhHant: '知道了', en: 'Got it', ja: '了解', ko: '확인'),
        );
      }
      return;
    }

    GroupAtMentionTarget? groupMember;
    if (_getConvType() == ConvType.group) {
      groupMember = GroupAtMention.resolveMember(
        _chatController.getGroupMemberList(),
        id,
      );
    }

    if (!mounted) {
      return;
    }
    final friendDeleted = await ProfilePageNav.openUserProfileOrAddFriend(
      context,
      userID: id,
      nickname: groupMember?.displayName,
      avatarUrl: groupMember?.faceUrl,
      addSource: _getConvType() == ConvType.group
          ? FriendAddSource.card
          : FriendAddSource.chat,
      groupId: _getConvType() == ConvType.group
          ? widget.selectedConversation.groupID
          : null,
      onRemarkUpdate: (String newRemark) {
        _applyConversationRemarkUpdate(newRemark);
      },
    );
    if (friendDeleted && mounted && _getConvType() == ConvType.c2c) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_getConvType() == ConvType.c2c) {
      unawaited(_loadPeerFaceUrl());
      unawaited(_loadPeerLocalProfile());
    }
    await _loadChatBackground();
    if (!mounted) {
      return;
    }
    await _recoverChatHistoryAfterOverlayReturn(
      reason: 'return_from_avatar_profile',
    );
  }

  /// 仅写入 [TIMUIKitChatBackgroundRegistry]；勿因背景加载而 setState 更换 TIMUIKitChat 的 Key。
  Future<void> _loadChatBackground() async {
    final conversationId = _resolvedConversationID();
    if (conversationId.isEmpty ||
        PlatformOfficialAccountService.isPlatformOfficialAccount(
          widget.selectedConversation.userID,
        ) ||
        ChatBackgroundService.isOfficialAccountConversationId(conversationId)) {
      if (conversationId.isNotEmpty) {
        TIMUIKitChatBackgroundRegistry.clearPath(conversationId);
      }
      return;
    }
    await ChatBackgroundService.instance.getBackgroundPathWithGlobalFallback(
      conversationId,
    );
  }

  void _schedulePostOpenTasks() {
    if (_openLifecycle.postOpenTasksScheduled) return;
    final taskGeneration = _openLifecycle.beginPostOpenTasks();
    final schedulerGeneration = _postOpenScheduler.beginRun();
    final scheduledConversationId = _resolvedConversationID();

    bool canRun() {
      return taskGeneration == _openLifecycle.postOpenTasksGeneration &&
          _isCurrentConversation(scheduledConversationId);
    }

    Future<void> runTasks() async {
      if (!canRun()) return;
      await _openLifecycle.waitForOpenHistoryPreparationGate();
      if (!canRun()) return;
      ChatOpenPerfLog.mark(
        'post_open_tasks_run',
        extras: <String, Object?>{'isGroup': _getConvType() == ConvType.group},
      );
      ChatJitterDiag.log(
        'post_open_tasks',
        extras: const <String, Object?>{'source': 'route_animation_or_delay'},
      );
      unawaited(_loadChatBackground());
      unawaited(_loadChatLocalDraft());
      _prepareOfficialAccountChat();
      if (_getConvType() == ConvType.group) {
        final groupId = ChatIdFormat.normalizeGroupId(
          widget.selectedConversation.groupID,
        );
        if (groupId.isNotEmpty) {
          // 与进页成员最小集错峰；本地已 seed 时只做权威补证。
          final muteGeneration = _openLifecycle.muteFetchGeneration;
          _postOpenScheduler.schedule(
            generation: schedulerGeneration,
            delay: ChatPostOpenScheduler.muteNetworkDelay,
            canRun: canRun,
            task: () {
              if (!mounted ||
                  muteGeneration != _openLifecycle.muteFetchGeneration) {
                return;
              }
              ChatOpenPerfLog.mark('mute_network_fetch_start');
              unawaited(_fetchAndStoreBackendMuteStatus(groupId));
            },
          );
        }
      }
      _postOpenScheduler.schedule(
        generation: schedulerGeneration,
        delay: ChatPostOpenScheduler.p1Delay,
        canRun: canRun,
        task: () {
          if (!canRun()) return;
          unawaited(_loadGroupMemberCount());
          unawaited(_loadGroupNoticeBanner());
          _checkAndShowGroupNoticeIfNeeded();
        },
      );
      _postOpenScheduler.schedule(
        generation: schedulerGeneration,
        delay: ChatPostOpenScheduler.p2Delay,
        canRun: canRun,
        task: () {
          if (!canRun()) return;
          unawaited(_loadGroupGameStatus());
          unawaited(_loadAgentRebateIdentity());
          unawaited(_loadGroupLiveCurrent());
        },
      );
      _postOpenScheduler.schedule(
        generation: schedulerGeneration,
        delay: ChatPostOpenScheduler.idleDelay,
        canRun: canRun,
        task: () {
          if (!canRun()) return;
          if (!CallLifecycleService.instance.isInActiveCall) {
            unawaited(SoundPlayer.ensurePlaybackReady());
          }
          unawaited(
            _retryWalletCardsForConversation(
              source: WalletCardSendSource.autoRetry,
            ),
          );
          if (!_hasVisibleHistoryMessages()) {
            unawaited(_reloadChatHistoryIfEmpty(reason: 'post_open'));
          }
        },
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation != null && !animation.isCompleted) {
        void listener(AnimationStatus status) {
          if (status != AnimationStatus.completed &&
              status != AnimationStatus.dismissed) {
            return;
          }
          _removeRouteTransitionListener(animation, listener);
          if (status == AnimationStatus.completed) {
            unawaited(runTasks());
          }
        }

        _addRouteTransitionListener(animation, listener);
        return;
      }
      _postOpenScheduler.schedule(
        generation: schedulerGeneration,
        delay: ChatPostOpenScheduler.routeFallbackDelay,
        canRun: canRun,
        task: () => unawaited(runTasks()),
      );
    });
  }

  Future<bool> _ensureCallPermissions(bool isVideo) {
    return PermissionGuard.call(context, video: isVideo);
  }

  Iterable<String> _externalEntryMessageKeys() sync* {
    final conversationID = _resolvedConversationID();
    if (conversationID.isNotEmpty) {
      yield conversationID;
    }
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isNotEmpty && convKey != conversationID) {
      yield convKey;
    }
  }

  bool _hasVisibleHistoryMessages() {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (final key in _externalEntryMessageKeys()) {
      if (globalModel.messageListMap[key]?.isNotEmpty == true) {
        return true;
      }
    }
    return false;
  }

  List<V2TimMessage> _visibleHistoryMessagesForExternalEntry() {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (final key in _externalEntryMessageKeys()) {
      final list = globalModel.messageListMap[key];
      if (list != null && list.isNotEmpty) {
        return List<V2TimMessage>.from(list);
      }
    }
    return const <V2TimMessage>[];
  }

  String _latestVisibleMessageId() {
    for (final message in _visibleHistoryMessagesForExternalEntry()) {
      if (ConversationPreviewHistorySync.isSyntheticLocalMessage(message)) {
        continue;
      }
      final msgID = message.msgID?.trim() ?? '';
      if (msgID.isNotEmpty &&
          !ConversationPreviewHistorySync.isSyntheticLocalAnchorId(msgID)) {
        return msgID;
      }
      final id = message.id?.trim() ?? '';
      if (id.isNotEmpty &&
          !ConversationPreviewHistorySync.isSyntheticLocalAnchorId(id)) {
        return id;
      }
    }
    return '';
  }

  String _latestRealVisibleMessageId() {
    for (final message in _visibleHistoryMessagesForExternalEntry()) {
      if (_localCallBubbleMarker(message) != null) {
        continue;
      }
      if (ConversationPreviewHistorySync.isSyntheticLocalMessage(message)) {
        continue;
      }
      final msgID = message.msgID?.trim() ?? '';
      if (msgID.isNotEmpty &&
          !ConversationPreviewHistorySync.isSyntheticLocalAnchorId(msgID)) {
        return msgID;
      }
    }
    return '';
  }

  bool _isForegroundRecoveryReason(String? source) {
    return _foregroundRecoveryReasons.contains(source);
  }

  List<Duration> _resolveRecoveryRetryDelays(
    String? source, {
    required bool hasVisibleMessages,
    required bool previewAhead,
  }) {
    if (_isForegroundRecoveryReason(source)) {
      final cloudCatchUpRequired = warm_resume.shouldAllowCloudCatchUp(
            source: source,
            previewAhead: previewAhead,
          ) &&
          !previewAhead;
      return ResumeForegroundPolicy.chatRecoveryRetryDelays(
        hasVisibleMessages: hasVisibleMessages,
        previewAhead: previewAhead,
        cloudCatchUpRequired: cloudCatchUpRequired,
      );
    }
    return const <Duration>[
      Duration.zero,
      Duration(milliseconds: 350),
      Duration(milliseconds: 900),
    ];
  }

  Future<V2TimMessage?> _fetchConversationPreviewLastMessage() async {
    final conversationID = _resolvedConversationID();
    if (conversationID.isNotEmpty) {
      final clearedAt = await ConversationLocalStore.instance
          .historyClearedAtMs(conversationID);
      if (clearedAt > 0) {
        final direct = widget.selectedConversation.lastMessage;
        final directMs = ConversationLocalStore.messageTimestampMs(direct);
        if (direct == null || directMs <= clearedAt) {
          final local = await ConversationLocalStore.instance.conversationById(
            conversationID,
          );
          final localLast = local?.lastMessage;
          final localMs = ConversationLocalStore.messageTimestampMs(localLast);
          if (localLast == null || localMs <= clearedAt) {
            return null;
          }
          return localLast;
        }
      }
    }
    final direct = widget.selectedConversation.lastMessage;
    if (direct != null) {
      return direct;
    }
    if (conversationID.isEmpty) {
      return null;
    }
    final local = await ConversationLocalStore.instance.conversationById(
      conversationID,
    );
    if (local?.lastMessage != null) {
      return local!.lastMessage;
    }
    return ConversationPreviewHistorySync.resolvePreviewLastMessage(
      widget.selectedConversation,
    );
  }

  bool _isMessageVisibleInHistory(V2TimMessage message) {
    return ConversationPreviewHistorySync.isMessageVisibleInList(
      message,
      _visibleHistoryMessagesForExternalEntry(),
    );
  }

  Future<bool> _conversationPreviewAheadOfHistory() async {
    final preview = await _fetchConversationPreviewLastMessage();
    return ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
      preview: preview,
      cached: _visibleHistoryMessagesForExternalEntry(),
    );
  }

  String _resolveLatestPullAnchorId() {
    final realAnchor = _latestRealVisibleMessageId();
    if (realAnchor.isNotEmpty) {
      return realAnchor;
    }
    return _latestVisibleMessageId();
  }

  String _conversationRecoveryKey() {
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isNotEmpty) {
      return MessageConversationId.normalizeComparableKey(convKey);
    }
    return MessageConversationId.normalizeComparableKey(
      _resolvedConversationID(),
    );
  }

  void _recordRecoverySuccess() {
    ChatHistoryRecoveryCoordinator.instance.recordSuccessfulRecovery(
      _conversationRecoveryKey(),
    );
  }

  Future<bool> _pullLatestMessagesFromAnchor({
    required TUIChatSeparateViewModel model,
    required String source,
    bool allowCloudPull = true,
  }) async {
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isNotEmpty &&
        globalModel.isReadingHistory(convKey) &&
        !globalModel.memoryWindowMissingNewer(convKey)) {
      ExternalChatEntryService.instance.logFlow(
        'anchor_skip_reading_history',
        source: source,
        conversationID: _resolvedConversationID(),
      );
      return false;
    }
    final beforeSignature = _visibleHistorySignature();
    final anchorId = _resolveLatestPullAnchorId();
    if (anchorId.isNotEmpty &&
        ConversationPreviewHistorySync.isSyntheticLocalAnchorId(anchorId)) {
      ExternalChatEntryService.instance.logFlow(
        'anchor_skip_synthetic_local',
        source: source,
        conversationID: _resolvedConversationID(),
        extras: <String, Object?>{'anchorMsgID': anchorId},
      );
      _clearMountedDisplayListCache();
      await _chatController.refreshCurrentHistoryList();
      return beforeSignature != _visibleHistorySignature();
    }
    if (anchorId.isNotEmpty) {
      await model.loadChatRecord(
        count: 20,
        lastMsgID: anchorId,
        direction: LoadDirection.latest,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG,
      );
      if (beforeSignature != _visibleHistorySignature()) {
        return true;
      }
      if (allowCloudPull) {
        await model.loadChatRecord(
          count: 20,
          lastMsgID: anchorId,
          direction: LoadDirection.latest,
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG,
        );
        if (beforeSignature != _visibleHistorySignature()) {
          return true;
        }
      }
      ExternalChatEntryService.instance.logFlow(
        'anchor_invalid_local',
        source: source,
        conversationID: _resolvedConversationID(),
        extras: <String, Object?>{'anchorMsgID': anchorId},
      );
      _clearMountedDisplayListCache();
      await _chatController.refreshCurrentHistoryList();
      return beforeSignature != _visibleHistorySignature();
    }
    if (!_hasVisibleHistoryMessages()) {
      await model.loadChatRecord(
        count: 20,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
      );
      if (beforeSignature != _visibleHistorySignature()) {
        return true;
      }
      await model.loadChatRecord(
        count: 20,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
      );
      return beforeSignature != _visibleHistorySignature();
    }
    return false;
  }

  Future<bool> _mergePreviewMessageIfMissing() async {
    // Conversation previews are summaries, not authoritative chat messages.
    // Official Tencent IM conversations must wait for SDK history; otherwise a
    // preview stub can appear as a fake/duplicate bubble.
    final historyModel = _chatController.model;
    if (historyModel?.usesOfficialSdkHistory == true) {
      return false;
    }
    final preview = await _fetchConversationPreviewLastMessage();
    if (preview == null) {
      return false;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isEmpty) {
      return false;
    }
    final existing =
        globalModel.messageListMap[convKey] ?? const <V2TimMessage>[];
    // bootstrap / peek 已灌窗：禁止再 merge 会话 preview stub（常缺 seq/msgID/textElem）。
    if (globalModel.hasInitialHistoryLoaded(convKey) && existing.isNotEmpty) {
      ChatDiagLog.log(
        'ChatHistory',
        'skip_preview_merge_warm_loaded',
        conversationID: _resolvedConversationID(),
        extras: <String, Object?>{
          'existingLen': existing.length,
          'previewMsgId': preview.msgID ?? '',
          'previewTs': preview.timestamp ?? 0,
        },
      );
      return false;
    }
    if (existing.any(
      (item) => TUIChatGlobalModel.messagesCorrelateForDedup(item, preview),
    )) {
      return false;
    }
    if (_isMessageVisibleInHistory(preview)) {
      return false;
    }
    // 本地 tip 不能灌进空聊天页，否则会连带触发 tip 历史整库回灌。
    if (ConversationPreviewHistorySync.isSyntheticLocalMessage(preview)) {
      ChatDiagLog.log(
        'ChatHistory',
        'skip_preview_merge_local_tip',
        conversationID: _resolvedConversationID(),
        extras: <String, Object?>{'previewMsgId': preview.msgID ?? ''},
      );
      return false;
    }
    if (GroupTipsMessageHelper.isGroupCreateRedundantWithHistory(
      preview,
      _visibleHistoryMessagesForExternalEntry(),
    )) {
      ChatDiagLog.log(
        'ChatHistory',
        'skip_preview_merge_group_create',
        conversationID: _resolvedConversationID(),
        extras: <String, Object?>{'previewMsgId': preview.msgID ?? ''},
      );
      return false;
    }
    final merged = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: existing,
      fetched: <V2TimMessage>[preview],
    );
    globalModel.setMessageList(
      convKey,
      merged,
      needResetNewMessageCount: false,
      replace: true,
    );
    return true;
  }

  Future<bool> _refreshChatHistoryLegacyFallback({
    required TUIChatSeparateViewModel model,
    required String source,
    required String current,
    required String beforeSignature,
  }) async {
    final historyModel = _chatController.model;
    if (historyModel?.usesOfficialSdkHistory == true) {
      // Normal IM conversations must not fall through to legacy/local/archive
      // recovery. The SDK cloud history path is authoritative.
      await historyModel!.loadChatRecord(
        count: 20,
        lastMsgID: _latestRealVisibleMessageId().isEmpty
            ? null
            : _latestRealVisibleMessageId(),
        direction: LoadDirection.latest,
        forceReloadNewest: true,
      );
      return true;
    }
    final latestAnchorId = _latestVisibleMessageId();
    if (latestAnchorId.isNotEmpty) {
      await model.loadChatRecord(
        count: 20,
        lastMsgID: latestAnchorId,
        direction: LoadDirection.latest,
      );
      if (beforeSignature != _visibleHistorySignature()) {
        ExternalChatEntryService.instance.logFlow(
          'history_latest_load_done',
          source: source,
          conversationID: current,
          extras: <String, Object?>{
            'anchorMsgID': latestAnchorId,
            'changed': true,
            'hasMessages': _hasVisibleHistoryMessages(),
          },
        );
        return true;
      }
    }
    await model.loadChatRecord(
      count: 20,
      getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    );
    if (_hasVisibleHistoryMessages()) {
      ExternalChatEntryService.instance.logFlow(
        'history_local_load_done',
        source: source,
        conversationID: current,
        extras: <String, Object?>{'hasMessages': true},
      );
      return true;
    }
    await model.loadChatRecord(
      count: 20,
      getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
    );
    if (_hasVisibleHistoryMessages()) {
      ExternalChatEntryService.instance.logFlow(
        'history_cloud_load_done',
        source: source,
        conversationID: current,
        extras: <String, Object?>{'hasMessages': true},
      );
      return true;
    }
    await _chatController.refreshCurrentHistoryList();
    ExternalChatEntryService.instance.logFlow(
      'history_fallback_refresh_done',
      source: source,
      conversationID: current,
      extras: <String, Object?>{'hasMessages': _hasVisibleHistoryMessages()},
    );
    return _hasVisibleHistoryMessages();
  }

  String _visibleHistorySignature() {
    return _historyListTrackingSignature(
      _visibleHistoryMessagesForExternalEntry(),
    );
  }

  void _publishExternalEntryState({bool? routeVisible}) {
    final conversationID = _resolvedConversationID();
    if (conversationID.isEmpty) {
      return;
    }
    final isVisible = routeVisible ?? RouteVisibility.isRouteVisible(context);
    final hasMessages = _hasVisibleHistoryMessages();
    final signature = '$conversationID|$isVisible|$hasMessages';
    if (_lastPublishedExternalEntryState == signature) {
      return;
    }
    _lastPublishedExternalEntryState = signature;
    if (hasMessages &&
        isVisible &&
        !_openLifecycle.scheduledVisibleSdkUnreadClean &&
        (widget.entryUnreadCount ?? 0) > 0) {
      _openLifecycle.scheduledVisibleSdkUnreadClean = true;
      unawaited(
        ConversationUnreadClearService.scheduleSdkUnreadClean(
          conversationID: conversationID,
          trigger: SdkUnreadCleanTrigger.chatVisible,
          hadUnread: true,
        ),
      );
    }
    ExternalChatEntryService.instance.updateActiveChatState(
      conversationID: conversationID,
      isRouteVisible: isVisible,
      hasVisibleMessages: hasMessages,
    );
  }

  void _scheduleExternalEntryStatePublish({required bool routeVisible}) {
    _pendingExternalEntryRouteVisible = routeVisible;
    if (_externalEntryPublishScheduled) {
      return;
    }
    _externalEntryPublishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _externalEntryPublishScheduled = false;
      if (!mounted) {
        return;
      }
      final visible = _pendingExternalEntryRouteVisible;
      _pendingExternalEntryRouteVisible = null;
      _publishExternalEntryState(routeVisible: visible);
    });
  }

  void _clearExternalEntryState([String? conversationID]) {
    ExternalChatEntryService.instance.clearActiveChatState(
      conversationID ?? _resolvedConversationID(),
    );
    _lastPublishedExternalEntryState = null;
  }

  bool _shouldSkipExternalHistoryRefreshDuringOpen(String reason) {
    final normalized = reason.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final isOpenNoise = normalized == 'chat_init' ||
        normalized == 'chat_open' ||
        normalized.startsWith('group_change_event_sync') ||
        normalized.startsWith('realtime_') ||
        normalized.startsWith('sync_full_');
    final isOptimisticOutbound =
        ChatHistoryRefreshBus.isOptimisticOutboundReason(normalized);
    if (!isOpenNoise && !isOptimisticOutbound) {
      return false;
    }
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isEmpty) {
      return false;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    return globalModel.hasInitialHistoryLoaded(convKey) &&
        globalModel.rawMessageCount(convKey) > 0;
  }

  Future<void> _scheduleDeferredGroupChangeSync(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (var attempt = 0; attempt < 50; attempt++) {
      if (!mounted) {
        return;
      }
      if (globalModel.hasInitialHistoryLoaded(id) ||
          globalModel.rawMessageCount(id) > 0) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      continue;
    }
    if (!mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }
    await _runChatInitGroupSyncWhenIdle(id);
  }

  /// chat_init 补偿：仅在列表空闲时跑，滑动中则短推迟。
  Future<void> _runChatInitGroupSyncWhenIdle(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty || !mounted) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (var idleAttempt = 0; idleAttempt < 40; idleAttempt++) {
      if (!mounted) {
        return;
      }
      if (!globalModel.isChatListUserScrolling) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    if (!mounted) {
      return;
    }
    if (globalModel.isChatListUserScrolling) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) {
          return;
        }
        unawaited(_runChatInitGroupSyncWhenIdle(id));
      }));
      return;
    }
    await GroupChangeEventSyncService.instance.syncForGroup(
      id,
      reason: 'chat_init',
    );
    unawaited(
      GroupMemberIncrementalSyncService.instance.syncForGroup(
        id,
        reason: 'chat_init',
      ),
    );
    await _applyGroupTipsOperatorPatches();
  }

  Future<void> _applyGroupTipsOperatorPatches() async {
    if (!SelfHostedGroupBridge.enabled) {
      return;
    }
    final groupId = widget.selectedConversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    await GroupTipsOperatorPatchService.instance.applyPatchesForVisibleGroup(
      groupId,
    );
  }

  Future<void> _activatePendingExternalEntryOnInit() async {
    final current = _resolvedConversationID();
    final target =
        ChatHistoryRefreshBus.instance.lastConversationId?.trim() ?? '';
    if (!mounted || current.isEmpty || !_matchesRefreshConversationId(target)) {
      _publishExternalEntryState();
      return;
    }
    final convKey = _getConvID()?.trim() ?? '';
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    if (convKey.isNotEmpty &&
        globalModel.hasInitialHistoryLoaded(convKey) &&
        globalModel.rawMessageCount(convKey) > 0) {
      _publishExternalEntryState();
      return;
    }
    ExternalChatEntryService.instance.logFlow(
      'chat_init_activation',
      source: 'chat_page',
      conversationID: current,
      extras: <String, Object?>{
        'reason': ChatHistoryRefreshBus.instance.lastReason,
      },
    );
    if (!mounted) {
      return;
    }
    await _refreshChatHistoryFromExternalEntry();
  }

  void _schedulePostOpenFailedMessageRetry() {
    _retryLoadedFailedChatMessages();
  }

  Future<void> _refreshHistoryIfPreviewAheadOnOpen(
    String convId,
    List<V2TimMessage> cachedMessages,
  ) async {
    final previewAhead = await _conversationPreviewAheadOfHistory();
    if (!mounted || !previewAhead) {
      return;
    }
    if (ChatHistoryRecoveryCoordinator.instance.shouldSkipForegroundRecovery(
      conversationKey: _conversationRecoveryKey(),
      hasVisibleMessages: cachedMessages.isNotEmpty,
      previewAhead: previewAhead,
      reason: ConversationPreviewHistorySync.previewAheadOnOpenReason,
    )) {
      return;
    }
    ChatHistoryRefreshBus.instance.requestRefresh(
      conversationId: _resolvedConversationID().isNotEmpty
          ? _resolvedConversationID()
          : convId,
      reason: ConversationPreviewHistorySync.previewAheadOnOpenReason,
    );
  }

  String _historyListTrackingSignature(List<V2TimMessage> messages) {
    if (messages.isEmpty) {
      return 'empty';
    }
    final meaningful = messages
        .where(
          (message) =>
              !ConversationPreviewHistorySync.isSyntheticLocalMessage(message),
        )
        .map(_messageMountIdentity)
        .toList(growable: false);
    if (meaningful.isEmpty) {
      return 'local_only|${messages.length}';
    }
    return '${messages.length}|${meaningful.first}|${meaningful.length}';
  }

  bool _listHasCorrelatingDup(List<V2TimMessage> messages) {
    if (messages.length < 2) {
      return false;
    }
    final scanCount = messages.length < 24 ? messages.length : 24;
    for (var i = 0; i < scanCount; i++) {
      for (var j = i + 1; j < scanCount; j++) {
        if (TUIChatGlobalModel.messagesCorrelateForDedup(
          messages[i],
          messages[j],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  void _onChatGlobalModelChanged() {
    if (!mounted) {
      return;
    }
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isEmpty) {
      return;
    }
    final globalModel = _chatGlobalModel;
    if (globalModel == null) {
      return;
    }
    final messages = globalModel.messageListMap[convKey] ??
        globalModel.messageListMap[_resolvedConversationID()] ??
        const <V2TimMessage>[];
    var count = messages.length;
    if ((count > _trackedGlobalMessageCount ||
            _listHasCorrelatingDup(messages)) &&
        messages.isNotEmpty) {
      final deduped = TUIChatGlobalModel.dedupeMessages(messages);
      if (deduped.length < count) {
        globalModel.setMessageList(
          convKey,
          deduped,
          needResetNewMessageCount: false,
          replace: true,
        );
        return;
      }
    }
    final revision = globalModel.messageListRevisionFor(convKey);
    final signature = _historyListTrackingSignature(messages);
    if (count == _trackedGlobalMessageCount &&
        revision == _trackedGlobalMessageRevision &&
        signature == _trackedGlobalLastMsgId) {
      return;
    }
    _trackedGlobalMessageCount = count;
    _trackedGlobalMessageRevision = revision;
    _trackedGlobalLastMsgId = signature;
    if (_hasMultipleCallMessagesForMount(messages)) {
      CallBubbleDedupe.scheduleDedupeConversation(
        convKey,
        reason: 'model_multi_call',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _c2cPermission.onTransitionToBlocked = _syncInFlightOutgoingOnC2cBlocked;
    _groupLiveState.addListener(_onGroupLiveStateChanged);
    GroupLiveIndexStore.instance.addListener(_onGroupLiveIndexStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(DiceAssetWarmup.warm(context));
    });
    _openLifecycle.clearedExternalEntryOnDeactivate = false;
    ConversationDeletedBus.instance.revision.addListener(
      _onConversationDeletedBus,
    );
    _conversation = _normalizedConversationForChat(widget.selectedConversation);
    if (_getConvType() == ConvType.c2c) {
      final peerId = widget.selectedConversation.userID?.trim() ?? '';
      if (peerId.isNotEmpty) {
        _peerLocalProfile = UserProfileLocalService.instance.readCached(peerId);
        final cachedFace = UserAvatarHelper.usableAvatarOrEmpty(
          _peerLocalProfile?.avatarUrl,
        );
        if (cachedFace.isNotEmpty) {
          _resolvedPeerFaceUrl = cachedFace;
          _resolvedPeerFaceUrlForId = peerId;
          _conversation.faceUrl = cachedFace;
          widget.selectedConversation.faceUrl = cachedFace;
        }
      }
    }
    final openedConversationId = _resolvedConversationID();
    final openConvKey = _getConvID()?.trim() ?? '';
    if (openConvKey.isNotEmpty) {
      CallBubbleDedupe.beginOpenHold(openConvKey);
    } else if (openedConversationId.isNotEmpty) {
      CallBubbleDedupe.beginOpenHold(openedConversationId);
    }
    final openPreview = widget.selectedConversation.lastMessage;
    final openGlobal = serviceLocator<TUIChatGlobalModel>();
    final openWarm = openConvKey.isEmpty
        ? const <V2TimMessage>[]
        : (openGlobal.messageListMap[openConvKey] ?? const <V2TimMessage>[]);
    final openWarmNewest =
        openWarm.isEmpty ? 0 : (openWarm.first.timestamp ?? 0);
    final openWarmOldest =
        openWarm.isEmpty ? 0 : (openWarm.last.timestamp ?? 0);
    ChatDiagLog.log(
      'ChatHistory',
      'chat_open',
      conversationID: openedConversationId,
      extras: <String, Object?>{
        'convKey': openConvKey,
        'type': _getConvType().name,
        'entryUnread': widget.entryUnreadCount ?? 0,
        'hasLastMessage': openPreview != null,
        'lastMsgId': openPreview?.msgID?.trim() ?? '',
        'cachedRaw':
            openConvKey.isEmpty ? 0 : openGlobal.rawMessageCount(openConvKey),
        'initialLoaded': openConvKey.isEmpty
            ? false
            : openGlobal.hasInitialHistoryLoaded(openConvKey),
        'warmNewestTs': openWarmNewest,
        'warmOldestTs': openWarmOldest,
        'warmNewestId':
            openWarm.isEmpty ? '' : (openWarm.first.msgID?.trim() ?? ''),
        'rawAlsoCached':
            openedConversationId.isEmpty || openedConversationId == openConvKey
                ? 0
                : openGlobal.rawMessageCount(openedConversationId),
      },
    );
    ChatOpenPerfLog.mark(
      'chat_init_state',
      conversationID:
          openConvKey.isNotEmpty ? openConvKey : openedConversationId,
      extras: <String, Object?>{
        'type': _getConvType().name,
        'entryUnread': widget.entryUnreadCount ?? 0,
        'cachedRaw':
            openConvKey.isEmpty ? 0 : openGlobal.rawMessageCount(openConvKey),
        'initialLoaded': openConvKey.isEmpty
            ? false
            : openGlobal.hasInitialHistoryLoaded(openConvKey),
        'warmNewestTs': openWarmNewest,
        'isGroup': _getConvType() == ConvType.group,
      },
    );
    ChatJitterDiag.markChatOpen(
      openConvKey.isNotEmpty ? openConvKey : openedConversationId,
    );
    ChatResourceSample.resetForChatOpen(
      openConvKey.isNotEmpty ? openConvKey : openedConversationId,
    );
    // 首屏窗口已在内存时立刻尝试 100/500/1000 节点（不等上翻）。
    final openCount =
        openConvKey.isEmpty ? 0 : openGlobal.rawMessageCount(openConvKey);
    if (openCount > 0) {
      ChatResourceSample.onRawMessageCount(openCount);
    }
    ConversationUnreadClearService.beginConversationChatSession(
      openedConversationId,
    );
    if (openedConversationId.isNotEmpty) {
      ActiveChatRegistry.instance.enter(
        openedConversationId,
        conversationType: _getConvType(),
      );
    }
    DeviceSyncService.instance.prepareForChatNavigation();
    DeviceSyncService.instance.beginForegroundMediaWork(
      reason: 'chat_open',
      duration: const Duration(hours: 2),
    );
    _cachedHeaderFaceUrl = _conversation.faceUrl;
    _cachedHeaderShowName = _conversation.showName;
    if (_getConvType() == ConvType.group) {
      _logGroupHeaderAvatarSource(
        source: 'selected_conversation',
        currentFaceUrl: '',
        candidateFaceUrl: _conversation.faceUrl ?? '',
        applied: true,
      );
    }
    _applyInitialC2cPermissionHint(resetIfMissing: true);
    _seedGroupDisplayFromMemory();
    _syncChatHeaderState(notify: false);
    _seedGroupLiveFromIndex();
    _syncChatTopFixState(notify: false);
    if (_getConvType() == ConvType.group) {
      // 进群尽早拉当前直播，顶部横幅不必等 post-open P2。
      unawaited(_loadGroupLiveCurrent());
      _startGroupLiveCurrentPoll();
    } else {
      _stopGroupLiveCurrentPoll();
    }
    unawaited(_hydrateGroupDisplayFromLocal());
    unawaited(_loadGroupMemberCount());
    unawaited(_resolveImGroupIdAfterOpen());
    // 先灌本地禁言/身份；有缓存则勿与进页抢网络，转场后再补后端权威态。
    unawaited(_seedSelfMemberFromLocalStore());
    if (_getConvType() == ConvType.group) {
      final groupId = ChatIdFormat.normalizeGroupId(
        widget.selectedConversation.groupID,
      );
      final selfId = ContactSocialCacheStore.safeLoginUserId().trim();
      final hasLocalSelf = groupId.isNotEmpty &&
          selfId.isNotEmpty &&
          GroupMemberStore.instance.memberOf(groupId, selfId) != null;
      if (groupId.isNotEmpty && !hasLocalSelf) {
        // 无本地成员缓存：尽快拉禁言，避免输入栏长时间错误可发。
        unawaited(_fetchAndStoreBackendMuteStatus(groupId));
      }
    }
    _clearMountedDisplayListCache();
    if (openedConversationId.isNotEmpty) {
      unawaited(
        ImChatNotificationClearService.instance
            .clearChatNotificationsForConversation(
          openedConversationId,
          reason: 'chat_open',
        ),
      );
    }
    _schedulePostOpenFailedMessageRetry();
    final convId = _getConvID()?.trim() ?? '';
    if (convId.isNotEmpty) {
      // 进页首帧先渲染；全局去重放到路由 settle（~1.2s）之后，
      // 且只排一次（resolvedId 与 convId 归一化后常是同一 key），
      // 避免 settle 窗内两次 setMessageList 打爆 Sliver。
      CallBubbleDedupe.scheduleDedupeConversation(
        convId,
        reason: 'chat_open',
        scheduleSlot: 'chat_open',
        delay: const Duration(milliseconds: 1400),
        callOnly: true,
      );
      final cachedMessages =
          serviceLocator<TUIChatGlobalModel>().getMessageList(convId);
      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        ChatImageMessagePrefetch.fromMessages(cachedMessages);
      }
    }
    // 转场前预热会话/首屏头像，降低气泡大图挤掉 imageCache 后的闪动。
    unawaited(_warmAvatarsOnChatOpen());
    if (convId.isNotEmpty) {
      PushFocusService.instance.enterChat(
        conversationType: _getConvType(),
        peerOrGroupId: convId,
      );
    }
    _chatLifeCycle = ChatLifeCycle(
      newMessageWillMount: (V2TimMessage message) async {
        _handleGroupLiveIncomingMessage(message);
        unawaited(
            MessageMediaMetadataStore.instance.upsertFromMessage(message));
        if (ChatImageMessagePrefetch.needsOnlineUrlResolution(
          message,
          includeSelf: true,
        )) {
          unawaited(
            ChatImageMessagePrefetch.resolveOnlineUrlsForMessages(
              <V2TimMessage>[message],
              includeSelf: true,
            ),
          );
        }
        if (_isCallSignalMessage(message) &&
            _shouldDisplayCallMessageInHistory(message)) {
          _removeLocalCallBubblePlaceholder(
            callId: _extractCallSignalInviteId(message),
          );
          final convKey = _getConvID()?.trim() ?? '';
          if (convKey.isNotEmpty) {
            _dedupeCallBubblesForConversation(convKey);
          }
        }
        return message;
      },
      didGetHistoricalMessageList: (List<V2TimMessage> messageList) async {
        await MessageMediaMetadataStore.instance.hydrateMessages(messageList);
        unawaited(
          MessageMediaMetadataStore.instance.persistFromMessages(messageList),
        );
        StickerMessagePrefetch.fromMessages(messageList);
        ChatImageMessagePrefetch.fromHistoricalBatch(messageList);
        // 本地历史必须先提交上屏；缺失的在线图片 URL 在后台补齐，不能
        // 把 SDK/网络耗时放进 didGetHistoricalMessageList 关键路径。
        unawaited(
          ChatImageMessagePrefetch.resolveOnlineUrlsForMessages(messageList)
              .then(
            (_) {
              unawaited(
                MessageMediaMetadataStore.instance.persistFromMessages(
                  messageList,
                ),
              );
              ChatImageMessagePrefetch.fromHistoricalBatch(messageList);
            },
          ).catchError((_) {}),
        );
        final skipCallNormalize =
            _getConvType() == ConvType.c2c || _getConvType() == ConvType.group;
        final normalized = skipCallNormalize
            ? messageList
            : CallBubbleDedupe.normalizeCallHistoryMessages(
                messageList,
                preserveTipIdentity: true,
              );
        final deduped = TUIChatGlobalModel.dedupeMessages(normalized);
        if (deduped.length != messageList.length) {
          // ignore: avoid_print
          print(
            '[CHAT_JITTER] event=call_bubble_normalize conv=${_getConvID()} '
            'openSeq=${ChatJitterDiag.openSeq} '
            'before=${messageList.length} after=${deduped.length} '
            'delta=${deduped.length - messageList.length}',
          );
        }
        // After history lands for list→chat open; filter logs: [RegExpProbe]
        RegExpProbe.dump(reason: 'list_to_chat_didGetHistoricalMessageList');
        RegExpProbe.reset();
        return deduped;
      },
      messageShouldMount: _messageShouldMountInHistory,
      messageListShouldMount: _normalizeMessageListForMount,
      messageDidSend: (sendMsgRes) {
        final conversationId = _resolvedConversationID();
        print('[ChatInputDiag] host=message_did_send conv=$conversationId '
            'code=${sendMsgRes.code} hasData=${sendMsgRes.data != null}');
        if (conversationId.isNotEmpty) {
          unawaited(_clearChatLocalDraftAfterSend(conversationId));
        }
        // 己方发送不走通知侧 patch；SDK onConversationChanged 若因群 ID
        // 形态/非成员门禁落库失败，列表预览会空，再进页会误标 empty-loaded。
        if (sendMsgRes.code == 0 && conversationId.isNotEmpty) {
          final sent = sendMsgRes.data;
          OutgoingVisibleProbe.log(
            'send_preview_patch_start',
            conversationID: conversationId,
            message: sent,
            extras: <String, Object?>{
              'hasData': sent != null,
              'code': sendMsgRes.code,
            },
          );
          unawaited(() async {
            // 好友刚通过时，本地乐观会话与 SDK 建会话存在竞态。己方首条
            // 消息又不会走 onRecvNewMessage，因此不能只等待 SDK 的
            // onConversationChanged；否则返回列表后可能一直没有该会话。
            if (sent != null) {
              unawaited(
                MessageMediaMetadataStore.instance.upsertFromMessage(sent),
              );
              if (ChatImageMessagePrefetch.needsOnlineUrlResolution(
                sent,
                includeSelf: true,
              )) {
                unawaited(
                  ChatImageMessagePrefetch.resolveOnlineUrlsForMessages(
                    <V2TimMessage>[sent],
                    includeSelf: true,
                  ),
                );
              }
              await ConversationSyncService.instance
                  .patchConversationLastMessage(
                conversationID: conversationId,
                message: sent,
              );
              OutgoingVisibleProbe.log(
                'send_preview_patch_done',
                conversationID: conversationId,
                message: sent,
              );
            }
            // 成功但 SDK 未回 message data 时也要拉取；有 data 时再拉一次
            // 权威会话，用于补齐 showName/faceUrl/lastMessage 并确保上屏。
            await ConversationSyncService.instance.refreshConversationItem(
              conversationId,
            );
            ConversationRefreshBus.instance.requestRefresh(
              reason: 'outgoing_message_sent',
              conversationId: conversationId,
              debounce: Duration.zero,
            );
          }()
              .catchError((Object error, StackTrace stack) {
            OutgoingVisibleProbe.log(
              'send_preview_patch_error',
              conversationID: conversationId,
              extras: <String, Object?>{'error': '$error'},
            );
          }));
        }
      },
    );
    if (openConvKey.isNotEmpty) {
      // Ready / 内存已齐：首帧挂重体，转场里就是完整记录。
      _mountHeavyChatBodyOrReady(openConvKey: openConvKey);
    } else {
      _mountHeavyChatBodyOrReady(openConvKey: '');
    }
    _ensureMessageItemBuilder();
    _chatGlobalModel = serviceLocator<TUIChatGlobalModel>();
    _chatGlobalModel!.addListener(_onChatGlobalModelChanged);
    _conversationViewModel.addListener(_onConversationViewModelChanged);
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
    serviceLocator<TUIFriendShipViewModel>().addListener(
      _onFriendshipModelChanged,
    );
    GroupMemberStore.instance.addListener(_onGroupMemberStoreChanged);
    unawaited(_loadPeerFaceUrl());
    unawaited(_loadPeerLocalProfile());
    WalletOrderEvents.chatCardPayload.addListener(_onWalletChatCard);
    WalletOrderEvents.chatCardSendFailedPayload.addListener(
      _onWalletChatCardSendFailed,
    );
    CallResultRepository.instance.revision.addListener(
      _onCallResultRepositoryChanged,
    );
    CallLifecycleService.instance.chatHistoryRefreshRevision.addListener(
      _onCallHistoryRefreshRequested,
    );
    ChatHistoryRefreshBus.instance.revision.addListener(
      _onExternalChatHistoryRefreshRequested,
    );
    GroupNoticeRefreshBus.instance.lastRefresh.addListener(
      _onGroupNoticeRefreshRequested,
    );
    GroupSyncService.instance.lastChanged.addListener(_onGroupRealtimeChanged);
    ConversationHistoryWarmScheduler.instance.pauseForActiveChat(
      reason: 'chat_open',
    );
    // 轻壳首帧就尽量带上真实聊天背景，避免转场结束后再换底。
    unawaited(_prefetchShellBackground());
    _schedulePostOpenTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ChatOpenPerfLog.mark(
        'chat_first_frame',
        conversationID:
            openConvKey.isNotEmpty ? openConvKey : openedConversationId,
        extras: <String, Object?>{
          'rawCount':
              openConvKey.isEmpty ? 0 : openGlobal.rawMessageCount(openConvKey),
          'gateActive': _openLifecycle.openHistoryGate != null,
        },
      );
      _attachLocalSettingListener();
      _publishExternalEntryState();
      unawaited(_activatePendingExternalEntryOnInit());
      unawaited(_verifyGroupMembershipOnOpen());
      final openConvResolved = _resolvedConversationID();
      if (openConvResolved.isNotEmpty) {
        CallBubbleInsertService.instance.ensureConversationBubbles(
          openConvResolved,
          reason: 'chat_open',
        );
      }
      _schedulePeerMessagePermissionSync(
        forceNetwork: _c2cPermission.trustedInitialCanMessage,
      );
    });
    // if (IMDemoConfig.customerServiceUserList.contains(widget.selectedConversation.userID)) {
    //   TencentCloudChatCustomerServicePlugin.sendCustomerServiceStartMessage(_chatController.sendMessage);
    // }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_groupSide.pendingGroupNoticeRecheck ||
        _groupSide.flushingPendingGroupNotice) {
      return;
    }
    if (!_canShowGroupNoticePopup()) {
      return;
    }
    _groupSide.flushingPendingGroupNotice = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _groupSide.flushingPendingGroupNotice = false;
      if (!mounted || !_groupSide.pendingGroupNoticeRecheck) {
        return;
      }
      if (!_canShowGroupNoticePopup()) {
        return;
      }
      _groupSide.pendingGroupNoticeRecheck = false;
      unawaited(_recheckGroupNoticeUntilShown());
    });
  }

  String? _lastVisibleMessageIdForLeave() {
    final convKey = _getConvID()?.trim() ?? '';
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final messages =
        convKey.isNotEmpty ? globalModel.messageListMap[convKey] : null;
    final list = messages ??
        globalModel.messageListMap[_resolvedConversationID()] ??
        const <V2TimMessage>[];
    for (var i = list.length - 1; i >= 0; i--) {
      final msgId = list[i].msgID?.trim() ?? '';
      if (msgId.isNotEmpty) {
        return msgId;
      }
    }
    return widget.selectedConversation.lastMessage?.msgID?.trim();
  }

  @override
  void deactivate() {
    final route = ModalRoute.of(context);
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final leaveId = _resolvedConversationID();
    OutgoingVisibleProbe.log(
      'chat_deactivate',
      conversationID: leaveId,
      extras: <String, Object?>{
        'routeCurrent': route?.isCurrent,
        'mediaPreview': globalModel.isMediaPreviewOverlayOpen,
        'walletOverlay': globalModel.isWalletOverlayOpen,
        'pickerOverlay': globalModel.isMediaPickerOverlayOpen,
        ...OutgoingVisibleProbe.trackedInList(
          globalModel.rawMessageList(leaveId),
        ),
      },
    );
    if (route != null &&
        !route.isCurrent &&
        !globalModel.isMediaPreviewOverlayOpen &&
        !globalModel.isWalletOverlayOpen &&
        !globalModel.isMediaPickerOverlayOpen) {
      // 被资料/代理页盖住：栈内仍开着 Chat，只标不可见，不 leave、不清未读、不交还列表。
      ActiveChatRegistry.instance.updateRouteVisible(false);
      _dismissChatInput();
      unawaited(_persistChatLocalDraft());
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      _restoreActiveChatRegistry(routeVisible: true);
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      // 与 deactivate 对称：媒体预览 / 相册 / 钱包盖层自管滚动与 UI（021），
      // 禁止走「贴底 + setState」强刷，否则下滑关闭时消息列表会闪一下。
      if (globalModel.isMediaPreviewOverlayOpen ||
          globalModel.isRestoringScrollAfterMediaPreview ||
          globalModel.isMediaPickerOverlayOpen ||
          globalModel.isWalletOverlayOpen) {
        return;
      }
      // 真·二级页返回：空列表重拉，有消息则贴底刷新，避免整页空白。
      unawaited(
        _recoverChatHistoryAfterOverlayReturn(reason: 'route_reactivated'),
      );
    }
  }

  @override
  void dispose() {
    ConversationDeletedBus.instance.revision.removeListener(
      _onConversationDeletedBus,
    );
    // 真正离页时再腾出气泡位图并预热列表头像（勿放 deactivate：进资料页也会覆盖路由）。
    _cancelChatOpenSideEffects(reason: 'chat_dispose');
    _clearRouteTransitionListeners();
    final gateConv = _openLifecycle.openHistoryGateConvKey;
    if (gateConv.isNotEmpty) {
      ChatHistoryOpenLayoutReady.cancel(gateConv);
    }
    _openLifecycle.resetForDispose();
    _releaseBubbleCacheAndWarmListAvatar();
    ChatJitterDiag.logImageCache('chat_dispose');
    unawaited(_persistChatLocalDraft());
    _draft.dispose();
    _headerState.dispose();
    _groupLiveState.removeListener(_onGroupLiveStateChanged);
    GroupLiveIndexStore.instance.removeListener(_onGroupLiveIndexStoreChanged);
    _stopGroupLiveCurrentPoll();
    _groupLiveState.dispose();
    _topFixState.dispose();
    _peerPermissionSyncDebounce?.cancel();
    _c2cPermission.nextRequestSeq();
    _c2cPermission.dispose();
    final convType = _getConvType();
    final convId = _getConvID()?.trim() ?? '';
    final leaveConversationId = _resolvedConversationID();
    OutgoingVisibleProbe.log(
      'chat_dispose',
      conversationID: leaveConversationId,
      extras: OutgoingVisibleProbe.trackedInList(
        serviceLocator<TUIChatGlobalModel>().rawMessageList(
          leaveConversationId.isNotEmpty ? leaveConversationId : convId,
        ),
      ),
    );
    if (leaveConversationId.isNotEmpty) {
      unawaited(
        ConversationUnreadClearService.finalizeConversationLeaveOnce(
          conversationID: leaveConversationId,
          lastMessageId: _lastVisibleMessageIdForLeave(),
          entryUnreadCount: widget.entryUnreadCount ?? 0,
          markViewModelReadLocally:
              _conversationViewModel.markConversationReadLocally,
        ),
      );
    }
    if (convId.isNotEmpty) {
      PushFocusService.instance.leaveChat(
        chatType: convType == ConvType.group ? 'group' : 'c2c',
        peerOrGroupId: convId,
      );
      ActiveChatRegistry.instance.leave(convId);
      _flushConversationListUiAfterChatLeave(
        reason: 'chat_leave_push_focus',
        leftConversationId:
            leaveConversationId.isNotEmpty ? leaveConversationId : convId,
      );
    }
    _chatGlobalModel?.removeListener(_onChatGlobalModelChanged);
    _chatGlobalModel = null;
    _clearMountedDisplayListCache();
    if (!_openLifecycle.clearedExternalEntryOnDeactivate) {
      _clearExternalEntryState();
    }
    DeviceSyncService.instance.onChatClosed();
    DeviceSyncService.instance.endForegroundMediaWork(
      reason: 'chat_open_dispose',
      cooldown: const Duration(minutes: 5),
    );
    _dismissChatInput();
    _conversationViewModel.removeListener(_onConversationViewModelChanged);
    PeerProfileRefreshBus.instance.revision.removeListener(
      _onPeerProfileRefresh,
    );
    serviceLocator<TUIFriendShipViewModel>().removeListener(
      _onFriendshipModelChanged,
    );
    GroupMemberStore.instance.removeListener(_onGroupMemberStoreChanged);
    WalletOrderEvents.chatCardPayload.removeListener(_onWalletChatCard);
    WalletOrderEvents.chatCardSendFailedPayload.removeListener(
      _onWalletChatCardSendFailed,
    );
    CallResultRepository.instance.revision.removeListener(
      _onCallResultRepositoryChanged,
    );
    CallLifecycleService.instance.chatHistoryRefreshRevision.removeListener(
      _onCallHistoryRefreshRequested,
    );
    ChatHistoryRefreshBus.instance.revision.removeListener(
      _onExternalChatHistoryRefreshRequested,
    );
    GroupNoticeRefreshBus.instance.lastRefresh.removeListener(
      _onGroupNoticeRefreshRequested,
    );
    GroupSyncService.instance.lastChanged.removeListener(
      _onGroupRealtimeChanged,
    );
    _callBubbleRefreshTimer?.cancel();
    _reconnectRecoveryTimer?.cancel();
    _groupMemberAvatarRefreshDebounce?.cancel();
    _postOpenScheduler.dispose();
    CallBubbleDedupe.endOpenHold(_getConvID()?.trim() ?? '');
    CallBubbleDedupe.endOpenHold(_resolvedConversationID());
    CallBubbleDedupe.cancelScheduled(_getConvID()?.trim() ?? '');
    CallBubbleDedupe.cancelScheduled(_resolvedConversationID());
    _sangongRealtimeSub?.cancel();
    _sangongRealtimeSub = null;
    SangongAdminRealtimeService.instance.release();
    _localSetting?.removeListener(_onLocalSettingChanged);
    final releaseConvId = _resolvedConversationID();
    ActiveChatRegistry.instance.leave(releaseConvId);
    _flushConversationListUiAfterChatLeave(
      reason: 'chat_leave_dispose',
      leftConversationId: releaseConvId,
    );
    if (releaseConvId.isNotEmpty) {
      ConversationSyncService.instance.schedulePostPopCoalesceWindow(
        conversationID: releaseConvId,
      );
      ConversationHistoryWarmScheduler.instance.scheduleReleaseAfterChatLeave(
        releaseConvId,
      );
    }
    _chatController.model?.disableVoiceAutoPlayChain();
    unawaited(SoundPlayer.stop());
    OrphanOverlayGuard.scheduleCleanup(
      reason: 'chat_leave_dispose',
      hideLoading: true,
    );
    super.dispose();
  }

  void _onCallHistoryRefreshRequested() {
    final convId = _resolvedConversationID();
    if (!mounted ||
        convId.isEmpty ||
        !MessageConversationId.sameConversation(
          ActiveChatRegistry.instance.activeConversationId,
          convId,
        )) {
      return;
    }
    _callBubbleRefreshTimer?.cancel();
    _callBubbleRefreshTimer = Timer(const Duration(milliseconds: 60), () {
      unawaited(_refreshChatHistoryAfterCallEnd());
    });
  }

  void _onCallResultRepositoryChanged() {
    if (!mounted) return;
    final convKey = _getConvID()?.trim() ?? '';
    final convId = _resolvedConversationID();
    if (convKey.isEmpty && convId.isEmpty) return;
    if (convId.isNotEmpty) {
      CallBubbleInsertService.instance.ensureConversationBubbles(
        convId,
        reason: 'call_result_repo',
      );
    }
    // Server/device result cache updated — dedupe + repaint.
    if (convKey.isNotEmpty) {
      CallBubbleDedupe.scheduleDedupeConversation(
        convKey,
        reason: 'call_result_repo',
        delay: Duration.zero,
      );
    }
    _clearMountedDisplayListCache();
    if (mounted) {
      setState(() {});
    }
  }

  void _onExternalChatHistoryRefreshRequested() {
    if (!mounted) {
      return;
    }
    final target =
        ChatHistoryRefreshBus.instance.lastConversationId?.trim() ?? '';
    final resolvedCurrent = _resolvedConversationID();
    if (target.isEmpty ||
        resolvedCurrent.isEmpty ||
        !_matchesRefreshConversationId(target)) {
      return;
    }
    final reason = ChatHistoryRefreshBus.instance.lastReason ?? '';
    if (reason == 'conversation_clear_history') {
      unawaited(_applyLocalHistoryClearToChat());
      return;
    }
    if (_shouldSkipExternalHistoryRefreshDuringOpen(reason)) {
      return;
    }
    unawaited(_refreshChatHistoryFromExternalEntry());
  }

  Future<void> _applyLocalHistoryClearToChat() async {
    if (!mounted) {
      return;
    }
    final convKey = _getConvID()?.trim() ?? '';
    final convId = _resolvedConversationID();
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (final key in <String>{convKey, convId}.where((e) => e.isNotEmpty)) {
      globalModel.clearLocalHistoryAsEmptyLoaded(key);
    }
    // clearHistory 内部同样走 clearLocalHistoryAsEmptyLoaded，不会清掉 initialLoaded。
    await _chatController.model?.clearHistory();
    _clearMountedDisplayListCache();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshChatHistoryFromExternalEntry() async {
    final conversationKey = _conversationRecoveryKey();
    if (conversationKey.isEmpty) {
      return;
    }
    final source =
        ChatHistoryRefreshBus.instance.lastReason ?? 'external_entry';
    await ChatHistoryRecoveryCoordinator.instance.runExclusive(
      conversationKey: conversationKey,
      reason: source,
      priority: ChatHistoryRecoveryCoordinator.priorityUser,
      task: _refreshChatHistoryFromExternalEntryImpl,
    );
  }

  Future<void> _refreshChatHistoryFromExternalEntryImpl() async {
    final conversationID = _resolvedConversationID();
    final source =
        ChatHistoryRefreshBus.instance.lastReason ?? 'external_entry';
    final isRecovery = _isForegroundRecoveryReason(source);
    var hasMessages = _hasVisibleHistoryMessages();
    final previewAheadForDelays =
        isRecovery ? await _conversationPreviewAheadOfHistory() : false;
    if (!mounted) {
      return;
    }
    final retryDelays = _resolveRecoveryRetryDelays(
      source,
      hasVisibleMessages: hasMessages,
      previewAhead: previewAheadForDelays,
    );
    // 清空聊天记录触发的激活（进页 initState 走到这里，绕过了 bus 监听里的
    // clear 短路）：会话已确认为空（无内存消息、预览也为空）时直接标记
    // empty-loaded 收工。否则 legacy「latest/local/cloud/refresh」四连拉
    // × 多轮重试会对一个已知为空的会话产生十余次无效 setMessageList。
    if (source == 'conversation_clear_history' && !hasMessages) {
      final preview = await _fetchConversationPreviewLastMessage();
      if (preview == null) {
        final convKey = _getConvID()?.trim() ?? '';
        final globalModel = serviceLocator<TUIChatGlobalModel>();
        for (final key in <String>{
          convKey,
          conversationID,
        }.where((e) => e.isNotEmpty)) {
          globalModel.clearLocalHistoryAsEmptyLoaded(key);
        }
        ExternalChatEntryService.instance.logFlow(
          'history_activation_skip_cleared_empty',
          source: source,
          conversationID: conversationID,
        );
        _publishExternalEntryState();
        return;
      }
    }
    for (var index = 0; index < retryDelays.length; index++) {
      final delay = retryDelays[index];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!mounted) {
        return;
      }
      final current = _resolvedConversationID();
      final target =
          ChatHistoryRefreshBus.instance.lastConversationId?.trim() ?? '';
      if (current.isEmpty || !_matchesRefreshConversationId(target)) {
        return;
      }
      final previewAhead =
          isRecovery ? await _conversationPreviewAheadOfHistory() : false;
      final anchorMsgID =
          isRecovery ? _resolveLatestPullAnchorId() : _latestVisibleMessageId();
      ExternalChatEntryService.instance.logFlow(
        'history_activation_attempt',
        source: source,
        conversationID: current,
        extras: <String, Object?>{
          'attempt': index + 1,
          'delayMs': delay.inMilliseconds,
          'hasMessagesBefore': hasMessages,
          'previewAhead': previewAhead,
          'anchorMsgID': anchorMsgID,
          'recoveryReason': isRecovery ? source : null,
        },
      );
      final model = _chatController.model;
      if (model == null) {
        ExternalChatEntryService.instance.logFlow(
          'history_activation_wait_model',
          source: source,
          conversationID: current,
        );
        continue;
      }
      try {
        if (isRecovery) {
          final shouldAllowCloudCatchUp = warm_resume.shouldAllowCloudCatchUp(
            source: source,
            previewAhead: previewAhead,
          );
          final changed = await _pullLatestMessagesFromAnchor(
            model: model,
            source: source,
            allowCloudPull: shouldAllowCloudCatchUp,
          );
          hasMessages = _hasVisibleHistoryMessages();
          ExternalChatEntryService.instance.logFlow(
            'history_recovery_pull_done',
            source: source,
            conversationID: current,
            extras: <String, Object?>{
              'changed': changed,
              'hasMessages': hasMessages,
              'previewAhead': previewAhead,
              'anchorMsgID': anchorMsgID,
              'shouldAllowCloudCatchUp': shouldAllowCloudCatchUp,
            },
          );
          if (changed) {
            _recordRecoverySuccess();
            _publishExternalEntryState();
            return;
          }
          final recoveryGlobalModel = serviceLocator<TUIChatGlobalModel>();
          final recoveryConvKey = _getConvID()?.trim() ?? '';
          final hasDeferredIncoming = recoveryConvKey.isNotEmpty &&
              recoveryGlobalModel.hasDeferredIncomingForResume(recoveryConvKey);
          if (isRecoveryAlreadySatisfied(
            changed: changed,
            hasMessages: hasMessages,
            previewAhead: previewAhead,
            hasDeferredIncoming: hasDeferredIncoming,
            cloudCatchUpRequired: shouldAllowCloudCatchUp && !previewAhead,
            cloudCatchUpAttempted: shouldAllowCloudCatchUp,
          )) {
            final savedDelayMs = retryDelays
                .skip(index + 1)
                .fold<int>(0, (sum, delay) => sum + delay.inMilliseconds);
            ExternalChatEntryService.instance.logFlow(
              'history_recovery_skip_satisfied',
              source: source,
              conversationID: current,
              extras: <String, Object?>{
                'attempt': index + 1,
                'recoveryReason': source,
                'savedDelayMs': savedDelayMs,
              },
            );
            _recordRecoverySuccess();
            _publishExternalEntryState();
            return;
          }
          final convKey = _getConvID()?.trim() ?? '';
          final globalModel = serviceLocator<TUIChatGlobalModel>();
          if (hasMessages &&
              convKey.isNotEmpty &&
              globalModel.hasInitialHistoryLoaded(convKey)) {
            // Cloud catch-up required: only arm the 30s skip window after an
            // allowed cloud pull with no deferred gap left. Otherwise fall
            // through to preview-merge / retries (do not record success).
            final cloudCatchUpRequired =
                shouldAllowCloudCatchUp && !previewAhead;
            final mayMarkSuccess =
                cloudCatchUpRequired ? !hasDeferredIncoming : true;
            ExternalChatEntryService.instance.logFlow(
              'history_recovery_skip_preview_merge_warm',
              source: source,
              conversationID: current,
              extras: <String, Object?>{
                'previewAhead': previewAhead,
                'anchorMsgID': anchorMsgID,
                'rawLen': globalModel.rawMessageCount(convKey),
                'shouldAllowCloudCatchUp': shouldAllowCloudCatchUp,
                'mayMarkSuccess': mayMarkSuccess,
              },
            );
            if (mayMarkSuccess) {
              _recordRecoverySuccess();
              _publishExternalEntryState();
              return;
            }
          }
          if (await _mergePreviewMessageIfMissing()) {
            hasMessages = _hasVisibleHistoryMessages();
            ExternalChatEntryService.instance.logFlow(
              'history_preview_merge_done',
              source: source,
              conversationID: current,
              extras: <String, Object?>{'hasMessages': hasMessages},
            );
            _recordRecoverySuccess();
            _publishExternalEntryState();
            return;
          }
          if (index + 1 >= retryDelays.length) {
            try {
              await _chatController.refreshCurrentHistoryList();
              hasMessages = _hasVisibleHistoryMessages();
              if (hasMessages) {
                _publishExternalEntryState();
                return;
              }
            } catch (_) {}
          }
          continue;
        }

        final beforeSignature = _visibleHistorySignature();
        final changed = await _refreshChatHistoryLegacyFallback(
          model: model,
          source: source,
          current: current,
          beforeSignature: beforeSignature,
        );
        hasMessages = _hasVisibleHistoryMessages();
        if (changed) {
          _publishExternalEntryState();
          return;
        }
      } catch (e) {
        ExternalChatEntryService.instance.logFlow(
          'history_activation_error',
          source: source,
          conversationID: current,
          extras: <String, Object?>{
            'error': e.toString(),
            'recoveryReason': isRecovery ? source : null,
          },
        );
        if (!isRecovery) {
          try {
            await _chatController.refreshCurrentHistoryList();
            hasMessages = _hasVisibleHistoryMessages();
            ExternalChatEntryService.instance.logFlow(
              'history_error_fallback_done',
              source: source,
              conversationID: current,
              extras: <String, Object?>{'hasMessages': hasMessages},
            );
            if (hasMessages) {
              _publishExternalEntryState();
              return;
            }
          } catch (_) {}
        } else if (index + 1 >= retryDelays.length) {
          try {
            await _chatController.refreshCurrentHistoryList();
            hasMessages = _hasVisibleHistoryMessages();
            if (hasMessages) {
              _publishExternalEntryState();
              return;
            }
          } catch (_) {}
        }
      }
    }
    ExternalChatEntryService.instance.logFlow(
      'history_activation_finished',
      source: source,
      conversationID: conversationID,
      extras: <String, Object?>{
        'hasMessages': hasMessages,
        'recoveryReason': isRecovery ? source : null,
      },
    );
    _publishExternalEntryState();
  }

  void _clearMountedDisplayListCache() {
    _mountedDisplayListCache = null;
    _mountedDisplayListLen = 0;
  }

  String _messageMountIdentity(V2TimMessage message) {
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      return msgID;
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final seq = message.seq?.trim();
    if (seq != null && seq.isNotEmpty) {
      return 'seq:$seq';
    }
    return '${message.timestamp}_${message.random}_${message.sender}';
  }

  bool _mountedDisplayListsMatchPrefix(
    List<V2TimMessage> current,
    List<V2TimMessage> cached,
    int cachedLen,
  ) {
    if (current.length <= cachedLen || cached.length != cachedLen) {
      return false;
    }
    for (var i = 0; i < cachedLen; i++) {
      if (_messageMountIdentity(current[i]) !=
          _messageMountIdentity(cached[i])) {
        return false;
      }
    }
    return true;
  }

  bool _mountedDisplayListsMatchSuffix(
    List<V2TimMessage> current,
    List<V2TimMessage> cached,
    int cachedLen,
  ) {
    if (current.length <= cachedLen || cached.length != cachedLen) {
      return false;
    }
    final delta = current.length - cachedLen;
    for (var i = 0; i < cachedLen; i++) {
      if (_messageMountIdentity(current[delta + i]) !=
          _messageMountIdentity(cached[i])) {
        return false;
      }
    }
    return true;
  }

  bool _messageLooksLikeCallForMount(V2TimMessage message) {
    if (_localCallBubbleMarker(message) != null) {
      return true;
    }
    return CallingMessageDataProvider.looksLikeCallMessage(message);
  }

  bool _hasMultipleCallMessagesForMount(List<V2TimMessage> messages) {
    var count = 0;
    for (final message in messages) {
      if (_messageLooksLikeCallForMount(message)) {
        count++;
        if (count > 1) {
          return true;
        }
      }
    }
    return false;
  }

  List<V2TimMessage> _normalizeMessageListForMount(
    List<V2TimMessage> messageList,
  ) {
    if (messageList.isEmpty) {
      _clearMountedDisplayListCache();
      return messageList;
    }

    final cached = _mountedDisplayListCache;
    final cachedLen = _mountedDisplayListLen;
    // 首屏 replace 后条数接近但身份全变时，禁止走增量拼接（群聊易出现空洞）。
    // 仅在严格前后缀匹配时才增量合并。
    if (cached != null &&
        cachedLen > 0 &&
        messageList.length > cachedLen &&
        messageList.length - cachedLen <=
            HistoryMessageDartConstant.getCount + 8) {
      final delta = messageList.length - cachedLen;
      List<V2TimMessage>? newSegment;
      List<V2TimMessage>? mergedBase;
      if (_mountedDisplayListsMatchPrefix(messageList, cached, cachedLen)) {
        // 新消息 / 本地群提示追加在时间序列表末尾。
        newSegment = messageList.sublist(cachedLen);
        mergedBase = cached;
      } else if (_mountedDisplayListsMatchSuffix(
        messageList,
        cached,
        cachedLen,
      )) {
        // 上拉加载更早历史：追加在时间序列表开头。
        newSegment = messageList.sublist(0, delta);
        mergedBase = cached;
      }
      if (newSegment != null &&
          mergedBase != null &&
          !newSegment.any(_messageLooksLikeCallForMount)) {
        _normalizeSelfMessageAvatars(newSegment);
        final deduped = TUIChatGlobalModel.dedupeMessages(<V2TimMessage>[
          ...mergedBase,
          ...newSegment,
        ]);
        var merged = TUIChatGlobalModel.sortMessagesChronologicallyAsc(deduped);
        if (merged.where(_messageLooksLikeCallForMount).length > 1) {
          merged = TUIChatGlobalModel.sortMessagesChronologicallyAsc(
            TUIChatGlobalModel.dedupeMessages(
              _normalizeCallHistoryMessages(merged),
            ),
          );
        }
        merged = GroupTipsMessageHelper.applyPostMergeFilters(merged);
        // 增量结果若比权威列表更短，说明拼错了，回退全量。
        if (merged.length >= messageList.length) {
          _mountedDisplayListCache = merged;
          _mountedDisplayListLen = merged.length;
          return merged;
        }
      }
    }

    final normalized = _normalizeCallHistoryMessages(messageList);
    _normalizeSelfMessageAvatars(normalized);
    final deduped = TUIChatGlobalModel.dedupeMessages(normalized);
    var sorted = TUIChatGlobalModel.sortMessagesChronologicallyAsc(deduped);
    sorted = GroupTipsMessageHelper.applyPostMergeFilters(sorted);
    final callCountBefore =
        messageList.where(_messageLooksLikeCallForMount).length;
    final callCountAfter = sorted.where(_messageLooksLikeCallForMount).length;
    if (callCountAfter < callCountBefore) {
      final convKey = _getConvID()?.trim() ?? '';
      if (convKey.isNotEmpty) {
        CallBubbleDedupe.scheduleDedupeConversation(
          convKey,
          reason: 'mount_dedupe',
        );
      }
    }
    _mountedDisplayListCache = List<V2TimMessage>.from(sorted);
    _mountedDisplayListLen = sorted.length;
    return sorted;
  }

  List<V2TimMessage> _normalizeCallHistoryMessages(
    List<V2TimMessage> messageList,
  ) {
    if (_getConvType() == ConvType.c2c || _getConvType() == ConvType.group) {
      return messageList;
    }
    return CallBubbleDedupe.normalizeCallHistoryMessages(
      messageList,
      preserveTipIdentity: true,
    );
  }

  String _callBubbleStableKey(
    V2TimMessage message, {
    _LocalCallBubbleMarker? marker,
  }) {
    final marked = marker ?? _localCallBubbleMarker(message);
    if (marked != null && marked.callId.trim().isNotEmpty) {
      return 'call:${marked.callId.trim()}';
    }
    // 非展示态（invite/accept）不要生成 call:$id，避免挡住本地终态气泡。
    if (!_shouldDisplayCallMessageInHistory(message)) {
      return '';
    }
    final unified = CallBubbleDedupe.c2cHangupKeyForMessage(message);
    if (unified.isNotEmpty) {
      return unified;
    }
    final durationSec = _callBubbleDurationSec(message);
    final roomId = CallBubbleDedupe.extractRoomId(message);
    if (roomId.isNotEmpty && durationSec > 0) {
      return 'call-room:$roomId:$durationSec';
    }
    final extracted = (_extractCallSignalInviteId(message) ?? '').trim();
    if (extracted.isNotEmpty) {
      return 'call:$extracted';
    }
    try {
      final provider = CallingMessageDataProvider(message);
      if (provider.isCallingSignal && provider.shouldDisplayInHistory) {
        return provider.callStableKey;
      }
    } catch (_) {}
    return '';
  }

  String _callBubbleNearDuplicateKey(
    V2TimMessage message, {
    _LocalCallBubbleMarker? marker,
  }) {
    final unified = CallBubbleDedupe.c2cHangupKeyForMessage(message);
    if (unified.isNotEmpty) {
      return unified;
    }
    final marked = marker ?? _localCallBubbleMarker(message);
    final inviteId = (_extractCallSignalInviteId(message) ?? '').trim();
    final ts = message.timestamp ?? 0;
    final bucket = ts <= 0 ? 0 : ts ~/ 60;
    if (inviteId.isNotEmpty) {
      return 'call-near:$inviteId:$bucket';
    }
    if (marked != null && marked.callId.isNotEmpty) {
      return 'call-near:${marked.callId}:$bucket';
    }
    return '';
  }

  String _conversationIdForCallBubbleMessage(V2TimMessage message) {
    final marker = _localCallBubbleMarker(message);
    if (marker != null && marker.conversationId.isNotEmpty) {
      return marker.conversationId;
    }
    try {
      final provider = CallingMessageDataProvider(message);
      if (provider.isCallingSignal && provider.shouldDisplayInHistory) {
        final conv = provider.conversationID.trim();
        if (conv.isNotEmpty) {
          return conv;
        }
      }
    } catch (_) {}
    final peer = widget.selectedConversation.userID?.trim() ?? '';
    if (peer.isNotEmpty) {
      return 'c2c_$peer';
    }
    return _resolvedConversationID();
  }

  int _callBubbleDurationSec(V2TimMessage message) {
    for (final raw in <String>[
      message.customElem?.data?.trim() ?? '',
      message.localCustomData?.trim() ?? '',
    ]) {
      if (raw.isEmpty || !raw.startsWith('{')) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final direct = decoded['call_end'] ?? decoded['callEnd'];
        if (direct is num && direct > 0) {
          return direct.round();
        }
        final data = decoded['data'];
        if (data is String && data.trim().startsWith('{')) {
          final nested = jsonDecode(data);
          if (nested is Map) {
            final nestedEnd = nested['call_end'] ?? nested['callEnd'];
            if (nestedEnd is num && nestedEnd > 0) {
              return nestedEnd.round();
            }
          }
        } else if (data is Map) {
          final nestedEnd = data['call_end'] ?? data['callEnd'];
          if (nestedEnd is num && nestedEnd > 0) {
            return nestedEnd.round();
          }
        }
      } catch (_) {}
    }
    return 0;
  }

  void _dedupeCallBubblesForConversation(String convKey) {
    final key = convKey.trim();
    if (key.isEmpty) {
      return;
    }
    CallBubbleDedupe.scheduleDedupeConversation(key, reason: 'chat_mount');
    _clearMountedDisplayListCache();
  }

  _LocalCallBubbleMarker? _localCallBubbleMarker(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['localCallBubble'] != true) {
        return null;
      }
      final callId = decoded['callId']?.toString().trim() ?? '';
      final conversationID = decoded['conversationID']?.toString().trim() ?? '';
      if (callId.isEmpty || conversationID.isEmpty) {
        return null;
      }
      return _LocalCallBubbleMarker(
        callId: callId,
        conversationId: conversationID,
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractCallSignalInviteId(V2TimMessage message) {
    String readFromMap(Map source) {
      for (final key in const ['inviteID', 'inviteId', 'callId', 'callID']) {
        final value = source[key]?.toString().trim() ?? '';
        if (value.isNotEmpty && value != 'null') return value;
      }
      for (final key in const ['signalingInfo', 'data', 'callInfo']) {
        final nested = source[key];
        if (nested is Map) {
          final value = readFromMap(nested);
          if (value.isNotEmpty) return value;
        } else if (nested is String && nested.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(nested);
            if (decoded is Map) {
              final value = readFromMap(decoded);
              if (value.isNotEmpty) return value;
            }
          } catch (_) {}
        }
      }
      return '';
    }

    for (final raw in <String>[
      message.customElem?.data?.trim() ?? '',
      message.localCustomData?.trim() ?? '',
      message.cloudCustomData?.trim() ?? '',
    ]) {
      if (raw.isEmpty || !raw.startsWith('{')) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final value = readFromMap(decoded);
          if (value.isNotEmpty) return value;
        }
      } catch (_) {}
    }
    return null;
  }

  bool _isCallSignalMessage(V2TimMessage message) {
    final data = message.customElem?.data ?? '';
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM ||
        data.trim().isEmpty) {
      return false;
    }
    return data.contains('av_call') ||
        data.contains('rtc_call') ||
        data.contains('lk_call');
  }

  bool _shouldDisplayCallMessageInHistory(V2TimMessage message) {
    try {
      return CallingMessageDataProvider(message).shouldDisplayInHistory;
    } catch (_) {
      return false;
    }
  }

  /// 不进历史列表的消息也不参与时间分割线锚点，避免中间「看不见」却留下孤儿时间。
  bool _messageShouldMountInHistory(V2TimMessage message) {
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS &&
        message.groupTipsElem == null) {
      return false;
    }
    if (GroupTipsMessageHelper.isImNativeAdminRoleTip(message) ||
        GroupTipsMessageHelper.isDeprecatedLocalMemberTip(message)) {
      return false;
    }
    // 通话中间态信号在气泡层是 SizedBox.shrink，挂载会导致分割线悬空。
    if (CallingMessageDataProvider.looksLikeCallMessage(message)) {
      return _shouldDisplayCallMessageInHistory(message);
    }
    return true;
  }

  void _removeLocalCallBubblePlaceholder({String? callId}) {
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isEmpty) {
      return;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final existing = List<V2TimMessage>.from(
      globalModel.messageListMap[convKey] ?? const [],
    );
    if (existing.isEmpty) {
      return;
    }
    final targetCallId = callId?.trim();
    final retained = <V2TimMessage>[];
    var removed = false;
    for (final item in existing) {
      final marker = _localCallBubbleMarker(item);
      if (marker == null) {
        retained.add(item);
        continue;
      }
      if (marker.conversationId != _resolvedConversationID()) {
        retained.add(item);
        continue;
      }
      if (targetCallId != null &&
          targetCallId.isNotEmpty &&
          marker.callId != targetCallId) {
        retained.add(item);
        continue;
      }
      removed = true;
    }
    if (!removed) {
      return;
    }
    globalModel.setMessageList(
      convKey,
      retained,
      needResetNewMessageCount: false,
    );
  }

  Future<void> _refreshChatHistoryAfterCallEnd() async {
    final convId = _resolvedConversationID();
    if (convId.isNotEmpty) {
      CallBubbleInsertService.instance.ensureConversationBubbles(
        convId,
        reason: 'call_history_refresh',
      );
    }
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 450),
      Duration(milliseconds: 1000),
    ];
    for (final delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final convId = _resolvedConversationID();
      if (!mounted ||
          convId.isEmpty ||
          !MessageConversationId.sameConversation(
            ActiveChatRegistry.instance.activeConversationId,
            convId,
          )) {
        return;
      }
      try {
        final model = _chatController.model;
        if (model == null) {
          await _chatController.refreshCurrentHistoryList();
          continue;
        }
        final anchorId = _latestRealVisibleMessageId();
        if (anchorId.isNotEmpty) {
          await model.loadChatRecord(
            count: 20,
            lastMsgID: anchorId,
            direction: LoadDirection.latest,
          );
        } else {
          await model.loadChatRecord(
            count: 20,
            getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
          );
          await model.loadChatRecord(
            count: 20,
            getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
          );
        }
      } catch (_) {
        try {
          await _chatController.refreshCurrentHistoryList();
        } catch (_) {}
      }
    }
    final convKey = _getConvID()?.trim() ?? '';
    if (convKey.isNotEmpty) {
      _dedupeCallBubblesForConversation(convKey);
    }
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'call_history_message',
      debounce: Duration.zero,
    );
  }

  @override
  void didUpdateWidget(Chat oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldConversationID = _resolvedConversationID(
      oldWidget.selectedConversation,
    );
    final newConversationID = _resolvedConversationID(
      widget.selectedConversation,
    );
    if (oldConversationID != newConversationID) {
      _groupMemberCountGeneration++;
      _lastGroupMetadataRefreshAt = null;
      _clearExternalEntryState(oldConversationID);
      _openLifecycle.cancelPendingMuteFetch();
      _openLifecycle.scheduledVisibleSdkUnreadClean = false;
      _lastPublishedExternalEntryState = null;
      _chatController.model?.disableVoiceAutoPlayChain();
      unawaited(SoundPlayer.stop());
      ActiveChatRegistry.instance.enter(
        _resolvedConversationID(),
        conversationType: _getConvType(),
      );
      ConversationHistoryWarmScheduler.instance.pauseForActiveChat(
        reason: 'chat_switch',
      );
      _conversation = _normalizedConversationForChat(
        widget.selectedConversation,
      );
      _cachedHeaderFaceUrl = _conversation.faceUrl;
      _cachedHeaderShowName = _conversation.showName;
      _groupMemberCount = null;
      _groupSide.agentRebateGroupBound = false;
      _groupSide.agentRebateGroupEnabled = false;
      _groupSide.agentRebateIdentityEnabled = false;
      _groupSide.groupNoticeBanner = '';
      _watchingGroupLive = false;
      _groupLiveIndexFingerprint = null;
      _seedGroupDisplayFromMemory();
      _seedGroupLiveFromIndex();
      _syncChatTopFixState();
      unawaited(_hydrateGroupDisplayFromLocal());
      unawaited(_loadGroupMemberCount());
      if (_getConvType() == ConvType.group) {
        unawaited(_loadGroupLiveCurrent());
        _startGroupLiveCurrentPoll();
      } else {
        _stopGroupLiveCurrentPoll();
      }
      _resolvedPeerFaceUrl = null;
      _resolvedPeerFaceUrlForId = null;
      _peerLocalProfile = null;
      _c2cPermission.canMessage = null;
      _c2cPermission.trustedInitialCanMessage = false;
      _c2cPermission.requestSeq++;
      _applyInitialC2cPermissionHint(resetIfMissing: true);
      final peer = _c2cPeerUserId();
      if (peer != null && !_c2cPermission.trustedInitialCanMessage) {
        C2cFriendMessageGuard.invalidate(peer);
      }
      _syncChatHeaderState();
      unawaited(_loadPeerFaceUrl());
      unawaited(_loadPeerLocalProfile());
      _schedulePeerMessagePermissionSync(forceNetwork: true);
      _resetWalletCardState();
      _ensureMessageItemBuilder();
      _invalidateChatConfigCache();
      final newConvKey = _getConvID()?.trim() ?? '';
      if (_heavyChatBodyMounted) {
        _startOpenHistoryGate(newConvKey);
      } else {
        _mountHeavyChatBody(
          openConvKey: newConvKey,
          reason: 'conversation_switch',
        );
      }
    }
    if (oldConversationID != newConversationID ||
        oldWidget.selectedConversation.groupID !=
            widget.selectedConversation.groupID ||
        oldWidget.selectedConversation.type !=
            widget.selectedConversation.type) {
      _openLifecycle.cancelPendingPostOpenTasks();
      _postOpenScheduler.cancelPending();
      _schedulePostOpenTasks();
    }
  }

  _itemClick(
    String id,
    BuildContext context,
    V2TimConversation conversation,
    VoidCallback closeFunc,
  ) async {
    closeFunc();
    switch (id) {
      case "sendMsg":
        if (widget.directToChat != null) {
          widget.directToChat!(conversation);
        }
        break;
    }
  }

  _buildBottomOperationList(
    BuildContext context,
    V2TimConversation conversation,
    VoidCallback closeFunc,
    TUITheme theme,
  ) {
    List operationList = [
      {
        "label": AppI18n.of(context).t(
          zhHans: '发送消息',
          zhHant: '傳送訊息',
          en: 'Send Message',
          ja: 'メッセージを送信',
          ko: '메시지 보내기',
        ),
        "id": "sendMsg",
      },
    ];

    return operationList.map((e) {
      return TIMUIKitProfileWidget.wideButton(
        margin: const EdgeInsets.symmetric(vertical: 0),
        smallCardMode: true,
        onPressed: () =>
            _itemClick(e["id"] ?? "", context, conversation, closeFunc),
        text: e["label"] ?? "",
        color: theme.primaryColor ?? hexToColor("3e4b67"),
      );
    }).toList();
  }

  void onClickUserName(Offset offset, TUITheme theme, [String? user]) {
    final conversationType = widget.selectedConversation.type;
    // 宽屏会话「设置」：单聊 / 群聊都走右侧边栏（与群资料形态一致）。
    // user != null 时是群成员名片，仍用轻量浮层。
    if (user == null && widget.showGroupProfile != null) {
      widget.showGroupProfile!();
      return;
    }
    if (conversationType == 1 || user != null) {
      final userID = user ?? widget.selectedConversation.userID;
      if (PlatformOfficialAccountService.showsVerifiedBadge(userID)) {
        return;
      }
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.showUserProfileFromChat,
        context: context,
        isDarkBackground: false,
        width: 350,
        offset: offset,
        height: (widget.selectedConversation.type == 2) ? 490 : 444,
        child: (closeFunc) => Container(
          padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
          child: TIMUIKitProfile(
            smallCardMode: true,
            profileWidgetBuilder: ProfileWidgetBuilder(
              pinConversationBar: (isPinned, onChange) {
                return ConversationProfilePinBar(
                  conversation: widget.selectedConversation,
                  source: 'chat_profile_popup',
                  smallCardMode: true,
                );
              },
              customBuilderOne: (
                bool isFriend,
                V2TimFriendInfo friendInfo,
                V2TimConversation conversation,
              ) {
                return Column(
                  children: _buildBottomOperationList(
                    context,
                    conversation,
                    closeFunc,
                    theme,
                  ),
                );
              },
            ),
            profileWidgetsOrder: const [
              ProfileWidgetEnum.userInfoCard,
              ProfileWidgetEnum.operationDivider,
              ProfileWidgetEnum.remarkBar,
              ProfileWidgetEnum.genderBar,
              ProfileWidgetEnum.birthdayBar,
              ProfileWidgetEnum.operationDivider,
              ProfileWidgetEnum.addToBlockListBar,
              ProfileWidgetEnum.pinConversationBar,
              ProfileWidgetEnum.messageMute,
              ProfileWidgetEnum.customBuilderOne,
            ],
            userID: userID ?? "",
          ),
        ),
      );
    } else {
      if (widget.showGroupProfile != null) {
        widget.showGroupProfile!();
      }
    }
  }

  static void _stickerPanelNoop() {}

  static void _stickerPanelNoopFace(int index, String data) {}

  static void _stickerPanelNoopAddText(int unicode) {}

  static void _stickerPanelNoopCustomEmoji(String singleEmojiName) {}

  StickerPanelConfig _stickerPanelConfigFor(BuildContext context) {
    return StickerPanelConfig(
      useQQStickerPackage: true,
      unicodeEmojiList: TUIKitStickerConstData.defaultUnicodeEmojiList,
      useTencentCloudChatStickerPackage: true,
      customStickerPackages: Provider.of<CustomStickerPackageData>(
        context,
        listen: false,
      ).customStickerPackageList,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 仅用户身份/头像变化需要刷新自己的气泡；LoginUserInfo 的其他通知
    // 不应重建整棵消息列表。
    context.select<LoginUserInfo, (String, String)>((model) {
      final info = model.loginUserInfo;
      return (info.userID?.trim() ?? '', info.faceUrl?.trim() ?? '');
    });
    final routeVisible = RouteVisibility.isRouteVisible(context);
    _scheduleExternalEntryStatePublish(routeVisible: routeVisible);
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final isDarkTheme = Provider.of<DefaultThemeData>(
          context,
          listen: false,
        ).currentThemeType ==
        ThemeType.dark;
    final overlayStyle = buildAppSystemUiOverlayStyle(
      theme,
      isDark: isDarkTheme,
    );

    if (!_heavyChatBodyMounted) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: TickerMode(
          enabled: routeVisible,
          child: TencentPage(
            name: 'chat',
            child: _buildChatTransitionShell(theme),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: TickerMode(
        enabled: routeVisible,
        child: TencentPage(
          name: 'chat',
          child: Selector<LocalSetting, bool>(
            selector: (_, settings) => settings.isShowReadingStatus,
            builder: (context, showReadingStatus, _) {
              return Selector<CustomStickerPackageData, int>(
                selector: (_, packs) => packs.customStickerPackageList.length,
                builder: (context, stickerPackCount, __) {
                  // 勿 context.watch<TUIFriendShipViewModel>()：移动端 push 进 Chat
                  // 时不在 TIMUIKitConversation 的 Provider 子树内，会 ProviderNotFound 灰屏。
                  // 好友/群资料变更由 initState 中 _onFriendshipModelChanged 监听处理。
                  final stickerPanelConfig = _stickerPanelConfigFor(context);
                  final configKey = _configCacheKey(
                    showReadingStatus: showReadingStatus,
                    stickerPackCount: stickerPackCount,
                    isDarkTheme: MorePanelStyles.isDark(theme),
                  );
                  _ensureChatBuildConfigs(
                    context: context,
                    theme: theme,
                    showReadingStatus: showReadingStatus,
                    stickerPanelConfig: stickerPanelConfig,
                    configKey: configKey,
                  );
                  final chatConfig = _cachedChatConfig!;
                  // ValueKey 用稳定的 groupID/userID，避免 resolved conversationID
                  // 首帧为空、随后补全时整棵 TIMUIKitChat remount。
                  final conversationKey = _getConvID()?.trim().isNotEmpty ==
                          true
                      ? _getConvID()!.trim()
                      : (_resolvedConversationID().isNotEmpty
                          ? _resolvedConversationID()
                          : widget.selectedConversation.conversationID
                                  .isNotEmpty
                              ? widget.selectedConversation.conversationID
                              : 'chat_${widget.selectedConversation.type}_'
                                  '${widget.selectedConversation.userID ?? widget.selectedConversation.groupID}');
                  final chatWidget = TIMUIKitChat(
                    key: ValueKey(conversationKey),
                    entryUnreadCount: widget.entryUnreadCount,
                    customEmojiStickerList: buildChatEmojiStickerList(context),
                    // New field, instead of `conversationID` / `conversationType` / `groupAtInfoList` / `conversationShowName` in previous.
                    conversation: _conversation,
                    conversationShowName: conversationName ?? _getTitle(),
                    draftText: _draft.text,
                    onTextChanged: _onChatDraftTextChanged,
                    controller: _chatController,
                    lifeCycle: _chatLifeCycle,
                    groupAtInfoList:
                        widget.selectedConversation.groupAtInfoList,
                    showTotalUnReadCount: true,
                    customStickerPanel: ({
                      void Function() sendTextMessage = _stickerPanelNoop,
                      void Function(int index, String data) sendFaceMessage =
                          _stickerPanelNoopFace,
                      void Function() deleteText = _stickerPanelNoop,
                      void Function(int unicode) addText =
                          _stickerPanelNoopAddText,
                      void Function(String singleEmojiName) addCustomEmojiText =
                          _stickerPanelNoopCustomEmoji,
                      List<CustomEmojiFaceData> defaultCustomEmojiStickerList =
                          const [],
                      double? width,
                      double? height,
                    }) =>
                        StickerChatPanel.build(
                      context: context,
                      stickerPanelConfig: stickerPanelConfig,
                      sendTextMessage: sendTextMessage,
                      sendFaceMessage: sendFaceMessage,
                      deleteText: deleteText,
                      addText: addText,
                      addCustomEmojiText: addCustomEmojiText,
                      defaultCustomEmojiStickerList:
                          defaultCustomEmojiStickerList,
                      height: height,
                      width: width,
                    ),
                    toolTipsConfig: _cachedToolTipsConfig!,
                    config: chatConfig,
                    mainHistoryListConfig: _historyListConfig,
                    conversationID: _getConvID() ?? '',
                    conversationType:
                        ConvType.values[widget.selectedConversation.type ?? 1],
                    onLongPressForOthersHeadPortrait:
                        _getConvType() == ConvType.group
                            ? _onLongPressOthersAvatar
                            : null,
                    onTapAvatar: (userID, tapDetails) =>
                        _onTapAvatar(userID, tapDetails, theme),
                    userAvatarBuilder: (context, message) =>
                        _buildMessageAvatar(message),
                    initFindingMsg: widget.initFindingMsg,
                    searchJumpAnchor: widget.searchJumpAnchor,
                    messageItemBuilder: _messageItemBuilder!,
                    abstractMessageBuilder: buildReplyAbstractMessage,
                    morePanelConfig: _cachedMorePanelConfig!,
                    topFixWidget: _buildChatTopFixWidget(),
                    inputTopBuilder: _resolveChatInputTopBuilder(theme),
                    textFieldBuilder: _resolveChatTextFieldBuilder(theme),
                    textFieldWrapperBuilder:
                        _resolveChatTextFieldWrapperBuilder(theme),
                    appBarConfig: isWideScreen
                        ? AppBar(
                            centerTitle: false,
                            titleSpacing: 0,
                            leadingWidth: 48,
                            elevation: 0,
                            scrolledUnderElevation: 0,
                            surfaceTintColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            backgroundColor:
                                theme.chatHeaderBgColor ?? theme.appbarBgColor,
                            bottom: _chatChromeDividerBar(
                              theme.weakDividerColor ??
                                  AppTokens.chatChromeDivider,
                            ),
                            title: ChatHeaderTitle(
                              key: _chatHeaderTitleKey,
                              peerUserId: widget.selectedConversation.userID,
                              conversationID: _getConvID() ?? '',
                              conversationFaceUrl: _headerConversationFaceUrl(),
                              title: _getHeaderTitleText(),
                              headerState: _headerState,
                              convType: _getConvType(),
                              groupType: _headerGroupType(),
                              onTap: _chatHeaderProfileTap,
                              theme: theme,
                            ),
                            leading: const BackButton(),
                            iconTheme: IconThemeData(
                              color:
                                  theme.primaryColor ?? const Color(0xFF1E90FF),
                            ),
                            actions: _buildChatHeaderActions(theme),
                          )
                        : null,
                    customAppBar: isWideScreen
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 60),
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    Expanded(
                                      child: TIMUIKitAppBar(
                                        onClickTitle: (details) {
                                          onClickUserName(
                                            Offset(
                                              details.globalPosition.dx,
                                              details.globalPosition.dy,
                                            ),
                                            theme,
                                          );
                                        },
                                        config: AppBar(
                                          backgroundColor:
                                              theme.chatHeaderBgColor ??
                                                  theme.appbarBgColor ??
                                                  (isWideScreen
                                                      ? hexToColor("fafafa")
                                                      : hexToColor("f2f3f5")),
                                          foregroundColor:
                                              theme.chatHeaderTitleTextColor ??
                                                  theme.appbarTextColor,
                                          surfaceTintColor: Colors.transparent,
                                          elevation: 0,
                                          scrolledUnderElevation: 0,
                                          title: ChatHeaderTitle(
                                            key: _chatHeaderTitleKey,
                                            peerUserId: widget
                                                .selectedConversation.userID,
                                            conversationID: _getConvID() ?? '',
                                            conversationFaceUrl:
                                                _headerConversationFaceUrl(),
                                            title: _getHeaderTitleText(),
                                            headerState: _headerState,
                                            convType: _getConvType(),
                                            groupType: _headerGroupType(),
                                            onTap: _chatHeaderProfileTap,
                                            theme: theme,
                                          ),
                                          actions: [
                                            ..._buildChatHeaderActions(theme),
                                            IconButton(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                                right: 16,
                                              ),
                                              onPressed: () async {
                                                onClickUserName(
                                                  Offset(
                                                    MediaQuery.of(
                                                          context,
                                                        ).size.width -
                                                        380,
                                                    30,
                                                  ),
                                                  theme,
                                                );
                                              },
                                              icon: Icon(
                                                Icons.more_horiz,
                                                color: theme.primaryColor ??
                                                    const Color(0xFF1E90FF),
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                        conversationShowName: _getTitle(),
                                        conversationID: _getConvID() ?? "",
                                        showC2cMessageEditStatus: true,
                                      ),
                                    ),
                                    SizedBox(
                                      height: AppTokens.chatChromeDividerWidth,
                                      child: ColoredBox(
                                        color: theme.weakDividerColor ??
                                            AppTokens.chatChromeDivider,
                                      ),
                                    ),
                                  ],
                                ),
                                if (PlatformUtils().isMacOS)
                                  SizedBox(height: 20, child: MoveWindow()),
                              ],
                            ),
                          )
                        : const PreferredSize(
                            preferredSize: Size.zero,
                            child: SizedBox.shrink(),
                          ),
                  );
                  final groupGameFloat = _buildGroupGameFloatingEntry(theme);
                  final agentRebateFloat = _buildAgentRebateFloatingEntry(
                    theme,
                  );
                  final gatedChat = _wrapChatWithOpenHistoryGate(chatWidget);
                  final chatBody =
                      (groupGameFloat == null && agentRebateFloat == null)
                          ? gatedChat
                          : Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.none,
                              children: [
                                gatedChat,
                                if (groupGameFloat != null) groupGameFloat,
                                if (agentRebateFloat != null) agentRebateFloat,
                              ],
                            );
                  if (isWideScreen) {
                    return chatBody;
                  }
                  return ChatMultiSelectPopGuard(
                    uiStateStore: serviceLocator<ChatUiStateStore>(),
                    conversationID: _getConvID() ?? '',
                    onCancelMultiSelect: _exitChatMultiSelect,
                    child: Scaffold(
                      resizeToAvoidBottomInset: false,
                      backgroundColor: theme.chatBgColor,
                      appBar: _buildChatAppBar(
                        theme,
                        headerInteractive: true,
                      ),
                      body: chatBody,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
