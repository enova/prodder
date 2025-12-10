Given 'a {string} git repository' do |project|
  fixture_repo = File.join(@prodder_root, 'features', 'support', "#{project}.git")
  unless File.directory? fixture_repo
    raise "Cannot initialize repo for project #{project}; expected fixture at: #{fixture_repo}"
  end

  run_command_and_stop "mkdir -p repos"
  if File.exist? File.join(expand_path('.'), "repos", "#{project}.git")
    run_command_and_stop "chmod -R a+w repos/#{project}.git"
    run_command_and_stop "rm -rf repos/#{project}.git"
  end
  run_command_and_stop "cp -pR #{fixture_repo} repos/#{project}.git"
end

Given 'I deleted the {string} git repository' do |project|
  run_command_and_stop "rm -rf repos/#{project}.git"
end

Given 'the {string} git repository does not allow pushing to it' do |project|
  run_command_and_stop "chmod -R a-w repos/#{project}.git"
end

Given 'a new commit is already in the {string} git repository' do |project|
  commit_to_remote project
end

Then 'the new commit should be in the workspace copy of the {string} repository' do |project|
  expect("prodder-workspace/#{project}/README").to have_file_content(/Also read this!/)
end

Then(/^(\d+) commits? by "([^"]+)" should be in the "([^"]+)" repository$/) do |n, author, project|
  in_workspace(project) do
    authors = `git log --pretty='format:%an'`.split("\n")
    expect(authors.grep(/#{author}/).size).to eq Integer(n)
  end
end

Then 'the file {string} should now be tracked' do |filename|
  in_current_directory do
    git = Prodder::Git.new(File.expand_path("prodder-workspace/blog"), nil)
    expect(git).to be_tracked(filename)
  end
end

Then 'the latest commit should have changed {string} to contain {string}' do |filename, content|
  in_workspace('blog') do
    changed = `git show --name-only HEAD | grep #{filename}`.split("\n")
    expect(changed).to_not be_empty

    diff = `git show HEAD | grep '#{content}'`.split("\n")
    expect(diff).to_not be_empty
  end
end

Then 'the latest commit should not have changed {string}' do |filename|
  in_workspace('blog') do
    changed = `git show --name-only HEAD | grep #{filename}`.split("\n")
    expect(changed).to be_empty
  end
end

Then 'the new commit should be in the remote repository' do
  in_current_directory do
    latest = `git --git-dir="./repos/blog.git" log | grep prodder`.split("\n")
    expect(latest).to_not be_empty
  end
end
