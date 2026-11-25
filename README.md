# ELND

ELND is a card battle game where you collect anomalies, build decks and fight bots in real-time battles.

Built with Godot 4 for Android phones in portrait.

## Layout

- `data/` holds every game number as JSON. Admin Mode saves its edits to `user://overrides.json`, which is laid on top of these.
- `scenes/` holds the screens.
- `scripts/autoload/` holds the always-on systems: data, settings, save game and screen navigation.
- `scripts/ui/` and `scripts/util/` hold shared helpers.

## Builds

Every push to `testing` builds an APK you can download from the Actions run.
Every push to `main` builds `ELND.apk` and publishes it as a release.

Every build is signed with `android/release.keystore`, so new versions install over old ones.

## License

MIT
