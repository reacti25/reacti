<?php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies as Middleware;

/**
 * Trust the proxies named in TRUSTED_PROXIES (`*`, or a comma-separated list
 * of IPs/CIDRs) at request time.
 *
 * TLS ends at a proxy in front of PHP: CloudPanel's nginx today, the AWS
 * load balancer tomorrow. Without this, Laravel sees plain HTTP from the
 * proxy's address, so every generated URL would say http:// and ip() would be the
 * proxy, putting every user in one login-throttle bucket (AWS plan, step
 * 1.8). Read from config here rather than in bootstrap/app.php because that
 * closure runs before the environment is loaded.
 */
class TrustProxies extends Middleware
{
    protected function proxies(): array|string|null
    {
        $proxies = config('app.trusted_proxies');

        return $proxies === '*' ? '*' : array_values(array_filter(array_map('trim', explode(',', (string) $proxies))));
    }
}
