Feature: prodder init

  Background:
    Given a prodder config in "prodder.yml" with project: blog
    And a "blog" git repository

  Scenario: Clone a project
    When I run `prodder init -c prodder.yml`
    Then the exit status should be 0
    And a directory named "prodder-workspace/blog" should exist
    And the workspace file "blog/README" should match /Read me/

  Scenario: Update pre-existing repository on re-initializing
    Given I run `prodder init -c prodder.yml`
    And a new commit is already in the "blog" git repository
    When I run `prodder init -c prodder.yml`
    Then the new commit should be in the workspace copy of the "blog" repository

  Scenario: Can't clone repository (no such repo, permissions, whatever)
    Given I deleted the "blog" git repository
    When I run `prodder init -c prodder.yml`
    Then the exit status should be 1
    And the output should contain "Failed to run 'git clone ./repos/blog"
    And the output should match /repository.*does not exist/
