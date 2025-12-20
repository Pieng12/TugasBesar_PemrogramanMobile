import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../widgets/profile_avatar.dart';
import 'job_applications_screen.dart';
import 'submit_review_screen.dart';
import 'worker_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Defines the context from which the detail screen is viewed.
enum JobDetailViewContext { browsing, customer, worker }

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  final JobModel? job; // Optional for backward compatibility
  final JobDetailViewContext viewContext;

  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.job,
    this.viewContext = JobDetailViewContext.browsing, // Default context
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _jobData;
  bool _isLoading = true;
  String? _error;
  bool _hasApplied = false;
  String? _applicationStatus; // 'pending', 'accepted', 'rejected'
  bool _isJobOwner = false;
  bool _hasRated = false;
  String? _currentUserId;
  bool _hasCancelledApplication = false;
  Map<String, dynamic>? _currentUserReview;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Load job data
    if (widget.job != null) {
      // Convert JobModel to Map for compatibility
      _jobData = {
        'id': widget.job!.id,
        'title': widget.job!.title,
        'description': widget.job!.description,
        'category': widget.job!.category.toString().split('.').last,
        'price': widget.job!.price,
        'address': widget.job!.location.address,
        'status': widget.job!.status.toString().split('.').last,
        'scheduled_time': widget.job!.scheduledTime?.toIso8601String(),
        'created_at': widget.job!.createdAt.toIso8601String(),
        'customer': {
          'id': '1',
          'name': 'Customer',
          'profile_image': null,
          'rating': 0.0,
        },
        'assigned_worker': null,
      };
      _isLoading = false;
      _animationController.forward();
    } else {
      _loadJobData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadJobData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      // Load job details and application status in parallel for efficiency
      final results = await Future.wait([
        _apiService.getJob(widget.jobId),
        if (_apiService.token != null)
          _apiService.getMyAppliedJobs()
        else
          Future.value({'success': false}),
      ]);

      final jobResponse = results[0];
      final appliedJobsResponse = results[1];

      if (jobResponse['success']) {
        final jobData = jobResponse['data'];
        final currentUser = await _apiService.getUser();
        final currentUserId = currentUser['data']?['id']?.toString();

        // Check if the current user is the owner of the job
        final isOwner = jobData['customer_id']?.toString() == currentUserId;
        
        // Store current user ID
        setState(() {
          _currentUserId = currentUserId;
        });

        // Check if the user has already applied for this job and get application status
        bool applied = false;
        String? applicationStatus;
        bool hasCancelledApplication = false;
        if (appliedJobsResponse['success']) {
          final dynamic appliedData = appliedJobsResponse['data'];
          List<Map<String, dynamic>> appliedJobs = [];

          if (appliedData is Map && appliedData.containsKey('data')) {
            appliedJobs = List<Map<String, dynamic>>.from(appliedData['data']);
          } else if (appliedData is List) {
            appliedJobs = List<Map<String, dynamic>>.from(appliedData);
          }

          final matchingApp = appliedJobs.firstWhere(
            (app) => app['job']?['id']?.toString() == widget.jobId,
            orElse: () => <String, dynamic>{},
          );

          if (matchingApp.isNotEmpty) {
            applicationStatus = matchingApp['status']?.toString();
            if (applicationStatus == 'cancelled') {
              applied = false;
              hasCancelledApplication = true;
            } else if (applicationStatus == 'rejected') {
              applied = false;
            } else {
              applied = true;
            }
          }
        }

        Map<String, dynamic>? currentReview;
        final hasReviewed =
            jobData['has_reviewed_by_current_user'] == true;
        if (jobData['current_user_review'] is Map<String, dynamic>) {
          currentReview =
              Map<String, dynamic>.from(jobData['current_user_review']);
        }

        setState(() {
          _jobData = jobData;
          _isJobOwner = isOwner;
          _hasApplied = applied;
          _applicationStatus = applicationStatus;
          _hasCancelledApplication = hasCancelledApplication;
          _hasRated = hasReviewed;
          _currentUserReview = currentReview;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _error = jobResponse['message'] ?? 'Failed to load job details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading job: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyToJob() async {
    if (_jobData == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _apiService.loadToken();

      if (_apiService.token == null) {
        Navigator.pop(context); // Close loading dialog
        _showNotification('Silakan login terlebih dahulu', isError: true);
        return;
      }

      final response = await _apiService.applyJob(_jobData!['id'].toString());

      Navigator.pop(context); // Close loading dialog

      if (response['success']) {
        _showNotification(
          'Berhasil mengambil pekerjaan: ${_jobData!['title']}',
        );
        // Update the UI to show "Lamaran Sudah Diajukan"
        setState(() {
          _hasApplied = true;
          _applicationStatus = 'pending';
          _hasCancelledApplication = false;
        });
      } else {
        _showNotification(
          response['message'] ?? 'Gagal mengambil pekerjaan',
          isError: true,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showNotification('Error: ${e.toString()}', isError: true);
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(
          'Apakah Anda yakin ingin mengambil pekerjaan "${_jobData!['title']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyToJob();
            },
            child: const Text('Ya, Ambil'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelJob() async {
    if (_jobData == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );


      final response = await _apiService.cancelJob(_jobData!['id'].toString(),);
      Navigator.pop(context); // Close loading dialog

      if (response['success']) {
        _showNotification(
          widget.viewContext == JobDetailViewContext.customer
              ? 'Pesanan berhasil dibatalkan'
              : 'Lamaran berhasil dibatalkan',
        );
        // Refresh data after cancellation
        _loadJobData();
      } else {
        _showNotification(
          response['message'] ?? 'Gagal membatalkan',
          isError: true,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showNotification('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _acceptPrivateOrder() async {
    if (_jobData == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await _apiService.acceptPrivateOrder(
        _jobData!['id'].toString(),
      );
      Navigator.pop(context); // Close loading dialog

      if (response['success']) {
        _showNotification('Pesanan pribadi berhasil diterima!');
        // Refresh data after acceptance
        _loadJobData();
      } else {
        _showNotification(
          response['message'] ?? 'Gagal menerima pesanan',
          isError: true,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showNotification('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _rejectPrivateOrder() async {
    if (_jobData == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await _apiService.rejectPrivateOrder(
        _jobData!['id'].toString(),
      );
      Navigator.pop(context); // Close loading dialog

      if (response['success']) {
        _showNotification('Pesanan pribadi berhasil ditolak');
        // Refresh data after rejection
        _loadJobData();
      } else {
        _showNotification(
          response['message'] ?? 'Gagal menolak pesanan',
          isError: true,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showNotification('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _workerCompleteJob() async {
    if (_jobData == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final response = await _apiService.workerCompleteJob(
        _jobData!['id'].toString(),
      );
      Navigator.pop(context); // Close loading dialog

      if (response['success']) {
        _showNotification('Pengajuan penyelesaian berhasil dikirim!');
        _loadJobData();
      } else {
        _showNotification(
          response['message'] ?? 'Gagal mengajukan penyelesaian',
          isError: true,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showNotification('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _customerConfirmCompletion() async {
    if (_jobData == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final response = await _apiService.customerConfirmCompletion(
        _jobData!['id'].toString(),
      );
      Navigator.pop(context); // Close loading dialog

      if (response['success']) {
        _showNotification('Pekerjaan telah ditandai sebagai Selesai!');
        _loadJobData();
      } else {
        _showNotification(
          response['message'] ?? 'Gagal mengonfirmasi penyelesaian',
          isError: true,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showNotification('Error: ${e.toString()}', isError: true);
    }
  }

  void _showWorkerCompleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajukan Penyelesaian?'),
        content: const Text(
          'Anda akan mengajukan bahwa pekerjaan ini telah selesai. Customer akan diminta untuk melakukan konfirmasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _workerCompleteJob();
            },
            child: const Text('Ya, Ajukan'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    final isCustomer = widget.viewContext == JobDetailViewContext.customer;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Batalkan ${isCustomer ? 'Pesanan' : 'Lamaran'}?'),
        content: Text(
          'Apakah Anda yakin ingin membatalkan ${isCustomer ? 'pesanan' : 'lamaran'} ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelJob();
            },
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  void _showAcceptConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terima Pesanan Pribadi?'),
        content: const Text(
          'Apakah Anda yakin ingin menerima pesanan pribadi ini? Setelah diterima, pesanan akan berubah status menjadi "Sedang Berlangsung".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptPrivateOrder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
            ),
            child: const Text('Ya, Terima'),
          ),
        ],
      ),
    );
  }

  void _showRejectConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pesanan Pribadi?'),
        content: const Text(
          'Apakah Anda yakin ingin menolak pesanan pribadi ini? Setelah ditolak, pesanan akan dibatalkan dan tidak dapat diambil kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectPrivateOrder();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Tolak'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadJobData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_jobData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('No job data available')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    children: [
                      // Quick Info Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
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
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_jobData!['status'])
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(_jobData!['status'])
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getStatusIcon(_jobData!['status']),
                                      color: _getStatusColor(_jobData!['status']),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getStatusDisplayName(_jobData!['status']),
                                      style: TextStyle(
                                        color: _getStatusColor(_jobData!['status']),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildQuickInfo(
                                    Icons.attach_money_rounded,
                                    'Rp ${(_jobData!['price'] is String ? double.parse(_jobData!['price']) : (_jobData!['price'] as num)).toStringAsFixed(0)}',
                                    'Bayaran',
                                    const Color(0xFF10B981),
                                  ),
                                  _buildQuickInfo(
                                    Icons.access_time_rounded,
                                    _jobData!['scheduled_time'] != null
                                        ? _formatScheduledTime(
                                            _jobData!['scheduled_time'])
                                        : 'Fleksibel',
                                    'Jadwal',
                                    const Color(0xFF6366F1),
                                  ),
                                  _buildQuickInfo(
                                    Icons.timer_outlined,
                                    _formatTimeAgo(_jobData!['created_at']),
                                    'Diposting',
                                    const Color(0xFFF59E0B),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_hasCancelledApplication)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildCancelledApplicationBanner(),
                        ),
                      if (_hasCancelledApplication) const SizedBox(height: 16),
                      // Content Sections
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _buildDescriptionSection(),
                            const SizedBox(height: 16),
                            _buildCustomerInfoSection(),
                            // Show assigned worker section if job is completed or in progress
                            if ((_jobData!['status'] == 'completed' || 
                                 _jobData!['status'] == 'inProgress' ||
                                 _jobData!['status'] == 'pending_completion') &&
                                _jobData!['assigned_worker'] != null) ...[
                              const SizedBox(height: 16),
                              _buildAssignedWorkerSection(),
                            ],
                            const SizedBox(height: 16),
                            _buildRequirementsSection(),
                            const SizedBox(height: 16),
                            _buildLocationSection(),
                            if (_jobData!['scheduled_time'] != null) ...[
                              const SizedBox(height: 16),
                              _buildScheduleSection(),
                            ],
                            const SizedBox(height: 100), // Space for bottom button
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom Action Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: _buildBottomActionButton(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton() {
    final jobStatus = _jobData?['status'] ?? 'pending';
    final isPrivateOrder = _isPrivateOrder();

    // Prioritaskan alur konfirmasi penyelesaian
    // Context: Customer, job is waiting for their confirmation
    if (widget.viewContext == JobDetailViewContext.customer &&
        jobStatus == 'pending_completion') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _customerConfirmCompletion,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Konfirmasi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981), // Green
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Context: Customer managing their order
    if (widget.viewContext == JobDetailViewContext.customer) {
      if (jobStatus == 'pending' || jobStatus == 'inProgress') {
        if (isPrivateOrder) {
          // For private orders, only show cancel button
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCancelDialog,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Batalkan Pesanan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        } else {
          // For public orders, show both application and cancel buttons
          return Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobApplicationsScreen(
                          jobId: widget.jobId,
                          jobTitle: _jobData?['title'] ?? 'Job',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people, size: 18),
                  label: const Text('Pekerja'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCancelDialog,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Batalkan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      }
      // Perbaikan: Buat status non-aktif lebih spesifik
      if (jobStatus == 'completed') {
        // Check if customer needs to rate the worker
        final assignedWorker = _jobData?['assigned_worker'];
        final assignedWorkerId = assignedWorker?['id']?.toString() ?? 
                                 _jobData?['assigned_worker_id']?.toString();
        
        if (assignedWorkerId != null && 
            _currentUserId != null && 
            assignedWorkerId != _currentUserId) {
          final label = _hasRated
              ? 'Ubah Rating & Review'
              : 'Beri Rating & Review';
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRatingDialog(assignedWorkerId, assignedWorker),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }
        return _buildDisabledButton('Pesanan Telah Selesai');
      } else if (jobStatus == 'cancelled') {
        return _buildDisabledButton('Pesanan Telah Dibatalkan');
      } else {
        return _buildDisabledButton('Status Tidak Aktif'); // Fallback
      }
    }

    // Context: Worker, check if application was rejected
    if (widget.viewContext == JobDetailViewContext.worker &&
        _applicationStatus == 'rejected') {
      return _buildDisabledButton('Anda Ditolak');
    }

    if (widget.viewContext == JobDetailViewContext.worker &&
        _applicationStatus == 'cancelled') {
      return _buildDisabledButton('Anda membatalkan pesanan ini');
    }

    // ALUR BARU PENYELESAIAN PEKERJAAN
    // Context: Worker, job is in progress -> Worker can submit completion
    // Only if application is accepted or job is assigned to this worker
    if (widget.viewContext == JobDetailViewContext.worker &&
        jobStatus == 'inProgress') {
      // Check if this worker is the assigned worker or has accepted application
      final assignedWorkerId = _jobData?['assigned_worker_id']?.toString();
      final isAssignedWorker = assignedWorkerId != null && 
                               _currentUserId != null && 
                               assignedWorkerId == _currentUserId;
      final hasAcceptedApplication = _applicationStatus == 'accepted';
      
      if (isAssignedWorker || hasAcceptedApplication) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showWorkerCompleteConfirmationDialog,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Selesaikan Pekerjaan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // Green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      } else {
        // Worker is not assigned, show disabled button
        return _buildDisabledButton('Anda Tidak Diterima untuk Pekerjaan Ini');
      }
    }

    // Context: Worker, job is waiting for customer confirmation
    if (widget.viewContext == JobDetailViewContext.worker &&
        jobStatus == 'pending_completion') {
      return _buildDisabledButton('Menunggu Konfirmasi Customer');
    }

    // Context: Worker managing their application
    if (widget.viewContext == JobDetailViewContext.worker) {
      // If application is accepted but job is still pending, show different message
      if (_applicationStatus == 'accepted' && jobStatus == 'pending') {
        return _buildDisabledButton('Lamaran Diterima - Menunggu Mulai Pekerjaan');
      }
      
      if (jobStatus == 'pending' || jobStatus == 'inProgress') {
        // Only show cancel button if application is pending or accepted
        if (_applicationStatus == 'pending' || _applicationStatus == 'accepted') {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCancelDialog,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Batalkan Lamaran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }
      }
      // Perbaikan: Buat status non-aktif lebih spesifik
      if (jobStatus == 'completed') {
        // Check if worker needs to rate the customer
        final customer = _jobData?['customer'];
        final customerId = customer?['id']?.toString() ?? 
                          _jobData?['customer_id']?.toString();
        
        if (customerId != null && 
            _currentUserId != null && 
            customerId != _currentUserId) {
          final label = _hasRated
              ? 'Ubah Rating & Review'
              : 'Beri Rating & Review';
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRatingDialog(customerId, customer),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }
        return _buildDisabledButton('Pekerjaan Telah Selesai');
      } else if (jobStatus == 'cancelled') {
        return _buildDisabledButton('Pekerjaan Telah Dibatalkan');
      } else {
        return _buildDisabledButton('Status Tidak Aktif'); // Fallback
      }
    }

    // Default Context: Browsing jobs
    if (_isJobOwner) {
      return _buildDisabledButton('Ini Pekerjaan Anda');
    }

    if (_hasApplied) {
      return _buildDisabledButton('Lamaran Sudah Diajukan');
    }

    // For private orders assigned to current worker, show accept/reject buttons
    if (isPrivateOrder && _isAssignedToCurrentWorkerSync()) {
      if (jobStatus == 'pending') {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showAcceptConfirmationDialog,
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Terima'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showRejectConfirmationDialog,
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('Tolak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      } else if (jobStatus == 'inProgress') {
        return _buildDisabledButton('Pesanan Sedang Berlangsung');
      }
    }

    // For private orders, don't show apply button
    if (isPrivateOrder) {
      return _buildDisabledButton('Pesanan Khusus - Tidak Dapat Diajukan');
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _showConfirmationDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27AE60),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Ambil Pekerjaan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  bool _isPrivateOrder() {
    if (_jobData == null) return false;

    // Check if this is a private order based on additional_info
    final additionalInfo = _jobData!['additional_info'];
    if (additionalInfo is Map<String, dynamic>) {
      return additionalInfo['is_private_order'] == true;
    }

    // Alternative check: if assigned_worker_id exists and no applicants, it's likely private
    return _jobData!['assigned_worker_id'] != null &&
        (_jobData!['applicant_count'] == null ||
            _jobData!['applicant_count'] == 0);
  }

  bool _isAssignedToCurrentWorkerSync() {
    if (_jobData == null) return false;

    // For now, we'll use a simple check based on the job data
    // In a real implementation, you might want to store the current user ID
    // and compare it with assigned_worker_id
    final assignedWorkerId = _jobData!['assigned_worker_id']?.toString();

    // This is a simplified check - in production you'd want to verify
    // that the current user matches the assigned worker
    return assignedWorkerId != null;
  }

  Future<bool> _isAssignedToCurrentWorker() async {
    if (_jobData == null) return false;

    try {
      final currentUser = await _apiService.getUser();
      final currentUserId = currentUser['data']?['id']?.toString();
      final assignedWorkerId = _jobData!['assigned_worker_id']?.toString();

      return currentUserId != null &&
          assignedWorkerId != null &&
          currentUserId == assignedWorkerId;
    } catch (e) {
      return false;
    }
  }

  String? _getAssignedWorkerName() {
    if (_jobData == null) return null;

    // Try to get worker name from additional_info first
    final additionalInfo = _jobData!['additional_info'];
    if (additionalInfo is Map<String, dynamic>) {
      final workerName = additionalInfo['target_worker_name'];
      if (workerName != null && workerName.toString().isNotEmpty) {
        return workerName.toString();
      }
    }

    // Try to get from assigned_worker object
    final assignedWorker = _jobData!['assigned_worker'];
    if (assignedWorker is Map<String, dynamic>) {
      return assignedWorker['name']?.toString();
    }

    // Fallback: return assigned_worker_id if no name available
    final assignedWorkerId = _jobData!['assigned_worker_id'];
    if (assignedWorkerId != null) {
      return 'Pekerja ${assignedWorkerId.toString().substring(0, 8)}...';
    }

    return null;
  }

  Widget _buildDisabledButton(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    if (_jobData == null) {
      return SliverAppBar(
        expandedHeight: 160.0,
        pinned: true,
        floating: false,
        backgroundColor: const Color(0xFF2563EB),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
    }

    return SliverAppBar(
      expandedHeight: 160.0,
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Stack(
            children: [
              // Decorative vector elements
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 60,
                top: 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: 10,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              // Wave pattern overlay
              CustomPaint(
                size: Size.infinite,
                painter: WavePatternPainter(),
              ),
              // Content
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SlideTransition(
                          position: _slideAnimation,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getCategoryIconFromString(
                                        _jobData!['category'],
                                      ),
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getCategoryDisplayName(
                                        _jobData!['category'],
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isPrivateOrder()) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF10B981),
                                        const Color(0xFF059669),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.person_pin_circle_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Pribadi',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            _jobData!['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22.0,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  blurRadius: 8,
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledApplicationBanner() {
    final isWorkerView = widget.viewContext == JobDetailViewContext.worker;
    final message = isWorkerView
        ? 'Anda membatalkan lamaran ini. Pesanan dipindahkan ke Riwayat Anda.'
        : 'Anda sebelumnya membatalkan lamaran ini. Ajukan kembali jika masih berminat.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWorkerView
                      ? 'Lamaran Dibatalkan'
                      : 'Lamaran Sebelumnya Dibatalkan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _buildSectionCard(
      icon: Icons.description_rounded,
      iconColor: const Color(0xFF2D9CDB),
      title: 'Deskripsi Pekerjaan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _jobData!['description'],
            style: const TextStyle(
              color: Color(0xFF4F4F4F),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (_isPrivateOrder()) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2D9CDB).withOpacity(0.1),
                    const Color(0xFF27AE60).withOpacity(0.1),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2D9CDB).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        color: const Color(0xFF2D9CDB),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesanan khusus ini dibuat langsung untuk pekerja tertentu dan tidak terbuka untuk aplikasi umum.',
                          style: const TextStyle(
                            color: Color(0xFF2D9CDB),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_getAssignedWorkerName() != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2D9CDB).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          ProfileAvatar(
                            profileImagePath: _jobData?['assigned_worker']?['profile_image'],
                            radius: 16,
                            name: _getAssignedWorkerName(),
                            backgroundColor: const Color(0xFF2D9CDB).withOpacity(0.1),
                            iconColor: const Color(0xFF2D9CDB),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Diajukan ke:',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getAssignedWorkerName()!,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.verified_user_rounded,
                            color: const Color(0xFF27AE60),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJobDetailsCard() {
    return _buildSectionCard(
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF6366F1),
      title: 'Detail Penting',
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.attach_money_rounded,
            label: 'Harga',
            value:
                'Rp ${(_jobData!['price'] is String ? double.parse(_jobData!['price']) : (_jobData!['price'] as num)).toStringAsFixed(0)}',
            valueColor: const Color(0xFF10B981),
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(
            icon: Icons.category_rounded,
            label: 'Kategori',
            value: _getCategoryDisplayName(_jobData!['category']),
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(
            icon: Icons.history_toggle_off_rounded,
            label: 'Status',
            value: 'Terbuka', // Placeholder
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        const SizedBox(width: 16),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF4F4F4F), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfoSection() {
    final customer = _jobData!['customer'];
    if (customer == null) return const SizedBox.shrink();

    return _buildSectionCard(
      icon: Icons.person_rounded,
      iconColor: const Color(0xFF2D9CDB),
      title: 'Diajukan oleh',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                profileImagePath: customer['profile_image'],
                radius: 24,
                name: customer['name'],
                backgroundColor: const Color(0xFF2D9CDB).withOpacity(0.1),
                iconColor: const Color(0xFF2D9CDB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${customer['rating'] ?? 0.0}',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.work_rounded,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${customer['completed_jobs'] ?? 0} pekerjaan',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to worker/customer detail
                  final userId = customer['id']?.toString();
                  if (userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerDetailScreen(
                          workerId: userId,
                          initialWorkerData: customer,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D9CDB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2D9CDB).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        color: const Color(0xFF2D9CDB),
                        size: 16,
                      ),
                      
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (customer['current_address'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer['current_address'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedWorkerSection() {
    final assignedWorker = _jobData!['assigned_worker'];
    if (assignedWorker == null) return const SizedBox.shrink();

    final jobStatus = _jobData!['status'] ?? 'pending';
    final isCompleted = jobStatus == 'completed';
    
    return _buildSectionCard(
      icon: isCompleted ? Icons.check_circle_rounded : Icons.person_rounded,
      iconColor: isCompleted ? const Color(0xFF10B981) : const Color(0xFF2D9CDB),
      title: isCompleted ? 'Diselesaikan oleh' : 'Ditugaskan ke',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                profileImagePath: assignedWorker['profile_image'],
                radius: 24,
                name: assignedWorker['name'],
                backgroundColor: isCompleted 
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFF2D9CDB).withOpacity(0.1),
                iconColor: isCompleted 
                    ? const Color(0xFF10B981)
                    : const Color(0xFF2D9CDB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignedWorker['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${assignedWorker['rating'] ?? 0.0}',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.work_rounded,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${assignedWorker['completed_jobs'] ?? 0} pekerjaan',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to worker detail
                  final workerId = assignedWorker['id']?.toString();
                  if (workerId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerDetailScreen(
                          workerId: workerId,
                          initialWorkerData: assignedWorker,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFF2D9CDB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : const Color(0xFF2D9CDB).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2D9CDB),
                        size: 16,
                      ),
                      
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (assignedWorker['current_address'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    assignedWorker['current_address'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementsSection() {
    List<String> requirements = [];
    
    // Get requirements from additional_info if available
    final additionalInfo = _jobData!['additional_info'];
    if (additionalInfo is Map<String, dynamic>) {
      final req = additionalInfo['requirements'];
      if (req != null && req.toString().trim().isNotEmpty) {
        // Split by newline or bullet points
        requirements = req.toString().split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((e) => e.replaceAll(RegExp(r'^[•\-\*]\s*'), ''))
            .toList();
      }
    }
    
    // If no requirements found, show default message
    if (requirements.isEmpty) {
      requirements = ['Tidak ada persyaratan khusus'];
    }

    return _buildSectionCard(
      icon: Icons.checklist_rtl_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Persyaratan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: requirements.map((req) => _buildRequirementItem(req)).toList(),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    final isNoRequirement = text.toLowerCase().contains('tidak ada');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isNoRequirement
                  ? Colors.grey[300]
                  : const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNoRequirement
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_rounded,
              color: isNoRequirement
                  ? Colors.grey[600]
                  : const Color(0xFF10B981),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isNoRequirement
                    ? Colors.grey[600]
                    : const Color(0xFF1E293B),
                fontSize: 14,
                height: 1.5,
                fontStyle: isNoRequirement ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildSectionCard(
      icon: Icons.location_on_outlined,
      iconColor: const Color(0xFFEB5757),
      title: 'Lokasi Pekerjaan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _jobData!['address'],
            style: const TextStyle(
              color: Color(0xFF4F4F4F),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    'https://media.wired.com/photos/59269cd37034dc5f91bec0f1/master/w_2560%2Cc_limit/GoogleMapTA.jpg',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Safely parse latitude and longitude
                      double? lat;
                      double? lng;
                      
                      final latValue = _jobData!['latitude'];
                      final lngValue = _jobData!['longitude'];
                      
                      if (latValue != null) {
                        if (latValue is double) {
                          lat = latValue;
                        } else if (latValue is int) {
                          lat = latValue.toDouble();
                        } else if (latValue is String) {
                          lat = double.tryParse(latValue);
                        }
                      }
                      
                      if (lngValue != null) {
                        if (lngValue is double) {
                          lng = lngValue;
                        } else if (lngValue is int) {
                          lng = lngValue.toDouble();
                        } else if (lngValue is String) {
                          lng = double.tryParse(lngValue);
                        }
                      }
                      
                      if (lat != null && lng != null) {
                        _openMap(lat, lng);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text(
                      'Lihat di Peta',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final uri = Uri.tryParse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showNotification('Tidak dapat membuka peta', isError: true);
      }
    }
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          BoxShadow(
            color: iconColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: iconColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor, iconColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildQuickInfo(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getCategoryName(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return 'Bersih-bersih';
      case JobCategory.delivery:
        return 'Antar-Jemput';
      case JobCategory.maintenance:
        return 'Perbaikan';
      case JobCategory.gardening:
        return 'Kebun';
      case JobCategory.cooking:
        return 'Memasak';
      case JobCategory.tutoring:
        return 'Edukasi';
      case JobCategory.photography:
        return 'Fotografi';
      case JobCategory.petCare:
        return 'Perawatan Hewan';
      case JobCategory.other:
        return 'Lainnya';
    }
  }

  IconData _getCategoryIcon(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return Icons.cleaning_services;
      case JobCategory.delivery:
        return Icons.delivery_dining;
      case JobCategory.maintenance:
        return Icons.build;
      case JobCategory.gardening:
        return Icons.nature_people;
      case JobCategory.cooking:
        return Icons.kitchen;
      case JobCategory.tutoring:
        return Icons.school;
      case JobCategory.photography:
        return Icons.camera_alt;
      case JobCategory.petCare:
        return Icons.pets;
      case JobCategory.other:
        return Icons.help_outline;
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    // Hapus fungsi duplikat
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
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
        backgroundColor: isError ? Colors.red : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper methods for API data
  IconData _getCategoryIconFromString(String category) {
    switch (category) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'delivery':
        return Icons.delivery_dining;
      case 'maintenance':
        return Icons.build;
      case 'gardening':
        return Icons.nature_people;
      case 'cooking':
        return Icons.kitchen;
      case 'tutoring':
        return Icons.school;
      case 'photography':
        return Icons.camera_alt;
      case 'petCare':
        return Icons.pets;
      case 'other':
      default:
        return Icons.help_outline;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'cleaning':
        return 'Pembersihan';
      case 'delivery':
        return 'Pengiriman';
      case 'maintenance':
        return 'Perbaikan';
      case 'gardening':
        return 'Taman';
      case 'cooking':
        return 'Memasak';
      case 'tutoring':
        return 'Edukasi';
      case 'photography':
        return 'Fotografi';
      case 'petCare':
        return 'Perawatan Hewan';
      case 'other':
      default:
        return 'Lainnya';
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'inProgress':
        return 'Sedang Berlangsung';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'disputed':
        return 'Dispute';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'disputed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return 'Baru saja';

    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      Duration difference = DateTime.now().difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}h lalu';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}j lalu';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m lalu';
      } else {
        return 'Baru';
      }
    } catch (e) {
      return 'Baru saja';
    }
  }

  String _formatScheduledTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Fleksibel';

    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      
      if (dateTime.day == now.day &&
          dateTime.month == now.month &&
          dateTime.year == now.year) {
        return 'Hari ini';
      }
      
      final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      return '${dayNames[dateTime.weekday - 1]}, ${dateTime.day}/${dateTime.month}';
    } catch (e) {
      return 'Fleksibel';
    }
  }

  Widget _buildScheduleSection() {
    if (_jobData!['scheduled_time'] == null) return const SizedBox.shrink();

    try {
      DateTime scheduledTime = DateTime.parse(_jobData!['scheduled_time']);
      final timeStr = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
      final dateStr = '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year}';

      return _buildSectionCard(
        icon: Icons.calendar_today_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: 'Jadwal Pekerjaan',
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: const Color(0xFF8B5CF6),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Tanggal',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: const Color(0xFF3B82F6),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Waktu',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.access_time_rounded;
      case 'inProgress':
        return Icons.work_outline_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'pending_completion':
        return Icons.pending_actions_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  void _showRatingDialog(String ratedUserId, Map<String, dynamic>? ratedUserData) {
    final ratedUserName = ratedUserData?['name'] ?? 'User';
    final ratedUserProfileImage = ratedUserData?['profile_image'];
    int? initialRating;
    final ratingValue = _currentUserReview?['rating'];
    if (ratingValue is num) {
      initialRating = ratingValue.round();
    }
    final initialComment =
        _currentUserReview?['comment']?.toString();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitReviewScreen(
          jobId: widget.jobId,
          ratedUserId: ratedUserId,
          ratedUserName: ratedUserName,
          ratedUserProfileImage: ratedUserProfileImage,
          jobTitle: _jobData?['title'] ?? 'Job',
          initialRating: initialRating,
          initialComment: initialComment,
          isEditing: _hasRated,
        ),
      ),
    ).then((result) {
      // If rating was submitted successfully, refresh job data
      if (result == true) {
        setState(() {
          _hasRated = true;
        });
        _loadJobData();
      }
    });
  }
}

// Tambahkan class CustomPainter yang sama seperti di JobListScreen
class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final dotSize = 3.0;
    final spacing = 20.0;

    for (var x = 0.0; x < size.width; x += spacing) {
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    var path = Path();
    path.moveTo(0, size.height * 0.5);

    for (var i = 0; i < size.width; i += 50) {
      path.quadraticBezierTo(
        i + 25,
        size.height * 0.25,
        i + 50,
        size.height * 0.5,
      );
    }

    canvas.drawPath(path, paint);

    var path2 = Path();
    path2.moveTo(0, size.height * 0.7);

    for (var i = 0; i < size.width; i += 40) {
      path2.quadraticBezierTo(
        i + 20,
        size.height * 0.9,
        i + 40,
        size.height * 0.7,
      );
    }

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
