# Design

Use iOS Documents/projects for new managed projects. Keep general iOS app data in Library/Application Support.

Persist iOS sandbox project paths relative to their durable root. Resolve these references before reading project metadata. Rebase legacy absolute paths that match the iOS container layout. Leave existing projects in place and retain their project IDs. Rebase supported recovery references before resolving files.

Enable file sharing and opening in place in Runner/Info.plist. Inspect the built Runner.app on GitHub Actions before producing the IPA.
