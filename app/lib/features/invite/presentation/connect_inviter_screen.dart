import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:reacti_app/analytics/analytics_locator.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/demo/presentation/demo_reacti_screen.dart';
import 'package:reacti_app/features/invite/data/invite_service.dart';
import 'package:reacti_app/features/invite/model/inviter.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/theme/app_theme.dart';

/// The one-tap "Connect with {Inviter}" screen (Feature 5, Part B).
///
/// Shown when a new user arrives with an invite [code]: it resolves the code to
/// the inviter's public profile and offers a single Connect action (never
/// forced — "Not now" is always there). Connecting creates the mutual
/// friendship server-side and pops with `true`.
class ConnectInviterScreen extends StatefulWidget {
  /// Creates the connect screen for [code].
  const ConnectInviterScreen({super.key, required this.code});

  /// The invite code carried from the shared link / manual entry.
  final String code;

  @override
  State<ConnectInviterScreen> createState() => _ConnectInviterScreenState();
}

class _ConnectInviterScreenState extends State<ConnectInviterScreen> {
  Inviter? _inviter;
  bool _loading = true;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final inviter = await InviteService.instance.resolveInviter(widget.code);
    if (!mounted) return;
    setState(() {
      _inviter = inviter;
      _loading = false;
    });
    if (inviter != null) {
      analytics.track(Events.inviteOpened, const {});
    }
  }

  Future<void> _connect() async {
    final inviter = _inviter;
    if (inviter == null || _connecting) return;
    setState(() => _connecting = true);

    final id = await InviteService.instance.connect(widget.code);

    if (!mounted) return;
    if (id != null) {
      analytics.track(Events.inviteConnected, const {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected with ${inviter.firstName}')),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() => _connecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't connect. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.reacti.canvas,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _inviter == null
                  ? _buildNotFound(context)
                  : _buildConnect(context, _inviter!),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Invite not found',
            style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
              color: context.reacti.textPrimary,
            ),
          ),
          UIHelper.verticalSpace(12.h),
          Text(
            "This invite link isn't valid or has expired.",
            textAlign: TextAlign.center,
            style: TextFontStyle.headline16w400CCCCCCCPoppins.copyWith(
              color: context.reacti.textSecondary,
            ),
          ),
          UIHelper.verticalSpace(24.h),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnect(BuildContext context, Inviter inviter) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 44.r,
            backgroundColor: context.reacti.surfaceVariant,
            backgroundImage:
                (inviter.avatar != null && inviter.avatar!.isNotEmpty)
                    ? NetworkImage(inviter.avatar!)
                    : null,
            child:
                (inviter.avatar == null || inviter.avatar!.isEmpty)
                    ? Text(
                      inviter.firstName.isNotEmpty
                          ? inviter.firstName[0].toUpperCase()
                          : '?',
                      style: TextFontStyle.headline20w600CFFFFFFPoppins,
                    )
                    : null,
          ),
        ),
        UIHelper.verticalSpace(20.h),
        Text(
          '${inviter.firstName} invited you',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline20w600CFFFFFFPoppins.copyWith(
            color: context.reacti.textPrimary,
          ),
        ),
        UIHelper.verticalSpace(12.h),
        // Says out loud why they are looking at the app instead of the web
        // demo they tapped. Without it the jump from a browser link into a
        // running app reads as a glitch.
        Text(
          "You already have Reacti, so there's nothing to install. Connect "
          'with ${inviter.firstName} and start sending real moments and '
          'reactions.',
          textAlign: TextAlign.center,
          style: TextFontStyle.headline16w400CCCCCCCPoppins.copyWith(
            color: context.reacti.textSecondary,
          ),
        ),
        UIHelper.verticalSpace(32.h),
        FilledButton(
          onPressed: _connecting ? null : _connect,
          child:
              _connecting
                  ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text('Connect with ${inviter.firstName}'),
        ),
        UIHelper.verticalSpace(8.h),
        // The demo the link would have shown in a browser, offered in the app
        // instead. Someone who taps an invite is often being told what Reacti
        // *is* for the first time, and arriving at a bare Connect button
        // answers a question they have not been asked yet.
        TextButton(
          onPressed: _connecting ? null : () => _openDemo(context),
          child: const Text('See how a Reacti works'),
        ),
        UIHelper.verticalSpace(4.h),
        TextButton(
          onPressed:
              _connecting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
      ],
    );
  }

  /// Opens the in-app demo, leaving this screen underneath.
  ///
  /// Pushed rather than replacing: closing the demo comes back here with the
  /// Connect button still waiting, which is the whole point of the invite.
  void _openDemo(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DemoReactiScreen()));
  }
}
