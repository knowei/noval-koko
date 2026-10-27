import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/net_diag.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets.dart';

/// 诊断页专用的状态色（调色板里只放中性色，语义色就地定义）。
const Color _danger = Color(0xFFB4544A);
const Color _warn = Color(0xFFB8862B);

/// 网络诊断页：把一组域名逐个探一遍，边探边刷新。
///
/// 用在两处：我的页（探全部书源的域名）、书源行菜单（只探这一个源）。
class NetDiagPage extends StatefulWidget {
  const NetDiagPage({
    super.key,
    required this.hosts,
    this.title = '网络诊断',
    this.note = '',
  });

  final List<String> hosts;
  final String title;
  final String note;

  @override
  State<NetDiagPage> createState() => _NetDiagPageState();
}

class _NetDiagPageState extends State<NetDiagPage> {
  final Map<String, HostProbe> _done = <String, HostProbe>{};
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // 首帧后再探，避免在 build 里 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_running || widget.hosts.isEmpty) return;
    setState(() {
      _running = true;
      _done.clear();
    });
    await NetDiag.probeAll(
      widget.hosts,
      onEach: (HostProbe probe) {
        if (!mounted) return;
        setState(() => _done[probe.host] = probe);
      },
    );
    if (!mounted) return;
    setState(() => _running = false);
  }

  List<HostProbe> get _ordered => <HostProbe>[
        for (final String host in widget.hosts)
          if (_done[host] != null) _done[host]!,
      ];

  Future<void> _copyReport(List<HostProbe> probes) async {
    final String text = NetDiag.report(
      probes,
      title: widget.title,
      note: widget.note,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('报告已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final List<HostProbe> probes = _ordered;
    final int total = widget.hosts.length;
    final int ok = probes.where((HostProbe x) => x.ok).length;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            PageHeader(
              title: widget.title,
              subtitle: total == 0
                  ? '这个源里没找到域名'
                  : '${probes.length}/$total 已探 · $ok 个可用',
              leading: IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: _running ? null : _run,
                  child: Text(_running ? '检测中…' : '重新检测'),
                ),
              ],
            ),
            Expanded(child: _body(p, probes, total, ok)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppPalette p, List<HostProbe> probes, int total, int ok) {
    if (total == 0) {
      return const EmptyHint(
        icon: Icons.wifi_tethering_off,
        title: '没有可探测的域名',
        subtitle: '书源里没写完整地址，或者只用了相对路径。',
      );
    }
    final int bad = probes.length - ok;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        0,
        AppSpace.page,
        AppSpace.xl,
      ),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.note.isEmpty
                    ? '先解析 DNS，再请求首页。红色说明网络到不了这个站，'
                        '这时候改规则没有意义。'
                    : widget.note,
                style: context.text.bodySmall?.copyWith(color: p.inkMid),
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: <Widget>[
                  Text('可用 $ok / ${probes.length}',
                      style: context.text.bodyMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: probes.isEmpty
                        ? null
                        : () => _copyReport(probes),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('复制报告'),
                  ),
                ],
              ),
              if (bad > 0) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  '有 $bad 个域名不通。先解决网络（换网络 / 开代理 / 换镜像站），'
                  '再谈规则。',
                  style: context.text.bodySmall?.copyWith(color: _danger),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        for (final HostProbe probe in probes) ...<Widget>[
          _ProbeRow(probe: probe),
          const SizedBox(height: AppSpace.xs),
        ],
      ],
    );
  }
}

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({required this.probe});

  final HostProbe probe;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color dot = probe.ok
        ? p.primary
        : (probe.dnsOk ? _warn : _danger);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  probe.host,
                  style: context.text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  probe.label,
                  style: context.text.bodySmall?.copyWith(color: p.inkMid),
                ),
                if (probe.ips.isNotEmpty)
                  Text(
                    probe.ips.join(' · '),
                    style: context.text.bodySmall?.copyWith(color: p.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
