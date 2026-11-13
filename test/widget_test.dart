import 'package:flutter_test/flutter_test.dart';

import 'package:maricklabs_profile/main.dart';

void main() {
  testWidgets('profile and pet navigation are available', (tester) async {
    await tester.pumpWidget(const FernandezProfileApp());

    expect(find.text('Fritz Marick A. Fernandez'), findsNWidgets(2));
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('My Pet'), findsOneWidget);

    await tester.tap(find.text('My Pet'));
    await tester.pumpAndSettle();

    expect(find.text('Leonardo DiCapybara'), findsOneWidget);
    expect(find.text('Play pet sound'), findsOneWidget);
  });

  testWidgets('Shelf has working My Picks, Books, and Movies tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const FernandezProfileApp());

    await tester.tap(find.text('Shelf'));
    await tester.pump();

    expect(find.text('My Shelf'), findsOneWidget);
    expect(find.text('My Picks'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);

    await tester.tap(find.text('Books'));
    await tester.pumpAndSettle();
    expect(find.text('Search books'), findsOneWidget);

    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Search movies'), findsOneWidget);
  });
}
