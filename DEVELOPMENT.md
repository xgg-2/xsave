# Development

`saveinstance.luau` is generated from `src/` by `build.py` (listed order in `manifest.txt`). Edit `src/`, then:

```bash
python build.py          # rebuild
python build.py --check  # verify it is up to date
```

Pushing changes under `src/` to `main` rebuilds and commits the file through GitHub Actions.

`tools/` holds the scripts that regenerate the property and class tables when Roblox changes. The Python ones run anywhere (`pip install requests`, then `python "Run Dumpers.py"`); the `.luau` ones run inside a game with an executor. `tools/diagnostics.luau` checks an executor for everything xsave needs.
