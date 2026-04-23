# Terraform Skeleton

This skeleton defines the set of core configurations and tools that apply to all Launch Terraform modules.

These are intended to be evolved and updated over time. For initial Terraform configurations that are applied when a new repository is created, see the [launch-terraform-template](https://github.com/launchbynttdata/launch-terraform-template) repository.

![repo-map-skeleton.jpg](repo-map-skeleton.jpg)

## How this repository works

This repository contains a template for the [Copier](https://copier.readthedocs.io/en/stable/) tool. The contents of the [template/](./template/) folder will be copied into a destination Terraform Module repository and kept current by way of our [automated update from skeleton workflow](./template/.github/workflows/update-from-skeleton.yml). This automated workflow checks for updates, applies the update if one is found, and opens a pull request that, if all checks pass, will automatically merge and update the Terraform module with the latest changes. The files delivered by this template shouldn't change very much on a per-repo basis, but Copier is smart enough to be able to detect and merge changes in downstream repositories in many cases. This means that you can safely add items to your .gitignore if your Terraform module generates temporary files that would otherwise be committed, and when changes are published to this skeleton your additions will be preserved.

If Copier can't safely merge changes from a given update, it will leave a pull request open on the repository so that a human or agent can address the issues and get the update merged after a manual review.

## Template Folder

Files contained within the [template](./template/) folder will be updated in the root of the downstream repos when they are changed. This allows us to separate the workflows associated with this repository from the workflows found in a downstream repository. Changes to these files should be made in a way that they are compatible with our entire Terraform ecosystem. Prereleases can be utilized to roll out a change across a subset of repositories.

## Release Process

Given that a change here may eventually land in several hundred downstream repositories, it's critical that we have a way to validate our changes before they are rolled out to the entire ecosystem. This repository uses a system of prereleases through GitHub and Copier to provide a rollout to a smaller sample. The full release process looks like this:

1. A pull request to this repository is opened with a desired change to the templates/ folder.
2. Once the PR has been reviewed, approved, and all checks are passing, it is merged to the main branch.
3. The act of merging to the main branch causes two releases to be created:
    - A prerelease (or release candidate) for the next version is created and published
    - A full release for the next version is drafted if it does not already exist, but it is not published
4. The prerelease is evaluated against a subset of the ecosystem to confirm that it behaves as expected
    - If the prerelease does not perform as expected, further changes are PRed and merged to main, which result in the creation of a new prerelease, which is retested.
5. Once the prerelease has been validated and works as desired, the drafted release is published, which will encompass all the changes in the prereleases

Be sure to regenerate the release notes prior to publishing the drafted release, to ensure you pick up all of the commits in the release candidates!

## Prerelease Opt-in

Prereleases are currently opt-in at the repository level, controlled via a Custom Property. Set the `prerelease` property to "true" on any Terraform module to have the auto-update workflows utilize prereleases.

