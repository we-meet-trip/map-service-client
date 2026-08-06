import '../models/place_detail.dart';

const Map<String, PlaceDetail> mockPlaceDetails = {
  'p0': PlaceDetail(
    id: 'p0',
    name: '경복궁',
    address: '서울 종로구 사직로 161',
    category: '역사·문화',
    rating: 4.7,
    openingHours: '09:00 – 18:00 (화요일 휴무)',
    aiSummary:
        '조선왕조 최대 규모의 궁궐로, 근정전·경회루 등 웅장한 건축물과 함께 계절마다 다채로운 풍경을 선사합니다. '
        '한복 착용 시 무료입장 혜택이 있어 여행객에게 특히 인기가 높습니다.',
    blogReviews: [
      BlogReview(
        title: '경복궁 한복 체험 후기 – 봄 나들이 완벽 코스',
        blogName: '여행의 맛',
        date: '2025-04-12',
        snippet: '한복을 입고 경복궁을 거닐면 마치 조선 시대로 돌아간 듯한 느낌이에요. 근정전 앞 사진이 정말 예쁘게 나왔습니다.',
      ),
      BlogReview(
        title: '경복궁 야간개장, 별빛 아래 거니는 궁궐',
        blogName: '소소한 서울 기록',
        date: '2025-03-28',
        snippet: '야간 조명이 환상적입니다. 예약은 필수! 평일에도 금방 마감되니 미리 준비하세요.',
      ),
      BlogReview(
        title: '아이와 함께 경복궁 나들이',
        blogName: '두 아이 엄마의 여행일기',
        date: '2025-02-15',
        snippet: '어린이 무료입장이라 부담 없이 다녀왔어요. 국립민속박물관까지 같이 돌면 반나절 코스로 딱입니다.',
      ),
      BlogReview(
        title: '경복궁 왕실 음식 문화 체험 – 전통 과자 만들기',
        blogName: '문화 탐방 일지',
        date: '2025-01-20',
        snippet: '사전 예약 후 체험 프로그램에 참여했는데 전통 다과와 함께하는 시간이 정말 알찼습니다.',
      ),
      BlogReview(
        title: '경복궁 사진 명소 TOP5 총정리',
        blogName: '렌즈 속 서울',
        date: '2024-12-05',
        snippet: '근정전 정면, 경회루 반영, 향원정 등 포인트별 촬영 팁을 담았습니다. 황금시간대는 오전 10시!',
      ),
      BlogReview(
        title: '경복궁 근처 맛집과 함께하는 당일치기',
        blogName: '서울 미식 탐험대',
        date: '2024-11-18',
        snippet: '궁 관람 후 삼청동 방향으로 걸어가면 카페와 한식당이 즐비합니다. 제 추천 루트를 공유해요.',
      ),
      BlogReview(
        title: '겨울 경복궁 눈 내리던 날',
        blogName: '사계절 여행러',
        date: '2024-12-25',
        snippet: '눈 쌓인 경복궁은 또 다른 아름다움이 있어요. 추위를 무릅쓰고 간 보람이 있었습니다.',
      ),
    ],
  ),
  'p1': PlaceDetail(
    id: 'p1',
    name: '인사동',
    address: '서울 종로구 인사동길',
    category: '전통·쇼핑',
    rating: 4.4,
    openingHours: '매일 10:00 – 22:00',
    aiSummary:
        '전통 공예품, 갤러리, 찻집이 밀집한 서울의 문화 거리입니다. '
        '주말에는 쌈지길 마당 공연과 거리 예술가들의 퍼포먼스를 즐길 수 있어 볼거리가 풍성합니다.',
    blogReviews: [
      BlogReview(
        title: '인사동 쌈지길 쇼핑 완벽 가이드',
        blogName: '서울 구석구석',
        date: '2025-05-03',
        snippet: '나선형 건물 안을 돌며 독특한 소품 가게들을 구경하는 재미가 있어요. 기념품 사기에 최고입니다.',
      ),
      BlogReview(
        title: '인사동 전통 찻집 투어',
        blogName: '티 러버의 서울',
        date: '2025-03-15',
        snippet: '전통차와 함께하는 한옥 분위기의 카페들이 많아요. 특히 쌍화탕이 인상 깊었습니다.',
      ),
      BlogReview(
        title: '인사동 갤러리 호핑 – 무료 전시 즐기기',
        blogName: '예술 산책',
        date: '2025-01-30',
        snippet: '주말마다 다양한 무료 전시가 열려요. 사전에 갤러리 일정을 체크하고 가면 더 알찹니다.',
      ),
      BlogReview(
        title: '인사동에서 찾은 나만의 도자기',
        blogName: '핸드메이드 라이프',
        date: '2024-11-22',
        snippet: '장인이 만든 도자기 컵을 구매했는데 일상에서 쓸 때마다 여행이 떠오릅니다.',
      ),
      BlogReview(
        title: '인사동 길거리 음식 베스트',
        blogName: '먹부림 일기',
        date: '2024-10-10',
        snippet: '꿀타래, 전통 과자, 호떡까지. 길거리 음식만으로도 충분히 즐거운 인사동입니다.',
      ),
    ],
  ),
  'p2': PlaceDetail(
    id: 'p2',
    name: '북촌한옥마을',
    address: '서울 종로구 계동길 37',
    category: '역사·문화',
    rating: 4.5,
    openingHours: '상시 개방 (내부 시설 별도)',
    aiSummary:
        '조선 시대부터 이어진 한옥이 밀집한 주거 지역으로, 가회동 골목의 기와지붕 풍경이 압권입니다. '
        '주민들이 실제 거주하는 공간이므로 조용히 관람하는 예절이 필요합니다.',
    blogReviews: [
      BlogReview(
        title: '북촌한옥마을 골목 산책 코스',
        blogName: '서울 골목 탐험가',
        date: '2025-04-20',
        snippet: '8경 포인트를 따라 걸으면 정말 아름다운 사진을 찍을 수 있어요. 이른 아침이 한산하고 빛도 좋습니다.',
      ),
      BlogReview(
        title: '북촌한옥마을 한복 포토스팟 총정리',
        blogName: '한복 여행러',
        date: '2025-03-05',
        snippet: '가회동 31번지 골목이 최고의 포인트! 평일 오전을 노리면 붐비지 않아요.',
      ),
      BlogReview(
        title: '북촌 공방 체험 – 전통 매듭 만들기',
        blogName: '손으로 기억하는 여행',
        date: '2025-02-01',
        snippet: '2시간짜리 매듭 공방 체험을 했는데 완성된 노리개를 가져올 수 있어서 뿌듯했습니다.',
      ),
      BlogReview(
        title: '북촌에서 창덕궁까지 걸어서',
        blogName: '도보 여행 일기',
        date: '2024-12-15',
        snippet: '북촌에서 창덕궁까지 걸으면 약 15분. 두 곳을 묶어서 반나절 코스로 즐기기 딱 좋습니다.',
      ),
      BlogReview(
        title: '북촌한옥마을 주민 매너 지키기',
        blogName: '착한 여행자',
        date: '2024-11-01',
        snippet: '주민들이 거주하는 공간이니 조용히, 쓰레기는 꼭 챙겨야 해요. 서로 배려합시다!',
      ),
    ],
  ),
  'p3': PlaceDetail(
    id: 'p3',
    name: '청계천',
    address: '서울 종로구 청계천로 일대',
    category: '자연·산책',
    rating: 4.3,
    openingHours: '상시 개방',
    aiSummary:
        '도심 한가운데 흐르는 수변 산책로로 계절마다 다른 풍경을 즐길 수 있습니다. '
        '겨울 청계천 빛축제와 봄 벚꽃 시즌이 특히 인기이며, 광교에서 고산자교까지 약 5.8km를 걷는 코스가 대표적입니다.',
    blogReviews: [
      BlogReview(
        title: '청계천 빛축제 2024 후기',
        blogName: '서울 빛 이야기',
        date: '2024-12-20',
        snippet: '형형색색 조명이 물에 반사되는 모습이 장관이에요. 커플 데이트 코스로 최고입니다.',
      ),
      BlogReview(
        title: '청계천 봄 산책 – 개나리·벚꽃 가득',
        blogName: '봄을 걷는 사람',
        date: '2025-04-05',
        snippet: '청계천변에 봄꽃이 피면 정말 예뻐요. 점심시간에 직장인들도 많이 나와 활기찬 분위기입니다.',
      ),
      BlogReview(
        title: '청계천 전 구간 완주 도전기',
        blogName: '서울 트레킹 로그',
        date: '2025-01-10',
        snippet: '광교부터 고산자교까지 약 6km. 2시간 정도 소요되었고 중간에 쉴 수 있는 공간도 많습니다.',
      ),
      BlogReview(
        title: '청계천 근처 먹자골목 탐방',
        blogName: '점심 맛집 사냥꾼',
        date: '2024-09-15',
        snippet: '청계천 산책 후 을지로 먹자골목에서 점심 먹는 게 진짜 조합이에요.',
      ),
      BlogReview(
        title: '청계천 야경 사진 찍는 법',
        blogName: '야경 전문 포토그래퍼',
        date: '2024-08-22',
        snippet: '삼각대 없이도 스마트폰으로 예쁜 야경 찍는 법을 공유합니다. 반영 사진이 핵심!',
      ),
    ],
  ),
  'p4': PlaceDetail(
    id: 'p4',
    name: '남산서울타워',
    address: '서울 용산구 남산공원길 105',
    category: '관광·전망',
    rating: 4.6,
    openingHours: '10:00 – 23:00 (연중무휴)',
    aiSummary:
        '서울 도심 어디서나 보이는 랜드마크로, 전망대에서 360도 파노라마 서울 전경을 감상할 수 있습니다. '
        '사랑의 자물쇠와 한류 스타 포토존이 유명하며, 남산 케이블카를 타고 오르는 코스가 대표적입니다.',
    blogReviews: [
      BlogReview(
        title: '남산타워 야경 데이트 완벽 가이드',
        blogName: '서울 데이트 플래너',
        date: '2025-05-10',
        snippet: '해질녘에 올라가면 일몰과 야경을 동시에 즐길 수 있어요. 전망대 예약은 꼭 미리 하세요!',
      ),
      BlogReview(
        title: '남산 걸어 올라가기 도전 – 케이블카 없이!',
        blogName: '서울 걷기왕',
        date: '2025-03-22',
        snippet: '남산 순환버스 정류장에서 걸어 올라가면 약 30분. 운동도 되고 뷰도 좋아서 추천합니다.',
      ),
      BlogReview(
        title: 'N서울타워 한식 레스토랑 후기',
        blogName: '파인다이닝 탐방기',
        date: '2025-02-14',
        snippet: '전망 레스토랑에서 먹는 한정식은 뷰 덕에 더 맛있게 느껴집니다. 예약 필수!',
      ),
      BlogReview(
        title: '남산 사랑의 자물쇠 달기 – 낭만 체험',
        blogName: '커플 여행 스토리',
        date: '2024-11-29',
        snippet: '자물쇠에 이름 새기고 달았어요. 수백만 개의 자물쇠가 벽을 가득 채운 모습이 인상적입니다.',
      ),
      BlogReview(
        title: '남산타워 아이와 함께 – 체험 시설 총정리',
        blogName: '패밀리 여행 다이어리',
        date: '2024-10-05',
        snippet: '아이들이 좋아하는 체험 존과 기념품 가게가 다양해요. 주말엔 줄이 길 수 있으니 평일 방문 추천!',
      ),
    ],
  ),
  'p5': PlaceDetail(
    id: 'p5',
    name: '홍대입구',
    address: '서울 마포구 어울마당로 일대',
    category: '문화·엔터테인먼트',
    rating: 4.2,
    openingHours: '매일 12:00 – 익일 02:00',
    aiSummary:
        '홍익대학교 앞 예술·문화·클럽 문화의 중심지입니다. 다양한 공연, 벽화 골목, 독립 카페, 빈티지 숍이 밀집해 있어 '
        '젊은 감성의 트렌디한 여행지로 손꼽힙니다.',
    blogReviews: [
      BlogReview(
        title: '홍대 자유공원 버스킹 즐기기',
        blogName: '음악을 따라 걷다',
        date: '2025-05-18',
        snippet: '주말 저녁 자유공원에서 열리는 버스킹은 수준이 정말 높아요. 무료 공연을 즐길 수 있는 최고의 장소!',
      ),
      BlogReview(
        title: '홍대 독립 카페 투어 – 숨은 명소 5곳',
        blogName: '카페 투어러',
        date: '2025-04-02',
        snippet: '체인 카페 말고 독립 카페 위주로 돌았는데 인테리어도 커피도 모두 특색 있었습니다.',
      ),
      BlogReview(
        title: '홍대 빈티지 숍 쇼핑 가이드',
        blogName: '빈티지 패션 러버',
        date: '2025-02-28',
        snippet: '홍대 일대에 빈티지 옷가게만 수십 곳. 보물 찾는 재미가 있어요. 흥정도 가끔 됩니다!',
      ),
      BlogReview(
        title: '홍대 맛집 지도 2025년 업데이트',
        blogName: '홍대 단골 방문기',
        date: '2025-01-15',
        snippet: '새로 생긴 맛집들 위주로 정리했습니다. 줄 서는 라멘집과 수제 버거 가게가 핫합니다.',
      ),
      BlogReview(
        title: '홍대 클럽 데이 경험담',
        blogName: '나이트라이프 탐방',
        date: '2024-12-31',
        snippet: '연말 파티 분위기 최고였어요. 클럽마다 분위기가 달라서 여러 곳 돌아다니는 재미가 있습니다.',
      ),
    ],
  ),
  'p6': PlaceDetail(
    id: 'p6',
    name: '명동성당',
    address: '서울 중구 명동길 74',
    category: '역사·문화',
    rating: 4.5,
    openingHours: '06:00 – 21:00',
    aiSummary:
        '1898년 완공된 한국 천주교의 상징적 건물로, 고딕 양식의 웅장한 외관이 인상적입니다. '
        '성당 내부의 스테인드글라스와 조각 작품들을 감상할 수 있으며, 주변 명동 쇼핑가와 함께 방문하기 좋습니다.',
    blogReviews: [
      BlogReview(
        title: '명동성당 야경 – 도심 속 고딕의 아름다움',
        blogName: '서울 야경 컬렉터',
        date: '2025-04-25',
        snippet: '조명을 받은 명동성당은 낮과 전혀 다른 분위기예요. 명동 쇼핑 후 들러보기 좋습니다.',
      ),
      BlogReview(
        title: '명동성당 내부 스테인드글라스 감상',
        blogName: '건축 여행자',
        date: '2025-03-10',
        snippet: '내부에 들어가면 빛이 스테인드글라스를 통해 쏟아지는 모습이 경이롭습니다. 미사 시간 외에 관람 가능!',
      ),
      BlogReview(
        title: '명동성당과 명동 맛집 1일 코스',
        blogName: '도심 당일치기',
        date: '2025-01-25',
        snippet: '성당 관람 후 명동교자에서 칼국수, 이후 롯데백화점 쇼핑까지. 알차게 보냈습니다.',
      ),
      BlogReview(
        title: '크리스마스 명동성당 미사 후기',
        blogName: '신앙 여행 일기',
        date: '2024-12-25',
        snippet: '크리스마스 미사는 정말 감동적이에요. 성가대 노래와 함께하는 예배는 특별한 경험입니다.',
      ),
    ],
  ),
  'p7': PlaceDetail(
    id: 'p7',
    name: '광화문광장',
    address: '서울 종로구 세종대로 172',
    category: '역사·문화',
    rating: 4.4,
    openingHours: '상시 개방',
    aiSummary:
        '세종대왕상과 이순신 장군상이 자리한 서울의 중심 광장입니다. '
        '각종 문화 행사와 시즌별 이벤트가 열리며, 광장 아래 세종이야기·충무공이야기 전시관을 무료로 관람할 수 있습니다.',
    blogReviews: [
      BlogReview(
        title: '광화문광장 세종이야기 전시관 무료 관람',
        blogName: '문화 혜택 탐구자',
        date: '2025-05-01',
        snippet: '광장 지하에 있는 전시관을 무료로 들어갈 수 있어요. 아이와 함께 역사 공부하기 딱 좋습니다.',
      ),
      BlogReview(
        title: '광화문 광장 야경 포인트',
        blogName: '서울 야경 전문',
        date: '2025-03-01',
        snippet: '광화문 앞에서 경복궁이 보이는 야경이 특히 아름답습니다. 삼각대 챙겨가면 환상적인 사진 찍을 수 있어요.',
      ),
      BlogReview(
        title: '광화문 광장 페스타 참여 후기',
        blogName: '서울 행사 정보통',
        date: '2024-10-15',
        snippet: '주말마다 다양한 공연과 체험 행사가 열려요. 공식 행사 일정을 미리 체크하고 방문하면 좋습니다.',
      ),
      BlogReview(
        title: '광화문에서 경복궁까지 도보 탐방',
        blogName: '역사를 걷다',
        date: '2024-09-20',
        snippet: '광화문에서 경복궁까지 걸어가면 5분 거리. 두 곳을 묶어서 오전 코스로 활용하면 완벽합니다.',
      ),
    ],
  ),
  'p8': PlaceDetail(
    id: 'p8',
    name: '동대문디자인플라자',
    address: '서울 중구 을지로 281',
    category: '건축·디자인',
    rating: 4.3,
    openingHours: '10:00 – 21:00 (월요일 휴무)',
    aiSummary:
        '자하 하디드가 설계한 비정형 건축물로 세계 건축계에서도 주목받는 랜드마크입니다. '
        '디자인·패션·예술 전시가 상시 열리며, 독특한 외관 덕분에 사진 명소로도 유명합니다.',
    blogReviews: [
      BlogReview(
        title: 'DDP 건축 투어 – 자하 하디드의 걸작',
        blogName: '건축 덕후 노트',
        date: '2025-04-18',
        snippet: '외부를 한 바퀴 걸으면서 보는 것만으로도 충분히 감탄스럽습니다. 내부 전시까지 즐기면 금상첨화!',
      ),
      BlogReview(
        title: 'DDP 서울 패션위크 현장 스케치',
        blogName: '패션 피플 일기',
        date: '2025-03-25',
        snippet: '매년 열리는 서울 패션위크에서 다양한 디자이너 컬렉션을 무료로 관람했어요.',
      ),
      BlogReview(
        title: 'DDP 야경 사진 – 조명이 예술이다',
        blogName: '서울 포토 다이어리',
        date: '2025-02-20',
        snippet: '밤에 LED 조명으로 빛나는 DDP는 정말 환상적입니다. 넓은 광장에서 다양한 각도로 찍어보세요.',
      ),
      BlogReview(
        title: 'DDP 내부 전시 완벽 가이드',
        blogName: '전시 투어러',
        date: '2024-12-10',
        snippet: '유료 전시와 무료 공간이 섞여 있어요. 홈페이지에서 현재 전시 일정 확인 후 방문하세요.',
      ),
      BlogReview(
        title: 'DDP 팝업 스토어 쇼핑 후기',
        blogName: '팝업 헌터',
        date: '2024-11-05',
        snippet: '유명 브랜드 팝업이 DDP에 자주 열립니다. SNS로 미리 체크하면 득템 기회!',
      ),
    ],
  ),
  'p9': PlaceDetail(
    id: 'p9',
    name: '이태원',
    address: '서울 용산구 이태원로 일대',
    category: '문화·엔터테인먼트',
    rating: 4.1,
    openingHours: '매일 11:00 – 익일 02:00',
    aiSummary:
        '다양한 국적의 음식점과 독특한 편집샵, 갤러리가 모여 있는 서울의 다문화 거리입니다. '
        '경리단길·해방촌 등 인근 골목 탐방과 함께 즐기면 더욱 풍성한 하루를 보낼 수 있습니다.',
    blogReviews: [
      BlogReview(
        title: '이태원 세계 음식 투어 – 한 번에 세계를 맛보다',
        blogName: '글로벌 푸드 탐험가',
        date: '2025-05-05',
        snippet: '멕시코 타코, 레바논 케밥, 태국 쌀국수까지. 한 거리에서 세계 각국 음식을 즐길 수 있어요.',
      ),
      BlogReview(
        title: '경리단길 카페 & 편집샵 투어',
        blogName: '힙스터 서울 기록',
        date: '2025-04-10',
        snippet: '이태원에서 걸어서 15분 거리의 경리단길은 분위기 있는 카페와 독특한 가게들이 가득합니다.',
      ),
      BlogReview(
        title: '이태원 핼러윈 축제 현장',
        blogName: '축제 덕후',
        date: '2024-10-31',
        snippet: '이태원 핼러윈은 정말 특별한 경험이에요. 코스튬 완성도가 정말 놀랍습니다.',
      ),
      BlogReview(
        title: '이태원 앤틱 가구 거리 탐방',
        blogName: '인테리어 쇼핑러',
        date: '2024-09-08',
        snippet: '이태원 뒷길에 앤틱 가구 상점들이 즐비합니다. 합리적인 가격에 빈티지 가구를 구할 수 있어요.',
      ),
      BlogReview(
        title: '해방촌 골목 산책과 일몰 뷰',
        blogName: '서울 골목 크리에이터',
        date: '2024-08-15',
        snippet: '해방촌 언덕에서 보는 서울 일몰이 정말 예쁩니다. 계단 골목 카페에서 커피 한 잔과 함께 즐겨보세요.',
      ),
    ],
  ),
};
