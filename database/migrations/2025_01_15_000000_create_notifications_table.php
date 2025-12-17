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
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id');
            $table->string('type'); // job_created, job_application, job_accepted, job_rejected, job_completed, job_cancelled, private_order_accepted, private_order_rejected, sos_nearby, etc.
            $table->string('title');
            $table->text('body');
            $table->boolean('is_read')->default(false);
            $table->string('related_type')->nullable(); // 'job', 'sos', 'application', etc.
            $table->unsignedBigInteger('related_id')->nullable(); // ID of related job, sos, application, etc.
            $table->json('data')->nullable(); // Additional data
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->index(['user_id', 'is_read']);
            $table->index(['user_id', 'created_at']);
            $table->index('type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};






