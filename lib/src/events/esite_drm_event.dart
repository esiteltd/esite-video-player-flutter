enum ESiteDrmEventType { licenseRequested, licenseAcquired, licenseFailed }

class ESiteDrmEvent {
  final ESiteDrmEventType type;
  final String? message;

  const ESiteDrmEvent({required this.type, this.message});
}
