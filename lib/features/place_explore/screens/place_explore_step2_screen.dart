import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../models/place.dart';
import '../models/place_detail.dart';
import '../providers/place_explore_provider.dart';
import '../widgets/place_select_card.dart';
import '../../trip/widgets/trip_step_header.dart';

class PlaceExploreStep2Screen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const PlaceExploreStep2Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
  });

  List<PlaceDetail> _orderedDetails(
    List<Place> places,
    Set<String> committedIds,
    PlaceExploreProvider provider,
  ) {
    final selected = <PlaceDetail>[];
    final unselected = <PlaceDetail>[];
    for (final place in places) {
      final detail = provider.cachedDetail(place.id);
      if (detail == null) continue;
      if (committedIds.contains(place.id)) {
        selected.add(detail);
      } else {
        unselected.add(detail);
      }
    }
    return [...selected, ...unselected];
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Consumer<PlaceExploreProvider>(
      builder: (context, provider, _) {
        final orderedDetails = _orderedDetails(
          provider.places,
          provider.committedIds,
          provider,
        );

        return SizedBox.expand(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 0),
                child: const TripStepHeader(
                  step: 2,
                  totalSteps: 2,
                  title: '내가 선택한 장소',
                  subtitle: '장소를 탭해 최종 목록을 조정하세요.',
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: orderedDetails.length,
                  itemBuilder: (context, index) {
                    final detail = orderedDetails[index];
                    final isSelected =
                        provider.selectedIds.contains(detail.id);
                    return Opacity(
                      opacity: isSelected ? 1.0 : 0.4,
                      child: PlaceSelectCard(
                        detail: detail,
                        isSelected: isSelected,
                        onTap: () => context
                            .read<PlaceExploreProvider>()
                            .togglePlace(detail.id),
                      ),
                    );
                  },
                ),
              ),
              _buildBottomControls(context, provider, bottomPad),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    PlaceExploreProvider provider,
    double bottomPad,
  ) {
    final canProceed = provider.selectedIds.isNotEmpty;

    return Container(
      color: AppColors.neutralScale[0],
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.neutralScale[600],
                  ),
                  children: [
                    const TextSpan(text: '선택 장소 '),
                    TextSpan(
                      text: '${provider.selectedIds.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryScale[500],
                      ),
                    ),
                    const TextSpan(text: '곳'),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    context.read<PlaceExploreProvider>().resetToCommitted(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: AppColors.neutralScale[300],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '초기화하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.neutralScale[300],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '최소 3곳 이상 선택',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.neutralScale[300],
              ),
            ),
          ),
          const SizedBox(height: 12),
          NextButton(
            onPressed: canProceed
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('다음 화면 준비 중'),
                        duration: Duration(seconds: 2),
                      ),
                    )
                : null,
          ),
          const SizedBox(height: 10),
          PrevButton(onPressed: onPrev),
        ],
      ),
    );
  }
}
