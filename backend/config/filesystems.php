<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default filesystem disk that should be used
    | by the framework. The "local" disk, as well as a variety of cloud
    | based disks are available to your application for file storage.
    |
    */

    'default' => env('FILESYSTEM_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Below you may configure as many filesystem disks as necessary, and you
    | may even configure multiple disks for the same driver. Examples for
    | most supported storage drivers are configured here for reference.
    |
    | Supported drivers: "local", "ftp", "sftp", "s3"
    |
    */

    'disks' => [

        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => true,
            'throw' => false,
        ],

        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => env('APP_URL').'/storage',
            'visibility' => 'public',
            'throw' => false,
        ],

        // Every user upload (chat media, reactions, avatars, settings images)
        // goes through this disk under the same relative `uploads/...` paths
        // the database stores. MEDIA_DISK=local (Hostinger) is the web root,
        // so URLs and files are exactly where they always were. MEDIA_DISK=s3
        // (AWS) is a private bucket fronted by CloudFront at AWS_URL.
        'media' => env('MEDIA_DISK', 'local') === 's3' ? [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),       // empty on ECS: the task role signs
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'url' => env('AWS_URL'),                 // https://media.reacti.io
            'endpoint' => env('AWS_ENDPOINT'),       // only for the S3 emulator in CI
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'throw' => true,
            // The bucket has ACLs disabled; Flysystem always sends one and this
            // is the only value such a bucket accepts. No 'visibility' key, or
            // Flysystem would send public-read and the upload would be refused.
            'options' => ['ACL' => 'bucket-owner-full-control'],
        ] : [
            'driver' => 'local',
            'root' => public_path(),
            'url' => env('APP_URL', 'http://localhost'),
            'visibility' => 'public', // files 0644, folders 0755
            'throw' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Here you may configure the symbolic links that will be created when the
    | `storage:link` Artisan command is executed. The array keys should be
    | the locations of the links and the values should be their targets.
    |
    */

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],

];
