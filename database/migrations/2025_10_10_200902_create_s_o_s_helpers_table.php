<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('s_o_s_helpers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sos_id')->constrained('s_o_s_requests')->onDelete('cascade');
            $table->foreignId('helper_id')->constrained('users')->onDelete('cascade');
            $table->timestamp('responded_at');
            $table->decimal('distance', 8, 2);
            $table->enum('status', ['responding', 'onTheWay', 'arrived', 'completed'])->default('responding');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('s_o_s_helpers');
    }
};
