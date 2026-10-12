---
paths:
  - ".zsh.addons/.zsh.find"
  - ".zsh.addons/.zsh.navigation"
  - "tests/directory_*"
  - "tests/files_*"
  - "tests/file_*"
  - "tests/folder_*"
  - "tests/search_*"
  - "tests/find_test.zsh"
  - "tests/navigation_*"
---

Browse, Search descendants, Recents and file actions are specified in
`engineering/workspaces/filesystem.md`; Browse and the Tab/Option-Tab entries
live in `.zsh.addons/.zsh.editor`, search providers in `.zsh.find`, Recents in
`.zsh.navigation`. Discovery runs only on explicit submission; by default
selection inserts a path, and only an explicit action changes directory.
Nothing selected is ever executed as code.
