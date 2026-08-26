# blobatar_example

The demo app for [`blobatar`](../), the Flutter port of
[blobatar](https://github.com/Alain00/blobatar).

Left alone it walks the fourteen expressions on its own, one every 1.3s, and
stops the moment you pick one yourself. Type a seed to see it render, and
below sits a grid chosen so all ten silhouettes are on screen at once — `round`,
`organic`, `boxy`, `capsule`, `nub`, `cloud`, `droplet`, `hexagon`, `sun` and
`triangle` — fifteen seeds, three full rows. `roberto` and `roberta` sit next
to each other on purpose: one
letter apart, and they do not even land on the same silhouette — one is
`organic`, the other `nub`.

`thinking` is the only expression that rocks the eyes, so it needs `animate`
set to see anything move.

## Running it

```bash
flutter run                       # whatever device is attached
flutter run -d chrome             # web
flutter run -d <simulator-id>     # iOS — `flutter devices` lists them
```

Hot reload (`r`) works on the library too, so this is the fastest way to see a
change to the painter.

## Widget previews

```bash
flutter widget-preview start
```

Renders the whole visual vocabulary side by side without launching the app —
all ten silhouettes, all fourteen expressions, the four backdrops, and the
`roberto`/`roberta` pair that shows the hash's avalanche. Defined in
`lib/previews.dart`. Your IDE shows the same thing in its Flutter Widget
Preview tab.
