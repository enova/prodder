Feature: Basic CLI usage

  Scenario: prodder help
    When I run `prodder help`
    Then the output should contain "Tasks:"

  Scenario: No config file supplied
    When I run `prodder`
    Then the output should contain "required option '--config'"

  Scenario: Config file not found
    When I run `prodder init -c not-there.yml`
    Then the output should contain exactly "Config file not found: not-there.yml\n"
    And the exit status should be 1

  Scenario: Malformed config file
    Given a file named "broken.yml" with:
      """
      %this IS NOT VALID YAML
      """
    When I run `prodder init -c broken.yml`
    Then the output should contain:
      """
      Invalid YAML in config file broken.yml. Current file contents:

      %this IS NOT VALID YAML
      """

  Scenario: No database defined on project
    Given a file named "prodder.yml" with:
      """
      blog:
        structure_file: db/structure.sql
        seed_file: db/seeds.sql
        quality_check_file: db/quality_checks.sql
        git:
          origin: git@github.com:pd/blog.git
          author: prodder auto-commit <pd+prodder@krh.me>
      """
    When I run `prodder dump blog -c prodder.yml`
    Then the output should contain:
      """
      Missing required configuration key: blog/db

      Example configuration:
      blog:
        structure_file: db/structure.sql
        seed_file: db/seeds.sql
        quality_check_file: db/quality_checks.sql
        git:
          origin: git@github.com:your/repo.git
          author: prodder <prodder@example.com>
        db:
          name: database_name
          host: database.server.example.com
          user: username
          password: password
          tables:
            - posts
            - authors
      """

  Scenario: Projects named not defined in config file
    Given a prodder config in "prodder.yml" with project: store
    When I run `prodder init blog api -c prodder.yml`
    Then the output should contain "Project not defined: blog, api"

  Scenario: Listing projects
    Given a prodder config in "prodder.yml" with projects: store, blog
    When I run `prodder ls -c prodder.yml`
    Then the output should contain exactly:
      """
      store
      blog

      """
