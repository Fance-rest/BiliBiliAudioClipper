import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bilibili_audio_clipper/providers/bilibili_provider.dart';
import 'package:bilibili_audio_clipper/providers/netease_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final neteaseProvider = context.read<NeteaseProvider>();
      _apiUrlCtrl.text = neteaseProvider.baseUrl;
    });
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: CupertinoColors.systemGrey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildCardRow({required Widget child, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
              ),
      ),
      child: child,
    );
  }

  Widget _buildQrDisplay(String qrData) {
    if (qrData.startsWith('data:image')) {
      final bytes = base64Decode(qrData.split(',').last);
      return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
    }
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: 200,
    );
  }

  Future<void> _showErrorDialog(String title, Object error) async {
    if (!mounted) {
      return;
    }
    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(error.toString()),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
    );
  }

  // ---- B站账号 section ----
  Widget _buildBilibiliSection(BilibiliProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('B站账号'),
        _buildCard([
          if (!provider.isLoggedIn && provider.qrCodeUrl == null && !provider.qrLoginStatus.startsWith('正在'))
            _buildCardRow(
              isLast: true,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('未登录', style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => provider.startQrLogin(),
                        child: const Text('扫码登录', style: TextStyle(color: Color(0xFF007AFF))),
                      ),
                    ],
                  ),
                  if (provider.qrLoginStatus.contains('失败'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        provider.qrLoginStatus,
                        style: const TextStyle(fontSize: 13, color: CupertinoColors.destructiveRed),
                      ),
                    ),
                ],
              ),
            )
          else if (provider.qrLoginStatus.startsWith('正在'))
            _buildCardRow(
              isLast: true,
              child: const Center(child: CupertinoActivityIndicator()),
            )
          else if (provider.qrCodeUrl != null)
            _buildCardRow(
              isLast: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '请用另一台设备上的哔哩哔哩 App 扫描下方二维码',
                    style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: QrImageView(
                      data: provider.qrCodeUrl!,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.qrLoginStatus,
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => provider.cancelQrLogin(),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _buildCardRow(
              child: const Row(
                children: [
                  Icon(CupertinoIcons.person_circle_fill,
                      color: Color(0xFF007AFF), size: 36),
                  SizedBox(width: 12),
                  Text('已登录', style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
            _buildCardRow(
              isLast: true,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => provider.logout(),
                child: const Text(
                  '退出登录',
                  style: TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ),
          ],
        ]),
      ],
    );
  }

  // ---- API 服务 section ----
  Widget _buildApiSection(NeteaseProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('API 服务'),
        _buildCard([
          _buildCardRow(
            isLast: true,
            child: Row(
              children: [
                const Text('服务地址', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoTextField(
                    controller: _apiUrlCtrl,
                    placeholder: 'http://100.x.x.x:3000',
                    textAlign: TextAlign.right,
                    decoration: const BoxDecoration(),
                    style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 15),
                    onSubmitted: (val) => provider.setBaseUrl(val.trim()),
                    onEditingComplete: () => provider.setBaseUrl(_apiUrlCtrl.text.trim()),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ---- 网易云账号 section ----
  Widget _buildNeteaseSection(NeteaseProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('网易云账号'),
        _buildCard([
          if (!provider.isLoggedIn && provider.qrCodeUrl == null && provider.qrLoginStatus.isEmpty) ...[
            _buildCardRow(
              isLast: true,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(8),
                onPressed: () async {
                  try {
                    await provider.setBaseUrl(_apiUrlCtrl.text.trim());
                    await provider.startQrLogin();
                  } catch (e) {
                    await _showErrorDialog('登录失败', e);
                  }
                },
                child: const Text('扫码登录', style: TextStyle(color: CupertinoColors.white)),
              ),
            ),
          ] else if (!provider.isLoggedIn) ...[
            _buildCardRow(
              isLast: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    provider.qrLoginStatus.isEmpty ? '请使用网易云音乐 App 扫码' : provider.qrLoginStatus,
                    style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (provider.qrCodeUrl != null)
                    Center(
                      child: _buildQrDisplay(provider.qrCodeUrl!),
                    )
                  else
                    const Center(child: CupertinoActivityIndicator()),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => provider.cancelQrLogin(),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildCardRow(
              child: Row(
                children: [
                  if (provider.avatarUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        provider.avatarUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          CupertinoIcons.person_circle_fill,
                          size: 36,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    )
                  else
                    const Icon(CupertinoIcons.person_circle_fill,
                        size: 36, color: Color(0xFF34C759)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.nickname ?? '已登录',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        if (provider.phone != null)
                          Text(
                            _maskPhone(provider.phone!),
                            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                          )
                        else
                          const Text(
                            '扫码登录',
                            style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildCardRow(
              isLast: true,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => provider.logout(),
                child: const Text(
                  '退出登录',
                  style: TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ),
          ],
        ]),
      ],
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Consumer2<BilibiliProvider, NeteaseProvider>(
            builder: (context, bilibiliProvider, neteaseProvider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBilibiliSection(bilibiliProvider),
                  _buildApiSection(neteaseProvider),
                  _buildNeteaseSection(neteaseProvider),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
