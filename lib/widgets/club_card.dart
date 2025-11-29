import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/club.dart';

class ClubCard extends StatelessWidget {
  final Club club;
  final VoidCallback onTap;
  final bool showJoinButton;
  final VoidCallback? onJoinTap;

  const ClubCard({
    Key? key,
    required this.club,
    required this.onTap,
    this.showJoinButton = false,
    this.onJoinTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Club Icon
              _buildClubIcon(),
              const SizedBox(width: 16),

              // Club Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Club Name
                    Text(
                      club.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Club Description
                    if (club.description.isNotEmpty)
                      Text(
                        club.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),

                    // Member Count
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 16,
                          color: Color(0xFF757575),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'clubs.info.memberCount'.tr(namedArgs: {
                            'count': '${club.memberCount}',
                            'max': '${club.maxMembers}',
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Visibility Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: club.isPublic
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            club.isPublic
                                ? 'clubs.info.public'.tr()
                                : 'clubs.info.private'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: club.isPublic ? Colors.green[700] : Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Button
              if (showJoinButton)
                ElevatedButton(
                  onPressed: club.isFull ? null : onJoinTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D0000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    club.isFull ? 'clubs.join.full'.tr() : 'clubs.joinButton'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: Color(0xFFBDBDBD),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubIcon() {
    Color iconColor;
    if (club.primaryColor != null) {
      try {
        iconColor = Color(int.parse(club.primaryColor!.replaceFirst('#', '0xFF')));
      } catch (e) {
        iconColor = const Color(0xFF3D0000);
      }
    } else {
      iconColor = const Color(0xFF3D0000);
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: iconColor.withOpacity(0.2),
      child: club.iconUrl != null && club.iconUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                club.iconUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultIcon(iconColor);
                },
              ),
            )
          : _buildDefaultIcon(iconColor),
    );
  }

  Widget _buildDefaultIcon(Color color) {
    return Text(
      club.name.isNotEmpty ? club.name[0].toUpperCase() : 'C',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}
