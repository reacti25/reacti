<?php

namespace Tests\Support;

use Illuminate\Contracts\Broadcasting\Broadcaster;

/**
 * A broadcast driver whose every publish throws — simulating a Pusher
 * outage/misconfiguration or transport error at fan-out time, without any
 * network. Registered as the default broadcaster in a test to prove that a
 * realtime failure never fails an already-persisted chat write.
 */
final class ThrowingBroadcaster implements Broadcaster
{
    public function auth($request)
    {
        return true;
    }

    public function validAuthenticationResponse($request, $result)
    {
        return $result;
    }

    /**
     * @param  array<int, string>  $channels
     * @param  array<string, mixed>  $payload
     */
    public function broadcast(array $channels, $event, array $payload = [])
    {
        throw new \RuntimeException('simulated broadcast/Pusher failure');
    }
}
