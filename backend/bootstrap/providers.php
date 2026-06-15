<?php

use App\Providers\AnalyticsServiceProvider;
use App\Providers\AppServiceProvider;
use Yajra\DataTables\DataTablesServiceProvider;

return [
    AppServiceProvider::class,
    AnalyticsServiceProvider::class,
    DataTablesServiceProvider::class,
];
