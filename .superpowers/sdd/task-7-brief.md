### Task 7: Create common UI widgets

**Files:**
- Create: `lib/core/widgets/work_card.dart`
- Create: `lib/core/widgets/loading_widget.dart`
- Create: `lib/core/widgets/error_widget.dart`

**Interfaces:**
- Consumes: `Work` (Task 2), `cached_network_image`
- Produces: `WorkCard`, `AppLoadingWidget`, `AppErrorWidget` widgets

- [ ] **Step 1: Create directory**

```bash
mkdir -p lib\core\widgets
```

- [ ] **Step 2: Write WorkCard widget**

Create `lib/core/widgets/work_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;
  final double width;
  final double imageHeight;

  const WorkCard({
    super.key,
    required this.work,
    this.onTap,
    this.width = 150,
    this.imageHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: width,
                height: imageHeight,
                child: work.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: work.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey[800]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.grey, size: 48),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              work.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (work.sourceName.isNotEmpty)
              Text(
                work.sourceName,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write LoadingWidget and ErrorWidget**

Create `lib/core/widgets/loading_widget.dart`:

```dart
import 'package:flutter/material.dart';

class AppLoadingWidget extends StatelessWidget {
  final String? message;
  const AppLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
```

Create `lib/core/widgets/error_widget.dart`:

```dart
import 'package:flutter/material.dart';

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('閲嶈瘯')),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/
git commit -m "feat(core): add common UI widgets WorkCard, LoadingWidget, ErrorWidget"
```

---


