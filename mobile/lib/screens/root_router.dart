import 'package:flutter/material.dart';

import '../state/app_session.dart';
import 'driver/driver_shell.dart';
import 'nav_shell.dart';

/// Chooses the right home shell for the signed-in user's role.
Widget rootForRole() =>
    AppSession.isDriver ? const DriverShell() : const NavShell();
