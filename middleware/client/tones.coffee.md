Not a middleware
================

This module is not a middleware, it's really just a regular module.

`tone_stream` specifications
============================

See [tone_stream](https://freeswitch.org/confluence/display/FREESWITCH/Tone_stream).

Basically:
```
[L=x;][v=y;]%(on-duration,off-duration,freq1[,freq2][,freq3][...])[;loops=x]
```

* `L=x` create `x` loops in memory (use e.g. for very short tones).
* `loops=x` play `x` loops in software; x=-1 == endless loop.
* on-duration/off-duration in ms.
* frequencies in Hz.
* `freq1,freq2` etc are additive; use `freq1=X+Y`, `freq2=X-Y` for 'X modulated by Y'.

Annex to ITU Operational Bulletin E.180-2010 -- Suisse (Confédération)
======================

[Annex to ITU OB E.180-2010](http://www.itu.int/dms_pub/itu-t/opb/sp/T-SP-E.180-2010-PDF-F.pdf) indicates:

- Tonalité d'occupation - 425 - 0.5 on 0.5 off
- Tonalité d'encombrement - 425 - 0.2 on 0.2 off
- Tonalité de numérotation - 425 - continu
- Tonalité de numérotation spéciale I - 425+340 - 1.1 on 1.1 off
- Tonalité de numérotation spéciale II - 425 - 0.5 on 0.05 off
- Tonalité de retour d'appel - 425 - 1.0 on 4.0 off
- Tonalité spéciale d'information - 950/1400/1800 - 3x0.333 on 1.0 off
- Tonalité d'appel en attente - 425 - 0.2 on 0.2 off 0.2 on 4.0 off

Note: The official reference would be Bakom's [RS 784.101.113/1.6](https://www.bakom.admin.ch/dam/bakom/fr/dokumente/tc/rechtliche_grundlagen/sr_784_101_113_16eigenschaftenvonschnittstellendergrundversorgun.pdf.download.pdf/rs_784_101_113_16caracteristiquesdinterfaceduserviceuniversel.pdf) which references [ETSI ES 201 970 V1.1.1 (2002-08)](http://www.etsi.org/deliver/etsi_es/201900_201999/201970/01.01.01_60/es_201970v010101p.pdf). Congestion tone esp. is actually 0.25s on / 0.25s off, while Call Waiting is 0.2/0.2/0.2/9.0.

    @ch =
      ringback: '%(1000,4000,425)'
      waiting: '%(200,200,425);%(200,4000,425)'

Annex to ITU Operational Bulletin E.180-2010 -- France
=============

Tonalité d'occupation - 440 - 0.5 on 0.5 off
Tonalité de numérotation - 440 continu
Tonalité de retour d'appel - 440 - 1.5 on 3.5 off
Tonalité spéciale d'information - 950/1400/1800 - 3x(0.3 on 0.03 off) 1.0 off
Tonalité d'appel en attente - 440 - 0.3 on 10.0 off

    @fr =
      ringback: '%(1500,3500,440)'
      waiting: '%(300,10000,440)'

    @loop = (tone) ->
      "tone_stream://#{tone};loops=-1"
