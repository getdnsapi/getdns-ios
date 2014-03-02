getdns-ios
==========

iOS Framework and sample project for getdns

Building the Framework
----------------------

Requirements (i.e. build env tested on)

 - XCode 5.0 with command line tools
 - OSX 10.9
 - iOS 7.0 SDK

Steps have been taken to automate building the framework.

 - cd scripts
 - ./build-framework.sh

All useful settings are in settings.env - by default the framework is built in build/output/getdns.framework

Sample App
----------

A sample application is provided.  If the framework is built with default settings, then the sample app should link as it looks in build/output for the framework.

Using the Framework
-------------------

Once built, the framework can be used in an iOS app.  In addition to adding the framework, the following libraries and frameworks must be added:

 - CFNetwork
 - libresolv.dylib
 - libiconv.dylib

Make sure that Dead Code Stripping under Build Settings is set to No.  Otherwise linker errors occur when building for devices.

Acknowledgements
----------------

The following projects / sources proved invaluable as reference:
 - https://github.com/x2on/expat-ios
 - https://github.com/hasseily/Makefile-to-iOS-Framework
 - https://github.com/Raphaelios/raphaelios-scripts

