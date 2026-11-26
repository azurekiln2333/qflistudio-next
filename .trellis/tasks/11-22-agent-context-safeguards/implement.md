# Implementation plan

1. Audit request accounting, streaming, skills and destructive file paths.
2. Freeze public context snapshot fields before UI wiring.
3. Implement R1 accounting, capacity metadata, composer preference and popup.
4. Implement R2 bounded Trellis bootstrap using existing project discovery.
5. Implement R3 shared configuration deletion policy at mutation boundaries.
6. Run targeted formatting and static analysis for each owner.
7. Review cross-layer data flow and protected parent/path-alias cases.
8. Run aggregate static analysis and staged diff checks.
9. Commit R1, R2 and R3 separately with explicit paths.
10. Record R4 streaming and dependency wiring evidence in closeout.

Root performs all index writes. Workers must not run runtime tests, builds,
services, devices, pushes or deployments. No credentials enter reports.
