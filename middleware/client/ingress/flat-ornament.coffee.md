    @name = 'huge-play:middleware:client:ingress:flat-ornament'
    seem = require 'seem'

    run = require 'flat-ornament'

    @include = seem ->

      return unless @session.direction is 'ingress'
      return if @session.forwarding is true

Processing
==========

* doc.local_number.timezone (string) Local timezone for doc.local_number.ornaments
* session.timezone (string) Local timezone, defaults to doc.local_number.timezone for ingress calls

      @session.timezone ?= @session.number.timezone

* doc.local_number.ornaments: array of ornaments. Each ornament is a list of statements which are executed in order. Each statement contains three fields: `type`: the command to be executed; optional `param` or `params[]`; optional `not` to reverse the outcome of the statement. Valid types include Preconditions: `source(pattern)`: calling number matches pattern; `weekdays(days...)`: current weekday is one of the listed days; `time(start,end)`: current time is between start and end time, in HH:MM format; `anonymous`: caller requested privacy; `in_calendars([calendars])`: date is in one of the named calendars, stored in doc.number_domain.calendars; Postconditions: `busy`, `unavailable`, `no-answer`, `failed`; Actions: `accept`: send call to customer; `reject`: reject call (no announcement); `announce(message)`: reject call with announcement; `voicemail`: send call to voicemail; `forward(destination)`: forward call to destination. Not implemented yet: `email(recipient,template)` and `nighttime`.

      yield run.call this, @session.number.ornaments, @ornaments_commands
      return

The ornaments are simply an array of ornaments which are executed in the order of the array.
If any ornament return `true`, skip the remaining ornaments in the list.
