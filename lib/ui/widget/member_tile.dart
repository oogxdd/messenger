// Copyright © 2022-2024 IT ENGINEERING MANAGEMENT INC,
//                       <https://github.com/team113>
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU Affero General Public License v3.0 as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License v3.0 for
// more details.
//
// You should have received a copy of the GNU Affero General Public License v3.0
// along with this program. If not, see
// <https://www.gnu.org/licenses/agpl-3.0.html>.

import 'package:flutter/material.dart';

import '/domain/repository/user.dart';
import '/l10n/l10n.dart';
import '/themes.dart';
import '/ui/page/home/widget/contact_tile.dart';
import '/util/message_popup.dart';
import 'animated_button.dart';
import 'animated_switcher.dart';
import 'svg/svg.dart';

/// Styled [ContactTile] representing the provided [RxUser] as a member of some
/// [Chat] or [OngoingCall].
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.user,
    this.inCall,
    this.onTap,
    this.me = false,
    this.onKick,
    this.onCall,
  });

  /// [RxUser] this [MemberTile] is about.
  final RxUser user;

  /// Indicator whether a call button should be active or not.
  ///
  /// No call button is displayed, if `null` is specified.
  final bool? inCall;

  /// Callback, called when the [ContactTile] is tapped.
  final void Function()? onTap;

  /// Callback, called when the call button is pressed.
  final void Function()? onCall;

  /// Indicator whether this [user] is treated as [MyUser], meaning displaying
  /// appropriate labels.
  final bool me;

  /// Callback, called when the kick button is pressed.
  final Future<void> Function()? onKick;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).style;

    return ContactTile(
      user: user,
      dense: true,
      onTap: me ? null : onTap,
      trailing: [
        if (inCall != null) ...[
          SafeAnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Material(
              key: Key(inCall == true ? 'InCall' : 'NotInCall'),
              color: inCall == true
                  ? onCall == null
                      ? style.colors.primaryHighlightLightest
                      : style.colors.danger
                  : style.colors.primary,
              type: MaterialType.circle,
              child: InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(60),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(
                    child: inCall == true
                        ? const SvgIcon(SvgIcons.callEndSmall)
                        : const SvgIcon(SvgIcons.callStartSmall),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        AnimatedButton(
          enabled: !me,
          onPressed: me
              ? null
              : () async {
                  final bool? result = await MessagePopup.alert(
                    'label_remove_member'.l10n,
                    description: [
                      TextSpan(text: 'alert_user_will_be_removed1'.l10n),
                      TextSpan(
                        text: user.user.value.name?.val ??
                            user.user.value.num.toString(),
                        style: style.fonts.normal.regular.onBackground,
                      ),
                      TextSpan(text: 'alert_user_will_be_removed2'.l10n),
                    ],
                  );

                  if (result == true) {
                    await onKick?.call();
                  }
                },
          child: me
              ? Text(
                  'label_you'.l10n,
                  style: style.fonts.normal.regular.secondary,
                )
              : const SvgIcon(SvgIcons.delete, key: Key('DeleteMemberButton')),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}
