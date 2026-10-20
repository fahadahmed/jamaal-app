Closes #

## What and why


## How to test it


## Release checks
- [ ] **Data model changed?** If a model or field was added or changed, the CloudKit schema must be deployed to **Production** before the next tag (see `docs/roadmap/release-process.md`). Changes must be additive.
- [ ] **Users will notice?** If so, add a line to `TestFlight/WhatToTest.en-US.txt`.
