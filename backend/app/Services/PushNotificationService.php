<?php

namespace App\Services;

use App\Helpers\Helper;
use App\Models\User;

/**
 * Delivers push notifications to a user's registered devices.
 *
 * Owns the one piece of push logic that was previously copy-pasted
 * across the chat services — the fan-out loop that sends a payload to
 * every Firebase Cloud Messaging token a user owns. Callers still build
 * their own feature-specific `$notifyData` payload (the title/body/icon
 * legitimately differ per feature); this service owns only the delivery
 * loop, giving the app a single seam to later move push delivery onto a
 * queue.
 */
class PushNotificationService
{
    /**
     * Send a notification payload to every device the user has registered.
     *
     * A no-op when the user has no Firebase tokens. Individual delivery
     * failures are swallowed and logged inside {@see Helper::sendNotifyMobile()},
     * so this method never throws.
     *
     * @param  User  $user  Recipient whose device tokens to push to.
     * @param  array  $notifyData  Payload: `title`, `body`, `icon`, plus any
     *                             feature-specific extras (e.g. `sender_id`).
     */
    public function sendToUser(User $user, array $notifyData): void
    {
        foreach ($user->firebaseTokens as $firebaseToken) {
            Helper::sendNotifyMobile($firebaseToken->token, $notifyData);
        }
    }
}
