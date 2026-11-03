import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class _StagedProduct {
  final String title;
  final String description;
  final double price;
  final String url;
  final File? imageFile;

  _StagedProduct({
    required this.title,
    required this.description,
    required this.price,
    required this.url,
    this.imageFile,
  });
}

class AddProductScreen extends StatefulWidget {
  final String action; // 'add' | 'edit'
  final int businessId;
  final Map<String, dynamic>? product;
  final int currentCount;
  final int productLimit;

  const AddProductScreen({
    super.key,
    required this.action,
    required this.businessId,
    this.product,
    this.currentCount = 0,
    this.productLimit = 5,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const _green = Color(0xFF1B4748);
  static const _red = Color(0xFFF48900);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  File? _pickedImage;
  bool _acceptedTerms = false;
  bool _saving = false;
  String? _existingImageUrl;

  final List<_StagedProduct> _staged = [];

  @override
  void initState() {
    super.initState();
    if (widget.action == 'edit' && widget.product != null) {
      final p = widget.product!;
      _titleCtrl.text = p['title'] ?? '';
      _descCtrl.text = p['description'] ?? '';
      _priceCtrl.text = (p['price'] ?? '').toString();
      _urlCtrl.text = p['url'] ?? '';
      _existingImageUrl = p['main_image'] as String?;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _existingImageUrl = null;
      });
    }
  }

  void _removeImage() => setState(() {
        _pickedImage = null;
        _existingImageUrl = null;
      });

  bool _validateForm() {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Title is required.');
      return false;
    }
    if (_priceCtrl.text.trim().isEmpty) {
      _showError('Price is required.');
      return false;
    }
    if (double.tryParse(_priceCtrl.text.trim()) == null) {
      _showError('Price must be a valid number.');
      return false;
    }
    if (_urlCtrl.text.trim().isEmpty) {
      _showError('URL is required.');
      return false;
    }
    return true;
  }

  void _stageProduct() {
    if (!_validateForm()) return;
    final remaining =
        widget.productLimit - widget.currentCount - _staged.length;
    if (remaining <= 0) {
      _showError(
          'You have reached the product limit (${widget.productLimit}).');
      return;
    }
    setState(() {
      _staged.add(_StagedProduct(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        url: _urlCtrl.text.trim(),
        imageFile: _pickedImage,
      ));
      _titleCtrl.clear();
      _descCtrl.clear();
      _priceCtrl.clear();
      _urlCtrl.clear();
      _pickedImage = null;
    });
  }

  void _removeStaged(int index) => setState(() => _staged.removeAt(index));

  Future<void> _save() async {
    if (widget.action == 'add') {
      if (_staged.isEmpty) {
        _showError('Please add at least one product first.');
        return;
      }
      if (!_acceptedTerms) {
        _showError('You must accept the terms to continue.');
        return;
      }
      await _saveNew();
    } else {
      if (!_validateForm()) return;
      await _saveEdit();
    }
  }

  Future<void> _saveNew() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      final fields = <String, String>{};
      final files = <String, File>{};
      for (var i = 0; i < _staged.length; i++) {
        final p = _staged[i];
        fields['products[$i][title]'] = p.title;
        fields['products[$i][description]'] = p.description;
        fields['products[$i][price]'] = p.price.toString();
        fields['products[$i][url]'] = p.url;
        if (p.imageFile != null) files['products[$i][image]'] = p.imageFile!;
      }
      fields['business'] = widget.businessId.toString();

      final response = await auth.apiService.postMultipart(
        '/api/v1/directory/business/${widget.businessId}/products/c/',
        fields: fields,
        files: files,
      );
      if (!mounted) return;
      _showSuccess('Products created successfully.');
      Navigator.pop(context, response);
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not save products. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveEdit() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final productId = widget.product!['id'];
    try {
      final fields = <String, String>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'url': _urlCtrl.text.trim(),
        'business': widget.businessId.toString(),
      };
      final files = <String, File>{};
      if (_pickedImage != null) files['image'] = _pickedImage!;

      final response = await auth.apiService.patchMultipart(
        '/api/v1/directory/business/product/$productId/u/',
        fields: fields,
        files: files,
      );
      if (!mounted) return;
      _showSuccess('Product updated successfully.');
      Navigator.pop(context, response);
    } on DioException catch (e) {
      _showError(
          e.response?.data?['error'] ?? 'Could not update product. Try again.');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _green));

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.action == 'edit';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Edit Product' : 'Add Products'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEdit) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Add your top products here. They link to the real product pages on your website. '
                    'Fill in the form and tap Add to stage each product, then tap Save when done.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: _green),
                    const SizedBox(width: 6),
                    Text(
                      'Products: ${widget.currentCount + _staged.length} / ${widget.productLimit}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _green,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Form card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ImagePickerWidget(
                          imageFile: _pickedImage,
                          existingUrl: _existingImageUrl,
                          onPick: _pickImage,
                          onRemove: _removeImage,
                        ),
                        const SizedBox(height: 20),
                        _label('Title', required: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: _inputDecoration('Product title'),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        _label('Description'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: _inputDecoration(
                              'Product description (optional)'),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 16),
                        _label('Price (R)', required: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _priceCtrl,
                          decoration: _inputDecoration('0.00')
                              .copyWith(prefixText: 'R '),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _label('URL', required: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _urlCtrl,
                          decoration:
                              _inputDecoration('Link to the product page'),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                        ),
                        const SizedBox(height: 20),
                        if (!isEdit)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _stageProduct,
                              icon: const Icon(Icons.add, color: _green),
                              label: const Text('Add to List',
                                  style: TextStyle(
                                      color: _green,
                                      fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _green),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Staged grid
              if (_staged.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Products Added',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _green)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _staged.length,
                  itemBuilder: (ctx, i) => _StagedProductCard(
                    product: _staged[i],
                    onRemove: () => _removeStaged(i),
                  ),
                ),
              ],

              // Terms
              if (!isEdit) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      activeColor: _green,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: RichText(
                          text: const TextSpan(
                            style:
                                TextStyle(color: Colors.black87, fontSize: 13),
                            children: [
                              TextSpan(text: 'I accept the '),
                              TextSpan(
                                text: 'terms',
                                style: TextStyle(
                                  color: _green,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Buttons
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => RichText(
        text: TextSpan(
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: _red)),
          ],
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _green, width: 1.5)),
      );
}

// ─── Image Picker Widget ──────────────────────────────────────────────────────

class _ImagePickerWidget extends StatelessWidget {
  final File? imageFile;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  static const _green = Color(0xFF1B4748);

  const _ImagePickerWidget({
    required this.imageFile,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasImage => imageFile != null || existingUrl != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Image',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _hasImage ? null : onPick,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(imageFile!, fit: BoxFit.cover),
                  )
                else if (existingUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(existingUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _NoImagePlaceholder()),
                  )
                else
                  const _NoImagePlaceholder(),
                if (_hasImage)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(7)),
                      ),
                      child: const Text('Upload',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_hasImage) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onPick,
            child: const Text('Change image',
                style: TextStyle(
                    color: _green,
                    fontSize: 12,
                    decoration: TextDecoration.underline)),
          ),
        ],
        const SizedBox(height: 4),
        Text('300 × 300 px recommended',
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ],
    );
  }
}

class _NoImagePlaceholder extends StatelessWidget {
  const _NoImagePlaceholder();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, color: Colors.grey[400], size: 32),
        const SizedBox(height: 4),
        Text('No image',
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ],
    );
  }
}

// ─── Staged Product Card ──────────────────────────────────────────────────────

class _StagedProductCard extends StatelessWidget {
  final _StagedProduct product;
  final VoidCallback onRemove;

  static const _red = Color(0xFFF48900);
  static const _green = Color(0xFF1B4748);

  const _StagedProductCard({required this.product, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(7)),
                  child: product.imageFile != null
                      ? Image.file(product.imageFile!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[100],
                          child: Icon(Icons.image_outlined,
                              color: Colors.grey[400], size: 28),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: _green),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'R ${product.price.toStringAsFixed(2)}',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 11),
            ),
          ),
        ),
      ],
    );
  }
}
