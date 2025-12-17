# Database Seeders

Seeder lengkap untuk database Servify dengan data yang realistis.

## Struktur Seeder

### 1. UserSeeder
- **2 Admin**: Super Admin dan Operations Admin
- **15 User**: User reguler dengan data lengkap
  - Rating (4.2 - 4.9)
  - Completed jobs (5 - 50)
  - Total earnings (berdasarkan pekerjaan yang diselesaikan)
  - Completed SOS dan helped SOS
  - Total points
  - NIK, gender, date_of_birth, address
  - 1 user banned untuk testing

### 2. AddressSeeder
- Setiap user memiliki 1-3 alamat
- Alamat default ditandai dengan `is_default = true`
- Koordinat latitude/longitude yang realistis

### 3. JobSeeder
- **30 Public Jobs**: Pekerjaan publik dengan berbagai status
  - Status: pending (30%), inProgress (20%), completed (40%), cancelled (10%)
  - 9 kategori: cleaning, maintenance, delivery, tutoring, photography, cooking, gardening, petCare, other
  - Harga bervariasi sesuai kategori
- **10 Private Orders**: Pekerjaan pribadi yang langsung di-assign
  - Status: pending (20%), inProgress (30%), completed (50%)
  - Harga 20% lebih tinggi dari pekerjaan publik

### 4. PrivateOrderSeeder
- Seeder tambahan untuk private orders (dari seeder lama)

### 5. JobApplicationSeeder
- Aplikasi untuk pekerjaan publik (bukan private orders)
- 1-5 aplikasi per pekerjaan
- Status: pending, accepted, rejected
- Hanya 1 aplikasi yang diterima per pekerjaan
- Jika diterima, pekerjaan langsung di-assign ke worker

### 6. JobReviewSeeder
- Review untuk pekerjaan yang sudah completed
- Customer review worker (80% chance)
- Worker review customer (70% chance)
- Rating berbobot: 5 stars (40%), 4 stars (35%), 3 stars (15%), 2 stars (7%), 1 star (3%)
- Komentar yang sesuai dengan rating
- Rating user otomatis di-update setelah review dibuat

### 7. SOSSeeder
- Seeder untuk SOS requests (dari seeder lama)

## Cara Menjalankan

```bash
# Fresh migration dan seed
php artisan migrate:fresh --seed

# Atau seed saja (jika tabel sudah ada)
php artisan db:seed

# Seed seeder tertentu
php artisan db:seed --class=UserSeeder
php artisan db:seed --class=JobSeeder
php artisan db:seed --class=JobApplicationSeeder
php artisan db:seed --class=JobReviewSeeder
```

## Data yang Dihasilkan

- **17 Users**: 2 admin + 15 user
- **40 Jobs**: 30 public + 10 private
- **~50-100 Applications**: Aplikasi untuk pekerjaan publik
- **~30-50 Reviews**: Review untuk pekerjaan completed
- **~20-45 Addresses**: Alamat untuk user

## Catatan

- Rating user dihitung otomatis dari review yang diterima
- Total earnings dihitung dari pekerjaan completed yang di-assign ke user
- Private orders langsung di-assign, tidak melalui aplikasi
- Completed jobs memiliki assigned_worker_id


