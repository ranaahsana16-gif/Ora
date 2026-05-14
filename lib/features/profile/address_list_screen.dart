import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/features/profile/address_provider.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/profile/addresses/new'),
          ),
        ],
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 64,
                    color: OraTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text('No addresses saved yet'),
                  const SizedBox(height: 24),
                  OraButton(
                    label: 'Add New Address',
                    onPressed: () => context.push('/profile/addresses/new'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return _AddressTile(address: address);
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AddressTile extends ConsumerWidget {
  final UserAddress address;
  const _AddressTile({required this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: OraTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.isDefault
              ? OraTheme.primaryOrange.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Text(
              address.label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: OraTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEFAULT',
                  style: TextStyle(
                    color: OraTheme.primaryOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${address.fullName} • ${address.phone}'),
            const SizedBox(height: 4),
            Text(
              '${address.house}, ${address.street}${address.block != null ? ', ${address.block}' : ''}, ${address.area}, ${address.city}',
              style: TextStyle(color: OraTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (val) {
            if (val == 'edit') {
              context.push('/profile/addresses/edit', extra: address);
            } else if (val == 'delete') {
              ref.read(addressProvider.notifier).deleteAddress(address.id);
            } else if (val == 'default') {
              ref.read(addressProvider.notifier).setDefault(address.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'default',
              child: Text('Set as Default'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: OraTheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}
