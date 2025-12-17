import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTabIndex = 0;
  final ApiService _apiService = ApiService();

  bool _loadingOverview = true;
  Map<String, dynamic>? _overviewData;
  String? _overviewError;

  bool _loadingUsers = true;
  List<Map<String, dynamic>> _users = [];
  String? _usersError;
  String _userStatusFilter = 'all';
  int _userCurrentPage = 1;
  int _userLastPage = 1;
  int _userTotalItems = 0;
  String _userSearchQuery = '';

  bool _loadingJobs = true;
  List<Map<String, dynamic>> _jobs = [];
  String? _jobsError;
  String _jobStatusFilter = 'all';
  int _jobCurrentPage = 1;
  int _jobLastPage = 1;
  int _jobTotalItems = 0;
  String _jobSearchQuery = '';

  bool _loadingSos = true;
  List<Map<String, dynamic>> _sos = [];
  String? _sosError;
  String _sosStatusFilter = 'active';
  int _sosCurrentPage = 1;
  int _sosLastPage = 1;
  int _sosTotalItems = 0;
  String _sosSearchQuery = '';

  bool _loadingReviews = true;
  List<Map<String, dynamic>> _reviews = [];
  String? _reviewsError;
  int _reviewCurrentPage = 1;
  int _reviewLastPage = 1;
  int _reviewTotalItems = 0;
  String _reviewSearchQuery = '';
  bool _loadingComplaints = true;
  List<Map<String, dynamic>> _complaints = [];
  String? _complaintsError;
  String _complaintStatusFilter = 'pending';
  int _complaintCurrentPage = 1;
  int _complaintLastPage = 1;
  int _complaintTotalItems = 0;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final NumberFormat _compactNumber = NumberFormat.compact(locale: 'id_ID');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _resetSearchQueries();
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    _loadAllData();
  }

  void _resetSearchQueries() {
    setState(() {
      _userSearchQuery = '';
      _jobSearchQuery = '';
      _sosSearchQuery = '';
      _reviewSearchQuery = '';
      _complaintStatusFilter = '';
    });
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadOverview(),
      _loadUsers(),
      _loadJobs(),
      _loadSos(),
      _loadReviews(),
      _loadComplaints(),
    ]);
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loadingOverview = true;
      _overviewError = null;
    });
    try {
      final response = await _apiService.getAdminDashboard();
      setState(() {
        _overviewData = response['data'] as Map<String, dynamic>?;
        _loadingOverview = false;
      });
    } catch (e) {
      setState(() {
        _overviewError = e.toString();
        _loadingOverview = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final response = await _apiService.getAdminUsers(
        status: _userStatusFilter == 'all' ? null : _userStatusFilter,
        page: _userCurrentPage,
      );
      setState(() {
        _users = _extractList(response['data']);
        final meta = _extractMeta(response['data']);
        _userCurrentPage = meta['current_page'] ?? 1;
        _userLastPage = meta['last_page'] ?? 1;
        _userTotalItems = meta['total'] ?? 0;
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _usersError = e.toString();
        _loadingUsers = false;
      });
    }
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loadingJobs = true;
      _jobsError = null;
    });
    try {
      final response = await _apiService.getAdminJobs(
        status: _jobStatusFilter == 'all' ? null : _jobStatusFilter,
        page: _jobCurrentPage,
      );
      setState(() {
        _jobs = _extractList(response['data']);
        final meta = _extractMeta(response['data']);
        _jobCurrentPage = meta['current_page'] ?? 1;
        _jobLastPage = meta['last_page'] ?? 1;
        _jobTotalItems = meta['total'] ?? 0;
        _loadingJobs = false;
      });
    } catch (e) {
      setState(() {
        _jobsError = e.toString();
        _loadingJobs = false;
      });
    }
  }

  Future<void> _loadSos() async {
    setState(() {
      _loadingSos = true;
      _sosError = null;
    });
    try {
      final response = await _apiService.getAdminSos(
        status: _sosStatusFilter == 'all' ? null : _sosStatusFilter,
        page: _sosCurrentPage,
      );
      setState(() {
        _sos = _extractList(response['data']);
        final meta = _extractMeta(response['data']);
        _sosCurrentPage = meta['current_page'] ?? 1;
        _sosLastPage = meta['last_page'] ?? 1;
        _sosTotalItems = meta['total'] ?? 0;
        _loadingSos = false;
      });
    } catch (e) {
      setState(() {
        _sosError = e.toString();
        _loadingSos = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loadingReviews = true;
      _reviewsError = null;
    });
    try {
      final response = await _apiService.getAdminReviews(
        page: _reviewCurrentPage,
      );
      setState(() {
        _reviews = _extractList(response['data']);
        final meta = _extractMeta(response['data']);
        _reviewCurrentPage = meta['current_page'] ?? 1;
        _reviewLastPage = meta['last_page'] ?? 1;
        _reviewTotalItems = meta['total'] ?? 0;
        _loadingReviews = false;
      });
    } catch (e) {
      setState(() {
        _reviewsError = e.toString();
        _loadingReviews = false;
      });
    }
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _loadingComplaints = true;
      _complaintsError = null;
    });
    try {
      final response = await _apiService.getAdminBanComplaints(
        status: _complaintStatusFilter == 'all' ? null : _complaintStatusFilter,
        page: _complaintCurrentPage,
      );
      setState(() {
        _complaints = _extractList(response['data']);
        final meta = _extractMeta(response['data']);
        _complaintCurrentPage = meta['current_page'] ?? 1;
        _complaintLastPage = meta['last_page'] ?? 1;
        _complaintTotalItems = meta['total'] ?? 0;
        _loadingComplaints = false;
      });
    } catch (e) {
      setState(() {
        _complaintsError = e.toString();
        _loadingComplaints = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _extractMeta(dynamic data) {
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<void> _banUser(Map<String, dynamic> user) async {
    final reasonController = TextEditingController();
    double duration = 7;
    bool isPermanent = false;
    String? errorMessage;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Blokir ${user['name'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: isPermanent,
                          onChanged: (value) {
                            setModalState(() {
                              isPermanent = value ?? false;
                              errorMessage = null; // Clear error when checkbox changes
                            });
                          },
                          activeColor: const Color(0xFFEF4444),
                        ),
                        const Expanded(
                          child: Text(
                            'Blokir Permanen',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isPermanent) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Durasi blokir (hari)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Slider(
                        value: duration,
                        min: 1,
                        max: 90,
                        divisions: 89,
                        label: '${duration.round()} hari',
                        activeColor: const Color(0xFFEF4444),
                        onChanged: (value) => setModalState(() => duration = value),
                      ),
                      Center(
                        child: Text(
                          duration.round() == 1
                              ? '1 hari'
                              : '${duration.round()} hari',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Alasan pemblokiran',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      onChanged: (value) {
                        if (errorMessage != null && value.trim().length >= 10) {
                          setModalState(() => errorMessage = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Tuliskan detail alasan blokir',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: errorMessage != null
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        errorText: errorMessage,
                        errorMaxLines: 2,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (reasonController.text.trim().length < 10) {
                                setModalState(() {
                                  errorMessage = 'Alasan harus minimal 10 karakter.';
                                });
                                FocusScope.of(context).unfocus();
                                return;
                              }
                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Blokir User'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        await _apiService.banUser(
          user['id'].toString(),
          durationDays: isPermanent ? null : duration.round(),
          reason: reasonController.text.trim(),
          isPermanent: isPermanent,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User berhasil diblokir.')),
          );
        }
        _loadUsers();
        _loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _unbanUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cabut Blokir',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Aktifkan kembali akses ${user['name'] ?? 'user'}?',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.unbanUser(user['id'].toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Blokir berhasil dicabut.')),
          );
        }
        _loadUsers();
        _loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _forceCancelJob(Map<String, dynamic> job) async {
    final controller = TextEditingController();
    String? errorMessage;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Hapus Pesanan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    onChanged: (value) {
                      if (errorMessage != null && value.trim().length >= 10) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Tuliskan alasan penghapusan',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: errorMessage != null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      errorText: errorMessage,
                      errorMaxLines: 2,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().length < 10) {
                    setDialogState(() {
                      errorMessage = 'Alasan minimal 10 karakter.';
                    });
                    FocusScope.of(context).unfocus();
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hapus Pesanan'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.forceCancelJob(
          job['id'].toString(),
          reason: controller.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pesanan dibatalkan.')));
        }
        _loadJobs();
        _loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final controller = TextEditingController();
    String? errorMessage;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Hapus Review',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review['comment'] ?? '(Tanpa komentar)',
                    style: const TextStyle(color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    onChanged: (value) {
                      if (errorMessage != null && value.trim().length >= 10) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Tuliskan alasan penghapusan',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: errorMessage != null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      errorText: errorMessage,
                      errorMaxLines: 2,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().length < 10) {
                    setDialogState(() {
                      errorMessage = 'Alasan minimal 10 karakter.';
                    });
                    FocusScope.of(context).unfocus();
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Hapus'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteReview(
          review['id'].toString(),
          reason: controller.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Review dihapus.')));
        }
        _loadReviews();
        _loadOverview();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
        title: const Text(
          'Servify Control Center',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                controller: _tabController,
                tabAlignment: TabAlignment.start,
                isScrollable: true,
                splashBorderRadius: BorderRadius.circular(18),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                indicatorPadding: const EdgeInsets.symmetric(
                  horizontal: -8,
                  vertical: 6,
                ),
                labelColor: const Color(0xFF1E293B),
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: const [
                  Tab(child: Text('Ringkasan')),
                  Tab(child: Text('User')),
                  Tab(child: Text('Pesanan')),
                  Tab(child: Text('SOS')),
                  Tab(child: Text('Review')),
                  Tab(child: Text('Komplain')),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
      const SizedBox(height: 20),
            const SizedBox(height: kToolbarHeight + 90), // Space for AppBar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: Colors.white,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildUsersTab(),
                        _buildJobsTab(),
                        _buildSosTab(),
                        _buildReviewsTab(),
                        _buildComplaintsTab(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_loadingOverview) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_overviewError != null) {
      return _buildErrorState(_overviewError!, _loadOverview);
    }

    final stats = (_overviewData?['stats'] ?? {}) as Map<String, dynamic>;
    final actions = _extractList(_overviewData?['recent_actions']);
    final bans = _extractList(_overviewData?['recent_bans']);

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        // Changed to ListView
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildPinnedInfoCard(),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isSingleColumn =
                  maxWidth < 520; // Threshold for single column
              final double itemWidth = isSingleColumn
                  ? maxWidth
                  : (maxWidth - 16) / 2;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: stats.entries.map((entry) {
                  final meta = _getStatMeta(entry.key);
                  return SizedBox(
                    width: itemWidth,
                    child: _buildStatChip(meta: meta, value: entry.value),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Aksi Admin Terbaru',
            child: actions.isEmpty
                ? _buildEmptyStateText('Belum ada aksi admin.')
                : Column(
                    children: actions.map((action) {
                      return _buildTimelineTile(
                        icon: Icons.history_rounded,
                        color: const Color(0xFF2563EB),
                        title: action['action_type'] ?? '-',
                        subtitle:
                            'Target: ${action['target_type'] ?? '-'} • ${_formatDate(action['created_at'])}',
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Ban Terbaru',
            child: bans.isEmpty
                ? _buildEmptyStateText('Belum ada ban terbaru.')
                : Column(
                    children: bans.map((ban) {
                      final user = ban['user'] as Map<String, dynamic>?;
                      return _buildTimelineTile(
                        icon: Icons.block_rounded,
                        color: const Color(0xFFEF4444),
                        title: user?['name'] ?? 'User',
                        subtitle:
                            'Hingga ${_formatDate(ban['banned_until'])}\n${ban['reason'] ?? ''}',
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedInfoCard() {
    const tabDescriptions = [
      'Lihat ringkasan performa platform dan aksi terbaru.',
      'Kelola dan moderasi seluruh akun pengguna.',
      'Pantau pesanan publik maupun privat.',
      'Respon laporan SOS yang sedang aktif.',
      'Tinjau ulasan dan jaga kualitas layanan.',
      'Kelola komplain dari user yang diblokir.',
    ];

    const tabIcons = [
      Icons.dashboard_rounded,
      Icons.groups_rounded,
      Icons.work_history_rounded,
      Icons.emergency_share_rounded,
      Icons.reviews_rounded,
      Icons.forum_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                tabIcons[_currentTabIndex],
                color: const Color(0xFF2563EB),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      'Ringkasan',
                      'Manajemen User',
                      'Monitoring Pesanan',
                      'Laporan SOS',
                      'Review & Reputasi',
                      'Komplain Ban',
                    ][_currentTabIndex],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tabDescriptions[_currentTabIndex],
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return _buildErrorState(_usersError!, _loadUsers);
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        // Changed to ListView
        padding: const EdgeInsets.all(16),
        children: [
          _buildPinnedInfoCard(),
          const SizedBox(height: 12),
          _buildSearchField(
            hint: 'Cari user berdasarkan nama...',
            onChanged: (value) {
              setState(() {
                _userSearchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label:
                    'Semua (${_compactNumber.format(_overviewData?['stats']?['total_users'] ?? 0)})',
                selected: _userStatusFilter == 'all',
                onTap: () {
                  setState(() {
                    _userStatusFilter = 'all';
                    _userCurrentPage = 1;
                  });
                  _loadUsers();
                },
              ),
              _buildFilterChip(
                label: 'Aktif',
                selected: _userStatusFilter == 'active',
                onTap: () {
                  setState(() {
                    _userStatusFilter = 'active';
                    _userCurrentPage = 1;
                  });
                  _loadUsers();
                },
              ),
              _buildFilterChip(
                label:
                    'Terblokir (${_compactNumber.format(_overviewData?['stats']?['banned_users'] ?? 0)})',
                selected: _userStatusFilter == 'banned',
                onTap: () {
                  setState(() {
                    _userStatusFilter = 'banned';
                    _userCurrentPage = 1;
                  });
                  _loadUsers();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._users
              .where(
                (user) =>
                    _userSearchQuery.isEmpty ||
                    (user['name'] as String? ?? '').toLowerCase().contains(
                      _userSearchQuery.toLowerCase(),
                    ),
              )
              .map(_buildUserCard),
          if (_users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada data user.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildPaginationControls(
            currentPage: _userCurrentPage,
            lastPage: _userLastPage,
            onPrevious: () {
              setState(() => _userCurrentPage--);
              _loadUsers();
            },
            onNext: () {
              setState(() => _userCurrentPage++);
              _loadUsers();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJobsTab() {
    if (_loadingJobs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_jobsError != null) {
      return _buildErrorState(_jobsError!, _loadJobs);
    }

    return RefreshIndicator(
      onRefresh: _loadJobs,
      child: ListView(
        // Changed to ListView
        padding: const EdgeInsets.all(16),
        children: [
          _buildPinnedInfoCard(),
          const SizedBox(height: 12),
          _buildSearchField(
            hint: 'Cari pesanan berdasarkan judul...',
            onChanged: (value) {
              setState(() {
                _jobSearchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: 'Semua',
                selected: _jobStatusFilter == 'all',
                onTap: () {
                  setState(() {
                    _jobStatusFilter = 'all';
                    _jobCurrentPage = 1;
                  });
                  _loadJobs();
                },
              ),
              _buildFilterChip(
                label: 'Pending',
                selected: _jobStatusFilter == 'pending',
                onTap: () {
                  setState(() {
                    _jobStatusFilter = 'pending';
                    _jobCurrentPage = 1;
                  });
                  _loadJobs();
                },
              ),
              _buildFilterChip(
                label: 'Berjalan',
                selected: _jobStatusFilter == 'inProgress',
                onTap: () {
                  setState(() {
                    _jobStatusFilter = 'inProgress';
                    _jobCurrentPage = 1;
                  });
                  _loadJobs();
                },
              ),
              _buildFilterChip(
                label: 'Dispute',
                selected: _jobStatusFilter == 'disputed',
                onTap: () {
                  setState(() {
                    _jobStatusFilter = 'disputed';
                    _jobCurrentPage = 1;
                  });
                  _loadJobs();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._jobs
              .where(
                (job) =>
                    _jobSearchQuery.isEmpty ||
                    (job['title'] as String? ?? '').toLowerCase().contains(
                      _jobSearchQuery.toLowerCase(),
                    ) ||
                    (job['customer']?['name'] as String? ?? '')
                        .toLowerCase()
                        .contains(_jobSearchQuery.toLowerCase()),
              )
              .map(_buildJobCard),
          if (_jobs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada data pesanan.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildPaginationControls(
            currentPage: _jobCurrentPage,
            lastPage: _jobLastPage,
            onPrevious: () {
              setState(() => _jobCurrentPage--);
              _loadJobs();
            },
            onNext: () {
              setState(() => _jobCurrentPage++);
              _loadJobs();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSosTab() {
    if (_loadingSos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sosError != null) {
      return _buildErrorState(_sosError!, _loadSos);
    }

    return RefreshIndicator(
      onRefresh: _loadSos,
      child: ListView(
        // Changed to ListView
        padding: const EdgeInsets.all(16),
        children: [
          _buildPinnedInfoCard(),
          const SizedBox(height: 12),
          _buildSearchField(
            hint: 'Cari SOS berdasarkan judul atau nama...',
            onChanged: (value) {
              setState(() {
                _sosSearchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: 'Aktif',
                selected: _sosStatusFilter == 'active',
                onTap: () {
                  setState(() {
                    _sosStatusFilter = 'active';
                    _sosCurrentPage = 1;
                  });
                  _loadSos();
                },
              ),
              _buildFilterChip(
                label: 'Selesai',
                selected: _sosStatusFilter == 'completed',
                onTap: () {
                  setState(() {
                    _sosStatusFilter = 'completed';
                    _sosCurrentPage = 1;
                  });
                  _loadSos();
                },
              ),
              _buildFilterChip(
                label: 'Batal',
                selected: _sosStatusFilter == 'cancelled',
                onTap: () {
                  setState(() {
                    _sosStatusFilter = 'cancelled';
                    _sosCurrentPage = 1;
                  });
                  _loadSos();
                },
              ),
              _buildFilterChip(
                label: 'Semua',
                selected: _sosStatusFilter == 'all',
                onTap: () {
                  setState(() {
                    _sosStatusFilter = 'all';
                    _sosCurrentPage = 1;
                  });
                  _loadSos();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._sos
              .where(
                (s) =>
                    _sosSearchQuery.isEmpty ||
                    (s['title'] as String? ?? '').toLowerCase().contains(
                      _sosSearchQuery.toLowerCase(),
                    ) ||
                    (s['requester']?['name'] as String? ?? '')
                        .toLowerCase()
                        .contains(_sosSearchQuery.toLowerCase()),
              )
              .map(_buildSosCard),
          if (_sos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada laporan SOS.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildPaginationControls(
            currentPage: _sosCurrentPage,
            lastPage: _sosLastPage,
            onPrevious: () {
              setState(() => _sosCurrentPage--);
              _loadSos();
            },
            onNext: () {
              setState(() => _sosCurrentPage++);
              _loadSos();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviewsError != null) {
      return _buildErrorState(_reviewsError!, _loadReviews);
    }

    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: ListView(
        // Changed to ListView
        padding: const EdgeInsets.all(16),
        children: [
          _buildPinnedInfoCard(),
          const SizedBox(height: 12),
          _buildSearchField(
            hint: 'Cari review berdasarkan nama...',
            onChanged: (value) {
              setState(() {
                _reviewSearchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          ..._reviews
              .where(
                (review) =>
                    _reviewSearchQuery.isEmpty ||
                    (review['reviewer']?['name'] as String? ?? '')
                        .toLowerCase()
                        .contains(_reviewSearchQuery.toLowerCase()),
              )
              .map(_buildReviewCard),
          if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada review.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildPaginationControls(
            currentPage: _reviewCurrentPage,
            lastPage: _reviewLastPage,
            onPrevious: () {
              setState(() => _reviewCurrentPage--);
              _loadReviews();
            },
            onNext: () {
              setState(() => _reviewCurrentPage++);
              _loadReviews();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsTab() {
    if (_loadingComplaints) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_complaintsError != null) {
      return _buildErrorState(_complaintsError!, _loadComplaints);
    }

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: ListView(
        // Changed to ListView
        padding: const EdgeInsets.all(16),
        children: [
          _buildPinnedInfoCard(),
          const SizedBox(height: 12),
          _buildSearchField(
            hint: 'Cari komplain berdasarkan nama...',
            onChanged: (value) {
              setState(() {
                _complaintStatusFilter = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: 'Pending',
                selected: _complaintStatusFilter == 'pending',
                onTap: () {
                  setState(() {
                    _complaintStatusFilter = 'pending';
                    _complaintCurrentPage = 1;
                  });
                  _loadComplaints();
                },
              ),
              _buildFilterChip(
                label: 'Ditinjau',
                selected: _complaintStatusFilter == 'reviewed',
                onTap: () {
                  setState(() {
                    _complaintStatusFilter = 'reviewed';
                    _complaintCurrentPage = 1;
                  });
                  _loadComplaints();
                },
              ),
              _buildFilterChip(
                label: 'Selesai',
                selected: _complaintStatusFilter == 'resolved',
                onTap: () {
                  setState(() {
                    _complaintStatusFilter = 'resolved';
                    _complaintCurrentPage = 1;
                  });
                  _loadComplaints();
                },
              ),
              _buildFilterChip(
                label: 'Ditolak',
                selected: _complaintStatusFilter == 'rejected',
                onTap: () {
                  setState(() {
                    _complaintStatusFilter = 'rejected';
                    _complaintCurrentPage = 1;
                  });
                  _loadComplaints();
                },
              ),
              _buildFilterChip(
                label: 'Semua',
                selected: _complaintStatusFilter == 'all',
                onTap: () {
                  setState(() {
                    _complaintStatusFilter = 'all';
                    _complaintCurrentPage = 1;
                  });
                  _loadComplaints();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._complaints
              .where(
                (complaint) =>
                    _complaintStatusFilter.isEmpty ||
                    (complaint['user']?['name'] as String? ?? '')
                        .toLowerCase()
                        .contains(_complaintStatusFilter.toLowerCase()),
              )
              .map(_buildComplaintCard),
          if (_complaints.isEmpty)
            _buildEmptyStateText('Tidak ada komplain untuk status ini.'),
          const SizedBox(height: 16),
          _buildPaginationControls(
            currentPage: _complaintCurrentPage,
            lastPage: _complaintLastPage,
            onPrevious: () {
              setState(() => _complaintCurrentPage--);
              _loadComplaints();
            },
            onNext: () {
              setState(() => _complaintCurrentPage++);
              _loadComplaints();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({required _StatMeta meta, required dynamic value}) {
    final displayValue = value is num
        ? _compactNumber.format(value)
        : value?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: meta.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: meta.gradient.last.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            meta.label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyStateText(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildTimelineTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _darken(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int lastPage,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    if (lastPage <= 1) {
      return const SizedBox.shrink(); // No controls if only one page
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Tombol Previous
          Expanded(
            child: OutlinedButton(
              onPressed: currentPage > 1 ? onPrevious : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Prev'),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Info halaman
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Halaman $currentPage dari $lastPage',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Tombol Next
          Expanded(
            child: OutlinedButton(
              onPressed: currentPage < lastPage ? onNext : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF2563EB) : const Color(0xFF475569),
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final bool isBanned = user['is_banned'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBanned
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                child: Text(
                  (user['name'] ?? 'U')[0].toString().toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      user['email'] ?? '-',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isBanned
                      ? const Color(0xFFFECDD3)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isBanned ? 'Terblokir' : 'Aktif',
                  style: TextStyle(
                    color: isBanned
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF047857),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isBanned && user['ban_reason'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alasan blokir:',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user['ban_reason'] ?? '-',
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                  if (user['banned_until'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Hingga ${_formatDate(user['banned_until'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ] else if (user['is_banned'] == true) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Blokir Permanen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    isBanned ? Icons.lock_open_rounded : Icons.gavel_rounded,
                    size: 18,
                  ),
                  label: Text(isBanned ? 'Cabut Blokir' : 'Blokir User'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isBanned
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    side: BorderSide(
                      color: isBanned
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  onPressed: () => isBanned ? _unbanUser(user) : _banUser(user),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] ?? 'pending';
    final customer = job['customer'] as Map<String, dynamic>?;
    final worker = job['assigned_worker'] as Map<String, dynamic>?;
    final bool alreadyCancelled = status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job['title'] ?? 'Pesanan',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job['category'] ?? '-',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Customer: ${customer?['name'] ?? '-'}',
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.handyman_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Worker: ${worker?['name'] ?? 'Belum ditugaskan'}',
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                _currency.format(_parseAmount(job['price'])),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (job['admin_cancel_reason'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Alasan admin: ${job['admin_cancel_reason']}',
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!alreadyCancelled)
            OutlinedButton.icon(
              onPressed: () => _forceCancelJob(job),
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
              ),
              label: const Text(
                'Hapus Pesanan',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSosCard(Map<String, dynamic> sos) {
    final requester = sos['requester'] as Map<String, dynamic>?;
    final helper = sos['helper'] as Map<String, dynamic>?;
    final status = sos['status'] ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sos['title'] ?? 'SOS',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sos['description'] ?? '-',
            style: const TextStyle(color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sos['address'] ?? '-',
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Requester: ${requester?['name'] ?? '-'}',
            style: const TextStyle(color: Color(0xFF475569)),
          ),
          if (helper != null)
            Text(
              'Helper: ${helper['name']}',
              style: const TextStyle(color: Color(0xFF047857)),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewer = review['reviewer'] as Map<String, dynamic>?;
    final reviewee = review['reviewee'] as Map<String, dynamic>?;
    final rating = (review['rating'] ?? 0).toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _deleteReview(review),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444)),
                ),
                child: const Text(
                  'Hapus Review',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'] ?? '(Tanpa komentar)',
            style: const TextStyle(color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            'Oleh ${reviewer?['name'] ?? '-'} untuk ${reviewee?['name'] ?? '-'}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = const Color(0xFFFBBF24);
        label = 'Pending';
        break;
      case 'inProgress':
        color = const Color(0xFF3B82F6);
        label = 'Berjalan';
        break;
      case 'completed':
        color = const Color(0xFF10B981);
        label = 'Selesai';
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444);
        label = 'Batal';
        break;
      case 'disputed':
        color = const Color(0xFFF97316);
        label = 'Dispute';
        break;
      case 'reviewed':
        color = const Color(0xFF0EA5E9);
        label = 'Ditinjau';
        break;
      case 'resolved':
        color = const Color(0xFF10B981);
        label = 'Selesai';
        break;
      case 'rejected':
        color = const Color(0xFFDC2626);
        label = 'Ditolak';
        break;
      default:
        color = const Color(0xFF10B981);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildErrorState(String message, Future<void> Function() retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: retry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    final user = complaint['user'] as Map<String, dynamic>?;
    final status = (complaint['status'] ?? 'pending').toString();
    final submittedAt = DateTime.tryParse(complaint['created_at'] ?? '');
    final evidenceUrl = complaint['evidence_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?['name'] ?? complaint['email'] ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      complaint['email'] ?? '-',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              complaint['reason'] ?? '-',
              style: const TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
          ),
          if (evidenceUrl != null && evidenceUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openEvidenceDialog(evidenceUrl),
              child: Row(
                children: const [
                  Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Text(
                    'Lihat Bukti',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                submittedAt != null
                    ? DateFormat(
                        'dd MMM yyyy, HH:mm',
                        'id_ID',
                      ).format(submittedAt)
                    : 'Belum diketahui',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          if (complaint['admin_notes'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan Admin: ${complaint['admin_notes']}',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _handleComplaintAction(complaint),
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
            label: const Text(
              'Tindak Lanjuti',
              style: TextStyle(color: Color(0xFF2563EB)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  void _openEvidenceDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Bukti Pendukung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Salin tautan berikut untuk membuka bukti:',
              style: TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            SelectableText(
              url,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tautan disalin ke clipboard')),
                );
              }
            },
            child: const Text('Salin'),
          ),
        ],
      ),
    );
  }

  void _handleComplaintAction(Map<String, dynamic> complaint) {
    final notesController = TextEditingController(
      text: complaint['admin_notes']?.toString() ?? '',
    );
    String status = (complaint['status'] ?? 'pending').toString();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tindak Lanjuti Komplain',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'reviewed',
                        child: Text('Sedang Ditinjau'),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('Disetujui / Dipulihkan'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Ditolak'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Catatan untuk user',
                      hintText: 'Berikan catatan singkat',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              try {
                                await _apiService.handleBanComplaint(
                                  complaint['id'].toString(),
                                  status: status,
                                  adminNotes:
                                      notesController.text.trim().isEmpty
                                      ? null
                                      : notesController.text.trim(),
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Status komplain diperbarui',
                                      ),
                                    ),
                                  );
                                }
                                await _loadComplaints();
                                if (context.mounted) Navigator.pop(context);
                              } on ApiException catch (e) {
                                _showErrorSnack(e.message);
                              } catch (e) {
                                _showErrorSnack(e.toString());
                              } finally {
                                setSheetState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed == null) return '-';
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(parsed);
    } catch (_) {
      return date.toString();
    }
  }

  String _formatStatKey(String key) {
    switch (key) {
      case 'total_users':
        return 'Total User';
      case 'banned_users':
        return 'User Terblokir';
      case 'active_jobs':
        return 'Pesanan Aktif';
      case 'disputed_jobs':
        return 'Pesanan Dispute';
      case 'active_sos':
        return 'SOS Aktif';
      case 'completed_sos':
        return 'SOS Selesai';
      case 'total_reviews':
        return 'Total Review';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  _StatMeta _getStatMeta(String key) {
    switch (key) {
      case 'total_users':
        return _StatMeta(
          label: 'Total User',
          icon: Icons.groups_rounded,
          gradient: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
        );
      case 'banned_users':
        return _StatMeta(
          label: 'User Terblokir',
          icon: Icons.block_rounded,
          gradient: const [Color(0xFFEF4444), Color(0xFFF87171)],
        );
      case 'active_jobs':
        return _StatMeta(
          label: 'Pesanan Aktif',
          icon: Icons.assignment_turned_in_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        );
      case 'disputed_jobs':
        return _StatMeta(
          label: 'Pesanan Dispute',
          icon: Icons.report_gmailerrorred_rounded,
          gradient: const [Color(0xFFF97316), Color(0xFFFEC05C)],
        );
      case 'active_sos':
        return _StatMeta(
          label: 'SOS Aktif',
          icon: Icons.emergency_rounded,
          gradient: const [Color(0xFFEC4899), Color(0xFFF472B6)],
        );
      case 'completed_sos':
        return _StatMeta(
          label: 'SOS Selesai',
          icon: Icons.workspace_premium_rounded,
          gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        );
      case 'total_reviews':
        return _StatMeta(
          label: 'Total Review',
          icon: Icons.rate_review_rounded,
          gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        );
      default:
        return _StatMeta(
          label: _formatStatKey(key),
          icon: Icons.analytics_outlined,
          gradient: const [Color(0xFF475569), Color(0xFF94A3B8)],
        );
    }
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  Color _darken(Color color, [double amount = .2]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _StatMeta {
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const _StatMeta({
    required this.label,
    required this.icon,
    required this.gradient,
  });
}
