import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:map_service_client/core/state/user_repository.dart';
import 'package:map_service_client/data/local/profile_local_store.dart';

/// 로그인한 사람의 이름이 화면에 나오게 하는 규칙을 확인한다.
///
/// 이 규칙이 없던 동안은 가입 화면을 거친 사용자만 이름을 갖고 있어서, 이미
/// 있는 계정으로 로그인하면 홈과 마이페이지가 계속 기본 이름을 보여 줬다.
void main() {
  setUpAll(() async {
    // 보관소가 값이 바뀔 때마다 기기에 적으므로 저장 공간이 있어야 한다.
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('map_profile_test');
    Hive.init(dir.path);
    await ProfileLocalStore.init();
  });

  setUp(() {
    UserRepository.instance.profile.value = UserProfile.empty();
  });

  group('보여 줄 이름', () {
    test('이름이 없으면 기본 이름을 쓴다', () {
      expect(UserProfile.empty().displayName, '여행자');
    });

    test('이름이 있으면 그 이름을 그대로 쓴다', () {
      final profile = UserProfile.empty().copyWith(nickname: 'maptester1');
      expect(profile.displayName, 'maptester1');
    });
  });

  group('계정 정보 반영', () {
    test('서버에서 받은 이름이 화면용 프로필에 들어간다', () {
      UserRepository.instance.applyAccount(nickname: 'maptester1');

      expect(UserRepository.instance.profile.value.displayName, 'maptester1');
    });

    test('이름만 아는 단계에서 나머지 항목을 지우지 않는다', () {
      UserRepository.instance.applyAccount(
        nickname: 'maptester1',
        gender: '남성',
        interests: const ['맛집'],
      );

      // 로그인 응답에는 이름만 실려 온다. 이때 나머지를 함께 덮어쓰면
      // 이미 받아 둔 취향이 사라진다.
      UserRepository.instance.applyAccount(nickname: 'maptester2');

      final profile = UserRepository.instance.profile.value;
      expect(profile.nickname, 'maptester2');
      expect(profile.gender, '남성');
      expect(profile.interests, ['맛집']);
    });

    test('빈 이름은 이미 있는 이름을 밀어내지 않는다', () {
      UserRepository.instance.applyAccount(nickname: 'maptester1');

      UserRepository.instance.applyAccount(nickname: '');

      expect(UserRepository.instance.profile.value.nickname, 'maptester1');
    });
  });

  group('로그아웃 정리', () {
    test('계정에서 온 항목만 비우고 기기에서 정한 항목은 남긴다', () {
      UserRepository.instance.applyAccount(
        nickname: 'maptester1',
        email: 'maptester1@admin.map',
        gender: '남성',
        interests: const ['맛집'],
        themes: const ['힐링'],
      );
      UserRepository.instance.updateProfileImage('/tmp/face.png');
      UserRepository.instance.updateHomeAddress('서울시 어딘가');

      UserRepository.instance.clearAccount();

      final profile = UserRepository.instance.profile.value;
      expect(profile.displayName, '여행자', reason: '다음 사람에게 옛 이름을 보이면 안 된다');
      expect(profile.email, isNull);
      expect(profile.gender, isNull);
      expect(profile.interests, isEmpty);
      expect(profile.themes, isEmpty);
      expect(profile.profileImagePath, '/tmp/face.png', reason: '기기에서 고른 사진이다');
      expect(profile.homeAddress, '서울시 어딘가', reason: '계정과 무관한 기기 설정이다');
    });
  });
}
