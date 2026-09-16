# Projekt Xcode kopii wydaniowej

Otwórz `FindHub Android.xcodeproj`, schemat `FindHub Android`. Target i nazwa aplikacji to „FindHub Android”; techniczny moduł Swift to `FindHubAndroid`.

Pełne instrukcje i status znajdują się w [README głównym](../README.md). To odrębna kopia do przygotowania publikacji; istniejące logowanie i dostęp Google nie są jeszcze zatwierdzoną integracją produkcyjną.

Z katalogu `App`:

```bash
xcodegen generate
bash Scripts/test_regressions.sh
bash Scripts/test_journal.sh
```

Nie używaj komend instalacji ani Bundle ID z historycznej dokumentacji starego projektu. Zmiany wykonuj wyłącznie w tej kopii.
