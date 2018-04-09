# package-live-reload

This is an Atom service that reloads Atom packages when a file changes.

**It only works in dev mode.**

In the `package.json` of your package:

```json
"consumedServices": {
  "package-live-reload": {
    "v1.0.1": {
      "^1.0.0": "consumeLiveReload"
    }
  }
}
```

In the main module of your package:

```coffee
exports.consumeLiveReload = (watch) ->
  watch 'my-package',
    include: ['lib/**/*.coffee', 'package.json']
```

For your package to be reloaded on changes, it must be open
in the tree view.

If you open an active package in the tree view, and that
package consumes the `package-live-reload` service,
it will be watched automatically.

But if you make a package consume the service while it's
active, you must either disable/re-enable it from the
settings **or** run the `Package Live Reload : Refresh`
command from the command palette. Otherwise, the package
will not be watched.

### Install

```sh
cd ~/.atom/packages
git clone --depth=1 https://github.com/aleclarson/package-live-reload#1.0.0
```

You must install [wch](https://npmjs.org/package/wch) too.

```sh
npm i -g wch
wch start
```
