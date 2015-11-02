Inbound calls
-------------

- [x] Set `X-CCNQ3-Endpoint` inbound, OpenSIPS needs it.
- [x] CFA should never reach OpenSIPS: route them before!
- [x] CFB on 486 -- make sure it is in `failure_causes`, and use `continue_on_fail` (actually `src/switch_channel.c` says that if `continue_on_fail` is `true` then it always continues -- except on attended transfer)
- [x] on 604 from OpenSIPS with CFNR, attempt to dial the CFNR.
- [x] on 604 from OpenSIPS with no CFNR, fallback to static.
- [x] static = `dst_endpoint/user_srv`, `dst_endpoint/user_ip`; send to OpenSIPS using `sip_network_destination` or `;fs_path=` or `sip_route_uri`. Note that the RURI is `sip_invite_req_uri`, while the To field is the `sofia/.../<To-field-here>` .
- [x] CFDA -- catch on 408 I assume?
- [x] On missing or invalid endpoint, send to CFNR, otherwise `500 Endpoint Error`.
- [x] `dst_number/reject_anonymous` -> decline (already implemented I believe)
- [x] `$DLG_timeout` = `$json(dst_number/dialog_timer)` -> `call_timeout`
- [x] `$T_fr_inv_timeout` = `$json(dst_number/inv_timer)` -> `originate_timeout` / `leg_timeout` -- use `originate_continue_on_timeout` to catch ... or is it `progress_timeout` ?
- [ ] `$T_fr_timeout` = `$json(dst_number/timer)`, transaction-level timer (default `fr_timer` = 2)
- [ ] `dst_number/rate_limit`, `dst_number/max_channels`

Outbound calls
--------------

- [x] Assert location from `src_endpoint/location`, `src_number/location`, it won't be provided in headers anymore. (Might already be implemented?)
- [x] `number_domain` is not provided, locate from `src_endpoint`.
- [x] Set `Privacy: id` based on `src_endpoint/privacy`, `src_number/privacy`
- [x] Set `P-Asserted-Identity: <$json(src_endpoint/asserted_number)@$fd>`, `P-Asserted-Identity: <$json(src_number/asserted_number)@$fd>`
- [x] if `src_endpoint/check_from`, make sure that `src_number/endpoint` === `src_endpoint/endpoint`, reject with `403 From Username is not listed`
- [ ] `src_number/rate_limit`, `src_number/max_channels`

Both in & out
-------------

- [ ] number-based rate-limiting, number-based max-channels must be done in FS
