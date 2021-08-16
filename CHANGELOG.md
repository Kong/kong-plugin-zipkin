1.4.1 - 2021-07-08

Fixes:
  - Multiple simultaneous instances of the plugin don't collide with each other (#116)

1.4.0 - 2021-06-15

New features:
  - service.name and route.name tags (#115)

Fixes:
  - balancer_latency is nil upon failure (#113), thanks @greut!

1.3.0 - 2021-03-19

New features:
  - Support for Jaeger style uber-trace-id headers (#101), thanks @nvx!
  - Support for OT headers (#103), thanks @ishg!
  - Allow insertion of custom tags on the Zipkin request trace (#102)

Fixes:
  - The w3c parsing function was returning a non-used extra value, and it now early-exits (#100), thanks @nvx!
  - Creation of baggage items on child spans is now possible (#98), thanks @Asafb26!
  - Fixed a bug in which span timestamping could sometimes raise an error (#105), thanks @Asafb26!


1.2.0 - 2020-11-11

New features:
  - Static tags can now be added to the config. They will be added to the
    request span (#84)
  - New `default_header_type` config option (#93)

Non-breaking Changes:
  - `http_endpoint` is now optional, making it possible to use the plugin
    to exclusively adding/passing around tracing headers (#94)

1.1.0 - 2020-04-30

New features:
  - New `traceid_byte_count` config option (#74)
  - Handling of W3C header, and new `header_type` config option (#75)

Fixes:
  - (docs) Span annotations not correctly documented in README (#77)

1.0.0 - 2020-03-09

This version of the plugin has changed enough to be named 1.0.0.

One of the biggest differences from previous versions is that it
is independent from opentracing, while still being compatible with
Zipkin (#64). This allowed simplifying the plugin code and removing
3 external dependencies.

New features:
  - Handling of B3 single header (#66)

Fixes:
  - Stopped tagging non-erroneous spans with `error=false` (#63)
  - Changed the structure of `localEndpoint` and `remoteEndpoint` (#63)
  - Store annotation times in microseconds (#71)
  - Prevent an error triggered when timing-related kong variables
    were not present (#71)

0.2.1 - 2019-12-20

  - Fixed incompatibilities in timestamps and annotations. Shortened annotations (#60)


0.2.0 - 2019-11-12

  - Remove dependency on BasePlugin (#50, #51)
  - Rename `component` tag to `lc` (#52)
  - Restructure of Kong generated spans (#52)
  - Change the name of spans for http traffic to `GET` (#57)
  - Remove the no-longer supported `run_on` field from plugin config schema (#54)


0.1.3 - 2019-08-16

  - Add support for stream subsystem (#30)
  - Made sending credential optional with a new configuration
    parameter `include_credential` (#37)
  - Add possibility to override unknown service name with a new
    configuration parameter `default_service_name` (#45)


0.1.2 - 2019-01-18

  - Fix logging failure when DNS is not resolved
  - Avoid sending redundant tags (#28)
  - Move `run_on` field to top level plugin schema, not config (#34)


0.1.1 - 2018-10-26

  - Add `run_on` field to the plugin's config


0.1.0 - 2018-10-18

  - Start using the new DB & PDK modules (compatibility with Kong >= 0.15.0)
  - New schema format


0.0.6 - 2018-10-18

  - Fix failures when request is invalid or exits early
  - Note that this will be the last release that supports Kong 0.14.


0.0.5 - 2018-09-16

  - Fix possible bug when service name is missing
  - Add kong.node.id tag


0.0.4 - 2018-08-09

  - Fix operation when service and/or route are missing (#19)
  - Fix cause of missing kong.credential field
  - Support for deprecated Kong "api" entity via kong.api tag
  - Upgrade to opentracing-lua 0.0.2
  - Start of test suite


0.0.3 - 2018-07-06

  - Always pass tag values as strings
  - Fix errors when phases get skipped
  - Pass service name as localEndpoint


0.0.2 - 2018-06-28

  - Prevent timestamps from being encoded with scientific notation


0.0.1 - 2018-05-17

  - Initial release
