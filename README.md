The repo contains the infrastructure to bulid PowerShell Core in Docker.

The module dockerBasedBuild is the main infrastructure.  The rest of the files are legacy.

Note:  This is currently highly geared toward VSTS, but we are open to contribution which make it more pluggable.  The majority of the VSTS specific operations have already been seperated into a separate module.

To use this module:

1. Create a wrapper script in your repo.  See docs/examples/vstsBuild.ps1.
1. Create Docker file(s) to build your product.  See docs/examples/Images.
1. Create a build JSON file which describe your docker file and how to build your product.  See docs/examples/build.json

