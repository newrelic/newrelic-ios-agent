#  GHA and locally running actions using `act`

Getting started
`brew install act`

Running github actions locally is normally easy via the act framework. One hitch in this case is that act doesn't yet support mac os. Luckily there is work being done in this area already in the open source community of act.
In order to run locally using the act framework you must use a patched version of act from this branch/pr: https://github.com/nektos/act/pull/1293

checkout act and build it from source by following guide:
https://github.com/nektos/act#manually-building-from-source

Here I've locally built act my ExtWorkspace folder and the patched binary is at /dist/local/act in my act source directory.

`../../ExtWorkspace/act/dist/local/act -v -P ubuntu-latest=-self-hosted`


The known issue I've ran into is that cmake can't be found for some reason the way xcodebuild is in invoked inside the host runner.
For now this can be fixed by substituting `/opt/homebrew/bin/cmake ` for `cmake` at the beginning of line 76 in libMobileAgents `createThinArchive.sh`