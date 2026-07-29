import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/address_search_screen.dart';
import '../../../common/widgets/app_confirm_dialog.dart';
import '../../../common/widgets/text_field.dart';
import '../../../core/state/trip_repository.dart';
import '../../../core/state/user_repository.dart';

class _RegisteredOrigin {
  final String name;
  final String address;
  const _RegisteredOrigin({required this.name, required this.address});
}

class TripDirectionsScreen extends StatefulWidget {
  const TripDirectionsScreen({super.key, this.savedTrip});

  final SavedTrip? savedTrip;

  @override
  State<TripDirectionsScreen> createState() => _TripDirectionsScreenState();
}

class _TripDirectionsScreenState extends State<TripDirectionsScreen> {
  int _originIndex = 1; // 0: 집, 1: 현재 위치, 2+i: 등록된 위치
  bool _loadingLocation = false;
  String? _currentLocationAddress;
  String? _homeAddress;
  final List<_RegisteredOrigin> _registeredOrigins = [];

  @override
  void initState() {
    super.initState();
    _homeAddress = UserRepository.instance.profile.value.homeAddress;
    _loadCurrentLocationAddress();
  }

  String get _originLabel {
    switch (_originIndex) {
      case 0:
        return _homeAddress ?? '출발지';
      case 1:
        if (_loadingLocation) return '위치 확인 중...';
        return _currentLocationAddress ?? '현재 위치를 확인할 수 없어요';
      default:
        final i = _originIndex - 2;
        if (i >= 0 && i < _registeredOrigins.length) {
          return _registeredOrigins[i].address;
        }
        return '출발지';
    }
  }

  Future<void> _onOriginChipTap(int index) async {
    setState(() => _originIndex = index);
    if (index == 1 && _currentLocationAddress == null && !_loadingLocation) {
      await _loadCurrentLocationAddress();
    } else if (index == 0 && _homeAddress == null) {
      await _registerHome();
    }
    // index >= 2 (등록된 위치)는 이미 주소가 있으므로 선택만 하면 된다.
  }

  Future<String?> _searchAddress() {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AddressSearchScreen(),
      ),
    );
  }

  Future<void> _registerHome() async {
    final address = await _searchAddress();
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _originIndex = 1);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏠 집으로 등록할까요?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralScale[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              address,
              style: TextStyle(fontSize: 14, color: AppColors.neutralScale[300]),
            ),
          ],
        ),
        cancelLabel: '아니요',
        confirmLabel: '등록하기',
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed == true && mounted) {
      UserRepository.instance.updateHomeAddress(address);
      setState(() => _homeAddress = address);
    } else if (mounted) {
      setState(() => _originIndex = 1);
    }
  }

  Future<void> _addNewOrigin() async {
    final address = await _searchAddress();
    if (address == null || address.isEmpty || !mounted) return;

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppConfirmDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📍 이름을 정해주세요.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                address,
                style: TextStyle(fontSize: 14, color: AppColors.neutralScale[300]),
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: nameController,
                hintText: '예: 회사, 학교',
                maxLength: 10,
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          cancelLabel: '취소',
          confirmLabel: '등록하기',
          onConfirm: nameController.text.trim().isNotEmpty
              ? () => Navigator.of(ctx).pop(nameController.text.trim())
              : null,
        ),
      ),
    );

    nameController.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      setState(() {
        _registeredOrigins.add(_RegisteredOrigin(name: name, address: address));
        _originIndex = 2 + _registeredOrigins.length - 1;
      });
    }
  }

  Future<void> _loadCurrentLocationAddress() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await _determinePosition();
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isEmpty) {
        throw Exception('No placemarks found');
      }
      final p = placemarks.first;
      final address = [p.administrativeArea, p.locality, p.subLocality, p.thoroughfare]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (!mounted) return;
      setState(() {
        _currentLocationAddress = address.isEmpty ? '현재 위치' : address;
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLocationAddress = '위치를 확인할 수 없어요';
        _loadingLocation = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('위치 서비스가 비활성화되어 있습니다.');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 10));
  }

  @override
  Widget build(BuildContext context) {
    final tripName = widget.savedTrip?.name ?? '저장된 일정';
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: AppColors.neutralScale[500]),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tripName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralScale[600],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '저장한 여정을 떠나는 방법을 알아보세요.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.tabBarUnselected,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _originLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tripAccentPurple,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildOriginChip('집', Icons.home_rounded, 0),
                            const SizedBox(width: 8),
                            _buildOriginChip('현재 위치', Icons.location_on, 1),
                            for (var i = 0; i < _registeredOrigins.length; i++) ...[
                              const SizedBox(width: 8),
                              _buildOriginChip(_registeredOrigins[i].name, Icons.place, 2 + i),
                            ],
                            const SizedBox(width: 8),
                            _buildAddChip(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSearchBox(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildBigCard(
                  title: '지하철',
                  subtitle: '가장 빠른 경로를 탐색해보세요',
                  image: 'assets/images/transport/train.png',
                  imageSize: 68,
                  imageRight: 26,
                ),
                const SizedBox(height: 12),
                _buildBigCard(
                  title: '버스',
                  subtitle: '실시간 버스 위치 확인해보세요',
                  image: 'assets/images/transport/tour_bus.png',
                  imageSize: 74,
                  imageRight: 20,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSmallCard(
                        title: '기차',
                        subtitle: '편리‧간편한 예매',
                        image: 'assets/images/transport/train2.png',
                        imageSize: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSmallCard(
                        title: '자전거‧킥보드',
                        subtitle: '가까운 단거리 이동',
                        image: 'assets/images/transport/bicycle_scooter.png',
                        imageSize: 48,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSmallCard(
                        title: '시외버스',
                        subtitle: '먼 곳까지 편하게',
                        image: 'assets/images/transport/intercity_bus.png',
                        imageSize: 47,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSmallCard(
                        title: '항공',
                        subtitle: '가성비 좋은 항공권',
                        image: 'assets/images/transport/plane.png',
                        imageSize: 46,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOriginChip(String label, IconData icon, int index) {
    return _buildChip(
      label: label,
      icon: icon,
      selected: _originIndex == index,
      onTap: () => _onOriginChipTap(index),
    );
  }

  Widget _buildAddChip() {
    return _buildChip(
      label: '등록',
      icon: Icons.add,
      selected: false,
      onTap: _addNewOrigin,
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tripOriginChipBg
              : AppColors.neutralScale[0],
          border: Border.all(
            color: selected
                ? AppColors.tripOriginChipBorder
                : AppColors.neutralScale[100]!,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 11,
                color: selected
                    ? AppColors.tripAccentPurple
                    : AppColors.neutralScale[300]),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.tripAccentPurple
                    : AppColors.neutralScale[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      width: 101,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.neutralScale[0]!.withAlpha(204),
        borderRadius: BorderRadius.circular(41),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryScale[900]!.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '검색',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.savedBadgeFar,
            ),
          ),
          const Spacer(),
          Icon(Icons.search, size: 17, color: AppColors.savedBadgeFar),
        ],
      ),
    );
  }

  Widget _buildBigCard({
    required String title,
    required String subtitle,
    required String image,
    required double imageSize,
    required double imageRight,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 81,
        decoration: BoxDecoration(
          color: AppColors.neutralScale[0],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryScale[900]!.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: imageRight,
              top: 15,
              child: Image.asset(image, width: imageSize, height: imageSize, fit: BoxFit.contain),
            ),
            Positioned(
              right: 16,
              top: 10,
              child: _buildFadeOverlay(width: 55, height: 62),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 90, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralScale[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.savedBadgeFar,
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

  Widget _buildSmallCard({
    required String title,
    required String subtitle,
    required String image,
    required double imageSize,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 81,
        decoration: BoxDecoration(
          color: AppColors.neutralScale[0],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryScale[900]!.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 16,
              top: (81 - imageSize) / 2,
              child: Image.asset(image, width: imageSize, height: imageSize, fit: BoxFit.contain),
            ),
            Positioned(
              right: 11,
              top: 13,
              child: _buildFadeOverlay(width: 37, height: 62),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 60, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralScale[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.savedBadgeFar,
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

  Widget _buildFadeOverlay({required double width, required double height}) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              AppColors.neutralScale[0]!,
              AppColors.neutralScale[0]!.withAlpha(0),
            ],
            stops: const [0.13, 0.70],
          ),
        ),
      ),
    );
  }
}
