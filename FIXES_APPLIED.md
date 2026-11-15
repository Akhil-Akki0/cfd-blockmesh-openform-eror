# Fixes applied

## OpenFOAM v2606 error

The screenshot is a missing-runtime-dependency error, not a malformed case or a bad video. The application invokes native OpenFOAM executables such as `blockMesh`; if the backend process cannot find them after sourcing OpenFOAM's `etc/bashrc`, the mesh pipeline cannot start. `/healthz` only says the web server is alive, so it is not proof that the solver is ready.

The previous Dockerfile used `opencfd/openfoam-default:latest`. That tag currently points to v2512, while this application requires v2606. The Dockerfile now uses Ubuntu 24.04, adds the official OpenCFD Debian/Ubuntu repository, installs `openfoam2606-default`, pins `OPENFOAM_BASHRC` to `/usr/lib/openfoam/openfoam2606/etc/bashrc`, and checks the required solver binaries during the image build. The healthcheck uses `/readyz`, which now checks `blockMesh`, `snappyHexMesh`, `checkMesh`, `foamToVTK`, and `simpleFoam` and returns the names of missing binaries.
The production image also copies `public/`, which contains the initial walkthrough video, logo, and other media. Express now serves root-level public files (such as `/logo.png`) in production as Vite already does during development.

Run the solver-ready app with:

```sh
docker compose up --build
```

Then open `http://localhost:3000`. Confirm solver readiness with `curl -i http://localhost:3000/readyz`; success is HTTP 200 and an empty `missingBinaries` array.

If you run `npm run dev` directly on a host instead, that host still needs OpenFOAM v2606 installed and sourced; starting Node alone cannot provide the solver. The README contains the official install/source commands. Docker engine is not installed in the task environment, so the container build could not be executed here; the OpenCFD package repository was checked and offers the v2606 package for Ubuntu 24.04.

## Compose PID-limit compatibility

The Compose file now sets the 256-process limit only at `deploy.resources.limits.pids`; the separate `pids_limit` shorthand has been removed so Compose cannot reconcile two different values.
The explicit `container_name` was also removed so Compose can generate a project-scoped name instead of colliding with an existing global `cfd_hardened_backend` container.

## Previously fixed items retained

- Compose has no Nginx proxy; it maps the backend directly to port 3000.
- Dockerfile and compose ports remain aligned on 3000.
- The Run-page canvas animation is iframe-hosted, not an HTML `<video>`. The iframe wrapper fills its clipped viewport edge to edge, eliminating the prior uncovered bottom strip. This change is retained in the new project folder.
