class GitHubPRDownloadStrategy < GitHubGitDownloadStrategy
  # A custom download strategy class that can work with revisions that are not in
  # the default fetch refs, in particular revisions (commits) that are in PRs.
  # The trick is to explicitly `git fetch` the particular revision when needed.
  def initialize(url, name, version, **meta)
    super
    @revision_fetched = false
  end

  def fetch_revision(revision, timeout: nil)
    if @revision_fetched
      return
    end
    ohai "Fetching PR revision #{revision}"
    command! "git",
     args: [ "fetch", "origin", revision ],
     chdir: cached_location,
     timeout: Utils::Timer.remaining(timeout)
    @revision_fetched = true
  end

  def checkout(timeout: nil)
    fetch_revision(@ref, timeout:)
    super
  end
end
