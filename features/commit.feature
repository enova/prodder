Feature: Commiting updated dumps to a project's repository

  Background:
    Given a prodder config in "prodder.yml" with project: blog
    And a "blog" git repository
    And I successfully run `prodder init -c prodder.yml`
    And I successfully run `prodder dump -c prodder.yml`

  Scenario: Structure, seed, quality_checks, permissions and settings files not yet tracked
    When I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository
    And the file "db/structure.sql" should now be tracked
    And the file "db/seeds.sql" should now be tracked
    And the file "db/quality_checks.sql" should now be tracked
    And the file "db/permissions.sql" should now be tracked
    And the file "db/settings.sql" should now be tracked

  Scenario: No changes to any file
    When I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository
    When I run `prodder dump -c prodder.yml`
    And  I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository

  Scenario: Changes only to the structure
    When I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository
    When I create a new table "linkbacks" in the "blog" database
    And  I run `prodder dump -c prodder.yml`
    And  I run `prodder commit -c prodder.yml`
    And  2 commits by "prodder auto-commit" should be in the "blog" repository
    And  the latest commit should have changed "db/structure.sql" to contain "CREATE TABLE linkbacks"
    And  the latest commit should not have changed "db/seeds.sql"
    And  the latest commit should not have changed "db/quality_checks.sql"
    And  the latest commit should not have changed "db/settings.sql"

  Scenario: Changes only to the seed file
    When I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository
    When I add a new author "Marley" to the "blog" database
    And  I run `prodder dump -c prodder.yml`
    And  I run `prodder commit -c prodder.yml`
    Then 2 commits by "prodder auto-commit" should be in the "blog" repository
    And  the latest commit should have changed "db/seeds.sql" to contain "Marley"
    And  the latest commit should not have changed "db/structure.sql"
    And  the latest commit should not have changed "db/quality_checks.sql"
    And  the latest commit should not have changed "db/settings.sql"

  Scenario: Changes to both
    When I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository
    When I create a new table "captchas" in the "blog" database
    And  I add a new author "Bob McBobbington" to the "blog" database
    And  I run `prodder dump -c prodder.yml`
    And  I run `prodder commit -c prodder.yml`
    Then 2 commits by "prodder auto-commit" should be in the "blog" repository
    And  the latest commit should have changed "db/structure.sql" to contain "CREATE TABLE captchas"
    And  the latest commit should have changed "db/seeds.sql" to contain "Bob McBobbington"
    And  the latest commit should not have changed "db/quality_checks.sql"
    And  the latest commit should not have changed "db/settings.sql"

  Scenario: Changes only to permissions
    When I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository
    When I create a new table "gotchas" in the "blog" database
    When I grant all permissions on table "gotchas" in the "blog" database to "prodder"
    And  I run `prodder dump -c prodder.yml`
    And  I run `prodder commit -c prodder.yml`
    And  2 commits by "prodder auto-commit" should be in the "blog" repository
    And  the latest commit should have changed "db/permissions.sql" to contain "GRANT ALL ON TABLE gotchas TO prodder"
    And  the latest commit should not have changed "db/seeds.sql"
    And  the latest commit should not have changed "db/quality_checks.sql"

  Scenario: Changes only to settings
    When I run `prodder commit -c prodder.yml`
    Then 1 commit by "prodder auto-commit" should be in the "blog" repository
    When I add a custom parameter "enova.key" with value "value" in the "blog" project's database
    And  I run `prodder dump -c prodder.yml`
    And  I run `prodder commit -c prodder.yml`
    And  2 commits by "prodder auto-commit" should be in the "blog" repository
    And  the latest commit should have changed "db/settings.sql" to contain "ALTER DATABASE prodder__blog_prod SET  enova.key=value"
    And  the latest commit should not have changed "db/seeds.sql"
    And  the latest commit should not have changed "db/quality_checks.sql"
    And  the latest commit should not have changed "db/permissions.sql"
