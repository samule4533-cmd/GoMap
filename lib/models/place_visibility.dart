enum PlaceVisibility {
  private('private'),
  friends('friends'),
  selectedFriends('selected_friends'),
  public('public');

  const PlaceVisibility(this.dbValue);

  final String dbValue;

  static PlaceVisibility fromDb(String value) => values.firstWhere(
        (v) => v.dbValue == value,
        orElse: () => PlaceVisibility.private,
      );
}
