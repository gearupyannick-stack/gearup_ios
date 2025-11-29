import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/club.dart';
import '../../services/club_service.dart';
import '../../widgets/club_card.dart';
import 'club_create_page.dart';
import 'club_join_dialog.dart';
import 'club_detail_page.dart';

class ClubsHubPage extends StatefulWidget {
  const ClubsHubPage({Key? key}) : super(key: key);

  @override
  State<ClubsHubPage> createState() => _ClubsHubPageState();
}

class _ClubsHubPageState extends State<ClubsHubPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _navigateToCreateClub() async {
    final clubId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ClubCreatePage()),
    );

    if (clubId != null && mounted) {
      // Navigate to the newly created club
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubDetailPage(clubId: clubId),
        ),
      );
    }
  }

  Future<void> _showJoinByCodeDialog() async {
    final clubId = await showDialog<String>(
      context: context,
      builder: (context) => const ClubJoinDialog(),
    );

    if (clubId != null && mounted) {
      // Navigate to the joined club
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubDetailPage(clubId: clubId),
        ),
      );
    }
  }

  void _navigateToClubDetail(String clubId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubDetailPage(clubId: clubId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('clubs.title'.tr()),
        backgroundColor: const Color(0xFF3D0000),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'clubs.myClubs'.tr()),
            Tab(text: 'clubs.discover'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyClubsTab(),
          _buildDiscoverTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateClub,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('clubs.createButton'.tr()),
      ),
    );
  }

  Widget _buildMyClubsTab() {
    if (_user == null) {
      return _buildEmptyState(
        icon: Icons.login,
        message: 'Please sign in to view your clubs',
      );
    }

    return StreamBuilder<List<Club>>(
      stream: ClubService.instance.getUserClubsStream(_user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState('clubs.errors.loadFailed'.tr());
        }

        final clubs = snapshot.data ?? [];

        if (clubs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.groups_outlined,
            message: 'clubs.empty.noClubs'.tr(),
            subtitle: 'clubs.empty.noClubsDiscover'.tr(),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            cacheExtent: 100,
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return ClubCard(
                key: ValueKey(club.clubId),
                club: club,
                onTap: () => _navigateToClubDetail(club.clubId),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // Join by Code Button
        Container(
          margin: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showJoinByCodeDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3D0000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.vpn_key),
            label: Text(
              'clubs.join.byCode'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Public Clubs List
        Expanded(
          child: StreamBuilder<List<Club>>(
            stream: ClubService.instance.getPublicClubsStream(limit: 50),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildErrorState('clubs.errors.loadFailed'.tr());
              }

              final clubs = snapshot.data ?? [];

              if (clubs.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.public_off,
                  message: 'clubs.empty.noPublicClubs'.tr(),
                  subtitle: 'clubs.empty.createFirst'.tr(),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  cacheExtent: 100,
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    final club = clubs[index];
                    return ClubCard(
                      key: ValueKey(club.clubId),
                      club: club,
                      onTap: () => _navigateToClubDetail(club.clubId),
                      showJoinButton: true,
                      onJoinTap: () => _joinClub(club),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _joinClub(Club club) async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to join clubs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ClubService.instance.joinClub(club.clubId, _user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('clubs.join.success'.tr(namedArgs: {'clubName': club.name})),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to club detail
        _navigateToClubDetail(club.clubId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('clubs.join.error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
