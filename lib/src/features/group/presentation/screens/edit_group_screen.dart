import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_info_bloc.dart';

class EditGroupScreen extends StatefulWidget {
  final String chatId;
  final GroupInfoModel groupInfo;

  const EditGroupScreen({
    super.key,
    required this.chatId,
    required this.groupInfo,
  });

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  File? _selectedImage;
  bool _hasChanges = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.groupInfo.title);
    _descriptionController = TextEditingController(
      text: widget.groupInfo.description ?? '',
    );

    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasTextChanges =
        _titleController.text != widget.groupInfo.title ||
        _descriptionController.text != (widget.groupInfo.description ?? '');

    setState(() {
      _hasChanges = hasTextChanges || _selectedImage != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش گروه'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('ذخیره', style: TextStyle(color: Colors.white)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Image Section
              _buildImageSection(context),

              const SizedBox(height: 24),

              // Group Title
              _buildTitleSection(context),

              const SizedBox(height: 16),

              // Group Description
              _buildDescriptionSection(context),

              const SizedBox(height: 24),

              // Info Card
              _buildInfoCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تصویر گروه',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: widget.groupInfo.avatarUrl != null
                          ? CachedNetworkImageProvider(widget.groupInfo.avatarUrl!)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'برای تغییر تصویر کلیک کنید',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نام گروه',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'نام گروه را وارد کنید',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توضیحات گروه',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'توضیحاتی درباره گروه بنویسید (اختیاری)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تغییرات برای همه اعضای گروه قابل مشاهده خواهد بود. اطمینان حاصل کنید که نام و توضیحات مناسب انتخاب کرده‌اید.',
              style: TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getGroupImage() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    } else if (widget.groupInfo.avatarUrl != null) {
      return CachedNetworkImageProvider(widget.groupInfo.avatarUrl!);
    }
    return null;
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('دوربین'),
              onTap: () {
                Navigator.pop(context);
                _getImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('گالری'),
              onTap: () {
                Navigator.pop(context);
                _getImageFromSource(ImageSource.gallery);
              },
            ),
            if (widget.groupInfo.avatarUrl != null ||
                _selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'حذف تصویر',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _hasChanges = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا در انتخاب تصویر: $e')));
      }
    }
  }

  void _saveChanges() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نام گروه نمی‌تواند خالی باشد'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: If image is selected, upload it first and get the URL
    // For now, we'll just update text fields
    context.read<GroupInfoBloc>().add(
      UpdateGroupInfo(
        chatId: widget.chatId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ),
    );
  }
}
