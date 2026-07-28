import 'package:flutter/material.dart';

import '../../data/driver_repository.dart';
import '../../models/driver_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'driver_account_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_home_screen.dart';
import 'driver_onboarding_screen.dart';
import 'driver_requests_screen.dart';

/// Root shell for drivers: Today · Requests · Earnings · Account.
/// If the signed-in driver has no vehicle record yet, onboarding is shown first.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  final _repo = DriverRepository();
  int _index = 0;
  Future<DriverProfile?>? _driverFuture;

  @override
  void initState() {
    super.initState();
    _driverFuture = _repo.myDriver();
  }

  void _refreshDriver() {
    setState(() => _driverFuture = _repo.myDriver());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverProfile?>(
      future: _driverFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        // No driver record yet (e.g. an existing account being promoted).
        if (snap.data == null) {
          return DriverOnboardingScreen(onDone: _refreshDriver);
        }

        final screens = [
          const DriverHomeScreen(),
          const DriverRequestsScreen(),
          const DriverEarningsScreen(),
          const DriverAccountScreen(),
        ];

        return Scaffold(
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: _DriverNavBar(
            index: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}

class _DriverNavBar extends StatelessWidget {
  const _DriverNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.dashboard_rounded, 'Today'),
    (Icons.inbox_rounded, 'Requests'),
    (Icons.account_balance_wallet_rounded, 'Earnings'),
    (Icons.person_rounded, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
        left: 8,
        right: 8,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            _DriverNavItem(
              icon: _items[i].$1,
              label: _items[i].$2,
              selected: index == i,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _DriverNavItem extends StatelessWidget {
  const _DriverNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: selected ? 24 : 0,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppType.caption.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
