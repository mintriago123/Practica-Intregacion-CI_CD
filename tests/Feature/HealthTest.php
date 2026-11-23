<?php

namespace Tests\Feature;

use Tests\TestCase;

class HealthTest extends TestCase
{
    public function test_health_endpoint_responde_ok(): void
    {
        $response = $this->getJson('/api/health');

        $response->assertOk();
        $response->assertJson(['status' => 'ok']);
    }
}
