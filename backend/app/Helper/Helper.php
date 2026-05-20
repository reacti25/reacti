<?php

namespace App\Helper;

use Exception;
use App\Models\User;
use Illuminate\Support\Str;
use Kreait\Firebase\Factory;
use Illuminate\Support\Facades\Log;
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
     * @param  \Illuminate\Http\UploadedFile  $file  The uploaded image.
     * @param  string  $folder  Sub-folder under uploads/ to store the file in.
     * @return string|null  Relative path of the stored image, or null if the upload is invalid.
     */
    public static function uploadImage($file, $folder)
    {

        if (!$file->isValid()) {
            return null;
        }

        $imageName = time() . '-' . Str::random(5) . '.' . $file->getClientOriginalExtension(); // Unique name
        $path = public_path('uploads/' . $folder);

        if (!file_exists($path)) {
            mkdir($path, 0755, true);
        }

        $file->move($path, $imageName);
        return 'uploads/' . $folder . '/' . $imageName;
    }

    /**
     * Store an uploaded file under public/uploads/{folder} using a slugged name.
     *
     * Preserves the original extension, falling back to a MIME-based guess
     * for HEIC/HEIF/QuickTime files that report no extension. The base
     * name is slugged for filesystem safety while the extension is left
     * intact.
     *
     * @param  \Illuminate\Http\UploadedFile  $file  The uploaded file.
     * @param  string  $folder  Sub-folder under uploads/ to store the file in.
     * @param  string  $name  Desired base name (its extension is ignored; the file's own extension wins).
     * @return string|null  Relative path of the stored file, or null if the upload is invalid.
     */
    public static function fileUpload($file, string $folder, string $name): ?string
    {
        if (!$file->isValid()) {
            return null;
        }

        // FIX: always use original extension
        $ext = strtolower($file->getClientOriginalExtension());

        // FIX: fallback for HEIC / HEIF / QuickTime
        if (!$ext) {
            $mime = $file->getMimeType();
            $map = [
                'image/heic' => 'heic',
                'image/heif' => 'heif',
                'video/quicktime' => 'mov',
            ];
            $ext = $map[$mime] ?? 'bin';
        }

        // FIX: DO NOT slug extension
        $filename = Str::slug(pathinfo($name, PATHINFO_FILENAME)) . '.' . $ext;

        $path = public_path("uploads/$folder");
        if (!file_exists($path)) {
            mkdir($path, 0777, true);
        }

        $file->move($path, $filename);

        return "uploads/$folder/$filename";
    }


    /**
     * Delete a single image from the public path by its relative URL.
     *
     * @param  string|null  $imageUrl  Relative path of the image to delete.
     * @return bool  True if the file was deleted, false if it was missing or the path was empty.
     */
    public static function deleteImage($imageUrl)
    {
        if (!$imageUrl) {
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
     * Delete a file given its absolute filesystem path.
     *
     * No-op when the file does not exist, so callers need not pre-check.
     *
     * @param  string  $path  Absolute path of the file to delete.
     * @return void
     */
    public static function fileDelete(string $path): void
    {
        if (file_exists($path)) {
            unlink($path);
        }
    }

    /**
     * Delete multiple images given their absolute URLs.
     *
     * Each URL has the app base URL stripped to derive a relative path
     * before deletion.
     *
     * @param  array<int, string>  $imageUrls  Absolute image URLs to delete.
     * @return bool  True when all existing files were removed; false on a failed unlink or non-array input.
     */
    public static function deleteImages($imageUrls)
    {
        if (is_array($imageUrls)) {
            foreach ($imageUrls as $imageUrl) {
                $baseUrl = url('/');
                $relativePath = str_replace($baseUrl . '/', '', $imageUrl);
                $fullPath = public_path($relativePath);


                if (file_exists($fullPath) && is_file($fullPath)) {

                    if (!unlink($fullPath)) {
                        return false;
                    }
                }
            }
            return true;
        }

        return false;
    }

    /**
     * Delete one or more video files from the public path.
     *
     * Accepts either a single relative path or an array of them; a scalar
     * is normalised to an array. unlink warnings are suppressed so a
     * missing file never interrupts the caller.
     *
     * @param  string|array<int, string>  $videoPaths  Relative path(s) of the video(s) to delete.
     * @return void
     */
    public static function deleteVideos($videoPaths)
    {
        if (!is_array($videoPaths)) {
            $videoPaths = [$videoPaths];
        }

        foreach ($videoPaths as $path) {
            $fullPath = public_path($path);
            if (file_exists($fullPath) && is_file($fullPath)) {
                @unlink($fullPath); // suppress warning
            }
        }
    }



    /**
     * Calculate a person's age in whole years from their date of birth.
     *
     * @param  string|\DateTimeInterface|null  $dateOfBirth  The date of birth (any Carbon-parsable value).
     * @return int|null  Age in completed years, or null when no date is supplied.
     */
    public static function calculateAge($dateOfBirth)
    {
        if (!$dateOfBirth) {
            return null;
        }

        $dob = \Carbon\Carbon::parse($dateOfBirth);
        $now = \Carbon\Carbon::now();

        return (int) $dob->diffInYears($now);
    }

    /**
     * Delete a file from the public path by its relative path.
     *
     * No-op when the path is empty or the file does not exist.
     *
     * @param  string|null  $filePath  Relative path of the file to delete.
     * @return void
     */
    public static function deleteFile($filePath)
    {
        if ($filePath && file_exists(public_path($filePath))) {
            unlink(public_path($filePath));
        }
    }

    /**
     * Generate a unique "@handle" style username from a person's name.
     *
     * Slugs the first and last name into a base handle and appends an
     * incrementing counter until an unused username is found.
     *
     * @param  string  $firstName  The user's first name.
     * @param  string  $lastName  The user's last name.
     * @return string  A username unique within the `users` table, prefixed with "@".
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
     * @param  array{title: string, body: string, icon: string}  $notifyData  Notification payload.
     * @return void
     */
    public static function sendNotifyMobile($token, $notifyData): void
    {
        try {
            $messaging = Firebase::messaging();

            $notification = Notification::create(
                $notifyData['title'],
                Str::limit($notifyData['body'], 100),
                $notifyData['icon']
            );

            $message = CloudMessage::withTarget('token', $token)
                ->withNotification($notification);

            $messaging->send($message);
        } catch (\Throwable $e) {
            Log::error($e->getMessage());
        }
    }
}
