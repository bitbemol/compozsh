# The website is an optional static surface, never a shell dependency.
_test_site_static_contract() {
  local site_dir="$TEST_REPO_ROOT/docs" site_file='' html='' css='' script=''
  for site_file in index.html styles.css app.mjs search.mjs demo-data.mjs .nojekyll; do
    [[ -f "$site_dir/$site_file" ]] || {
      test_fail "missing static website file: $site_file"
      return 1
    }
  done
  html=$(<"$site_dir/index.html")
  css=$(<"$site_dir/styles.css")
  script=$(<"$site_dir/app.mjs")
  test_assert_contains "$html" 'lang="en"' || return
  test_assert_contains "$html" 'href="#main"' || return
  test_assert_contains "$html" 'src="./app.mjs"' || return
  test_assert_contains "$html" 'href="./styles.css"' || return
  test_assert_contains "$html" 'Content-Security-Policy' || return
  test_assert_contains "$html" "connect-src 'none'" || return
  test_assert_contains "$html" 'Browser demo' || return
  test_assert_contains "$html" 'id="git-review-demo"' || return
  test_assert_contains "$html" '--symlink --dry-run' || return
  test_assert_contains "$html" 'blob/main/SECURITY.md' || return
  test_assert_contains "$html" 'Local processing. Compozsh never transmits your data.' || return
  test_assert_contains "$css" 'prefers-reduced-motion' || return
  test_assert_contains "$css" 'clamp(' || return
  test_assert_contains "$css" '.review-workspace' || return
  [[ $html != *'src="https://'* && $css != *'@import'* &&
     $script != *'innerHTML'* && $script != *'eval('* &&
     $script != *'fetch('* && $script != *XMLHttpRequest* &&
     $script != *WebSocket* && $script != *sendBeacon* ]] || {
    test_fail 'website added a remote asset, connection API, or executable text'
    return 1
  }
}
test_case 'website stays static, accessible, self-contained, and isolated' \
  _test_site_static_contract
