<?php

namespace App\Helpers;

use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Kreait\Firebase\Messaging\AndroidConfig;
use Kreait\Firebase\Messaging\ApnsConfig;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Laravel\Firebase\Facades\Firebase;

/**
 * Static utility methods shared across the backend.
 *
 * Bundles common cross-cutting helpers: image/file uploads into the
 * public `uploads/` tree, file/image deletion, age calculation, unique
 * username generation, and Firebase push notification dispatch.
 */
class Helper
{
    /**
     * Store an uploaded image under public/uploads/{folder} with a unique name.
     *
     * Creates the target folder if it does not exist. The generated name
     * combines a timestamp and random suffix to avoid collisions.
     *
     * @param  UploadedFile  $file  The uploaded image.
     * @param  string  $folder  Sub-folder under uploads/ to store the file in.
     * @return string|null Relative path of the stored image, or null if the upload is invalid.
     */
    public static function uploadImage($file, $folder)
    {

        if (! $file->isValid()) {
            return null;
        }

        $imageName = time().'-'.Str::random(5).'.'.$file->getClientOriginalExtension(); // Unique name
        $path = public_path('uploads/'.$folder);

        if (! file_exists($path)) {
            mkdir($path, 0755, true);
        }

        $file->move($path, $imageName);

        return 'uploads/'.$folder.'/'.$imageName;
    }

    /**
     * Store an uploaded file under public/uploads/{folder} using a slugged name.
     *
     * Preserves the original extension, falling back to a MIME-based guess
     * for HEIC/HEIF/QuickTime files that report no extension. The base
     * name is slugged for filesystem safety while the extension is left
     * intact.
     *
     * @param  UploadedFile  $file  The uploaded file.
     * @param  string  $folder  Sub-folder under uploads/ to store the file in.
     * @param  string  $name  Desired base name (its extension is ignored; the file's own extension wins).
     * @return string|null Relative path of the stored file, or null if the upload is invalid.
     */
    public static function fileUpload($file, string $folder, string $name): ?string
    {
        if (! $file->isValid()) {
            return null;
        }

        // FIX: always use original extension
        $ext = strtolower($file->getClientOriginalExtension());

        // FIX: fallback for HEIC / HEIF / QuickTime
        if (! $ext) {
            $mime = $file->getMimeType();
            $map = [
                'image/heic' => 'heic',
                'image/heif' => 'heif',
                'video/quicktime' => 'mov',
            ];
            $ext = $map[$mime] ?? 'bin';
        }

        // FIX: DO NOT slug extension
        $filename = Str::slug(pathinfo($name, PATHINFO_FILENAME)).'.'.$ext;

        $path = public_path("uploads/$folder");
        if (! file_exists($path)) {
            // 0755, not 0777: the upload dir must not be world-writable.
            // Matches uploadImage() above.
            mkdir($path, 0755, true);
        }

        $file->move($path, $filename);

        return "uploads/$folder/$filename";
    }

    /**
     * Delete a single image from the public path by its relative URL.
     *
     * @param  string|null  $imageUrl  Relative path of the image to delete.
     * @return bool True if the file was deleted, false if it was missing or the path was empty.
     */
    public static function deleteImage($imageUrl)
    {
        if (! $imageUrl) {
            // Pre-fix this branch contained `dd("jalis")` — a stray
            // debug call that halted the whole request whenever
            // deleteImage(null) was reached (e.g. deleting an entity
            // with no avatar). Now a clean no-op false.
            return false;
        }
        $filePath = public_path($imageUrl);
        if (file_exists($filePath)) {
            return unlink($filePath);
        }

        return false;
    }

    /**
     * Delete stored media files (message photos, videos, reactions, thumbnails,
     * group avatars) whose records are being deleted.
     *
     * Without this, deleting a message, a conversation, a group or a whole
     * account removed only the database rows: the files stayed on the server,
     * still reachable by URL, which breaks the privacy policy's deletion
     * promise and Google Play's account-deletion requirement.
     *
     * Accepts the values as stored in `file` / `thumbnail` / `avatar` columns:
     * normally `uploads/...`, but older rows may hold a full URL, so anything
     * before `uploads/` is dropped. Paths outside `uploads/` or containing `..`
     * are refused, so a bad value can never delete anything else.
     *
     * @param  iterable<int, string|null>  $paths  Stored paths; null/empty entries are skipped.
     * @return int How many files were actually removed.
     *
     * @example Helper::deleteFiles([$chat->file, $chat->thumbnail]);
     */
    public static function deleteFiles(iterable $paths): int
    {
        $removed = 0;
        foreach ($paths as $path) {
            $relative = self::uploadsPath($path);
            if ($relative !== null && self::deleteImage($relative)) {
                $removed++;
            }
        }

        return $removed;
    }

    /**
     * The `uploads/...` part of a stored media path or URL, or null when the
     * value is empty, lies outside uploads/, or tries to climb out with `..`.
     *
     * @param  string|null  $path  A stored `file`/`thumbnail`/`avatar` value.
     * @return string|null The safe relative path, e.g. `uploads/chat/a.jpg`.
     */
    public static function uploadsPath(?string $path): ?string
    {
        if (! $path) {
            return null;
        }
        $start = strpos($path, 'uploads/');
        if ($start === false) {
            return null;
        }
        // Drop any query string or fragment a full URL might carry.
        $relative = strtok(substr($path, $start), '?#');

        return str_contains($relative, '..') ? null : $relative;
    }

    /**
     * Generate a unique "@handle" style username from a person's name.
     *
     * Slugs the first and last name into a base handle and appends an
     * incrementing counter until an unused username is found.
     *
     * @param  string  $firstName  The user's first name.
     * @param  string  $lastName  The user's last name.
     * @return string A username unique within the `users` table, prefixed with "@".
     */
    public static function generateUniqueUsername($firstName, $lastName)
    {
        $base = Str::slug("{$firstName} {$lastName}", '_');
        $username = "@{$base}";

        $counter = 1;
        $original = $username;

        while (User::where('username', $username)->exists()) {
            $username = "@{$base}{$counter}";
            $counter++;
        }

        return $username;
    }

    /**
     * Send a Firebase Cloud Messaging push notification to a single device.
     *
     * The body is truncated to 100 characters. Failures are caught and
     * logged so notification errors never break the calling request
     * (best-effort delivery).
     *
     * @param  string  $token  The recipient device's FCM registration token.
     * @param  array{title: string, body: string, icon: string, data?: array<string, string>}  $notifyData  Notification payload. An optional `data` map carries deep-link routing keys (all string values, per FCM) so the app can open the right chat on tap.
     * @param  int|null  $badge  When set, the iOS app-icon badge number (unseen conversation count) so a terminated app still shows the badge.
     */
    public static function sendNotifyMobile($token, $notifyData, ?int $badge = null): void
    {
        try {
            Firebase::messaging()->send(self::buildPushMessage($token, $notifyData, $badge));
        } catch (\Throwable $e) {
            Log::error($e->getMessage());
        }
    }

    /**
     * Builds the FCM push message for a device, including the alert sound.
     *
     * Extracted from {@see sendNotifyMobile} so the payload shape is testable
     * without touching FCM. The sound matters: iOS delivers a push **silently**
     * unless the payload carries an explicit `aps.sound`, so a message arriving
     * while the app is backgrounded/closed made no sound at all on iPhone. The
     * in-app "message received" tone is separate (played from Dart while you are
     * inside the chat) — this is the distinct system tone for a new arrival.
     *
     * @param  string  $token  The recipient device's FCM registration token.
     * @param  array{title: string, body: string, icon: string, data?: array<string, string>}  $notifyData
     * @param  int|null  $badge  iOS app-icon badge (unseen count); null to omit.
     */
    public static function buildPushMessage($token, $notifyData, ?int $badge = null): CloudMessage
    {
        $notification = Notification::create(
            $notifyData['title'],
            Str::limit($notifyData['body'], 100),
            $notifyData['icon']
        );

        $message = CloudMessage::withTarget('token', $token)
            ->withNotification($notification);

        // Attach deep-link routing keys as the FCM data payload so a tap can
        // open the exact conversation. Additive: absent for callers that
        // don't supply it, and an old app simply ignores unknown data.
        if (! empty($notifyData['data'])) {
            $message = $message->withData($notifyData['data']);
        }

        // Set the iOS app-icon badge (APNs aps.badge) so the count updates
        // even while the app is terminated. Only when supplied.
        if ($badge !== null) {
            $message = $message->withApnsConfig(
                ApnsConfig::fromArray(['payload' => ['aps' => ['badge' => $badge]]])
            );
        }

        // Android: show on the app's high-importance channel (a heads-up
        // banner; the channel id must match kAndroidPushChannelId in the app),
        // and deliver at high priority so a dozing phone wakes for it. iOS
        // ignores this block. Additive: older Android builds just use it too.
        $message = $message->withAndroidConfig(AndroidConfig::fromArray([
            'priority' => 'high',
            'notification' => ['channel_id' => 'high_importance_channel'],
        ]));

        // Default alert sound for iOS *and* Android. Applied last so it merges
        // into (never replaces) the badge-carrying APNs payload and the
        // channel-carrying Android payload above.
        return $message->withDefaultSounds();
    }
}
