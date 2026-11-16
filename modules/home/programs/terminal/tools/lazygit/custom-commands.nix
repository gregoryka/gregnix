# Custom commands for lazygit
# See: https://github.com/jesseduffield/lazygit/wiki/Custom-Commands-Compendium
[
  # GitHub integration
  {
    key = "V";
    context = "localBranches";
    loadingText = "Checking out GitHub Pull Request...";
    command = "gh pr checkout {{.Form.PullRequestNumber}}";
    description = "Checkout GitHub PR";
    prompts = [
      {
        type = "menuFromCommand";
        title = "Which PR do you want to check out?";
        key = "PullRequestNumber";
        command = "gh pr list --json number,title,headRefName,updatedAt --template '{{range .}}{{printf \"#%v: %s - %s (%s)\n\" .number .title .headRefName (timeago .updatedAt)}}{{end}}'";
        filter = "#(?P<number>[0-9]+): (?P<title>.+) - (?P<ref_name>[^ ]+).*";
        valueFormat = "{{.number}}";
        labelFormat = "{{\"#\" | black | bold}}{{.number | white | bold}} {{.title | yellow | bold}}{{\" [\" | black | bold}}{{.ref_name | green}}{{\"]\" | black | bold}}";
      }
    ];
  }

  # Branch cleanup
  {
    key = "<c-g>";
    context = "localBranches";
    command = "git fetch -p && for branch in $(git for-each-ref --format '%(refname) %(upstream:track)' refs/heads | awk '$2 == \"[gone]\" {sub(\"refs/heads/\", \"\", $1); print $1}'); do git branch -D $branch; done";
    description = "Prune local branches no longer on remote (gone)";
    loadingText = "Pruning gone branches...";
  }
  {
    key = "p";
    context = "remotes";
    command = "git remote prune {{.SelectedRemote.Name}}";
    description = "Prune deleted remote branches";
    loadingText = "Pruning...";
  }

  # Difftool
  {
    key = "f";
    context = "commitFiles";
    command = "git difftool -y {{.SelectedLocalCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
    description = "Compare (difftool) with local copy";
  }
]
