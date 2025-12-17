import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/profile_avatar.dart';

class SubmitReviewScreen extends StatefulWidget {
  final String jobId;
  final String ratedUserId;
  final String ratedUserName;
  final String? ratedUserProfileImage;
  final String jobTitle;
  final int? initialRating;
  final String? initialComment;
  final bool isEditing;

  const SubmitReviewScreen({
    super.key,
    required this.jobId,
    required this.ratedUserId,
    required this.ratedUserName,
    this.ratedUserProfileImage,
    required this.jobTitle,
    this.initialRating,
    this.initialComment,
    this.isEditing = false,
  });

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialRating ?? 0;
    if (widget.initialComment != null) {
      _commentController.text = widget.initialComment!;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      _showSnackBar('Silakan pilih rating terlebih dahulu', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _apiService.submitRating(
        jobId: widget.jobId,
        ratedUserId: widget.ratedUserId,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (response['success'] == true) {
          _showSnackBar('Review berhasil dikirim!');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          _showSnackBar(
            response['message'] ?? 'Gagal mengirim review',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Ubah Rating & Review' : 'Beri Rating & Review',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    profileImagePath: widget.ratedUserProfileImage,
                    radius: 40,
                    name: widget.ratedUserName,
                    backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                    iconColor: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ratedUserName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.jobTitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Rating Section
            const Text(
              'Berikan Rating',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive star size and padding
                  final availableWidth = constraints.maxWidth;
                  final starSize = (availableWidth / 5) * 0.6; // 60% of available space per star
                  final maxStarSize = 48.0;
                  final minStarSize = 32.0;
                  final finalStarSize = starSize.clamp(minStarSize, maxStarSize);
                  final horizontalPadding = (availableWidth - (finalStarSize * 5)) / 10; // Distribute remaining space
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final rating = index + 1;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRating = rating;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding.clamp(2.0, 8.0)),
                          child: Icon(
                            rating <= _selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: finalStarSize,
                            color: rating <= _selectedRating
                                ? const Color(0xFFF59E0B)
                                : Colors.grey[300],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            if (_selectedRating > 0) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _getRatingText(_selectedRating),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Comment Section
            const Text(
              'Tulis Review (Opsional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Bagikan pengalaman Anda...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Kirim Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Tidak Puas';
      case 2:
        return 'Tidak Puas';
      case 3:
        return 'Cukup';
      case 4:
        return 'Puas';
      case 5:
        return 'Sangat Puas';
      default:
        return '';
    }
  }
}


