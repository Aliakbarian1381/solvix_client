import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_info_bloc.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String chatId;
  final GroupInfoModel groupInfo;
  final UserModel? currentUser;

  const GroupSettingsScreen({
    super.key,
    required this.chatId,
    required this.groupInfo,
    required this.currentUser,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late GroupSettingsModel _settings;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.groupInfo.settings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات گروه'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'ذخیره',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: BlocListener<GroupInfoBloc, GroupInfoState>(
        listener: (context, state) {
          if (state is GroupInfoUpdated) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is GroupInfoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.security, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تنظیمات امنیتی گروه',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'این تنظیمات تعیین می‌کند چه کسانی چه عملیاتی را می‌توانند انجام دهند',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Messages Settings
            _buildSettingsCard(
              context,
              'مجوزهای پیام‌رسانی',
              [
                _buildSettingTile(
                  context,
                  'ارسال پیام',
                  'تعیین کنید چه کسانی می‌توانند در گروه پیام بفرستند',
                  Icons.message,
                  _settings.onlyAdminsCanSendMessages,
                      (value) =>
                      _updateSetting(
                        _settings.copyWith(onlyAdminsCanSendMessages: value),
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Members Management Settings
            _buildSettingsCard(
              context,
              'مدیریت اعضا',
              [
                _buildSettingTile(
                  context,
                  'اضافه کردن عضو',
                  'تعیین کنید چه کسانی می‌توانند عضو جدید اضافه کنند',
                  Icons.person_add,
                  _settings.onlyAdminsCanAddMembers,
                      (value) =>
                      _updateSetting(
                        _settings.copyWith(onlyAdminsCanAddMembers: value),
                      ),
                ),
                _buildSettingTile(
                  context,
                  'ویرایش اطلاعات گروه',
                  'تعیین کنید چه کسانی می‌توانند نام و توضیحات گروه را تغییر دهند',
                  Icons.edit,
                  _settings.onlyAdminsCanEditGroupInfo,
                      (value) =>
                      _updateSetting(
                        _settings.copyWith(onlyAdminsCanEditGroupInfo: value),
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Group Limits
            _buildSettingsCard(
              context,
              'محدودیت‌ها',
              [
                _buildMaxMembersSlider(context),
              ],
            ),

            const SizedBox(height: 32),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تغییرات تنظیمات بلافاصله بر روی تمام اعضای گروه اعمال می‌شود. فقط مالک و ادمین‌های گروه می‌توانند این تنظیمات را تغییر دهند.',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, String title,
      List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      bool value,
      Function(bool) onChanged,) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme
                  .of(context)
                  .primaryColor
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme
                  .of(context)
                  .primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme
                .of(context)
                .primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMaxMembersSlider(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme
                    .of(context)
                    .primaryColor
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.groups,
                size: 20,
                color: Theme
                    .of(context)
                    .primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حداکثر تعداد اعضا: ${_settings.maxMembers}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'تعیین کنید حداکثر چند نفر می‌توانند عضو این گروه باشند',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme
                .of(context)
                .primaryColor,
            thumbColor: Theme
                .of(context)
                .primaryColor,
            overlayColor: Theme
                .of(context)
                .primaryColor
                .withOpacity(0.2),
          ),
          child: Slider(
            value: _settings.maxMembers.toDouble(),
            min: 10,
            max: 1000,
            divisions: 99,
            label: '${_settings.maxMembers} نفر',
            onChanged: (value) {
              _updateSetting(_settings.copyWith(maxMembers: value.round()));
            },
          ),
        ),
      ],
    );
  }

  void _updateSetting(GroupSettingsModel newSettings) {
    setState(() {
      _settings = newSettings;
      _hasChanges = true;
    });
  }

  void _saveSettings() {
    context.read<GroupInfoBloc>().add(
      UpdateGroupSettings(
        chatId: widget.chatId,
        settings: _settings,
      ),
    );
  }
}

extension GroupRoleExtension on GroupRole {
  String get displayName {
    switch (this) {
      case GroupRole.owner:
        return 'مالک';
      case GroupRole.admin:
        return 'ادمین';
      case GroupRole.member:
        return 'عضو';
    }
  }

  Color get color {
    switch (this) {
      case GroupRole.owner:
        return Colors.amber;
      case GroupRole.admin:
        return Colors.blue;
      case GroupRole.member:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case GroupRole.owner:
        return Icons.crown;
      case GroupRole.admin:
        return Icons.admin_panel_settings;
      case GroupRole.member:
        return Icons.person;
    }
  }
}