import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_info_bloc.dart';

class GroupSettingsPanel extends StatefulWidget {
  final GroupInfoModel groupInfo;
  final bool canEdit;

  const GroupSettingsPanel({
    Key? key,
    required this.groupInfo,
    required this.canEdit,
  }) : super(key: key);

  @override
  State<GroupSettingsPanel> createState() => _GroupSettingsPanelState();
}

class _GroupSettingsPanelState extends State<GroupSettingsPanel> {
  late GroupSettingsModel _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.groupInfo.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تنظیمات گروه',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildSettingTile(
          title: 'فقط ادمین‌ها پیام بفرستند',
          subtitle: 'تنها مدیران و مالک می‌توانند پیام ارسال کنند',
          value: _settings.onlyAdminsCanSendMessages,
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _settings = _settings.copyWith(
                      onlyAdminsCanSendMessages: value,
                    );
                  });
                  _updateSettings();
                }
              : null,
        ),
        _buildSettingTile(
          title: 'فقط ادمین‌ها عضو اضافه کنند',
          subtitle: 'تنها مدیران و مالک می‌توانند عضو جدید اضافه کنند',
          value: _settings.onlyAdminsCanAddMembers,
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _settings = _settings.copyWith(
                      onlyAdminsCanAddMembers: value,
                    );
                  });
                  _updateSettings();
                }
              : null,
        ),
        _buildSettingTile(
          title: 'فقط ادمین‌ها اطلاعات گروه را ویرایش کنند',
          subtitle:
              'تنها مدیران و مالک می‌توانند نام و توضیحات گروه را تغییر دهند',
          value: _settings.onlyAdminsCanEditInfo,
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _settings = _settings.copyWith(
                      onlyAdminsCanEditInfo: value,
                    );
                  });
                  _updateSettings();
                }
              : null,
        ),
        _buildSettingTile(
          title: 'فقط ادمین‌ها پیام حذف کنند',
          subtitle: 'تنها مدیران و مالک می‌توانند پیام‌های دیگران را حذف کنند',
          value: _settings.onlyAdminsCanDeleteMessages,
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _settings = _settings.copyWith(
                      onlyAdminsCanDeleteMessages: value,
                    );
                  });
                  _updateSettings();
                }
              : null,
        ),
        _buildSettingTile(
          title: 'اجازه خروج اعضا',
          subtitle: 'اعضا می‌توانند خودشان از گروه خارج شوند',
          value: _settings.allowMemberToLeave,
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _settings = _settings.copyWith(allowMemberToLeave: value);
                  });
                  _updateSettings();
                }
              : null,
        ),
        _buildSettingTile(
          title: 'گروه عمومی',
          subtitle: 'هر کسی می‌تواند به گروه بپیوندد',
          value: _settings.isPublic,
          onChanged: widget.canEdit
              ? (value) {
                  setState(() {
                    _settings = _settings.copyWith(isPublic: value);
                  });
                  _updateSettings();
                }
              : null,
        ),
        const SizedBox(height: 24),
        _buildMaxMembersSection(),
      ],
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildMaxMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حداکثر تعداد اعضا',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'تعداد فعلی: ${widget.groupInfo.membersCount} نفر',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'حداکثر: ${_settings.maxMembers} نفر',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (widget.canEdit) ...[
              Slider(
                value: _settings.maxMembers.toDouble(),
                min: widget.groupInfo.membersCount.toDouble(),
                max: 1000,
                divisions: 100,
                label: _settings.maxMembers.toString(),
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(maxMembers: value.round());
                  });
                },
                onChangeEnd: (value) => _updateSettings(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateSettings() {
    context.read<GroupInfoBloc>().add(
      UpdateGroupSettings(chatId: widget.groupInfo.id, settings: _settings),
    );
  }
}
