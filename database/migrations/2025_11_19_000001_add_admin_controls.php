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
        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('user')->after('profile_image');
            $table->boolean('is_banned')->default(false)->after('role');
            $table->timestamp('ban_started_at')->nullable()->after('is_banned');
            $table->timestamp('banned_until')->nullable()->after('ban_started_at');
            $table->text('ban_reason')->nullable()->after('banned_until');
            $table->foreignId('last_banned_by')->nullable()->after('ban_reason')->constrained('users')->nullOnDelete();
        });

        Schema::create('user_bans', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('admin_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('banned_from');
            $table->timestamp('banned_until');
            $table->text('reason');
            $table->timestamp('lifted_at')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('admin_actions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_id')->constrained('users')->cascadeOnDelete();
            $table->string('action_type');
            $table->string('target_type');
            $table->unsignedBigInteger('target_id')->nullable();
            $table->text('reason')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::table('jobs', function (Blueprint $table) {
            $table->foreignId('cancelled_by_admin_id')->nullable()->after('assigned_worker_id')->constrained('users')->nullOnDelete();
            $table->text('admin_cancel_reason')->nullable()->after('cancelled_by_admin_id');
            $table->timestamp('admin_cancelled_at')->nullable()->after('admin_cancel_reason');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropForeign(['cancelled_by_admin_id']);
            $table->dropColumn(['cancelled_by_admin_id', 'admin_cancel_reason', 'admin_cancelled_at']);
        });

        Schema::dropIfExists('admin_actions');
        Schema::dropIfExists('user_bans');

        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['last_banned_by']);
            $table->dropColumn([
                'role',
                'is_banned',
                'ban_started_at',
                'banned_until',
                'ban_reason',
                'last_banned_by',
            ]);
        });
    }
};





