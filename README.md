FreeSwitch CCNQ4 middlewares and configuration

Configuration
=============

`country`: short (two-letter) country name
`dialplan`: `e164` (global numbers), `national` (ingress and egress, requires country), `centrex` (egress only, requires country)

Centrex
-------

Typically for Centrex we use `number_domain` === `endpoint_domain`.

### Global Number (`number:<E164-number>`)

Add

`local_number`: `number@number_domain`

### Endpoint (`endpoint:<ip>` or `endpoint:<username>@<endpoint_domain>`)

Changes:
- `number_domain` is now a Centrex number-domain.
- `country` must be specified.

Note that generally `username` === `local_number`.
For Centrex, generally `endpoint_domain` === `number_domain`.

`number_domain`: Used to retrieve the local number. No default.
`outbound_route`: Used for national dialplan (once out of Centrex profile).

### Local Number

- `country` (optional)

### Number Domain (`number_domain:<number_domain>`)

Used for egress.

- `dialplan`
- `country`
