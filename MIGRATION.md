Inbound calls
-------------

- Set `X-CCNQ3-Endpoint` inbound, OpenSIPS needs it.
- CFA should never reach OpenSIPS: route them before!
- CFB on 486 -- make sure it is in `failure_causes`, and use `continue_on_fail`
- on 604 from OpenSIPS with CFNR, attempt to dial the CFNR.
- on 604 from OpenSIPS with no CFNR, fallback to static.
- static = `dst_endpoint/user_srv`, `dst_endpoint/user_ip`; send to OpenSIPS using `sip_network_destination` or `;fs_path=` or `sip_route_uri`. Note that the RURI is `sip_invite_req_uri`, while the To field is the `sofia/.../<To-field-here>` .
- CFDA -- catch on 408 I assume?
- On missing or invalid endpoint, send to CFNR, otherwise `500 Endpoint Error`.
- `dst_number/reject_anonymous` -> decline (already implemented I believe)
- `$DLG_timeout` = `$json(dst_number/dialog_timer)` -> `call_timeout`
- `$T_fr_inv_timeout` = `$json(dst_number/inv_timer)` -> `originate_timeout` / `leg_timeout` -- use `originate_continue_on_timeout` to catch ... or is it `progress_timeout` ?
- `$T_fr_timeout` = `$json(dst_number/timer)`, transaction-level timer (default `fr_timer` = 2)
- `dst_number/rate_limit`, `dst_number/max_channels`

Outbound calls
--------------

- Assert location from `src_endpoint/location`, `src_number/location`, it won't be provided in headers anymore. (Might already be implemented?)
- `number_domain` is not provided, locate from `src_endpoint`.
- Set `Privacy: id` based on `src_endpoint/privacy`, `src_number/privacy`
- Set `P-Asserted-Identity: <$json(src_endpoint/asserted_number)@$fd>`, `P-Asserted-Identity: <$json(src_number/asserted_number)@$fd>`
- if `src_endpoint/check_from`, make sure that `src_number/endpoint` === `src_endpoint/endpoint`, reject with `403 From Username is not listed`
- `src_number/rate_limit`, `src_number/max_channels`

Both in & out
-------------

- number-based rate-limiting, number-based max-channels must be done in FS
