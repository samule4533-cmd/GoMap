import 'package:flutter/material.dart';
import '../../../models/naver_place.dart';

class PlaceBottomSheet extends StatelessWidget {
  const PlaceBottomSheet({super.key, required this.place});

  final NaverPlace place;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (place.address != null) Text(place.address!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
