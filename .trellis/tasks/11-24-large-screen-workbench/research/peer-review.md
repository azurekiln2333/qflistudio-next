# Four-Pi planning review

The existing Pi peers in Herdr workspace w37 were reused. No implementation
was dispatched. They were instructed not to run product tests or edit product
files. Read limits did not reliably prevent repeated exploration. The parent
ended those loops and used directly inspected source as the design authority.

## A — w37:pC

The upstream model returned HTTP 524 during its first attempt. Its later
recommendation to reuse the retained controller is consistent with source.
Its suggested 900dp family gate and Flutter DragTarget for Explorer drops are
not adopted. Width does not determine the required device family, and a Dart
DragTarget alone does not implement OS directory drag intake.

## B — w37:p14

The useful seam is ProjectStore.addExisting. The parent verified its source at
lib/store/project_store.dart:584–650. It registers but does not open an editor.
The recommendation to reject all UNC paths is unsupported and not adopted.
The parent verified the Windows qflistudio/platform channel in
windows/runner/flutter_window.cpp. No native folder drop handler exists there.
Windows directories do not need Apple external-folder bookmarks.

## C — w37:pG

The first reply incorrectly denied lib/layout/breakpoints.dart and suggested
mouse-presence classification. These claims are rejected. The second attempt
hit HTTP 524. The parent's design separates device family from window width.
Android tablet classification remains a documented heuristic. Exact native
API availability must be checked against the project's SDK before code lands.

## D — w37:pJ

Useful acceptance cases: direct workbench launch, one visible sidebar,
retained dirty text/cursor/drafts, in-place project selection, folder drop.
Its statement that all existing listed tests assert pushed editor routes is
not established. Preserve their actual behavior assertions instead.
Its one-editor count must be per project/session, not a global widget count:
the retained host legitimately holds inactive projects offstage.

## Later user clarification

Desktop/tablet removes the separate project-list navigation layer. Phone keeps
project-list → editor. GitHub repositories become a Home tab after connection.
GitHub connection management moves to Profile. Desktop/tablet avatar belongs
at the bottom left. These requirements supersede earlier tentative layouts.

## Evidence limits

No product execution, simulator, local probe or local test was used for this
planning task. Official native web lookups returned no usable content. The
design does not treat those lookups as verification. Cloud builds and actual
device acceptance are still required after implementation.
