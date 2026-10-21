<?php

namespace Tests\Unit;

use Kreait\Firebase\Contract\Messaging;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * AWS plan step 1.5: on AWS the service account is injected from SSM as a
 * JSON string in FIREBASE_CREDENTIALS, not as a file path. kreait resolves
 * a value starting with `{` as JSON; this pins that the messaging client
 * builds from it (sending is not exercised, that needs Google).
 */
class FirebaseCredentialsFromEnvTest extends TestCase
{
    #[Test]
    public function messaging_client_builds_from_a_json_string_credential(): void
    {
        // Shape only: the key is never used until a push is actually sent.
        $pem = "-----BEGIN PRIVATE KEY-----\nMIIBVQIBADANBgkqhkiG9w0BAQEFAASCAT8wggE7AgEAAkEA0\n-----END PRIVATE KEY-----\n";

        config(['firebase.projects.app.credentials' => json_encode([
            'type' => 'service_account',
            'project_id' => 'reacti-test',
            'private_key_id' => 'test-key',
            'private_key' => $pem,
            'client_email' => 'push@reacti-test.iam.gserviceaccount.com',
            'client_id' => '1',
            'token_uri' => 'https://oauth2.googleapis.com/token',
        ])]);

        $this->assertInstanceOf(Messaging::class, app('firebase.manager')->project('app')->messaging());
    }
}
