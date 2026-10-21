<?php

namespace Tests\Feature\Ops;

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * AWS plan steps 1.7 and 1.8: what a load balancer and a cutover check
 * need from the app.
 */
class EdgeReadinessTest extends TestCase
{
    #[Test]
    public function health_route_answers_without_the_database_and_during_maintenance(): void
    {
        DB::enableQueryLog();

        $this->get('/up')->assertOk()->assertHeader('X-Reacti-Origin', 'hostinger');
        $this->assertSame([], DB::getQueryLog(), '/up must not touch the database');

        Artisan::call('down');
        try {
            $this->get('/up')->assertOk();
            $this->get('/api/anything')->assertStatus(503); // maintenance answers before routing
        } finally {
            Artisan::call('up');
        }
    }

    #[Test]
    public function origin_header_follows_served_by(): void
    {
        config(['app.served_by' => 'aws']);

        $this->get('/up')->assertHeader('X-Reacti-Origin', 'aws');
    }

    #[Test]
    public function forwarded_headers_are_believed_from_a_trusted_proxy_only(): void
    {
        Route::get('/_probe', fn () => [request()->ip(), url()->current()]);
        $headers = ['X-Forwarded-Proto' => 'https', 'X-Forwarded-For' => '203.0.113.9', 'X-Forwarded-Host' => 'reacti.io'];

        config(['app.trusted_proxies' => '*']);
        $this->get('http://localhost/_probe', $headers)->assertExactJson(['203.0.113.9', 'https://reacti.io/_probe']);

        config(['app.trusted_proxies' => '10.0.0.0/8']); // the test client comes from 127.0.0.1
        $this->get('http://localhost/_probe', $headers)->assertExactJson(['127.0.0.1', 'http://localhost/_probe']);
    }
}
