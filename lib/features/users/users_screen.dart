import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router.dart';
import '../../shared/widgets/paged_list_view.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/common.dart';
import 'users.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
    setState(() {}); // Show/hide the clear button.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _search,
              hintText: 'Search by ID, phone, email or name',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              trailing: [
                if (_search.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      _onChanged('');
                    },
                  ),
              ],
              onChanged: _onChanged,
              onSubmitted: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
      ),
      body: PagedListView<UserSummary>(
        provider: userSearchProvider(_query),
        onRefresh: () => ref.read(userSearchProvider(_query).notifier).refresh(),
        onLoadMore: () => ref.read(userSearchProvider(_query).notifier).loadMore(),
        empty: EmptyView(
          title: _query.isEmpty ? 'No users yet' : 'No users match "$_query"',
          message: _query.isEmpty ? null : 'Phone and email match from the start; names match anywhere.',
          icon: Icons.person_search_outlined,
        ),
        itemBuilder: (context, u) => UserTile(user: u),
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user});
  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final contact = [u.phone, u.primaryEmail].whereType<String>().join(' · ');
    return ListTile(
      leading: CircleAvatar(child: Icon(u.status == 'active' ? Icons.person_outline : Icons.person_off_outlined)),
      title: Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (contact.isNotEmpty && u.name != null) contact,
          'Joined ${formatDate(u.createdAt)}',
          '${u.appCount} apps',
        ].join('\n'),
      ),
      isThreeLine: contact.isNotEmpty && u.name != null,
      trailing: u.status == 'active' ? null : StatusChip.status(u.status),
      onTap: () => context.go(Routes.user(u.id)),
    );
  }
}
