import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/race_challenge.dart';

class RaceChallengeDialog extends StatefulWidget {
  const RaceChallengeDialog({Key? key}) : super(key: key);

  @override
  State<RaceChallengeDialog> createState() => _RaceChallengeDialogState();
}

class _RaceChallengeDialogState extends State<RaceChallengeDialog> {
  ChallengeType _selectedType = ChallengeType.instant;
  int _maxParticipants = 4;
  int _questionsCount = 10;
  DateTime? _scheduledTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2E2E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      title: _buildHeader(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildSectionTitle('Race Type'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    type: ChallengeType.instant,
                    icon: Icons.flash_on,
                    title: 'Instant',
                    subtitle: 'Starts when full',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeOption(
                    type: ChallengeType.scheduled,
                    icon: Icons.schedule,
                    title: 'Scheduled',
                    subtitle: 'Set start time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedType == ChallengeType.scheduled) ...[
              _buildSectionTitle('Start Time'),
              const SizedBox(height: 12),
              _buildDateTimePicker(),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle('Max Participants'),
            const SizedBox(height: 4),
            _buildParticipantsSlider(),
            const SizedBox(height: 24),
            _buildSectionTitle('Number of Questions'),
            const SizedBox(height: 12),
            _buildQuestionsSelector(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton(
          onPressed: _canCreate() ? _createChallenge : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade800,
            disabledForegroundColor: Colors.grey.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.emoji_events,
            color: Color(0xFFE53935),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Create Race',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildTypeOption({
    required ChallengeType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE53935) : const Color(0xFF3D3D3D),
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected ? Border.all(color: Colors.red.shade200, width: 1) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[300],
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[200],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.red.shade100 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return InkWell(
      onTap: _selectDateTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF3D3D3D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFFE53935)),
            const SizedBox(width: 12),
            Text(
              _scheduledTime != null
                  ? DateFormat('MMM d, yyyy - HH:mm').format(_scheduledTime!)
                  : 'Select date and time',
              style: TextStyle(
                fontSize: 15,
                color: _scheduledTime != null ? Colors.white : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: _maxParticipants.toDouble(),
              min: 2,
              max: 10,
              divisions: 8,
              activeColor: const Color(0xFFE53935),
              inactiveColor: Colors.grey[600],
              label: '$_maxParticipants players',
              onChanged: (value) {
                setState(() => _maxParticipants = value.toInt());
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_maxParticipants',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [5, 10, 15, 20].map((count) {
        final isSelected = _questionsCount == count;
        return InkWell(
          onTap: () => setState(() => _questionsCount = count),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFFE53935) : const Color(0xFF3D3D3D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[300],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initialDate = _scheduledTime ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isAfter(now) ? initialDate : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE53935),
              onPrimary: Colors.white,
              surface: Color(0xFF2E2E2E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF3D3D3D),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFE53935),
                onPrimary: Colors.white,
                surface: Color(0xFF2E2E2E),
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: const Color(0xFF3D3D3D),
            ),
            child: child!,
          );
        },
      );

      if (time != null && mounted) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  bool _canCreate() {
    if (_selectedType == ChallengeType.scheduled && _scheduledTime == null) {
      return false;
    }
    if (_selectedType == ChallengeType.scheduled &&
        _scheduledTime != null &&
        _scheduledTime!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  void _createChallenge() {
    Navigator.pop(context, {
      'type': _selectedType,
      'scheduledTime': _scheduledTime,
      'maxParticipants': _maxParticipants,
      'questionsCount': _questionsCount,
    });
  }
}
