import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets/common.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';

class AppCreateScreen extends ConsumerStatefulWidget {
  const AppCreateScreen({super.key});

  @override
  ConsumerState<AppCreateScreen> createState() => _AppCreateScreenState();
}

class _AppCreateScreenState extends ConsumerState<AppCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _slug = TextEditingController();
  final _name = TextEditingController();
  final _audience = TextEditingController();
  final _description = TextEditingController();
  final _icon = TextEditingController();
  final _marketing = TextEditingController();
  bool _busy = false;
  bool _slugEdited = false;

  @override
  void dispose() {
    for (final c in [_slug, _name, _audience, _description, _icon, _marketing]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Suggests a slug from the name until the user edits it.
  void _onNameChanged(String name) {
    if (_slugEdited) return;
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    _slug.text = slug.length > 40 ? slug.substring(0, 40) : slug;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final app = await runAction(
      context,
      () => ref
          .read(appsRepositoryProvider)
          .create(
            slug: _slug.text.trim(),
            name: _name.text.trim(),
            apiAudience: _audience.text.trim(),
            description: trimmedOrNull(_description.text),
            iconUrl: trimmedOrNull(_icon.text),
            marketingUrl: trimmedOrNull(_marketing.text),
          ),
      success: 'App created',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (app != null) {
      ref.invalidate(appsListProvider);
      context.pushReplacement(Routes.app(app.slug, tab: 'clients'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New app')),
      body: Form(
        key: _form,
        child: PageBody(
          children: [
            SectionCard(
              title: 'App',
              subtitle: 'One product (e.g. "Astro Graph"). Its websites and mobile apps are clients of it.',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    maxLength: 100,
                    textInputAction: TextInputAction.next,
                    onChanged: _onNameChanged,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _slug,
                    decoration: const InputDecoration(
                      labelText: 'Slug',
                      helperText: 'Lowercase letters, digits and dashes. Used in client IDs; cannot be changed.',
                      helperMaxLines: 2,
                    ),
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _slugEdited = true,
                    validator: (v) => AppModel.slugPattern.hasMatch((v ?? '').trim())
                        ? null
                        : '2 to 40 characters: a-z, 0-9 and "-", not starting with "-"',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _audience,
                    decoration: const InputDecoration(
                      labelText: 'API audience URL',
                      hintText: 'https://api.example.com',
                      helperText: "Your API's identifier: access tokens are issued for it. Must be unique.",
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: validateHttpUrl,
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Listing (optional)',
              subtitle: 'Shown to users in the account centre and "our other apps".',
              child: Column(
                children: [
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLength: 500,
                    maxLines: 3,
                    minLines: 1,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _icon,
                    decoration: const InputDecoration(labelText: 'Icon URL'),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (v) => validateHttpUrl(v, required: false),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _marketing,
                    decoration: const InputDecoration(labelText: 'Marketing URL'),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (v) => validateHttpUrl(v, required: false),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: BusyButton(onPressed: _submit, busy: _busy, label: 'Create app', icon: Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}
