import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../core/api/kakao_address_service.dart';
import 'back_header.dart';
import 'text_field.dart';

/// 카카오 주소 검색 API로 도로명주소를 검색하는 화면.
/// 주소 선택(확인) 시 해당 주소 문자열을 반환하며, 취소되면 null.
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _controller = TextEditingController();
  List<KakaoAddressResult> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? _]) async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await KakaoAddressService.instance.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '주소 검색에 실패했어요. 다시 시도해주세요.';
        _loading = false;
      });
    }
  }

  void _onSelect(KakaoAddressResult result) {
    context.pop(result.displayAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(title: '주소 검색', onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      hintText: '도로명, 지역명 등으로 검색',
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.search, color: AppColors.neutralScale[400]),
                    onPressed: _search,
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(_error!, style: TextStyle(color: AppColors.neutralScale[400])),
              )
            else if (_searched && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('검색 결과가 없어요.', style: TextStyle(color: AppColors.neutralScale[400])),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _results.length,
                  separatorBuilder: (_, index) => Divider(
                    height: 1,
                    color: AppColors.neutralScale[100],
                  ),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        r.displayAddress,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutralScale[600],
                        ),
                      ),
                      subtitle: r.roadAddress.isNotEmpty && r.jibunAddress.isNotEmpty
                          ? Text(
                              r.jibunAddress,
                              style: TextStyle(fontSize: 12, color: AppColors.neutralScale[300]),
                            )
                          : null,
                      onTap: () => _onSelect(r),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
