<?php

use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'service' => 'laboratorio-ci-laravel',
        'timestamp' => now()->toIso8601String(),
    ]);
});
