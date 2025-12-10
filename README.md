
# Prodder

A tool to maintain and load your Rails application's database structure, seed
table contents, permissions and database settings based on its migration history
and the current state in production databases.

In short: `db:reset db:migrate`

## Requirements

- **Ruby 3.3+** - This gem requires Ruby 3.3.0 or later
- PostgreSQL 9.1.11+ (confirmed working: 9.1.11+, 9.2.6+)

**Note:** Support for Ruby versions older than 3.3 (including 2.6, 2.7, and 3.0) has been removed as of version 1.0. If you need to use an older Ruby version, please use a previous version of this gem.

## Overview

1. Your project maintains `db/structure.sql`, `db/seeds.sql`, and optional
   `db/quality_checks.sql` and `db/permissions.sql` files as it sees fit (ie, by using `prodder` as a script to dump
   production and push it to your git repository).
2. Make sure `db/seeds.sql` includes the `schema_migrations` table.
3. Only new migrations will be run against prod's structure using its seed table contents.
4. Once a migration has been deployed, it should result in `db/structure.sql` and
   `db/quality_checks.sql` files being modified, and any new seed data being added to
   `db/seeds.sql` -- including the new entry in `schema_migrations`.
5. That migration never needs to be run in development again. Feel free to `rm`.
6. Any application related permission changes will result in `db/permissions.sql` being modified.

## Replacing `rake db:*`
`prodder` can be included as a railtie in your application to automatically
replace many of Rails' `db:*` tasks. The only prerequisites to its usage are
the existence of `db/structure.sql`, `db/seeds.sql` with at least the
`schema_migrations` table contents included. Optional `db/quality_checks.sql` and `db/permissions.sql`
will be loaded after seeding, which can be helpful if you wish to seed the database
prior to enforcing foreign key constraints and if you want to develop in an environment
with the same permissions setup as production.

### Installation

In your Gemfile:

```ruby
gem 'prodder', require: 'prodder/railtie'
```

It doesn't really matter, but for sanity's sake, you should set your `schema_format`
to `:sql`:

```ruby
# config/application.rb
module Whatever
  class Application
    config.active_record.schema_format = :sql
  end
end
```

If you want to work with permissions setup like production:
```ruby
# config/database.yml

username: user_who_will_run_your_app (# for example identity__web)
migration_user: migration_overlay_user_who_is_usually_db_owner (# for example identity__owner)
superuser: godmode (# for example postgres)
```

Note that the `migration_user` and `superuser` must be created before you run `db:reset db:migrate`, just as you would have to when you have to
create the `username: user` even with the standard setup. Note that this is only ever recommended for development environments. Do NOT
mess with production overlays to have 3 different users in production, that's the reason for having overlays in the first place.You can also
easily control this by making the gem a `group :development` only dependency:

```
#!/usr/bin/env bash

set -eu

createuser --superuser --createrole --createdb godmode || true
createuser --createrole migration_overlay_user_who_is_usually_db_owner || true

bundle install
bundle exec rake db:reset db:migrate
```

### Usage

Things that really matter:

1. `rake db:reset` recreates your database, loading `db/structure.sql`, `db/seeds.sql`,
   `db/quality_checks.sql` and `permissions.sql`.
2. `rake db:migrate` runs migrations, as before, but runs *after* the initial seeds were
   created. Those initial seeds should have included your production app's `schema_migrations`
   table contents. This means only those migrations that have not yet run in production
   will need to be run locally.
3. If you configured to have 3 users in your `#config/database.yml` file and have a `permissions.sql` file present,
   all your `db:*` commands will be run in the context of the user it makes the most sense to run as, mimicking
   our production environment. For instance(s), to reset the database (god forbid we do this in production), it will
   run as `superuser`, to run a migration, as the `migration_user` and your application will connect to the database
   as `username`. Thus it achieves the overlays of a DBA, migration and production application.
4. Having 3 users configured and to achieve the effects of step 3, you must have a `permissions.sql`. However, you do
   not need to have 3 users configured to restore permissions (load the `permissions.sql` file). This being said, it
   does not make sense to restore permissions in your environment if you're just going to run everything as a single,
   most likely superuser.


### Details

This will remove the `db:*` tasks:

* `db:_dump`: an internal task used by rails to dump the schema after migrations. Obsolete.
* `db:drop:*`
* `db:create:*`
* `db:migrate`
* `db:migrate:reset`
* `db:migrate:up`
* `db:migrate:down`
* `db:fixtures:.*`
* `db:abort_if_pending_migrations`
* `db:purge:*`
* `db:charset`
* `db:collation`
* `db:rollback`
* `db:version`
* `db:forward`
* `db:reset`
* `db:schema:*`
* `db:seed`
* `db:setup`
* `db:structure:*`
* `db:test:*`
* `test:prepare`: Rails 4.1 added this task to auto-maintain the test DB schema.

And reimplement only the following:

* `db:structure:load`: Load the contents of `db/structure.sql` into the database of your current environment.
* `db:seed`: Load `db/seeds.sql` into the database of your current environment.
* `db:quality_check`: Load `db/quality_checks.sql` into the database of your current environment, if present.
* `db:reset`: db:drop db:setup
* `db:settings`: Load the contents of `db/settings.sql` into the database of your current environment.
* `db:setup`: db:create db:structure:load db:seed db:quality_check db:settings
* `db:test:prepare`: RAILS_ENV=test db:reset db:migrate
* `db:test:clone_structure`: RAILS_ENV=test db:reset db:migrate
* `test:prepare`: db:test:prepare
* `db:drop`: Drop database as superuser
* `db:create`:  Create database as `superuser` and transfer ownership to `migration_user`
* `db:migrate:*`, `db:rollback` Run migrations up/down as `migration_user`
* `db:purge:*, db:charset, db:collation, db:version, db:forward, db:rollback, db:abort_if_pending_migrations` as
  appropriate users.

See [lib/prodder/prodder.rake](lib/prodder/prodder.rake)
for more info.

This is likely to cause issues across Rails versions. No other choice really. It
has been used in anger on Rails 3.2.x and Rails 4.1.x.

## Development and Testing

### Ruby Version

This project uses Ruby 3.3. The required Ruby version is specified in `.ruby-version` and the gemspec file.

### Testing Frameworks

This project uses the following testing frameworks:

- **RSpec 3.13+** for unit tests
- **Cucumber 10.x** for feature tests (upgraded from 2.x)
- **Aruba 2.x** for CLI testing (upgraded from 0.5.x)

### Running Tests

```bash
# Run RSpec tests
bundle exec rspec

# Run Cucumber features
bundle exec cucumber

# Run all tests
bundle exec rspec && bundle exec cucumber
```

### Supported PostgreSQL Versions

Confirmed working versions of Postgres:

* 9.1.11+
* 9.2.6+

## Using prodder to maintain `db/*` files

### Example configuration

`prodder` is configured using a simplistic YAML file. There is no logic performed
to locate that file; the path to it *must* be provided each time `prodder` is
invoked.

```yaml
# Each top-level key is the name of the Rails project for which we are updating
# the structure and seed data. Let's pretend we're maintaining a online store.

store:
  structure_file: db/structure.sql
  seed_file: db/seeds.sql
  quality_check_file: db/quality_checks.sql
  permissions:
    file: db/permissions.sql
    included_users: service__owner, service__web, prodder__read_only
  git:
    origin: git@github.com:pd/store.git
    author: prodder auto-commit <pd+prodder@krh.me>
  db:
    name: store_production_db
    host: store-db.krh.me
    user: prodder_readonly
    password: super-secret
    tables:
      - schema_migrations
      - coupons
      - products
      - vendors
    exclude_tables:
      - production_only_table
    exclude_schemas:
      - production_only_replication_schema
```

If you would prefer to maintain the list of seed tables within your application
itself, the `db.tables` key can be given the path to a YAML file from which to
load the list instead:

```yaml
# prodder-config.yml
store:
  # [snip]
  db:
    tables: config/seeds.yml

# store/config/seeds.yml:
- schema_migrations
- coupons
- products
- vendors
```

### Quality Checks

In some cases, such as foreign key dependencies and triggers, you may wish to defer
loading constraints on your tables until _after_ your seed data has been loaded.
`prodder` treats the presence of a `quality_check_file` key in the configuration
as an indication that it should split `structure_file` into those statements which
create the base structure, and put the constraints into the `quality_check_file`.

### Permissions

We have had multiple cases in the past with deployments failing because some role
cannot access something on prod. To fail early and catch these in development, it
would be easier to just have these permissions loaded in development environments.
However, note that to actually take advantage of these restored permissions, you
must configure the 3 users as mentioned before in `#config/database.yml`.

```yaml
store:
  structure_file: db/structure.sql       # CREATE TABLE ...
  quality_check_file: db/quality_checks.sql # ALTER TABLE ... ADD FOREIGN KEY ...
```

### Example usage

The `-c` option to specify the configuration file is always required. All
options should be passed at the end of the command line.

```
# Clone all the repositories in prodder.yml, update the remotes for
# any that already existed but have new origins specified, and
# check out the branch specified in the config. The branch must be
# the name of an available remote branch, as the local branch will
# be forcibly reset to its current SHA with `git reset --hard`.
$ prodder init -c prodder.yml

# Dump the remote databases' structures and seed tables into the
# files specified by structure_file and seed_file.
$ prodder dump -c prodder.yml

# Lots of projects? Dump just one or two:
$ prodder dump store chordgen -c prodder.yml

# Commit the changes to each project's repository. Only repositories
# with actual changes will be committed.
$ prodder commit -c prodder.yml

# Push.
$ prodder push -c prodder.yml
```

## TODO

* Log activity as it is performed.
* Support tracking a particular branch instead of master.
* Support specifying the options to pass to each pg_dump form.
* Select dumping only a subset of a seed table. (pg_dump won't do this ...)

## Previous Contributors

* [Kyle Hargraves](https://github.com/pd)
* [Sri Rangarajan](https://github.com/Slania)
* [Emmanuel Sambo](https://github.com/esambo)
* [Cindy Wise](https://github.com/cyyyz)
* [Robert Nubel](https://github.com/rnubel)
* [Josh Cheek](https://github.com/JoshCheek)

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
