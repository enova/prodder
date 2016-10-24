Feature: prodder dump

  Background:
    Given a prodder config in "prodder.yml" with project: blog

  Scenario: Happy path: dump structure.sql, listed seed tables, quality_checks.sql, permissions.sql and settings.sql
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/structure.sql" should match /CREATE TABLE posts/
    And  the workspace file "blog/db/structure.sql" should match /CREATE TABLE authors/
    And  the workspace file "blog/db/seeds.sql" should match /COPY posts/
    And  the workspace file "blog/db/seeds.sql" should match /COPY authors/
    And  the workspace file "blog/db/quality_checks.sql" should match /SET search_path/
    And  the workspace file "blog/db/quality_checks.sql" should match /CREATE TRIGGER /
    And  the workspace file "blog/db/permissions.sql" should match /GRANT /
    And  the workspace file "blog/db/settings.sql" should match /ALTER DATABASE /

  Scenario: Include specified users, exclude other login roles from permissions dump
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should not match /exclude_this/
    And  the workspace file "blog/db/permissions.sql" should match /include_this/

  Scenario: Roles missing ACL must be created, modified and granted if they're granted to non-login/included users
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should match /create_role_if_not_exists\('prodder__blog_prod:read_only'\);/
    And  the workspace file "blog/db/permissions.sql" should match /ALTER ROLE "prodder__blog_prod:read_only" WITH NOSUPERUSER/
    And  the workspace file "blog/db/permissions.sql" should match /GRANT "prodder__blog_prod:read_only" TO "prodder"/

  Scenario: Roles are created smartly based on connected components in structure
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should not match /create_role_if_not_exists\('_92b'\);/
    And  the workspace file "blog/db/permissions.sql" should not match /create_role_if_not_exists\('_93b'\);/
    And  the workspace file "blog/db/permissions.sql" should not match /ALTER ROLE "_92b" WITH/
    And  the workspace file "blog/db/permissions.sql" should not match /ALTER ROLE "_93b" WITH/
    And  the workspace file "blog/db/permissions.sql" should not match /GRANT "_92b" TO "_93b"/

  #TODO: Not sure how to test this
  Scenario: All loginable (are there other kinds?) superusers are dumped
  #TODO: Not sure how to test this
  Scenario: Exhaustively test ACL

  Scenario: Valid until option is quoted
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should match /VALID UNTIL '.*'/

  Scenario: Exclude passwords from permissions dump
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should not match /PASSWORD '.*'/

  Scenario: Roles are created if not existing instead of always being created
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should not match /CREATE ROLE \S*;/
    And  the workspace file "blog/db/permissions.sql" should match /create_role_if_not_exists\(.*\)/

  Scenario: Exclude permissions dump if file missing
    Given the prodder config in "prodder.yml" does not include a permissions file for the "blog" project
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    Then  the workspace file "blog/db/permissions.sql" should not exist

  Scenario: Exclude permissions dump if permissions object is missing
    Given the prodder config in "prodder.yml" does not include permissions for the "blog" project
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    Then  the workspace file "blog/db/permissions.sql" should not exist

  Scenario Outline: Exhaustively test role creation and altering
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should match /<role_creation>/
    And  the workspace file "blog/db/permissions.sql" should match /<role_altering>/

    Examples:
      |                role_creation                |                                role_altering                              |
      |                   prodder                   |                     ALTER ROLE "prodder" WITH NOSUPERUSER                 |
      |         prodder__blog_prod:read_only        |           ALTER ROLE "prodder__blog_prod:read_only" WITH NOSUPERUSER      |
      |                 include_this                |                  ALTER ROLE "include_this" WITH NOSUPERUSER               |
      |                  _90enva                    |                       ALTER ROLE "_90enva" WITH NOSUPERUSER               |
      |                   _91b                      |                       ALTER ROLE "_91b" WITH NOSUPERUSER                  |
      |                   _91qa                     |                       ALTER ROLE "_91qa" WITH NOSUPERUSER                 |
      |                   _91se                     |                       ALTER ROLE "_91se" WITH NOSUPERUSER                 |
      |                   _92qa                     |                       ALTER ROLE "_92qa" WITH NOSUPERUSER                 |
      |                   _92se                     |                       ALTER ROLE "_92se" WITH NOSUPERUSER                 |
      |                   _93se                     |                       ALTER ROLE "_93se" WITH NOSUPERUSER                 |
      |                   _94se                     |                       ALTER ROLE "_94se" WITH NOSUPERUSER                 |
      |prodder__blog_prod:permissions_test:read_only|ALTER ROLE "prodder__blog_prod:permissions_test:read_only" WITH NOSUPERUSER|
     |prodder__blog_prod:permissions_test:read_only|ALTER ROLE "prodder__blog_prod:permissions_test:read_write" WITH NOSUPERUSER|

  Scenario Outline: Exhaustively test memeberships
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/permissions.sql" should match /<membership>/

    Examples:
      |                                         membership                                        |
      |         GRANT "prodder__blog_prod:permissions_test:read_write" TO "include_this"          |
      |                     GRANT "prodder__blog_prod:read_only" TO "prodder"                     |
      |  GRANT "prodder__blog_prod:permissions_test:read_only" TO "prodder__blog_prod:read_only"  |
      |                                GRANT "_90enva" TO "_91se"                                 |
      |                                GRANT "_90enva" TO "_91qa"                                 |
      |                                GRANT "_90enva" TO "_91b"                                  |
      |                                GRANT "_91se" TO "_92se"                                   |
      |                                GRANT "_91qa" TO "_92se"                                   |
      |                                GRANT "_91qa" TO "_92qa"                                   |
      |                                GRANT "_91b" TO "_92qa"                                    |
      |                                GRANT "_91qa" TO "_94se"                                   |
      |                                GRANT "_92se" TO "_93se"                                   |
      |                                GRANT "_93se" TO "_94se"                                   |

  Scenario: Exclude specified tables from structure dump
    Given the prodder config in "prodder.yml" excludes the table "authors" from the dump of "blog"
    When  I run `prodder dump -c prodder.yml`
    Then  the exit status should be 0
    And   the workspace file "blog/db/structure.sql" should not match /CREATE TABLE authors/

  Scenario: Verify settings file contents
    Given I add a customer parameter "c.p" with value "v" in the "blog" project's database
    When  I run `prodder dump -c prodder.yml`
    Then the workspace file "blog/db/settings.sql" should match /ALTER DATABASE prodder__blog_prod SET  c.p=v/

  Scenario: Exclude specified schemas from structure dump
    Given the prodder config in "prodder.yml" excludes the schema "ads" from the dump of "blog"
    And   I add a "ads" schema to the "blog" project's database
    When  I run `prodder dump -c prodder.yml`
    Then  the exit status should be 0
    And   the workspace file "blog/db/structure.sql" should not match /CREATE SCHEMA ads/

  Scenario: Unspecified tables are not dumped to seeds
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/seeds.sql" should not match /COPY comments/

  Scenario: Grant/revoke/ownership are not in the structure dump
    When I run `prodder dump -c prodder.yml`
    Then the workspace file "blog/db/structure.sql" should not match /GRANT/
    And  the workspace file "blog/db/structure.sql" should not match /ALTER TABLE.*OWNER TO/

  Scenario: Ownership is not in the seeds dump
    When I run `prodder dump -c prodder.yml`
    Then the workspace file "blog/db/seeds.sql" should match /Owner: -/
    And  the workspace file "blog/db/seeds.sql" should not match /Owner: [^-]/

  Scenario: Verify quality_checks file contents
    Given I add a foreign key from table "posts" and column "author_id" to table "authors" and column "author_id" in the "blog" project's database
    When I run `prodder dump -c prodder.yml`
    Then the workspace file "blog/db/quality_checks.sql" should match /ADD CONSTRAINT .* FOREIGN KEY/
    Given I add an index to table "posts" on column "author_id" in the "blog" project's database
    When I run `prodder dump -c prodder.yml`
    Then the workspace file "blog/db/quality_checks.sql" should match /CREATE INDEX /

  Scenario: Maintaining quality checks directly in the structure file
    Given the prodder config in "prodder.yml" does not include a quality check file for the "blog" project
    And   I add a foreign key from table "posts" and column "author_id" to table "authors" and column "author_id" in the "blog" project's database
    When  I run `prodder dump -c prodder.yml`
    Then  the workspace file "blog/db/quality_checks.sql" should not exist
    And   the workspace file "blog/db/structure.sql" should match /ADD CONSTRAINT .* FOREIGN KEY/

  Scenario: Projects can use a YAML file to specify their seed tables
    Given the prodder config in "prodder.yml" says to read the "blog" seed tables from "db/seeds.yml"
    And  the "blog" file "db/seeds.yml" contains:
      """
      - posts
      """
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 0
    And  the workspace file "blog/db/seeds.sql" should match /COPY posts/
    But  the workspace file "blog/db/seeds.sql" should not match /COPY authors/

  Scenario: YAML file listing seed tables does not exist
    Given the prodder config in "prodder.yml" says to read the "blog" seed tables from "db/seeds.yml"
    But   the "blog" file "db/seeds.yml" does not exist
    When  I run `prodder dump -c prodder.yml`
    Then  the exit status should be 1
    And   the output should contain "No such file: blog/db/seeds.yml"

  @restore-perms
  Scenario: pg_dump failed
    Given the "prodder" role can not read from the "blog" database's tables
    When I run `prodder dump -c prodder.yml`
    Then the exit status should be 1
    And the output should contain "permission denied"
