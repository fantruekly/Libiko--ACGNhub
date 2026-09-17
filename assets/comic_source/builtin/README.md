# Built-in comic sources

These `.js` files are vendored unmodified from
[`venera-app/venera-configs`](https://github.com/venera-app/venera-configs)
(branch `main`) and are installed by `BuiltinSourceInstaller`.

`index.json` records the bundled version and each source's name/key/version.
To update a source, replace its file and bump the manifest `version` so the
installer overwrites the copy in the app support directory.

**Licensing:** the upstream repository does not ship a LICENSE file; confirm
redistribution terms with the upstream project before shipping these files.
