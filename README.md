FreeSwitch CCNQ4 middlewares and configuration

Provisioning
============

Provisioning is done using the CouchDB document conventions.

A typical document will contain at least:

- `type`: `endpoint`, `number`, `number_domain`, …;
- a field named after `type`, for example `endpoint`, which contains the key for the record;
- `_id` is the concatenation of the type, `:`, and the key.

Other fields are specified for each individual document type.

This project uses especially the following extensions:

- `country`: short (two-letter) country name
- `dialplan`: `e164` (global numbers), `national` (ingress and egress, requires country), `centrex` (egress only, requires country)

Here are the main types of documents:

Endpoints
---------

An endpoint is an authenticated line or device on the customer side.

The `_id` for an endpoint may contain:
- `endpoint:<ip>` for static endpoints (authentication is IP-based);
- `endpoint:<username>@<endpoint_domain>` for dynamic endpoints (authentication is password-based).

The value for `endpoint_domain` must be a valid DNS name, typically defined using a NAPTR record, or proper SRV records. The document type `domain` can be used to dynamically create DNS domains inside CCNQ4.

Numbers
-------

Numbers might be global numbers (used to route between domain) or local numbers (used inside a domain).

The `_id` for numbers may contain:
- `number:<global-number>` where global-number is country-code + national number;
- `number:<local-number>@<number-domain>` where local-number is the number as presented and used by the customer.

Number-domain
-------------

A number-domain is a closed dialplan (such as a national dialplan, or a Centrex dialplan).

The `_id` for number-domains contains `number_domain:<number-domain>`.

Centrex
=======

For Centrex we use the convention `number_domain` === `endpoint_domain`.

### Global Number (`number:<E164-number>`)

Inbound translation from a global number to a local (Centrex) extension:
- `local_number`: `number@number_domain`

### Endpoint (`endpoint:<ip>` or `endpoint:<username>@<endpoint_domain>`)

For Centrex the following conventions are used:
- `endpoint_domain` is a Centrex number-domain.
- `country` must be specified.

Note that generally speaking, `username` === `local_number`.
And that for Centrex, `endpoint_domain` === `number_domain`.

Endpoints must specify:
- `number_domain`: Used to retrieve the local number. No default.
- `outbound_route`: Used for national dialplan (once out of Centrex profile).

### Local Number

Centrex local numbers must specify:
- `country` (optional)

### Number Domain (`number_domain:<number_domain>`)

Used for egress.

- `dialplan`
- `country`
