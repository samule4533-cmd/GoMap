class CoordConverter {
  static double naverMapXToLng(String mapx) {
    final raw = double.parse(mapx);
    return raw / 1e7;
  }

  static double naverMapYToLat(String mapy) {
    final raw = double.parse(mapy);
    return raw / 1e7;
  }
}
