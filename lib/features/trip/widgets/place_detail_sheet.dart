import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/constants/category_tags.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/api/place_photo_api_service.dart';
import '../../../core/api/review_api_service.dart';

/// 장소 상세를 아래에서 올라오는 시트로 보여 준다.
///
/// [name] 은 장소명, [address] 는 주소, [category] 는 분류 칩에 쓴다.
/// 두 줄 요약은 이 시트를 열 때 서버에 물어 만든다. 일정 목록에는 요약을 싣지
/// 않는다 — 요약은 장소를 눌러 자세히 볼 때 필요한 정보다. 서버가 장소별로
/// 하루 동안 결과를 들고 있어 두 번째 클릭부터는 즉시 나온다.
///
/// 사진은 [latitude]·[longitude] 가 함께 올 때만 받아 온다. 이름만으로 찾으면
/// 같은 상호의 다른 동네 지점 사진이 오기 때문이다. 좌표가 없거나 사진을 못
/// 구하면 사진 영역째 접히므로, 늘 비어 있는 칸이 남지 않는다.
///
/// 별점·영업시간은 화면에 두지 않는다. 지금 쓰는 장소 출처가 그 값을 주지
/// 않아서, 자리를 만들어 두면 늘 비어 있는 칸이 남는다.
Future<void> showPlaceDetailSheet(
  BuildContext context, {
  required String name,
  required String address,
  String? category,
  double? latitude,
  double? longitude,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlaceDetailSheet(
      name: name,
      address: address,
      category: category,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}

class _PlaceDetailSheet extends StatefulWidget {
  const _PlaceDetailSheet({
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String address;
  final String? category;
  final double? latitude;
  final double? longitude;

  @override
  State<_PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<_PlaceDetailSheet> {
  /// 처음 보여 주는 후기 수.
  static const _firstPageSize = 2;

  /// 더보기를 누를 때마다 늘리는 수. 첫 더보기에서 앞의 2건에 3건을 더해 5건이
  /// 되고, 그 뒤로는 5건씩 늘어난다.
  static const _morePageSize = 5;

  /// 사진 목록의 높이와 타일 폭.
  static const _photoStripHeight = 140.0;
  static const _photoTileWidth = 180.0;

  final _api = ReviewApiService.instance;
  final _photoApi = PlacePhotoApiService.instance;

  List<String> _bullets = const [];
  bool _summaryLoading = false;

  List<PlacePhoto> _photos = const [];

  final List<BlogReview> _reviews = [];
  bool _reviewsLoading = true;
  bool _moreLoading = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadPhotos();
    _loadFirstPage();
  }

  /// 사진을 받아 온다. 좌표가 없으면 아예 요청하지 않는다 — 이름만으로 찾은
  /// 사진은 다른 동네 지점의 것일 수 있고, 서버 쪽 조회에도 비용이 든다.
  Future<void> _loadPhotos() async {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null) return;
    final photos = await _photoApi.fetchPhotos(
      widget.name,
      latitude: lat,
      longitude: lng,
    );
    if (!mounted || photos.isEmpty) return;
    setState(() => _photos = photos);
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryLoading = true);
    final bullets = await _api.fetchSummary(widget.name);
    if (!mounted) return;
    setState(() {
      _bullets = bullets;
      _summaryLoading = false;
    });
  }

  Future<void> _loadFirstPage() async {
    final page = await _api.fetchReviews(
      widget.name,
      start: 1,
      display: _firstPageSize,
    );
    if (!mounted) return;
    setState(() {
      _reviews
        ..clear()
        ..addAll(page.reviews);
      _hasMore = page.hasMore;
      _reviewsLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_moreLoading) return;
    setState(() => _moreLoading = true);
    // 첫 더보기는 5건까지 채우고, 그 뒤로는 5건씩 더 받는다.
    final target = _reviews.length < _morePageSize
        ? _morePageSize - _reviews.length
        : _morePageSize;
    final page = await _api.fetchReviews(
      widget.name,
      start: _reviews.length + 1,
      display: target,
    );
    if (!mounted) return;
    setState(() {
      _reviews.addAll(page.reviews);
      _hasMore = page.hasMore;
      _moreLoading = false;
    });
  }

  Future<void> _openLink(String link) async {
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tag = tagForCategory(widget.category);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutralScale[100],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
            if (widget.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.address,
                style: TextStyle(
                    fontSize: 13, color: AppColors.neutralScale[400]),
              ),
            ],
            if (tag != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryScale[50],
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryScale[500],
                    ),
                  ),
                ),
              ),
            ],
            _buildPhotos(),
            const SizedBox(height: 24),
            _buildSummary(),
            const SizedBox(height: 24),
            _buildReviews(),
          ],
        ),
      ),
    );
  }

  /// 사진을 크게 본다.
  ///
  /// 제공자 표기와 원본 링크는 이 화면에 둔다. 작은 타일 위에 겹쳐 쓰면
  /// 사진이 가려지고 글자도 읽히지 않는다.
  void _openPhotoViewer(int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PhotoViewer(
        photos: _photos,
        initialIndex: index,
        onOpenLink: _openLink,
      ),
    );
  }

  /// 사진 영역. 사진을 못 구했으면 영역째 접는다.
  Widget _buildPhotos() {
    if (_photos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('사진',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('제공: Google',
                style: TextStyle(
                    fontSize: 11, color: AppColors.neutralScale[300])),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _photoStripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _PhotoTile(
              photo: _photos[i],
              width: _photoTileWidth,
              onTap: () => _openPhotoViewer(i),
            ),
          ),
        ),
      ],
    );
  }

  /// 요약 영역. 근거를 못 구했으면 영역째 접는다.
  Widget _buildSummary() {
    if (_summaryLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_bullets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome,
                size: 18, color: AppColors.primaryScale[400]),
            const SizedBox(width: 6),
            const Text('AI 리뷰 요약',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryScale[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryScale[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in _bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.neutralScale[600]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 블로그 후기 목록과 더보기.
  Widget _buildReviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('블로그 리뷰',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_reviewsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('아직 등록된 후기가 없어요.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.neutralScale[300])),
          )
        else
          for (final review in _reviews) _ReviewCard(
            review: review,
            onTap: () => _openLink(review.link),
          ),
        if (_hasMore && !_reviewsLoading) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: _moreLoading ? null : _loadMore,
              icon: _moreLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              label: const Text('블로그 리뷰 더보기'),
            ),
          ),
        ],
      ],
    );
  }
}

/// 목록에 걸리는 사진 한 장. 누르면 크게 본다.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.width,
    required this.onTap,
  });

  final PlacePhoto photo;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: Image.network(
            photo.photoUri,
            fit: BoxFit.cover,
            // 웹에서는 그림을 캔버스에 직접 그리는데, 다른 출처의 이미지는
            // 그쪽이 허용 헤더를 주지 않으면 캔버스에 올릴 수 없다. 그럴 때는
            // 브라우저 이미지 요소로 대신 그리게 두어 사진이 통째로 사라지지
            // 않게 한다.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const _PhotoPlaceholder(),
            errorBuilder: (_, _, _) =>
                const _PhotoPlaceholder(failed: true),
          ),
        ),
      ),
    );
  }
}

/// 사진을 아직 못 받았거나 못 그렸을 때 자리를 지키는 회색 칸.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutralScale[100],
      alignment: Alignment.center,
      child: failed
          ? Icon(Icons.broken_image_outlined,
              size: 22, color: AppColors.neutralScale[200])
          : const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
    );
  }
}

/// 사진을 크게 보는 화면.
///
/// 좌우로 넘겨 가며 보고, 아래에 지금 보고 있는 사진의 제공자 표기와 원본
/// 링크를 함께 둔다. 목록 타일에는 표기를 겹치지 않는 대신 여기서 반드시
/// 보이게 한다.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onOpenLink,
  });

  final List<PlacePhoto> photos;
  final int initialIndex;
  final Future<void> Function(String link) onOpenLink;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    widget.photos[i].photoUri,
                    fit: BoxFit.contain,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white38),
                                ),
                              ),
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 40, color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ),
            _buildAttribution(photo),
          ],
        ),
      ),
    );
  }

  /// 제공자 표기와 원본 링크. 이름만 있는 제공자는 링크 없이 이름만 건다.
  ///
  /// 보여 줄 표기도 원본 링크도 없으면 영역째 접는다. 그대로 두면 사진 아래에
  /// 빈 여백만 남는다.
  Widget _buildAttribution(PlacePhoto photo) {
    final names = photo.attributions;
    if (names.isEmpty && photo.googleMapsUri == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (names.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('사진 제공',
                    style: TextStyle(fontSize: 12, color: Colors.white54)),
                for (final a in names)
                  GestureDetector(
                    onTap: a.uri == null
                        ? null
                        : () => widget.onOpenLink(a.uri!),
                    child: Text(
                      a.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        decoration: a.uri == null
                            ? TextDecoration.none
                            : TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          if (photo.googleMapsUri != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => widget.onOpenLink(photo.googleMapsUri!),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Google 지도에서 보기',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white)),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded,
                      size: 13, color: Colors.white),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 후기 한 건. 누르면 원문으로 이동한다.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onTap});

  final BlogReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      review.bloggerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (review.title.isNotEmpty) ...[
                    Text('  |  ',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.neutralScale[200])),
                    Expanded(
                      flex: 2,
                      child: Text(
                        review.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                review.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.neutralScale[500]),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(review.displayDate,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.neutralScale[300])),
                  Row(
                    children: [
                      Text('더보기',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryScale[500])),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppColors.primaryScale[500]),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
