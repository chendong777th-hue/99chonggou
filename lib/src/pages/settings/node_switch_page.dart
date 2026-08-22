import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/api_node_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

class NodeSwitchPage extends StatefulWidget {
  const NodeSwitchPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<NodeSwitchPage> createState() => _NodeSwitchPageState();
}

class _NodeSwitchPageState extends State<NodeSwitchPage> {
  final ApiNodeService _nodes = ApiNodeService.instance;

  @override
  void initState() {
    super.initState();
    _nodes.addListener(_onNodesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_nodes.isHydrated) {
        await _nodes.hydrate();
      }
      if (!mounted) return;
      // 进入页面自动测一次，贴近产品截图有延迟数据。
      if (_nodes.lastProbeAt == null && !_nodes.isProbing) {
        unawaited(_nodes.probeAll());
      }
    });
  }

  @override
  void dispose() {
    _nodes.removeListener(_onNodesChanged);
    super.dispose();
  }

  void _onNodesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatProbeTime(AppI18n i18n) {
    final at = _nodes.lastProbeAt;
    if (at == null) {
      return i18n.t(
        zhHans: '尚未测速',
        zhHant: '尚未測速',
        en: 'Not tested',
        ja: '未測定',
        ko: '미측정',
      );
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  String _statusLabel(AppI18n i18n, ApiNodeProbeResult? probe) {
    final status = probe?.status ?? ApiNodeProbeStatus.unknown;
    switch (status) {
      case ApiNodeProbeStatus.normal:
        final ms = probe?.latencyMs;
        final base = i18n.t(
          zhHans: '正常',
          zhHant: '正常',
          en: 'OK',
          ja: '正常',
          ko: '정상',
        );
        if (ms == null) {
          return base;
        }
        return '$base (${ms}ms)';
      case ApiNodeProbeStatus.abnormal:
        return i18n.t(
          zhHans: '异常',
          zhHant: '異常',
          en: 'Abnormal',
          ja: '異常',
          ko: '이상',
        );
      case ApiNodeProbeStatus.unknown:
        return i18n.t(
          zhHans: '未知',
          zhHant: '未知',
          en: 'Unknown',
          ja: '不明',
          ko: '알 수 없음',
        );
    }
  }

  Color _statusColor(bool dark, ApiNodeProbeResult? probe) {
    final status = probe?.status ?? ApiNodeProbeStatus.unknown;
    switch (status) {
      case ApiNodeProbeStatus.normal:
        return const Color(0xFF34C759);
      case ApiNodeProbeStatus.abnormal:
        return AppColors.primaryRed;
      case ApiNodeProbeStatus.unknown:
        return AppColors.subText(dark: dark);
    }
  }

  Future<void> _onSelect(String nodeId) async {
    await _nodes.selectNode(nodeId);
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);
    final text = AppColors.text(dark: dark);
    final sub = AppColors.subText(dark: dark);
    final accent = AppTokens.accent;

    return SettingsScaffold(
      embedded: widget.embedded,
      title: i18n.t(
        zhHans: '节点切换',
        zhHant: '節點切換',
        en: 'Node Switch',
        ja: 'ノード切替',
        ko: '노드 전환',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _nodes.isProbing
                    ? null
                    : () => unawaited(_nodes.probeAll()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.7)),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                icon: _nodes.isProbing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Icon(Icons.speed_rounded, size: 18, color: accent),
                label: Text(
                  i18n.t(
                    zhHans: '手动测速',
                    zhHant: '手動測速',
                    en: 'Speed Test',
                    ja: '速度測定',
                    ko: '속도 측정',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    i18n.t(
                      zhHans: '测速时间',
                      zhHant: '測速時間',
                      en: 'Tested at',
                      ja: '測定時刻',
                      ko: '측정 시간',
                    ),
                    style: TextStyle(color: sub, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatProbeTime(i18n),
                    style: TextStyle(color: sub, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsGroup(
          children: [
            for (var i = 0; i < ApiNodeService.catalog.length; i++)
              _NodeRow(
                // 列表只展示友好名称，绝不渲染 IP / 域名 / 端口。
                title: ApiNodeService.catalog[i].name,
                selected: _nodes.selectedNodeId ==
                    ApiNodeService.catalog[i].id,
                statusText: _statusLabel(
                  i18n,
                  _nodes.probeOf(ApiNodeService.catalog[i].id),
                ),
                statusColor: _statusColor(
                  dark,
                  _nodes.probeOf(ApiNodeService.catalog[i].id),
                ),
                textColor: text,
                showDivider: i != ApiNodeService.catalog.length - 1,
                onTap: () => unawaited(
                  _onSelect(ApiNodeService.catalog[i].id),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Text(
            i18n.t(
              zhHans:
                  '加载失败或速度慢时，可手动切换节点提升体验。\n\n'
                  '状态说明：正常 / 异常 / 未知。可切换 4G、5G、Wi‑Fi 后重新测速，选择延迟更低的节点。',
              zhHant:
                  '載入失敗或速度慢時，可手動切換節點提升體驗。\n\n'
                  '狀態說明：正常 / 異常 / 未知。可切換 4G、5G、Wi‑Fi 後重新測速，選擇延遲更低的節點。',
              en:
                  'If loading fails or feels slow, switch nodes manually.\n\n'
                  'Status: OK / Abnormal / Unknown. Retest on 4G, 5G, or Wi‑Fi '
                  'and pick the lower-latency node.',
              ja:
                  '読み込み失敗や遅い場合はノードを切り替えてください。\n\n'
                  '状態：正常 / 異常 / 不明。4G・5G・Wi‑Fi を変えて再測定し、'
                  '遅延の小さいノードを選んでください。',
              ko:
                  '로딩 실패나 속도가 느릴 때 노드를 직접 바꿔보세요.\n\n'
                  '상태: 정상 / 이상 / 알 수 없음. 4G·5G·Wi‑Fi를 바꾼 뒤 '
                  '다시 측정해 지연이 낮은 노드를 선택하세요.',
            ),
            style: TextStyle(
              color: sub,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.title,
    required this.selected,
    required this.statusText,
    required this.statusColor,
    required this.textColor,
    required this.showDivider,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final String statusText;
  final Color statusColor;
  final Color textColor;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.line(dark: settingsIsDark(context)),
                    width: 0.6,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.circle, size: 8, color: statusColor),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 22,
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      color: AppTokens.accent,
                      size: 22,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
