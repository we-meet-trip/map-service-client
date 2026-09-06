class VisionLocation {
  final double lat;
  final double lng;
  const VisionLocation({required this.lat, required this.lng});
  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class VisionRequest {
  final String sessionId;
  final String frameB64;
  final bool voiceTriggered;
  final String? voiceText;
  final String? priorContext;
  final List<Map<String, String>> conversationHistory;
  final VisionLocation? location;

  const VisionRequest({
    required this.sessionId,
    required this.frameB64,
    this.voiceTriggered = false,
    this.voiceText,
    this.priorContext,
    this.conversationHistory = const [],
    this.location,
  });

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'frame_b64': frameB64,
    'voice_triggered': voiceTriggered,
    'voice_text': voiceText,
    'prior_context': priorContext,
    'conversation_history': conversationHistory,
    'location': location?.toJson(),
  };
}

class DetectedObject {
  final String label;
  final double confidence;
  final List<double> bbox;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.bbox,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) => DetectedObject(
    label: json['label'] as String,
    confidence: (json['confidence'] as num).toDouble(),
    bbox: List<double>.from(json['bbox'] as List),
  );
}

class IdentifyResult {
  final String name;
  final String category;
  final String description;
  final String searchQuery;

  const IdentifyResult({
    required this.name,
    required this.category,
    required this.description,
    required this.searchQuery,
  });

  factory IdentifyResult.fromJson(Map<String, dynamic> json) => IdentifyResult(
    name: json['name'] as String,
    category: json['category'] as String,
    description: json['description'] as String,
    searchQuery: json['search_query'] as String,
  );
}

class SearchResult {
  final String title;
  final String summary;
  final String source;
  final String? url;

  const SearchResult({
    required this.title,
    required this.summary,
    required this.source,
    this.url,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    title: json['title'] as String,
    summary: json['summary'] as String,
    source: json['source'] as String,
    url: json['url'] as String?,
  );
}

class VisionResponse {
  final String sessionId;
  final DetectedObject? detectedObject;
  final IdentifyResult? identifyResult;
  final List<SearchResult> searchResults;
  final String status;
  final String? error;

  const VisionResponse({
    required this.sessionId,
    this.detectedObject,
    this.identifyResult,
    this.searchResults = const [],
    required this.status,
    this.error,
  });

  bool get isSuccess => status == 'done' && error == null;

  factory VisionResponse.fromJson(Map<String, dynamic> json) => VisionResponse(
    sessionId: json['session_id'] as String,
    detectedObject: json['detected_object'] != null
        ? DetectedObject.fromJson(
            json['detected_object'] as Map<String, dynamic>,
          )
        : null,
    identifyResult: json['identify_result'] != null
        ? IdentifyResult.fromJson(
            json['identify_result'] as Map<String, dynamic>,
          )
        : null,
    searchResults: (json['search_results'] as List? ?? [])
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    status: json['status'] as String,
    error: json['error'] as String?,
  );
}
