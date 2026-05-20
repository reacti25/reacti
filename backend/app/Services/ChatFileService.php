<?php

namespace App\Services;

use Exception;
use FFMpeg\Coordinate\TimeCode;
use FFMpeg\FFMpeg;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\Facades\Image;

/**
 * Stores and post-processes media attached to chat messages.
 *
 * Persists uploaded files to the `public` disk and enriches them with
 * type-specific metadata: image dimensions and thumbnails, video duration
 * and frame thumbnails (via FFMpeg), and audio duration. Also exposes
 * helpers for MIME-based type detection, size validation, and deletion.
 */
class ChatFileService
{
    /**
     * Create a new class instance.
     */
    public function __construct()
    {
        //
    }

    /**
     * Upload and process a chat file, dispatching to the type-specific handler.
     *
     * @param  UploadedFile  $file  The uploaded attachment.
     * @param  string  $type  Logical media type: image|video|audio|document.
     * @return array<string, mixed> Stored file metadata (path, name, mime, size, plus type-specific keys).
     */
    public function uploadFile(UploadedFile $file, string $type): array
    {
        $data = [
            'type' => $type,
            'file_name' => $file->getClientOriginalName(),
            'file_type' => $file->getMimeType(),
            'file_size' => $file->getSize(),
        ];

        switch ($type) {
            case 'image':
                return $this->processImage($file, $data);

            case 'video':
                return $this->processVideo($file, $data);

            case 'audio':
                return $this->processAudio($file, $data);

            case 'document':
                return $this->processDocument($file, $data);

            default:
                return $data;
        }
    }

    /**
     * Process an image upload: store it, capture dimensions, and build a thumbnail.
     *
     * If image processing fails the file is still kept; width/height fall
     * back to null so the caller is not blocked.
     *
     * @param  UploadedFile  $file  The uploaded image.
     * @param  array<string, mixed>  $data  Base metadata to augment.
     * @return array<string, mixed> Metadata with file_path, width, height, and thumbnail.
     */
    protected function processImage(UploadedFile $file, array $data): array
    {
        // Store original image
        $path = $file->store('chat/images', 'public');
        $data['file_path'] = $path;

        // Get image dimensions
        try {
            $image = Image::make($file);
            $data['width'] = $image->width();
            $data['height'] = $image->height();

            // Create thumbnail
            $thumbnailPath = 'chat/thumbnails/'.basename($path);
            $thumbnail = Image::make($file)->fit(300, 300);
            Storage::disk('public')->put($thumbnailPath, $thumbnail->encode());
            $data['thumbnail'] = $thumbnailPath;
        } catch (Exception $e) {
            // Fallback if image processing fails
            $data['width'] = null;
            $data['height'] = null;
        }

        return $data;
    }

    /**
     * Process a video upload: store it, then use FFMpeg to extract duration,
     * dimensions, and a thumbnail frame taken at the 1-second mark.
     *
     * FFMpeg failures are logged but not thrown — the video is still saved.
     *
     * @param  UploadedFile  $file  The uploaded video.
     * @param  array<string, mixed>  $data  Base metadata to augment.
     * @return array<string, mixed> Metadata with file_path, and (on success) duration, thumbnail, width, height.
     */
    protected function processVideo(UploadedFile $file, array $data): array
    {
        // Store video
        $path = $file->store('chat/videos', 'public');
        $data['file_path'] = $path;

        try {
            // Get video duration and create thumbnail using FFMpeg
            // Note: You need to install php-ffmpeg package
            // composer require php-ffmpeg/php-ffmpeg

            $ffmpeg = FFMpeg::create([
                'ffmpeg.binaries' => env('FFMPEG_BINARY', '/usr/bin/ffmpeg'),
                'ffprobe.binaries' => env('FFPROBE_BINARY', '/usr/bin/ffprobe'),
            ]);

            $video = $ffmpeg->open(Storage::disk('public')->path($path));

            // Get duration
            $duration = $video->getStreams()->videos()->first()->get('duration');
            $data['duration'] = (int) $duration;

            // Create thumbnail at 1 second
            $thumbnailPath = 'chat/thumbnails/'.pathinfo($path, PATHINFO_FILENAME).'.jpg';
            $video->frame(TimeCode::fromSeconds(1))
                ->save(Storage::disk('public')->path($thumbnailPath));
            $data['thumbnail'] = $thumbnailPath;

            // Get dimensions
            $dimensions = $video->getStreams()->videos()->first()->getDimensions();
            $data['width'] = $dimensions->getWidth();
            $data['height'] = $dimensions->getHeight();
        } catch (Exception $e) {
            // Fallback if video processing fails
            Log::error('Video processing failed: '.$e->getMessage());
        }

        return $data;
    }

    /**
     * Process an audio upload: store it and read its duration via FFMpeg.
     *
     * FFMpeg failures are logged but not thrown — the audio is still saved.
     *
     * @param  UploadedFile  $file  The uploaded audio file.
     * @param  array<string, mixed>  $data  Base metadata to augment.
     * @return array<string, mixed> Metadata with file_path and (on success) duration.
     */
    protected function processAudio(UploadedFile $file, array $data): array
    {
        // Store audio
        $path = $file->store('chat/audios', 'public');
        $data['file_path'] = $path;

        try {
            // Get audio duration using getID3 or FFMpeg
            $ffmpeg = FFMpeg::create();
            $audio = $ffmpeg->open(Storage::disk('public')->path($path));
            $duration = $audio->getStreams()->audios()->first()->get('duration');
            $data['duration'] = (int) $duration;
        } catch (Exception $e) {
            Log::error('Audio processing failed: '.$e->getMessage());
        }

        return $data;
    }

    /**
     * Process a document upload: store it on the public disk.
     *
     * Contains a placeholder branch for future PDF thumbnail generation;
     * no thumbnail is produced yet.
     *
     * @param  UploadedFile  $file  The uploaded document.
     * @param  array<string, mixed>  $data  Base metadata to augment.
     * @return array<string, mixed> Metadata with file_path.
     */
    protected function processDocument(UploadedFile $file, array $data): array
    {
        // Store document
        $path = $file->store('chat/documents', 'public');
        $data['file_path'] = $path;

        // Generate thumbnail for PDF files
        if ($file->getMimeType() === 'application/pdf') {
            try {
                // You can use Spatie PDF package for thumbnail generation
                // composer require spatie/pdf-to-image

                // For now, we'll skip thumbnail generation
                // You can implement it based on your requirements
            } catch (Exception $e) {
                Log::error('PDF thumbnail generation failed: '.$e->getMessage());
            }
        }

        return $data;
    }

    /**
     * Derive the logical media type from an uploaded file's MIME type.
     *
     * Anything that is not image/video/audio is treated as a document.
     *
     * @param  UploadedFile  $file  The uploaded file.
     * @return string One of: image|video|audio|document.
     */
    public function getFileType(UploadedFile $file): string
    {
        $mimeType = $file->getMimeType();

        if (str_starts_with($mimeType, 'image/')) {
            return 'image';
        } elseif (str_starts_with($mimeType, 'video/')) {
            return 'video';
        } elseif (str_starts_with($mimeType, 'audio/')) {
            return 'audio';
        } else {
            return 'document';
        }
    }

    /**
     * Check that an uploaded file is within the size limit for its type.
     *
     * Limits: image 5MB, video 50MB, audio/document 10MB; unknown types
     * default to the 5MB image cap.
     *
     * @param  UploadedFile  $file  The uploaded file.
     * @param  string  $type  Logical media type: image|video|audio|document.
     * @return bool True when the file is within the allowed size.
     */
    public function validateFileSize(UploadedFile $file, string $type): bool
    {
        $maxSizes = [
            'image' => 5 * 1024, // 5MB in KB
            'video' => 50 * 1024, // 50MB in KB
            'audio' => 10 * 1024, // 10MB in KB
            'document' => 10 * 1024, // 10MB in KB
        ];

        $maxSize = $maxSizes[$type] ?? 5 * 1024;

        return $file->getSize() <= ($maxSize * 1024); // Convert to bytes
    }

    /**
     * Delete a stored file and its optional thumbnail from the public disk.
     *
     * Null or non-existent paths are silently ignored, so the call is safe
     * to make even when no file was ever stored.
     *
     * @param  string|null  $filePath  Path of the primary file to remove.
     * @param  string|null  $thumbnailPath  Optional path of the associated thumbnail.
     */
    public function deleteFile(?string $filePath, ?string $thumbnailPath = null): void
    {
        if ($filePath && Storage::disk('public')->exists($filePath)) {
            Storage::disk('public')->delete($filePath);
        }

        if ($thumbnailPath && Storage::disk('public')->exists($thumbnailPath)) {
            Storage::disk('public')->delete($thumbnailPath);
        }
    }
}
