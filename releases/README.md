# Release builds

Finished **Release** builds of Comunicator go here after you run:

```bash
./scripts/build-release.sh
```

| Artifact | Description |
|---|---|
| `Comunicator.app` | macOS application bundle |
| `Comunicator.zip` | Same app, zipped for sharing |

These binaries are **gitignored** so the repo stays source-only. Attach the zip to a [GitHub Release](https://docs.github.com/en/repositories/releasing-projects-on-github) when you publish a version.

**Note:** Without Apple Developer ID notarization, other Macs need Right-click → Open (see root README).
