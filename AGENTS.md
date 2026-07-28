# Agent instructions

## Deploy / production safety

- **Never hot-patch production** (no `scp` / `docker cp` / live container edits, no live SQL or config rewrites on prod) unless the user **explicitly** asks for a production hot-patch in that message.
