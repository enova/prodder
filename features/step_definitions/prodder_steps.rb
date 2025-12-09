Given 'the "store/db/name" key is missing from "$filename"' do |filename|
  # Eh, good enough!
  path = File.join @aruba_root, filename
  contents = File.read path
  File.open(path, 'w') { |f| f.write contents.sub(/^\s+name: \w+$/, '') }
end

Given 'the "$role" role can not read from the "blog" database\'s tables' do |role|
  Prodder::PG.new.psql('prodder__blog_prod', 'REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM prodder;')
end

Given 'I add an index to table "$table" on column "$column" in the "$project" project\'s database' do |table, column, project|
  Prodder::PG.new.psql "prodder__#{project}_prod", "CREATE INDEX test_index ON #{table} (#{column});"
end

Given 'I add a custom parameter "$parameter" with value "$value" in the "$project" project\'s database' do |parameter, value, project|
  Prodder::PG.new.psql "prodder__#{project}_prod", "ALTER DATABASE prodder__#{project}_prod SET #{parameter} = '#{value}';"
end

Given 'I add a foreign key from table "$table1" and column "$column1" to table "$table2" and column "$column2" in the "$project" project\'s database' do |table1, column1, table2, column2, project|
  Prodder::PG.new.psql "prodder__#{project}_prod", "ALTER TABLE #{table1} ADD CONSTRAINT fk_authors FOREIGN KEY (#{column1}) REFERENCES #{table2} (#{column2});"
end

Given 'no-op versions of these bins are available on my PATH: $bins' do |bins|
  paths = bins.split(/,\s*/).map { |bin|
    File.join(@aruba_root, "stub-#{bin}").tap do |dir|
      FileUtils.mkdir_p dir
      File.open(File.join(dir, bin), 'w') { |f| f.write 'foo' }
    end
  }.join(File::PATH_SEPARATOR)

  set_env 'PATH', "#{paths}#{File::PATH_SEPARATOR}#{ENV['PATH']}"
end

Given '"$bin" is not available on my PATH' do |bin|
  path = ENV['PATH'].split(File::PATH_SEPARATOR)
  dirs = path.select { |dir| File.exist? File.join(dir, bin) }
  set_env 'PATH', path.reject { |dir| dirs.include?(dir) }.join(File::PATH_SEPARATOR)
end

When 'I create a new table "$table" in the "$project" database' do |table, project|
  pg = Prodder::PG.new
  pg.psql "prodder__#{project}_prod", "CREATE TABLE #{table} ( id SERIAL PRIMARY KEY );"
end

When 'I add a new author "$author" to the "$project" database' do |author, project|
  pg = Prodder::PG.new
  pg.psql "prodder__#{project}_prod", "INSERT INTO authors (name) VALUES ('#{author}');"
end

When 'I add a "$name" schema to the "$project" project\'s database' do |name, project|
  pg = Prodder::PG.new
  pg.psql "prodder__#{project}_prod", "CREATE SCHEMA #{name} AUTHORIZATION prodder CREATE TABLE #{name}.providers ( id SERIAL PRIMARY KEY );"
end

When 'I grant all permissions on table "$table" in the "$project" database to "$role"' do |table, project, role|
  pg = Prodder::PG.new
  pg.psql "prodder__#{project}_prod", "GRANT ALL ON #{table} TO #{role}"
end

Then 'the output should contain the example config contents' do
  assert_partial_output Prodder::Config.example_contents, all_output
end

Then /^the workspace file "([^"]*)" should match \/([^\/]*)\/$/ do |file, partial_content|
  expect("prodder-workspace/#{file}").to have_file_content(/#{partial_content}/)
end

Then /^the workspace file "([^"]*)" should not match \/([^\/]*)\/$/ do |file, partial_content|
  expect("prodder-workspace/#{file}").not_to have_file_content(/#{partial_content}/)
end

Then /^the workspace file "([^"]*)" should not exist$/ do |file|
  expect("prodder-workspace/#{file}").not_to be_an_existing_file
end

Given(/a prodder config in "([^"]*)" with projects?: (.*)/) do |filename, projects|
  contents = projects.split(/,\s*/).map { |name|
    strip_leading <<-EOF
    #{name}:
      structure_file: db/structure.sql
      seed_file: db/seeds.sql
      quality_check_file: db/quality_checks.sql
      permissions:
        file: db/permissions.sql
        included_users: prodder, include_this
      git:
        origin: ./repos/#{name}.git
        author: prodder auto-commit <pd+prodder@krh.me>
      db:
        name: prodder__#{name}_prod
        host: localhost
        user: prodder
        tables:
          - posts
          - authors
    EOF
  }.join("\n")

  write_file filename, contents
end

Given 'the "$project" file "$filename" contains:' do |project, filename, contents|
  write_file "prodder-workspace/#{project}/#{filename}", contents
end

Given 'the prodder config in "$filename" says to read the "$project" seed tables from "$seeds"' do |filename, project, seeds|
  update_config filename do |config|
    config[project]['db']['tables'] = seeds
  end
end

Given 'the prodder config in "$filename" excludes the table "$table" from the dump of "$project"' do |filename, table, project|
  update_config filename do |config|
    config[project]['db']['exclude_tables'] ||= []
    config[project]['db']['exclude_tables'].push table
  end
end

Given 'the prodder config in "$filename" excludes the schema "$schema" from the dump of "$project"' do |filename, schema, project|
  update_config filename do |config|
    config[project]['db']['exclude_schemas'] ||= []
    config[project]['db']['exclude_schemas'].push schema
  end
end

Given 'the prodder config in "$filename" does not include a quality check file for the "$project" project' do |filename, project|
  update_config filename do |config|
    config[project].delete 'quality_check_file'
  end
end

Given 'the prodder config in "$filename" does not include a permissions file for the "$project" project' do |filename, project|
  update_config filename do |config|
    config[project]['permissions'].delete 'file'
  end
end

Given 'the prodder config in "$filename" does not include permissions for the "$project" project' do |filename, project|
  update_config filename do |config|
    config[project].delete 'permissions'
  end
end

Given 'the "$project" file "$filename" does not exist' do |project, filename|
  begin
    remove_file "prodder-workspace/#{project}/#{filename}"
  rescue Errno::ENOENT
  end
end
