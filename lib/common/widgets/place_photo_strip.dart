import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../../core/api/place_photo_api_service.dart';

/// 장소 사진 가로 목록. 누르면 크게 본다.
///
/// 제목과 제공자 표기는 여기에 두지 않는다. 큰 사진과 이 목록이 한 덩어리로
/// 걸리는데 각자 표기를 달면, 사진이 한 장뿐이라 목록이 비는 순간 표기까지
/// 함께 사라진다. 표기는 두 자리를 아우르는 쪽에서 한 번만 단다.
///
/// 걸 사진이 없으면 영역째 접는다.
class PlacePhotoStrip extends StatelessWidget {
  const PlacePhotoStrip({
    super.key,
    required this.photos,
    this.stripHeight = 140,
    this.tileWidth = 180,
  });

  final List<PlacePhoto> photos;
  final double stripHeight;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _PhotoTile(
          photo: photos[i],
          width: tileWidth,
          onTap: () => _openViewer(context, i),
        ),
      ),
    );
  }

  /// 제공자 표기와 원본 링크는 크게 보는 화면에 둔다. 작은 타일 위에 겹쳐 쓰면
  /// 사진이 가려지고 글자도 읽히지 않는다.
  void _openViewer(BuildContext context, int index) =>
      showPlacePhotoViewer(context, photos, index);
}

/// 사진 한 장을 크게 거는 자리.
///
/// [loading] 인 동안에는 사진이 없어도 자리를 지킨다 — 이 칸이 없다가 생기면
/// 사진이 도착하는 순간 시트 높이가 달라져 화면이 한 번 튄다. 다만 받을 것이
/// 없다고 판명된 뒤까지 빈 칸을 남기지는 않는다. 그 판단은 부르는 쪽이 하며,
/// 여기서는 받은 상태를 그대로 그린다.
class PlacePhotoHero extends StatelessWidget {
  const PlacePhotoHero({
    super.key,
    required this.photos,
    this.loading = false,
    this.height = 180,
  });

  final List<PlacePhoto> photos;

  /// 아직 조회 중인지. 사진이 없을 때 돌아가는 표시를 둘지 가른다.
  final bool loading;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: photos.isEmpty
            ? _PhotoPlaceholder(loading: loading)
            : Semantics(
                button: true,
                label: '장소 사진. 누르면 크게 봅니다',
                child: GestureDetector(
                onTap: () => showPlacePhotoViewer(context, photos, 0),
                child: Image.network(
                  photos.first.photoUri,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const _PhotoPlaceholder(),
                  errorBuilder: (_, _, _) =>
                      const _PhotoPlaceholder(failed: true),
                ),
              ),
              ),
      ),
    );
  }
}

/// 사진을 크게 보는 화면을 띄운다. 목록 타일과 큰 사진 자리가 같이 쓴다.
void showPlacePhotoViewer(
  BuildContext context,
  List<PlacePhoto> photos,
  int initialIndex,
) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _PhotoViewer(photos: photos, initialIndex: initialIndex),
  );
}

Future<void> _openLink(String link) async {
  if (link.isEmpty) return;
  final uri = Uri.tryParse(link);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    return Semantics(
      button: true,
      label: '장소 사진. 누르면 크게 봅니다',
      child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: Image.network(
            photo.photoUri,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            // 웹에서는 그림을 캔버스에 직접 그리는데, 다른 출처의 이미지는
            // 그쪽이 허용 헤더를 주지 않으면 캔버스에 올릴 수 없다. 그럴 때는
            // 브라우저 이미지 요소로 대신 그리게 두어 사진이 통째로 사라지지
            // 않게 한다.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const _PhotoPlaceholder(),
            errorBuilder: (_, _, _) => const _PhotoPlaceholder(failed: true),
          ),
        ),
      ),
      ),
    );
  }
}

/// 사진을 아직 못 받았거나 못 그렸을 때 자리를 지키는 회색 칸.
///
/// 내려받는 중에만 돌아가는 표시를 둔다. 받을 것이 없는데 계속 돌리면 곧 올
/// 것처럼 보이고, 화면이 멈추기를 기다리는 검사도 끝나지 않는다.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.failed = false, this.loading = true});

  final bool failed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutralScale[100],
      alignment: Alignment.center,
      // 그림만 있는 칸은 읽어 줄 글이 없어 화면 낭독기에 아무것도 안 들린다.
      child: Semantics(
        label: failed
            ? '사진을 표시하지 못했어요'
            : loading
                ? '사진을 불러오는 중'
                : '사진 없음',
        child: failed
          ? Icon(Icons.broken_image_outlined,
              size: 22, color: AppColors.neutralScale[200])
          : loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(PhosphorIcons.image(),
                  size: 40, color: AppColors.neutralScale[300]),
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
  });

  final List<PlacePhoto> photos;
  final int initialIndex;

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
                                      strokeWidth: 2, color: Colors.white38),
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
                    onTap: a.uri == null ? null : () => _openLink(a.uri!),
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
              onTap: () => _openLink(photo.googleMapsUri!),
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
                  Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
